// health_import_test.dart
//
// 測試 Health Connect 血型映射邏輯
// 不需要實機或 Health Connect API，純邏輯測試

import 'package:flutter_test/flutter_test.dart';

/// 從 medical_card_screen.dart 提取的映射邏輯（測試用副本）
String? mapBloodType(String healthConnectValue) {
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

void main() {
  group('Health Connect — Blood Type Mapping', () {
    test('A_POSITIVE → A+', () {
      expect(mapBloodType('A_POSITIVE'), equals('A+'));
    });

    test('A_NEGATIVE → A-', () {
      expect(mapBloodType('A_NEGATIVE'), equals('A-'));
    });

    test('B_POSITIVE → B+', () {
      expect(mapBloodType('B_POSITIVE'), equals('B+'));
    });

    test('B_NEGATIVE → B-', () {
      expect(mapBloodType('B_NEGATIVE'), equals('B-'));
    });

    test('AB_POSITIVE → AB+', () {
      expect(mapBloodType('AB_POSITIVE'), equals('AB+'));
    });

    test('AB_NEGATIVE → AB-', () {
      expect(mapBloodType('AB_NEGATIVE'), equals('AB-'));
    });

    test('O_POSITIVE → O+', () {
      expect(mapBloodType('O_POSITIVE'), equals('O+'));
    });

    test('O_NEGATIVE → O-', () {
      expect(mapBloodType('O_NEGATIVE'), equals('O-'));
    });

    test('case insensitive mapping', () {
      expect(mapBloodType('a_positive'), equals('A+'));
      expect(mapBloodType('o_negative'), equals('O-'));
    });

    test('unknown value returns null', () {
      expect(mapBloodType('UNKNOWN'), isNull);
      expect(mapBloodType(''), isNull);
      expect(mapBloodType('XYZABC'), isNull);
    });
  });
}
