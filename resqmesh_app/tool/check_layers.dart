// 烽傳 Ignirelay layer-boundary checker.
//
// 強制 platform / app / ui 三層的 import 規則：
//   - lib/ui/**   禁止 import lib/platform/**
//   - lib/app/**  禁止 import lib/ui/**
//
// 另外強制「UI 不得直觸 legacy singleton entry point」的符號規則：
//   - lib/ui/**   禁止直接呼叫 `IdentityManager(` 建構式
//                 （唯一允許的建構點是 main.dart 的 Provider wiring；
//                  UI 一律 context.read<IdentityManager>() 或由 controller
//                  建構式注入）
//
// 使用：
//   dart run tool/check_layers.dart                   檢查並與 baseline 比對，
//                                                    新增違規即 exit 1
//   dart run tool/check_layers.dart --warn            僅印出，不 fail
//   dart run tool/check_layers.dart --strict          忽略 baseline，任何違規都 fail
//   dart run tool/check_layers.dart --update-baseline 以當前狀態重寫 baseline
//
// Baseline 檔：tool/layer_violations_baseline.txt
// 每行格式 `<rule>\t<file>\t<importUri>`（file 與 line 無關，避免搬檔即破壞 baseline）。
//
// 契約：計畫 Refactoring-0.2.0-plan.md L110「違反 → build fail」。
// Stage 1 時既有 4 筆違規已寫入 baseline，Stage 4a/4d/5 清除時須同步移除 baseline 條目
// （或跑 `--update-baseline` 重建）。Stage 5 結束後 baseline 應為空，Stage 7 之後可在
// CI 加上 `--strict` 作為最終閘門。

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
];

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

final _symbolRules = <_SymbolRule>[
  _SymbolRule(
    name: 'ui-cannot-construct-identity-manager',
    sourcePrefix: 'lib/ui/',
    // `IdentityManager(` 但不含 `IdentityManager<` 或 `IdentityManager.`，
    // 所以 context.read<IdentityManager>() / 型別標註 / 靜態存取都不會誤觸。
    pattern: RegExp(r'\bIdentityManager\s*\('),
    hint: '改用 context.read<IdentityManager>() 或由 controller 建構式注入',
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
    '# Stage 5 結束應清空，Stage 7 於 CI 加 --strict 鎖死',
    '',
    ...({for (final v in violations) v.fingerprint}.toList()..sort()),
  ];
  File(_baselinePath).writeAsStringSync('${lines.join('\n')}\n');
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

  final violations = _scan(lib);

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
