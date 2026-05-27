// event_type_enum_test.dart
//
// Bug 1 驗證：Protobuf EventType enum 0–13 全部可解析
// 確保 valueOf() 不回傳 null（之前 8–13 缺失導致 chatMessage 被編碼為 type=0）
//
// v0.2.5 Stage 4：新增「Dart EventType 常數 ↔ proto enum」漂移測試。
//   - `EventType`（unprefixed）= lib/app/mesh/event_types.dart 的領域常數類別
//   - `pb.EventType`           = 產生碼的 protobuf enum

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pbenum.dart' as pb;

void main() {
  group('EventType enum — Bug 1 regression', () {
    test('valueOf(0..13) all return non-null', () {
      for (var i = 0; i <= 13; i++) {
        final et = pb.EventType.valueOf(i);
        expect(et, isNotNull, reason: 'EventType.valueOf($i) should not be null');
        expect(et!.value, equals(i));
      }
    });

    test('CHAT_MESSAGE is value 13', () {
      expect(pb.EventType.CHAT_MESSAGE.value, equals(13));
      expect(pb.EventType.valueOf(13), equals(pb.EventType.CHAT_MESSAGE));
    });

    test('MATCH_CONFIRM through MATCH_GONE are 8–12', () {
      expect(pb.EventType.MATCH_CONFIRM.value, equals(8));
      expect(pb.EventType.MATCH_REJECT.value, equals(9));
      expect(pb.EventType.MATCH_INQUIRY.value, equals(10));
      expect(pb.EventType.MATCH_AVAILABLE.value, equals(11));
      expect(pb.EventType.MATCH_GONE.value, equals(12));
    });

    test('values list contains all 19 entries', () {
      expect(pb.EventType.values.length, equals(19));
    });

    test('valueOf(14..18) map to the new-slot constants', () {
      expect(pb.EventType.valueOf(14), equals(pb.EventType.LOCATION_UPDATE));
      expect(pb.EventType.valueOf(15), equals(pb.EventType.MATCH_REQUEST));
      expect(pb.EventType.valueOf(16), equals(pb.EventType.HANDSHAKE_COMPLETE));
      expect(pb.EventType.valueOf(17), equals(pb.EventType.STATION_CLAIM));
      expect(pb.EventType.valueOf(18), equals(pb.EventType.STATION_RESPONSE));
    });

    // 每個 Dart 端 EventType 常數都必須有對應的 proto enum 值，否則事件會被
    // encodeWirePayload 靜默編碼成 type=0（Bug 1 根因）。
    //
    // 此測試原本被 skip，註解寫「proto enum 只到 14，常數 15–18 尚無對應，
    // 待 v0.3 再修」——但這個缺口其實正在線上把 matchRequest(15) /
    // handshakeComplete(16) 壓成 type=0、收端 sig-fail，導致需求方發起的媒合與
    // 交接完成跨機失效（0d 兩機實測坐實）。proto enum 已補齊 15–18，移除 skip，
    // 讓本測試成為「Dart 常數 ↔ proto enum」漂移的長期守門員。
    test('Dart EventType constants must all have proto counterparts', () {
      final dartValues = <int>{
        EventType.resourceRegister, // 0
        EventType.requestBroadcast, // 1
        EventType.matchOffer, // 2
        EventType.physicalHandshake, // 3
        EventType.hazardMarker, // 4
        EventType.quarantineVote, // 5
        EventType.matchCancel, // 6
        EventType.fireAlarmRf, // 7
        EventType.matchAccept, // 8
        EventType.matchDecline, // 9
        EventType.matchInquiry, // 10
        EventType.matchAvailable, // 11
        EventType.matchGone, // 12
        EventType.chatMessage, // 13
        EventType.locationUpdate, // 14
        EventType.matchRequest, // 15
        EventType.handshakeComplete, // 16
        EventType.stationClaim, // 17
        EventType.stationResponse, // 18
      };
      for (final v in dartValues) {
        expect(pb.EventType.valueOf(v), isNotNull,
            reason: 'EventType constant $v has no matching proto enum value. '
                'Sync protos/mesh_protocol.proto before adding new EventType '
                'constants.');
      }
    });
  });
}
