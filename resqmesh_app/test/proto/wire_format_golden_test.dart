// wire_format_golden_test.dart
//
// v0.2.5 Stage 4 §6.2：MeshEvent wire-format golden 測試。
//
// 對每個有 proto 對應的 EventType（0–14），用固定輸入建一個 MeshEvent、
// 序列化，並與 test/proto/goldens/event_type_$type.bin 比對。任何 wire
// format 漂移（欄位增減、tag 變動、編碼行為改變）都會讓對應 case 失敗。
//
// 若漂移是「刻意的」，確認後跑：
//   dart run tool/update_goldens.dart
// 重新產生 golden 基準。
//
// 建構邏輯在 wire_format_fixtures.dart，與 update_goldens.dart 共用。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'wire_format_fixtures.dart';

const _goldenDir = 'test/proto/goldens';

void main() {
  group('MeshEvent wire-format golden', () {
    test('golden directory has exactly ${goldenEventTypes.length} .bin files',
        () {
      final bins = Directory(_goldenDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.bin'))
          .toList();
      expect(bins.length, equals(goldenEventTypes.length),
          reason: 'Expected one golden per working EventType (0–14). '
              'If you intentionally changed coverage, update goldenEventTypes '
              'and rerun tool/update_goldens.dart.');
    });

    for (final type in goldenEventTypes) {
      test('EventType $type wire format golden', () {
        final bytes = buildFixedEvent(type).writeToBuffer();
        final golden =
            File('$_goldenDir/event_type_$type.bin').readAsBytesSync();
        expect(bytes, equals(golden),
            reason: 'Wire format for EventType $type changed. '
                'If intentional, update golden with: '
                'dart run tool/update_goldens.dart');
      });
    }
  });
}
