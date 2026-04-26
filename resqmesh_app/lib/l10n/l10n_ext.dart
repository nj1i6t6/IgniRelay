// Stage 7：i18n 安全取值
//
// 目的：消除舊式 force-unwrap 強制解包風險（啟動冷路徑或 async UI 回呼時，
// MaterialApp 的 Localizations 可能尚未掛載到指定 BuildContext，原寫法會 throw）。
//
// 設計：
//   - 提供 `context.l10n` 擴充，回退到平台 locale 的對應資源；
//   - 不重建 i18n 架構，僅消除 timing 崩潰；
//   - 保持非 nullable 介面，呼叫端用法和原本 force-unwrap 寫法等價。
//
// 用法：
//   import 'package:ignirelay_app/l10n/l10n_ext.dart';
//   Text(context.l10n.appTitle);
//
// 不建議用法：在背景 isolate / 非 widget 樹的 BuildContext。
// 那種情境本來就不該取 S；改傳純字串或在 widget 樹發起。

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

S? _cachedFallback;

S _resolveFallback() {
  final cached = _cachedFallback;
  if (cached != null) return cached;
  final platformLocale = PlatformDispatcher.instance.locale;
  final locale =
      platformLocale.languageCode == 'en' ? const Locale('en') : const Locale('zh');
  return _cachedFallback = lookupS(locale);
}

extension BuildContextL10n on BuildContext {
  /// 安全取得 i18n 資源；MaterialApp 尚未就緒時回退平台預設語系。
  ///
  /// 取代舊版 force-unwrap 寫法，呼叫端介面不變。
  S get l10n => S.of(this) ?? _resolveFallback();
}
