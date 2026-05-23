import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/mesh/iblt.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/platform/native_bridge.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

/// BLE Mesh 管理員（Central 角色）
///
/// 統一走 NativeBridge（MethodChannel）：
/// - Android → Nordic BLE Library
/// - iOS → CoreBluetooth
///
/// 上層邏輯（Bloom Filter 比對、DB 查詢、TriageQueue 消費）保留在 Dart，
/// 只有 BLE 原語（掃描、連線、讀寫）走平台專用路徑。
class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  // BLE Sync Protocol Control Codes
  static const int kControlIBLT = 0x01;
  static const int kControlSlowPath = 0x02;
  static const int kControlChatWatermark = 0x03;
  static const int kControlEventData = 0x04;

  bool _isScanning = false;
  bool _isActive = false;

  final MeshEventHandler _eventHandler = MeshEventHandler();

  // 已知節點快取（避免在同一輪掃描內重複連線）
  final Set<String> _knownPeers = {};
  // 節點冷卻時間
  final Map<String, DateTime> _peerCooldown = {};

  // 待連線設備佇列（序列化處理，避免 Android BLE 並行 GATT 衝突）
  // 存 String (deviceAddress)，統一走 NativeBridge
  final List<dynamic> _pendingDevices = [];
  bool _isConnecting = false;

  // Bug 5 Fix: 取消標記 — timeout 時設定，sync 每步檢查
  // Stage 6 (commit #10)：原本無界 Set；改 LRU(200) 防無限成長（leak L2）。
  // 同步完成或 cooldown 過期時可被剔除；維持插入順序的 LinkedHashSet。
  static const int _maxCancelledSyncs = 200;
  final _cancelledSyncs = <String>{};

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

  // Stage 6 (commit #10)：原本無界 Set 紀錄全程看到的 peer（debug stat 用）。
  // 改 LRU(500)：同樣是 Set 語意，但 add 時會檢查上限並剔最舊一筆（leak L1）。
  // FIFO 即可滿足 debug 視窗需求，不需嚴格 LRU。
  static const int _maxUniquePeersEverSeen = 500;
  final uniquePeersEverSeen = <String>{};

  void _dlog(String msg) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = '[$ts] $msg';
    debugLogs.add(entry);
    if (debugLogs.length > _maxDebugLogs) debugLogs.removeAt(0);
    debugPrint('[BLE-DBG] $msg');
    DatabaseHelper().writeDebugLog('BLE', entry);
  }

  /// 啟動 BLE 掃描（Central 模式）— 統一走 NativeBridge
  Future<void> startScanning() async {
    if (_isScanning) return;
    await _startNativeScan();
  }

  /// 停止掃描
  Future<void> stopScanning() async {
    _isActive = false;
    _isScanning = false;
    _dlog('SCAN STOPPED (manual)');

    await NativeBridge.stopNordicScan();
    await _nordicEventSub?.cancel();
    _nordicEventSub = null;
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── NativeBridge (Android: Nordic / iOS: CoreBluetooth) ─────────────
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _startNativeScan() async {
    _isActive = true;
    _isScanning = true;
    scanCycleCount++;

    _cleanupCooldowns();
    _updateNativeBloomFilter();

    _dlog('NORDIC SCAN #$scanCycleCount started (known=${_knownPeers.length}, cooldown=${_peerCooldown.length}, seen=${_eventHandler.seenEventsCount})');

    // 監聽 Nordic EventChannel 事件
    _nordicEventSub?.cancel();
    _nordicEventSub = NativeBridge.nativeEventStream.listen((event) {
      // Bug 12 Fix: try-catch 防止任何事件處理例外導致整個 stream 崩潰
      try {
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
        } else if (type == 'notify_push_start') {
          final device = event['device'] ?? '';
          final count = event['count'] ?? 0;
          _dlog('NOTIFY_PUSH → $device: $count events queued');
        } else if (type == 'notify_push_done') {
          final device = event['device'] ?? '';
          final count = event['count'] ?? 0;
          _dlog('NOTIFY_PUSH_DONE → $device: $count events sent');
        } else if (type == 'notify_sent') {
          final device = event['device'] ?? '';
          final status = event['status'] ?? -1;
          final ok = event['ok'] ?? false;
          _dlog('NOTIFY_SENT → $device: status=$status ok=$ok');
        }
      }
      } catch (e) {
        _dlog('EVENT_HANDLER_ERR: $e');
      }
    });

    // 啟動 Nordic 掃描
    final success = await NativeBridge.startNordicScan();
    if (!success) {
      _dlog('Nordic scan failed to start');
      _isScanning = false;
      return;
    }

    // 定時重啟掃描循環
    _scheduleNordicScanRestart();
  }

  void _scheduleNordicScanRestart() {
    Future.delayed(const Duration(seconds: kScanDurationSec), () async {
      if (!_isActive) return;
      await NativeBridge.stopNordicScan();
      _isScanning = false;
      _dlog('Nordic scan cycle done, restart in ${kScanRestartDelaySec}s');
      Future.delayed(const Duration(seconds: kScanRestartDelaySec), () {
        if (_isActive) _startNativeScan();
      });
    });
  }

  void _handleNordicDeviceFound(Map event) {
    final deviceId = event['device'] as String? ?? '';
    final rssi = event['rssi'] as int? ?? 0;
    if (deviceId.isEmpty) return;

    _addBoundedPeer(deviceId);
    if (!_knownPeers.contains(deviceId) && !_isInCooldown(deviceId)
        && !_pendingDevices.contains(deviceId)) {
      _knownPeers.add(deviceId);
      _pendingDevices.add(deviceId); // Android: 存 String
      _dlog('FOUND $deviceId (RSSI=$rssi) → queued (pending=${_pendingDevices.length})');
    }
    _processQueue();
  }

  void _handleNordicDataReceived(Map event) {
    try {
      final deviceId = event['device'] as String? ?? 'unknown';
      // Bug 11 Fix: v2 同步中的裝置由 notifySub 處理，這裡跳過避免重複
      if (_syncingDevices.contains(deviceId)) return;
      final dataList = event['data'];
      if (dataList is List && dataList.isNotEmpty) {
        final data = Uint8List.fromList(List<int>.from(dataList));
        _dlog('NOTIFY from $deviceId: ${data.length} bytes (Nordic)');
        _eventHandler.handleIncomingData(data, deviceId);
        receivedEventCount++;
        _eventStreamController.add(BleEvent.received(deviceId, data.toList()));
      }
    } catch (e) {
      _dlog('DATA_RECV_ERR: $e');
    }
  }

  /// Bug 5 Fix: 檢查 sync 是否已被 timeout 取消
  bool _isCancelled(String deviceId) => _cancelledSyncs.contains(deviceId);

  /// Bug 11 Fix: 追蹤正在 v2 同步中的裝置，避免 _handleNordicDataReceived 重複處理
  final Set<String> _syncingDevices = {};

  /// Android: 使用 Nordic 連線並同步（v2 協議 — Write Bloom + Notify 差量推送）
  ///
  /// 流程：
  /// 1. 連線 → Nordic 自動 subscribe Event Char Notify
  /// 2. Write 本機 Bloom 到對端 Bloom Char → 觸發對端差量比對
  /// 3. 等待對端 Notify 推送缺少的事件 + 對端 Bloom + 結束標記
  /// 4. 用對端 Bloom 比對，Write 對端缺少的事件
  /// 5. 斷線
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

      // Bug 11 Fix: 標記此裝置正在 v2 同步中，防止 _handleNordicDataReceived 重複處理
      // 使用 try...finally 確保無論成功、失敗、取消都一定會釋放鎖定
      _syncingDevices.add(deviceId);
      try {
        await _nordicSyncProtocolV2(deviceId);
      } finally {
        // 先解鎖再斷線，避免空窗期（解鎖後 _handleNordicDataReceived 立即接手）
        _syncingDevices.remove(deviceId);
      }

      await Future.delayed(const Duration(seconds: 2));
      await NativeBridge.nordicDisconnect(deviceId);
    } catch (e, st) {
      _syncingDevices.remove(deviceId); // 連線階段就失敗的情況
      if (_isCancelled(deviceId)) return;
      _dlog('ERROR $deviceId: $e');
      debugPrint('[BLE] Sync error stack: $st');
      _knownPeers.remove(deviceId);
      // Bug 12 Fix: 確保斷線，避免 GATT 連線洩漏
      try { await NativeBridge.nordicDisconnect(deviceId); } catch (_) {}
    }
  }

  /// IBLT Fast Path 同步嘗試
  ///
  /// 流程：
  /// 1. 建構本機 IBLT（排除聊天事件）
  /// 2. 取得本機聊天水位線（Chat_Messages 的最大 hlc_timestamp）
  /// 3. 打包 517 byte 封包：[0x01](1B) + [watermark](8B) + [IBLT](504B) + [padding](4B)
  /// 4. 寫入對端，等待對端 IBLT 回應
  /// 5. 做 IBLT 相減並嘗試 peel
  /// 6. 成功 → 只交換缺少的事件（Fast Path）
  /// 7. 失敗 → 回傳 false，由呼叫端 fallback 到 Bloom-based Slow Path
  Future<bool> _tryIBLTSync(String deviceId) async {
    try {
      // ── 1. 建構本機 IBLT（排除聊天事件）──
      final handler = MeshEventHandler();
      final localEventIds = await handler.getLocalEventIds(excludeChat: true);
      final localIblt = IBLT();
      for (final id in localEventIds) {
        localIblt.insert(id);
      }

      // ── 2. 取得聊天水位線 ──
      final db = await DatabaseHelper().database;
      final wmResult = await db.rawQuery(
          'SELECT MAX(hlc_timestamp) as wm FROM Chat_Messages');
      final chatWatermark = (wmResult.first['wm'] as int?) ?? 0;

      // ── 3. 打包封包：control(1) + watermark(8) + iblt(504) = 513 ──
      final ibltBytes = localIblt.toBytes();
      final packet = Uint8List(1 + 8 + ibltBytes.length);
      packet[0] = kControlIBLT;
      final wmData = ByteData(8)..setInt64(0, chatWatermark, Endian.little);
      packet.setRange(1, 9, wmData.buffer.asUint8List());
      packet.setRange(9, 9 + ibltBytes.length, ibltBytes);

      // ── 4. 寫入 IBLT 封包到對端 ──
      final writeOk = await NativeBridge.nordicWriteBloom(deviceId, packet);
      if (_isCancelled(deviceId)) {
        _dlog('IBLT CANCELLED(write) $deviceId');
        return false;
      }
      _dlog('IBLT_WRITE → $deviceId: ${packet.length} bytes, ok=$writeOk');
      if (!writeOk) return false;

      // ── 5. 等待對端 IBLT 回應封包 ──
      Uint8List? peerIbltBytes;
      int peerChatWatermark = 0;
      final ibltCompleter = Completer<bool>();
      StreamSubscription? ibltSub;

      ibltSub = NativeBridge.nativeEventStream.listen((event) {
        try {
        if (event is Map &&
            event['type'] == 'nordic_data' &&
            event['device'] == deviceId) {
          final dataList = event['data'];
          if (dataList is List && dataList.isNotEmpty) {
            final data = Uint8List.fromList(List<int>.from(dataList));
            // 檢查是否為 IBLT 回應封包（control byte = 0x01, 長度 >= 513）
            if (data.length >= 513 && data[0] == kControlIBLT) {
              final wmView = ByteData.sublistView(data, 1, 9);
              peerChatWatermark = wmView.getInt64(0, Endian.little);
              peerIbltBytes = Uint8List.sublistView(data, 9, 9 + 504);
              if (!ibltCompleter.isCompleted) ibltCompleter.complete(true);
              return;
            }
            // 收到 Slow Path 控制碼代表對端不支援 IBLT
            if (data.isNotEmpty && data[0] == kControlSlowPath) {
              if (!ibltCompleter.isCompleted) ibltCompleter.complete(false);
              return;
            }
          }
        }
        } catch (e) {
          debugPrint('[BLE] IBLT listener error: $e');
          if (!ibltCompleter.isCompleted) ibltCompleter.complete(false);
        }
      });

      // 8 秒超時（IBLT 交換應很快）
      bool gotResponse = false;
      try {
        gotResponse = await ibltCompleter.future
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
      } catch (_) {}
      await ibltSub.cancel();

      if (!gotResponse || peerIbltBytes == null) {
        _dlog('IBLT_TIMEOUT or no response from $deviceId → fallback to Bloom');
        return false;
      }

      // ── 6. IBLT 相減並嘗試 peel ──
      IBLT peerIblt;
      try {
        peerIblt = IBLT.fromBytes(peerIbltBytes!);
      } catch (e) {
        _dlog('IBLT_DECODE_ERR for $deviceId: $e → fallback to Bloom');
        return false;
      }
      final diff = localIblt.subtract(peerIblt);
      final peelResult = diff.peel();

      if (peelResult == null) {
        _dlog('IBLT_PEEL failed for $deviceId (too many differences) → fallback to Bloom');
        return false;
      }

      _dlog('IBLT_PEEL OK for $deviceId: onlyLocal=${peelResult.onlyInA.length}, onlyRemote=${peelResult.onlyInB.length}');

      // ── 7. Fast Path: 推送對端缺少的事件（onlyInA = 我們有、對端沒有的）──
      if (peelResult.onlyInA.isNotEmpty) {
        final eventsToSend =
            await handler.getEventsByKeyHashes(peelResult.onlyInA);
        int fastPathSent = 0;
        for (final evt in eventsToSend) {
          if (_isCancelled(deviceId)) return false;
          final evtId = evt['event_id'] as String;
          final payload = evt['payload'] as Uint8List?;
          if (payload == null) continue;
          try {
            final wireData = MeshEventHandler.encodeWirePayload(
              evtId,
              payload.toList(),
              urgency: (evt['urgency'] as int?) ?? 0,
              eventType: (evt['event_type'] as int?) ?? 0,
              // 保留 stored ttl（getEventsByKeyHashes 已過濾 ttl<=0），不要回到
              // encodeWirePayload 預設 10。
              ttl: (evt['ttl'] as int?) ?? 10,
              signature: (evt['signature'] as Uint8List?)?.toList(),
              senderPubKey: (evt['sender_pub_key'] as Uint8List?)?.toList(),
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
            if (success) {
              fastPathSent++;
              syncedEventCount++;
              _dlog('IBLT_SENT ${evtId.substring(0, 8)}.. → $deviceId');
            }
          } catch (e) {
            _dlog('IBLT_WRITE_ERR ${evtId.substring(0, 8)}.. → $deviceId: $e');
            break;
          }
        }
        _dlog('IBLT_FAST_PATH → $deviceId: sent=$fastPathSent/${eventsToSend.length}');
      }

      // ── 8. 比較聊天水位線，若不同則請求缺少的聊天訊息 ──
      if (chatWatermark != peerChatWatermark) {
        final lowerWm = chatWatermark < peerChatWatermark
            ? chatWatermark
            : peerChatWatermark;
        _dlog('CHAT_WM_DIFF local=$chatWatermark peer=$peerChatWatermark → requesting missing chat since $lowerWm');
        // 發送聊天水位線請求封包
        final wmPacket = Uint8List(9);
        wmPacket[0] = kControlChatWatermark;
        final wmReqData = ByteData(8)..setInt64(0, lowerWm, Endian.little);
        wmPacket.setRange(1, 9, wmReqData.buffer.asUint8List());
        await NativeBridge.nordicWriteEvent(deviceId, wmPacket);
      }

      _dlog('IBLT_SYNC OK for $deviceId (Fast Path complete)');
      return true;
    } catch (e) {
      _dlog('IBLT sync failed for $deviceId: $e → fallback to Bloom');
      return false;
    }
  }

  /// v2 同步協議核心邏輯（從 _nordicConnectAndSync 抽出，方便 try...finally 包裹）
  ///
  /// 新增 IBLT Fast Path：先嘗試 IBLT 差量同步，失敗再 fallback 到 Bloom Slow Path。
  Future<void> _nordicSyncProtocolV2(String deviceId) async {
      // ── IBLT Fast Path 嘗試 ──
      // 如果成功，跳過後續 Bloom-based Slow Path
      final ibltOk = await _tryIBLTSync(deviceId);
      if (_isCancelled(deviceId)) { _dlog('CANCELLED(iblt) $deviceId'); return; }
      if (ibltOk) {
        _dlog('IBLT Fast Path succeeded for $deviceId, skipping Bloom Slow Path');
        _eventStreamController.add(BleEvent.connected(deviceId));
        _peerCooldown[deviceId] = DateTime.now();
        _dlog('DONE(IBLT) with $deviceId (sent=$syncedEventCount, recv=$receivedEventCount) → cooldown ${kPeerCooldownSec}s');
        return;
      }
      _dlog('IBLT Fast Path unavailable for $deviceId, using Bloom Slow Path');

      // ── Bloom Slow Path（原有流程）──
      // ── 1. Write 本機 Bloom Filter 到對端 ──
      // 對端 GATT Server 收到後會比對差量，只 Notify 推送我們缺少的事件 + 對端 Bloom。
      // 不再用 GATT Read（繞過 GATT Server Read 壞掉的問題）。
      final localBloom = await MeshEventHandler.buildLocalBloomFilter();
      final bloomWriteOk = await NativeBridge.nordicWriteBloom(deviceId, localBloom);
      if (_isCancelled(deviceId)) { _dlog('CANCELLED(write-bloom) $deviceId'); return; }
      _dlog('BLOOM_WRITE → $deviceId: ${localBloom.length} bytes, ok=$bloomWriteOk');

      // ── 2. 等待對端 Notify 推送（事件 + Bloom + 結束標記）──
      // Magic bytes: Bloom 前綴 [0xFF, 0xB1, 0x00, 0x4D], 結束標記 [0xFF, 0xE7, 0xD0, 0x7E]
      Set<String> remoteEventIds = {};
      int notifyRecvCount = 0;
      final completer = Completer<void>();
      StreamSubscription? notifySub;

      // 監聽 nordic_data 事件（Notify 推送的資料）
      notifySub = NativeBridge.nativeEventStream.listen((event) {
        try {
        if (event is Map && event['type'] == 'nordic_data' && event['device'] == deviceId) {
          final dataList = event['data'];
          if (dataList is List && dataList.isNotEmpty) {
            final data = Uint8List.fromList(List<int>.from(dataList));

            // 檢查結束標記
            if (data.length == 4 && data[0] == 0xFF && data[1] == 0xE7 && data[2] == 0xD0 && data[3] == 0x7E) {
              _dlog('NOTIFY_END from $deviceId (received $notifyRecvCount events)');
              if (!completer.isCompleted) completer.complete();
              return;
            }

            // 檢查 Bloom 封包（前綴 [0xFF, 0xB1, 0x00, 0x4D]）
            if (data.length > 4 && data[0] == 0xFF && data[1] == 0xB1 && data[2] == 0x00 && data[3] == 0x4D) {
              final bloomBytes = data.sublist(4);
              remoteEventIds = MeshEventHandler.parseBloomFilter(bloomBytes.toList());
              _dlog('NOTIFY_BLOOM from $deviceId: ${bloomBytes.length} bytes, ${remoteEventIds.length} event IDs');
              return;
            }

            // 正常事件資料
            _dlog('NOTIFY from $deviceId: ${data.length} bytes');
            _eventHandler.handleIncomingData(data, deviceId);
            notifyRecvCount++;
            receivedEventCount++;
            _eventStreamController.add(BleEvent.received(deviceId, data.toList()));
          }
        }
        } catch (e) {
          debugPrint('[BLE] Notify listener error: $e');
        }
      });

      // 15 秒超時保底（避免對端不支援新協議或推送卡住）
      try {
        await completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
          _dlog('NOTIFY_WAIT timeout (15s) for $deviceId — proceeding with available data');
        });
      } catch (_) {}
      await notifySub.cancel();

      if (_isCancelled(deviceId)) { _dlog('CANCELLED(notify-wait) $deviceId'); return; }

      // ── 3. 用對端 Bloom 比對，Write 對端缺少的事件 ──
      // 先推 TriageQueue
      final queue = EventManager().queue;
      final sentFromQueue = <String>{};

      while (!queue.isEmpty) {
        if (_isCancelled(deviceId)) { _dlog('CANCELLED(queue) $deviceId'); return; }
        final task = queue.dequeue();
        if (task == null) break;
        if (remoteEventIds.contains(task.eventId)) continue;

        try {
          // The MeshTask carries only the raw payload (no signature /
          // senderPubKey), so sending it directly makes the receiver reject it
          // as no-sig. Rebuild the fully-signed wire packet from Event_Logs
          // (same shape as the DB-sync path below).
          final wireData = await _signedWireForEventId(task.eventId);
          if (wireData == null) {
            // Event_Logs row gone (cancelled / expired) — drop the task.
            continue;
          }
          final success = await NativeBridge.nordicWriteEvent(
            deviceId,
            wireData,
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

      // 從 DB 補充最近 24h 的事件
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
          'ttl',
        ],
        // 排除 v2 投影列：它們無 v1 簽章，送出去對端只會拒收。
        // 排除 CHAT_MESSAGE：聊天已遷移成 v2-only（走 chunked BLE bridge），
        // 不再經 v1 wire，避免收件端 v1+v2 雙顯。
        // 排除 ttl<=0：已耗盡 hop budget 的事件不再轉發（hop-limit 收尾）。
        where:
            'hlc_timestamp > ? AND ttl > 0 AND event_id NOT LIKE ? AND event_type != ?',
        whereArgs: [
          cutoff24h,
          '${MeshEventHandler.v2ProjectionIdPrefix}%',
          EventType.chatMessage,
        ],
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
              // 保留 stored ttl（已逐跳遞減），不要回到 encodeWirePayload 預設 10，
              // 否則中繼會把 hop budget 灌滿、傳播比預期更遠。
              ttl: (evt['ttl'] as int?) ?? 10,
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

      _dlog('SYNC_STATS → $deviceId: notify_recv=$notifyRecvCount bloom_skip=$dbBloomSkipped write_attempted=$dbAttempted write_sent=$dbSent remote_bloom=${remoteEventIds.length}');

      _eventStreamController.add(BleEvent.connected(deviceId));
      _peerCooldown[deviceId] = DateTime.now();
      _dlog('DONE with $deviceId (sent=$syncedEventCount, recv=$receivedEventCount) → cooldown ${kPeerCooldownSec}s');
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── 共用邏輯 ─────────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════

  /// 推送本機 Bloom Filter + Event Outbox 到 Native GATT Server
  Future<void> _updateNativeBloomFilter() async {
    try {
      final bloomBytes = await MeshEventHandler.buildLocalBloomFilter();
      await NativeBridge.updateBloomFilter(bloomBytes);
      _dlog('Bloom filter pushed to native: ${bloomBytes.length} bytes');
    } catch (e) {
      _dlog('Bloom filter push failed: $e');
    }

    // Bug 7 Fix: 推送事件 outbox 到 native（供 GATT Server Notify 反向推送）
    // 當 OPPO (Central) 連上我方 GATT Server 並 subscribe Event Char 通知時，
    // Server 主動把 outbox 中的事件透過 Notify 推送給 OPPO。
    // 這讓 OPPO 能透過「能正常運作的 Central 角色」接收資料。
    try {
      final outboxEvents = await _buildEventOutbox();
      if (outboxEvents.isNotEmpty) {
        await NativeBridge.updateEventOutbox(outboxEvents);
        _dlog('Event outbox pushed to native: ${outboxEvents.length} events');
      }
    } catch (e) {
      _dlog('Event outbox push failed: $e');
    }
  }

  /// 從 Event_Logs 以 [eventId] 重建「帶簽章」的 v1 wire 封包。
  ///
  /// TriageQueue 的 MeshTask 只帶原始 payload（沒有 signature / senderPubKey），
  /// 即時送出若直接送原始 payload，收件端會以 no-sig 拒收。即時路徑因此必須回讀
  /// 已簽章的 Event_Logs row 重新編碼。row 不存在（已取消／過期）時回傳 null。
  Future<Uint8List?> _signedWireForEventId(String eventId) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
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
        'ttl',
      ],
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final evt = rows.first;
    final payload = evt['payload'] as Uint8List?;
    if (payload == null) return null;
    final ttl = (evt['ttl'] as int?) ?? 10;
    if (ttl <= 0) return null; // 已耗盡 hop budget，不再送出（hop-limit 收尾）
    final wireData = MeshEventHandler.encodeWirePayload(
      eventId,
      payload.toList(),
      urgency: (evt['urgency'] as int?) ?? 0,
      eventType: (evt['event_type'] as int?) ?? 0,
      signature: (evt['signature'] as Uint8List?)?.toList(),
      senderPubKey: (evt['sender_pub_key'] as Uint8List?)?.toList(),
      hlcTimestamp: (evt['hlc_timestamp'] as int?) ?? 0,
      hlcCounter: (evt['hlc_counter'] as int?) ?? 0,
      ttl: ttl,
      lat: (evt['received_lat'] as num?)?.toDouble(),
      lng: (evt['received_lng'] as num?)?.toDouble(),
      originLat: (evt['origin_lat'] as num?)?.toDouble(),
      originLng: (evt['origin_lng'] as num?)?.toDouble(),
    );
    return Uint8List.fromList(wireData);
  }

  /// Bug 7: 建構事件 outbox（最近 24h 的事件，供 Notify 反向推送）
  Future<List<Uint8List>> _buildEventOutbox() async {
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
        'ttl',
      ],
      // 排除 v2 投影列：它們無 v1 簽章，不可進 native Notify outbox。
      // 排除 CHAT_MESSAGE：聊天已遷移成 v2-only，不再經 v1 wire。
      // 排除 ttl<=0：已耗盡 hop budget 的事件不再轉發（hop-limit 收尾）。
      where:
          'hlc_timestamp > ? AND ttl > 0 AND event_id NOT LIKE ? AND event_type != ?',
      whereArgs: [
        cutoff24h,
        '${MeshEventHandler.v2ProjectionIdPrefix}%',
        EventType.chatMessage,
      ],
      orderBy: 'urgency DESC, hlc_timestamp DESC',
      limit: 50,
    );

    final events = <Uint8List>[];
    for (final evt in myEvents) {
      final evtId = evt['event_id'] as String;
      final payload = evt['payload'] as Uint8List?;
      if (payload != null) {
        final wireData = MeshEventHandler.encodeWirePayload(
          evtId,
          payload.toList(),
          urgency: (evt['urgency'] as int?) ?? 0,
          eventType: (evt['event_type'] as int?) ?? 0,
          // 保留 stored ttl（已逐跳遞減），不要回到 encodeWirePayload 預設 10。
          ttl: (evt['ttl'] as int?) ?? 10,
          signature: (evt['signature'] as Uint8List?)?.toList(),
          senderPubKey: (evt['sender_pub_key'] as Uint8List?)?.toList(),
          hlcTimestamp: (evt['hlc_timestamp'] as int?) ?? 0,
          hlcCounter: (evt['hlc_counter'] as int?) ?? 0,
          lat: (evt['received_lat'] as num?)?.toDouble(),
          lng: (evt['received_lng'] as num?)?.toDouble(),
          originLat: (evt['origin_lat'] as num?)?.toDouble(),
          originLng: (evt['origin_lng'] as num?)?.toDouble(),
        );
        events.add(Uint8List.fromList(wireData));
      }
    }
    return events;
  }

  bool _isInCooldown(String deviceId) {
    final last = _peerCooldown[deviceId];
    if (last == null) return false;
    return DateTime.now().difference(last) <
        const Duration(seconds: kPeerCooldownSec);
  }

  void _cleanupCooldowns() {
    _peerCooldown.removeWhere((_, time) =>
        DateTime.now().difference(time) > const Duration(seconds: kPeerCooldownSec));
    _knownPeers.clear();
    // Stage 6：cooldown 過期意味著此 peer 已可重試 → 連帶從 _cancelledSyncs
    // 移除；正常情況下這保證 _cancelledSyncs 大小跟著 cooldown 縮減而非無界堆積。
    _cancelledSyncs.removeWhere((id) => !_peerCooldown.containsKey(id));
  }

  // Stage 6 (commit #10)：bounded set helpers — 兩個 Set 共用 FIFO eviction。
  // FIFO 既能保證上限又能保留近期插入；不需嚴格 LRU 因為這兩個 set 都是 debug
  // / defensive 用途，舊資料失準的影響低於記憶體無界增長。
  void _addBoundedPeer(String id) =>
      addBoundedFifo(uniquePeersEverSeen, id, _maxUniquePeersEverSeen);

  void _addBoundedCancelled(String id) =>
      addBoundedFifo(_cancelledSyncs, id, _maxCancelledSyncs);

  /// 序列化處理連線佇列（一台連完再連下一台）
  Future<void> _processQueue() async {
    if (_isConnecting) return;
    _isConnecting = true;
    try {
      while (_pendingDevices.isNotEmpty && _isActive) {
        final device = _pendingDevices.removeAt(0);
        try {
          final deviceId = device as String;
          await _nordicConnectAndSync(deviceId)
              .timeout(const Duration(seconds: 30), onTimeout: () async {
            _dlog('TIMEOUT connecting to $deviceId');
            _knownPeers.remove(deviceId);
            _addBoundedCancelled(deviceId);
            try { await NativeBridge.nordicDisconnect(deviceId); } catch (_) {}
            _peerCooldown[deviceId] = DateTime.now();
          });
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

/// Stage 6：可重用的 FIFO bounded set 插入。
///
/// 加入 `item` 到 `set`；若已存在則 no-op；若達上限 `max` 則先剔除最舊一筆。
/// `Set` 不保證順序，但 Dart 內建 `LinkedHashSet`（`{}` 字面量預設）保留
/// 插入順序，`set.first` 即最舊一筆。
///
/// **暴露為 top-level**：BleManager 之外，其他模組若需相同 bounded 語意可
/// 直接呼叫；Stage 6 測試也以此函式做壓力驗證。
void addBoundedFifo<T>(Set<T> set, T item, int max) {
  if (max <= 0) return; // degenerate cap → 永遠空集合
  if (set.contains(item)) return;
  while (set.length >= max && set.isNotEmpty) {
    set.remove(set.first);
  }
  set.add(item);
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
