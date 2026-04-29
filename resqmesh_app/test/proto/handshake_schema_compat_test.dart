// handshake_schema_compat_test.dart
//
// Stage 6 (commit #10)：HandshakeCompleteData 的 schema_version 雙向相容性測試。
//
// 規範：
//   - 新 client 寫出時 schema_version = HandshakeSchema.currentSchemaVersion（目前 = 1）。
//   - 舊 client 讀取（不識別 field 10）→ protobuf 自動把 unknown field 收進
//     unknownFields 容器，整個 payload 不崩、其他欄位仍可用。
//   - 新 client 讀取舊 payload（無 field 10）→ schemaVersion 取得 scalar
//     default 值 0；其他欄位仍可用。
//
// 本測試不依 DB / native plugin，純 protobuf wire 對照。

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/proto/handshake_schema.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;
import 'package:protobuf/protobuf.dart' as $pb;

/// Stage 6-fix：模擬「不認識 field 10 schema_version」的舊 builder。
///
/// 只宣告 field 1-9，故意省略 field 10。protobuf 庫在解析時遇到未知 tag 會
/// 自動把它收進 `unknownFields`，整個 parse 不會崩。本 class 用來實測
/// 「舊 client 解析新 payload」的真實行為，取代之前用同一個 class 自我解析
/// 無法證明的弱測法。
class _OldHandshakeBuilder extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('OldHandshakeBuilder',
      package: const $pb.PackageName('resqmesh'),
      createEmptyInstance: () => _OldHandshakeBuilder())
    ..aOS(1, 'negotiationId', protoName: 'negotiation_id')
    ..aOS(2, 'resourceId', protoName: 'resource_id')
    ..aOS(3, 'requestId', protoName: 'request_id')
    ..a<List<int>>(4, 'providerPubKey', $pb.PbFieldType.OY,
        protoName: 'provider_pub_key')
    ..a<List<int>>(5, 'requesterPubKey', $pb.PbFieldType.OY,
        protoName: 'requester_pub_key')
    ..a<double>(6, 'actualDeliveredQty', $pb.PbFieldType.OF,
        protoName: 'actual_delivered_qty')
    ..aOS(7, 'method')
    ..a<List<int>>(8, 'providerSignature', $pb.PbFieldType.OY,
        protoName: 'provider_signature')
    ..a<List<int>>(9, 'requesterSignature', $pb.PbFieldType.OY,
        protoName: 'requester_signature')
    // 故意不宣告 tag 10 — 模擬舊 client。
    ..hasRequiredFields = false;

  _OldHandshakeBuilder() : super();

  factory _OldHandshakeBuilder.fromBuffer(List<int> i) =>
      _OldHandshakeBuilder()..mergeFromBuffer(i);

  @override
  _OldHandshakeBuilder createEmptyInstance() => _OldHandshakeBuilder();
  @override
  _OldHandshakeBuilder clone() => _OldHandshakeBuilder()..mergeFromMessage(this);
  @override
  $pb.BuilderInfo get info_ => _i;

  String get negotiationId => $_getSZ(0);
  String get resourceId => $_getSZ(1);
  String get requestId => $_getSZ(2);
  double get actualDeliveredQty => $_getN(5);
  String get method => $_getSZ(6);
}

