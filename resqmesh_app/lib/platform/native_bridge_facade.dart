import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:ignirelay_app/platform/native_bridge.dart';

/// Stage 5：在 controller 與 `NativeBridge` static method 之間插入可替換的
/// facade，使 controller 單元測試能注入 `FakeNativeBridge`。
///
/// 設計原則（對齊 plan §Stage 5 L304-306「介面覆蓋面限縮」）：
///
/// - 只覆蓋本階段會動到的 controller（`HandoffController` +
///   `BleScanController`）實際使用的 method，共 14 個。
/// - **不**一次把 BLE / Wi-Fi Direct / NFC / battery / foreground service
///   全部 static 都包進來——其他方法仍由原有 wrapper (`DeviceInfoController`
///   等) 或未來階段（Stage 6 handoff 歸一化、Stage 7 全面清理）收斂。
/// - UI 全域零 `NativeBridge.` 直呼的硬驗收不因本 facade 限縮而放寬；
///   未抽進 facade 的 method，UI 仍不得繞過 controller 直呼，須走 controller
///   routing（此條已在 Stage 4a/4d 完成，本階段只做防回歸）。
///
/// 測試注入：
/// ```dart
/// setUp(() => NativeBridgeFacade.instance = FakeNativeBridge());
/// tearDown(() => NativeBridgeFacade.resetToReal());
/// ```
abstract class NativeBridgeFacade {
  // ── Handoff（HandoffController 4 個）──────────────────────────────

  Future<bool> startHandoffAdvertising({
    required String resourceId,
    required String pinHash,
  });

  Future<bool> sendHandoffPin({
    required String deviceId,
    required String resourceId,
    required String pin,
  });

  Future<void> stopHandoffAdvertising();

  Stream<Map<String, dynamic>> get handoffEvents;

  // ── BLE Central（BleScanController 10 個）─────────────────────────

  Future<bool> isBluetoothEnabled();

  Future<bool> requestBluetoothEnable();

  Future<bool> startNordicScan();

  Future<void> stopNordicScan();

  Future<bool> nordicConnect(String deviceId);

  Future<void> nordicDisconnect(String deviceId);

  Future<Uint8List?> nordicReadBloom(String deviceId);

  Future<bool> nordicWriteBloom(String deviceId, Uint8List bloomBytes);

  Future<bool> nordicWriteEvent(String deviceId, Uint8List eventBytes);

  /// Stage 6-fix：寫 PIN+resourceId JSON 到對端 HANDSHAKE_CHAR。
  /// 回傳值 = provider 端 GATT server 的 SHA-256 驗證結果（依 GATT response status 翻譯）。
  Future<bool> nordicWriteHandshake(String deviceId, Uint8List handshakeBytes);

  Stream<dynamic> get nativeEventStream;

  // ── Singleton / 測試替換 ──────────────────────────────────────────

  static NativeBridgeFacade _instance = _RealNativeBridgeFacade();

  static NativeBridgeFacade get instance => _instance;

  /// 僅供測試注入。於 `tearDown` 呼叫 `resetToReal()` 還原，避免污染其他測試。
  @visibleForTesting
  static set instance(NativeBridgeFacade f) => _instance = f;

  /// 還原為正式實作。
  @visibleForTesting
  static void resetToReal() => _instance = _RealNativeBridgeFacade();
}

/// 正式實作：每個方法透傳到對應的 `NativeBridge` static。
class _RealNativeBridgeFacade implements NativeBridgeFacade {
  @override
  Future<bool> startHandoffAdvertising({
    required String resourceId,
    required String pinHash,
  }) =>
      NativeBridge.startHandoffAdvertising(
        resourceId: resourceId,
        pinHash: pinHash,
      );

  @override
  Future<bool> sendHandoffPin({
    required String deviceId,
    required String resourceId,
    required String pin,
  }) =>
      NativeBridge.sendHandoffPin(
        deviceId: deviceId,
        resourceId: resourceId,
        pin: pin,
      );

  @override
  Future<void> stopHandoffAdvertising() => NativeBridge.stopHandoffAdvertising();

  @override
  Stream<Map<String, dynamic>> get handoffEvents => NativeBridge.handoffEvents;

  @override
  Future<bool> isBluetoothEnabled() => NativeBridge.isBluetoothEnabled();

  @override
  Future<bool> requestBluetoothEnable() => NativeBridge.requestBluetoothEnable();

  @override
  Future<bool> startNordicScan() => NativeBridge.startNordicScan();

  @override
  Future<void> stopNordicScan() => NativeBridge.stopNordicScan();

  @override
  Future<bool> nordicConnect(String deviceId) =>
      NativeBridge.nordicConnect(deviceId);

  @override
  Future<void> nordicDisconnect(String deviceId) =>
      NativeBridge.nordicDisconnect(deviceId);

  @override
  Future<Uint8List?> nordicReadBloom(String deviceId) =>
      NativeBridge.nordicReadBloom(deviceId);

  @override
  Future<bool> nordicWriteBloom(String deviceId, Uint8List bloomBytes) =>
      NativeBridge.nordicWriteBloom(deviceId, bloomBytes);

  @override
  Future<bool> nordicWriteEvent(String deviceId, Uint8List eventBytes) =>
      NativeBridge.nordicWriteEvent(deviceId, eventBytes);

  @override
  Future<bool> nordicWriteHandshake(String deviceId, Uint8List handshakeBytes) =>
      NativeBridge.nordicWriteHandshake(deviceId, handshakeBytes);

  @override
  Stream<dynamic> get nativeEventStream => NativeBridge.nativeEventStream;
}
