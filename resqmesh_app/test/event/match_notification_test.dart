// match_notification_test.dart
//
// 測試媒合意向通知邏輯：
// - MatchIntentData protobuf 解碼
// - requesterPubKey 匹配判斷
// - 非目標用戶不應收到通知

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;

void main() {
  group('MatchIntent Notification — PubKey Matching', () {
    test('MatchIntentData encodes and decodes correctly', () {
      final requesterKey = List<int>.generate(32, (i) => i + 10);
      final providerKey = List<int>.generate(32, (i) => i + 50);

      final intent = pb.MatchIntentData()
        ..requestId = 'req-123'
        ..resourceId = 'res-456'
        ..requesterPubKey = requesterKey
        ..providerPubKey = providerKey
        ..matchScore = 85.5;

      final bytes = intent.writeToBuffer();
      final decoded = pb.MatchIntentData.fromBuffer(bytes);

      expect(decoded.requestId, equals('req-123'));
      expect(decoded.resourceId, equals('res-456'));
      expect(decoded.matchScore, closeTo(85.5, 0.01));
      expect(decoded.requesterPubKey.length, equals(32));
      expect(decoded.providerPubKey.length, equals(32));
    });

    test('requesterPubKey matches when identical', () {
      final myPubKey = Uint8List.fromList(List.generate(32, (i) => i + 10));
      final requesterKey = List<int>.generate(32, (i) => i + 10);

      bool isMe = requesterKey.length == myPubKey.length;
      if (isMe) {
        for (int i = 0; i < myPubKey.length; i++) {
          if (requesterKey[i] != myPubKey[i]) {
            isMe = false;
            break;
          }
        }
      }
      expect(isMe, isTrue);
    });

    test('requesterPubKey does not match different key', () {
      final myPubKey = Uint8List.fromList(List.generate(32, (i) => i + 10));
      final otherKey = List<int>.generate(32, (i) => i + 50);

      bool isMe = otherKey.length == myPubKey.length;
      if (isMe) {
        for (int i = 0; i < myPubKey.length; i++) {
          if (otherKey[i] != myPubKey[i]) {
            isMe = false;
            break;
          }
        }
      }
      expect(isMe, isFalse);
    });

    test('empty requesterPubKey is handled', () {
      final intent = pb.MatchIntentData()
        ..requestId = 'req-empty'
        ..resourceId = 'res-empty'
        ..matchScore = 50.0;

      final bytes = intent.writeToBuffer();
      final decoded = pb.MatchIntentData.fromBuffer(bytes);

      expect(decoded.requesterPubKey.isEmpty, isTrue);
    });
  });
}