void main() {
  group('HandshakeCompleteData schema_version compat', () {
    test('current schema version 常數 = 1', () {
      expect(HandshakeSchema.currentSchemaVersion, 1);
    });

    test('新 client 寫 → 新 client 讀：所有欄位 + schema_version 完整保留', () {
      final pubP = Uint8List.fromList(List.generate(32, (i) => i));
      final pubR = Uint8List.fromList(List.generate(32, (i) => 0xFF - i));
      final src = pb.HandshakeCompleteData(
        negotiationId: 'neg-001',
        resourceId: 'res-001',
        requestId: 'req-001',
        providerPubKey: pubP,
        requesterPubKey: pubR,
        actualDeliveredQty: 5.5,
        method: 'PIN_4DIGIT',
        schemaVersion: HandshakeSchema.currentSchemaVersion,
      );
      final bytes = src.writeToBuffer();

      final round = pb.HandshakeCompleteData.fromBuffer(bytes);
      expect(round.negotiationId, 'neg-001');
      expect(round.resourceId, 'res-001');
      expect(round.requestId, 'req-001');
      expect(round.providerPubKey, equals(pubP));
      expect(round.requesterPubKey, equals(pubR));
      expect(round.actualDeliveredQty, closeTo(5.5, 1e-6));
      expect(round.method, 'PIN_4DIGIT');
      expect(round.schemaVersion, 1);
      expect(round.hasSchemaVersion(), isTrue);
    });

    test('舊 payload (無 schema_version) → 新 client 解析：schemaVersion=0、其他欄位完整',
        () {
      // 模擬舊 client 寫出：不設 schemaVersion → 不寫 field 10。
      final old = pb.HandshakeCompleteData(
        negotiationId: 'neg-legacy',
        resourceId: 'res-legacy',
        requestId: 'req-legacy',
        actualDeliveredQty: 3.0,
        method: 'BLE',
        // 注意：故意不設 schemaVersion
      );
      // 確認沒寫 field 10
      expect(old.hasSchemaVersion(), isFalse);
      final bytes = old.writeToBuffer();

      final parsed = pb.HandshakeCompleteData.fromBuffer(bytes);
      // scalar default = 0 → 解析端自動取 0，代表「來自舊 client」
      expect(parsed.schemaVersion, 0);
      expect(parsed.hasSchemaVersion(), isFalse);
      // 其他欄位正常
      expect(parsed.negotiationId, 'neg-legacy');
      expect(parsed.actualDeliveredQty, closeTo(3.0, 1e-6));
      expect(parsed.method, 'BLE');
    });

    test('新 payload → 真正不認識 field 10 的舊 builder 解析：主要欄位完整、'
        'field 10 自動進 unknownFields（舊客戶端真實行為）', () {
      // Stage 6-fix：原本這個測試用同一個 HandshakeCompleteData class 解析自己寫
      // 的 payload，無法證明「真正舊 build」的相容性。改用一個只認識 field
      // 1-9 的 _OldHandshakeBuilder 來解析新 payload，這才是 plan §Stage 6
      // L343 要求的「舊 client 解析新 payload」實測。
      final n = pb.HandshakeCompleteData(
        negotiationId: 'neg-new',
        resourceId: 'res-new',
        actualDeliveredQty: 7.25,
        method: 'DROP_OFF',
        schemaVersion: 99,
      );
      final newBytes = n.writeToBuffer();

      // 用「不認識 field 10」的舊 builder 解析
      final asOld = _OldHandshakeBuilder.fromBuffer(newBytes);
      expect(asOld.negotiationId, 'neg-new');
      expect(asOld.resourceId, 'res-new');
      expect(asOld.actualDeliveredQty, closeTo(7.25, 1e-6));
      expect(asOld.method, 'DROP_OFF');
      // field 10 對這個 builder 來說是未知的，自動落入 unknownFields；
      // 整體 parse 不崩、上面已知欄位皆正確。
      expect(asOld.unknownFields.hasField(10), isTrue);
    });

    test('新 client 寫一個未來版本的 fake field（tag 99）→ 解析端不崩、'
        '收進 unknownFields、其他欄位完整', () {
      // 用 protobuf builder 直接塞一個未知 tag，模擬「新 client 多送了未來欄位」。
      // 測試「相容於未知 field」。
      final src = pb.HandshakeCompleteData(
        negotiationId: 'future-neg',
        resourceId: 'future-res',
        actualDeliveredQty: 9.0,
      );
      final base = src.writeToBuffer();
      // 在尾端手動 append 一個 tag 99 (varint)：
      //   wire-format: (99 << 3) | 0 = 792，varint encode: 0x98 0x06
      //   value = 1234（0xD2 0x09）
      final tampered = Uint8List.fromList(
          [...base, 0x98, 0x06, 0xD2, 0x09]);

      // 解析應仍可成功，且已知欄位完整
      final parsed = pb.HandshakeCompleteData.fromBuffer(tampered);
      expect(parsed.negotiationId, 'future-neg');
      expect(parsed.resourceId, 'future-res');
      expect(parsed.actualDeliveredQty, closeTo(9.0, 1e-6));
      // unknownFields 應收到 tag 99
      final uf = parsed.unknownFields;
      expect(uf.hasField(99), isTrue);
    });
  });
}
