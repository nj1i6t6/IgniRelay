import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// Stage 4d Round 2：標記模式中，若附近已有同類型危險回報時的提示對話框。
///
/// 原位：`map_screen.dart` 原 `_publishOrUpdateMark` 內的
/// `showDialog<String>`（L1081-1112）。回傳三值之一：
///   - `'confirm'`：使用者選擇「確認既有回報」（增加 confirm_count）
///   - `'new'`：使用者選擇「建立全新標記」
///   - `null`：使用者按返回 / dismiss 視為取消
class HazardNearbyDialog {
  HazardNearbyDialog._();

  /// 顯示附近已有回報的提示。
  ///
  /// [typeLabel] 由 caller 以 `_hazardInfo` 轉完 i18n 再傳入。
  static Future<String?> show(
    BuildContext context, {
    required int distanceMeters,
    required int confirmCount,
    required String typeLabel,
  }) {
    final l = context.l10n;
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final p = ctx.igni;
        return AlertDialog(
          backgroundColor: p.bg1,
          title: Row(children: [
            Icon(Icons.people, color: p.warn),
            const SizedBox(width: 8),
            Text(l.mapMarkingNearbyExists,
                style: TextStyle(color: p.text0, fontSize: 16)),
          ]),
          content: Text(
            l.mapMarkingNearbyContent(distanceMeters, typeLabel, confirmCount),
            style: TextStyle(color: p.text1, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'new'),
              child: Text(l.mapMarkingCreateNew,
                  style: TextStyle(color: p.text2)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'confirm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.warn,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check, color: Colors.white, size: 18),
              label: Text(l.mapMarkingConfirmReport,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
