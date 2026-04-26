// handoff_controller_test.dart
//
// Stage 6 (commit #10)：驗證 HandoffController 對跨平台 native event 的歸一化。
// Stage 6-fix (2026-04-26)：補上「真實 stream 路徑」+「sendPin BLE-write
// 路由」測試——之前只驗了純函式 debugNormalize，沒有實測上游 stream 是否
// 真的把 handshake_data 帶到 controller、以及 sendPin 是否真的會走 BLE write。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/controllers/handoff_controller.dart';
import 'package:ignirelay_app/platform/native_bridge_facade.dart';

import '../fakes/fake_native_bridge.dart';

void main() {
  group('HandoffController.debugNormalize (純函式)', () {
    test('handoff_result 直接透傳', () {
      final input = {
        'type': 'handoff_result',
        'device': 'dev-1',
        'resourceId': 'res-A',
        'success': true,
      };
      final out = HandoffController.debugNormalize(input);
      expect(out['type'], 'handoff_result');
      expect(out['resourceId'], 'res-A');
      expect(out['success'], isTrue);
      expect(out.containsKey('legacy'), isFalse);
    });

    test('handshake_data fallback 成 handoff_result + success=false + legacy=true',
        () {
      final input = {
        'type': 'handshake_data',
        'device': 'dev-2',
        'data': [0x01, 0x02, 0x03],
      };
      final out = HandoffController.debugNormalize(input);
      expect(out['type'], 'handoff_result');
      expect(out['device'], 'dev-2');
      expect(out['success'], isFalse);
      expect(out['legacy'], isTrue);
      expect(out['resourceId'], '');
    });

    test('未知 type 原樣返回（不會吃掉訊息）', () {
      final input = {'type': 'something_else', 'foo': 'bar'};
      final out = HandoffController.debugNormalize(input);
      expect(out, equals(input));
    });
  });

  group('HandoffController.events (真實 stream 路徑)', () {
    late FakeNativeBridge fake;

    setUp(() {
      fake = FakeNativeBridge();
      NativeBridgeFacade.instance = fake;
    });
    tearDown(() {
      fake.dispose();
      NativeBridgeFacade.resetToReal();
    });

    test('handoff_result 通過 stream 後仍是 handoff_result', () async {
      final received = <Map<String, dynamic>>[];
      final sub = HandoffController.instance.events.listen(received.add);

      fake.handoffEventsCtrl.add({
        'type': 'handoff_result',
        'device': 'dev-X',
        'resourceId': 'res-Y',
        'success': true,
      });
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received.first['type'], 'handoff_result');
      expect(received.first['success'], isTrue);
      expect(received.first.containsKey('legacy'), isFalse);
      await sub.cancel();
    });

    test('handshake_data 走 stream 後被 fallback 成 handoff_result + legacy=true', () async {
      // 注意：此測試模擬 native_bridge.dart 已放行 handshake_data 之後的行為。
      // 真實 stream 上游若仍 filter 掉，下游永遠看不到 handshake_data。
      final received = <Map<String, dynamic>>[];
      final sub = HandoffController.instance.events.listen(received.add);

      fake.handoffEventsCtrl.add({
        'type': 'handshake_data',
        'device': 'dev-legacy',
        'data': [0x99, 0x88],
      });
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received.first['type'], 'handoff_result');
      expect(received.first['legacy'], isTrue);
      expect(received.first['success'], isFalse);
      await sub.cancel();
    });
  });

  group('HandoffController.sendPin (BLE write 路由)', () {
    late FakeNativeBridge fake;

    setUp(() {
      fake = FakeNativeBridge();
      NativeBridgeFacade.instance = fake;
    });
    tearDown(() {
      fake.dispose();
      NativeBridgeFacade.resetToReal();
    });

    test('deviceId 提供時：走 nordicWriteHandshake、payload 為 JSON {pin, resourceId}',
        () async {
      fake.writeHandshakeResult = true;
      final ok = await HandoffController.instance.sendPin(
        deviceId: 'peer-AA',
        resourceId: 'res-001',
        pin: '1234',
      );
      expect(ok, isTrue);

      // 應該呼叫 nordicWriteHandshake 一次，且不應呼叫 sendHandoffPin
      expect(fake.calls.map((c) => c.$1).toList(), ['nordicWriteHandshake']);
      final args = fake.calls.single.$2;
      expect(args['deviceId'], 'peer-AA');
      // bytes = utf8(json({pin, resourceId}))
      final decoded =
          jsonDecode(utf8.decode(args['handshakeBytes'] as List<int>));
      expect(decoded, {'pin': '1234', 'resourceId': 'res-001'});
    });

    test('writeHandshake 回 false（PIN 不對）→ sendPin 也回 false', () async {
      fake.writeHandshakeResult = false;
      final ok = await HandoffController.instance.sendPin(
        deviceId: 'peer-BB',
        resourceId: 'res-002',
        pin: '0000',
      );
      expect(ok, isFalse);
      expect(fake.calls.single.$1, 'nordicWriteHandshake');
    });

    test('deviceId 為空字串：fallback 走本地 sendHandoffPin（同裝置 dev 用）', () async {
      fake.sendHandoffPinResult = true;
      final ok = await HandoffController.instance.sendPin(
        deviceId: '',
        resourceId: 'res-003',
        pin: '5555',
      );
      expect(ok, isTrue);
      expect(fake.calls.single.$1, 'sendHandoffPin');
      // 確保沒有走 BLE write 路徑
      expect(fake.calls.map((c) => c.$1).contains('nordicWriteHandshake'),
          isFalse);
    });
  });
}
