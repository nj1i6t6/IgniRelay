import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/generated/app_localizations.dart';

/// Stage 4d Round 2：刪除危險標記確認對話框。
///
/// 原位：`map_screen.dart` 原 `_deleteHazardConfirm` 內的 `AlertDialog`
/// （L1528-1561）。工廠式 `show()` 回 `Future<bool>`；實際刪除與
/// `_loadOverlays` 留在 caller。
class HazardDeleteDialog {
  HazardDeleteDialog._();

  /// 顯示刪除確認對話框。使用者按「確認刪除」回 true，否則 false。
  static Future<bool> show(BuildContext context) async {
    final l = S.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(l.mapHazardDeleteTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(l.mapHazardDeleteContent,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.mapHazardDeleteCancel,
                style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l.mapHazardDeleteConfirm,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result == true;
  }
}
