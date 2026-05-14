import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/services/rate_limit_exception.dart';
import 'package:ignirelay_app/app/geo/geo_context_resolver.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

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
      await context.read<EventPublisher>().publishRequest(
        resourceType: _fullResourceType,
        quantity: int.parse(_quantityCtrl.text),
        note: _descCtrl.text.trim(),
        maxRangeMeters: _maxRange,
        mobilityMode: _mobilityMode,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.reqSheetSuccessSnack),
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
          SnackBar(content: Text(context.l10n.reqSheetFailSnack(e.toString())), backgroundColor: Colors.red[700]),
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
        title: Text(context.l10n.reqSheetTitle,
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
            Text(context.l10n.reqSheetCategoryLabel,
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

            // ── 第二層：子類別 ──
            if (_selectedCategory != null) ...[
              Text('${SupplyCategoryLocalizer.categoryLabel(context, _selectedCategory!.code)} ${context.l10n.reqSheetSubCategoryLabel}',
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
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── 第三層：具體品項 ──
            if (_selectedSubCategory != null &&
                _selectedSubCategory!.items.isNotEmpty) ...[
              Text(context.l10n.reqSheetItemLabel,
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

            // ── 需求數量 ──
            TextFormField(
              controller: _quantityCtrl,
              style: TextStyle(color: p.text0),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration(
                  context, context.l10n.reqSheetQtyLabel, Icons.numbers),
              validator: (v) => (v == null || v.isEmpty) ? context.l10n.supplyRegQtyValidator : null,
            ),
            const SizedBox(height: 20),

            // ── 交接方式 ──
            Text(context.l10n.reqSheetMobilitySection,
                style: TextStyle(color: p.text1, fontSize: 14)),
            const SizedBox(height: 8),
            _buildMobilityOption(
              mode: 'CAN_GO',
              icon: Icons.directions_walk,
              label: context.l10n.reqSheetMobilityPickup,
              subtitle: context.l10n.reqSheetMobilityPickupDesc,
              activeColor: p.ok,
            ),
            const SizedBox(height: 8),
            _buildMobilityOption(
              mode: 'NEED_DELIVER',
              icon: Icons.accessibility_new,
              label: context.l10n.reqSheetMobilityDelivery,
              subtitle: context.l10n.reqSheetMobilityDeliveryDesc,
              activeColor: p.warn,
            ),
            const SizedBox(height: 8),
            _buildMobilityOption(
              mode: 'DROP_OFF',
              icon: Icons.inventory_2,
              label: context.l10n.reqSheetMobilityDropoff,
              subtitle: context.l10n.reqSheetMobilityDropoffDesc,
              activeColor: p.brand,
            ),
            const SizedBox(height: 20),

            // ── 搜尋半徑 ──
            Row(
              children: [
                Icon(Icons.radar, color: p.text2, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.reqSheetRange((_maxRange / 1000).toStringAsFixed(1)),
                    style: TextStyle(color: p.text1),
                  ),
                ),
              ],
            ),
            Slider(
              value: _maxRange,
              min: 100,
              max: 20000,
              divisions: 39,
              activeColor: p.sos,
              inactiveColor: p.border1,
              label: '${(_maxRange / 1000).toStringAsFixed(1)} km',
              onChanged: (v) => setState(() => _maxRange = v),
            ),
            Text(
              context.l10n.supplyRegRangeNote,
              style: TextStyle(color: p.text3, fontSize: 11),
            ),
            const SizedBox(height: 16),

            // ── 備註 ──
            TextFormField(
              controller: _descCtrl,
              style: TextStyle(color: p.text0),
              maxLines: 2,
              decoration: _inputDecoration(
                  context, context.l10n.supplyRegNoteHint, Icons.notes),
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
                  _publishing ? context.l10n.reqSheetPublishing : context.l10n.reqSheetPublishButton,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.sos,
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

  Widget _buildMobilityOption({
    required String mode,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color activeColor,
  }) {
    final p = context.igni;
    final selected = _mobilityMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mobilityMode = mode),
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
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
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
        borderSide: BorderSide(color: p.sos),
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
