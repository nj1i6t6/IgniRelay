// 烽傳 Ignirelay layer-boundary checker.
//
// 強制 platform / app / ui 三層的 import 規則：
//   - lib/ui/**   禁止 import lib/platform/**
//   - lib/app/**  禁止 import lib/ui/**
//
// 使用：
//   dart run tool/check_layers.dart         （報告違規，exit 1 若有）
//   dart run tool/check_layers.dart --warn  （僅警告，exit 0）
//
// 本工具在 Stage 4a-4d / Stage 5 期間會觀察到逐漸遞減的違規數，
// Stage 5 結束應為 0，Stage 7 之後可改為 CI 強制。

import 'dart:io';

const _package = 'ignirelay_app';

class _Rule {
  final String name;
  final String sourcePrefix; // 例如 'lib/ui/'
  final String forbiddenPrefix; // 例如 'lib/platform/'

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

  @override
  String toString() =>
      '$file:$line  [${rule.name}]  imports $importUri';
}

List<_Violation> _scan(Directory libDir) {
  final violations = <_Violation>[];
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    final relPath = entity.path
        .replaceAll('\\', '/')
        .substring(entity.path.lastIndexOf('lib'));
    // Normalize to forward slashes relative to project root
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

void main(List<String> args) {
  final warnOnly = args.contains('--warn');
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('error: lib/ not found (run from resqmesh_app/)');
    exit(2);
  }

  final violations = _scan(lib);
  if (violations.isEmpty) {
    stdout.writeln('[check_layers] ok — no boundary violations');
    exit(0);
  }

  stdout.writeln('[check_layers] ${violations.length} violation(s):');
  for (final v in violations) {
    stdout.writeln('  $v');
  }

  if (warnOnly) {
    stdout.writeln('[check_layers] --warn: not failing');
    exit(0);
  }
  exit(1);
}
