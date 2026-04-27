// poi_layer.dart
//
// Stage 7-r2：純呈現的救災 POI 圓點層。
//
// 責任：吃 `List<PoiVm>`，產出 `MarkerLayer`，tap 時把 VM 往上送。
// 不查 DB / 圖磚、不做 i18n。

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:ignirelay_app/ui/screens/map/models/map_view_models.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/poi_category.dart';

class PoiOverlay {
  PoiOverlay._();

  static List<Marker> build({
    required List<PoiVm> pois,
    required void Function(PoiVm) onTap,
  }) {
    final markers = <Marker>[];
    for (final p in pois) {
      final color = PoiCategories.color(p.classKey, p.subclassKey);
      final icon = PoiCategories.icon(p.classKey, p.subclassKey);
      markers.add(Marker(
        point: p.latLng,
        width: 24,
        height: 24,
        child: GestureDetector(
          onTap: () => onTap(p),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 1)),
              ],
            ),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
        ),
      ));
    }
    return markers;
  }
}
