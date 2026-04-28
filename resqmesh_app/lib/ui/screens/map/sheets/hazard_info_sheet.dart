import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// Stage 4d Round 2：危險標記詳情 BottomSheet。
///
/// 原位：`map_screen.dart` 原 `_showHazardInfo`（L1166-1356）。由 caller 傳入
/// 危險資訊與 `isMine`、`typeLabel`、`typeIcon`、`typeColor`（後三者來自
/// `_hazardInfo` / `PinPalette`）；按鈕事件以 callback 外送。
///
/// 原版於「這是我的」提示行使用 `[U+1F464]` emoji，違反 plan §六 L310，
/// 本輪改用 `Icons.person_outline`。
///
/// 使用：`HazardInfoSheet.show(context, ...)`。
class HazardInfoSheet {
  HazardInfoSheet._();

  static void show(
    BuildContext context, {
    required Map<String, dynamic> hazard,
    required String typeLabel,
    required IconData typeIcon,
    required Color typeColor,
    required bool isMine,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required Future<void> Function() onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.igni.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _HazardInfoSheetBody(
        hazard: hazard,
        typeLabel: typeLabel,
        typeIcon: typeIcon,
        typeColor: typeColor,
        isMine: isMine,
        onEdit: onEdit,
        onDelete: onDelete,
        onConfirm: onConfirm,
      ),
    );
  }
}

class _HazardInfoSheetBody extends StatelessWidget {
  const _HazardInfoSheetBody({
    required this.hazard,
    required this.typeLabel,
    required this.typeIcon,
    required this.typeColor,
    required this.isMine,
    required this.onEdit,
    required this.onDelete,
    required this.onConfirm,
  });

  final Map<String, dynamic> hazard;
  final String typeLabel;
  final IconData typeIcon;
  final Color typeColor;
  final bool isMine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final severity = (hazard['severity'] as int?) ?? 3;
    final radius = (hazard['radius'] as num?)?.toDouble() ?? 200.0;
    final confirmCount = (hazard['confirm_count'] as int?) ?? 1;
    final desc = hazard['description'] as String? ?? '';
    final createdAt = (hazard['created_at'] as int?) ?? 0;

    final l = context.l10n;

    // 時間顯示
    String timeAgo = '';
    if (createdAt > 0) {
      final diff = DateTime.now().millisecondsSinceEpoch - createdAt;
      final mins = diff ~/ 60000;
      if (mins < 60) {
        timeAgo = l.mapTimeAgoMinutes(mins);
      } else if (mins < 1440) {
        timeAgo = l.mapTimeAgoHours(mins ~/ 60);
      } else {
        timeAgo = l.mapTimeAgoDays(mins ~/ 1440);
      }
    }

    // 可信度標籤（用 palette 的 ok / warn / text3 對應，淺/深色都可讀）
    String credLabel;
    Color credColor;
    if (confirmCount >= 5) {
      credLabel = l.mapCredibilityConfirmed;
      credColor = p.ok;
    } else if (confirmCount >= 3) {
      credLabel = l.mapCredibilityCredible;
      credColor = p.ok;
    } else if (confirmCount >= 2) {
      credLabel = l.mapCredibilityEndorsed;
      credColor = p.warn;
    } else {
      credLabel = l.mapCredibilityUnverified;
      credColor = p.text3;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: p.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 標題行
          Row(children: [
            Icon(typeIcon, color: typeColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(typeLabel,
                  style: TextStyle(
                      color: p.text0,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: credColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: credColor, width: 1),
              ),
              child: Text('$credLabel ×$confirmCount',
                  style: TextStyle(color: credColor, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 12),
          // 嚴重度條
          Row(children: [
            Text('${l.mapHazardInfoSeverity}  ',
                style: TextStyle(color: p.text2, fontSize: 13)),
            ...List.generate(
              5,
              (i) => Icon(
                Icons.circle,
                size: 12,
                color: i < severity
                    ? (severity >= 4 ? p.sos : p.warn)
                    : p.border2,
              ),
            ),
            Text('  ($severity/5)',
                style: TextStyle(color: p.text3, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          Text(l.mapHazardInfoRadius(radius.round()),
              style: TextStyle(color: p.text2, fontSize: 13)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(l.mapHazardInfoDesc(desc),
                style: TextStyle(color: p.text1, fontSize: 13)),
          ],
          if (timeAgo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(l.mapHazardInfoTime(timeAgo),
                style: TextStyle(color: p.text3, fontSize: 12)),
          ],
          if (isMine)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, color: p.ok, size: 14),
                  const SizedBox(width: 4),
                  Text(l.mapHazardInfoMine,
                      style: TextStyle(color: p.ok, fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // 操作按鈕
          Row(children: [
            if (isMine) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(l.mapHazardInfoEditButton),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: p.brand,
                      side: BorderSide(color: p.brand)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                  icon: const Icon(Icons.delete, size: 16),
                  label: Text(l.mapHazardDeleteConfirm),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: p.sos,
                      side: BorderSide(color: p.sos)),
                ),
              ),
            ] else ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await onConfirm();
                  },
                  icon: const Icon(Icons.check,
                      color: Colors.white, size: 18),
                  label: Text(l.mapHazardInfoConfirmButton,
                      style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: p.brand,
                      foregroundColor: Colors.white),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}
