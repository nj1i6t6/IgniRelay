import 'dart:convert';

/// 醫療卡欄位 key 定義
class MedicalField {
  static const String name = 'name';
  static const String age = 'age';
  static const String heightCm = 'height_cm';
  static const String weightKg = 'weight_kg';
  static const String bloodType = 'blood_type';
  static const String conditions = 'conditions';
  static const String allergies = 'allergies';
  static const String medications = 'medications';
  static const String emergencyContact = 'emergency_contact';
  static const String organDonor = 'organ_donor';
  static const String primaryLanguage = 'primary_language';

  static const List<String> allFields = [
    name,
    age,
    heightCm,
    weightKg,
    bloodType,
    conditions,
    allergies,
    medications,
    emergencyContact,
    organDonor,
    primaryLanguage,
  ];

  /// 欄位中文名稱
  static String label(String field) {
    switch (field) {
      case name:
        return '姓名';
      case age:
        return '年齡';
      case heightCm:
        return '身高 (cm)';
      case weightKg:
        return '體重 (kg)';
      case bloodType:
        return '血型';
      case conditions:
        return '醫療狀況';
      case allergies:
        return '過敏原';
      case medications:
        return '目前藥物';
      case emergencyContact:
        return '緊急聯絡人';
      case organDonor:
        return '器官捐贈意願';
      case primaryLanguage:
        return '主要語言';
      default:
        return field;
    }
  }

  /// 欄位所屬區段
  static String section(String field) {
    switch (field) {
      case name:
      case age:
      case heightCm:
      case weightKg:
      case bloodType:
        return '基本生理';
      case conditions:
      case allergies:
      case medications:
        return '醫療背景';
      case emergencyContact:
      case organDonor:
      case primaryLanguage:
        return '急救資訊';
      default:
        return '';
    }
  }

  /// 「最小揭露」預設：血型、過敏原、主要語言
  static const Set<String> presetMinimal = {
    bloodType,
    allergies,
    primaryLanguage,
  };

  /// 「建議設定」預設：血型、醫療狀況、過敏原、目前藥物、主要語言、姓名
  static const Set<String> presetRecommended = {
    name,
    bloodType,
    conditions,
    allergies,
    medications,
    primaryLanguage,
  };

  /// 「全部分享」預設：全部 11 個欄位
  static final Set<String> presetFull = Set.from(allFields);
}

/// 過敏原條目
class AllergyEntry {
  String allergen;
  String reaction;

  AllergyEntry({required this.allergen, required this.reaction});

  Map<String, dynamic> toJson() => {
        'allergen': allergen,
        'reaction': reaction,
      };

  factory AllergyEntry.fromJson(Map<String, dynamic> json) => AllergyEntry(
        allergen: json['allergen'] as String? ?? '',
        reaction: json['reaction'] as String? ?? '',
      );
}

/// 緊急聯絡人
class EmergencyContactData {
  String phone;
  String relation;

  EmergencyContactData({required this.phone, required this.relation});

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'relation': relation,
      };

  factory EmergencyContactData.fromJson(Map<String, dynamic> json) =>
      EmergencyContactData(
        phone: json['phone'] as String? ?? '',
        relation: json['relation'] as String? ?? '',
      );

  bool get isEmpty => phone.isEmpty && relation.isEmpty;
}

/// 完整醫療卡資料模型
/// 每個欄位都帶有 sos flag 控制是否在 SOS 廣播時附帶
class MedicalCard {
  String name;
  int? age;
  int? heightCm;
  int? weightKg;
  String bloodType;
  List<String> conditions;
  List<AllergyEntry> allergies;
  List<String> medications;
  EmergencyContactData emergencyContact;
  bool? organDonor;
  String primaryLanguage;

  /// 每個欄位是否在 SOS 廣播時附帶 (key → bool)
  Map<String, bool> sosFlags;

  MedicalCard({
    this.name = '',
    this.age,
    this.heightCm,
    this.weightKg,
    this.bloodType = '',
    List<String>? conditions,
    List<AllergyEntry>? allergies,
    List<String>? medications,
    EmergencyContactData? emergencyContact,
    this.organDonor,
    this.primaryLanguage = '',
    Map<String, bool>? sosFlags,
  })  : conditions = conditions ?? [],
        allergies = allergies ?? [],
        medications = medications ?? [],
        emergencyContact =
            emergencyContact ?? EmergencyContactData(phone: '', relation: ''),
        sosFlags = sosFlags ??
            {for (final f in MedicalField.allFields)
              f: MedicalField.presetRecommended.contains(f)};

