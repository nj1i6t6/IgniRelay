import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:bridgefy/bridgefy.dart';
import '../config/app_config.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import 'mesh_transport.dart';
import 'mesh_event_handler.dart';
import 'event_manager.dart';
import '../db/database_helper.dart';

/// BridgefyTransport — 使用 Bridgefy SDK 實作 MeshTransport
///
/// 廣播驅動的 Bloom Filter 策略：
/// 1. 每 30 秒 (+/- 5s 隨機抖動) broadcast MeshEnvelope{BLOOM_FILTER}
/// 2. 收到 BLOOM_FILTER 時：比對本地差集 → sendToNode 回傳缺少事件
/// 3. 收到 EVENT 時：交給 MeshEventHandler 處理
/// 4. SOS_RED 在佇列中時，縮短 Bloom 間隔至 10 秒
class BridgefyTransport with BridgefyDelegate implements MeshTransport {
  static final BridgefyTransport _instance = BridgefyTransport._internal();
  factory BridgefyTransport() => _instance;
  BridgefyTransport._internal();

  final Bridgefy _bridgefy = Bridgefy();
  final MeshEventHandler _eventHandler = MeshEventHandler();
  final _random = Random();

  // Stream controllers
  final _dataController = StreamController<MeshDataReceived>.broadcast();
  final _peerConnectedController = StreamController<String>.broadcast();
  final _peerDisconnectedController = StreamController<String>.broadcast();
  final _stateController = StreamController<TransportState>.broadcast();

  // 狀態
  TransportState _state = TransportState.stopped;
  String? _localUserId;
  final Set<String> _connectedPeers = {};
  int _sentCount = 0;

  // Bloom Filter 定時廣播
  Timer? _bloomTimer;

  // Debug logs
  static const int _maxDebugLogs = 80;
  final List<String> _debugLogs = [];

