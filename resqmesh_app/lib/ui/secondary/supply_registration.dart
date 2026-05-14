import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/services/rate_limit_exception.dart';
import 'package:ignirelay_app/app/geo/geo_context_resolver.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// Stage 7-r3：theme 收斂。原本整頁硬編 [Color(0xFF0d0d1a)] / [Colors.white*]，
/// 切到淺色主題就直接讀不到。改成全程依 [IgniPalette]（context.igni），
/// dark / light 兩種主題下都能保持文字對比、邊框可見。
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
      await context.read<EventPublisher>().publishSupply(
        resourceType: _fullResourceType,
        quantity: int.parse(_quantityCtrl.text),
        maxRangeMeters: _maxRange,
        deliveryMode: _deliveryModes.join(','),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.supplyRegSuccessSnack),
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
          SnackBar(content: Text(context.l10n.supplyRegFailSnack(e.toString())), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Scaffold(
      backgroundColor: p.bg0,
      appBar: AppBar(
        title: Text(context.l10n.supplyRegTitle,
            style: TextStyle(color: p.text0)),
        backgroundColor: p.bg1,
        iconTheme: IconThemeData(color: p.text0),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── 第一層：物資大類 ──
            Text(context.l10n.supplyRegCategoryLabel,
                style: TextStyle(color: p.text1, fontSize: 14)),
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
                          : p.bg2,
                      border: Border.all(
                          color: selected ? cat.color : p.border1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon,
                            color: selected ? cat.color : p.text2,
                            size: 18),
                        const SizedBox(width: 6),
                        Text(SupplyCategoryLocalizer.categoryLabel(context, cat.code),
                            style: TextStyle(
                              color: selected ? cat.color : p.text1,
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
              Text(context.l10n.supplyRegSubCategoryLabel(SupplyCategoryLocalizer.categoryLabel(context, _selectedCategory!.code)),
                  style: TextStyle(color: p.text1, fontSize: 14)),
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
                    backgroundColor: p.bg2,
                    labelStyle: TextStyle(
                      color:
                          selected ? _selectedCategory!.color : p.text1,
                    ),
                    side: BorderSide(
                      color:
                          selected ? _selectedCategory!.color : p.border1,
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
              Text(context.l10n.supplyRegItemLabel,
                  style: TextStyle(color: p.text1, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedSubCategory!.items.map((item) {
                  final selected = _selectedItem == item.code;
                  return FilterChip(
                    label: Text(SupplyCategoryLocalizer.itemLabel(context, item.code),
                        style: TextStyle(
                          color: selected ? p.text0 : p.text2,
                          fontSize: 12,
                        )),
                    selected: selected,
                    selectedColor:
                        _selectedCategory!.color.withValues(alpha: 0.4),
                    backgroundColor: p.bg3,
                    checkmarkColor: p.text0,
                    side: BorderSide(
                      color:
                          selected ? _selectedCategory!.color : p.border0,
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
                color: p.bg2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.border0),
              ),
              child: Row(
                children: [
                  Icon(Icons.label,
                      color: _selectedCategory?.color ?? p.text3, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      getLocalizedReadableName(_fullResourceType, context),
                      style: TextStyle(color: p.text0, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 有效期限（hasExpiry 子分類才顯示）──
            if (_selectedSubCategory?.hasExpiry == true) ...[
              Text(context.l10n.supplyRegExpiryLabel,
                  style: TextStyle(color: p.text1, fontSize: 14)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ??
                        DateTime.now().add(const Duration(days: 180)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _expiryDate = picked);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: p.bg2,
                    border: Border.all(color: p.border1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: p.text2, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _expiryDate != null
                              ? '${_expiryDate!.year}/${_expiryDate!.month.toString().padLeft(2, '0')}/${_expiryDate!.day.toString().padLeft(2, '0')}'
                              : context.l10n.supplyRegExpiryHint,
                          style: TextStyle(
                            color: _expiryDate != null
                                ? p.text0
                                : p.text3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_expiryDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _expiryDate = null),
                          child: Icon(Icons.clear,
                              color: p.text3, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── 物品狀態（trackCondition 子分類才顯示）──
            if (_selectedSubCategory?.trackCondition == true) ...[
              Text(context.l10n.supplyRegConditionLabel,
                  style: TextStyle(color: p.text1, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ItemCondition.values.map((cond) {
                  final selected = _itemCondition == cond;
                  return ChoiceChip(
                    label: Text(cond.localLabel(context)),
                    selected: selected,
                    selectedColor: (_selectedCategory?.color ?? p.text3)
                        .withValues(alpha: 0.3),
                    backgroundColor: p.bg2,
                    labelStyle: TextStyle(
                      color: selected
                          ? (_selectedCategory?.color ?? p.text0)
                          : p.text1,
                    ),
                    side: BorderSide(
                      color: selected
                          ? (_selectedCategory?.color ?? p.text0)
                          : p.border1,
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
              style: TextStyle(color: p.text0),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration(
                  context, context.l10n.supplyRegQtyLabel, Icons.numbers),
              validator: (v) => (v == null || v.isEmpty) ? context.l10n.supplyRegQtyValidator : null,
            ),
            const SizedBox(height: 20),

            // ── 交接方式（可複選）──
            Text(context.l10n.supplyRegDeliverySection,
                style: TextStyle(color: p.text1, fontSize: 14)),
            const SizedBox(height: 8),
            ...[
              _buildDeliveryModeCheckbox(
                mode: 'DELIVER',
                icon: Icons.delivery_dining,
                label: context.l10n.supplyRegDeliveryDeliver,
                subtitle: context.l10n.supplyRegDeliveryDeliverDesc,
                activeColor: p.ok,
              ),
              const SizedBox(height: 8),
              _buildDeliveryModeCheckbox(
                mode: 'PICKUP',
                icon: Icons.storefront,
                label: context.l10n.supplyRegDeliveryPickup,
                subtitle: context.l10n.supplyRegDeliveryPickupDesc,
                activeColor: p.info,
              ),
              const SizedBox(height: 8),
              _buildDeliveryModeCheckbox(
                mode: 'DROP_OFF',
                icon: Icons.inventory_2,
                label: context.l10n.supplyRegDeliveryDropoff,
                subtitle: context.l10n.supplyRegDeliveryDropoffDesc,
                activeColor: p.brand,
              ),
            ],
            const SizedBox(height: 16),

            // ── 備註 ──
            TextFormField(
              controller: _descCtrl,
              style: TextStyle(color: p.text0),
              maxLines: 2,
              decoration: _inputDecoration(
                  context, context.l10n.supplyRegNoteHint, Icons.notes),
            ),
            const SizedBox(height: 20),

            // ── 覆蓋半徑 ──
            Row(
              children: [
                Icon(Icons.radar, color: p.text2, size: 18),
                const SizedBox(width: 8),
                Text(
                  context.l10n.supplyRegRange((_maxRange / 1000).toStringAsFixed(1)),
                  style: TextStyle(color: p.text1),
                ),
              ],
            ),
            Slider(
              value: _maxRange,
              min: 100,
              max: 20000,
              divisions: 39,
              activeColor: p.brand,
              inactiveColor: p.border1,
              label: '${(_maxRange / 1000).toStringAsFixed(1)} km',
              onChanged: (v) => setState(() => _maxRange = v),
            ),
            Text(
              context.l10n.supplyRegRangeNote,
              style: TextStyle(color: p.text3, fontSize: 11),
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
                  _publishing ? context.l10n.supplyRegPublishing : context.l10n.supplyRegPublishButton,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.ok,
                  foregroundColor: Colors.white,
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
    final p = context.igni;
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
              : p.bg2,
          border: Border.all(
              color: selected ? activeColor : p.border1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              color: selected ? activeColor : p.text3,
              size: 22,
            ),
            const SizedBox(width: 12),
            Icon(icon,
                color: selected ? activeColor : p.text2, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: selected ? activeColor : p.text1,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                        color: selected ? p.text2 : p.text3,
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

  InputDecoration _inputDecoration(
      BuildContext ctx, String label, IconData icon) {
    final p = ctx.igni;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: p.text2),
      prefixIcon: Icon(icon, color: p.text2),
      filled: true,
      fillColor: p.bg2,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: p.border1),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: p.brand),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: p.sos),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: p.sos),
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
