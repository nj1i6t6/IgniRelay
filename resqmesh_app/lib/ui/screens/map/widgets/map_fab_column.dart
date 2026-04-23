import 'package:flutter/material.dart';

import 'sos_button.dart';

/// Stage 4d：`MapScreen` 右下角的 FAB 欄。
///
/// 結構：
///   - 上：GPS 定位 small FAB
///   - 下：SOS long-press FAB（已送出態 → 取消型，未送出 → 需長按 1.5s）
///   - 最底與 tab bar 留 16pt 間距（plan §Stage 4d L224）
///
/// 由父層 `MapScreen` 透過 callback 取得 `_centerOnUser` / SOS triage 流程；
/// 本 widget 只負責排版與按鈕互動。
class MapFabColumn extends StatelessWidget {
  const MapFabColumn({
    super.key,
    required this.hasUserLocation,
    required this.onCenterOnUser,
    required this.activeSosEventId,
    required this.activeSosUrgency,
    required this.onSosHoldActivated,
    required this.onCancelSos,
    required this.sosLabel,
    required this.sosActiveLabel,
    required this.sosHoldHint,
  });

  final bool hasUserLocation;
  final VoidCallback onCenterOnUser;
  final String? activeSosEventId;
  final int activeSosUrgency;
  final VoidCallback onSosHoldActivated;
  final VoidCallback onCancelSos;
  final String sosLabel;
  final String sosActiveLabel;
  final String sosHoldHint;

  @override
  Widget build(BuildContext context) {
    // Scaffold 的 floatingActionButton 已自帶與 BottomNavigation 的標準間距，
    // 這裡額外補 4pt 使總間距接近 plan 規範的 16pt（預設約 12pt）。
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'gps',
            backgroundColor:
                hasUserLocation ? Colors.blueAccent : Colors.grey[700],
            onPressed: onCenterOnUser,
            child: Icon(
              hasUserLocation ? Icons.my_location : Icons.location_searching,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          SosLongPressButton(
            active: activeSosEventId != null,
            activeUrgencyHigh: activeSosUrgency >= 3,
            onActivated: onSosHoldActivated,
            onCancelActive: onCancelSos,
            label: sosLabel,
            activeLabel: sosActiveLabel,
            holdHint: sosHoldHint,
          ),
        ],
      ),
    );
  }
}
