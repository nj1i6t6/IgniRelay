// match_to_handoff_e2e_test.dart
//
// Stage 7：Match → Navigation → Handoff → Complete 端到端 happy-path
// 驗證（測試替身驅動）。
//
// 不接真實 BLE / native；以 [FakeNativeBridge] 模擬：
//   1. Provider 端 `startHandoffAdvertising` 起服；
//   2. Requester 端 `nordicWriteHandshake(deviceId, payload)` 寫 PIN；
//   3. Native 由 BLE 拉回的事件由 fake 注入 `handoffEventsCtrl`，
//      `HandoffController.events` 應吐出歸一化後的 handoff_result；
//   4. 雙方收到 success=true → 對應前端 UI 應切到 success step（此處
//      只驗 controller 層事件流，UI integration 留 widget test 範圍）。

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ignirelay_app/app/controllers/handoff_controller.dart';
import 'package:ignirelay_app/platform/native_bridge_facade.dart';

import '../fakes/fake_native_bridge.dart';

void main() {
  group('Stage 7 E2E：match → handoff happy path', () {
    late FakeNativeBridge fake;

    setUp(() {
      fake = FakeNativeBridge();
      NativeBridgeFacade.instance = fake;
    });
    tearDown(() {
      fake.dispose();
      NativeBridgeFacade.resetToReal();
    });

    test('provider 起服 + requester 寫入 PIN + 雙方拿到 success=true',
        () async {
      // 1. Provider 端：開廣告
      final startOk = await NativeBridgeFacade.instance.startHandoffAdvertising(
        resourceId: 'res-001',
        pinHash: 'abc123hash',
      );
      expect(startOk, isTrue);
      expect(fake.calls.first.$1, 'startHandoffAdvertising');

      // 2. Requester 端：對 provider 的 deviceId 寫入 PIN payload。
      // sendPin 在 deviceId 非空時會路由到 nordicWriteHandshake（Stage 6-fix）
      final ctrl = HandoffController.instance;
      final routedOk = await ctrl.sendPin(
        deviceId: 'provider-device-A',
        resourceId: 'res-001',
        pin: '4287',
      );
      expect(routedOk, isTrue);

      // 確認 controller 真的走 BLE write 路徑而非 sendHandoffPin
      final writeCall =
          fake.calls.firstWhere((c) => c.$1 == 'nordicWriteHandshake');
      expect(writeCall.$2['deviceId'], 'provider-device-A');
      final payload = writeCall.$2['handshakeBytes'] as Uint8List;
      final decoded = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      expect(decoded['pin'], '4287');
      expect(decoded['resourceId'], 'res-001');

      // 3. Native 把 handoff_result（驗證成功）回送到雙方。
      final receivedRequester = <Map<String, dynamic>>[];
      final receivedProvider = <Map<String, dynamic>>[];
      final subR = ctrl.events.listen(receivedRequester.add);
      final subP = ctrl.events.listen(receivedProvider.add);

      fake.handoffEventsCtrl.add({
        'type': 'handoff_result',
        'device': 'provider-device-A',
        'resourceId': 'res-001',
        'success': true,
      });
      await Future<void>.delayed(Duration.zero);

      // 4. 雙方 controller 都收到 success=true
      expect(receivedRequester.length, 1);
      expect(receivedRequester.first['success'], isTrue);
      expect(receivedRequester.first['resourceId'], 'res-001');
      expect(receivedProvider.length, 1);
      expect(receivedProvider.first['success'], isTrue);

      await subR.cancel();
      await subP.cancel();
    });

    test('PIN 錯誤：native 回 success=false 時 controller 不轉 success',
        () async {
      final ctrl = HandoffController.instance;
      final received = <Map<String, dynamic>>[];
      final sub = ctrl.events.listen(received.add);

      // 模擬 native GATT_FAILURE / writeNotPermitted 回應
      fake.handoffEventsCtrl.add({
        'type': 'handoff_result',
        'device': 'provider-device-A',
        'resourceId': 'res-002',
        'success': false,
        'reason': 'pin_mismatch',
      });
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received.first['success'], isFalse);
      expect(received.first['resourceId'], 'res-002');

      await sub.cancel();
    });

    test('legacy handshake_data：fallback 成 handoff_result + success=false',
        () async {
      // 舊版 native 推 handshake_data 但沒有經過 GATT 驗證 → controller 應
      // 標記為 legacy 並 success=false（讓 UI 不要自動進 success step）。
      final ctrl = HandoffController.instance;
      final received = <Map<String, dynamic>>[];
      final sub = ctrl.events.listen(received.add);

      fake.handoffEventsCtrl.add({
        'type': 'handshake_data',
        'device': 'provider-device-B',
        'data': [0x01, 0x02, 0x03],
      });
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received.first['type'], 'handoff_result');
      expect(received.first['success'], isFalse);
      expect(received.first['legacy'], isTrue);

      await sub.cancel();
    });
  });
}
