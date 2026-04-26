// ble_scan_controller_test.dart
//
// Stage 5：以 `FakeNativeBridge` 注入 `NativeBridgeFacade`，驗證
// `BleScanController` 的每個 method 都正確 routing 到 facade 並透傳參數/回傳。
//
// 這個測試的存在主要是為了：
//   1. 證明 `NativeBridgeFacade` 可被替換（Stage 5 acceptance）
//   2. 防回歸：未來若有人把 controller 改回直接呼叫 `NativeBridge.*` 靜態，
//      facade 替換會失效，本測試會炸掉。
//
// 不需要 sqflite / SharedPreferences / FFI，因為 controller 純粹是 facade
// 的 thin wrapper。

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/controllers/ble_scan_controller.dart';
import 'package:ignirelay_app/app/controllers/handoff_controller.dart';
import 'package:ignirelay_app/platform/native_bridge_facade.dart';

import '../fakes/fake_native_bridge.dart';

void main() {
  late FakeNativeBridge fake;

  setUp(() {
    fake = FakeNativeBridge();
    NativeBridgeFacade.instance = fake;
  });

  tearDown(() {
    fake.dispose();
    NativeBridgeFacade.resetToReal();
  });

  group('BleScanController → FakeNativeBridge', () {
    test('isBluetoothEnabled 透傳結果', () async {
      fake.bluetoothEnabled = false;
      expect(await BleScanController.instance.isBluetoothEnabled(), isFalse);

      fake.bluetoothEnabled = true;
      expect(await BleScanController.instance.isBluetoothEnabled(), isTrue);

      expect(fake.calls.map((c) => c.$1).toList(),
          ['isBluetoothEnabled', 'isBluetoothEnabled']);
    });

    test('requestBluetoothEnable 透傳結果', () async {
      fake.requestBluetoothEnableResult = false;
      expect(
          await BleScanController.instance.requestBluetoothEnable(), isFalse);
      expect(fake.calls.single.$1, 'requestBluetoothEnable');
    });

    test('startScan / stopScan', () async {
      fake.startScanResult = true;
      expect(await BleScanController.instance.startScan(), isTrue);
      await BleScanController.instance.stopScan();

      expect(fake.calls.map((c) => c.$1).toList(),
          ['startNordicScan', 'stopNordicScan']);
    });

    test('connect / disconnect 帶 deviceId', () async {
      fake.connectResult = true;
      expect(await BleScanController.instance.connect('dev-1'), isTrue);
      await BleScanController.instance.disconnect('dev-1');

      expect(fake.calls[0].$1, 'nordicConnect');
      expect(fake.calls[0].$2, {'deviceId': 'dev-1'});
      expect(fake.calls[1].$1, 'nordicDisconnect');
      expect(fake.calls[1].$2, {'deviceId': 'dev-1'});
    });

    test('readBloom 回傳 Uint8List?', () async {
      // null 回傳路徑
      expect(await BleScanController.instance.readBloom('dev-2'), isNull);

      // 帶資料回傳路徑
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      fake.readBloomResult = bytes;
      final result = await BleScanController.instance.readBloom('dev-2');
      expect(result, equals(bytes));

      expect(fake.calls.length, 2);
      expect(fake.calls.every((c) => c.$1 == 'nordicReadBloom'), isTrue);
    });

    test('writeHandshake 帶 bytes 並透傳結果（Stage 6-fix）', () async {
      final hs = Uint8List.fromList([0x11, 0x22, 0x33]);
      fake.writeHandshakeResult = false;
      expect(
          await BleScanController.instance.writeHandshake('peer-1', hs), isFalse);
      fake.writeHandshakeResult = true;
      expect(
          await BleScanController.instance.writeHandshake('peer-1', hs), isTrue);
      expect(fake.calls.map((c) => c.$1).toList(),
          ['nordicWriteHandshake', 'nordicWriteHandshake']);
      expect(fake.calls.first.$2['handshakeBytes'], equals(hs));
    });

    test('writeBloom / writeEvent 帶 bytes', () async {
      final bloom = Uint8List.fromList([0xAA, 0xBB]);
      final event = Uint8List.fromList([0xCC, 0xDD, 0xEE]);

      fake.writeBloomResult = true;
      fake.writeEventResult = false;

      expect(await BleScanController.instance.writeBloom('dev-3', bloom),
          isTrue);
      expect(await BleScanController.instance.writeEvent('dev-3', event),
          isFalse);

      expect(fake.calls[0].$1, 'nordicWriteBloom');
      expect(fake.calls[0].$2['deviceId'], 'dev-3');
      expect(fake.calls[0].$2['bloomBytes'], equals(bloom));

      expect(fake.calls[1].$1, 'nordicWriteEvent');
      expect(fake.calls[1].$2['deviceId'], 'dev-3');
      expect(fake.calls[1].$2['eventBytes'], equals(event));
    });

    test('rawEventStream 透傳 native event', () async {
      final received = <dynamic>[];
      final sub = BleScanController.instance.rawEventStream.listen(received.add);

      fake.nativeEventCtrl.add({'type': 'scan_result', 'rssi': -42});
      fake.nativeEventCtrl.add('plain-string-event');
      await Future<void>.delayed(Duration.zero);

      expect(received, [
        {'type': 'scan_result', 'rssi': -42},
        'plain-string-event',
      ]);

      await sub.cancel();
    });
  });

  group('HandoffController → FakeNativeBridge', () {
    test('startAdvertising 帶 named args', () async {
      fake.startHandoffAdvertisingResult = true;
      final ok = await HandoffController.instance.startAdvertising(
        resourceId: 'res-1',
        pinHash: 'sha-abc',
      );
      expect(ok, isTrue);

      expect(fake.calls.single.$1, 'startHandoffAdvertising');
      expect(fake.calls.single.$2,
          {'resourceId': 'res-1', 'pinHash': 'sha-abc'});
    });

    test('sendPin 帶 deviceId：Stage 6-fix 改走 nordicWriteHandshake', () async {
      // Stage 6-fix：deviceId 非空時，sendPin 改走 BLE writeHandshake，
      // 而不是 native sendHandoffPin（後者僅在 deviceId 為空時 fallback）。
      // 詳細的 BLE 路由與 JSON payload 驗證移到 handoff_controller_test.dart。
      fake.writeHandshakeResult = false;
      final ok = await HandoffController.instance.sendPin(
        deviceId: 'dev-x',
        resourceId: 'res-2',
        pin: '1234',
      );
      expect(ok, isFalse);
      expect(fake.calls.single.$1, 'nordicWriteHandshake');
    });

    test('stopAdvertising', () async {
      await HandoffController.instance.stopAdvertising();
      expect(fake.calls.single.$1, 'stopHandoffAdvertising');
    });

    test('events stream 透傳 handoff event', () async {
      final received = <Map<String, dynamic>>[];
      final sub = HandoffController.instance.events.listen(received.add);

      fake.handoffEventsCtrl.add({'type': 'pin_ok', 'resourceId': 'res-3'});
      await Future<void>.delayed(Duration.zero);

      expect(received, [
        {'type': 'pin_ok', 'resourceId': 'res-3'},
      ]);

      await sub.cancel();
    });
  });

  test('resetToReal 還原為正式實作', () {
    // setUp 已注入 fake；呼叫 resetToReal 後 instance 應 != fake
    NativeBridgeFacade.resetToReal();
    expect(identical(NativeBridgeFacade.instance, fake), isFalse);
  });
}
