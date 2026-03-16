import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'event_manager.dart';
import 'mesh_constants.dart';
import 'mesh_event_handler.dart';
import 'native_bridge.dart';
import '../db/database_helper.dart';

/// BLE Mesh 管理員（Central 角色）
///
/// 負責掃描、連線、MTU 協商、交換 Bloom Filter 和同步 Event 資料。
/// 接收端邏輯統一委託給 [MeshEventHandler]（去重、geo-routing、DB 寫入）。
/// 發送端使用 [MeshEventHandler.encodeWirePayload] 編碼。
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

    _cleanupCooldowns();

    // 推送最新 Bloom Filter 到 Native GATT Server
    _updateNativeBloomFilter();

    _dlog('SCAN #$scanCycleCount started (known=${_knownPeers.length}, cooldown=${_peerCooldown.length}, seen=${_eventHandler.seenEventsCount})');

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
          _pendingDevices.add(r.device);
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

  /// 推送本機 Bloom Filter 到 Native GATT Server（供 Peripheral 端回應 Central 讀取）
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
        autoConnect: false,
        timeout: Duration(seconds: kConnectTimeoutSec),
      );
      _dlog('CONNECTED $deviceId ✓');

      // ── MTU 協商（參考 BitChat: 200ms 延遲後請求 517）──
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

        for (final evt in myEvents) {
          final evtId = evt['event_id'] as String;
          if (remoteEventIds.contains(evtId)) continue;
          if (_eventHandler.hasSeen(evtId)) continue;
          if (sentFromQueue.contains(evtId)) continue;

          final payload = evt['payload'] as Uint8List?;
          if (payload != null) {
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
              _eventHandler.markSeen(evtId);
              syncedEventCount++;
              _dlog('SENT(db) ${evtId.substring(0, 8)}.. urg=${evt['urgency']} → $deviceId');
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
              // 委託給 MeshEventHandler 統一處理（去重、geo-routing、DB 寫入）
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
