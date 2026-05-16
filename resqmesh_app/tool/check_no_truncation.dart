// CI guard for v0.3 Stage 0c2 (P0 truncation removal).
//
// Spec: docs/specs/native_transport_v1_2026-05-13.md §2.4.
//
// > The strings `copyOf(514)` and the literal integer `514` MUST NOT appear in
// > `IgniRelayForegroundService.kt` after Stage 0c2 lands.
//
// This script greps the Android foreground service for the legacy notify-
// truncation patterns and exits non-zero if any are found, so the regression
// cannot reappear without a deliberate spec amendment.
//
// Usage:
//   dart run tool/check_no_truncation.dart
// Exit codes:
//   0 — clean
//   1 — found a banned pattern
//   2 — file missing or unreadable

import 'dart:io';

const String _kRelativePath =
    'android/app/src/main/kotlin/network/ignirelay/ignirelay_app/IgniRelayForegroundService.kt';

const List<String> _bannedPatterns = <String>[
  'copyOf(514)',
  '514',
];

Future<int> main(List<String> args) async {
  final file = File(_kRelativePath);
  if (!await file.exists()) {
    stderr.writeln('check_no_truncation: file not found: ${file.path}');
    stderr.writeln(
        '  (run from resqmesh_app/ — current cwd: ${Directory.current.path})');
    return 2;
  }
  final lines = await file.readAsLines();
  final hits = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final pattern in _bannedPatterns) {
      if (line.contains(pattern)) {
        hits.add('  ${file.path}:${i + 1}: contains "$pattern"\n    > $line');
      }
    }
  }
  if (hits.isEmpty) {
    stdout.writeln('check_no_truncation: OK (no banned 514-truncation patterns)');
    return 0;
  }
  stderr.writeln(
      'check_no_truncation: FAIL — Stage 0c2 banned patterns found in ${file.path}:');
  for (final hit in hits) {
    stderr.writeln(hit);
  }
  stderr.writeln(
      '\nPer spec docs/specs/native_transport_v1_2026-05-13.md §2.4 the literal\n'
      '`514` and the substring `copyOf(514)` MUST NOT appear in this file.\n'
      'Use the per-device MTU map and safeSingleNotify() instead.');
  return 1;
}
