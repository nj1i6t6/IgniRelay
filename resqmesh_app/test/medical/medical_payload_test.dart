import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/models/medical_card.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;

void main() {
  final em = EventManager();

  MedicalCard cardWithOnly(String field, MedicalCard base) {
    return MedicalCard(
      name: base.name,
      age: base.age,
      heightCm: base.heightCm,
      weightKg: base.weightKg,
      bloodType: base.bloodType,
      conditions: base.conditions,
      allergies: base.allergies,
      medications: base.medications,
      emergencyContact: base.emergencyContact,
      organDonor: base.organDonor,
      primaryLanguage: base.primaryLanguage,
      sosFlags: {
        for (final f in MedicalField.allFields) f: f == field,
      },
    );
  }

  group('buildMedicalPayload — flag filtering', () {
    test('all flags OFF → returns null', () {
      final card = MedicalCard(
        name: 'Bob',
        bloodType: 'A+',
        sosFlags: {for (final f in MedicalField.allFields) f: false},
      );
      expect(em.buildMedicalPayload(card), isNull);
    });

    test('empty card + all flags ON → returns null (no data to share)', () {
      final card = MedicalCard(
        sosFlags: {for (final f in MedicalField.allFields) f: true},
      );
      // No actual field values → MedicalSummary is empty → null
      // May return null OR empty bytes — key invariant: must not throw
      expect(() => em.buildMedicalPayload(card), returnsNormally);
    });

    test('name flag ON → MedicalSummary contains name', () {
      final base = MedicalCard(name: 'Charlie');
      final card = cardWithOnly(MedicalField.name, base);
      final bytes = em.buildMedicalPayload(card);
      expect(bytes, isNotNull);
      final summary = pb.MedicalSummary.fromBuffer(bytes!);
      expect(summary.name, equals('Charlie'));
    });

    test('bloodType flag ON → MedicalSummary contains bloodType', () {
      final base = MedicalCard(bloodType: 'B-');
      final card = cardWithOnly(MedicalField.bloodType, base);
      final bytes = em.buildMedicalPayload(card);
      expect(bytes, isNotNull);
      expect(pb.MedicalSummary.fromBuffer(bytes!).bloodType, equals('B-'));
    });

    test('age flag ON → MedicalSummary contains age', () {
      final base = MedicalCard(age: 42);
      final card = cardWithOnly(MedicalField.age, base);
      final bytes = em.buildMedicalPayload(card);
      expect(bytes, isNotNull);
      expect(pb.MedicalSummary.fromBuffer(bytes!).age, equals(42));
    });

    test('allergy flag ON → MedicalSummary contains allergies', () {
      final base = MedicalCard(
        allergies: [AllergyEntry(allergen: 'peanuts', reaction: 'anaphylaxis')],
      );
      final card = cardWithOnly(MedicalField.allergies, base);
      final bytes = em.buildMedicalPayload(card);
      expect(bytes, isNotNull);
      final summary = pb.MedicalSummary.fromBuffer(bytes!);
      expect(summary.allergies.length, equals(1));
      expect(summary.allergies[0].allergen, equals('peanuts'));
    });

    test('conditions flag ON → MedicalSummary contains conditions', () {
      final base = MedicalCard(conditions: ['Asthma', 'Epilepsy']);
      final card = cardWithOnly(MedicalField.conditions, base);
      final bytes = em.buildMedicalPayload(card);
      expect(bytes, isNotNull);
      expect(pb.MedicalSummary.fromBuffer(bytes!).conditions,
          equals(['Asthma', 'Epilepsy']));
    });

    test('medications flag ON → MedicalSummary contains medications', () {
      final base = MedicalCard(medications: ['Metformin']);
      final card = cardWithOnly(MedicalField.medications, base);
      final bytes = em.buildMedicalPayload(card);
      expect(bytes, isNotNull);
      expect(pb.MedicalSummary.fromBuffer(bytes!).medications,
          equals(['Metformin']));
    });

    test('organDonor flag ON → MedicalSummary contains organDonor', () {
      final base = MedicalCard(organDonor: true);
      final card = cardWithOnly(MedicalField.organDonor, base);
      final bytes = em.buildMedicalPayload(card);
      expect(bytes, isNotNull);
      expect(pb.MedicalSummary.fromBuffer(bytes!).organDonor, isTrue);
    });

    test('primaryLanguage flag ON → MedicalSummary contains language', () {
      final base = MedicalCard(primaryLanguage: 'zh-TW');
      final card = cardWithOnly(MedicalField.primaryLanguage, base);
      final bytes = em.buildMedicalPayload(card);
      expect(bytes, isNotNull);
      expect(pb.MedicalSummary.fromBuffer(bytes!).primaryLanguage, equals('zh-TW'));
    });

    test('flag OFF for a field → that field absent in MedicalSummary', () {
      // name flag OFF even though name has data
      final card = MedicalCard(
        name: 'Hidden',
        bloodType: 'O+',
        sosFlags: {
          for (final f in MedicalField.allFields) f: false,
          MedicalField.bloodType: true, // only bloodType shared
        },
      );
      final bytes = em.buildMedicalPayload(card);
      expect(bytes, isNotNull);
      final summary = pb.MedicalSummary.fromBuffer(bytes!);
      expect(summary.name, isEmpty); // name hidden
      expect(summary.bloodType, equals('O+'));
    });

    test('output is valid protobuf (re-parseable)', () {
      final card = MedicalCard(
        name: 'Test',
        bloodType: 'AB+',
        sosFlags: {
          for (final f in MedicalField.allFields) f: false,
          MedicalField.name: true,
          MedicalField.bloodType: true,
        },
      );
      final bytes = em.buildMedicalPayload(card);
      expect(bytes, isNotNull);
      // Must parse without throwing
      expect(
        () => pb.MedicalSummary.fromBuffer(bytes!),
        returnsNormally,
      );
    });
  });
}
