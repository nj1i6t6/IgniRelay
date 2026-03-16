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

  /// ?? iOS/Android Tier 2 BLE 銝剔匱璅∪? (雿?)
  static Future<bool> startBleRelayMode() async {
    try {
      final bool result = await _channel.invokeMethod('startBleRelayMode');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to start BLE Relay Mode: '${e.message}'.");
      return false;
    }
  }

  /// ?迫???mesh ??
  static Future<void> stopAllServices() async {
    try {
      await _channel.invokeMethod('stopAllServices');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop services: '${e.message}'.");
    }
  }

  /// 更新 Native GATT Server 的 Bloom Filter 快取
  /// 當 Central 讀取 Bloom Characteristic 時會回傳此資料
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

  /// ???祆??餅??駁? (0-100)嚗瘜?敺???-1
  static Future<int> getBatteryLevel() async {
    try {
      final int level = await _channel.invokeMethod('getBatteryLevel');
      return level;
    } on PlatformException {
      return -1;
    }
  }


  /// ?? BLE 撱?嚗???鋆蔭?賜?暹蝭暺?
  static Future<bool> startBleAdvertising(
      List<int> pubKeyPrefix, int identityLevel) async {
    try {
      final bool result = await _channel.invokeMethod('startBleAdvertising', {
        'pubKeyPrefix': pubKeyPrefix.sublist(0, 4),
        'identityLevel': identityLevel,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("BLE advertising failed: '${e.message}'.");
      return false;
    }
  }

  // ?? 頝刻?蝵桀祕擃漱??PIN 撽? ?????????????????????????????????????

  // ?? ??? & ?餅??芸? ???????????????????????????????????????????

  /// ?? Mesh ???嚗?頛虜擏嚗甇Ｙ頂蝯望捏???堆?
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

  /// ?迫 Mesh ???
  static Future<void> stopMeshForegroundService() async {
    try {
      await _channel.invokeMethod('stopMeshForegroundService');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop foreground service: '${e.message}'.");
    }
  }

  /// 瑼Ｘ?臬撌脰??瘙??
  static Future<bool> isBatteryOptimizationExempt() async {
    try {
      final bool exempt =
          await _channel.invokeMethod('isBatteryOptimizationExempt');
      return exempt;
    } on PlatformException {
      return false;
    }
  }

  /// 隢??餅??芸?鞊?嚗??箇頂蝯勗?閰望?嚗?
  static Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final bool result =
          await _channel.invokeMethod('requestBatteryOptimizationExemption');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// ?? Android ?餅??芸?閮剖??
  static Future<bool> openBatterySettings() async {
    try {
      final bool result = await _channel.invokeMethod('openBatterySettings');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// ??鋆蔭鋆賡??迂嚗?撖恬?
  static Future<String> getManufacturer() async {
    try {
      final String manufacturer =
          await _channel.invokeMethod('getManufacturer');
      return manufacturer;
    } on PlatformException {
      return 'unknown';
    }
  }

  /// ???之撱?蝘??皞恣?身摰???
  /// (撠掖?芸???箏??圈??PPO ??賢???..)
  static Future<bool> openManufacturerPowerSettings() async {
    try {
      final bool result =
          await _channel.invokeMethod('openManufacturerPowerSettings');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// Provider 蝡荔???GATT Server ??Handshake Characteristic 銝?
  /// 撖怠敺漱?亥?閮?蝑? Requester ???撽? PIN
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

  /// Requester 蝡荔??? BLE Central 撖怠 PIN ??Provider ??GATT
  /// deviceId ??Provider ??BLE remoteId
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

  /// Provider 蝡荔??迫鈭斗撱?
  static Future<void> stopHandoffAdvertising() async {
    try {
      await _channel.invokeMethod('stopHandoffAdvertising');
    } on PlatformException catch (e) {
      debugPrint("Stop handoff advertising failed: '${e.message}'.");
    }
  }

  /// ??靘 GATT Server ?漱?仿?霅???
  /// ?鈭辣?澆?嚗'type': 'handoff_result', 'resourceId': ..., 'success': true/false}
  static Stream<Map<String, dynamic>> get handoffEvents {
    return nativeEventStream.where((event) {
      return event is Map && event['type'] == 'handoff_result';
    }).map((event) => Map<String, dynamic>.from(event));
  }

  /// ??靘摨惜??Mesh Events (Protobuf bytes stream)
  static Stream<List<int>> get incomingMeshEvents {
    return nativeEventStream
        .where((event) => event is List)
        .map((event) => List<int>.from(event));
  }
}
