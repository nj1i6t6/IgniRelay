import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ignirelay_app/app/controllers/ble_scan_controller.dart';
import 'package:ignirelay_app/app/services/negotiation_manager.dart';
import 'package:ignirelay_app/app/services/negotiation_events.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:ignirelay_app/app/mesh/mbtiles_loader.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/match_service.dart';
import 'package:ignirelay_app/ui/secondary/physical_handoff.dart';
import 'package:ignirelay_app/ui/theme/ignirelay_theme.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';

/// 導航引導畫面
/// 顯示供給/需求兩方座標、直線距離、方位、BLE 近接偵測
class NavigationScreen extends StatefulWidget {
  final MatchEntry match;
  final String negotiationId;

  const NavigationScreen({super.key, required this.match, required this.negotiationId});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _location = LocationService();
  final _mapController = MapController();
  final _eventManager = EventManager();

  // MBTiles 離線地圖
  MbTiles? _mbTiles;
  TileProviders? _tileProviders;
  vtr.Theme? _mapTheme;
  bool _mapReady = false;

  // BLE 掃描
  StreamSubscription? _bleScanSub;
  bool _peerDetected = false;
  int _peerRssi = -100;
  Timer? _scanTimer;
  bool _scanning = false;

  // 位置更新
  Timer? _locationRefresh;
  LatLng? _myLocation;

  // 對方位置（從 Match_Negotiations 讀取）
  LatLng? _peerLocation;
  StreamSubscription? _meshEventSub;

  // Negotiation 事件訂閱（取消/完成偵測）
  late final StreamSubscription _negotiationSub;

