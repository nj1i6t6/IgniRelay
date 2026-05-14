import 'package:flutter/widgets.dart';
import 'package:health/health.dart';

import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/models/medical_card.dart';
import 'package:ignirelay_app/app/services/medical_card_repo.dart';

// =============================================================================
// MedicalCardController — Stage 2B：由 medical_card_screen god file 拆出。
//
// 持有醫療卡表單 state（[MedicalCard] + 11 個 TextEditingController）、
// load / save / 預設套用 / SOS flag toggle / 過敏原增刪 / Health Connect 匯入。
//
// UI 端（thin shell + section widgets）只讀 state、呼叫 command；對話框 /
// snackbar 等視覺回饋留在 widget，由 command 回傳的 outcome 決定。
// =============================================================================

/// `save()` 的結果。
sealed class MedicalSaveOutcome {
  const MedicalSaveOutcome();
}

class MedicalSaveOk extends MedicalSaveOutcome {
  const MedicalSaveOk();
}

class MedicalSaveFail extends MedicalSaveOutcome {
  const MedicalSaveFail(this.error);
  final String error;
}

/// `importFromHealthConnect()` 的結果。對話框 / snackbar 由 widget 依此決定。
sealed class HealthImportOutcome {
  const HealthImportOutcome();
}

/// Health Connect 未安裝 / 不支援 — widget 應引導安裝。
class HealthImportSdkUnavailable extends HealthImportOutcome {
  const HealthImportSdkUnavailable();
}

/// 使用者未授權讀取。
class HealthImportAuthDenied extends HealthImportOutcome {
  const HealthImportAuthDenied();
}

/// 查無任何健康資料。
class HealthImportNoData extends HealthImportOutcome {
  const HealthImportNoData();
}

/// 成功匯入 [count] 個欄位。
class HealthImportImported extends HealthImportOutcome {
  const HealthImportImported(this.count);
  final int count;
}

/// 有資料但都已填過，沒有可覆寫的新欄位。
class HealthImportNoNewData extends HealthImportOutcome {
  const HealthImportNoNewData();
}

/// 匯入過程丟例外。
class HealthImportFailure extends HealthImportOutcome {
  const HealthImportFailure(this.error);
  final String error;
}

class MedicalCardController extends ChangeNotifier {
  MedicalCardController({
    required MedicalCardRepo repo,
    required IdentityManager identity,
  })  : _repo = repo,
        _identity = identity;

  final MedicalCardRepo _repo;
  final IdentityManager _identity;

