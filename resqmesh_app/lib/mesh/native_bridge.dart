import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('network.resqmesh/native');
  static const EventChannel _eventChannel =
      EventChannel('network.resqmesh/events');

  /// 共享的 Native EventChannel broadcast stream
  /// （EventChannel 只能 receiveBroadcastStream 一次，這裡用 asBroadcastStream 共享）
  static Stream<dynamic>? _sharedEventStream;
  static Stream<dynamic> get nativeEventStream {
    _sharedEventStream ??=
        _eventChannel.receiveBroadcastStream().asBroadcastStream();
    return _sharedEventStream!;
  }

  // ── Nordic BLE Central 操作（Android 專用）─────────────────────────────

  /// 啟動 Nordic BLE 掃描（軟體 UUID 過濾，解決 MediaTek 晶片 bug）
  static Future<bool> startNordicScan() async {
    try {
      final bool result = await _channel.invokeMethod('startNordicScan');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Nordic scan start failed: '${e.message}'.");
      return false;
    }
  }

  /// 停止 Nordic BLE 掃描
  static Future<void> stopNordicScan() async {
    try {
      await _channel.invokeMethod('stopNordicScan');
    } on PlatformException catch (e) {
      debugPrint("Nordic scan stop failed: '${e.message}'.");
    }
  }

  /// 連線到指定裝置（Nordic BLE Library 自動處理跨廠牌相容性 + MTU + 服務發現）
  static Future<bool> nordicConnect(String deviceId) async {
    try {
      final bool result = await _channel.invokeMethod('nordicConnect', {
        'deviceId': deviceId,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Nordic connect failed: '${e.message}'.");
      return false;
    }
  }

  /// 斷開指定裝置
  static Future<void> nordicDisconnect(String deviceId) async {
    try {
      await _channel.invokeMethod('nordicDisconnect', {
        'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      debugPrint("Nordic disconnect failed: '${e.message}'.");
    }
  }

  /// 讀取對端 Bloom Filter
  static Future<Uint8List?> nordicReadBloom(String deviceId) async {
    try {
      final result = await _channel.invokeMethod('nordicReadBloom', {
        'deviceId': deviceId,
      });
      if (result is Uint8List) return result;
      if (result is List) return Uint8List.fromList(List<int>.from(result));
      return null;
    } on PlatformException catch (e) {
      debugPrint("Nordic readBloom failed: '${e.message}'.");
      return null;
    }
  }

  /// 寫入事件到對端 Event Characteristic
  static Future<bool> nordicWriteEvent(
      String deviceId, Uint8List data) async {
    try {
      final bool result = await _channel.invokeMethod('nordicWriteEvent', {
        'deviceId': deviceId,
        'data': data,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Nordic writeEvent failed: '${e.message}'.");
      return false;
    }
  }

  // ── 原有 Peripheral / Service 操作 ─────────────────────────────────────

  /// 啟動 Android Tier 1 Data Mule 模式（掛載 Foreground Service）
  static Future<bool> startAndroidDataMuleMode() async {
    try {
      final bool result = await _channel.invokeMethod('startDataMuleMode');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to start Data Mule Mode: '${e.message}'.");
      return false;
    }
  }

  /// BLE Relay 模式
  static Future<bool> startBleRelayMode() async {
    try {
      final bool result = await _channel.invokeMethod('startBleRelayMode');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to start BLE Relay Mode: '${e.message}'.");
      return false;
    }
  }

  /// 停止所有 mesh 服務
  static Future<void> stopAllServices() async {
    try {
      await _channel.invokeMethod('stopAllServices');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop services: '${e.message}'.");
    }
  }

  /// 更新 Native GATT Server 的 Bloom Filter 快取
  static Future<bool> updateBloomFilter(Uint8List bloomBytes) async {
    try {
      final bool result = await _channel.invokeMethod('updateBloomFilter', {
        'bloom': bloomBytes,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to update bloom filter: '${e.message}'.");
      return false;
    }
  }

  /// 高頻寬傳輸請求（保留介面，目前回傳 false）
  static Future<bool> requestHighBandwidthTransfer(
      String peerMac, List<int> payload) async {
    try {
      final bool result =
          await _channel.invokeMethod('requestHighBandwidthTransfer', {
        'peer': peerMac,
        'payload_size': payload.length,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("High-bandwidth transfer failed: '${e.message}'.");
      return false;
    }
  }

  /// 取得裝置電池電量 (0-100)，失敗回傳 -1
  static Future<int> getBatteryLevel() async {
    try {
      final int level = await _channel.invokeMethod('getBatteryLevel');
      return level;
    } on PlatformException {
      return -1;
    }
  }

  /// 啟動 BLE 廣播（Peripheral 角色，透過 ForegroundService）
  static Future<bool> startBleAdvertising(
      List<int> pubKeyPrefix, int identityLevel) async {
    try {
      final bool result = await _channel.invokeMethod('startBleAdvertising', {
        'pubKeyPrefix': pubKeyPrefix.length >= 4
            ? pubKeyPrefix.sublist(0, 4)
            : pubKeyPrefix + List.filled(4 - pubKeyPrefix.length, 0),
        'identityLevel': identityLevel,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("BLE advertising failed: '${e.message}'.");
      return false;
    }
  }

  // ── 前景服務 & 電池優化 ─────────────────────────────────────────────────

  /// 啟動 Mesh 前景服務
  static Future<bool> startMeshForegroundService() async {
    try {
      final bool result =
          await _channel.invokeMethod('startMeshForegroundService');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to start foreground service: '${e.message}'.");
      return false;
    }
  }

  /// 停止 Mesh 前景服務
  static Future<void> stopMeshForegroundService() async {
    try {
      await _channel.invokeMethod('stopMeshForegroundService');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop foreground service: '${e.message}'.");
    }
  }

  /// 檢查是否已豁免電池優化
  static Future<bool> isBatteryOptimizationExempt() async {
    try {
      final bool exempt =
          await _channel.invokeMethod('isBatteryOptimizationExempt');
      return exempt;
    } on PlatformException {
      return false;
    }
  }

  /// 請求電池優化豁免
  static Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final bool result =
          await _channel.invokeMethod('requestBatteryOptimizationExemption');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// 開啟 Android 電池優化設定頁
  static Future<bool> openBatterySettings() async {
    try {
      final bool result = await _channel.invokeMethod('openBatterySettings');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// 取得裝置製造商名稱
  static Future<String> getManufacturer() async {
    try {
      final String manufacturer =
          await _channel.invokeMethod('getManufacturer');
      return manufacturer;
    } on PlatformException {
      return 'unknown';
    }
  }

  /// 開啟各廠牌私有的電源管理設定頁
  static Future<bool> openManufacturerPowerSettings() async {
    try {
      final bool result =
          await _channel.invokeMethod('openManufacturerPowerSettings');
      return result;
    } on PlatformException {
      return false;
    }
  }

  // ── 跨裝置 PIN 交接 ────────────────────────────────────────────────────

  /// Provider 端：啟動 GATT Server 廣播 Handshake Characteristic
  static Future<bool> startHandoffAdvertising({
    required String resourceId,
    required String pinHash,
  }) async {
    try {
      final bool result =
          await _channel.invokeMethod('startHandoffAdvertising', {
        'resourceId': resourceId,
        'pinHash': pinHash,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Handoff advertising failed: '${e.message}'.");
      return false;
    }
  }

  /// Requester 端：透過 BLE Central 發送 PIN 到 Provider 的 GATT
  static Future<bool> sendHandoffPin({
    required String deviceId,
    required String resourceId,
    required String pin,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('sendHandoffPin', {
        'deviceId': deviceId,
        'resourceId': resourceId,
        'pin': pin,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Handoff PIN send failed: '${e.message}'.");
      return false;
    }
  }

  /// Provider 端：停止交接廣播
  static Future<void> stopHandoffAdvertising() async {
    try {
      await _channel.invokeMethod('stopHandoffAdvertising');
    } on PlatformException catch (e) {
      debugPrint("Stop handoff advertising failed: '${e.message}'.");
    }
  }

  /// 監聽 GATT Server 的交接驗證結果
  static Stream<Map<String, dynamic>> get handoffEvents {
    return nativeEventStream.where((event) {
      return event is Map && event['type'] == 'handoff_result';
    }).map((event) => Map<String, dynamic>.from(event));
  }

  /// 監聽原始 Mesh Events (Protobuf bytes stream)
  static Stream<List<int>> get incomingMeshEvents {
    return nativeEventStream
        .where((event) => event is List)
        .map((event) => List<int>.from(event));
  }
}
