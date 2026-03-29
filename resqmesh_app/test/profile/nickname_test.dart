// nickname_test.dart
//
// 測試暱稱功能：
// - SharedPreferences 讀寫
// - 空暱稱 fallback 為「匿名用戶」
// - 暱稱更新後可正確讀取

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Nickname — SharedPreferences', () {
    test('empty nickname falls back to 匿名用戶', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final nickname = prefs.getString('nickname') ?? '';
      final display = nickname.isNotEmpty ? nickname : '匿名用戶';
      expect(display, equals('匿名用戶'));
    });

    test('saved nickname is retrievable', () async {
      SharedPreferences.setMockInitialValues({'nickname': '小明'});
      final prefs = await SharedPreferences.getInstance();
      final nickname = prefs.getString('nickname') ?? '';
      expect(nickname, equals('小明'));
    });

    test('nickname can be updated', () async {
      SharedPreferences.setMockInitialValues({'nickname': '舊名'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nickname'), equals('舊名'));

      await prefs.setString('nickname', '新名');
      expect(prefs.getString('nickname'), equals('新名'));
    });

    test('nickname can be cleared to empty', () async {
      SharedPreferences.setMockInitialValues({'nickname': '有名字'});
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('nickname', '');
      final nickname = prefs.getString('nickname') ?? '';
      final display = nickname.isNotEmpty ? nickname : '匿名用戶';
      expect(display, equals('匿名用戶'));
    });

    test('nickname with max length 20 chars', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final longName = '一' * 20; // 20 Chinese characters
      await prefs.setString('nickname', longName);
      expect(prefs.getString('nickname')?.length, equals(20));
    });
  });
}
