// map_screen.dart
//
// Stage 7-r2：地圖頁 thin shell。
//
// 此檔案在 round 1 之前 1380 行同時承擔 controller、render、async orchestration、
// dialog 觸發；r2 起退化為「組裝者」：
//   - 持有 [MapScreenController]（state / async / domain commands single source of truth）；
//   - 負責 widget 樹的組裝（AppBar / FAB / Body 三塊）；
//   - 負責所有 UI side effect（snackbar / dialog / showModalBottomSheet）；
//   - 把 5 個 layer/flow widget 串起來。
//
// 不在此 widget：
//   - 任何 hazard / event / poi 的 DB 查詢、marker 構造、async race 防護
//     → 全部在 [MapScreenController]；
//   - flutter_map MapController 與 viewport 推算 → 在 [MapView]；
//   - marking 流程 → 在 [HazardReportFlow]；
//   - hazard polygon / marker 構造 → 在 [HazardOverlay]；
//   - poi marker / self marker 構造 → 在 [PoiOverlay] / [SelfMarkerLayer]。

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TapPosition;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/screens/map/map_screen_controller.dart';
import 'package:ignirelay_app/ui/screens/map/models/map_action_results.dart';
import 'package:ignirelay_app/ui/screens/map/models/map_view_models.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/event_info_sheet.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/hazard_delete_dialog.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/hazard_info_sheet.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/poi_info_sheet.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/sos_cancel_dialog.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/hazard_report_flow.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_attribution_badge.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_error_screen.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_fab_column.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_legend_panel.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_loading_screen.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_location_header.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_view.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/pin_palette.dart';
import 'package:ignirelay_app/ui/secondary/triage_input.dart';
import 'package:ignirelay_app/ui/sheets/map_layer_settings.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final MapScreenController _ctrl;
  bool _ctrlInitialized = false;
  late final AnimationController _refreshSpinCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _isRefreshing = false;
  bool _showLegend = false;
  final GlobalKey<HazardReportFlowState> _flowKey =
      GlobalKey<HazardReportFlowState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ctrlInitialized) {
      _ctrl = MapScreenController(
        eventPublisher: context.read<EventPublisher>(),
        eventStream: context.read<EventStream>(),
        eventStore: context.read<EventStore>(),
        locationService: context.read<LocationService>(),
      );
      _ctrlInitialized = true;
      _ctrl.bootstrap();
    }
    // Phase 4：地圖 label 依 UI locale 渲染；同時 plumb brightness 給 Phase 5。
    // 此 callback 在 Localizations / Theme inherited widget 變動時自動 fire，
    // controller 內部會 dedupe 同值（避免每次 build 都 rebuild theme）。
    _ctrl.updateMapPresentation(
      locale: Localizations.localeOf(context),
      brightness: Theme.of(context).brightness,
    );
  }

  @override
  void dispose() {
    _refreshSpinCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // ── i18n + 視覺對照（提供給子 widget 注入）──

  /// hazard 種類 → (label, icon, color)。i18n 在 widget 樹層解。
  (String, IconData, Color) _hazardInfo(BuildContext ctx, String type) {
    final l = ctx.l10n;
    final color = PinPalette.color(PinCategory.hazard);
    switch (type) {
      case 'ROADBLOCK':
        return (l.mapHazardRoadblock, PinPalette.hazardIcon(type), color);
      case 'FIRE':
        return (l.mapHazardFire, PinPalette.hazardIcon(type), color);
      case 'CHEMICAL':
        return (l.mapHazardChemical, PinPalette.hazardIcon(type), color);
      case 'FLOOD':
        return (l.mapHazardFlood, PinPalette.hazardIcon(type), color);
      case 'BUILDING':
        return (l.mapHazardCollapse, PinPalette.hazardIcon(type), color);
      case 'LANDSLIDE':
        return (l.mapHazardLandslide, PinPalette.hazardIcon(type), color);
      default:
        return (type, Icons.help, color);
    }
  }

  /// EventVm → marker 視覺樣式（i18n tooltip）。
  EventMarkerStyle _eventStyle(EventVm e) {
    final l = context.l10n;
    String tooltipBase;
    IconData icon;
    double size;
    switch (e.urgency) {
      case 3:
        tooltipBase = l.mapEventSosRed;
        icon = Icons.sos;
        size = 36;
        break;
      case 2:
        tooltipBase = l.mapEventSosYellow;
        icon = Icons.warning_amber;
        size = 32;
        break;
      case 1:
        tooltipBase = l.mapEventSupply;
        icon = e.eventType == 0 ? Icons.inventory_2 : Icons.volunteer_activism;
        size = 28;
        break;
      default:
        tooltipBase = l.mapEventInfo;
        icon = Icons.info_outline;
        size = 24;
    }
    final tooltip =
        e.description.isNotEmpty ? '$tooltipBase\n${e.description}' : tooltipBase;
    return EventMarkerStyle(icon: icon, size: size, tooltip: tooltip);
  }

  // ── Map tap routing ──

  Future<void> _onMapTap(TapPosition tapPosition, LatLng latlng) async {
    if (_ctrl.marking.isActive) {
      _ctrl.updateMarkingCenter(latlng);
      return;
    }
    final pq = _ctrl.poiQuery;
    if (pq == null || !_ctrl.mapReady) return;
    // 對齊 r2 之前的行為：縮太遠時不查（避免低縮放時點到大片空地誤開 POI 詳情），
    // 並把實際 viewport zoom 傳進去做 nearest/tolerance 判定，避免用假 zoom (14)
    // 造成判定半徑與畫面不一致。
    final zoom = _ctrl.viewportZoom;
    if (zoom < 12) return;
    final poi = await pq.queryNearestPoi(latlng, zoom);
    if (poi == null || !mounted) return;
    PoiInfoSheet.show(context, poi);
  }

  Future<void> _onMapLongPress(TapPosition tapPosition, LatLng latlng) async {
    if (_ctrl.marking.isActive) return;
    _ctrl.enterMarkingNew(latlng);
  }

  // ── Hazard interaction ──

  void _openHazardInfo(HazardVm h) {
    final (typeLabel, typeIcon, typeColor) = _hazardInfo(context, h.type);
    HazardInfoSheet.show(
      context,
      hazard: h.raw,
      typeLabel: typeLabel,
      typeIcon: typeIcon,
      typeColor: typeColor,
      isMine: h.isMine,
      onEdit: () => _enterEditMode(h),
      onDelete: () => _deleteHazardConfirm(h.id),
      onConfirm: () async {
        final outcome = await _ctrl.confirmHazard(h);
        if (!mounted) return;
        switch (outcome) {
          case ConfirmHazardSucceeded(newCount: final n, typeKey: final t):
            final (label, _, _) = _hazardInfo(context, t);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.mapHazardConfirmSnack(label, n)),
                backgroundColor: Colors.green,
              ),
            );
          case ConfirmHazardFailure(errorMessage: final e):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.mapMbtilesLoadFail(e)),
                backgroundColor: Colors.red,
              ),
            );
        }
      },
    );
  }

  void _enterEditMode(HazardVm h) {
    final desc = _ctrl.enterMarkingEdit(h);
    // 把既有描述塞進 flow widget 的 TextEditingController。
    _flowKey.currentState?.seedDescription(desc);
  }

  Future<void> _deleteHazardConfirm(String hazardId) async {
    final confirmed = await HazardDeleteDialog.show(context);
    if (!confirmed || !mounted) return;
    final outcome = await _ctrl.deleteHazard(hazardId);
    if (!mounted) return;
    switch (outcome) {
      case DeleteHazardSucceeded():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.mapHazardDeletedSnack),
            backgroundColor: Colors.green,
          ),
        );
      case DeleteHazardFailure(errorMessage: final e):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.mapMbtilesLoadFail(e)),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // ── Sheets / Dialogs ──

  void _showLayerControlSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.igni.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MapLayerControlSheet(settings: _ctrl.layerSettings),
    );
  }

  void _openTriageSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.igni.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TriageInputWidget(onSubmit: _onTriageSubmit),
    );
  }

  Future<void> _onTriageSubmit(int urgency, String desc,
      {bool attachMedicalCard = false}) async {
    final outcome = await _ctrl.publishTriage(
      urgency: urgency,
      description: desc,
      attachMedicalCard: attachMedicalCard,
    );
    if (!mounted) return;
    switch (outcome) {
      case TriagePublished(urgency: final u, description: final d):
        final l = context.l10n;
        final labels = [
          l.mapTriageBroadcastLabel0,
          l.mapTriageBroadcastLabel1,
          l.mapTriageBroadcastLabel2,
          l.mapTriageBroadcastLabel3,
        ];
        final colors = [
          Colors.blue[700],
          Colors.green[700],
          Colors.orange[700],
          Colors.red[700],
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.mapTriageBroadcastSnack(labels[u], d)),
            backgroundColor: colors[u],
          ),
        );
      case TriageRateLimited(message: final m):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(m), backgroundColor: Colors.orange),
        );
      case TriageFailure(errorMessage: final e):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.mapMbtilesLoadFail(e)),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _cancelSos() async {
    final confirm = await SosCancelDialog.show(context);
    if (!confirm || !mounted) return;
    // i18n 由 widget 端組好再交給 controller，避免 controller 持有 BuildContext。
    final outcome = await _ctrl.cancelSos(
      descriptionPrefix: context.l10n.mapSosCancelledPrefix,
    );
    if (!mounted) return;
    switch (outcome) {
      case CancelSosSucceeded():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.mapSosCancelledSnack),
            backgroundColor: Colors.grey[700],
          ),
        );
      case CancelSosFailure(errorMessage: final e):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.mapSosCancelFailSnack(e)),
            backgroundColor: Colors.red[700],
          ),
        );
    }
  }

  // ── 重新整理動畫 ──

  Future<void> _refreshWithSpin() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshSpinCtrl.repeat();
    try {
      await Future.wait([
        _ctrl.loadOverlays(),
        Future.delayed(const Duration(milliseconds: 800)),
      ]);
    } finally {
      _refreshSpinCtrl.stop();
      _refreshSpinCtrl.reset();
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _centerOnUser() {
    final ok = _ctrl.requestCenterOnUser();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.mapGpsNotReady),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.igni;
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (ctx, _) {
        final mb = _ctrl.mbTilesState;
        return Scaffold(
          backgroundColor: p.bg0,
          appBar: AppBar(
            backgroundColor: p.bg1,
            foregroundColor: p.text0,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.mapTitle,
                    style: IgniTypography.titleMedium(p.text0)),
                Text(
                  '${_ctrl.events.length} EVENTS · ${_ctrl.hazards.length} HAZARDS',
                  style: IgniTypography.monoSmall(p.text2),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.layers, color: p.text1),
                onPressed: _showLayerControlSheet,
                tooltip: context.l10n.mapLayerControlTooltip,
              ),
              IconButton(
                icon: Icon(Icons.legend_toggle, color: p.text1),
                onPressed: () => setState(() => _showLegend = !_showLegend),
                tooltip: context.l10n.mapLegendTooltip,
              ),
              IconButton(
                icon: AnimatedBuilder(
                  animation: _refreshSpinCtrl,
                  builder: (_, child) => Transform.rotate(
                    angle: _refreshSpinCtrl.value * 2 * 3.14159265,
                    child: child,
                  ),
                  child: Icon(Icons.refresh, color: p.text1),
                ),
                onPressed: _refreshWithSpin,
                tooltip: context.l10n.mapRefreshTooltip,
              ),
            ],
          ),
          body: mb.loading
              ? const MapLoadingScreen()
              : !mb.available
                  ? MapErrorScreen(
                      errorKey: mb.errorKey,
                      errorArg: mb.errorArg,
                      onRetry: _ctrl.retryInitMbTiles,
                    )
                  : Stack(
                      children: [
                        MapView(
                          controller: _ctrl,
                          eventStyleFor: _eventStyle,
                          hazardIconFor: PinPalette.hazardIcon,
                          onHazardTap: _openHazardInfo,
                          onEventTap: (e) => EventInfoSheet.show(
                            context,
                            e.raw,
                            userLocation: _ctrl.selfLocation?.location,
                          ),
                          onPoiTap: (poi) =>
                              PoiInfoSheet.show(context, poi.raw),
                          onMapTap: _onMapTap,
                          onMapLongPress: _onMapLongPress,
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: MapLocationHeader(
                            userLocation: _ctrl.selfLocation?.location,
                            district: _ctrl.district,
                            road: _ctrl.road,
                          ),
                        ),
                        if (!_ctrl.marking.isActive)
                          Positioned(
                            bottom: 80,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  context.l10n.mapLongPressHint,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        HazardReportFlow(
                          key: _flowKey,
                          controller: _ctrl,
                          hazardInfoBuilder: _hazardInfo,
                        ),
                        if (_showLegend && !_ctrl.marking.isActive)
                          const MapLegendPanel(),
                        // OSM 圖資 attribution（左下、半透明、不吃手勢）。
                        const Positioned(
                          left: 8,
                          bottom: 8,
                          child: MapAttributionBadge(),
                        ),
                      ],
                    ),
          floatingActionButton: _ctrl.marking.isActive
              ? null
              : MapFabColumn(
                  hasUserLocation: _ctrl.selfLocation != null,
                  onCenterOnUser: _centerOnUser,
                  activeSosEventId: _ctrl.sos.activeEventId,
                  activeSosUrgency: _ctrl.sos.urgency,
                  onSosHoldActivated: _openTriageSheet,
                  onCancelSos: _cancelSos,
                  sosLabel: context.l10n.mapSosButton,
                  sosActiveLabel: context.l10n.mapSosSentLabel,
                  sosHoldHint: context.l10n.mapSosHoldHint,
                ),
        );
      },
    );
  }
}
