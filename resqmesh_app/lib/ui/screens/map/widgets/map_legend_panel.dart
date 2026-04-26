import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// Stage 4d Round 2：地圖右上圖例面板。
///
/// 原位：`map_screen.dart` 原 `_buildLegendPanel` + `_legendItem`
/// （L2227-2302）。純顯示；原版本於標題用 `[U+1F6A8]` emoji，違反 plan
/// §六 L310，本輪改用 `Icons.warning_amber`。
class MapLegendPanel extends StatelessWidget {
  const MapLegendPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
          ],
        ),
        child: Builder(builder: (ctx) {
          final l = ctx.l10n;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber,
                      color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(l.mapLegendTitle,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              Text(l.mapLegendZoomHint,
                  style: const TextStyle(color: Colors.red, fontSize: 10)),
              const Divider(color: Colors.black12, height: 16),
              _LegendItem(color: Colors.red, label: l.mapLegendHospital),
              _LegendItem(
                  color: const Color(0xFF3366ff), label: l.mapLegendPolice),
              _LegendItem(color: Colors.orange, label: l.mapLegendSchool),
              _LegendItem(color: Colors.purple, label: l.mapLegendPharmacy),
              _LegendItem(color: Colors.green, label: l.mapLegendSupermarket),
              const Divider(color: Colors.black12, height: 16),
              Text(l.mapLegendMeshEvents,
                  style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
              _LegendItem(
                  color: Colors.red,
                  label: l.mapEventSosRed,
                  icon: Icons.sos),
              _LegendItem(
                  color: Colors.amber,
                  label: l.mapEventSosYellow,
                  icon: Icons.warning_amber),
              _LegendItem(
                  color: Colors.green,
                  label: l.mapEventSupply,
                  icon: Icons.inventory_2),
              _LegendItem(
                  color: Colors.cyan,
                  label: l.mapEventInfo,
                  icon: Icons.info_outline),
            ],
          );
        }),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.icon});

  final Color color;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon != null
              ? Icon(icon, color: color, size: 14)
              : Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26, width: 1),
                  ),
                ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.black87, fontSize: 12)),
        ],
      ),
    );
  }
}
