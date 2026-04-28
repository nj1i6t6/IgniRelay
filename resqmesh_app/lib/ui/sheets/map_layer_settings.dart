import 'package:flutter/material.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// POI 類別定義
// ─────────────────────────────────────────────────────────────────────────────

class PoiCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const PoiCategory(this.id, this.label, this.icon, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// 地圖圖層設定 (POI 顯示 + 危險區域篩選)
// ─────────────────────────────────────────────────────────────────────────────

class MapLayerSettings extends ChangeNotifier {
  // ── POI ──
  bool _showPoi = true;
  final Map<String, bool> _poiEnabled = {
    'resq_hospital': true,
    'resq_pharmacy': true,
    'resq_police': true,
    'resq_school': true,
    'resq_grocery': true,
  };

  bool get showPoi => _showPoi;
  set showPoi(bool v) {
    _showPoi = v;
    notifyListeners();
  }

  bool poiIsEnabled(String id) => _poiEnabled[id] ?? true;
  void setPoiEnabled(String id, bool v) {
    _poiEnabled[id] = v;
    notifyListeners();
  }

  /// 被關閉的 POI category IDs（用於 theme 重建）
  Set<String> get disabledPoiIds {
    if (!_showPoi) return _poiEnabled.keys.toSet(); // 全關
    return _poiEnabled.entries.where((e) => !e.value).map((e) => e.key).toSet();
  }

  // ── 危險區域 ──
  bool _showHazards = true;
  bool _showOtherHazards = true;
  int _minConfirmCount = 1;

  bool get showHazards => _showHazards;
  set showHazards(bool v) {
    _showHazards = v;
    notifyListeners();
  }

  bool get showOtherHazards => _showOtherHazards;
  set showOtherHazards(bool v) {
    _showOtherHazards = v;
    notifyListeners();
  }

  int get minConfirmCount => _minConfirmCount;
  set minConfirmCount(int v) {
    _minConfirmCount = v;
    notifyListeners();
  }

  // ── 常量 ──
  static List<PoiCategory> getPoiCategories(BuildContext context) => [
    PoiCategory('resq_hospital', context.l10n.mapLayerPoiHospital, Icons.local_hospital, Colors.red),
    PoiCategory('resq_pharmacy', context.l10n.mapLayerPoiPharmacy, Icons.local_pharmacy, Colors.purple),
    PoiCategory('resq_police', context.l10n.mapLayerPoiPolice, Icons.local_police, const Color(0xFF3366ff)),
    PoiCategory('resq_school', context.l10n.mapLayerPoiSchool, Icons.school, Colors.orange),
    PoiCategory('resq_grocery', context.l10n.mapLayerPoiSupermarket, Icons.store, Colors.green),
  ];

  static List<({String label, String desc, int min})> getCredibilityLevels(BuildContext context) => [
    (label: context.l10n.mapLayerCredAll, desc: context.l10n.mapLayerCredAllDesc, min: 1),
    (label: context.l10n.mapLayerCred2, desc: context.l10n.mapLayerCred2Desc, min: 2),
    (label: context.l10n.mapLayerCred3, desc: context.l10n.mapLayerCred3Desc, min: 3),
    (label: context.l10n.mapLayerCred5, desc: context.l10n.mapLayerCred5Desc, min: 5),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// 圖層控制面板（ModalBottomSheet）
// ─────────────────────────────────────────────────────────────────────────────

class MapLayerControlSheet extends StatefulWidget {
  final MapLayerSettings settings;
  const MapLayerControlSheet({super.key, required this.settings});

  @override
  State<MapLayerControlSheet> createState() => _MapLayerControlSheetState();
}

class _MapLayerControlSheetState extends State<MapLayerControlSheet> {
  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final p = context.igni;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 抓手 ──
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: p.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.layers, color: p.text0, size: 22),
              const SizedBox(width: 8),
              Text(context.l10n.mapLayerTitle,
                  style: TextStyle(
                      color: p.text0,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),

          // ═══════════ POI 區段 ═══════════
          _sectionHeader(
            context,
            context.l10n.mapLayerPoiSection,
            Icons.place,
            s.showPoi,
            (v) => setState(() => s.showPoi = v),
          ),
          if (s.showPoi) ...[
            const SizedBox(height: 4),
            ...MapLayerSettings.getPoiCategories(context).map((cat) => _poiToggle(context, cat, s)),
          ],
          Divider(color: p.border0, height: 24),

          // ═══════════ 危險區域區段 ═══════════
          _sectionHeader(
            context,
            context.l10n.mapLayerHazardSection,
            Icons.warning_amber,
            s.showHazards,
            (v) => setState(() => s.showHazards = v),
          ),
          if (s.showHazards) ...[
            const SizedBox(height: 4),
            _subToggle(
              context,
              context.l10n.mapLayerHazardShowOthers,
              s.showOtherHazards,
              (v) => setState(() => s.showOtherHazards = v),
            ),
            if (s.showOtherHazards) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(context.l10n.mapLayerHazardMinCredibility,
                    style: TextStyle(color: p.text2, fontSize: 12)),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: MapLayerSettings.getCredibilityLevels(context).map((level) {
                    final selected = s.minConfirmCount == level.min;
                    return ChoiceChip(
                      label: Text(level.label),
                      selected: selected,
                      selectedColor: p.brand.withValues(alpha: 0.25),
                      backgroundColor: p.bg3,
                      labelStyle: TextStyle(
                        color: selected ? p.brand : p.text1,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: selected ? p.brand : p.border1,
                      ),
                      onSelected: (_) {
                        setState(() => s.minConfirmCount = level.min);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext ctx, String title, IconData icon,
      bool value, ValueChanged<bool> onChanged) {
    final p = ctx.igni;
    return Row(
      children: [
        Icon(icon, color: p.text1, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                color: p.text0,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: p.ok,
        ),
      ],
    );
  }

  Widget _subToggle(BuildContext ctx, String label, bool value,
      ValueChanged<bool> onChanged) {
    final p = ctx.igni;
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(color: p.text1, fontSize: 13)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: p.ok,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _poiToggle(BuildContext ctx, PoiCategory cat, MapLayerSettings s) {
    final p = ctx.igni;
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Icon(cat.icon, color: cat.color, size: 18),
          const SizedBox(width: 8),
          Text(cat.label,
              style: TextStyle(color: p.text1, fontSize: 13)),
          const Spacer(),
          Switch(
            value: s.poiIsEnabled(cat.id),
            onChanged: (v) => setState(() => s.setPoiEnabled(cat.id, v)),
            activeThumbColor: cat.color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
