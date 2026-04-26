import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/models/medical_card.dart';

void main() {
  group('MedicalCard — hasData', () {
    test('empty card: hasData is false', () {
      expect(MedicalCard().hasData, isFalse);
    });

    test('card with name: hasData is true', () {
      expect(MedicalCard(name: 'Alice').hasData, isTrue);
    });

    test('card with age: hasData is true', () {
      expect(MedicalCard(age: 30).hasData, isTrue);
    });

    test('card with bloodType: hasData is true', () {
      expect(MedicalCard(bloodType: 'O+').hasData, isTrue);
    });

    test('card with allergies: hasData is true', () {
      final card = MedicalCard(
        allergies: [AllergyEntry(allergen: 'penicillin', reaction: 'anaphylaxis')],
      );
      expect(card.hasData, isTrue);
    });

    test('card with emergency contact: hasData is true', () {
      final card = MedicalCard(
        emergencyContact: EmergencyContactData(phone: '0912345678', relation: 'Spouse'),
      );
      expect(card.hasData, isTrue);
    });
  });

  group('MedicalCard — Serialization Roundtrip', () {
    test('full card serialize → deserialize preserves all fields', () {
      final original = MedicalCard(
        name: 'Alice',
        age: 35,
        heightCm: 165,
        weightKg: 58,
        bloodType: 'O+',
        conditions: ['Diabetes', 'Hypertension'],
        allergies: [
          AllergyEntry(allergen: 'penicillin', reaction: 'anaphylaxis'),
          AllergyEntry(allergen: 'latex', reaction: 'hives'),
        ],
        medications: ['Metformin', 'Lisinopril'],
        emergencyContact: EmergencyContactData(phone: '0912345678', relation: 'Spouse'),
        organDonor: true,
        primaryLanguage: 'zh-TW',
        sosFlags: {
          MedicalField.name: true,
          MedicalField.age: false,
          MedicalField.heightCm: false,
          MedicalField.weightKg: false,
          MedicalField.bloodType: true,
          MedicalField.conditions: true,
          MedicalField.allergies: true,
          MedicalField.medications: false,
          MedicalField.emergencyContact: true,
          MedicalField.organDonor: false,
          MedicalField.primaryLanguage: true,
        },
      );

      final restored = MedicalCard.fromJsonString(original.toJsonString());

      expect(restored.name, equals('Alice'));
      expect(restored.age, equals(35));
      expect(restored.heightCm, equals(165));
      expect(restored.weightKg, equals(58));
      expect(restored.bloodType, equals('O+'));
      expect(restored.conditions, equals(['Diabetes', 'Hypertension']));
      expect(restored.allergies.length, equals(2));
      expect(restored.allergies[0].allergen, equals('penicillin'));
      expect(restored.allergies[1].allergen, equals('latex'));
      expect(restored.medications, equals(['Metformin', 'Lisinopril']));
      expect(restored.emergencyContact.phone, equals('0912345678'));
      expect(restored.emergencyContact.relation, equals('Spouse'));
      expect(restored.organDonor, isTrue);
      expect(restored.primaryLanguage, equals('zh-TW'));
    });

    test('sosFlags preserved through serialize → deserialize', () {
      final original = MedicalCard(
        name: 'Bob',
        sosFlags: {
          for (final f in MedicalField.allFields) f: false,
          MedicalField.name: true,
          MedicalField.bloodType: true,
        },
      );
      final restored = MedicalCard.fromJsonString(original.toJsonString());
      expect(restored.sosFlags[MedicalField.name], isTrue);
      expect(restored.sosFlags[MedicalField.bloodType], isTrue);
      expect(restored.sosFlags[MedicalField.age], isFalse);
    });

    test('empty card roundtrip', () {
      final restored = MedicalCard.fromJsonString(MedicalCard().toJsonString());
      expect(restored.hasData, isFalse);
      expect(restored.name, isEmpty);
      expect(restored.age, isNull);
    });

    test('multiple serialize/deserialize cycles are stable', () {
      final card = MedicalCard(name: 'Carol', bloodType: 'AB+');
      final json1 = card.toJsonString();
      final json2 = MedicalCard.fromJsonString(json1).toJsonString();
      expect(json1, equals(json2));
    });
  });

  group('MedicalCard — applyPreset', () {
    test('presetMinimal: only bloodType, allergies, primaryLanguage are true', () {
      final card = MedicalCard();
      card.applyPreset(MedicalField.presetMinimal);
      for (final f in MedicalField.allFields) {
        final expected = MedicalField.presetMinimal.contains(f);
        expect(card.sosFlags[f], equals(expected), reason: f);
      }
    });

    test('presetRecommended: includes name, bloodType, conditions, allergies, medications, primaryLanguage', () {
      final card = MedicalCard();
      card.applyPreset(MedicalField.presetRecommended);
      expect(card.sosFlags[MedicalField.name], isTrue);
      expect(card.sosFlags[MedicalField.bloodType], isTrue);
      expect(card.sosFlags[MedicalField.conditions], isTrue);
      expect(card.sosFlags[MedicalField.allergies], isTrue);
      expect(card.sosFlags[MedicalField.medications], isTrue);
      expect(card.sosFlags[MedicalField.primaryLanguage], isTrue);
      // age is NOT in recommended preset
      expect(card.sosFlags[MedicalField.age], isFalse);
    });

    test('presetFull: all 11 fields true', () {
      final card = MedicalCard();
      card.applyPreset(MedicalField.presetFull);
      for (final f in MedicalField.allFields) {
        expect(card.sosFlags[f], isTrue, reason: f);
      }
    });

    test('applyPreset does not modify field values, only sosFlags', () {
      final card = MedicalCard(name: 'Dave', age: 40);
      card.applyPreset(MedicalField.presetMinimal);
      expect(card.name, equals('Dave'));
      expect(card.age, equals(40));
    });
  });

  group('AllergyEntry', () {
    test('serialization roundtrip', () {
      final entry = AllergyEntry(allergen: 'shellfish', reaction: 'hives');
      final restored = AllergyEntry.fromJson(entry.toJson());
      expect(restored.allergen, equals('shellfish'));
      expect(restored.reaction, equals('hives'));
    });

    test('empty strings preserved', () {
      final entry = AllergyEntry(allergen: '', reaction: '');
      final restored = AllergyEntry.fromJson(entry.toJson());
      expect(restored.allergen, isEmpty);
      expect(restored.reaction, isEmpty);
    });
  });

  group('EmergencyContactData', () {
    test('isEmpty: true when both fields empty', () {
      expect(EmergencyContactData(phone: '', relation: '').isEmpty, isTrue);
    });

    test('isEmpty: false when phone is set', () {
      expect(EmergencyContactData(phone: '123', relation: '').isEmpty, isFalse);
    });

    test('isEmpty: false when relation is set', () {
      expect(EmergencyContactData(phone: '', relation: 'Parent').isEmpty, isFalse);
    });

    test('serialization roundtrip', () {
      final ec = EmergencyContactData(phone: '0912345678', relation: 'Parent');
      final restored = EmergencyContactData.fromJson(ec.toJson());
      expect(restored.phone, equals('0912345678'));
      expect(restored.relation, equals('Parent'));
    });
  });

  group('MedicalField — metadata', () {
    test('allFields has 11 items', () {
      expect(MedicalField.allFields.length, equals(11));
    });

    test('label returns non-empty string for each field', () {
      for (final f in MedicalField.allFields) {
        expect(MedicalField.label(f), isNotEmpty, reason: f);
      }
    });

    test('section returns non-empty string for each field', () {
      for (final f in MedicalField.allFields) {
        expect(MedicalField.section(f), isNotEmpty, reason: f);
      }
    });

    test('presetMinimal ⊂ allFields', () {
      for (final f in MedicalField.presetMinimal) {
        expect(MedicalField.allFields.contains(f), isTrue, reason: f);
      }
    });

    test('presetRecommended ⊂ allFields', () {
      for (final f in MedicalField.presetRecommended) {
        expect(MedicalField.allFields.contains(f), isTrue, reason: f);
      }
    });
  });
}
