import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/app/services/rate_limit_exception.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_controller.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_models.dart';
import 'package:ignirelay_app/ui/secondary/station_visibility_picker.dart';

/// Stage 2A 拆分：station_supply_screen 的「新增據點物資」分頁。
class StationSupplyRegisterTab extends StatefulWidget {
  const StationSupplyRegisterTab({super.key, required this.onPublished});

  final VoidCallback onPublished;

  @override
  State<StationSupplyRegisterTab> createState() => _StationSupplyRegisterTabState();
}

class _StationSupplyRegisterTabState extends State<StationSupplyRegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _quantityCtrl = TextEditingController(text: '100');
  final _catLimitCtrl = TextEditingController(text: '5');
  final _totalLimitCtrl = TextEditingController(text: '10');

  SupplyCategory? _selectedCategory;
  SupplySubCategory? _selectedSubCategory;
  String? _selectedItem;

  int _resetIntervalHours = 24;
  StationVisibilitySelection _visibility = const StationVisibilitySelection(
    mode: 'village',
    villcodes: [],
    towncode: null,
  );
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = supplyCategories.first;
    _selectedSubCategory = _selectedCategory!.subCategories.first;
  }

  String get _fullResourceType {
    final parts = <String>[_selectedCategory?.code ?? 'WATER'];
    if (_selectedSubCategory != null) parts.add(_selectedSubCategory!.code);
    if (_selectedItem != null) parts.add(_selectedItem!);
    return parts.join('/');
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _publishing = true);

    try {
      final meta = StationMeta(
        isStation: true,
        perUserCategoryLimit: int.parse(_catLimitCtrl.text),
        perUserTotalLimit: int.parse(_totalLimitCtrl.text),
        resetIntervalMs: _resetIntervalHours * 3600 * 1000,
        visibleZones: _visibility.mode == 'village' ? _visibility.villcodes : null,
        visibleTownship: _visibility.mode == 'township' ? _visibility.towncode : null,
      );

      await context.read<StationSupplyController>().publishStationSupply(
            resourceType: _fullResourceType,
            quantity: int.parse(_quantityCtrl.text),
            meta: meta,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.stationPublishSuccess), backgroundColor: Colors.green[700]),
        );
        widget.onPublished();
      }
    } on RateLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.orange[700]),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.stationRemoveFailSnack(e.toString())), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildCategorySelector(),
          const SizedBox(height: 20),
          if (_selectedCategory != null) ...[
            _buildSubCategorySelector(),
            const SizedBox(height: 16),
          ],
          if (_selectedSubCategory != null && _selectedSubCategory!.items.isNotEmpty) ...[
            _buildItemSelector(),
            const SizedBox(height: 16),
          ],
          _buildResourceTypeTag(),
          const SizedBox(height: 24),
          _sectionTitle(context.l10n.stationQtyLabel),
          const SizedBox(height: 8),
          TextFormField(
            controller: _quantityCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(context.l10n.stationTotalQtyLabel, Icons.inventory),
            validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? context.l10n.stationQtyValidator : null,
          ),
          const SizedBox(height: 24),
          _sectionTitle(context.l10n.stationQuotaSection),
          const SizedBox(height: 8),
          _buildQuotaInputs(),
          const SizedBox(height: 16),
          _buildResetInterval(),
          const SizedBox(height: 24),
          _sectionTitle(context.l10n.stationVisibilityLabel),
          const SizedBox(height: 8),
          StationVisibilityPicker(onChanged: (v) => _visibility = v),
          const SizedBox(height: 32),
          _buildPublishButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.stationCategoryLabel, style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? cat.color.withValues(alpha: 0.3) : const Color(0xFF1a1a2e),
                  border: Border.all(color: selected ? cat.color : Colors.white24),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, color: selected ? cat.color : Colors.white54, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      SupplyCategoryLocalizer.categoryLabel(context, cat.code),
                      style: TextStyle(
                        color: selected ? cat.color : Colors.white54,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${SupplyCategoryLocalizer.categoryLabel(context, _selectedCategory!.code)} ${context.l10n.stationSubCategoryLabel}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedCategory!.subCategories.map((sub) {
            final selected = _selectedSubCategory?.code == sub.code;
            return ChoiceChip(
              label: Text(SupplyCategoryLocalizer.subCategoryLabel(context, sub.code)),
              selected: selected,
              selectedColor: _selectedCategory!.color.withValues(alpha: 0.3),
              backgroundColor: const Color(0xFF1a1a2e),
              labelStyle: TextStyle(color: selected ? _selectedCategory!.color : Colors.white54),
              side: BorderSide(color: selected ? _selectedCategory!.color : Colors.white24),
              onSelected: (_) => setState(() {
                _selectedSubCategory = sub;
                _selectedItem = null;
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildItemSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.stationItemLabel, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _selectedSubCategory!.items.map((item) {
            final selected = _selectedItem == item.code;
            return FilterChip(
              label: Text(
                SupplyCategoryLocalizer.itemLabel(context, item.code),
                style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 12),
              ),
              selected: selected,
              selectedColor: _selectedCategory!.color.withValues(alpha: 0.4),
              backgroundColor: const Color(0xFF222244),
              checkmarkColor: Colors.white,
              side: BorderSide(color: selected ? _selectedCategory!.color : Colors.white12),
              onSelected: (v) => setState(() => _selectedItem = v ? item.code : null),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResourceTypeTag() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.label, color: _selectedCategory?.color ?? Colors.grey, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              getLocalizedReadableName(_fullResourceType, context),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaInputs() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _catLimitCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(context.l10n.stationQuotaCategoryLimit, Icons.category),
            validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? context.l10n.stationFieldRequired : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _totalLimitCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(context.l10n.stationQuotaTotalLimit, Icons.equalizer),
            validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? context.l10n.stationFieldRequired : null,
          ),
        ),
      ],
    );
  }

  Widget _buildResetInterval() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.stationResetCycleLabel, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _resetChip(context.l10n.stationResetChip6h, 6),
            _resetChip(context.l10n.stationResetChip12h, 12),
            _resetChip(context.l10n.stationResetChip24h, 24),
            _resetChip(context.l10n.stationResetChip48h, 48),
            _resetChip(context.l10n.stationResetChip72h, 72),
            _resetChip(context.l10n.stationResetChipNone, 0),
          ],
        ),
        if (_resetIntervalHours > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              context.l10n.stationResetNoteInterval(_resetIntervalHours),
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ),
        if (_resetIntervalHours == 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              context.l10n.stationResetNoteNone,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _publishing ? null : _publish,
        icon: _publishing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add_business, color: Colors.white),
        label: Text(
          _publishing ? context.l10n.stationPublishing : context.l10n.stationPublishButton,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orangeAccent[700],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _resetChip(String label, int hours) {
    final selected = _resetIntervalHours == hours;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: Colors.orangeAccent.withValues(alpha: 0.3),
      backgroundColor: const Color(0xFF1a1a2e),
      labelStyle: TextStyle(color: selected ? Colors.orangeAccent : Colors.white54, fontSize: 13),
      side: BorderSide(color: selected ? Colors.orangeAccent : Colors.white24),
      onSelected: (_) => setState(() => _resetIntervalHours = hours),
    );
  }

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: Colors.orangeAccent),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.orangeAccent, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
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
        borderSide: const BorderSide(color: Colors.orangeAccent),
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
    _catLimitCtrl.dispose();
    _totalLimitCtrl.dispose();
    super.dispose();
  }
}
