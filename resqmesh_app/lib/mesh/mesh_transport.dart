import 'dart:async';
import 'dart:typed_data';

/// Mesh 網路收到的資料封包
class MeshDataReceived {
  final String sourceNodeId;
  final Uint8List data;
  final String? messageId;

  MeshDataReceived(this.sourceNodeId, this.data, {this.messageId});
}

/// Transport 統計資訊（供 UI Debug 面板使用）
class TransportStats {
  final int sentCount;
  final int receivedCount;
  final int connectedPeers;
  final int seenEventsCount;
  final List<String> debugLogs;

  const TransportStats({
    this.sentCount = 0,
    this.receivedCount = 0,
    this.connectedPeers = 0,
    this.seenEventsCount = 0,
    this.debugLogs = const [],
  });
}

/// Transport 狀態
enum TransportState { stopped, starting, running, error }

/// MeshTransport 抽象介面
///
/// 上層（EventManager、UI）只依賴此介面，
/// 不感知底層實作細節。
/// 這層抽象確保未來替換 transport 時，上層程式碼零修改。
abstract class MeshTransport {
  // ── 生命週期 ─────────────────────────────────────────────
  /// 初始化 transport
  Future<void> initialize();

  /// 啟動 mesh 網路（開始掃描/廣播）
  Future<void> start();

  /// 停止 mesh 網路
  Future<void> stop();

  // ── 發送 ─────────────────────────────────────────────────
  /// 廣播資料給所有附近節點（透過 mesh 擴散）
  /// 回傳 messageId
  Future<String> broadcast(Uint8List data);

  /// 定向傳送資料給特定節點（透過 mesh 多跳）
  /// 回傳 messageId
  Future<String> sendToNode(String nodeId, Uint8List data);

  // ── 接收（Streams）────────────────────────────────────────
  /// 收到資料時觸發（raw Protobuf bytes）
  Stream<MeshDataReceived> get onDataReceived;

  /// Peer 連線時觸發
  Stream<String> get onPeerConnected;

  /// Peer 斷線時觸發
  Stream<String> get onPeerDisconnected;

  /// Transport 狀態變化
  Stream<TransportState> get onStateChanged;

  // ── 狀態查詢 ─────────────────────────────────────────────
  /// transport 是否運作中
  bool get isActive;

  /// 統計資訊（供 Debug UI）
  TransportStats get stats;

  /// 釋放資源
  void dispose();
}
