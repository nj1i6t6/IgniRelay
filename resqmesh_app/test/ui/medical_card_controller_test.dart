// medical_card_controller_test.dart
//
// Stage 2B：MedicalCardController 單元測試。
//
// 範圍：純同步表單編輯 command（preset / SOS flag / 過敏原增刪 / 血型 /
//   器捐）+ outcome sealed class。
//   - load / save / importFromHealthConnect 涉及 IdentityManager 金鑰、
//     MedicalCardRepo DB I/O 與 Health Connect 平台 channel，留 widget
//     integration / 實機測。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/models/medical_card.dart';
import 'package:ignirelay_app/app/services/medical_card_repo.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_controller.dart';

MedicalCardController _make() => MedicalCardController(
      repo: MedicalCardRepo(DatabaseHelper()),
      identity: IdentityManager(),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.testDatabasePathOverride = inMemoryDatabasePath;
    SharedPreferences.setMockInitialValues({});
  });

  group('MedicalCardController 初始 state', () {
    test('loading=true、card 為空白卡', () {
      final c = _make();
      addTearDown(c.dispose);

      expect(c.loading, isTrue);
      expect(c.saving, isFalse);
      expect(c.card.hasData, isFalse);
      expect(c.nameCtrl.text, isEmpty);
    });
  });

  group('preset 套用與判別', () {
    test('applyPreset 後 isPresetActive 對應該 preset 為 true，其它為 false', () {
      final c = _make();
      addTearDown(c.dispose);

      c.applyPreset(MedicalField.presetMinimal);
      expect(c.isPresetActive(MedicalField.presetMinimal), isTrue);
      expect(c.isPresetActive(MedicalField.presetFull), isFalse);

      c.applyPreset(MedicalField.presetFull);
      expect(c.isPresetActive(MedicalField.presetFull), isTrue);
      expect(c.isPresetActive(MedicalField.presetMinimal), isFalse);
    });

    test('toggleSosFlag 翻轉單一欄位 flag', () {
      final c = _make();
      addTearDown(c.dispose);

      final before = c.card.sosFlags[MedicalField.name] ?? false;
      c.toggleSosFlag(MedicalField.name);
      expect(c.card.sosFlags[MedicalField.name], !before);
    });
  });

  group('過敏原增刪', () {
    test('addAllergy 新增一筆並清空輸入框', () {
      final c = _make();
      addTearDown(c.dispose);

      c.allergenCtrl.text = '花生';
      c.reactionCtrl.text = '紅疹';
      c.addAllergy(c.allergenCtrl.text, c.reactionCtrl.text,
          fallbackReaction: '不明');

      expect(c.card.allergies.length, 1);
      expect(c.card.allergies.first.allergen, '花生');
      expect(c.card.allergies.first.reaction, '紅疹');
      expect(c.allergenCtrl.text, isEmpty);
      expect(c.reactionCtrl.text, isEmpty);
    });

    test('addAllergy reaction 為空時用 fallbackReaction', () {
      final c = _make();
      addTearDown(c.dispose);

      c.addAllergy('海鮮', '', fallbackReaction: '不明');
      expect(c.card.allergies.single.reaction, '不明');
    });

    test('addAllergy allergen 為空時 no-op', () {
      final c = _make();
      addTearDown(c.dispose);

      c.addAllergy('   ', '反應', fallbackReaction: '不明');
      expect(c.card.allergies, isEmpty);
    });

    test('removeAllergy 移除指定 index，越界則 no-op', () {
      final c = _make();
      addTearDown(c.dispose);

      c.addAllergy('A', 'a', fallbackReaction: '不明');
      c.addAllergy('B', 'b', fallbackReaction: '不明');
      c.removeAllergy(0);
      expect(c.card.allergies.single.allergen, 'B');

      c.removeAllergy(5); // 越界
      expect(c.card.allergies.length, 1);
    });
  });

  group('血型 / 器捐 setter', () {
    test('setBloodType / setOrganDonor 更新 card', () {
      final c = _make();
      addTearDown(c.dispose);

      c.setBloodType('O+');
      expect(c.card.bloodType, 'O+');

      c.setOrganDonor(true);
      expect(c.card.organDonor, isTrue);
      c.setOrganDonor(null);
      expect(c.card.organDonor, isNull);
    });
  });

  group('outcome sealed class', () {
    test('MedicalSaveOutcome 兩個 case 可 switch 窮舉', () {
      String label(MedicalSaveOutcome o) => switch (o) {
            MedicalSaveOk() => 'ok',
            MedicalSaveFail(:final error) => 'fail:$error',
          };
      expect(label(const MedicalSaveOk()), 'ok');
      expect(label(const MedicalSaveFail('boom')), 'fail:boom');
    });

    test('HealthImportOutcome 六個 case 可 switch 窮舉', () {
      String label(HealthImportOutcome o) => switch (o) {
            HealthImportSdkUnavailable() => 'sdk',
            HealthImportAuthDenied() => 'auth',
            HealthImportNoData() => 'nodata',
            HealthImportImported(:final count) => 'imported:$count',
            HealthImportNoNewData() => 'nonew',
            HealthImportFailure(:final error) => 'fail:$error',
          };
      expect(label(const HealthImportSdkUnavailable()), 'sdk');
      expect(label(const HealthImportAuthDenied()), 'auth');
      expect(label(const HealthImportNoData()), 'nodata');
      expect(label(const HealthImportImported(3)), 'imported:3');
      expect(label(const HealthImportNoNewData()), 'nonew');
      expect(label(const HealthImportFailure('x')), 'fail:x');
    });
  });
}
