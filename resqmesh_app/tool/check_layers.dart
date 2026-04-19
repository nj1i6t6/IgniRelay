// 烽傳 Ignirelay layer-boundary checker.
//
// 強制 platform / app / ui 三層的 import 規則：
//   - lib/ui/**   禁止 import lib/platform/**
//   - lib/app/**  禁止 import lib/ui/**
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
  final String importUri;
  final _Rule rule;

  _Violation(this.file, this.line, this.importUri, this.rule);

  /// 用來與 baseline 比對的指紋，刻意排除行號避免搬檔誤觸。
  String get fingerprint => '${rule.name}\t$file\t$importUri';

  @override
  String toString() => '$file:$line  [${rule.name}]  imports $importUri';
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
        _rules.where((r) => normalized.startsWith(r.sourcePrefix));
    if (matchingRules.isEmpty) continue;

    final content = entity.readAsStringSync();
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final match = _importRe.firstMatch(lines[i]);
      if (match == null) continue;
      final uri = match.group(1)!;
      final libPath = _importToLibPath(uri);
      if (libPath == null) continue;
      for (final rule in matchingRules) {
        if (libPath.startsWith(rule.forbiddenPrefix)) {
          violations.add(_Violation(normalized, i + 1, uri, rule));
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
    '# 格式：<rule>\\t<file>\\t<importUri>（行號刻意不記錄）',
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
