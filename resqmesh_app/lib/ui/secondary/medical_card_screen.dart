import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/models/medical_card.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';

class MedicalCardScreen extends StatefulWidget {
  const MedicalCardScreen({super.key});

  @override
  State<MedicalCardScreen> createState() => _MedicalCardScreenState();
}

class _MedicalCardScreenState extends State<MedicalCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identity = IdentityManager();
  final _db = DatabaseHelper();
  bool _loading = true;
  bool _saving = false;

  late MedicalCard _card;

  // 文字欄位控制器
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _allergenCtrl = TextEditingController();
  final _reactionCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  final _ecRelationCtrl = TextEditingController();
  final _languageCtrl = TextEditingController();

  static const _bloodTypes = [
    '',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _conditionsCtrl.dispose();
    _medicationsCtrl.dispose();
    _allergenCtrl.dispose();
    _reactionCtrl.dispose();
    _ecPhoneCtrl.dispose();
    _ecRelationCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final pubKey = await _identity.getPublicKeyBytes();
    final json = await _db.getMedicalCard(pubKey);
    if (json != null) {
      _card = MedicalCard.fromJsonString(json);
    } else {
      _card = MedicalCard();
    }
    _syncControllersFromCard();
    if (mounted) setState(() => _loading = false);
  }

  void _syncControllersFromCard() {
    _nameCtrl.text = _card.name;
    _ageCtrl.text = _card.age?.toString() ?? '';
    _heightCtrl.text = _card.heightCm?.toString() ?? '';
    _weightCtrl.text = _card.weightKg?.toString() ?? '';
    _conditionsCtrl.text = _card.conditions.join('、');
    _medicationsCtrl.text = _card.medications.join('、');
    _ecPhoneCtrl.text = _card.emergencyContact.phone;
    _ecRelationCtrl.text = _card.emergencyContact.relation;
    _languageCtrl.text = _card.primaryLanguage;
  }

  void _syncCardFromControllers() {
    _card.name = _nameCtrl.text.trim();
    _card.age = int.tryParse(_ageCtrl.text.trim());
    _card.heightCm = int.tryParse(_heightCtrl.text.trim());
    _card.weightKg = int.tryParse(_weightCtrl.text.trim());
    _card.conditions = _conditionsCtrl.text
        .split(RegExp(r'[、,，]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _card.medications = _medicationsCtrl.text
        .split(RegExp(r'[、,，]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _card.emergencyContact.phone = _ecPhoneCtrl.text.trim();
    _card.emergencyContact.relation = _ecRelationCtrl.text.trim();
    _card.primaryLanguage = _languageCtrl.text.trim();
  }

  Future<void> _save() async {
    _syncCardFromControllers();
    setState(() => _saving = true);
    try {
      final pubKey = await _identity.getPublicKeyBytes();
      await _db.saveMedicalCard(pubKey, _card.toJsonString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.medicalSavedSnack),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.medicalSaveFailSnack(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyPreset(Set<String> preset, String presetName) {
    setState(() => _card.applyPreset(preset));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.medicalPresetApplied(presetName)),
        backgroundColor: const Color(0xFF1a1a2e),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: Text(S.of(context)!.medicalTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  // SOS 廣播說明
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            S.of(context)!.medicalSosInfo,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 快速預設
                  _buildPresetRow(),
                  const SizedBox(height: 12),

                  // 從系統健康資料匯入
                  _buildHealthImportButton(),
                  const SizedBox(height: 20),

                  // ── 基本生理 ──
                  _buildSectionHeader(S.of(context)!.medicalSectionBasic, Icons.person_outline),
                  _buildTextField(
                    field: MedicalField.name,
                    label: S.of(context)!.medicalFieldName,
                    controller: _nameCtrl,
                    hint: S.of(context)!.medicalHintName,
                    icon: Icons.badge_outlined,
                  ),
                  _buildNumberField(
                    field: MedicalField.age,
                    label: S.of(context)!.medicalFieldAge,
                    controller: _ageCtrl,
                    hint: S.of(context)!.medicalHintAge,
                    icon: Icons.cake_outlined,
                    suffix: S.of(context)!.medicalSuffixAge,
                  ),
                  _buildNumberField(
                    field: MedicalField.heightCm,
                    label: S.of(context)!.medicalFieldHeight,
                    controller: _heightCtrl,
                    hint: S.of(context)!.medicalHintHeight,
                    icon: Icons.height,
                    suffix: S.of(context)!.medicalSuffixHeight,
                  ),
                  _buildNumberField(
                    field: MedicalField.weightKg,
                    label: S.of(context)!.medicalFieldWeight,
                    controller: _weightCtrl,
                    hint: S.of(context)!.medicalHintWeight,
                    icon: Icons.monitor_weight_outlined,
                    suffix: S.of(context)!.medicalSuffixWeight,
                  ),
                  _buildBloodTypeField(),
                  const SizedBox(height: 20),

                  // ── 醫療背景 ──
                  _buildSectionHeader(S.of(context)!.medicalSectionBackground, Icons.medical_services_outlined),
                  _buildTextField(
                    field: MedicalField.conditions,
                    label: S.of(context)!.medicalFieldConditions,
                    controller: _conditionsCtrl,
                    hint: S.of(context)!.medicalHintConditions,
                    icon: Icons.healing_outlined,
                    maxLines: 2,
                  ),
                  _buildAllergySection(),
                  _buildTextField(
                    field: MedicalField.medications,
                    label: S.of(context)!.medicalFieldMedications,
                    controller: _medicationsCtrl,
                    hint: S.of(context)!.medicalHintMedications,
                    icon: Icons.medication_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // ── 急救資訊 ──
                  _buildSectionHeader(S.of(context)!.medicalSectionEmergency, Icons.emergency_outlined),
                  _buildEmergencyContactSection(),
                  _buildOrganDonorField(),
                  _buildTextField(
                    field: MedicalField.primaryLanguage,
                    label: S.of(context)!.medicalFieldPrimaryLanguage,
                    controller: _languageCtrl,
                    hint: S.of(context)!.medicalHintLanguage,
                    icon: Icons.language,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(_saving ? S.of(context)!.medicalSaving : S.of(context)!.medicalSaveButton,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
    );
  }

  // ── 快速預設列 ──
  Widget _buildPresetRow() {
    final s = S.of(context)!;
    return Row(
      children: [
        Text(s.medicalPresetLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(width: 12),
        _presetChip(s.medicalPresetMinimal, MedicalField.presetMinimal),
        const SizedBox(width: 8),
        _presetChip(s.medicalPresetRecommended, MedicalField.presetRecommended),
        const SizedBox(width: 8),
        _presetChip(s.medicalPresetFull, MedicalField.presetFull),
      ],
    );
  }

  // ── 從系統健康資料匯入按鈕 ──
  Widget _buildHealthImportButton() {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.cyanAccent,
        side: const BorderSide(color: Colors.cyanAccent),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      onPressed: _importFromHealthConnect,
      icon: const Icon(Icons.download, size: 18),
      label: Text(S.of(context)!.medicalHealthImportButton, style: const TextStyle(fontSize: 13)),
    );
  }

  Future<void> _importFromHealthConnect() async {
    final health = Health();

    // Bug 13 Fix: 必須先呼叫 configure()，否則 Health Connect API 不會初始化
    await health.configure();

    // 要讀取的資料類型
    final types = <HealthDataType>[
      HealthDataType.HEIGHT,
      HealthDataType.WEIGHT,
      HealthDataType.BLOOD_TYPE,
    ];

    try {
      // ── 1. 檢查 Health Connect 是否可用 ──
      final status = await health.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        if (!mounted) return;
        // Health Connect 未安裝或不支援 → 引導用戶安裝
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(S.of(context)!.medicalHealthConnectRequired),
            content: Text(S.of(context)!.medicalHealthConnectInstallGuide),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.of(context)!.medicalHealthConnectDismiss),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  health.installHealthConnect();
                },
                child: Text(S.of(context)!.medicalHealthConnectInstall),
              ),
            ],
          ),
        );
        return;
      }

      // ── 2. 請求授權 ──
      final hasPermissions = await health.hasPermissions(types,
          permissions: types.map((_) => HealthDataAccess.READ).toList());
      if (hasPermissions != true) {
        final granted = await health.requestAuthorization(types,
            permissions: types.map((_) => HealthDataAccess.READ).toList());
        if (!granted) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(S.of(context)!.medicalHealthConnectAuthFail),
              content: Text(S.of(context)!.medicalHealthConnectAuthGuide),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(S.of(context)!.medicalHealthConnectDismiss),
                ),
              ],
            ),
          );
          return;
        }
      }

      // ── 3. 讀取最近 365 天的資料 ──
      final now = DateTime.now();
      final oneYearAgo = now.subtract(const Duration(days: 365));
      final healthData = await health.getHealthDataFromTypes(
        types: types,
        startTime: oneYearAgo,
        endTime: now,
      );

      if (healthData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context)!.medicalHealthConnectNoData),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ── 4. 取最新的各類型數據 ──
      int imported = 0;
      for (final dp in healthData.reversed) {
        switch (dp.type) {
          case HealthDataType.HEIGHT:
            final cm = (dp.value as NumericHealthValue).numericValue.toInt();
            if (cm > 0 && _card.heightCm == null) {
              _heightCtrl.text = cm.toString();
              _card.heightCm = cm;
              imported++;
            }
            break;
          case HealthDataType.WEIGHT:
            final kg = (dp.value as NumericHealthValue).numericValue.toInt();
            if (kg > 0 && _card.weightKg == null) {
              _weightCtrl.text = kg.toString();
              _card.weightKg = kg;
              imported++;
            }
            break;
          case HealthDataType.BLOOD_TYPE:
            final val = dp.value.toString();
            if (val.isNotEmpty && _card.bloodType.isEmpty) {
              final mapped = _mapBloodType(val);
              if (mapped != null) {
                _card.bloodType = mapped;
                imported++;
              }
            }
            break;
          default:
            break;
        }
      }

      if (mounted) {
        setState(() {}); // 刷新 UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imported > 0
                ? S.of(context)!.medicalHealthConnectImported(imported)
                : S.of(context)!.medicalHealthConnectNoNewData),
            backgroundColor: imported > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.medicalHealthConnectFailSnack(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String? _mapBloodType(String healthConnectValue) {
    final v = healthConnectValue.toUpperCase();
    const map = {
      'A_POSITIVE': 'A+',
      'A_NEGATIVE': 'A-',
      'B_POSITIVE': 'B+',
      'B_NEGATIVE': 'B-',
      'AB_POSITIVE': 'AB+',
      'AB_NEGATIVE': 'AB-',
      'O_POSITIVE': 'O+',
      'O_NEGATIVE': 'O-',
    };
    return map[v];
  }

  Widget _presetChip(String label, Set<String> preset) {
    // 檢查當前是否匹配此預設
    bool isActive = true;
    for (final f in MedicalField.allFields) {
      if ((_card.sosFlags[f] ?? false) != preset.contains(f)) {
        isActive = false;
        break;
      }
    }

    return GestureDetector(
      onTap: () => _applyPreset(preset, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.redAccent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.redAccent : Colors.white24,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.redAccent : Colors.white54,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── 區段標題 ──
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 12),
              child: Divider(color: Colors.white12),
            ),
          ),
        ],
      ),
    );
  }

  // ── SOS 廣播 toggle ──
  Widget _buildSosToggle(String field) {
    final isOn = _card.sosFlags[field] ?? false;
    return GestureDetector(
      onTap: () => setState(() => _card.sosFlags[field] = !isOn),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isOn
              ? Colors.redAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOn ? Icons.cell_tower : Icons.cell_tower,
              color: isOn ? Colors.redAccent : Colors.white24,
              size: 16,
            ),
            const SizedBox(width: 2),
            Text(
              isOn ? 'ON' : 'OFF',
              style: TextStyle(
                color: isOn ? Colors.redAccent : Colors.white24,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 通用文字欄位 ──
  Widget _buildTextField({
    required String field,
    String? label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: label ?? MedicalField.label(field),
                labelStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                prefixIcon: Icon(icon, color: Colors.white38, size: 18),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white12),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: const Color(0xFF1a1a2e),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildSosToggle(field),
          ),
        ],
      ),
    );
  }

  // ── 數字欄位 ──
  Widget _buildNumberField({
    required String field,
    String? label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: label ?? MedicalField.label(field),
                labelStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                prefixIcon: Icon(icon, color: Colors.white38, size: 18),
                suffixText: suffix,
                suffixStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white12),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: const Color(0xFF1a1a2e),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSosToggle(field),
        ],
      ),
    );
  }

  // ── 血型下拉選單 ──
  Widget _buildBloodTypeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value:
                  _bloodTypes.contains(_card.bloodType) ? _card.bloodType : '',
              dropdownColor: const Color(0xFF1a1a2e),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: S.of(context)!.medicalFieldBloodType,
                labelStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.bloodtype_outlined,
                    color: Colors.white38, size: 18),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white12),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: const Color(0xFF1a1a2e),
              ),
              items: _bloodTypes.map((bt) {
                return DropdownMenuItem(
                  value: bt,
                  child: Text(bt.isEmpty ? S.of(context)!.medicalBloodTypeNone : bt),
                );
              }).toList(),
              onChanged: (v) => setState(() => _card.bloodType = v ?? ''),
            ),
          ),
          const SizedBox(width: 8),
          _buildSosToggle(MedicalField.bloodType),
        ],
      ),
    );
  }

  // ── 過敏原區段（支援多筆）──
  Widget _buildAllergySection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_outlined,
                  color: Colors.white38, size: 18),
              const SizedBox(width: 8),
              Text(S.of(context)!.medicalAllergenLabel,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const Spacer(),
              _buildSosToggle(MedicalField.allergies),
            ],
          ),
          const SizedBox(height: 8),
          // 現有過敏條目
          ..._card.allergies.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${a.allergen} → ${a.reaction}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _card.allergies.removeAt(i)),
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 16),
                  ),
                ],
              ),
            );
          }),
          // 新增過敏原輸入
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _allergenCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: S.of(context)!.medicalAllergenHint,
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 12),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.redAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFF1a1a2e),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _reactionCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: S.of(context)!.medicalReactionHint,
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 12),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.redAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFF1a1a2e),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  final allergen = _allergenCtrl.text.trim();
                  final reaction = _reactionCtrl.text.trim();
                  if (allergen.isEmpty) return;
                  setState(() {
                    _card.allergies.add(AllergyEntry(
                      allergen: allergen,
                      reaction: reaction.isNotEmpty ? reaction : S.of(context)!.medicalReactionUnknown,
                    ));
                    _allergenCtrl.clear();
                    _reactionCtrl.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child:
                      const Icon(Icons.add, color: Colors.redAccent, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 緊急聯絡人 ──
  Widget _buildEmergencyContactSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ecPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: S.of(context)!.medicalEcPhoneLabel,
                    labelStyle:
                        const TextStyle(color: Colors.white38, fontSize: 13),
                    hintText: '0912-345-678',
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 13),
                    prefixIcon: const Icon(Icons.phone_outlined,
                        color: Colors.white38, size: 18),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.redAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: const Color(0xFF1a1a2e),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSosToggle(MedicalField.emergencyContact),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ecRelationCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: S.of(context)!.medicalEcRelationLabel,
                    labelStyle:
                        const TextStyle(color: Colors.white38, fontSize: 13),
                    hintText: S.of(context)!.medicalEcRelationHint,
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 13),
                    prefixIcon: const Icon(Icons.people_outline,
                        color: Colors.white38, size: 18),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.redAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: const Color(0xFF1a1a2e),
                  ),
                ),
              ),
              // 佔位，與電話欄的 toggle 對齊
              const SizedBox(width: 8),
              const SizedBox(width: 52),
            ],
          ),
        ],
      ),
    );
  }

  // ── 器官捐贈意願 ──
  Widget _buildOrganDonorField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volunteer_activism_outlined,
                      color: Colors.white38, size: 18),
                  const SizedBox(width: 12),
                  Text(S.of(context)!.medicalOrganDonorLabel,
                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const Spacer(),
                  DropdownButton<bool?>(
                    value: _card.organDonor,
                    dropdownColor: const Color(0xFF1a1a2e),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: [
                      DropdownMenuItem(value: null, child: Text(S.of(context)!.medicalOrganDonorNone)),
                      DropdownMenuItem(value: true, child: Text(S.of(context)!.medicalOrganDonorYes)),
                      DropdownMenuItem(value: false, child: Text(S.of(context)!.medicalOrganDonorNo)),
                    ],
                    onChanged: (v) => setState(() => _card.organDonor = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSosToggle(MedicalField.organDonor),
        ],
      ),
    );
  }
}
