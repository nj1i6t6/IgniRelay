import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// Stage 4d Round 2：地圖底圖載入中的全螢幕佔位。
///
/// 原位：`map_screen.dart` 原 `_buildLoadingScreen`（L2152-2172）。純顯示，
/// 不依賴任何 state / callback。
class MapLoadingScreen extends StatelessWidget {
  const MapLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      color: const Color(0xFFF2EFE9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(l.mapLoading,
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text(
              l.mapLoadingNote,
              style: const TextStyle(color: Colors.black38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
