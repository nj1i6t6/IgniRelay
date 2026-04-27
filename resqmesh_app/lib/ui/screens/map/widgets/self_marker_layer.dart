// self_marker_layer.dart
//
// Stage 7-r2：純呈現的自身位置 + 精度圈。
//
// 吃 `SelfLocationVm?`，產出 (Markers, CircleMarkers)。

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:ignirelay_app/ui/screens/map/models/map_view_models.dart';

class SelfMarkerLayer {
  SelfMarkerLayer._();

  static (List<Marker>, List<CircleMarker>) build(SelfLocationVm? self) {
    if (self == null) return (const [], const []);
    final markers = <Marker>[
      Marker(
        point: self.location,
        width: 26,
        height: 26,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ),
    ];
    final circles = <CircleMarker>[];
    if (self.accuracyMeters > 0) {
      circles.add(CircleMarker(
        point: self.location,
        radius: self.accuracyMeters,
        useRadiusInMeter: true,
        color: Colors.blue.withValues(alpha: 0.1),
        borderColor: Colors.blue.withValues(alpha: 0.3),
        borderStrokeWidth: 1,
      ));
    }
    return (markers, circles);
  }
}
