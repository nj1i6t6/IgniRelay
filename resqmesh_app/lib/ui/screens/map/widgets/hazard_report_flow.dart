// hazard_report_flow.dart
//
// Stage 7-r2：危險標記發布流程容器。
//
// 責任：
//   - 持有 `TextEditingController _descCtrl`（依建議，TEC 不放進 controller）；
//   - 依 controller.marking 的 isActive 顯示 / 隱藏 MarkingPanel；
//   - 點 publish 時呼叫 controller.publishOrUpdateMark；
//   - 依 outcome 物件決定 UI side effect：snackbar / nearby dialog / cancel；
//   - 透過 GlobalKey 暴露 seedDescription 給父層在 edit 模式時注入既有描述。
//
// 不在此 widget：
//   - long press 進入 marking 模式（由 MapView onMapLongPress → map_screen → controller）；
//   - hazard info sheet 開啟（由 map_screen 處理）；
//   - 確認他人 hazard / 刪除自己 hazard（由 map_screen 內 sheet 流程）。

import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/screens/map/map_screen_controller.dart';
import 'package:ignirelay_app/ui/screens/map/models/map_action_results.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/hazard_nearby_dialog.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/marking_panel.dart';

class HazardReportFlow extends StatefulWidget {
  const HazardReportFlow({
    super.key,
    required this.controller,
    required this.hazardInfoBuilder,
  });

  final MapScreenController controller;

  /// (label, icon, color) — 由父層注入，避免在此 widget 引入 i18n + PinPalette
  /// 雙依賴。
  final (String, IconData, Color) Function(BuildContext, String) hazardInfoBuilder;

  @override
  State<HazardReportFlow> createState() => HazardReportFlowState();
}

class HazardReportFlowState extends State<HazardReportFlow> {
  final TextEditingController _descCtrl = TextEditingController();
  String? _lastEditingId;
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromController);
    _syncFromController();
  }

  @override
  void didUpdateWidget(covariant HazardReportFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromController);
      widget.controller.addListener(_syncFromController);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _descCtrl.dispose();
    super.dispose();
  }

  void _syncFromController() {
    final m = widget.controller.marking;
    // 退出 marking 模式 → 清描述
    if (_wasActive && !m.isActive) {
      _descCtrl.clear();
      _lastEditingId = null;
    }
    // 從新建切到編輯（或反之），讓父層透過 seedDescription 顯式塞值即可；
    // 這裡只追蹤 transition 旗標。
    if (m.editingHazardId != _lastEditingId) {
      _lastEditingId = m.editingHazardId;
    }
    _wasActive = m.isActive;
  }

  /// 由 map_screen 在 hazard info sheet 點 edit 後呼叫，把既有描述塞入 TEC。
  /// 對應 controller.enterMarkingEdit(...) 的回傳值。
  void seedDescription(String text) {
    _descCtrl.text = text;
  }

  Future<void> _onPublish() async {
    final outcome = await widget.controller
        .publishOrUpdateMark(description: _descCtrl.text);
    if (!mounted) return;
    await _handleOutcome(outcome);
  }

  Future<void> _handleOutcome(PublishHazardOutcome outcome) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    switch (outcome) {
      case PublishHazardPublished():
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.mapHazardPublishedSnack),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case PublishHazardUpdated():
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.mapHazardUpdatedSnack),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case PublishHazardConfirmedExisting(typeKey: final t):
        final (typeLabel, _, _) = widget.hazardInfoBuilder(context, t);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.mapHazardConfirmSnack(typeLabel, 1)),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case PublishHazardNearbyConflict(
          distanceMeters: final d,
          confirmCount: final c,
          typeKey: final t,
          nearbyId: final id
        ):
        final (typeLabel, _, _) = widget.hazardInfoBuilder(context, t);
        final action = await HazardNearbyDialog.show(
          context,
          distanceMeters: d,
          confirmCount: c,
          typeLabel: typeLabel,
        );
        if (!mounted) return;
        if (action == 'confirm') {
          final out2 = await widget.controller.publishOrUpdateMark(
            description: _descCtrl.text,
            confirmExistingId: id,
          );
          if (mounted) await _handleOutcome(out2);
        } else if (action == 'new') {
          final out2 = await widget.controller.publishOrUpdateMark(
            description: _descCtrl.text,
            skipNearbyCheck: true,
          );
          if (mounted) await _handleOutcome(out2);
        }
        // null（取消）→ 留在 marking 模式，使用者可繼續調整
        break;
      case PublishHazardFailure(errorMessage: final e):
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.mapMbtilesLoadFail(e)),
            backgroundColor: Colors.red,
          ),
        );
        break;
      case PublishHazardNoop():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (ctx, _) {
        final m = widget.controller.marking;
        if (!m.isActive) return const SizedBox.shrink();
        return MarkingPanel(
          isEditing: m.isEditing,
          markType: m.type,
          markSeverity: m.severity,
          markRadius: m.radiusMeters,
          descController: _descCtrl,
          isPublishing: m.isPublishing,
          onTypeChanged: widget.controller.updateMarkingType,
          onSeverityChanged: widget.controller.updateMarkingSeverity,
          onRadiusChanged: widget.controller.updateMarkingRadius,
          onCancel: widget.controller.exitMarking,
          onPublish: _onPublish,
          hazardInfoBuilder: widget.hazardInfoBuilder,
        );
      },
    );
  }
}