  /// 血型下拉選項（含空字串＝未指定）。
  static const List<String> bloodTypes = [
    '',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  // ── 文字欄位控制器（表單 state 的一部分，由 controller 持有）──
  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final conditionsCtrl = TextEditingController();
  final medicationsCtrl = TextEditingController();
  final allergenCtrl = TextEditingController();
  final reactionCtrl = TextEditingController();
  final ecPhoneCtrl = TextEditingController();
  final ecRelationCtrl = TextEditingController();
  final languageCtrl = TextEditingController();

  MedicalCard _card = MedicalCard();
  bool _loading = true;
  bool _saving = false;
  bool _disposed = false;

  MedicalCard get card => _card;
  bool get loading => _loading;
  bool get saving => _saving;

  // ── 載入 / 儲存 ────────────────────────────────────────────

  Future<void> load() async {
    final pubKey = await _identity.getPublicKeyBytes();
    final json = await _repo.getMedicalCard(pubKey);
    if (_disposed) return;
    _card = json != null ? MedicalCard.fromJsonString(json) : MedicalCard();
    _syncControllersFromCard();
    _loading = false;
    notifyListeners();
  }

  Future<MedicalSaveOutcome> save() async {
    _syncCardFromControllers();
    _saving = true;
    notifyListeners();
    try {
      final pubKey = await _identity.getPublicKeyBytes();
      await _repo.saveMedicalCard(pubKey, _card.toJsonString());
      return const MedicalSaveOk();
    } catch (e) {
      return MedicalSaveFail(e.toString());
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _syncControllersFromCard() {
    nameCtrl.text = _card.name;
    ageCtrl.text = _card.age?.toString() ?? '';
    heightCtrl.text = _card.heightCm?.toString() ?? '';
    weightCtrl.text = _card.weightKg?.toString() ?? '';
    conditionsCtrl.text = _card.conditions.join('、');
    medicationsCtrl.text = _card.medications.join('、');
    ecPhoneCtrl.text = _card.emergencyContact.phone;
    ecRelationCtrl.text = _card.emergencyContact.relation;
    languageCtrl.text = _card.primaryLanguage;
  }

  void _syncCardFromControllers() {
    _card.name = nameCtrl.text.trim();
    _card.age = int.tryParse(ageCtrl.text.trim());
    _card.heightCm = int.tryParse(heightCtrl.text.trim());
    _card.weightKg = int.tryParse(weightCtrl.text.trim());
    _card.conditions = _splitList(conditionsCtrl.text);
    _card.medications = _splitList(medicationsCtrl.text);
    _card.emergencyContact.phone = ecPhoneCtrl.text.trim();
    _card.emergencyContact.relation = ecRelationCtrl.text.trim();
    _card.primaryLanguage = languageCtrl.text.trim();
  }

  List<String> _splitList(String raw) => raw
      .split(RegExp(r'[、,，]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  // ── 表單編輯 command ──────────────────────────────────────

  void applyPreset(Set<String> preset) {
    _card.applyPreset(preset);
    notifyListeners();
  }

  /// 當前 SOS flag 組合是否正好等於 [preset]。
  bool isPresetActive(Set<String> preset) {
    for (final f in MedicalField.allFields) {
      if ((_card.sosFlags[f] ?? false) != preset.contains(f)) return false;
    }
    return true;
  }

  void toggleSosFlag(String field) {
    _card.sosFlags[field] = !(_card.sosFlags[field] ?? false);
    notifyListeners();
  }

  void setBloodType(String value) {
    _card.bloodType = value;
    notifyListeners();
  }

  void setOrganDonor(bool? value) {
    _card.organDonor = value;
    notifyListeners();
  }

  /// 新增一筆過敏原。[allergen] 為空則 no-op；[reaction] 為空時用
  /// [fallbackReaction]（由 widget 傳入，已 l10n）。
  void addAllergy(String allergen, String reaction,
      {required String fallbackReaction}) {
    final a = allergen.trim();
    if (a.isEmpty) return;
    final r = reaction.trim();
    _card.allergies
        .add(AllergyEntry(allergen: a, reaction: r.isNotEmpty ? r : fallbackReaction));
    allergenCtrl.clear();
    reactionCtrl.clear();
    notifyListeners();
  }

  void removeAllergy(int index) {
    if (index < 0 || index >= _card.allergies.length) return;
    _card.allergies.removeAt(index);
    notifyListeners();
  }

  // ── Health Connect 匯入 ───────────────────────────────────

  Future<HealthImportOutcome> importFromHealthConnect() async {
    final health = Health();
    await health.configure();

    const types = <HealthDataType>[
      HealthDataType.HEIGHT,
      HealthDataType.WEIGHT,
      HealthDataType.BLOOD_TYPE,
    ];

    try {
      final status = await health.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        return const HealthImportSdkUnavailable();
      }

      final perms = types.map((_) => HealthDataAccess.READ).toList();
      final hasPermissions =
          await health.hasPermissions(types, permissions: perms);
      if (hasPermissions != true) {
        final granted =
            await health.requestAuthorization(types, permissions: perms);
        if (!granted) return const HealthImportAuthDenied();
      }

      final now = DateTime.now();
      final healthData = await health.getHealthDataFromTypes(
        types: types,
        startTime: now.subtract(const Duration(days: 365)),
        endTime: now,
      );
      if (healthData.isEmpty) return const HealthImportNoData();

      var imported = 0;
      for (final dp in healthData.reversed) {
        switch (dp.type) {
          case HealthDataType.HEIGHT:
            final cm = (dp.value as NumericHealthValue).numericValue.toInt();
            if (cm > 0 && _card.heightCm == null) {
              heightCtrl.text = cm.toString();
              _card.heightCm = cm;
              imported++;
            }
            break;
          case HealthDataType.WEIGHT:
            final kg = (dp.value as NumericHealthValue).numericValue.toInt();
            if (kg > 0 && _card.weightKg == null) {
              weightCtrl.text = kg.toString();
              _card.weightKg = kg;
              imported++;
            }
            break;
          case HealthDataType.BLOOD_TYPE:
            final mapped = _mapBloodType(dp.value.toString());
            if (mapped != null && _card.bloodType.isEmpty) {
              _card.bloodType = mapped;
              imported++;
            }
            break;
          default:
            break;
        }
      }

      if (imported > 0) {
        notifyListeners();
        return HealthImportImported(imported);
      }
      return const HealthImportNoNewData();
    } catch (e) {
      return HealthImportFailure(e.toString());
    }
  }

  /// 引導使用者安裝 Health Connect（由 widget 在 [HealthImportSdkUnavailable]
  /// 對話框內呼叫）。
  Future<void> installHealthConnect() async {
    final health = Health();
    await health.configure();
    await health.installHealthConnect();
  }

  String? _mapBloodType(String healthConnectValue) {
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
    return map[healthConnectValue.toUpperCase()];
  }

  @override
  void dispose() {
    _disposed = true;
    nameCtrl.dispose();
    ageCtrl.dispose();
    heightCtrl.dispose();
    weightCtrl.dispose();
    conditionsCtrl.dispose();
    medicationsCtrl.dispose();
    allergenCtrl.dispose();
    reactionCtrl.dispose();
    ecPhoneCtrl.dispose();
    ecRelationCtrl.dispose();
    languageCtrl.dispose();
    super.dispose();
  }
}
