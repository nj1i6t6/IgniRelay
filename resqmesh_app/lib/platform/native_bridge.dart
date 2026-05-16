import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('network.ignirelay/native');
  static const EventChannel _eventChannel =
      EventChannel('network.ignirelay/events');

  /// 共享的 Native EventChannel broadcast stream
  /// （EventChannel 只能 receiveBroadcastStream 一次，這裡用 asBroadcastStream 共享）
  static Stream<dynamic>? _sharedEventStream;
  static Stream<dynamic> get nativeEventStream {
    _sharedEventStream ??=
        _eventChannel.receiveBroadcastStream().asBroadcastStream();
    return _sharedEventStream!;
  }

  // ── 藍牙硬體狀態檢查 ─────────────────────────────────────────────────

  /// 檢查藍牙硬體是否已開啟
  static Future<bool> isBluetoothEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isBluetoothEnabled');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// 請求系統開啟藍牙（觸發 ACTION_REQUEST_ENABLE）
  static Future<bool> requestBluetoothEnable() async {
    try {
      final bool result = await _channel.invokeMethod('requestBluetoothEnable');
      return result;
    } on PlatformException {
      return false;
    }
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

  /// Bug 10 Fix: 寫入本機 Bloom Filter 到對端 Bloom Characteristic
  /// 觸發對端 GATT Server 做差量比對後 Notify 推送缺少的事件。
  static Future<bool> nordicWriteBloom(
      String deviceId, Uint8List data) async {
    try {
      final bool result = await _channel.invokeMethod('nordicWriteBloom', {
        'deviceId': deviceId,
        'data': data,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Nordic writeBloom failed: '${e.message}'.");
      return false;
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

  /// v0.3 Stage 0c wave 3B — Peripheral 角色 (GATT Server) 主動 Notify 一個
  /// EVENT_CHAR chunk 給已 subscribe 的 Central。
  ///
  /// 與 [nordicWriteEvent] 對稱：v2 chunked 流量在 Dart 端切好 chunks 後，依
  /// 連線角色決定走哪一邊：central 角色用 nordicWriteEvent (peripheral 收)；
  /// peripheral 角色用 notifyEventChunk (central 收)。
  ///
  /// Spec: docs/specs/native_transport_v1_2026-05-13.md §4.5 (Option B mandate).
  static Future<bool> notifyEventChunk(
      String deviceId, Uint8List data) async {
    try {
      final bool result = await _channel.invokeMethod('notifyEventChunk', {
        'deviceId': deviceId,
        'data': data,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("notifyEventChunk failed: '${e.message}'.");
      return false;
    }
  }

  /// Stage 6-fix：把 PIN+resourceId JSON 寫到對端 Handshake Characteristic。
  /// Provider 的 GATT server 在收到後做 SHA-256 + resourceId 比對，並透過
  /// GATT response status 回報結果（Android：GATT_SUCCESS / GATT_FAILURE；
  /// iOS：CBATTError.success / .writeNotPermitted）。本 future 的回傳值即
  /// 「PIN 在 provider 端驗證通過」。
  static Future<bool> nordicWriteHandshake(
      String deviceId, Uint8List data) async {
    try {
      final bool result = await _channel.invokeMethod('nordicWriteHandshake', {
        'deviceId': deviceId,
        'data': data,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Nordic writeHandshake failed: '${e.message}'.");
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

  /// Bug 7 Fix: 更新事件 outbox（供 GATT Server Notify 反向推送）
  /// 當 Central 連上並 subscribe Event Char 通知時，Server 主動推送這些事件。
  /// 解決 OPPO GATT Server 壞掉導致 OPPO 無法接收資料的問題。
  static Future<bool> updateEventOutbox(List<Uint8List> events) async {
    try {
      // Length-prefix framed 格式: [4-byte len][event bytes] ...
      final buffer = BytesBuilder();
      for (final event in events) {
        final len = event.length;
        buffer.add([
          (len >> 24) & 0xFF,
          (len >> 16) & 0xFF,
          (len >> 8) & 0xFF,
          len & 0xFF,
        ]);
        buffer.add(event);
      }
      final bool result = await _channel.invokeMethod('updateEventOutbox', {
        'data': buffer.toBytes(),
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to update event outbox: '${e.message}'.");
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

  /// 查詢 GATT Server 狀態（持久狀態，不依賴 log buffer）
  static Future<Map<String, dynamic>> getGattServerStatus() async {
    try {
      final result = await _channel.invokeMethod('getGattServerStatus');
      if (result is Map) return Map<String, dynamic>.from(result);
      return {'ready': false, 'status': -999};
    } on PlatformException {
      return {'ready': false, 'status': -999};
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

  /// 監聽 GATT Server 的交接驗證結果。
  ///
  /// Stage 6-fix：除了 `handoff_result`（新版兩端統一型別），也放行 `handshake_data`
  /// （未升級之 iOS legacy）。`HandoffController._normalizeEvent` 會把後者
  /// fallback 為 `success=false + legacy=true`，避免 stream 上層收不到事件。
  static Stream<Map<String, dynamic>> get handoffEvents {
    return nativeEventStream.where((event) {
      if (event is! Map) return false;
      final t = event['type'];
      return t == 'handoff_result' || t == 'handshake_data';
    }).map((event) => Map<String, dynamic>.from(event));
  }

  /// 監聽原始 Mesh Events (Protobuf bytes stream)
  static Stream<List<int>> get incomingMeshEvents {
    return nativeEventStream
        .where((event) => event is List)
        .map((event) => List<int>.from(event));
  }
}
