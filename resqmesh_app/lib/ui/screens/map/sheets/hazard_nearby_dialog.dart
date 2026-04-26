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
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.igni.bg2,
        title: Row(children: [
          const Icon(Icons.people, color: Colors.orange),
          const SizedBox(width: 8),
          Text(l.mapMarkingNearbyExists,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Text(
          '距離 ${distanceMeters}m 處已有「$typeLabel」回報\n'
          '目前已有 $confirmCount 人確認\n\n'
          '你可以「確認」來增加可信度，\n或建立全新標記。',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'new'),
            child: Text(l.mapMarkingCreateNew,
                style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'confirm'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            icon: const Icon(Icons.check, color: Colors.white, size: 18),
            label: Text(l.mapMarkingConfirmReport,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
