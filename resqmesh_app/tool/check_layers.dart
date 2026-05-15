// 烽傳 Ignirelay layer-boundary checker.
//
// 強制 platform / app / ui 三層的 import 規則（v0.2.5 Stage 3 起共 6 條）：
//   - lib/ui/**       禁止 import lib/platform/**
//   - lib/app/**      禁止 import lib/ui/**
//   - lib/ui/**       禁止 import lib/app/mesh/**
//   - lib/ui/**       禁止 import lib/app/proto/**
//   - lib/ui/**       禁止 import lib/app/db/**
//   - lib/platform/** 禁止 import lib/app/**
//
// 另外強制「UI 不得直接建構 app-layer 依賴」的符號規則：
//   - lib/ui/**   禁止直接呼叫 facade / repo / manager / legacy singleton
//                 的建構式（IdentityManager / NegotiationManager /
//                 NegotiationRepo / MatchRepository / EventManager /
//                 MeshEventHandler / DatabaseHelper / LocationService /
//                 ChatService）。唯一允許的建構點是 main.dart 的 Provider
//                 wiring；UI 一律 context.read<T>() 或由 controller 建構式
//                 注入。清單見 `_uiForbiddenConstructors`。
//
// 例外清單：`_exceptions`。若某條規則對某檔為「已知且有理由的」違規，
// 在 `_exceptions` 加一筆（含 reason），掃描時會跳過。`--warn` 模式會列出
// 被跳過的例外以供審視。v0.2.5 完成後此清單預期為空。
//
// 使用：
//   dart run tool/check_layers.dart                   檢查並與 baseline 比對，
//                                                    新增違規即 exit 1
//   dart run tool/check_layers.dart --warn            僅印出，不 fail（含例外清單）
//   dart run tool/check_layers.dart --strict          忽略 baseline，任何違規都 fail
//   dart run tool/check_layers.dart --update-baseline 以當前狀態重寫 baseline
//
// Baseline 檔：tool/layer_violations_baseline.txt
// 每行格式 `<rule>\t<file>\t<detail>`（file 與 line 無關，避免搬檔即破壞 baseline）。
//
// 契約：計畫 Refactoring-0.2.0-plan.md L110「違反 → build fail」。
// Stage 1 時既有 4 筆違規已寫入 baseline，Stage 4a/4d/5 清除時須同步移除 baseline 條目
// （或跑 `--update-baseline` 重建）。v0.2.5 Stage 3 起 baseline 已清空，CI 以
// `--strict` 作為最終閘門。

import 'dart:io';

const _package = 'ignirelay_app';
const _baselinePath = 'tool/layer_violations_baseline.txt';

class _Rule {
  final String name;
  final String sourcePrefix;
  final String forbiddenPrefix;

  const _Rule({
    required this.name,
    required this.sourcePrefix,
    required this.forbiddenPrefix,
  });
}

const _rules = <_Rule>[
  _Rule(
    name: 'ui-cannot-import-platform',
    sourcePrefix: 'lib/ui/',
    forbiddenPrefix: 'lib/platform/',
  ),
  _Rule(
    name: 'app-cannot-import-ui',
    sourcePrefix: 'lib/app/',
    forbiddenPrefix: 'lib/ui/',
  ),
  // v0.2.5 Stage 3：UI 與協定 / mesh / DB 解耦，跨層存取一律走 app/ 的 facade。
  _Rule(
    name: 'ui-cannot-import-mesh',
    sourcePrefix: 'lib/ui/',
    forbiddenPrefix: 'lib/app/mesh/',
  ),
  _Rule(
    name: 'ui-cannot-import-proto',
    sourcePrefix: 'lib/ui/',
    forbiddenPrefix: 'lib/app/proto/',
  ),
  _Rule(
    name: 'ui-cannot-import-db',
    sourcePrefix: 'lib/ui/',
    forbiddenPrefix: 'lib/app/db/',
  ),
  // platform/ 是純 native adapter，不得反向依賴 app/ 業務層。
  _Rule(
    name: 'platform-cannot-import-app',
    sourcePrefix: 'lib/platform/',
    forbiddenPrefix: 'lib/app/',
  ),
];

/// 已知且有理由的例外：掃描時命中即跳過。v0.2.5 完成後預期為空。
class _Exception {
  final String rule;
  final String file;
  final String reason;