  /// 是否有任何資料已填入
  bool get hasData =>
      name.isNotEmpty ||
      age != null ||
      heightCm != null ||
      weightKg != null ||
      bloodType.isNotEmpty ||
      conditions.isNotEmpty ||
      allergies.isNotEmpty ||
      medications.isNotEmpty ||
      !emergencyContact.isEmpty ||
      organDonor != null ||
      primaryLanguage.isNotEmpty;

  /// 序列化為 JSON 字串 (存入 SQLite)
  String toJsonString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
        MedicalField.name: {'value': name, 'sos': sosFlags[MedicalField.name] ?? false},
        MedicalField.age: {'value': age, 'sos': sosFlags[MedicalField.age] ?? false},
        MedicalField.heightCm: {'value': heightCm, 'sos': sosFlags[MedicalField.heightCm] ?? false},
        MedicalField.weightKg: {'value': weightKg, 'sos': sosFlags[MedicalField.weightKg] ?? false},
        MedicalField.bloodType: {'value': bloodType, 'sos': sosFlags[MedicalField.bloodType] ?? false},
        MedicalField.conditions: {'value': conditions, 'sos': sosFlags[MedicalField.conditions] ?? false},
        MedicalField.allergies: {
          'value': allergies.map((a) => a.toJson()).toList(),
          'sos': sosFlags[MedicalField.allergies] ?? false,
        },
        MedicalField.medications: {'value': medications, 'sos': sosFlags[MedicalField.medications] ?? false},
        MedicalField.emergencyContact: {
          'value': emergencyContact.toJson(),
          'sos': sosFlags[MedicalField.emergencyContact] ?? false,
        },
        MedicalField.organDonor: {'value': organDonor, 'sos': sosFlags[MedicalField.organDonor] ?? false},
        MedicalField.primaryLanguage: {
          'value': primaryLanguage,
          'sos': sosFlags[MedicalField.primaryLanguage] ?? false,
        },
      };

  /// 從 JSON 字串還原
  factory MedicalCard.fromJsonString(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return MedicalCard.fromJson(map);
  }

  factory MedicalCard.fromJson(Map<String, dynamic> json) {
    dynamic getValue(String key) => (json[key] as Map<String, dynamic>?)?['value'];
    bool getSos(String key) => (json[key] as Map<String, dynamic>?)?['sos'] as bool? ?? false;

    final sosFlags = <String, bool>{};
    for (final f in MedicalField.allFields) {
      sosFlags[f] = getSos(f);
    }

    final allergiesRaw = getValue(MedicalField.allergies);
    final allergies = allergiesRaw is List
        ? allergiesRaw
            .map((a) => AllergyEntry.fromJson(a as Map<String, dynamic>))
            .toList()
        : <AllergyEntry>[];

    final conditionsRaw = getValue(MedicalField.conditions);
    final conditions = conditionsRaw is List
        ? conditionsRaw.cast<String>()
        : <String>[];

    final medsRaw = getValue(MedicalField.medications);
    final medications = medsRaw is List ? medsRaw.cast<String>() : <String>[];

    final ecRaw = getValue(MedicalField.emergencyContact);
    final ec = ecRaw is Map<String, dynamic>
        ? EmergencyContactData.fromJson(ecRaw)
        : EmergencyContactData(phone: '', relation: '');

    return MedicalCard(
      name: getValue(MedicalField.name) as String? ?? '',
      age: getValue(MedicalField.age) as int?,
      heightCm: getValue(MedicalField.heightCm) as int?,
      weightKg: getValue(MedicalField.weightKg) as int?,
      bloodType: getValue(MedicalField.bloodType) as String? ?? '',
      conditions: conditions,
      allergies: allergies,
      medications: medications,
      emergencyContact: ec,
      organDonor: getValue(MedicalField.organDonor) as bool?,
      primaryLanguage: getValue(MedicalField.primaryLanguage) as String? ?? '',
      sosFlags: sosFlags,
    );
  }

  /// 套用快速預設 (只更新 sosFlags，不動資料)
  void applyPreset(Set<String> preset) {
    for (final f in MedicalField.allFields) {
      sosFlags[f] = preset.contains(f);
    }
  }
}
