// CI guard for cross-platform chunking constants (v0.3 Stage 0c).
//
// Spec: docs/specs/native_transport_v1_2026-05-13.md §4.6 / §15.8.
//
// The chunking + envelope-budget constants are hand-maintained in three sibling
// files. This script greps each file for the named constants and fails if any
// of the three disagree. Spec calls this out explicitly: "no code generation".
//
//   - lib/app/mesh/mesh_constants.dart          (Dart)
//   - android/.../IgniRelayConstants.kt         (Kotlin)
//   - ios/Runner/IgniRelayConstants.swift       (Swift)
//
// Usage:
//   dart run tool/check_constants_parity.dart
// Exit codes:
//   0 — clean
//   1 — divergence detected
//   2 — input file missing or unreadable

import 'dart:io';

const String _dartPath = 'lib/app/mesh/mesh_constants.dart';
const String _kotlinPath =
    'android/app/src/main/kotlin/network/ignirelay/ignirelay_app/IgniRelayConstants.kt';
const String _swiftPath = 'ios/Runner/IgniRelayConstants.swift';

/// Each entry maps a logical constant name to its identifier in each language.
/// All three values MUST resolve to the same integer literal (decimal, with
/// underscores allowed). Values that are durations use `_MS` suffix; budgets
/// are bare integers.
final List<_ConstSpec> _specs = <_ConstSpec>[
  _ConstSpec('PROTOCOL_VERSION_V2',
      dartName: 'kProtocolVersionV2'),
  _ConstSpec('MAX_ENVELOPE_BYTES',
      dartName: 'kMaxEnvelopeBytes'),
  _ConstSpec('CHUNK_HEADER_SIZE',
      dartName: 'kChunkHeaderSize'),
  _ConstSpec('ATT_HEADER_SIZE',
      dartName: 'kAttHeaderSize'),
  _ConstSpec('MAX_CHUNKS_PER_ENVELOPE',
      dartName: 'kMaxChunksPerEnvelope'),
  _ConstSpec('REASSEMBLY_TIMEOUT_MS',
      dartName: 'kReassemblyTimeoutMs'),
  _ConstSpec('MAX_REASSEMBLY_BUFFER_BYTES',
      dartName: 'kMaxReassemblyBufferBytes'),
  _ConstSpec('MAX_REASSEMBLY_BUFFER_ENTRIES',
      dartName: 'kMaxReassemblyBufferEntries'),
  _ConstSpec('SOS_ENVELOPE_BUDGET_BYTES',
      dartName: 'kSosEnvelopeBudgetBytes'),
  _ConstSpec('RESOURCE_ENVELOPE_BUDGET_BYTES',
      dartName: 'kResourceEnvelopeBudgetBytes'),
  _ConstSpec('ALERT_ENVELOPE_BUDGET_BYTES',
      dartName: 'kAlertEnvelopeBudgetBytes'),
  _ConstSpec('HELLO_FALLBACK_TIMEOUT_MS',
      dartName: 'kHelloFallbackTimeoutMs'),
  _ConstSpec('SUBSCRIBE_BLOOM_FALLBACK_MS',
      dartName: 'kSubscribeBloomFallbackMs'),
];

Future<int> main(List<String> args) async {
  final dart = await _readSafe(_dartPath);
  final kotlin = await _readSafe(_kotlinPath);
  final swift = await _readSafe(_swiftPath);
  if (dart == null || kotlin == null || swift == null) return 2;

  var failed = false;
  for (final spec in _specs) {
    final dartVal = _extractValue(dart, spec.dartName);
    final kotlinVal = _extractValue(kotlin, spec.cName);
    final swiftVal = _extractValue(swift, spec.cName);
    if (dartVal == null || kotlinVal == null || swiftVal == null) {
      stderr.writeln(
          '  ${spec.cName}: missing in '
          '${dartVal == null ? "Dart " : ""}'
          '${kotlinVal == null ? "Kotlin " : ""}'
          '${swiftVal == null ? "Swift " : ""}');
      failed = true;
      continue;
    }
    if (!(dartVal == kotlinVal && kotlinVal == swiftVal)) {
      stderr.writeln(
          '  ${spec.cName}: dart=$dartVal kotlin=$kotlinVal swift=$swiftVal (DIVERGE)');
      failed = true;
    }
  }
  if (failed) {
    stderr.writeln(
        '\ncheck_constants_parity: FAIL — Stage 0c constants drift detected.\n'
        'Update all three files together (see spec §4.6 / §15.8).');
    return 1;
  }
  stdout.writeln('check_constants_parity: OK (${_specs.length} constants in sync)');
  return 0;
}

class _ConstSpec {
  /// Kotlin/Swift name (UPPER_SNAKE_CASE) — same identifier in both.
  final String cName;

  /// Dart name (lowerCamel kFoo); defaults to `'k' + camel(cName)`.
  final String dartName;

  _ConstSpec(this.cName, {required this.dartName});
}

Future<String?> _readSafe(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    stderr.writeln('check_constants_parity: missing file ${file.path}');
    stderr.writeln(
        '  (run from resqmesh_app/ — current cwd: ${Directory.current.path})');
    return null;
  }
  return file.readAsString();
}

/// Extract the integer literal assigned to `name` in the file's source.
/// Accepts Dart `const int kFoo = 12;` / `const int kFoo = 1024 * 4;` and
/// Kotlin/Swift `const val NAME = 4_096` / `static let NAME = 60_000`.
/// Returns null on miss. Underscore separators in integer literals are stripped.
int? _extractValue(String source, String name) {
  // Look for `name` followed by `=` then an integer (possibly with arithmetic).
  // We restrict the RHS to a simple `<int>(<op><int>)?` form to keep this
  // grep-style check predictable.
  final re = RegExp(
    r'\b' + RegExp.escape(name) + r'\b\s*[:=]\s*([0-9_]+(?:\s*\*\s*[0-9_]+)*(?:\s*\+\s*[0-9_]+(?:\s*\*\s*[0-9_]+)*)*)',
    multiLine: true,
  );
  final match = re.firstMatch(source);
  if (match == null) return null;
  final expr = match.group(1)!;
  return _evalIntExpr(expr);
}

/// Tiny evaluator for chained `+` and `*` of integer literals; left-to-right
/// with `*` having higher precedence (parsed by splitting on `+` first).
int? _evalIntExpr(String expr) {
  final addTerms = expr.split('+');
  var total = 0;
  for (final term in addTerms) {
    final mulFactors = term.split('*');
    var product = 1;
    for (final f in mulFactors) {
      final clean = f.replaceAll('_', '').trim();
      final v = int.tryParse(clean);
      if (v == null) return null;
      product *= v;
    }
    total += product;
  }
  return total;
}
