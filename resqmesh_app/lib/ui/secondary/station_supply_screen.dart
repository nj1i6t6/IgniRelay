import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:provider/provider.dart';
import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/station_supply_repo.dart';
import 'package:ignirelay_app/app/services/rate_limit_exception.dart';
import 'package:ignirelay_app/app/geo/village_geofence.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

// =============================================================================
// 據點物資管理畫面 (Station Supply Screen)
//
// 功能：
//   1. 註冊新的據點物資（is_station=true），設定配額與可見區域
//   2. 瀏覽 / 管理已註冊的據點物資
//   3. 查看各用戶的領取額度使用情形
//   4. 手動重設額度
//
// 權限：需要 L2+ 身分等級
// =============================================================================

class StationSupplyScreen extends StatefulWidget {
  const StationSupplyScreen({super.key});

  @override
  State<StationSupplyScreen> createState() => _StationSupplyScreenState();
}

class _StationSupplyScreenState extends State<StationSupplyScreen>
    with SingleTickerProviderStateMixin {
  final _identity = IdentityManager();

  late TabController _tabController;
  bool _authorized = false;
  bool _loading = true;

  // ── 已註冊的據點物資 ──
  List<_StationItem> _stationItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final level = _identity.getIdentityLevel();
    setState(() {
      _authorized = level >= 2;
      _loading = false;
    });
    if (_authorized) {
      await _loadStationItems();
    }
  }

  Future<void> _loadStationItems() async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final eventStore = context.read<EventStore>();
    final decoder = context.read<EventDecoder>();
    final supplyRepo = context.read<StationSupplyRepo>();

    final allRegisters = await eventStore.queryResourceRegisters();
    final rows = allRegisters.where((row) {
      final senderKey = row['sender_pub_key'] as Uint8List?;
      if (senderKey == null || senderKey.length != pubKeyBytes.length) return false;
      for (int i = 0; i < pubKeyBytes.length; i++) {
        if (senderKey[i] != pubKeyBytes[i]) return false;
      }
      return true;
    }).toList();

    final items = <_StationItem>[];
    for (final row in rows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;
      try {
        final rd = decoder.decodeResourceData(payload);
        if (rd == null) continue;
        final meta = _StationMeta.tryParse(rd.deliveryMode);
        if (meta == null || !meta.isStation) continue;

        final quotas = await supplyRepo.queryStationQuotas(stationId: rd.resourceType);

        items.add(_StationItem(
          eventId: row['event_id'] as String,
          resourceId: rd.resourceType,
          resourceType: rd.resourceType,
          quantity: rd.quantity.toDouble(),
          meta: meta,
          quotaRows: quotas,
          hlcTimestamp: row['hlc_timestamp'] as int,
        ));
      } catch (_) {
        continue;
      }
    }

    if (mounted) setState(() => _stationItems = items);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0d0d1a),
        body: Center(
          child: CircularProgressIndicator(color: Colors.orangeAccent),
        ),
      );
    }

    if (!_authorized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0d0d1a),
        appBar: AppBar(
          title: Text(context.l10n.stationTitle, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1a1a2e),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white38, size: 64),
                const SizedBox(height: 16),
                Text(
                  context.l10n.stationAuthRequired,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.stationAuthCurrentLevel(_identity.getIdentityLevel()),
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.stationAuthDesc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white30, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: Text(context.l10n.stationTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          labelColor: Colors.orangeAccent,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(icon: const Icon(Icons.add_business), text: context.l10n.stationTabAdd),
            Tab(icon: const Icon(Icons.inventory_2), text: context.l10n.stationTabManage),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RegisterTab(
            onPublished: () async {
              await _loadStationItems();
              _tabController.animateTo(1);
            },
          ),
          _ManageTab(
            items: _stationItems,
            onRefresh: _loadStationItems,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 新增據點物資 Tab
// =============================================================================

class _RegisterTab extends StatefulWidget {
  final VoidCallback onPublished;
  const _RegisterTab({required this.onPublished});

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _quantityCtrl = TextEditingController(text: '100');
  final _catLimitCtrl = TextEditingController(text: '5');
  final _totalLimitCtrl = TextEditingController(text: '10');

  SupplyCategory? _selectedCategory;
  SupplySubCategory? _selectedSubCategory;
  String? _selectedItem;

  // ── 額度重設週期 ──
  int _resetIntervalHours = 24;

  // ── 可見範圍 ──
  String _visibilityMode = 'village'; // 'village' or 'township'
  List<VillageInfo> _nearbyVillages = [];
  Set<String> _selectedVillcodes = {};
  String? _selectedTowncode;
  String? _townDisplayName;
  bool _loadingGeo = true;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = supplyCategories.first;
    _selectedSubCategory = _selectedCategory!.subCategories.first;
    _loadGeoData();
  }

  Future<void> _loadGeoData() async {
    try {
      await VillageGeofence.init();
      // 使用預設座標查詢（實際應用中應取得 GPS）
      final villages = await VillageGeofence.query(25.045, 121.543);
      if (mounted) {
        setState(() {
          _nearbyVillages = villages;
          if (villages.isNotEmpty) {
            _selectedVillcodes = {villages.first.villcode};
            _selectedTowncode = villages.first.towncode;
            _townDisplayName =
                '${villages.first.countyName}${villages.first.townName}';
          }
          _loadingGeo = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingGeo = false);
    }
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
      final meta = _StationMeta(
        isStation: true,
        perUserCategoryLimit: int.parse(_catLimitCtrl.text),
        perUserTotalLimit: int.parse(_totalLimitCtrl.text),
        resetIntervalMs: _resetIntervalHours * 3600 * 1000,
        visibleZones: _visibilityMode == 'village'
            ? _selectedVillcodes.toList()
            : null,
        visibleTownship:
            _visibilityMode == 'township' ? _selectedTowncode : null,
      );

      await context.read<EventPublisher>().publishSupply(
        resourceType: _fullResourceType,
        quantity: int.parse(_quantityCtrl.text),
        maxRangeMeters: 50000, // 據點物資覆蓋範圍更大
        deliveryMode: 'STATION:${meta.toJson()}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.stationPublishSuccess),
            backgroundColor: Colors.green[700],
          ),
        );
        widget.onPublished();
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
          SnackBar(
              content: Text(context.l10n.stationRemoveFailSnack(e.toString())), backgroundColor: Colors.red[700]),
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
          // ── 物資大類 ──
          Text(context.l10n.stationCategoryLabel,
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
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── 物資子類 ──
          if (_selectedCategory != null) ...[
            Text('${SupplyCategoryLocalizer.categoryLabel(context, _selectedCategory!.code)} ${context.l10n.stationSubCategoryLabel}',
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
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // ── 具體品項 ──
          if (_selectedSubCategory != null &&
              _selectedSubCategory!.items.isNotEmpty) ...[
            Text(context.l10n.stationItemLabel,
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

          // ── 已選類型顯示 ──
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
                    getLocalizedReadableName(_fullResourceType, context),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 總庫存數量 ──
          _sectionTitle(context.l10n.stationQtyLabel),
          const SizedBox(height: 8),
          TextFormField(
            controller: _quantityCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(context.l10n.stationTotalQtyLabel, Icons.inventory),
            validator: (v) =>
                (v == null || v.isEmpty || int.tryParse(v) == null)
                    ? context.l10n.stationQtyValidator
                    : null,
          ),
          const SizedBox(height: 24),

          // ── 配額設定 ──
          _sectionTitle(context.l10n.stationQuotaSection),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _catLimitCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration(context.l10n.stationQuotaCategoryLimit, Icons.category),
                  validator: (v) =>
                      (v == null || v.isEmpty || int.tryParse(v) == null)
                          ? context.l10n.stationFieldRequired
                          : null,
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
                  validator: (v) =>
                      (v == null || v.isEmpty || int.tryParse(v) == null)
                          ? context.l10n.stationFieldRequired
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 重設週期 ──
          Text(context.l10n.stationResetCycleLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
          const SizedBox(height: 24),

          // ── 可見區域 ──
          _sectionTitle(context.l10n.stationVisibilityLabel),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _visibilityMode = 'village'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _visibilityMode == 'village'
                          ? Colors.blue.withValues(alpha: 0.25)
                          : const Color(0xFF1a1a2e),
                      border: Border.all(
                          color: _visibilityMode == 'village'
                              ? Colors.blueAccent
                              : Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.location_city,
                            color: _visibilityMode == 'village'
                                ? Colors.blueAccent
                                : Colors.white54,
                            size: 28),
                        const SizedBox(height: 6),
                        Text(context.l10n.stationVisibilityVillage,
                            style: TextStyle(
                              color: _visibilityMode == 'village'
                                  ? Colors.blueAccent
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            )),
                        const SizedBox(height: 2),
                        Text(context.l10n.stationVisibilityVillageDesc,
                            style: TextStyle(
                              color: _visibilityMode == 'village'
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
                  onTap: () => setState(() => _visibilityMode = 'township'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _visibilityMode == 'township'
                          ? Colors.green.withValues(alpha: 0.25)
                          : const Color(0xFF1a1a2e),
                      border: Border.all(
                          color: _visibilityMode == 'township'
                              ? Colors.greenAccent
                              : Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.map,
                            color: _visibilityMode == 'township'
                                ? Colors.greenAccent
                                : Colors.white54,
                            size: 28),
                        const SizedBox(height: 6),
                        Text(context.l10n.stationVisibilityTownship,
                            style: TextStyle(
                              color: _visibilityMode == 'township'
                                  ? Colors.greenAccent
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            )),
                        const SizedBox(height: 2),
                        Text(context.l10n.stationVisibilityTownshipDesc,
                            style: TextStyle(
                              color: _visibilityMode == 'township'
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
          const SizedBox(height: 12),

          if (_loadingGeo)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                    color: Colors.orangeAccent, strokeWidth: 2),
              ),
            )
          else if (_visibilityMode == 'village') ...[
            if (_nearbyVillages.isEmpty)
              Text(context.l10n.stationVisibilityNoVillages,
                  style: const TextStyle(color: Colors.white38, fontSize: 13))
            else
              ..._nearbyVillages.map((v) {
                final selected = _selectedVillcodes.contains(v.villcode);
                return CheckboxListTile(
                  title: Text(v.fullName,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text('代碼: ${v.villcode}',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                  value: selected,
                  activeColor: Colors.blueAccent,
                  checkColor: Colors.white,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedVillcodes.add(v.villcode);
                      } else {
                        _selectedVillcodes.remove(v.villcode);
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }),
            const SizedBox(height: 4),
            Text(
              context.l10n.stationVisibilityVillageNote,
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ] else ...[
            // township mode
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _townDisplayName ?? context.l10n.stationVisibilityTownNotLocated,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  if (_selectedTowncode != null)
                    Text(
                      _selectedTowncode!,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.stationVisibilityTownNote,
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
          const SizedBox(height: 32),

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
                  : const Icon(Icons.add_business, color: Colors.white),
              label: Text(
                _publishing ? context.l10n.stationPublishing : context.l10n.stationPublishButton,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
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
      labelStyle: TextStyle(
        color: selected ? Colors.orangeAccent : Colors.white54,
        fontSize: 13,
      ),
      side: BorderSide(
        color: selected ? Colors.orangeAccent : Colors.white24,
      ),
      onSelected: (_) => setState(() => _resetIntervalHours = hours),
    );
  }

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: Colors.orangeAccent),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            )),
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
    // Stage 5 修正：原本誤放在 `deactivate()`，會在 widget 暫離 tree 時就把
    // TextEditingController 釋放掉，下次 reactivate 會炸 use-after-dispose。
    _quantityCtrl.dispose();
    _catLimitCtrl.dispose();
    _totalLimitCtrl.dispose();
    super.dispose();
  }
}

// =============================================================================
// 管理已註冊據點物資 Tab
// =============================================================================

class _ManageTab extends StatelessWidget {
  final List<_StationItem> items;
  final VoidCallback onRefresh;

  const _ManageTab({required this.items, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_mall_directory,
                color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(context.l10n.stationManageEmptyTitle,
                style: const TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            Text(context.l10n.stationManageEmptySubtitle,
                style: const TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: Colors.orangeAccent,
      backgroundColor: const Color(0xFF1a1a2e),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _StationItemCard(item: items[index], onRefresh: onRefresh),
      ),
    );
  }
}

// =============================================================================
// 單一據點物資卡片
// =============================================================================

class _StationItemCard extends StatelessWidget {
  final _StationItem item;
  final VoidCallback onRefresh;

  const _StationItemCard({required this.item, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final meta = item.meta;
    final totalUsedByAll = item.quotaRows.fold<int>(
      0,
      (sum, row) => sum + ((row['total_used'] as int?) ?? 0),
    );
    final uniqueUsers = item.quotaRows
        .map((r) => r['user_pub_key'])
        .toSet()
        .length;
    final remaining = (item.quantity - totalUsedByAll).clamp(0, item.quantity);

    return Card(
      color: const Color(0xFF1a1a2e),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 標題行 ──
            Row(
              children: [
                const Icon(Icons.store, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    getLocalizedReadableName(item.resourceType, context),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusBadge(context, remaining, item.quantity.toInt()),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),

            // ── 庫存資訊 ──
            _infoRow(Icons.inventory_2, context.l10n.stationInfoTotalQty,
                context.l10n.stationInfoQtyUnit(item.quantity.toInt())),
            _infoRow(Icons.shopping_cart, context.l10n.stationInfoUsed, context.l10n.stationInfoQtyUnit(totalUsedByAll)),
            _infoRow(Icons.check_circle_outline, context.l10n.stationInfoRemaining,
                context.l10n.stationInfoQtyUnit(remaining.toInt())),
            _infoRow(Icons.people, context.l10n.stationInfoUsers, context.l10n.stationInfoUsersUnit(uniqueUsers)),
            const SizedBox(height: 8),

            // ── 配額資訊 ──
            Text(context.l10n.stationQuotaRulesLabel,
                style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _infoRow(Icons.category, context.l10n.stationQuotaCategoryLimitInfo,
                context.l10n.stationInfoQtyUnit(meta.perUserCategoryLimit)),
            _infoRow(
                Icons.equalizer, context.l10n.stationQuotaTotalLimitInfo, context.l10n.stationInfoQtyUnit(meta.perUserTotalLimit)),
            _infoRow(
              Icons.timer,
              context.l10n.stationQuotaResetCycleInfo,
              meta.resetIntervalMs > 0
                  ? context.l10n.stationQuotaResetHours((meta.resetIntervalMs / 3600000).round())
                  : context.l10n.stationQuotaResetNone,
            ),

            // ── 可見範圍 ──
            const SizedBox(height: 4),
            if (meta.visibleZones != null && meta.visibleZones!.isNotEmpty)
              _infoRow(Icons.location_on, context.l10n.stationVisibleZones,
                  context.l10n.stationVisibleZonesCount(meta.visibleZones!.length)),
            if (meta.visibleTownship != null)
              _infoRow(Icons.map, context.l10n.stationVisibleZones,
                  context.l10n.stationVisibleTownship(meta.visibleTownship!)),
            const Divider(color: Colors.white12, height: 20),

            // ── 操作按鈕 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 查看額度明細
                TextButton.icon(
                  onPressed: () => _showQuotaDetails(context),
                  icon: const Icon(Icons.list_alt,
                      color: Colors.blueAccent, size: 16),
                  label: Text(context.l10n.stationQuotaDetailButton,
                      style:
                          const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                // 重設額度
                TextButton.icon(
                  onPressed: () => _confirmResetQuotas(context),
                  icon: const Icon(Icons.refresh,
                      color: Colors.orangeAccent, size: 16),
                  label: Text(context.l10n.stationQuotaResetButton,
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                // 下架
                TextButton.icon(
                  onPressed: () => _confirmRemove(context),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 16),
                  label: Text(context.l10n.stationRemoveButton,
                      style:
                          const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, num remaining, int total) {
    final ratio = total > 0 ? remaining / total : 0;
    Color color;
    String label;
    if (ratio > 0.5) {
      color = Colors.green;
      label = context.l10n.stationStatusSufficient;
    } else if (ratio > 0.1) {
      color = Colors.orange;
      label = context.l10n.stationStatusLow;
    } else if (remaining > 0) {
      color = Colors.red;
      label = context.l10n.stationStatusCritical;
    } else {
      color = Colors.grey;
      label = context.l10n.stationStatusDepleted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 14),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  void _showQuotaDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        if (item.quotaRows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(ctx.l10n.stationQuotaDetailEmpty,
                  style: const TextStyle(color: Colors.white38, fontSize: 16)),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt,
                    color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.stationQuotaDetailTitle(getLocalizedReadableName(item.resourceType, ctx)),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),
            ...item.quotaRows.map((row) {
              final pubKey = row['user_pub_key'] as Uint8List;
              final keyHex = pubKey
                  .take(4)
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join();
              final cat = row['category'] as String? ?? '';
              final used = row['used_quantity'] as int? ?? 0;
              final total = row['total_used'] as int? ?? 0;
              final lastReset = row['last_reset_at'] as int? ?? 0;
              final resetTime = lastReset > 0
                  ? DateTime.fromMillisecondsSinceEpoch(lastReset)
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person,
                            color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(ctx.l10n.stationQuotaUserLabel(keyHex),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const Spacer(),
                        Text(cat,
                            style: const TextStyle(
                                color: Colors.orangeAccent, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(ctx.l10n.stationQuotaUsedTotal(used, total),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    if (resetTime != null)
                      Text(
                        ctx.l10n.stationQuotaLastReset('${resetTime.month}/${resetTime.day} ${resetTime.hour}:${resetTime.minute.toString().padLeft(2, '0')}'),
                        style: const TextStyle(
                            color: Colors.white30, fontSize: 11),
                      ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _confirmResetQuotas(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(ctx.l10n.stationResetAllDialogTitle,
            style: const TextStyle(color: Colors.white)),
        content: Text(
          ctx.l10n.stationResetAllDialogContent,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.stationResetAllDialogCancel,
                style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.stationResetAllDialogConfirm,
                style: const TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await context.read<StationSupplyRepo>().resetStationUsage(item.resourceId);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.stationResetSuccessSnack),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.stationResetFailSnack(e.toString())),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(ctx.l10n.stationRemoveDialogTitle,
            style: const TextStyle(color: Colors.white)),
        content: Text(
          ctx.l10n.stationRemoveDialogContent(getLocalizedReadableName(item.resourceType, ctx)),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.stationRemoveDialogCancel,
                style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.stationRemoveDialogConfirm,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await context.read<EventPublisher>().cancelSupply(item.eventId);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.stationRemoveSuccessSnack),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.stationRemoveFailSnack(e.toString())),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }
}

// =============================================================================
// 據點物資元資料 (編碼在 ResourceData.description 欄位中)
// =============================================================================

class _StationMeta {
  final bool isStation;
  final int perUserCategoryLimit;
  final int perUserTotalLimit;
  final int resetIntervalMs;
  final List<String>? visibleZones;
  final String? visibleTownship;

  const _StationMeta({
    required this.isStation,
    required this.perUserCategoryLimit,
    required this.perUserTotalLimit,
    required this.resetIntervalMs,
    this.visibleZones,
    this.visibleTownship,
  });

  String toJson() {
    final map = <String, dynamic>{
      'is_station': isStation,
      'per_user_category_limit': perUserCategoryLimit,
      'per_user_total_limit': perUserTotalLimit,
      'reset_interval_ms': resetIntervalMs,
    };
    if (visibleZones != null) map['visible_zones'] = visibleZones;
    if (visibleTownship != null) map['visible_township'] = visibleTownship;
    return jsonEncode(map);
  }

  static _StationMeta? tryParse(String description) {
    // description 格式: "STATION:{json}"
    if (!description.startsWith('STATION:')) return null;
    try {
      final jsonStr = description.substring('STATION:'.length);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _StationMeta(
        isStation: map['is_station'] as bool? ?? false,
        perUserCategoryLimit: map['per_user_category_limit'] as int? ?? 5,
        perUserTotalLimit: map['per_user_total_limit'] as int? ?? 10,
        resetIntervalMs: map['reset_interval_ms'] as int? ?? 86400000,
        visibleZones: (map['visible_zones'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        visibleTownship: map['visible_township'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

// =============================================================================
// 據點物資資料模型
// =============================================================================

class _StationItem {
  final String eventId;
  final String resourceId;
  final String resourceType;
  final double quantity;
  final _StationMeta meta;
  final List<Map<String, dynamic>> quotaRows;
  final int hlcTimestamp;

  const _StationItem({
    required this.eventId,
    required this.resourceId,
    required this.resourceType,
    required this.quantity,
    required this.meta,
    required this.quotaRows,
    required this.hlcTimestamp,
  });
}
