import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'event_manager.dart';
import 'mesh_constants.dart';
import 'mesh_event_handler.dart';
import 'native_bridge.dart';
import '../db/database_helper.dart';

/// BLE Mesh 管理員（Central 角色）
///
/// 平台感知路由：
/// - Android → Nordic BLE Library（透過 MethodChannel）
///   解決跨廠牌（MediaTek / Qualcomm / Exynos）相容性問題
/// - iOS → flutter_blue_plus（Core Bluetooth 本來就穩定）
///
/// 上層邏輯（Bloom Filter 比對、DB 查詢、TriageQueue 消費）保留在 Dart，
/// 只有 BLE 原語（掃描、連線、讀寫）走平台專用路徑。
class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  bool _isScanning = false;
  bool _isActive = false;

  final MeshEventHandler _eventHandler = MeshEventHandler();

  // 已知節點快取（避免在同一輪掃描內重複連線）
  final Set<String> _knownPeers = {};
  // 節點冷卻時間
  final Map<String, DateTime> _peerCooldown = {};

  // 待連線設備佇列（序列化處理，避免 Android BLE 並行 GATT 衝突）
  // Android: 存 String (deviceAddress), iOS: 存 BluetoothDevice
  final List<dynamic> _pendingDevices = [];
  bool _isConnecting = false;

  // Bug 5 Fix: 取消標記 — timeout 時設定，sync 每步檢查
  final Set<String> _cancelledSyncs = {};

  StreamSubscription? _scanSubscription;
  StreamSubscription? _isScanningSubscription;
  StreamSubscription? _nordicEventSub;

  final StreamController<BleEvent> _eventStreamController =
      StreamController<BleEvent>.broadcast();

  Stream<BleEvent> get events => _eventStreamController.stream;

  // 統計
  int syncedEventCount = 0;
  int receivedEventCount = 0;

  // ── Debug Log ──────────────────────────────────────────────────────────
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

    if (Platform.isAndroid) {
      await _startAndroidNordicScan();
    } else {
      await _startIosScan();
    }
  }

  /// 停止掃描
  Future<void> stopScanning() async {
    _isActive = false;
    _isScanning = false;
    _dlog('SCAN STOPPED (manual)');

    if (Platform.isAndroid) {
      await NativeBridge.stopNordicScan();
      await _nordicEventSub?.cancel();
      _nordicEventSub = null;
    } else {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      await _isScanningSubscription?.cancel();
      _isScanningSubscription = null;
      await FlutterBluePlus.stopScan();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── Android: Nordic BLE Library via MethodChannel ────────────────────
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _startAndroidNordicScan() async {
    _isActive = true;
    _isScanning = true;
    scanCycleCount++;

    _cleanupCooldowns();
    _updateNativeBloomFilter();

    _dlog('NORDIC SCAN #$scanCycleCount started (known=${_knownPeers.length}, cooldown=${_peerCooldown.length}, seen=${_eventHandler.seenEventsCount})');

    // 監聽 Nordic EventChannel 事件
    _nordicEventSub?.cancel();
    _nordicEventSub = NativeBridge.nativeEventStream.listen((event) {
      if (event is Map) {
        final type = event['type'] as String?;
        if (type == 'nordic_found') {
          _handleNordicDeviceFound(event);
        } else if (type == 'nordic_data') {
          _handleNordicDataReceived(event);
        } else if (type == 'gatt_op_fail') {
          final op = event['op'] ?? '';
          final status = event['status'] ?? -1;
          final reason = event['reason'] ?? '';
          _dlog('GATT_FAIL($op) status=$status${reason.toString().isNotEmpty ? " reason=$reason" : ""}');
        } else if (type == 'gatt_service_added') {
          final success = event['success'] ?? false;
          final status = event['status'] ?? -1;
          _dlog('GATT_SVC_ADD ${success == true ? "OK" : "FAIL"} status=$status');
        } else if (type == 'gatt_server_error') {
          final error = event['error'] ?? '';
          _dlog('GATT_SERVER_ERR: $error');
        } else if (type == 'gatt_mtu') {
          final device = event['device'] ?? '';
          final mtu = event['mtu'] ?? 0;
          _dlog('GATT_MTU $device → $mtu');
        }
      }
    });

    // 啟動 Nordic 掃描
    final success = await NativeBridge.startNordicScan();
    if (!success) {
      _dlog('Nordic scan failed to start');
      _isScanning = false;
      return;
    }

    // 定時重啟掃描循環（模擬 flutter_blue_plus 的 timeout + restart）
    _scheduleNordicScanRestart();
  }

  void _scheduleNordicScanRestart() {
    Future.delayed(Duration(seconds: kScanDurationSec), () async {
      if (!_isActive) return;
      await NativeBridge.stopNordicScan();
      _isScanning = false;
      _dlog('Nordic scan cycle done, restart in ${kScanRestartDelaySec}s');
      Future.delayed(Duration(seconds: kScanRestartDelaySec), () {
        if (_isActive) _startAndroidNordicScan();
      });
    });
  }

  void _handleNordicDeviceFound(Map event) {
    final deviceId = event['device'] as String? ?? '';
    final rssi = event['rssi'] as int? ?? 0;
    if (deviceId.isEmpty) return;

    uniquePeersEverSeen.add(deviceId);
    if (!_knownPeers.contains(deviceId) && !_isInCooldown(deviceId)
        && !_pendingDevices.contains(deviceId)) {
      _knownPeers.add(deviceId);
      _pendingDevices.add(deviceId); // Android: 存 String
      _dlog('FOUND $deviceId (RSSI=$rssi) → queued (pending=${_pendingDevices.length})');
    }
    _processQueue();
  }

  void _handleNordicDataReceived(Map event) {
    final deviceId = event['device'] as String? ?? 'unknown';
    final dataList = event['data'];
    if (dataList is List && dataList.isNotEmpty) {
      final data = Uint8List.fromList(List<int>.from(dataList));
      _dlog('NOTIFY from $deviceId: ${data.length} bytes (Nordic)');
      _eventHandler.handleIncomingData(data, deviceId);
      receivedEventCount++;
      _eventStreamController.add(BleEvent.received(deviceId, data.toList()));
    }
  }

  /// Bug 5 Fix: 檢查 sync 是否已被 timeout 取消
  bool _isCancelled(String deviceId) => _cancelledSyncs.contains(deviceId);

  /// Android: 使用 Nordic 連線並同步
  Future<void> _nordicConnectAndSync(String deviceId) async {
    // Bug 5 Fix: 清除之前的取消標記（新的 sync 開始）
    _cancelledSyncs.remove(deviceId);

    try {
      _dlog('NORDIC CONNECT $deviceId ...');
      final connected = await NativeBridge.nordicConnect(deviceId);
      if (_isCancelled(deviceId)) { _dlog('CANCELLED(connect) $deviceId'); return; }
      if (!connected) {
        _dlog('NORDIC CONNECT FAILED $deviceId');
        _knownPeers.remove(deviceId);
        return;
      }
      _dlog('NORDIC CONNECTED $deviceId ✓ (MTU + services auto-negotiated)');

      // ── 1. 讀取對端 Bloom Filter ──
      // Bug 6 Fix: OPPO/ColorOS GATT Server 不回應 read requests（已知 BLE stack 問題）。
      // Nordic 端已加 5s timeout，讀取失敗時進入 blind relay 模式（發送全部事件）。
      // 接收端已有 SKIP(seen) 去重機制，不會重複處理。
      final remoteBloomBytes = await NativeBridge.nordicReadBloom(deviceId);
      if (_isCancelled(deviceId)) { _dlog('CANCELLED(bloom) $deviceId'); return; }
      final remoteEventIds = remoteBloomBytes != null
          ? MeshEventHandler.parseBloomFilter(remoteBloomBytes.toList())
          : <String>{};
      if (remoteBloomBytes == null || remoteBloomBytes.isEmpty) {
        _dlog('BLOOM_SKIP $deviceId — read failed/timeout, blind relay mode (sending all events)');
      } else {
        _dlog('BLOOM from $deviceId: ${remoteBloomBytes.length} bytes, ${remoteEventIds.length} event IDs');
      }

      // ── 2. 推送 TriageQueue 中的高優先級事件 ──
      final queue = EventManager().queue;
      final sentFromQueue = <String>{};

      while (!queue.isEmpty) {
        if (_isCancelled(deviceId)) { _dlog('CANCELLED(queue) $deviceId'); return; }
        final task = queue.dequeue();
        if (task == null) break;
        if (remoteEventIds.contains(task.eventId)) continue;

        try {
          final wireData = MeshEventHandler.encodeWirePayload(
            task.eventId,
            task.payload,
            urgency: task.urgency,
            eventType: task.eventType,
          );
          final success = await NativeBridge.nordicWriteEvent(
            deviceId,
            Uint8List.fromList(wireData),
          );
          if (_isCancelled(deviceId)) { queue.enqueue(task); return; }
          if (success) {
            sentFromQueue.add(task.eventId);
            syncedEventCount++;
            _dlog('SENT(queue) ${task.eventId.substring(0, 8)}.. urg=${task.urgency} → $deviceId');
          } else {
            queue.enqueue(task);
            break;
          }
        } catch (e) {
          queue.enqueue(task);
          debugPrint('[BLE] Nordic queue write error: $e');
          break;
        }
      }

      if (_isCancelled(deviceId)) { _dlog('CANCELLED(pre-db) $deviceId'); return; }

      // ── 3. 從 DB 補充最近 24h 的事件 ──
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
          'event_type',
          'sender_pub_key',
          'hlc_timestamp',
          'hlc_counter',
          'received_lat',
          'received_lng',
          'origin_lat',
          'origin_lng',
        ],
        where: 'hlc_timestamp > ?',
        whereArgs: [cutoff24h],
        orderBy: 'urgency DESC, hlc_timestamp DESC',
        limit: 50,
      );

      _dlog('DB query: ${myEvents.length} events in last 24h');

      int dbBloomSkipped = 0;
      int dbAttempted = 0;
      int dbSent = 0;

      for (final evt in myEvents) {
        if (_isCancelled(deviceId)) { _dlog('CANCELLED(db-loop) $deviceId'); return; }
        final evtId = evt['event_id'] as String;
        if (remoteEventIds.contains(evtId)) { dbBloomSkipped++; continue; }
        if (sentFromQueue.contains(evtId)) continue;

        final payload = evt['payload'] as Uint8List?;
        if (payload != null) {
          dbAttempted++;
          try {
            final wireData = MeshEventHandler.encodeWirePayload(
              evtId,
              payload.toList(),
              urgency: (evt['urgency'] as int?) ?? 0,
              eventType: (evt['event_type'] as int?) ?? 0,
              signature: (evt['signature'] as Uint8List?)?.toList(),
              senderPubKey:
                  (evt['sender_pub_key'] as Uint8List?)?.toList(),
              hlcTimestamp: (evt['hlc_timestamp'] as int?) ?? 0,
              hlcCounter: (evt['hlc_counter'] as int?) ?? 0,
              lat: (evt['received_lat'] as num?)?.toDouble(),
              lng: (evt['received_lng'] as num?)?.toDouble(),
              originLat: (evt['origin_lat'] as num?)?.toDouble(),
              originLng: (evt['origin_lng'] as num?)?.toDouble(),
            );
            final success = await NativeBridge.nordicWriteEvent(
              deviceId,
              Uint8List.fromList(wireData),
            );
            if (_isCancelled(deviceId)) return;
            if (success) {
              dbSent++;
              syncedEventCount++;
              _dlog('SENT(db) ${evtId.substring(0, 8)}.. urg=${evt['urgency']} → $deviceId');
            } else {
              _dlog('WRITE_FAIL(db) ${evtId.substring(0, 8)}.. urg=${evt['urgency']} → $deviceId (wireLen=${wireData.length}B)');
              break;
            }
          } catch (e) {
            _dlog('WRITE_ERR(db) ${evtId.substring(0, 8)}.. → $deviceId: $e');
            break;
          }
        }
      }

      _dlog('RELAY_STATS → $deviceId: bloom_skip=$dbBloomSkipped attempted=$dbAttempted sent=$dbSent');

      // ── 4. 通知已由 Nordic 自動啟用，資料透過 EventChannel 接收 ──
      _eventStreamController.add(BleEvent.connected(deviceId));
      _peerCooldown[deviceId] = DateTime.now();
      _dlog('DONE with $deviceId (sent=$syncedEventCount, recv=$receivedEventCount) → cooldown ${kPeerCooldownSec}s');

      await Future.delayed(const Duration(seconds: 2));
      await NativeBridge.nordicDisconnect(deviceId);
    } catch (e) {
      if (_isCancelled(deviceId)) return; // 被取消導致的異常，靜默處理
      _dlog('ERROR $deviceId: $e');
      _knownPeers.remove(deviceId);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── iOS: flutter_blue_plus (Core Bluetooth) ─────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _startIosScan() async {
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _dlog('Bluetooth is OFF, cannot scan');
      return;
    }

    _isActive = true;
    _isScanning = true;
    scanCycleCount++;

    _cleanupCooldowns();
    _updateNativeBloomFilter();

    _dlog('IOS SCAN #$scanCycleCount started (known=${_knownPeers.length}, cooldown=${_peerCooldown.length}, seen=${_eventHandler.seenEventsCount})');

    await FlutterBluePlus.startScan(
      withServices: [Guid(kResQMeshServiceUUID)],
      timeout: Duration(seconds: kScanDurationSec),
    );

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final deviceId = r.device.remoteId.str;
        final rssi = r.rssi;
        uniquePeersEverSeen.add(deviceId);
        if (!_knownPeers.contains(deviceId) && !_isInCooldown(deviceId)) {
          _knownPeers.add(deviceId);
          _pendingDevices.add(r.device); // iOS: 存 BluetoothDevice
          _dlog('FOUND $deviceId (RSSI=$rssi) → queued (pending=${_pendingDevices.length})');
        }
      }
      _processQueue();
    });

    _isScanningSubscription?.cancel();
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _isActive) {
        _isScanning = false;
        _dlog('Scan stopped, will restart in ${kScanRestartDelaySec}s');
        Future.delayed(Duration(seconds: kScanRestartDelaySec), () {
          if (_isActive) startScanning();
        });
      }
    });
  }

  /// iOS: 使用 flutter_blue_plus 連線並同步
  Future<void> _iosConnectAndSync(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    try {
      _dlog('CONNECT $deviceId ...');
      await device.connect(
        license: License.free,
        autoConnect: false,
        timeout: const Duration(seconds: kConnectTimeoutSec),
      );
      _dlog('CONNECTED $deviceId ✓');

      // MTU 協商
      await Future.delayed(
          const Duration(milliseconds: kMtuRequestDelayMs));
      try {
        final mtu = await device.requestMtu(kRequestMtu);
        _dlog('MTU negotiated: $mtu');
      } catch (e) {
        _dlog('MTU request failed (using default): $e');
      }

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

      BluetoothCharacteristic? bloomChar;
      BluetoothCharacteristic? eventChar;

      for (final c in resqService.characteristics) {
        final uuid = c.characteristicUuid.str.toLowerCase();
        if (uuid == kBloomCharUUID.toLowerCase()) bloomChar = c;
        if (uuid == kEventCharUUID.toLowerCase()) eventChar = c;
      }

      _dlog('Chars: bloom=${bloomChar != null}, event=${eventChar != null}');

      if (bloomChar != null && eventChar != null) {
        // 1. 讀取對端 Bloom Filter
        final remoteBloomBytes = await bloomChar.read();
        final remoteEventIds =
            MeshEventHandler.parseBloomFilter(remoteBloomBytes);
        _dlog('BLOOM from $deviceId: ${remoteBloomBytes.length} bytes, ${remoteEventIds.length} event IDs');

        // 2. 推送 TriageQueue 中的高優先級事件
        final queue = EventManager().queue;
        final sentFromQueue = <String>{};

        while (!queue.isEmpty) {
          final task = queue.dequeue();
          if (task == null) break;
          if (remoteEventIds.contains(task.eventId)) continue;
          if (_eventHandler.hasSeen(task.eventId)) continue;

          try {
            final wireData = MeshEventHandler.encodeWirePayload(
              task.eventId,
              task.payload,
              urgency: task.urgency,
            );
            await eventChar.write(wireData, withoutResponse: false);
            _eventHandler.markSeen(task.eventId);
            sentFromQueue.add(task.eventId);
            syncedEventCount++;
            _dlog('SENT(queue) ${task.eventId.substring(0, 8)}.. urg=${task.urgency} → $deviceId');
          } catch (e) {
            queue.enqueue(task);
            debugPrint('[BLE] Queue write error: $e');
            break;
          }
        }

        // 3. 從 DB 補充最近 24h 的事件
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
            'event_type',
            'sender_pub_key',
            'hlc_timestamp',
            'hlc_counter',
            'received_lat',
            'received_lng',
            'origin_lat',
            'origin_lng',
          ],
          where: 'hlc_timestamp > ?',
          whereArgs: [cutoff24h],
          orderBy: 'urgency DESC, hlc_timestamp DESC',
          limit: 50,
        );

        _dlog('DB query: ${myEvents.length} events in last 24h');

        int iosBloomSkipped = 0;
        int iosAttempted = 0;
        int iosSent = 0;

        for (final evt in myEvents) {
          final evtId = evt['event_id'] as String;
          if (remoteEventIds.contains(evtId)) { iosBloomSkipped++; continue; }
          // Fix B: 移除 hasSeen 過濾 — hasSeen 只應阻止「重複接收」，
          // 不應阻止「繼電已收到的封包給其他 peer」
          if (sentFromQueue.contains(evtId)) continue;

          final payload = evt['payload'] as Uint8List?;
          if (payload != null) {
            iosAttempted++;
            try {
              final wireData = MeshEventHandler.encodeWirePayload(
                evtId,
                payload.toList(),
                urgency: (evt['urgency'] as int?) ?? 0,
                eventType: (evt['event_type'] as int?) ?? 0,
                signature: (evt['signature'] as Uint8List?)?.toList(),
                senderPubKey:
                    (evt['sender_pub_key'] as Uint8List?)?.toList(),
                hlcTimestamp: (evt['hlc_timestamp'] as int?) ?? 0,
                hlcCounter: (evt['hlc_counter'] as int?) ?? 0,
                lat: (evt['received_lat'] as num?)?.toDouble(),
                lng: (evt['received_lng'] as num?)?.toDouble(),
                originLat: (evt['origin_lat'] as num?)?.toDouble(),
                originLng: (evt['origin_lng'] as num?)?.toDouble(),
              );
              await eventChar.write(wireData, withoutResponse: false);
              iosSent++;
              syncedEventCount++;
              _dlog('SENT(db) ${evtId.substring(0, 8)}.. urg=${evt['urgency']} → $deviceId');
            } catch (e) {
              _dlog('WRITE_ERR(db) ${evtId.substring(0, 8)}.. → $deviceId: $e');
              break;
            }
          }
        }

        _dlog('RELAY_STATS → $deviceId: bloom_skip=$iosBloomSkipped attempted=$iosAttempted sent=$iosSent');

        // 4. 訂閱接收對端推送過來的事件
        if (eventChar.properties.notify) {
          await eventChar.setNotifyValue(true);
          _dlog('Subscribed to notifications from $deviceId');
          eventChar.lastValueStream.listen((data) {
            if (data.isNotEmpty) {
              _dlog('NOTIFY from $deviceId: ${data.length} bytes');
              _eventHandler.handleIncomingData(
                Uint8List.fromList(data),
                deviceId,
              );
              receivedEventCount++;
              _eventStreamController
                  .add(BleEvent.received(deviceId, data));
            }
          });
        } else {
          _dlog('eventChar.notify NOT supported on $deviceId');
        }
      } else {
        _dlog('SKIP sync: missing chars on $deviceId');
      }

      _eventStreamController.add(BleEvent.connected(deviceId));

      _peerCooldown[deviceId] = DateTime.now();
      _dlog('DONE with $deviceId (sent=$syncedEventCount, recv=$receivedEventCount) → cooldown ${kPeerCooldownSec}s');

      await Future.delayed(const Duration(seconds: 2));
      await device.disconnect();
    } catch (e) {
      _dlog('ERROR $deviceId: $e');
      _knownPeers.remove(deviceId);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── 共用邏輯 ─────────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  /// 推送本機 Bloom Filter 到 Native GATT Server
  Future<void> _updateNativeBloomFilter() async {
    try {
      final bloomBytes = await MeshEventHandler.buildLocalBloomFilter();
      await NativeBridge.updateBloomFilter(bloomBytes);
      _dlog('Bloom filter pushed to native: ${bloomBytes.length} bytes');
    } catch (e) {
      _dlog('Bloom filter push failed: $e');
    }
  }

  bool _isInCooldown(String deviceId) {
    final last = _peerCooldown[deviceId];
    if (last == null) return false;
    return DateTime.now().difference(last) <
        Duration(seconds: kPeerCooldownSec);
  }

  void _cleanupCooldowns() {
    _peerCooldown.removeWhere((_, time) =>
        DateTime.now().difference(time) > Duration(seconds: kPeerCooldownSec));
    _knownPeers.clear();
  }

  /// 序列化處理連線佇列（一台連完再連下一台）
  Future<void> _processQueue() async {
    if (_isConnecting) return;
    _isConnecting = true;
    try {
      while (_pendingDevices.isNotEmpty && _isActive) {
        final device = _pendingDevices.removeAt(0);
        try {
          if (Platform.isAndroid) {
            final deviceId = device as String;
            await _nordicConnectAndSync(deviceId)
                .timeout(const Duration(seconds: 30), onTimeout: () async {
              _dlog('TIMEOUT connecting to $deviceId');
              _knownPeers.remove(deviceId);
              // Bug 5 Fix: 設定取消標記，讓孤兒 sync 在下個 await 檢查後停止
              _cancelledSyncs.add(deviceId);
              // 斷開連線以終止底層 GATT 操作
              try { await NativeBridge.nordicDisconnect(deviceId); } catch (_) {}
              // 加入冷卻，避免 timeout 後的裝置立刻被重新連線
              _peerCooldown[deviceId] = DateTime.now();
            });
          } else {
            await _iosConnectAndSync(device as BluetoothDevice)
                .timeout(const Duration(seconds: 30));
          }
        } on TimeoutException {
          _dlog('TIMEOUT (exception) connecting to $device');
        }
      }
    } finally {
      _isConnecting = false;
    }
  }

  bool get isScanning => _isScanning;
  bool get isActive => _isActive;
  bool get isConnecting => _isConnecting;
  int get pendingCount => _pendingDevices.length;
  int get knownPeersCount => _knownPeers.length;
  int get cooldownCount => _peerCooldown.length;
  int get seenEventsCount => _eventHandler.seenEventsCount;
}

/// BLE 事件通知（供 NativeBleTransport 橋接用）
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
