// map_label_language.dart
//
// Phase 4：地圖 label 多語 resolver。
//
// 把 UI Locale 對應到 vector tile feature 的 name 欄位 fallback list，再產生
// Mapbox style "coalesce" expression 給 vector_tile_renderer 5.2.1 用。
//
// 解析規則對應企畫書 §8.2 / §8.4：
//   - zh_*：name:zh-Hant > name:zh > name > name_en > name:en
//   - en_*：name_en > name:en > name_int > name
//   - 支援的非中文語言：name:<lang> > name_en > name:en > name_int > name
//   - 不支援的語言：name_en > name:en > name_int > name（即 en 規則）
//
// 此 resolver 不接觸 BuildContext / Material；caller 自行從 Localizations.localeOf
// 取出 Locale 後再傳進來。

import 'dart:ui' show Locale;

/// MBTiles（OpenMapTiles 系）目前已知會帶 `name:<lang>` 的非中文語言代碼。
///
/// 中文系（`zh-Hant`、`zh-Hans`、`zh`）走獨立 zh 規則，不放在這個 set 裡。
///
/// 來源：OpenMapTiles schema "name:<lang>" 慣例語言。第一版以常數呈現，未來
/// 可改用 build-time script 從 metadata 對應；變更時請同步調整 §8.4 的 fallback
/// 期望。
const Set<String> _supportedNameLanguages = {
  'en',
  'ja',
  'ko',
  'fr',
  'de',
  'es',
  'it',
  'pt',
  'ru',
  'nl',
  'ar',
  'hi',
  'th',
  'vi',
  'tr',
  'pl',
  'sv',
  'da',
  'fi',
  'no',
  'cs',
  'el',
  'he',
  'id',
};

/// UI locale → 地圖 label 欄位 fallback。
class MapLabelLanguage {
  const MapLabelLanguage({
    required this.languageCode,
    required this.preferredFields,
  });

  /// 解析後的語言代碼（normalized；中文一律寫成 `zh-Hant`）。
  final String languageCode;

  /// 由前到後嘗試的 feature property 名稱。
  final List<String> preferredFields;

  /// 解析 [Locale] → [MapLabelLanguage]。
  ///
  /// 對於中文系（包含 `zh`、`zh_TW`、`zh_HK`、`zh_Hant`、`zh_CN`、`zh_Hans` 等），
  /// 一律 fallback 到繁體中文鏈：`name:zh-Hant` 優先（OpenMapTiles 對台港繁中
  /// 主要使用此欄位），再退到 `name:zh`、`name`，最後 latin。
  ///
  /// 對於英文系，使用 `name_en`（OpenMapTiles 早期欄位）優先，再退 `name:en` /
  /// `name_int` / `name`。
  ///
  /// 對於支援列表中的其他語言（如 `ja`、`ko`），使用 `name:<lang>` 優先，再退
  /// 英文鏈。
  ///
  /// 對於不在支援列表的語言，直接 fallback 至英文鏈。
  factory MapLabelLanguage.forLocale(Locale locale) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'zh') {
      return const MapLabelLanguage(
        languageCode: 'zh-Hant',
        preferredFields: [
          'name:zh-Hant',
          'name:zh',
          'name',
          'name_en',
          'name:en',
        ],
      );
    }
    if (lang == 'en') {
      return const MapLabelLanguage(
        languageCode: 'en',
        preferredFields: [
          'name_en',
          'name:en',
          'name_int',
          'name',
        ],
      );
    }
    if (_supportedNameLanguages.contains(lang)) {
      return MapLabelLanguage(
        languageCode: lang,
        preferredFields: [
          'name:$lang',
          'name_en',
          'name:en',
          'name_int',
          'name',
        ],
      );
    }
    // 不支援語言 → 走英文 fallback。languageCode 仍記原 locale 以便除錯。
    return MapLabelLanguage(
      languageCode: lang,
      preferredFields: const [
        'name_en',
        'name:en',
        'name_int',
        'name',
      ],
    );
  }

  /// 產出 Mapbox style "coalesce" expression：
  ///   ["coalesce", ["get", "field1"], ["get", "field2"], ...]
  ///
  /// 直接塞進 layer.layout.text-field；vector_tile_renderer 5.2.1 認得。
  List<dynamic> toCoalesceExpression() {
    return <dynamic>[
      'coalesce',
      for (final f in preferredFields) <dynamic>['get', f],
    ];
  }
}
