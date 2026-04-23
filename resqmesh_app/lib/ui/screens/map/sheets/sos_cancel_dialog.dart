import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/generated/app_localizations.dart';

/// Stage 4d Round 2：取消 SOS 求救確認對話框。
///
/// 原位：`map_screen.dart` 原 `_cancelSos` 開頭的 `AlertDialog`
/// （L1628-1647）。只負責使用者意願確認；後續的 `_eventManager.publishEvent`
/// 與 `setState` 回寫留在 caller。
class SosCancelDialog {
  SosCancelDialog._();

  /// 顯示「取消 SOS 嗎？」對話框。使用者選「是」回 true，否則 false。
  static Future<bool> show(BuildContext context) async {
    final l = S.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(l.mapCancelSosTitle,
            style: const TextStyle(color: Colors.white)),
        content: Text(
          l.mapCancelSosContent,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.mapCancelSosBack),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.mapCancelSosConfirm,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result == true;
  }
}
