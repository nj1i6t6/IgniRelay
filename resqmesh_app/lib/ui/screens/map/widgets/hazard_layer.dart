// hazard_layer.dart
//
// Stage 7-r2：純呈現的危險區域圖層。
//
// 責任：吃 `List<HazardVm>`，吐出 (PolygonLayer + MarkerLayer) 與 onTap callback。
// 不查 DB、不碰 service、不做 i18n。tap 時把 VM 往上送。

import 'dart:math' as m;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:ignirelay_app/ui/screens/map/models/map_view_models.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/pin_palette.dart';

class HazardOverlay {
  HazardOverlay._();

  /// 產生 (Polygons, CenterMarkers) 給 FlutterMap children 使用。
  /// onTap 回 VM 給呼叫端開 sheet。
  static (List<Polygon>, List<Marker>) build({
    required List<HazardVm> hazards,
    required IconData Function(String type) iconFor,
    required void Function(HazardVm) onTap,
  }) {
    final polygons = <Polygon>[];
    final markers = <Marker>[];
    for (final h in hazards) {
      // 多邊形底色：按 type + severity 分色
      Color polygonColor;
      switch (h.type) {
        case 'FIRE':
          polygonColor = Colors.red;
          break;
        case 'FLOOD':
          polygonColor = Colors.blue;
          break;
        case 'CHEMICAL':
          polygonColor = Colors.yellow;
          break;
        case 'BUILDING':
          polygonColor = Colors.brown;
          break;
        case 'LANDSLIDE':
          polygonColor = Colors.grey;
          break;
        default:
          polygonColor = Colors.orange;
      }
      if (h.severity >= 4) polygonColor = Colors.red;

      polygons.add(Polygon(
        points: _circlePolygonPoints(h.lat, h.lng, h.radiusMeters),
        color: polygonColor.withValues(
            alpha: h.confirmCount >= 2 ? 0.25 : 0.12),
        borderColor: polygonColor,
        borderStrokeWidth: h.confirmCount >= 3 ? 3.0 : 2.0,
        pattern: h.confirmCount < 2
            ? const StrokePattern.dotted()
            : const StrokePattern.solid(),
      ));

      // 中心 marker：大類一色紅（PinCategory.hazard），icon 為次分類
      final markerColor = PinPalette.color(PinCategory.hazard);
      final typeIcon = iconFor(h.type);
      markers.add(Marker(
        point: h.latLng,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => onTap(h),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: markerColor.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: h.isMine ? Colors.greenAccent : Colors.white,
                    width: h.isMine ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: markerColor.withValues(alpha: 0.5),
                        blurRadius: 6),
                  ],
                ),
                child: Icon(typeIcon, color: Colors.white, size: 18),
              ),
              if (h.confirmCount > 1)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: Text(
                      '×${h.confirmCount}',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ));
    }
    return (polygons, markers);
  }

  /// 圓形多邊形頂點（36 邊近似圓）。
  static List<LatLng> _circlePolygonPoints(double lat, double lng,
      double radiusM, {int segments = 36}) {
    final latR = lat * m.pi / 180;
    final latDelta = radiusM / 111320.0;
    final lngDelta = radiusM / (111320.0 * m.cos(latR));
    return List.generate(segments, (i) {
      final a = 2 * m.pi * i / segments;
      return LatLng(lat + latDelta * m.sin(a), lng + lngDelta * m.cos(a));
    });
  }

  /// Stage 4d / r2 共用：marking 模式預覽用的圓形頂點（給 widget 直接呼）。
  static List<LatLng> circlePoints(double lat, double lng, double radiusM) =>
      _circlePolygonPoints(lat, lng, radiusM);
}
