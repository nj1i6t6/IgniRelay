// handshake_schema_compat_test.dart
//
// Stage 6 (commit #10)：HandshakeCompleteData 的 schema_version 雙向相容性測試。
//
// 規範：
//   - 新 client 寫出時 schema_version = kCurrentSchemaVersion（目前 = 1）。
//   - 舊 client 讀取（不識別 field 10）→ protobuf 自動把 unknown field 收進
//     unknownFields 容器，整個 payload 不崩、其他欄位仍可用。
//   - 新 client 讀取舊 payload（無 field 10）→ schemaVersion 取得 scalar
//     default 值 0；其他欄位仍可用。
//
// 本測試不依 DB / native plugin，純 protobuf wire 對照。

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;

void main() {
  group('HandshakeCompleteData schema_version compat', () {
    test('current schema version 常數 = 1', () {
      expect(pb.HandshakeCompleteData.kCurrentSchemaVersion, 1);
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
        schemaVersion: pb.HandshakeCompleteData.kCurrentSchemaVersion,
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

    test('新 payload (含 schema_version) → 舊 client 解析（不認識 field 10）：'
        '主要欄位完整 + 不崩', () {
      // 新 client 寫
      final n = pb.HandshakeCompleteData(
        negotiationId: 'neg-new',
        resourceId: 'res-new',
        actualDeliveredQty: 7.25,
        method: 'DROP_OFF',
        schemaVersion: 99, // 故意送一個未來版本號
      );
      final newBytes = n.writeToBuffer();

      // 模擬「舊 client」：用同一個 class 解析時，verify behavior — 我們無法在
      // 同 process 真的還原一個沒有 field 10 的 class，但 protobuf 的契約是
      // unknown field 會被收進 unknownFields 容器，不影響已知欄位的讀取。
      final asOld = pb.HandshakeCompleteData.fromBuffer(newBytes);
      // 已知欄位仍可正確讀取
      expect(asOld.negotiationId, 'neg-new');
      expect(asOld.resourceId, 'res-new');
      expect(asOld.actualDeliveredQty, closeTo(7.25, 1e-6));
      expect(asOld.method, 'DROP_OFF');
      // 因為 class 在這個 build 下「認識」field 10，所以 hasSchemaVersion 為真；
      // 真正未知的欄位會落在 unknownFields。本測試對「不崩 + 主要欄位正確」即足夠。
      expect(asOld.schemaVersion, 99);
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
