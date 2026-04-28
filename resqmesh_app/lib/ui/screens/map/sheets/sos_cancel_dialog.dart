import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// Stage 4d Round 2：取消 SOS 求救確認對話框。
///
/// 原位：`map_screen.dart` 原 `_cancelSos` 開頭的 `AlertDialog`
/// （L1628-1647）。只負責使用者意願確認；後續的 `_eventManager.publishEvent`
/// 與 `setState` 回寫留在 caller。
class SosCancelDialog {
  SosCancelDialog._();

  /// 顯示「取消 SOS 嗎？」對話框。使用者選「是」回 true，否則 false。
  static Future<bool> show(BuildContext context) async {
    final l = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = ctx.igni;
        return AlertDialog(
          backgroundColor: p.bg1,
          title: Text(l.mapCancelSosTitle,
              style: TextStyle(color: p.text0)),
          content: Text(
            l.mapCancelSosContent,
            style: TextStyle(color: p.text1),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.mapCancelSosBack),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.mapCancelSosConfirm,
                  style: TextStyle(color: p.sos)),
            ),
          ],
        );
      },
    );
    return result == true;
  }
}
