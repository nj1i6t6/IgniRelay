import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// Stage 4d Round 2：標記模式的底部面板。
///
/// 原位：`map_screen.dart` 原 `_buildMarkingPanel`（L1972-2150）。
/// 所有狀態由 caller 擁有，widget 純粹 layout + 透過 callback 回寫；
/// 這樣 `_MapScreenState.setState` 仍為單一 source of truth，不需要引入
/// 新狀態管理（Stage 7 若抽 `MapController` 再一併搬）。
///
/// `hazardInfoBuilder` 由 caller 提供（`_hazardInfo`），負責把 hazard type
/// string 轉成 (label, icon, color) 三元組；這樣本 widget 不需要知道
/// `PinPalette` 的存在。
class MarkingPanel extends StatelessWidget {
  const MarkingPanel({
    super.key,
    required this.isEditing,
    required this.markType,
    required this.markSeverity,
    required this.markRadius,
    required this.descController,
    required this.isPublishing,
    required this.onTypeChanged,
    required this.onSeverityChanged,
    required this.onRadiusChanged,
    required this.onCancel,
    required this.onPublish,
    required this.hazardInfoBuilder,
  });

  final bool isEditing;
  final String markType;
  final double markSeverity;
  final double markRadius;
  final TextEditingController descController;
  final bool isPublishing;

  final ValueChanged<String> onTypeChanged;
  final ValueChanged<double> onSeverityChanged;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onCancel;
  final VoidCallback onPublish;

  /// 把 hazard type 轉成 (label, icon, color) 三元組。
  final (String, IconData, Color) Function(BuildContext, String)
      hazardInfoBuilder;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (_, _, typeColor) = hazardInfoBuilder(context, markType);
    const types = [
      'ROADBLOCK',
      'FIRE',
      'CHEMICAL',
      'FLOOD',
      'BUILDING',
      'LANDSLIDE',
    ];
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: context.igni.bg2.withValues(alpha: 0.97),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題 + 取消
            Row(children: [
              const Icon(Icons.warning_amber,
                  color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text(
                isEditing
                    ? l.mapMarkingEditTitle
                    : l.mapMarkingNewTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.close, color: Colors.white38),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            Text(l.mapMarkingTapHint,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 10),

            // 危險類型選擇
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: types.map((key) {
                  final (label, icon, color) =
                      hazardInfoBuilder(context, key);
                  final selected = markType == key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(icon, color: color, size: 16),
                      label: Text(label),
                      selected: selected,
                      selectedColor: color.withValues(alpha: 0.3),
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: selected ? color : Colors.white70,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                          color: selected ? color : Colors.white24),
                      onSelected: (_) => onTypeChanged(key),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // 嚴重程度
            Row(children: [
              Text(l.mapMarkingSeverityLabel,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: markSeverity,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: typeColor,
                  inactiveColor: Colors.white12,
                  label: '${markSeverity.round()}',
                  onChanged: onSeverityChanged,
                ),
              ),
              Text('${markSeverity.round()}/5',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),

            // 影響半徑
            Row(children: [
              Text(l.mapMarkingRadiusLabel,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: markRadius,
                  min: 50,
                  max: 2000,
                  divisions: 39,
                  activeColor: Colors.orange,
                  inactiveColor: Colors.white12,
                  label: '${markRadius.round()}m',
                  onChanged: onRadiusChanged,
                ),
              ),
              Text('${markRadius.round()}m',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),

            // 描述
            SizedBox(
              height: 40,
              child: TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: l.mapMarkingDescHint,
                  hintStyle: const TextStyle(
                      color: Colors.white24, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 發布按鈕
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: isPublishing ? null : onPublish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: isPublishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(
                        isEditing ? Icons.save : Icons.cell_tower,
                        color: Colors.white,
                        size: 20),
                label: Text(
                  isEditing
                      ? l.mapMarkingUpdateButton
                      : l.mapMarkingPublishButton,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
