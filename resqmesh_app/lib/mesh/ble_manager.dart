import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import '../crdt/hlc.dart';
import '../db/database_helper.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import 'event_manager.dart';

/// ResQMesh BLE 服務 UUID（自定義 128-bit）
const String kResQMeshServiceUUID = 'f47a7b20-2d0a-11ee-be56-0242ac120002';
const String kEventCharUUID = 'f47a7b21-2d0a-11ee-be56-0242ac120002';
const String kBloomCharUUID = 'f47a7b22-2d0a-11ee-be56-0242ac120002';
const String kHandshakeCharUUID = 'f47a7b23-2d0a-11ee-be56-0242ac120002';

/// BLE Mesh 管理員
/// 負責掃描、連線、交換 Bloom Filter 和同步 Event 資料
/// 同時也負責消費 TriageQueue 中的待發送事件
class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  bool _isScanning = false;
  bool _isActive = false;

  // 已知節點快取（避免在同一輪掃描內重複連線）
  final Set<String> _knownPeers = {};
  // 節點冷卻時間（連線過的節點在 60 秒後才允許再次同步）
  final Map<String, DateTime> _peerCooldown = {};
  static const _cooldownDuration = Duration(seconds: 60);

  // 本機 Bloom Filter（已看過的 event_id 集合）
  final Set<String> _seenEvents = {};

  // 待連線設備佇列（序列化處理，避免 Android BLE 並行 GATT 衝突）
  final List<BluetoothDevice> _pendingDevices = [];
  bool _isConnecting = false;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _isScanningSubscription;

  final StreamController<BleEvent> _eventStreamController =
      StreamController<BleEvent>.broadcast();

  Stream<BleEvent> get events => _eventStreamController.stream;

  // 統計
  int syncedEventCount = 0;
  int receivedEventCount = 0;

  // ── Debug Log ──────────────────────────────────────────────────────────────
  static const int _maxDebugLogs = 80;
  final List<String> debugLogs = [];
  int scanCycleCount = 0;
  final Set<String> uniquePeersEverSeen = {};

  void _dlog(String msg) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = '[$ts] $msg';
    debugLogs.add(entry);
    if (debugLogs.length > _maxDebugLogs) debugLogs.removeAt(0);
    debugPrint('[BLE-DBG] $msg');
  }

  /// 啟動 BLE 掃描（Central 模式）
  Future<void> startScanning() async {
    if (_isScanning) return;

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _dlog('Bluetooth is OFF, cannot scan');
      return;
    }

    _isActive = true;
    _isScanning = true;
    scanCycleCount++;

    // 清除已過期的冷卻節點
    _cleanupCooldowns();

    _dlog('SCAN #$scanCycleCount started (known=${_knownPeers.length}, cooldown=${_peerCooldown.length}, seen=${_seenEvents.length})');

    await FlutterBluePlus.startScan(
      withServices: [Guid(kResQMeshServiceUUID)],
      timeout: const Duration(seconds: 30),
    );

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final deviceId = r.device.remoteId.str;
        final rssi = r.rssi;
        uniquePeersEverSeen.add(deviceId);
        if (!_knownPeers.contains(deviceId) && !_isInCooldown(deviceId)) {
          _knownPeers.add(deviceId);
          _pendingDevices.add(r.device);
          _dlog('FOUND $deviceId (RSSI=$rssi) → queued (pending=${_pendingDevices.length})');
        }
      }
      _processQueue();
    });

    // 只註冊一次自動重啟監聽
    _isScanningSubscription?.cancel();
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _isActive) {
        // 重設 _isScanning，讓下一輪 startScanning() 能進入
        _isScanning = false;
        _dlog('Scan stopped, will restart in 5s');
        Future.delayed(const Duration(seconds: 5), () {
          if (_isActive) startScanning();
        });
      }
    });
  }

  /// 停止掃描
  Future<void> stopScanning() async {
    _isActive = false;
    _isScanning = false;
    _dlog('SCAN STOPPED (manual)');
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _isScanningSubscription?.cancel();
    _isScanningSubscription = null;
    await FlutterBluePlus.stopScan();
  }

  bool _isInCooldown(String deviceId) {
    final last = _peerCooldown[deviceId];
    if (last == null) return false;
    return DateTime.now().difference(last) < _cooldownDuration;
  }

  void _cleanupCooldowns() {
    _peerCooldown.removeWhere(
        (_, time) => DateTime.now().difference(time) > _cooldownDuration);
    _knownPeers.clear();
  }

  /// 序列化處理連線佇列（一台連完再連下一台）
  Future<void> _processQueue() async {
    if (_isConnecting) return;
    _isConnecting = true;
    try {
      while (_pendingDevices.isNotEmpty && _isActive) {
        final device = _pendingDevices.removeAt(0);
        await _connectAndSync(device);
      }
    } finally {
      _isConnecting = false;
    }
  }

  /// 與發現的對等節點連線並執行 Epidemic Routing 同步
  Future<void> _connectAndSync(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    try {
      _dlog('CONNECT $deviceId ...');
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 10),
      );
      _dlog('CONNECTED $deviceId ✓');

      await device.discoverServices();
      final services = device.servicesList;

      BluetoothService? resqService;
      for (final s in services) {
        if (s.serviceUuid.str.toLowerCase() ==
            kResQMeshServiceUUID.toLowerCase()) {
          resqService = s;
          break;
        }
      }

      if (resqService == null) {
        _dlog('NO ResQMesh service on $deviceId (services=${services.length})');
        await device.disconnect();
        return;
      }

      // 找到特徵
      BluetoothCharacteristic? bloomChar;
      BluetoothCharacteristic? eventChar;

      for (final c in resqService.characteristics) {
        final uuid = c.characteristicUuid.str.toLowerCase();
        if (uuid == kBloomCharUUID.toLowerCase()) bloomChar = c;
        if (uuid == kEventCharUUID.toLowerCase()) eventChar = c;
      }

      _dlog('Chars: bloom=${bloomChar != null}, event=${eventChar != null}');

      if (bloomChar != null && eventChar != null) {
        // 1. 讀取對端 Bloom Filter（event_id UTF-8 列表，以 \n 分隔）
        final remoteBloomBytes = await bloomChar.read();
        final remoteEventIds = _parseBloomFilter(remoteBloomBytes);
        _dlog('BLOOM from $deviceId: ${remoteBloomBytes.length} bytes, ${remoteEventIds.length} event IDs');

        // 2. 從 TriageQueue 和 DB 取出需要推送的事件
        // 優先推送 TriageQueue 裡的高優先級事件
        final queue = EventManager().queue;
        final sentFromQueue = <String>{};

        while (!queue.isEmpty) {
          // 如果有 SOS_RED 搶佔，優先處理
          final task = queue.dequeue();
          if (task == null) break;
          if (remoteEventIds.contains(task.eventId)) continue;
          if (_seenEvents.contains(task.eventId)) continue;

          try {
            // 構建 Protobuf MeshEvent 傳輸
            final wireData = _encodeWirePayload(
              task.eventId,
              task.payload,
              urgency: task.urgency,
            );
            await eventChar.write(wireData, withoutResponse: false);
            _seenEvents.add(task.eventId);
            sentFromQueue.add(task.eventId);
            syncedEventCount++;
            _dlog('SENT(queue) ${task.eventId.substring(0, 8)}.. urgency=${task.urgency} → $deviceId');
          } catch (e) {
            // 傳送失敗，放回佇列
            queue.enqueue(task);
            debugPrint('[BLE] Queue write error: $e');
            break;
          }
        }

        // 3. 從 DB 補充最近 24 小時的事件（不再用 is_synced 過濾，
        //    改靠 Bloom Filter 避免重複傳送，讓事件能多跳擴散）
        final db = await DatabaseHelper().database;
        final cutoff24h =
            DateTime.now().millisecondsSinceEpoch - (24 * 3600 * 1000);
        final myEvents = await db.query(
          'Event_Logs',
          columns: [
            'event_id',
            'payload',
            'signature',
            'urgency',
            'sender_pub_key',
            'hlc_timestamp',
            'hlc_counter',
            'received_lat',
            'received_lng',
            'identity_level',
          ],
          where: 'hlc_timestamp > ?',
          whereArgs: [cutoff24h],
          orderBy: 'urgency DESC, hlc_timestamp DESC',
          limit: 50,
        );

        _dlog('DB query: ${myEvents.length} events in last 24h');

        for (final evt in myEvents) {
          final evtId = evt['event_id'] as String;
          if (remoteEventIds.contains(evtId)) {
            _dlog('SKIP(bloom) ${evtId.substring(0, 8)}..');
            continue;
          }
          if (_seenEvents.contains(evtId)) {
            _dlog('SKIP(seen) ${evtId.substring(0, 8)}..');
            continue;
          }
          if (sentFromQueue.contains(evtId)) continue;

          final payload = evt['payload'] as Uint8List?;
          if (payload != null) {
            try {
              final wireData = _encodeWirePayload(
                evtId,
                payload.toList(),
                urgency: (evt['urgency'] as int?) ?? 0,
                eventType: (evt['event_type'] as int?) ?? 0,
                signature: (evt['signature'] as Uint8List?)?.toList(),
                senderPubKey: (evt['sender_pub_key'] as Uint8List?)?.toList(),
                hlcTimestamp: (evt['hlc_timestamp'] as int?) ?? 0,
                hlcCounter: (evt['hlc_counter'] as int?) ?? 0,
                lat: (evt['received_lat'] as num?)?.toDouble(),
                lng: (evt['received_lng'] as num?)?.toDouble(),
              );
              await eventChar.write(wireData, withoutResponse: false);
              _seenEvents.add(evtId);
              syncedEventCount++;
              _dlog('SENT(db) ${evtId.substring(0, 8)}.. type=${evt['event_type']} urg=${evt['urgency']} → $deviceId');
            } catch (e) {
              debugPrint('[BLE] Write error: $e');
              break;
            }
          }
        }

        // 4. 訂閱接收對端推送過來的事件
        if (eventChar.properties.notify) {
          await eventChar.setNotifyValue(true);
          _dlog('Subscribed to notifications from $deviceId');
          eventChar.lastValueStream.listen((data) {
            if (data.isNotEmpty) {
              _dlog('NOTIFY from $deviceId: ${data.length} bytes');
              _handleIncomingPayload(data, deviceId);
            }
          });
        } else {
          _dlog('eventChar.notify NOT supported on $deviceId');
        }
      } else {
        _dlog('SKIP sync: missing chars on $deviceId');
      }

      _eventStreamController.add(BleEvent.connected(deviceId));

      // 設定冷卻時間
      _peerCooldown[deviceId] = DateTime.now();
      _dlog('DONE with $deviceId (sent=$syncedEventCount, recv=$receivedEventCount) → cooldown 60s');

      // 延遲斷線
      await Future.delayed(const Duration(seconds: 2));
      await device.disconnect();
    } catch (e) {
      _dlog('ERROR $deviceId: $e');
      _knownPeers.remove(deviceId); // 允許之後重試
    }
  }

  /// 處理從對等節點接收到的 payload
  /// wire 格式: eventId(36 bytes UUID) + '|' + payload bytes
  Future<void> _handleIncomingPayload(
      List<int> data, String sourceDeviceId) async {
    try {
      final decoded = _decodeWirePayload(data);
      if (decoded == null) {
        debugPrint('[BLE] Invalid wire payload from $sourceDeviceId');
        return;
      }

      final evtId = decoded.eventId;
      final payload = decoded.payload;

      _dlog('RECV ${evtId.substring(0, 8)}.. type=${decoded.eventType} urg=${decoded.urgency} payload=${payload.length}B from $sourceDeviceId');

      if (_seenEvents.contains(evtId)) {
        _dlog('RECV SKIP(seen) ${evtId.substring(0, 8)}..');
        return;
      }
      _seenEvents.add(evtId);

      // TODO: 完整 Protobuf 解析後可以做簽名驗證
      // 使用從 Protobuf 解碼出的資訊

      // 合併 HLC（確保時間同步）
      if (decoded.hlcTimestamp > 0) {
        HLC.merge(HLC(decoded.hlcTimestamp, decoded.hlcCounter));
      } else {
        HLC.merge(HLC(DateTime.now().millisecondsSinceEpoch, 0));
      }

      // 存入本地資料庫
      final db = await DatabaseHelper().database;
      try {
        await db.insert('Event_Logs', {
          'event_id': evtId,
          'sender_pub_key': decoded.senderPubKey != null
              ? Uint8List.fromList(decoded.senderPubKey!)
              : Uint8List.fromList(utf8.encode(sourceDeviceId)),
          'identity_level': 0,
          'event_type': decoded.eventType,
          'urgency': decoded.urgency,
          'hlc_timestamp': decoded.hlcTimestamp > 0
              ? decoded.hlcTimestamp
              : DateTime.now().millisecondsSinceEpoch,
          'hlc_counter': decoded.hlcCounter,
          'ttl': decoded.ttl > 0 ? decoded.ttl - 1 : 9,
          'received_lat': decoded.lat,
          'received_lng': decoded.lng,
          'node_tier': 2,
          'chunk_index': 0,
          'total_chunks': 1,
          'payload': Uint8List.fromList(payload),
          'signature': decoded.signature != null
              ? Uint8List.fromList(decoded.signature!)
              : Uint8List(0),
          'is_synced': 0, // 收到的事件需要繼續轉發
        });
      } catch (e) {
        // UNIQUE constraint 失敗代表已有此事件，忽略
        debugPrint('[BLE] DB insert skipped (duplicate): $evtId');
      }

      // 如果是危險區域事件，解析 payload 並寫入 Hazards_State（讓地圖 UI 顯示）
      if (decoded.eventType == EventType.hazardMarker && payload.isNotEmpty) {
        try {
          final hazard = pb.HazardData.fromBuffer(payload);
          if (hazard.hazardId.isNotEmpty &&
              hazard.centerLat != 0 &&
              hazard.centerLng != 0) {
            final reporterHex = decoded.senderPubKey != null
                ? decoded.senderPubKey!
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join()
                : sourceDeviceId;
            await db.insert('Hazards_State', {
              'hazard_id': hazard.hazardId,
              'type': hazard.hazardType,
              'severity': hazard.severity,
              'lat': hazard.centerLat,
              'lng': hazard.centerLng,
              'radius': hazard.radiusMeters > 0 ? hazard.radiusMeters : 200.0,
              'reported_by': reporterHex,
              'created_at': hazard.observedAt.toInt() > 0
                  ? hazard.observedAt.toInt()
                  : DateTime.now().millisecondsSinceEpoch,
              'confirm_count': 1,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            });
            debugPrint(
                '[BLE] Hazard synced to Hazards_State: ${hazard.hazardId}');
          }
        } catch (e) {
          // 解析失敗或 UNIQUE 重複，忽略
          debugPrint('[BLE] Hazard sync skipped: $e');
        }
      }

      receivedEventCount++;
      _eventStreamController.add(BleEvent.received(sourceDeviceId, payload));
      debugPrint(
          '[BLE] Received event $evtId (${payload.length} bytes) from $sourceDeviceId');
    } catch (e) {
      debugPrint('[BLE] Parse error: $e');
    }
  }

  /// 將 Bloom Filter bytes 解析為事件 ID 集合
  /// 格式：UTF-8 編碼的 event_id 列表，以 '\n' 分隔
  Set<String> _parseBloomFilter(List<int> bytes) {
    final result = <String>{};
    if (bytes.isEmpty) return result;
    try {
      final str = utf8.decode(bytes);
      for (final id in str.split('\n')) {
        final trimmed = id.trim();
        if (trimmed.isNotEmpty) result.add(trimmed);
      }
    } catch (_) {
      // 解析失敗，回傳空集合（全量同步）
    }
    return result;
  }

  /// 編碼 wire payload：使用 Protobuf MeshEvent 封裝
  /// 包含 eventId, urgency, hlc, payload, signature 等完整資訊
  List<int> _encodeWirePayload(
    String eventId,
    List<int> payload, {
    int urgency = 0,
    int eventType = 0,
    List<int>? signature,
    List<int>? senderPubKey,
    int? hlcTimestamp,
    int? hlcCounter,
    int ttl = 10,
    double? lat,
    double? lng,
  }) {
    final meshEvent = pb.MeshEvent()
      ..eventId = eventId
      ..urgency = pb.UrgencyLevel.valueOf(urgency) ?? pb.UrgencyLevel.INFO
      ..type = pb.EventType.valueOf(eventType) ?? pb.EventType.RESOURCE_REGISTER
      ..payload = payload
      ..ttl = ttl;
    if (signature != null) meshEvent.signature = signature;
    if (senderPubKey != null) meshEvent.senderPubKey = senderPubKey;
    if (hlcTimestamp != null)
      meshEvent.hlcTimestamp = fixnum.Int64(hlcTimestamp);
    if (hlcCounter != null) meshEvent.hlcCounter = fixnum.Int64(hlcCounter);
    if (lat != null) meshEvent.receivedLat = lat;
    if (lng != null) meshEvent.receivedLng = lng;
    return meshEvent.writeToBuffer();
  }

  /// 解碼 wire payload：嘗試 Protobuf MeshEvent，失敗則 fallback 到舊格式
  _WirePayload? _decodeWirePayload(List<int> data) {
    // 先嘗試 Protobuf 解枋
    try {
      final meshEvent = pb.MeshEvent.fromBuffer(data);
      if (meshEvent.eventId.isNotEmpty) {
        return _WirePayload(
          meshEvent.eventId,
          meshEvent.payload,
          urgency: meshEvent.urgency.value,
          eventType: meshEvent.type.value,
          hlcTimestamp: meshEvent.hlcTimestamp.toInt(),
          hlcCounter: meshEvent.hlcCounter.toInt(),
          ttl: meshEvent.ttl,
          lat: meshEvent.receivedLat,
          lng: meshEvent.receivedLng,
          signature: meshEvent.signature,
          senderPubKey: meshEvent.senderPubKey,
        );
      }
    } catch (_) {}

    // Fallback: 舊版格式 eventId(36) + '|' + payload
    try {
      final pipeIndex = data.indexOf(0x7C); // '|' = 0x7C
      if (pipeIndex < 1) return null;
      final eventId = utf8.decode(data.sublist(0, pipeIndex));
      final payload = data.sublist(pipeIndex + 1);
      return _WirePayload(eventId, payload);
    } catch (_) {
      return null;
    }
  }

  /// 取得本機已知事件 ID 列表（用於建構 Bloom Filter）
  Future<Uint8List> buildLocalBloomFilter() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'Event_Logs',
      columns: ['event_id'],
      orderBy: 'hlc_timestamp DESC',
      limit: 200,
    );
    final ids = rows.map((r) => r['event_id'] as String).join('\n');
    return Uint8List.fromList(utf8.encode(ids));
  }

  bool get isScanning => _isScanning;
  bool get isActive => _isActive;
  bool get isConnecting => _isConnecting;
  int get pendingCount => _pendingDevices.length;
  int get knownPeersCount => _knownPeers.length;
  int get cooldownCount => _peerCooldown.length;
  int get seenEventsCount => _seenEvents.length;
}

/// Wire payload 解碼結果
class _WirePayload {
  final String eventId;
  final List<int> payload;
  final int urgency;
  final int eventType;
  final int hlcTimestamp;
  final int hlcCounter;
  final int ttl;
  final double? lat;
  final double? lng;
  final List<int>? signature;
  final List<int>? senderPubKey;

  _WirePayload(
    this.eventId,
    this.payload, {
    this.urgency = 0,
    this.eventType = 0,
    this.hlcTimestamp = 0,
    this.hlcCounter = 0,
    this.ttl = 9,
    this.lat,
    this.lng,
    this.signature,
    this.senderPubKey,
  });
}

/// BLE 事件通知
class BleEvent {
  final String type;
  final String deviceId;
  final List<int>? data;

  BleEvent.connected(this.deviceId)
      : type = 'connected',
        data = null;
  BleEvent.received(this.deviceId, this.data) : type = 'received';
  BleEvent.disconnected(this.deviceId)
      : type = 'disconnected',
        data = null;
}