  const _Exception({
    required this.rule,
    required this.file,
    required this.reason,
  });
}

const _exceptions = <_Exception>{
  // 範例（v0.2.5 後應為空）：
  // _Exception(
  //   rule: 'ui-cannot-import-mesh',
  //   file: 'lib/ui/screens/map/widgets/map_view.dart',
  //   reason: 'flutter_map TileLayer types',
  // ),
};

/// 禁止在某層的原始碼直接出現某個符號（用來擋 legacy singleton 的直接建構）。
class _SymbolRule {
  final String name;
  final String sourcePrefix;
  final RegExp pattern;
  final String hint;

  const _SymbolRule({
    required this.name,
    required this.sourcePrefix,
    required this.pattern,
    required this.hint,
  });
}

/// UI 不得直接建構的 app-layer 型別：facade / repo / manager / legacy
/// singleton entry point。一律由 main.dart 的 root Provider 建構，UI 透過
/// `context.read<T>()` 取得，或由 controller 建構式注入。
/// 對應 CLAUDE.md「Rules」一節列舉的 entry point 清單。
const _uiForbiddenConstructors = <String>[
  'IdentityManager',
  'NegotiationManager',
  'NegotiationRepo',
  'MatchRepository',
  'EventManager',
  'MeshEventHandler',
  'DatabaseHelper',
  'LocationService',
  'ChatService',
];

final _symbolRules = <_SymbolRule>[
  _SymbolRule(
    name: 'ui-cannot-construct-app-singleton',
    sourcePrefix: 'lib/ui/',
    // `Foo(` 但不含 `Foo<` 或 `Foo.`，所以 context.read<Foo>() / 型別標註 /
    // 靜態存取都不會誤觸。
    pattern: RegExp('\\b(${_uiForbiddenConstructors.join('|')})\\s*\\('),
    hint: '改用 context.read<T>()（root Provider wiring）或由 controller '
        '建構式注入',
  ),
];

