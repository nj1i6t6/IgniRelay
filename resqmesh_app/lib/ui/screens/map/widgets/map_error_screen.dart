import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// Stage 4d Round 2：MBTiles 載入失敗時的全螢幕錯誤畫面。
///
/// 原位：`map_screen.dart` 原 `_buildErrorScreen`（L2174-2225）。外部傳入
/// 錯誤鍵與參數，以及 `onRetry` callback；retry 時的 setState + _initMBTiles
/// 留在 `_MapScreenState`，widget 本身無狀態。
class MapErrorScreen extends StatelessWidget {
  const MapErrorScreen({
    super.key,
    required this.errorKey,
    required this.errorArg,
    required this.onRetry,
  });

  /// ARB key：'mapMbtilesNotFound' | 'mapMbtilesLoadFail' | null
  final String? errorKey;

  /// 對應 mapMbtilesLoadFail 的動態參數。
  final String? errorArg;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String errorMsg;
    if (errorKey == 'mapMbtilesLoadFail') {
      errorMsg = l.mapMbtilesLoadFail(errorArg ?? '');
    } else if (errorKey == 'mapMbtilesNotFound') {
      errorMsg = l.mapMbtilesNotFound;
    } else {
      errorMsg = l.mapErrorUnknown;
    }
    return Container(
      color: const Color(0xFFF2EFE9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, color: Colors.black26, size: 64),
            const SizedBox(height: 16),
            Text(l.mapErrorTitle,
                style: const TextStyle(color: Colors.black54, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              errorMsg,
              style: const TextStyle(color: Colors.black38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              l.mapErrorAssetNote,
              style: const TextStyle(color: Colors.black26, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(l.mapRetryButton,
                  style: const TextStyle(color: Colors.white)),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}
