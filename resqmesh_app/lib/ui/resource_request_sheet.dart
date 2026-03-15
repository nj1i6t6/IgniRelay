import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../mesh/event_manager.dart';
import '../mesh/geo_context_resolver.dart';
import 'supply_category_data.dart';

/// 物資需求發佈頁面（全頁 Scaffold，與供給登記頁面統一風格）
class ResourceRequestScreen extends StatefulWidget {
  const ResourceRequestScreen({super.key});

  @override
  State<ResourceRequestScreen> createState() => _ResourceRequestScreenState();
}

class _ResourceRequestScreenState extends State<ResourceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();
  final _eventManager = EventManager();
  final _geoResolver = GeoContextResolver();

  // ── 多層級物資分類 ──
  SupplyCategory? _selectedCategory;
  SupplySubCategory? _selectedSubCategory;
  String? _selectedItem;
  double _maxRange = 1000.0;
  bool _publishing = false;

  // ── 行動模式 ──
  String _mobilityMode = 'CAN_GO'; // 'CAN_GO' or 'NEED_DELIVER'

  @override
  void initState() {
    super.initState();
    _selectedCategory = supplyCategories.first;
    _selectedSubCategory = _selectedCategory!.subCategories.first;
    _loadGeoContext();
  }

  Future<void> _loadGeoContext() async {
    final ctx = await _geoResolver.resolveContext(25.045, 121.543);
    setState(() {
      _maxRange = (ctx['suggested_range_meters'] as double?) ?? 1000.0;
    });
  }

  String get _fullResourceType {
    final parts = <String>[
      _selectedCategory?.code ?? 'WATER',
    ];
    if (_selectedSubCategory != null) {
      parts.add(_selectedSubCategory!.code);
    }
    if (_selectedItem != null) {
      parts.add(_selectedItem!);
    }
    return parts.join('/');
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _publishing = true);

    try {
      await _eventManager.publishRequest(
        resourceType: _fullResourceType,
        quantity: int.parse(_quantityCtrl.text),
        note: _descCtrl.text.trim(),
        maxRangeMeters: _maxRange,
        mobilityMode: _mobilityMode,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('需求已廣播至 Mesh 網路！'),
            backgroundColor: Colors.green[700],
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on RateLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: Colors.orange[700]),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發布失敗: $e'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: const Text('發佈物資需求', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── 第一層：物資大類 ──
            const Text('需要什麼物資？',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: supplyCategories.map((cat) {
                final selected = _selectedCategory?.code == cat.code;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = cat;
                    _selectedSubCategory = cat.subCategories.first;
                    _selectedItem = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? cat.color.withValues(alpha: 0.3)
                          : const Color(0xFF1a1a2e),
                      border: Border.all(
                          color: selected ? cat.color : Colors.white24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon,
                            color: selected ? cat.color : Colors.white54,
                            size: 18),
                        const SizedBox(width: 6),
                        Text(cat.label,
                            style: TextStyle(
                              color: selected ? cat.color : Colors.white54,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── 第二層：子類別 ──
            if (_selectedCategory != null) ...[
              Text('${_selectedCategory!.label} → 子類別',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedCategory!.subCategories.map((sub) {
                  final selected = _selectedSubCategory?.code == sub.code;
                  return ChoiceChip(
                    label: Text(sub.label),
                    selected: selected,
                    selectedColor:
                        _selectedCategory!.color.withValues(alpha: 0.3),
                    backgroundColor: const Color(0xFF1a1a2e),
                    labelStyle: TextStyle(
                      color:
                          selected ? _selectedCategory!.color : Colors.white54,
                    ),
                    side: BorderSide(
                      color:
                          selected ? _selectedCategory!.color : Colors.white24,
                    ),
                    onSelected: (_) => setState(() {
                      _selectedSubCategory = sub;
                      _selectedItem = null;
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── 第三層：具體品項 ──
            if (_selectedSubCategory != null &&
                _selectedSubCategory!.items.isNotEmpty) ...[
              const Text('具體品項 (可選)',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedSubCategory!.items.map((item) {
                  final selected = _selectedItem == item.code;
                  return FilterChip(
                    label: Text(item.label,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white54,
                          fontSize: 12,
                        )),
                    selected: selected,
                    selectedColor:
                        _selectedCategory!.color.withValues(alpha: 0.4),
                    backgroundColor: const Color(0xFF222244),
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color:
                          selected ? _selectedCategory!.color : Colors.white12,
                    ),
                    onSelected: (v) =>
                        setState(() => _selectedItem = v ? item.code : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── 已選擇顯示 ──
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.label,
                      color: _selectedCategory?.color ?? Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      getReadableName(_fullResourceType),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 需求數量 ──
            TextFormField(
              controller: _quantityCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration('需求數量', Icons.numbers),
              validator: (v) => (v == null || v.isEmpty) ? '請輸入數量' : null,
            ),
            const SizedBox(height: 20),

            // ── 行動模式 ──
            const Text('您的行動能力',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mobilityMode = 'CAN_GO'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _mobilityMode == 'CAN_GO'
                            ? Colors.green.withValues(alpha: 0.25)
                            : const Color(0xFF1a1a2e),
                        border: Border.all(
                            color: _mobilityMode == 'CAN_GO'
                                ? Colors.greenAccent
                                : Colors.white24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.directions_walk,
                              color: _mobilityMode == 'CAN_GO'
                                  ? Colors.greenAccent
                                  : Colors.white54,
                              size: 28),
                          const SizedBox(height: 6),
                          Text('可自行前往',
                              style: TextStyle(
                                color: _mobilityMode == 'CAN_GO'
                                    ? Colors.greenAccent
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              )),
                          const SizedBox(height: 2),
                          Text('我可以移動去取物資',
                              style: TextStyle(
                                color: _mobilityMode == 'CAN_GO'
                                    ? Colors.white54
                                    : Colors.white30,
                                fontSize: 10,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mobilityMode = 'NEED_DELIVER'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _mobilityMode == 'NEED_DELIVER'
                            ? Colors.orange.withValues(alpha: 0.25)
                            : const Color(0xFF1a1a2e),
                        border: Border.all(
                            color: _mobilityMode == 'NEED_DELIVER'
                                ? Colors.orange
                                : Colors.white24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.accessibility_new,
                              color: _mobilityMode == 'NEED_DELIVER'
                                  ? Colors.orange
                                  : Colors.white54,
                              size: 28),
                          const SizedBox(height: 6),
                          Text('需協助送達',
                              style: TextStyle(
                                color: _mobilityMode == 'NEED_DELIVER'
                                    ? Colors.orange
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              )),
                          const SizedBox(height: 2),
                          Text('無法移動，需要人送來',
                              style: TextStyle(
                                color: _mobilityMode == 'NEED_DELIVER'
                                    ? Colors.white54
                                    : Colors.white30,
                                fontSize: 10,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 搜尋半徑 ──
            Row(
              children: [
                const Icon(Icons.radar, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '搜尋半徑: ${(_maxRange / 1000).toStringAsFixed(1)} km',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
            Slider(
              value: _maxRange,
              min: 100,
              max: 20000,
              divisions: 39,
              activeColor: Colors.redAccent,
              inactiveColor: Colors.white12,
              label: '${(_maxRange / 1000).toStringAsFixed(1)} km',
              onChanged: (v) => setState(() => _maxRange = v),
            ),
            const Text(
              '* 由地理環境自動建議，可手動調整',
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
            const SizedBox(height: 16),

            // ── 備註 ──
            TextFormField(
              controller: _descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: _inputDecoration('備註描述 (選填)', Icons.notes),
            ),
            const SizedBox(height: 24),

            // ── 發布按鈕 ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _publishing ? null : _publish,
                icon: _publishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.broadcast_on_personal,
                        color: Colors.white),
                label: Text(
                  _publishing ? '廣播中...' : '發布需求至 Mesh 網路',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}