  void _dlog(String msg) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = '[$ts] $msg';
    _debugLogs.add(entry);
    if (_debugLogs.length > _maxDebugLogs) _debugLogs.removeAt(0);
    debugPrint('[Bridgefy] $msg');
  }

  // ── MeshTransport 實作 ──────────────────────────────────────────

  @override
  Future<void> initialize() async {
    if (!AppConfig.hasBridgefyKey) {
      _dlog('ERROR: No Bridgefy API key configured');
      _state = TransportState.error;
      _stateController.add(_state);
      return;
    }
    try {
      _state = TransportState.starting;
      _stateController.add(_state);
      _dlog('Initializing Bridgefy SDK...');
      await _bridgefy.initialize(
        apiKey: AppConfig.bridgefyApiKey,
        delegate: this,
        verboseLogging: false,
      );
      _dlog('Bridgefy SDK initialized');
    } catch (e) {
      _dlog('Init error: $e');
      _state = TransportState.error;
      _stateController.add(_state);
    }
  }

  @override
  Future<void> start() async {
    try {
      _dlog('Starting Bridgefy mesh (LongReach)...');
      await _bridgefy.start(
        propagationProfile: BridgefyPropagationProfile.longReach,
      );
      _state = TransportState.running;
      _stateController.add(_state);
      _startBloomBroadcastTimer();
      _dlog('Bridgefy mesh started');
    } catch (e) {
      _dlog('Start error: $e');
      _state = TransportState.error;
      _stateController.add(_state);
    }
  }

  @override
  Future<void> stop() async {
    _bloomTimer?.cancel();
    _bloomTimer = null;
    try {
      await _bridgefy.stop();
    } catch (e) {
      _dlog('Stop error: $e');
    }
    _state = TransportState.stopped;
    _stateController.add(_state);
    _connectedPeers.clear();
    _dlog('Bridgefy mesh stopped');
  }

  @override
  Future<String> broadcast(Uint8List data) async {
    // 包裝為 MeshEnvelope (EVENT 型別)
    final envelope = pb.MeshEnvelope()
      ..type = pb.EnvelopeType.ENVELOPE_EVENT
      ..payload = data
      ..senderId = _localUserId ?? 'unknown';

    final envelopeBytes = Uint8List.fromList(envelope.writeToBuffer());

    final msgId = await _bridgefy.send(
      data: envelopeBytes,
      transmissionMode: BridgefyTransmissionMode(
        type: BridgefyTransmissionModeType.broadcast,
        uuid: '',
      ),
    );
    _sentCount++;
    _dlog('BROADCAST ${data.length}B → msgId=$msgId');
    return msgId;
  }

  @override
  Future<String> sendToNode(String nodeId, Uint8List data) async {
    final envelope = pb.MeshEnvelope()
      ..type = pb.EnvelopeType.ENVELOPE_EVENT
      ..payload = data
      ..senderId = _localUserId ?? 'unknown';

    final envelopeBytes = Uint8List.fromList(envelope.writeToBuffer());

    final msgId = await _bridgefy.send(
      data: envelopeBytes,
      transmissionMode: BridgefyTransmissionMode(
        type: BridgefyTransmissionModeType.mesh,
        uuid: nodeId,
      ),
    );
    _sentCount++;
    _dlog('SEND → $nodeId ${data.length}B msgId=$msgId');
    return msgId;
  }

  @override
  Stream<MeshDataReceived> get onDataReceived => _dataController.stream;

  @override
  Stream<String> get onPeerConnected => _peerConnectedController.stream;

  @override
  Stream<String> get onPeerDisconnected => _peerDisconnectedController.stream;

  @override
  Stream<TransportState> get onStateChanged => _stateController.stream;

  @override
  bool get isActive => _state == TransportState.running;

  @override
  TransportStats get stats => TransportStats(
        sentCount: _sentCount,
        receivedCount: _eventHandler.receivedEventCount,
        connectedPeers: _connectedPeers.length,
        seenEventsCount: _eventHandler.seenEventsCount,
        debugLogs: List.unmodifiable(_debugLogs),
      );

  @override
  void dispose() {
    _bloomTimer?.cancel();
    _dataController.close();
    _peerConnectedController.close();
    _peerDisconnectedController.close();
    _stateController.close();
  }

  // ── Bloom Filter 廣播驅動 ───────────────────────────────────────

  void _startBloomBroadcastTimer() {
    _bloomTimer?.cancel();
    _scheduleNextBloom();
  }

  void _scheduleNextBloom() {
    final hasSOSRed = EventManager().queue.hasSOSRedPreemptionPending;
    final baseInterval = hasSOSRed
        ? AppConfig.bloomBroadcastSosIntervalSec
        : AppConfig.bloomBroadcastIntervalSec;
    final jitter = _random.nextInt(AppConfig.bloomJitterSec * 2) -
        AppConfig.bloomJitterSec;
    final interval = Duration(seconds: max(5, baseInterval + jitter));

    _bloomTimer = Timer(interval, () async {
      if (_state != TransportState.running) return;
      await _broadcastBloomFilter();
      _scheduleNextBloom();
    });
  }

  Future<void> _broadcastBloomFilter() async {
    try {
      final bloomData = await MeshEventHandler.buildLocalBloomFilter(
        limit: AppConfig.bloomMaxEventIds,
      );
      final envelope = pb.MeshEnvelope()
        ..type = pb.EnvelopeType.ENVELOPE_BLOOM_FILTER
        ..payload = bloomData
        ..senderId = _localUserId ?? 'unknown';

      final envelopeBytes = Uint8List.fromList(envelope.writeToBuffer());

      await _bridgefy.send(
        data: envelopeBytes,
        transmissionMode: BridgefyTransmissionMode(
          type: BridgefyTransmissionModeType.broadcast,
          uuid: '',
        ),
      );
      _dlog('BLOOM broadcast ${bloomData.length}B');
    } catch (e) {
      _dlog('Bloom broadcast error: $e');
    }
  }

  /// 收到遠端 Bloom Filter → 計算差集 → 回傳缺少事件
  Future<void> _handleRemoteBloomFilter(
      List<int> bloomBytes, String senderId) async {
    final remoteEventIds = MeshEventHandler.parseBloomFilter(bloomBytes);
    _dlog('BLOOM from $senderId: ${remoteEventIds.length} event IDs');

    // 從 DB 取出最近 24h 事件，找出對方沒有的
    final db = await DatabaseHelper().database;
    final cutoff24h =
        DateTime.now().millisecondsSinceEpoch - (24 * 3600 * 1000);
    final myEvents = await db.query(
      'Event_Logs',
      columns: [
        'event_id',
        'payload',
        'urgency',
        'event_type',
        'signature',
        'sender_pub_key',
        'hlc_timestamp',
        'hlc_counter',
        'received_lat',
        'received_lng',
      ],
      where: 'hlc_timestamp > ?',
      whereArgs: [cutoff24h],
      orderBy: 'urgency DESC, hlc_timestamp DESC',
      limit: 50,
    );

    int sentCount = 0;
    for (final evt in myEvents) {
      final evtId = evt['event_id'] as String;
      if (remoteEventIds.contains(evtId)) continue;

      final payload = evt['payload'] as Uint8List?;
      if (payload == null) continue;

      try {
        final wireData = MeshEventHandler.encodeWirePayload(
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

        // 用 mesh 模式定向回傳給請求者
        final envelopeData = pb.MeshEnvelope()
          ..type = pb.EnvelopeType.ENVELOPE_EVENT
          ..payload = wireData
          ..senderId = _localUserId ?? 'unknown';

        await _bridgefy.send(
          data: Uint8List.fromList(envelopeData.writeToBuffer()),
          transmissionMode: BridgefyTransmissionMode(
            type: BridgefyTransmissionModeType.mesh,
            uuid: senderId,
          ),
        );
        sentCount++;
        _sentCount++;
      } catch (e) {
        _dlog('Bloom diff send error: $e');
        break;
      }
    }

    // 也推送 TriageQueue 中排隊的事件
    final queue = EventManager().queue;
    while (!queue.isEmpty) {
      final task = queue.dequeue();
      if (task == null) break;
      if (remoteEventIds.contains(task.eventId)) continue;

      try {
        final wireData = MeshEventHandler.encodeWirePayload(
          task.eventId,
          task.payload,
          urgency: task.urgency,
        );
        final envelopeData = pb.MeshEnvelope()
          ..type = pb.EnvelopeType.ENVELOPE_EVENT
          ..payload = wireData
          ..senderId = _localUserId ?? 'unknown';

        await _bridgefy.send(
          data: Uint8List.fromList(envelopeData.writeToBuffer()),
          transmissionMode: BridgefyTransmissionMode(
            type: BridgefyTransmissionModeType.mesh,
            uuid: senderId,
          ),
        );
        sentCount++;
        _sentCount++;
      } catch (e) {
        queue.enqueue(task);
        break;
      }
    }

    _dlog('BLOOM diff → sent $sentCount events to $senderId');
  }

  // ── BridgefyDelegate callbacks ──────────────────────────────────

  @override
  void bridgefyDidStart({required String currentUserID}) {
    _localUserId = currentUserID;
    _dlog('Started as userID=$currentUserID');
  }

  @override
  void bridgefyDidFailToStart({required BridgefyError error}) {
    _dlog('Failed to start: ${error.type} - ${error.message}');
    _state = TransportState.error;
    _stateController.add(_state);
  }

  @override
  void bridgefyDidStop() {
    _dlog('SDK stopped');
    _state = TransportState.stopped;
    _stateController.add(_state);
  }

  @override
  void bridgefyDidFailToStop({required BridgefyError error}) {
    _dlog('Failed to stop: ${error.type}');
  }

  @override
  void bridgefyDidReceiveData({
    required Uint8List data,
    required String messageId,
    required BridgefyTransmissionMode transmissionMode,
  }) {
    _dlog('RECV ${data.length}B msgId=$messageId');

    try {
      // 解析 MeshEnvelope
      final envelope = pb.MeshEnvelope.fromBuffer(data);

      switch (envelope.type) {
        case pb.EnvelopeType.ENVELOPE_BLOOM_FILTER:
          _handleRemoteBloomFilter(envelope.payload, envelope.senderId);
          break;

        case pb.EnvelopeType.ENVELOPE_EVENT:
          // 交給共用 MeshEventHandler 處理
          _eventHandler.handleIncomingData(
            Uint8List.fromList(envelope.payload),
            envelope.senderId,
          );
          // 轉發到上層 stream
          _dataController.add(MeshDataReceived(
            envelope.senderId,
            Uint8List.fromList(envelope.payload),
            messageId: messageId,
          ));
          break;

        default:
          _dlog('Unknown envelope type: ${envelope.type}');
      }
    } catch (e) {
      // Fallback: 可能是未包裝的舊格式
      _dlog('Envelope parse failed, trying raw: $e');
      _eventHandler.handleIncomingData(data, 'unknown');
      _dataController.add(MeshDataReceived('unknown', data, messageId: messageId));
    }
  }

  @override
  void bridgefyDidSendDataProgress({
    required String messageID,
    required int position,
    required int of,
  }) {
    // 大封包分塊傳輸進度（通常不需處理）
  }

  @override
  void bridgefyDidSendMessage({required String messageID}) {
    _dlog('Message sent: $messageID');
  }

  @override
  void bridgefyDidFailSendingMessage({
    required String messageID,
    BridgefyError? error,
  }) {
    _dlog('Send failed msgID=$messageID: ${error?.type}');
  }

  @override
  void bridgefyDidConnect({required String userID}) {
    _connectedPeers.add(userID);
    _peerConnectedController.add(userID);
    _dlog('Peer connected: $userID (total=${_connectedPeers.length})');
  }

  @override
  void bridgefyDidDisconnect({required String userID}) {
    _connectedPeers.remove(userID);
    _peerDisconnectedController.add(userID);
    _dlog('Peer disconnected: $userID (total=${_connectedPeers.length})');
  }

  @override
  void bridgefyDidEstablishSecureConnection({required String userID}) {
    _dlog('Secure connection established: $userID');
  }

  @override
  void bridgefyDidFailToEstablishSecureConnection({
    required String userID,
    required BridgefyError error,
  }) {
    _dlog('Secure connection failed: $userID - ${error.type}');
  }

  @override
  void bridgefyDidDestroySession() {
    _dlog('Session destroyed');
    _state = TransportState.stopped;
    _stateController.add(_state);
  }

  @override
  void bridgefyDidFailToDestroySession() {
    _dlog('Failed to destroy session');
  }
}
