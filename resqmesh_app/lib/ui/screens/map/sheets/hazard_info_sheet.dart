import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/generated/app_localizations.dart';

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
      backgroundColor: const Color(0xFF1a1a2e),
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
    final severity = (hazard['severity'] as int?) ?? 3;
    final radius = (hazard['radius'] as num?)?.toDouble() ?? 200.0;
    final confirmCount = (hazard['confirm_count'] as int?) ?? 1;
    final desc = hazard['description'] as String? ?? '';
    final createdAt = (hazard['created_at'] as int?) ?? 0;

    final l = S.of(context)!;

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

    // 可信度標籤
    String credLabel;
    Color credColor;
    if (confirmCount >= 5) {
      credLabel = l.mapCredibilityConfirmed;
      credColor = Colors.greenAccent;
    } else if (confirmCount >= 3) {
      credLabel = l.mapCredibilityCredible;
      credColor = Colors.lightGreen;
    } else if (confirmCount >= 2) {
      credLabel = l.mapCredibilityEndorsed;
      credColor = Colors.orange;
    } else {
      credLabel = l.mapCredibilityUnverified;
      credColor = Colors.white38;
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
                color: Colors.white24,
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
                  style: const TextStyle(
                      color: Colors.white,
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
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ...List.generate(
              5,
              (i) => Icon(
                Icons.circle,
                size: 12,
                color: i < severity
                    ? (severity >= 4 ? Colors.red : Colors.orange)
                    : Colors.white12,
              ),
            ),
            Text('  ($severity/5)',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          Text(l.mapHazardInfoRadius(radius.round()),
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(l.mapHazardInfoDesc(desc),
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          if (timeAgo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(l.mapHazardInfoTime(timeAgo),
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
          if (isMine)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline,
                      color: Colors.greenAccent[400], size: 14),
                  const SizedBox(width: 4),
                  Text(l.mapHazardInfoMine,
                      style: TextStyle(
                          color: Colors.greenAccent[400], fontSize: 12)),
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
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange)),
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
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red)),
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
                      backgroundColor: Colors.orange),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}
