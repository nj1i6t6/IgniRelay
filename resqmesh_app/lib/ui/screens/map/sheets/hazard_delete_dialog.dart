import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// Stage 4d Round 2：刪除危險標記確認對話框。
///
/// 原位：`map_screen.dart` 原 `_deleteHazardConfirm` 內的 `AlertDialog`
/// （L1528-1561）。工廠式 `show()` 回 `Future<bool>`；實際刪除與
/// `_loadOverlays` 留在 caller。
class HazardDeleteDialog {
  HazardDeleteDialog._();

  /// 顯示刪除確認對話框。使用者按「確認刪除」回 true，否則 false。
  static Future<bool> show(BuildContext context) async {
    final l = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = ctx.igni;
        return AlertDialog(
          backgroundColor: p.bg1,
          title: Text(l.mapHazardDeleteTitle,
              style: TextStyle(color: p.text0, fontSize: 16)),
          content: Text(l.mapHazardDeleteContent,
              style: TextStyle(color: p.text1, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.mapHazardDeleteCancel,
                  style: TextStyle(color: p.text2)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: p.sos, foregroundColor: Colors.white),
              child: Text(l.mapHazardDeleteConfirm,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    return result == true;
  }
}
