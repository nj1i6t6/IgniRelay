// map_view.dart
//
// Stage 7-r2：地圖核心呈現容器。
//
// 責任：
//   - 持有 *flutter_map 的* MapController（與 app-level MapScreenController 嚴格區分）；
//   - 訂閱 controller.centerRequest，當 controller 要求 centerOn 時執行 camera move；
//   - 在 onMapReady / onPositionChanged 把 viewport（zoom + bounds + ready）回報給
//     controller，由 controller 決定何時刷 POI；
//   - 組裝 children：底圖 / POI / 精度圈 / hazard / event / self / marking preview；
//   - tap callback 由父層注入（POI / hazard / event sheet 都在 widget 樹層處理）。
//
// 注意：本 widget 不直接讀 DB / service / l10n，所有資料來源是 MapScreenController。
// 但 children 的部分（如 EventMarker tooltip 文字）仍需 BuildContext，由父層
// 預先把字串組好並透過 callback 注入。

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import 'package:ignirelay_app/ui/screens/map/map_screen_controller.dart';
import 'package:ignirelay_app/ui/screens/map/models/map_view_models.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/cluster_bubble.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/event_marker_icon.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/hazard_layer.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/pin_palette.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/poi_layer.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/self_marker_layer.dart';

/// 事件 marker 視覺尺寸/icon/tooltip 的對照（由父層提供 i18n 字串）。
class EventMarkerStyle {
  const EventMarkerStyle({
    required this.icon,
    required this.size,
    required this.tooltip,
  });
  final IconData icon;
  final double size;
  final String tooltip;
}

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.controller,
    required this.eventStyleFor,
    required this.hazardIconFor,
    required this.onHazardTap,
    required this.onEventTap,
    required this.onPoiTap,
    required this.onMapTap,
    required this.onMapLongPress,
  });

  final MapScreenController controller;

  /// 父層依 EventVm 提供 i18n tooltip + Icon + size。
  final EventMarkerStyle Function(EventVm vm) eventStyleFor;

  /// 父層提供 hazard 種類 → Icon 的對應（`PinPalette.hazardIcon` 即可，封裝在父層
  /// 是為了讓 hazard_layer 完全與 i18n 解耦）。
  final IconData Function(String type) hazardIconFor;

  final void Function(HazardVm) onHazardTap;
  final void Function(EventVm) onEventTap;
  final void Function(PoiVm) onPoiTap;

  /// 點擊地圖空白處（非 marker）。父層用來：marking 模式下移動 center；
  /// 否則查 nearest POI 並開 sheet。
  final void Function(TapPosition tapPosition, LatLng latlng) onMapTap;

  /// 長按進入 marking 模式。
  final void Function(TapPosition tapPosition, LatLng latlng) onMapLongPress;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  /// flutter_map 的 MapController（與 MapScreenController 不同）。
  final MapController _flutterMapController = MapController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.controller.centerRequest.addListener(_onCenterRequest);
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.centerRequest.removeListener(_onCenterRequest);
      widget.controller.centerRequest.addListener(_onCenterRequest);
    }
  }

  @override
  void dispose() {
    widget.controller.centerRequest.removeListener(_onCenterRequest);
    super.dispose();
  }

  void _onCenterRequest() {
    final request = widget.controller.centerRequest.value;
    if (request == null) return;
    if (!_ready || !mounted) {
      // 還沒 ready，延後到 ready 後再取 value 跑 move。避免在 map 未掛載前
      // 操作 camera（已知 timing 風險）。
      return;
    }
    // 即使 onMapReady 已 fire，flutter_map 7.0.2 內部 controller state 仍可能在
    // 「same-frame」未連上：camera / move 會丟
    //   "You need to have the FlutterMap widget rendered at least once before
    //    using the MapController."
    // 所以延後到下一個 post-frame 再操作；同時 try/catch 容忍極端 race。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ready) return;
      try {
        final zoom = request.zoom ?? _flutterMapController.camera.zoom;
        if (request.resetRotation) {
          _flutterMapController.moveAndRotate(request.location, zoom, 0.0);
        } else {
          _flutterMapController.move(request.location, zoom);
        }
      } catch (e) {
        // 安全網：偶發在熱重啟 / 快速 dispose / 還沒首次 layout 完成。
        debugPrint('[MapView] moveAndRotate skipped: $e');
        return;
      }
      // 消費掉，避免重複觸發
      if (widget.controller.centerRequest.value == request) {
        widget.controller.centerRequest.value = null;
      }
    });
  }

  void _reportViewport({bool hasGesture = false}) {
    if (!mounted) return;
    try {
      final cam = _flutterMapController.camera;
      widget.controller.setViewport(
        zoom: cam.zoom,
        bounds: cam.visibleBounds,
        ready: _ready,
        hasGesture: hasGesture,
      );
    } catch (e) {
      // controller 還沒 attach（onMapReady 之前極小 race）— 這次 viewport 略過，
      // 等下一次 onPositionChanged / postFrame 自然補上。
      debugPrint('[MapView] viewport read skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (ctx, _) {
        final mb = c.mbTilesState;
        final selfTuple = SelfMarkerLayer.build(c.selfLocation);
        final selfMarkers = selfTuple.$1;
        final accuracyCircles = selfTuple.$2;
        final (hazardPolygons, hazardCenterMarkers) = HazardOverlay.build(
          hazards: c.hazards,
          iconFor: widget.hazardIconFor,
          onTap: widget.onHazardTap,
        );
        // Phase 2：POI 不再在外層 ListenableBuilder 內計算；下面 children 用
        // ValueListenableBuilder 訂閱 c.poiNotifier 各自重建。
        final eventMarkers = <Marker>[];
        final eventCategoryByMarker = <Marker, PinCategory>{};
        for (final e in c.events) {
          final style = widget.eventStyleFor(e);
          final marker = Marker(
            point: e.latLng,
            width: style.size + 4,
            height: style.size + 4,
            child: GestureDetector(
              onTap: () => widget.onEventTap(e),
              child: EventMarkerIcon(
                icon: style.icon,
                color: PinPalette.color(e.category),
                size: style.size,
                tooltip: style.tooltip,
                isSOS: e.urgency >= 2,
              ),
            ),
          );
          eventMarkers.add(marker);
          eventCategoryByMarker[marker] = e.category;
        }

        final marking = c.marking;
        final previewPolygons = <Polygon>[];
        final previewMarkers = <Marker>[];
        if (marking.isActive && marking.center != null) {
          final previewColor = PinPalette.color(PinCategory.hazard);
          previewPolygons.add(Polygon(
            points: HazardOverlay.circlePoints(
              marking.center!.latitude,
              marking.center!.longitude,
              marking.radiusMeters,
            ),
            color: previewColor.withValues(alpha: 0.18),
            borderColor: previewColor,
            borderStrokeWidth: 2.5,
            pattern: const StrokePattern.dotted(),
          ));
          previewMarkers.add(Marker(
            point: marking.center!,
            width: 40,
            height: 40,
            child:
                const Icon(Icons.location_on, color: Colors.white, size: 36),
          ));
        }

        return FlutterMap(
          mapController: _flutterMapController,
          options: MapOptions(
            initialCenter: c.selfLocation?.location ??
                const LatLng(23.97, 120.97),
            initialZoom: 15.0,
            minZoom: 6.0,
            maxZoom: 18.0,
            onMapReady: () {
              _ready = true;
              // 推遲一格，確保 FlutterMap 已經完成首次 layout / build。
              // flutter_map 7.0.2 在 onMapReady 同步呼叫 camera / move 的時序仍然
              // 偏緊，曾觀察到 MapController 內部 _state 還沒接上而 throw。
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _reportViewport(hasGesture: false);
                _onCenterRequest();
              });
            },
            onTap: widget.onMapTap,
            onLongPress: widget.onMapLongPress,
            onPositionChanged: (pos, hasGesture) {
              _reportViewport(hasGesture: hasGesture);
            },
          ),
          children: [
            if (mb.available && c.tileProviders != null && c.mapTheme != null)
              VectorTileLayer(
                key: ValueKey('vt_${mb.themeGeneration}'),
                tileProviders: c.tileProviders!,
                theme: c.mapTheme!,
                sprites: null,
                layerMode: VectorTileLayerMode.raster,
              ),
            // Phase 2：POI layer 由獨立 notifier 驅動。POI 更新只 rebuild 本層，
            // 不會觸發外層 ListenableBuilder 重建 VectorTileLayer / hazard / event /
            // self / marking。空 list 仍回 MarkerLayer(markers: const [])，
            // flutter_map 7.0.2 children 不接受非 layer widget。
            ValueListenableBuilder<List<PoiVm>>(
              valueListenable: c.poiNotifier,
              builder: (_, pois, __) {
                final markers = PoiOverlay.build(
                  pois: pois,
                  onTap: widget.onPoiTap,
                );
                return RepaintBoundary(
                  child: MarkerLayer(markers: markers),
                );
              },
            ),
            if (accuracyCircles.isNotEmpty)
              RepaintBoundary(
                child: CircleLayer(circles: accuracyCircles),
              ),
            if (hazardPolygons.isNotEmpty)
              RepaintBoundary(
                child: PolygonLayer(polygons: hazardPolygons),
              ),
            if (previewPolygons.isNotEmpty)
              PolygonLayer(polygons: previewPolygons),
            if (hazardCenterMarkers.isNotEmpty)
              RepaintBoundary(
                child: MarkerLayer(markers: hazardCenterMarkers),
              ),
            if (previewMarkers.isNotEmpty)
              MarkerLayer(markers: previewMarkers),
            if (eventMarkers.isNotEmpty)
              RepaintBoundary(
                child: MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 60,
                    size: const Size(44, 44),
                    alignment: Alignment.center,
                    spiderfyCluster: false,
                    zoomToBoundsOnClick: true,
                    padding: const EdgeInsets.all(32),
                    markers: eventMarkers,
                    polygonOptions: const PolygonOptions(
                      color: Color(0x22E8803B),
                      borderColor: Color(0x55E8803B),
                      borderStrokeWidth: 1,
                    ),
                    builder: (ctx, markers) {
                      PinCategory top = PinCategory.life;
                      int topPri = PinPalette.clusterPriority(top);
                      for (final m in markers) {
                        final cat = eventCategoryByMarker[m];
                        if (cat == null) continue;
                        final pri = PinPalette.clusterPriority(cat);
                        if (pri < topPri) {
                          topPri = pri;
                          top = cat;
                        }
                      }
                      return ClusterBubble(
                        count: markers.length,
                        highestPriority: top,
                      );
                    },
                  ),
                ),
              ),
            if (selfMarkers.isNotEmpty)
              RepaintBoundary(
                child: MarkerLayer(markers: selfMarkers),
              ),
          ],
        );
      },
    );
  }
}