  @override
  void initState() {
    super.initState();
    _myLocation = _location.currentLocation;
    _initMBTiles();
    _startBleScan();
    _loadPeerLocation();
    // 每 3 秒刷新位置 + 發送位置同步
    _locationRefresh = Timer.periodic(const Duration(seconds: 3), (_) {
      final loc = _location.currentLocation;
      if (loc != null && mounted) {
        setState(() => _myLocation = loc);
        // 背景發送位置更新（內部有 30s 節流）
        _eventManager.publishLocationUpdate(
          negotiationId: widget.negotiationId,
          lat: loc.latitude,
          lng: loc.longitude,
        );
      }
      // 讀取對方最新位置
      _loadPeerLocation();
    });
    // 監聽 Mesh 事件，即時更新對方位置
    _meshEventSub = MeshEventHandler().events.listen((_) {
      _loadPeerLocation();
    });
    // 監聽 Negotiation 事件（取消 / 完成）
    _negotiationSub = NegotiationManager().events.listen((event) {
      if (event is NegotiationCancelled && event.negotiationId == widget.negotiationId) {
        _locationRefresh?.cancel();
        if (mounted) {
          HapticFeedback.vibrate();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1a1a2e),
              title: Text(S.of(context)!.navCancelDialogTitle, style: const TextStyle(color: Colors.white)),
              content: Text(S.of(context)!.navCancelDialogContent, style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  child: Text(S.of(context)!.navCancelDialogBack, style: const TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          );
        }
      } else if (event is NegotiationCompleted && event.negotiationId == widget.negotiationId) {
        _locationRefresh?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context)!.navCompleteSnack), backgroundColor: Colors.green),
          );
          Navigator.popUntil(context, (r) => r.isFirst);
        }
      }
    });
  }

  Future<void> _loadPeerLocation() async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query('Match_Negotiations',
          where: "negotiation_id = ? AND status IN ('ACCEPTED', 'NAVIGATING')",
          whereArgs: [widget.negotiationId],
          limit: 1);
      if (rows.isEmpty || !mounted) return;

      final session = rows.first;
      // 判斷自己是 provider 還是 requester，讀對方的位置
      // （myLoc 目前未用於 peer 推算；保留 deliveryMode 判斷即可）
      final providerLat = (session['provider_lat'] as num?)?.toDouble();
      final providerLng = (session['provider_lng'] as num?)?.toDouble();
      final requesterLat = (session['requester_lat'] as num?)?.toDouble();
      final requesterLng = (session['requester_lng'] as num?)?.toDouble();

      // 如果 deliveryMode == DELIVER, 我是供給者 → 對方是 requester
      // 如果 deliveryMode == PICKUP, 我是需求者 → 對方是 provider
      LatLng? peerLoc;
      if (widget.match.deliveryMode == 'DELIVER') {
        if (requesterLat != null && requesterLng != null &&
            requesterLat != 0 && requesterLng != 0) {
          peerLoc = LatLng(requesterLat, requesterLng);
        }
      } else {
        if (providerLat != null && providerLng != null &&
            providerLat != 0 && providerLng != 0) {
          peerLoc = LatLng(providerLat, providerLng);
        }
      }

      if (peerLoc != null && mounted) {
        setState(() => _peerLocation = peerLoc);
      }
    } catch (_) {}
  }

  Future<void> _initMBTiles() async {
    try {
      final available = await MBTilesLoader.isAvailable();
      if (!available) return;
      final path = await MBTilesLoader.getLocalPath();
      await MBTilesLoader.sanitizeMetadata(path);
      final mbTiles = MbTiles(mbtilesPath: path, gzip: true);
      final provider = MbTilesVectorTileProvider(mbtiles: mbTiles);
      // 不帶 POI → 傳入全部 disabled（空 set = 全部啟用，我們直接用無 POI 的 theme）
      final theme = buildIgniRelayTheme(disabledPoi: _allPoiIds);
      if (mounted) {
        setState(() {
          _mbTiles = mbTiles;
          _tileProviders = TileProviders({'openmaptiles': provider});
          _mapTheme = theme;
          _mapReady = true;
        });
      }
    } catch (e) {
      debugPrint('[Navigation] MBTiles init failed: $e');
    }
  }

  /// 所有 POI ID，用來讓 theme 隱藏全部 POI 圖層
  static final Set<String> _allPoiIds = {
    'resq_grocery',
    'resq_pharmacy',
    'resq_school',
    'resq_police',
    'resq_hospital',
  };

  LatLng? get _supplyPos {
    final m = widget.match;
    if (m.supplyLat != null && m.supplyLng != null) {
      return LatLng(m.supplyLat!, m.supplyLng!);
    }
    return null;
  }

  LatLng? get _requestPos {
    final m = widget.match;
    if (m.requestLat != null && m.requestLng != null) {
      return LatLng(m.requestLat!, m.requestLng!);
    }
    return null;
  }

  LatLng get _targetPos {
    // 優先使用即時對方位置
    if (_peerLocation != null) return _peerLocation!;
    // 根據配送方向決定目標
    // DELIVER → 供給者要前往需求者位置
    // PICKUP → 需求者要前往供給者位置
    if (widget.match.deliveryMode == 'DELIVER') {
      return _requestPos ??
          _supplyPos ??
          _myLocation ??
          const LatLng(25.033, 121.565);
    }
    return _supplyPos ??
        _requestPos ??
        _myLocation ??
        const LatLng(25.033, 121.565);
  }

  // ── BLE 掃描 ──────────────────────────────────────────────────

  Future<void> _startBleScan() async {
    try {
      final btOn = await BleScanController.instance.isBluetoothEnabled();
      if (!btOn) {
        debugPrint('[Navigation] BLE 未開啟');
        return;
      }

      _scanning = true;
      _performScan();

      // 每 15 秒重新掃描
      _scanTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted && _scanning) _performScan();
      });
    } catch (e) {
      debugPrint('[Navigation] BLE 初始化失敗: $e');
    }
  }

  Future<void> _performScan() async {
    try {
      await BleScanController.instance.startScan();

      _bleScanSub?.cancel();
      _bleScanSub = BleScanController.instance.rawEventStream.listen((event) {
        if (event is Map && event['type'] == 'nordic_found' && mounted) {
          final rssi = event['rssi'] as int? ?? -100;
          setState(() {
            _peerDetected = true;
            if (rssi > _peerRssi) _peerRssi = rssi;
          });
        }
      });

      // 8 秒後停止本輪掃描
      Future.delayed(const Duration(seconds: 8), () {
        if (_scanning) BleScanController.instance.stopScan();
      });
    } catch (e) {
      debugPrint('[Navigation] BLE scan error: $e');
    }
  }

  void _stopBleScan() {
    _scanning = false;
    _scanTimer?.cancel();
    _bleScanSub?.cancel();
    try {
      BleScanController.instance.stopScan();
    } catch (_) {}
  }

  // ── 開始交接 ──────────────────────────────────────────────────

  void _startHandoff() {
    // Stage 5：依 deliveryMode 判定當前裝置在交接中的角色，避免硬編碼成 provider。
    // 與 `_loadPeerLocation` / `_targetPos` 採同一套慣例：
    //   - DELIVER：我是供給者（provider），要把物資帶到需求者位置
    //   - PICKUP（含未填值的 fallback）：我是需求者（requester），要前往供給者位置
    final role = widget.match.deliveryMode == 'DELIVER'
        ? HandoffRole.provider
        : HandoffRole.requester;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PhysicalHandoffScreen(
        role: role,
        resourceId: widget.match.resourceId,
        resourceType: widget.match.resourceType,
        urgency: widget.match.urgency,
        requestId: widget.match.requestEventId,
        negotiationId: widget.negotiationId,
      ),
    ));
  }

  // ── UI ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final readableName = getLocalizedReadableName(m.resourceType, context);
    final myLoc = _myLocation;
    final target = _targetPos;

    // 距離和方向
    double? distMeters;
    String? dirLabel;
    double? bearingDeg;
    if (myLoc != null) {
      distMeters = LocationService.haversineMeters(myLoc, target);
      bearingDeg = LocationService.bearing(myLoc, target);
      dirLabel = LocationService.bearingToDirection(bearingDeg);
    } else if (m.distanceMeters > 0) {
      distMeters = m.distanceMeters;
    }

    // 配送方向描述
    String whoMoves;
    if (m.deliveryMode == 'DELIVER') {
      whoMoves = S.of(context)!.navDirectionProviderToReq;
    } else {
      whoMoves = S.of(context)!.navDirectionReqToProvider;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: Text(S.of(context)!.navTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── 地圖區域 ──
          Expanded(
            flex: 5,
            child: _buildMap(myLoc, target),
          ),

          // ── 資訊面板 ──
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1a1a2e),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 物資名稱 + 配送方向
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(readableName,
                                style: const TextStyle(
                                    color: Colors.greenAccent, fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          m.deliveryMode == 'DELIVER'
                              ? Icons.delivery_dining
                              : Icons.directions_walk,
                          color: Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(whoMoves,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 距離 + 方向 大字
                    if (distMeters != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            LocationService.formatDistance(distMeters),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (dirLabel != null) ...[
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  if (bearingDeg != null)
                                    Transform.rotate(
                                      angle: bearingDeg * pi / 180,
                                      child: const Icon(
                                        Icons.navigation,
                                        color: Colors.redAccent,
                                        size: 24,
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  Text(dirLabel,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 18)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        S.of(context)!.navSupplyInfo(m.supplyQty.toInt(), m.requestQty.toInt(), (m.fulfillmentRatio * 100).toInt()),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      Text(S.of(context)!.navGpsLocating,
                          style:
                              const TextStyle(color: Colors.white38, fontSize: 16)),
                    ],
                    const SizedBox(height: 16),

                    // BLE 狀態
                    _buildBleStatus(context),

                    const SizedBox(height: 16),

                    // 交接按鈕
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _peerDetected ? _startHandoff : null,
                        icon: Icon(
                          _peerDetected
                              ? Icons.handshake
                              : Icons.bluetooth_searching,
                          color: _peerDetected ? Colors.white : Colors.white38,
                        ),
                        label: Text(
                          _peerDetected ? S.of(context)!.navHandoffButton : S.of(context)!.navHandoffWaiting,
                          style: TextStyle(
                            color:
                                _peerDetected ? Colors.white : Colors.white38,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _peerDetected
                              ? Colors.amber[700]
                              : const Color(0xFF2a2a3e),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(LatLng? myLoc, LatLng target) {
    // 計算 bounds 包含所有點
    final points = <LatLng>[target];
    if (myLoc != null) points.add(myLoc);
    if (_supplyPos != null) points.add(_supplyPos!);
    if (_requestPos != null) points.add(_requestPos!);

    final center = _fitCenter(points);
    final zoom = _fitZoom(points);

    final markers = <Marker>[];
    final polylines = <Polyline>[];

    // 我的位置
    if (myLoc != null) {
      markers.add(Marker(
        point: myLoc,
        width: 24,
        height: 24,
        child:
            const Icon(Icons.my_location, color: Colors.cyanAccent, size: 24),
      ));
    }

    // 供給位置
    if (_supplyPos != null) {
      markers.add(Marker(
        point: _supplyPos!,
        width: 32,
        height: 32,
        child:
            const Icon(Icons.inventory_2, color: Colors.greenAccent, size: 28),
      ));
    }

    // 需求位置
    if (_requestPos != null) {
      markers.add(Marker(
        point: _requestPos!,
        width: 32,
        height: 32,
        child: const Icon(Icons.campaign, color: Colors.amber, size: 28),
      ));
    }

    // 連線
    if (_supplyPos != null && _requestPos != null) {
      polylines.add(Polyline(
        points: [_supplyPos!, _requestPos!],
        color: Colors.redAccent.withValues(alpha: 0.7),
        strokeWidth: 3,
      ));
    } else if (myLoc != null) {
      polylines.add(Polyline(
        points: [myLoc, target],
        color: Colors.redAccent.withValues(alpha: 0.7),
        strokeWidth: 3,
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 6.0,
        maxZoom: 18.0,
        backgroundColor: const Color(0xFF0a0a18),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // 離線向量圖磚底圖（街道+地名，無 POI/災害）
        if (_mapReady && _tileProviders != null && _mapTheme != null)
          VectorTileLayer(
            tileProviders: _tileProviders!,
            theme: _mapTheme!,
            layerMode: VectorTileLayerMode.vector,
          ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildBleStatus(BuildContext context) {
    if (_peerDetected) {
      // RSSI 轉信號強度
      String strength;
      Color strengthColor;
      if (_peerRssi > -60) {
        strength = S.of(context)!.navBleSignalStrong;
        strengthColor = Colors.greenAccent;
      } else if (_peerRssi > -80) {
        strength = S.of(context)!.navBleSignalMedium;
        strengthColor = Colors.amber;
      } else {
        strength = S.of(context)!.navBleSignalWeak;
        strengthColor = Colors.orange;
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.bluetooth_connected,
                color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text(S.of(context)!.navBleDetected,
                style:
                    const TextStyle(color: Colors.greenAccent, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: strengthColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(S.of(context)!.navBleSignal(strength),
                  style: TextStyle(color: strengthColor, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white38),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.of(context)!.navBleScanning,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _fitCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(25.033, 121.565);
    double sumLat = 0, sumLng = 0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  double _fitZoom(List<LatLng> points) {
    if (points.length < 2) return 15;
    double maxDist = 0;
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final d = LocationService.haversineMeters(points[i], points[j]);
        if (d > maxDist) maxDist = d;
      }
    }
    // 粗略 zoom 映射
    if (maxDist < 100) return 17;
    if (maxDist < 500) return 15;
    if (maxDist < 2000) return 13;
    if (maxDist < 10000) return 11;
    return 9;
  }

  @override
  void dispose() {
    _negotiationSub.cancel();
    _stopBleScan();
    _locationRefresh?.cancel();
    _meshEventSub?.cancel();
    _mbTiles?.dispose();
    super.dispose();
  }
}
