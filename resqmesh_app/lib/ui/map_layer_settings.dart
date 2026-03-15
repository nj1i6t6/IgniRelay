import 'package:flutter/material.dart';

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
  static const poiCategories = [
    PoiCategory('resq_hospital', '醫院/診所', Icons.local_hospital, Colors.red),
    PoiCategory('resq_pharmacy', '藥局', Icons.local_pharmacy, Colors.purple),
    PoiCategory('resq_police', '警消單位', Icons.local_police, Color(0xFF3366ff)),
    PoiCategory('resq_school', '學校（避難所）', Icons.school, Colors.orange),
    PoiCategory('resq_grocery', '超市/商店', Icons.store, Colors.green),
  ];

  static const credibilityLevels = [
    (label: '全部顯示', desc: '包含未驗證', min: 1),
    (label: '2 人以上', desc: '有人附議', min: 2),
    (label: '3 人以上', desc: '多人回報', min: 3),
    (label: '確信 (5+)', desc: '高度可信', min: 5),
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
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Row(
            children: [
              Icon(Icons.layers, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('圖層控制',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),

          // ═══════════ POI 區段 ═══════════
          _sectionHeader(
            '地點圖標',
            Icons.place,
            s.showPoi,
            (v) => setState(() => s.showPoi = v),
          ),
          if (s.showPoi) ...[
            const SizedBox(height: 4),
            ...MapLayerSettings.poiCategories.map((cat) => _poiToggle(cat, s)),
          ],
          const Divider(color: Colors.white12, height: 24),

          // ═══════════ 危險區域區段 ═══════════
          _sectionHeader(
            '危險區域',
            Icons.warning_amber,
            s.showHazards,
            (v) => setState(() => s.showHazards = v),
          ),
          if (s.showHazards) ...[
            const SizedBox(height: 4),
            _subToggle(
              '顯示他人回報',
              s.showOtherHazards,
              (v) => setState(() => s.showOtherHazards = v),
            ),
            if (s.showOtherHazards) ...[
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 20),
                child: Text('最低可信度',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: MapLayerSettings.credibilityLevels.map((level) {
                    final selected = s.minConfirmCount == level.min;
                    return ChoiceChip(
                      label: Text(level.label),
                      selected: selected,
                      selectedColor: Colors.orange.withValues(alpha: 0.3),
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: selected ? Colors.orange : Colors.white70,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: selected ? Colors.orange : Colors.white24,
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

  Widget _sectionHeader(
      String title, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.greenAccent,
        ),
      ],
    );
  }

  Widget _subToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.greenAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _poiToggle(PoiCategory cat, MapLayerSettings s) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: [
          Icon(cat.icon, color: cat.color, size: 18),
          const SizedBox(width: 8),
          Text(cat.label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Switch(
            value: s.poiIsEnabled(cat.id),
            onChanged: (v) => setState(() => s.setPoiEnabled(cat.id, v)),
            activeColor: cat.color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
