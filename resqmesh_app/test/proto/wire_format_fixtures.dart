// wire_format_fixtures.dart
//
// v0.2.5 Stage 4 §6.2：wire-format golden 測試的共用建構器。
//
// 同時被 `wire_format_golden_test.dart`（比對）與 `tool/update_goldens.dart`
// （重新產生 golden）使用，確保「測試讀的」與「工具寫的」是同一份建構邏輯，
// 不會因為兩邊各寫一份而悄悄漂移。
//
// 非 _test.dart：不會被當測試跑。

import 'package:fixnum/fixnum.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart';

/// 目前有 proto enum 對應、會被 golden 覆蓋的 EventType（0–14）。
/// 15–18 尚無 proto 對應（見 event_type_enum_test.dart 的 drift 測試），
/// 不納入 golden，待 v0.3 Envelope v2 後再補。
const goldenEventTypes = <int>[
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
];

/// 以「固定、可重現」的輸入建一個 [MeshEvent]，只有 [type] 隨參數變動。
///
/// 所有純量 / bytes / 座標都是寫死的常數，因此 `writeToBuffer()` 的輸出
/// 對同一個 [type] 永遠相同 —— 這正是 golden 比對成立的前提。
MeshEvent buildFixedEvent(int type) {
  return MeshEvent(
    eventId: 'golden-fixed-event',
    senderPubKey: List<int>.generate(32, (i) => i & 0xFF),
    identityLevel: 1,
    type: EventType.valueOf(type)!,
    urgency: UrgencyLevel.SOS_YELLOW,
    hlcTimestamp: Int64(1700000000000),
    hlcCounter: Int64(7),
    ttl: 8,
    chunkIndex: 0,
    totalChunks: 1,
    payload: List<int>.generate(16, (i) => (i * 7) & 0xFF),
    signature: List<int>.generate(64, (i) => (i * 3) & 0xFF),
    receivedLat: 25.0330,
    receivedLng: 121.5654,
    originLat: 25.0478,
    originLng: 121.5170,
  );
}