final _importRe = RegExp(
  r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""",
  multiLine: true,
);

String? _importToLibPath(String uri) {
  if (uri.startsWith('package:$_package/')) {
    final rel = uri.substring('package:$_package/'.length);
    return 'lib/$rel';
  }
  return null;
}

class _Violation {
  final String file;
  final int line;
  final String ruleName;

  /// 進指紋的細節（import uri，或被擋下的符號片段）。刻意不含行號。
  final String detail;

  /// 給人看的訊息（toString 用）。
  final String message;

  _Violation(
    this.file,
    this.line,
    this.ruleName,
    this.detail,
    this.message,
  );

  /// 用來與 baseline 比對的指紋，刻意排除行號避免搬檔誤觸。
  String get fingerprint => '$ruleName\t$file\t$detail';

  @override
  String toString() => '$file:$line  [$ruleName]  $message';
}

/// 去掉行內 `//` 註解，避免註解裡提到符號名被當成違規。
String _stripLineComment(String line) {
  final idx = line.indexOf('//');
  return idx < 0 ? line : line.substring(0, idx);
}

List<_Violation> _scan(Directory libDir) {
  final violations = <_Violation>[];
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    final relPath = entity.path
        .replaceAll('\\', '/')
        .substring(entity.path.lastIndexOf('lib'));
    final normalized = relPath.replaceAll('\\', '/');
    final matchingRules =
        _rules.where((r) => normalized.startsWith(r.sourcePrefix)).toList();
    final matchingSymbolRules = _symbolRules
        .where((r) => normalized.startsWith(r.sourcePrefix))
        .toList();
    if (matchingRules.isEmpty && matchingSymbolRules.isEmpty) continue;

    final content = entity.readAsStringSync();
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      // ── import 規則 ──
      final match = _importRe.firstMatch(lines[i]);
      if (match != null) {
        final uri = match.group(1)!;
        final libPath = _importToLibPath(uri);
        if (libPath != null) {
          for (final rule in matchingRules) {
            if (libPath.startsWith(rule.forbiddenPrefix)) {
              violations.add(
                _Violation(normalized, i + 1, rule.name, uri, 'imports $uri'),
              );
            }
          }
        }
      }

      // ── 符號規則（擋 legacy singleton 直接建構）──
      if (matchingSymbolRules.isNotEmpty) {
        final code = _stripLineComment(lines[i]);
        for (final rule in matchingSymbolRules) {
          final m = rule.pattern.firstMatch(code);
          if (m != null) {
            violations.add(
              _Violation(
                normalized,
                i + 1,
                rule.name,
                m.group(0)!.trim(),
                'direct call ${m.group(0)!.trim()} — ${rule.hint}',
              ),
            );
          }
        }
      }
    }
  }
  return violations;
}

Set<String> _readBaseline() {
  final f = File(_baselinePath);
  if (!f.existsSync()) return <String>{};
  return f
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
}

void _writeBaseline(List<_Violation> violations) {
  final lines = <String>[
    '# 烽傳 Ignirelay layer-boundary baseline',
    '# 由 `dart run tool/check_layers.dart --update-baseline` 產生',
    '# 格式：<rule>\\t<file>\\t<detail>（detail 為 importUri 或符號片段；行號刻意不記錄）',
    '# v0.2.5 Stage 3 起應為空（僅註解），CI 以 --strict 鎖死',
    '',
    ...({for (final v in violations) v.fingerprint}.toList()..sort()),
  ];
  File(_baselinePath).writeAsStringSync('${lines.join('\n')}\n');
}

/// 找出命中 [v] 的例外條目（規則名 + 檔案路徑相符）；無則回傳 null。
_Exception? _matchException(_Violation v) {
  for (final e in _exceptions) {
    if (e.rule == v.ruleName && e.file == v.file) return e;
  }
  return null;
}

void main(List<String> args) {
  final warnOnly = args.contains('--warn');
  final strict = args.contains('--strict');
  final update = args.contains('--update-baseline');

  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('error: lib/ not found (run from resqmesh_app/)');
    exit(2);
  }

  // 掃描後先濾掉 `_exceptions` 命中的條目；剩下的才是真正要把關的違規。
  final rawViolations = _scan(lib);
  final excepted = <_Violation>[];
  final violations = <_Violation>[];
  for (final v in rawViolations) {
    if (_matchException(v) != null) {
      excepted.add(v);
    } else {
      violations.add(v);
    }
  }

  if (warnOnly && excepted.isNotEmpty) {
    stdout.writeln(
        '[check_layers] ${excepted.length} skipped via _exceptions:');
    for (final v in excepted) {
      stdout.writeln('  ~ $v  (reason: ${_matchException(v)!.reason})');
    }
  }

  if (update) {
    _writeBaseline(violations);
    stdout.writeln(
        '[check_layers] baseline updated: ${violations.length} entry(ies) -> $_baselinePath');
    exit(0);
  }

  if (violations.isEmpty) {
    stdout.writeln('[check_layers] ok — no boundary violations');
    exit(0);
  }

  final baseline = strict ? <String>{} : _readBaseline();
  final newViolations = <_Violation>[];
  final grandfathered = <_Violation>[];
  for (final v in violations) {
    if (baseline.contains(v.fingerprint)) {
      grandfathered.add(v);
    } else {
      newViolations.add(v);
    }
  }

  if (grandfathered.isNotEmpty) {
    stdout.writeln(
        '[check_layers] ${grandfathered.length} grandfathered (from baseline):');
    for (final v in grandfathered) {
      stdout.writeln('  - $v');
    }
  }

  if (newViolations.isEmpty) {
    stdout.writeln('[check_layers] ok — no new violations');
    // 偵測 baseline 中已消滅的條目，提醒更新
    final liveFps = {for (final v in violations) v.fingerprint};
    final stale = baseline.where((b) => !liveFps.contains(b)).toList();
    if (stale.isNotEmpty) {
      stdout.writeln(
          '[check_layers] hint: ${stale.length} baseline entry(ies) no longer present; '
          'run with --update-baseline to shrink baseline:');
      for (final s in stale) {
        stdout.writeln('  - $s');
      }
    }
    exit(0);
  }

  stdout.writeln(
      '[check_layers] ${newViolations.length} NEW violation(s) (not in baseline):');
  for (final v in newViolations) {
    stdout.writeln('  ! $v');
  }

  if (warnOnly) {
    stdout.writeln('[check_layers] --warn: not failing');
    exit(0);
  }
  exit(1);
}
