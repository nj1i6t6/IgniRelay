// Phase 4：MapLabelLanguage resolver 與 coalesce expression 測試。
//
// 對應企畫書 §8.2 解析規則：
//   - zh_*：name:zh-Hant > name:zh > name > name_en > name:en
//   - en_*：name_en > name:en > name_int > name
//   - 支援的非中文語言：name:<lang> > name_en > name:en > name_int > name
//   - 不支援的語言：name_en > name:en > name_int > name

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/ui/theme/map_label_language.dart';

void main() {
  group('MapLabelLanguage.forLocale — 中文系列', () {
    test('zh_TW 走繁中 fallback 鏈', () {
      final lang = MapLabelLanguage.forLocale(const Locale('zh', 'TW'));
      expect(lang.languageCode, 'zh-Hant');
      expect(
        lang.preferredFields,
        ['name:zh-Hant', 'name:zh', 'name', 'name_en', 'name:en'],
      );
    });

    test('zh_HK 也走繁中 fallback 鏈', () {
      final lang = MapLabelLanguage.forLocale(const Locale('zh', 'HK'));
      expect(lang.preferredFields.first, 'name:zh-Hant');
    });

    test('zh_CN 也走繁中 fallback 鏈（先 name:zh-Hant，再退 name:zh / name）', () {
      // 設計原則：app 沒打簡體 asset，先優先繁中、再退 name:zh / name；
      // 雖然簡體使用者看到的會是繁中欄位內容，但比 raw `name`（可能是英文或其他）
      // 更接近期望。
      final lang = MapLabelLanguage.forLocale(const Locale('zh', 'CN'));
      expect(lang.preferredFields, [
        'name:zh-Hant',
        'name:zh',
        'name',
        'name_en',
        'name:en',
      ]);
    });

    test('純 zh（無 country code）也走繁中 fallback 鏈', () {
      final lang = MapLabelLanguage.forLocale(const Locale('zh'));
      expect(lang.preferredFields.first, 'name:zh-Hant');
    });
  });

  group('MapLabelLanguage.forLocale — 英文系列', () {
    test('en_US 走英文 fallback 鏈', () {
      final lang = MapLabelLanguage.forLocale(const Locale('en', 'US'));
      expect(lang.languageCode, 'en');
      expect(
        lang.preferredFields,
        ['name_en', 'name:en', 'name_int', 'name'],
      );
    });

    test('en_GB 走英文 fallback 鏈', () {
      final lang = MapLabelLanguage.forLocale(const Locale('en', 'GB'));
      expect(lang.preferredFields, [
        'name_en',
        'name:en',
        'name_int',
        'name',
      ]);
    });
  });

  group('MapLabelLanguage.forLocale — 支援的非中文語言', () {
    test('ja 走 name:ja → 英文 fallback', () {
      final lang = MapLabelLanguage.forLocale(const Locale('ja', 'JP'));
      expect(lang.languageCode, 'ja');
      expect(
        lang.preferredFields,
        ['name:ja', 'name_en', 'name:en', 'name_int', 'name'],
      );
    });

    test('fr_FR 走 name:fr → 英文 fallback', () {
      final lang = MapLabelLanguage.forLocale(const Locale('fr', 'FR'));
      expect(lang.preferredFields.first, 'name:fr');
      expect(lang.preferredFields, [
        'name:fr',
        'name_en',
        'name:en',
        'name_int',
        'name',
      ]);
    });
  });

  group('MapLabelLanguage.forLocale — 不支援的語言', () {
    test('未知語言 fallback 到英文鏈', () {
      // `xx` 不在 OpenMapTiles `name:<lang>` 慣例支援列表
      final lang = MapLabelLanguage.forLocale(const Locale('xx'));
      expect(
        lang.preferredFields,
        ['name_en', 'name:en', 'name_int', 'name'],
      );
    });
  });

  group('MapLabelLanguage.toCoalesceExpression', () {
    test('產生 Mapbox style coalesce 結構', () {
      const lang = MapLabelLanguage(
        languageCode: 'en',
        preferredFields: ['name_en', 'name:en', 'name'],
      );
      expect(lang.toCoalesceExpression(), [
        'coalesce',
        ['get', 'name_en'],
        ['get', 'name:en'],
        ['get', 'name'],
      ]);
    });

    test('中文 expression 對應 §8.4 規格', () {
      final lang = MapLabelLanguage.forLocale(const Locale('zh', 'TW'));
      expect(lang.toCoalesceExpression(), [
        'coalesce',
        ['get', 'name:zh-Hant'],
        ['get', 'name:zh'],
        ['get', 'name'],
        ['get', 'name_en'],
        ['get', 'name:en'],
      ]);
    });
  });
}
