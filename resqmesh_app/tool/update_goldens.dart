// update_goldens.dart
//
// v0.2.5 Stage 4 §6.2：重新產生 wire-format golden 檔。
//
// 何時跑：當 MeshEvent 的 wire format「刻意」變動時（例如新增欄位、
// 調整 proto），`wire_format_golden_test.dart` 會開始失敗。確認變動是
// 預期的之後，跑這支工具把 golden 重寫成新基準：
//
//   dart run tool/update_goldens.dart   （從 resqmesh_app/ 執行）
//
// 注意：建構邏輯來自 test/proto/wire_format_fixtures.dart —— 測試與工具
// 共用同一份，避免兩邊漂移。

import 'dart:io';

import '../test/proto/wire_format_fixtures.dart';

const _goldenDir = 'test/proto/goldens';

void main() {
  final dir = Directory(_goldenDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  var written = 0;
  for (final type in goldenEventTypes) {
    final bytes = buildFixedEvent(type).writeToBuffer();
    final file = File('$_goldenDir/event_type_$type.bin');
    file.writeAsBytesSync(bytes);
    stdout.writeln('  wrote ${file.path} (${bytes.length} bytes)');
    written++;
  }
  stdout.writeln('[update_goldens] done — $written golden file(s) -> $_goldenDir');
}
