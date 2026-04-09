import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/generated/app_localizations.dart';
import '../mesh/event_manager.dart';
import '../mesh/geo_context_resolver.dart';
import 'supply_category_data.dart';

class SupplyRegistrationScreen extends StatefulWidget {
  const SupplyRegistrationScreen({super.key});

  @override
  State<SupplyRegistrationScreen> createState() =>
      _SupplyRegistrationScreenState();
}

class _SupplyRegistrationScreenState extends State<SupplyRegistrationScreen> {
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

  // ── 配送模式（可複選）──
  final Set<String> _deliveryModes = {'PICKUP'};

  // ── hasExpiry / trackCondition 相關 ──
  DateTime? _expiryDate;
  ItemCondition? _itemCondition;

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
      await _eventManager.publishSupply(
        resourceType: _fullResourceType,
        quantity: int.parse(_quantityCtrl.text),
        maxRangeMeters: _maxRange,
        deliveryMode: _deliveryModes.join(','),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.supplyRegSuccessSnack),
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
          SnackBar(content: Text(S.of(context)!.supplyRegFailSnack(e.toString())), backgroundColor: Colors.red[700]),
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
        title: Text(S.of(context)!.supplyRegTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── 第一層：物資大類 ──
            Text(S.of(context)!.supplyRegCategoryLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                    _expiryDate = null;
                    _itemCondition = null;
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
                        Text(SupplyCategoryLocalizer.categoryLabel(context, cat.code),
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

            // ── 第二層：物資子類 ──
            if (_selectedCategory != null) ...[
              Text(S.of(context)!.supplyRegSubCategoryLabel(SupplyCategoryLocalizer.categoryLabel(context, _selectedCategory!.code)),
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedCategory!.subCategories.map((sub) {
                  final selected = _selectedSubCategory?.code == sub.code;
                  return ChoiceChip(
                    label: Text(SupplyCategoryLocalizer.subCategoryLabel(context, sub.code)),
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
                      _expiryDate = null;
                      _itemCondition = null;
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── 第三層：具體品項（若有） ──
            if (_selectedSubCategory != null &&
                _selectedSubCategory!.items.isNotEmpty) ...[
              Text(S.of(context)!.supplyRegItemLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedSubCategory!.items.map((item) {
                  final selected = _selectedItem == item.code;
                  return FilterChip(
                    label: Text(SupplyCategoryLocalizer.itemLabel(context, item.code),
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

            // ── 有效期限（hasExpiry 子分類才顯示）──
            if (_selectedSubCategory?.hasExpiry == true) ...[
              Text(S.of(context)!.supplyRegExpiryLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ??
                        DateTime.now().add(const Duration(days: 180)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    builder: (context, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.redAccent,
                          surface: Color(0xFF1a1a2e),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _expiryDate = picked);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white54, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _expiryDate != null
                              ? '${_expiryDate!.year}/${_expiryDate!.month.toString().padLeft(2, '0')}/${_expiryDate!.day.toString().padLeft(2, '0')}'
                              : S.of(context)!.supplyRegExpiryHint,
                          style: TextStyle(
                            color: _expiryDate != null
                                ? Colors.white
                                : Colors.white38,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_expiryDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _expiryDate = null),
                          child: const Icon(Icons.clear,
                              color: Colors.white38, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── 物品狀態（trackCondition 子分類才顯示）──
            if (_selectedSubCategory?.trackCondition == true) ...[
              Text(S.of(context)!.supplyRegConditionLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ItemCondition.values.map((cond) {
                  final selected = _itemCondition == cond;
                  return ChoiceChip(
                    label: Text(cond.localLabel(context)),
                    selected: selected,
                    selectedColor: (_selectedCategory?.color ?? Colors.grey)
                        .withValues(alpha: 0.3),
                    backgroundColor: const Color(0xFF1a1a2e),
                    labelStyle: TextStyle(
                      color: selected
                          ? (_selectedCategory?.color ?? Colors.white)
                          : Colors.white54,
                    ),
                    side: BorderSide(
                      color: selected
                          ? (_selectedCategory?.color ?? Colors.white)
                          : Colors.white24,
                    ),
                    onSelected: (_) =>
                        setState(() => _itemCondition = selected ? null : cond),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── 數量 ──
            TextFormField(
              controller: _quantityCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration(S.of(context)!.supplyRegQtyLabel, Icons.numbers),
              validator: (v) => (v == null || v.isEmpty) ? S.of(context)!.supplyRegQtyValidator : null,
            ),
            const SizedBox(height: 20),

            // ── 交接方式（可複選）──
            Text(S.of(context)!.supplyRegDeliverySection,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            ...[
              _buildDeliveryModeCheckbox(
                mode: 'DELIVER',
                icon: Icons.delivery_dining,
                label: S.of(context)!.supplyRegDeliveryDeliver,
                subtitle: S.of(context)!.supplyRegDeliveryDeliverDesc,
                activeColor: Colors.greenAccent,
              ),
              const SizedBox(height: 8),
              _buildDeliveryModeCheckbox(
                mode: 'PICKUP',
                icon: Icons.storefront,
                label: S.of(context)!.supplyRegDeliveryPickup,
                subtitle: S.of(context)!.supplyRegDeliveryPickupDesc,
                activeColor: Colors.blueAccent,
              ),
              const SizedBox(height: 8),
              _buildDeliveryModeCheckbox(
                mode: 'DROP_OFF',
                icon: Icons.inventory_2,
                label: S.of(context)!.supplyRegDeliveryDropoff,
                subtitle: S.of(context)!.supplyRegDeliveryDropoffDesc,
                activeColor: Colors.amber,
              ),
            ],
            const SizedBox(height: 16),

            // ── 備註 ──
            TextFormField(
              controller: _descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: _inputDecoration(S.of(context)!.supplyRegNoteHint, Icons.notes),
            ),
            const SizedBox(height: 20),

            // ── 覆蓋半徑 ──
            Row(
              children: [
                const Icon(Icons.radar, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(
                  S.of(context)!.supplyRegRange((_maxRange / 1000).toStringAsFixed(1)),
                  style: const TextStyle(color: Colors.white70),
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
            Text(
              S.of(context)!.supplyRegRangeNote,
              style: const TextStyle(color: Colors.white30, fontSize: 11),
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
                  _publishing ? S.of(context)!.supplyRegPublishing : S.of(context)!.supplyRegPublishButton,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
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

  Widget _buildDeliveryModeCheckbox({
    required String mode,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color activeColor,
  }) {
    final selected = _deliveryModes.contains(mode);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          // 至少保留一種模式
          if (_deliveryModes.length > 1) _deliveryModes.remove(mode);
        } else {
          _deliveryModes.add(mode);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0xFF1a1a2e),
          border: Border.all(
              color: selected ? activeColor : Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              color: selected ? activeColor : Colors.white38,
              size: 22,
            ),
            const SizedBox(width: 12),
            Icon(icon,
                color: selected ? activeColor : Colors.white54, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: selected ? activeColor : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                        color: selected ? Colors.white54 : Colors.white30,
                        fontSize: 11,
                      )),
                ],
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
