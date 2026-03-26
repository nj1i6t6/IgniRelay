import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../mesh/event_manager.dart';
import '../mesh/mesh_event_handler.dart';
import '../services/location_service.dart';
import '../services/match_repository.dart';
import '../services/match_service.dart';
import 'navigation_screen.dart';
import 'resource_request_sheet.dart';
import 'supply_registration.dart';
import 'supply_category_data.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _repo = MatchRepository();
  final _matchService = MatchService();
  final _eventManager = EventManager();
  final _locationService = LocationService();
  List<MatchEntry> _matches = [];
  List<MatchEntry> _inboundMatches = [];
  List<MyPublish> _myPublishes = [];
  List<CommunityItem> _communityItems = [];
  bool _loading = true;
  String? _error;
  String? _gpsWarning;
  late final AnimationController _refreshSpinCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _isRefreshing = false;
  StreamSubscription? _meshEventSub;
  Timer? _meshDebounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
    // 監聽 Mesh 事件，收到新資料時自動刷新社區動態
    _meshEventSub = MeshEventHandler().events.listen((_) {
      _meshDebounce?.cancel();
      _meshDebounce = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isRefreshing) _loadAll();
      });
    });
  }

  @override
  void dispose() {
    _meshEventSub?.cancel();
    _meshDebounce?.cancel();
    _refreshSpinCtrl.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    final gpsFuture = _locationService.init();
    final dataFuture = _loadAll();
    await Future.wait([gpsFuture, dataFuture]);

    if (mounted) {
      setState(() {
        _gpsWarning = _locationService.unavailableReason;
      });
    }
  }

  Future<void> _refreshWithSpin() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshSpinCtrl.repeat();
    try {
      await Future.wait([
        _loadAll(),
        Future.delayed(const Duration(milliseconds: 800)),
      ]);
    } finally {
      _refreshSpinCtrl.stop();
      _refreshSpinCtrl.reset();
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 過期配對自動釋放
      await _eventManager.expireStaleMatches();

      final results = await Future.wait([
        _repo.getAvailableSupplies(),
        _repo.getRequests(),
        _repo.getMyPublishes(),
        _repo.getCommunityItems(),
        _repo.getOthersSupplies(),
        _repo.getMyRequests(),
      ]);
      final supplies = results[0] as List<DecodedSupply>;
      final requests = results[1] as List<DecodedRequest>;
      final publishes = results[2] as List<MyPublish>;
      final community = results[3] as List<CommunityItem>;
      final othersSupplies = results[4] as List<DecodedSupply>;
      final myRequests = results[5] as List<DecodedRequest>;

      final matchResult = _matchService.computeFullMatches(
        mySupplies: supplies,
        allRequests: requests,
        othersSupplies: othersSupplies,
        myRequests: myRequests,
      );

      if (mounted) {
        setState(() {
          _matches = matchResult.outboundMatches;
          _inboundMatches = matchResult.inboundMatches;
          _myPublishes = publishes;
          _communityItems = community;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[MatchScreen] 載入失敗: $e');
      if (mounted) {
        setState(() {
          _error = '載入失敗: $e';
          _loading = false;
        });
      }
    }
  }

  // ── UI 工具 ────────────────────────────────────────────────────

  Widget _buildGpsWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.orange[900]!.withValues(alpha: 0.85),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _gpsWarning ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          if (_locationService.permDeniedForever)
            TextButton(
              onPressed: () => Geolocator.openAppSettings(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('開啟設定',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            )
          else
            TextButton(
              onPressed: () => Geolocator.openLocationSettings(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('開啟定位',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Color _urgencyColor(int urgency) {
    switch (urgency) {
      case 3:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _urgencyLabel(int urgency) {
    switch (urgency) {
      case 3:
        return '緊急求救';
      case 2:
        return '求助';
      case 1:
        return '物資';
      default:
        return '資訊';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: const Text('物資媒合', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        actions: [
          IconButton(
            icon: AnimatedBuilder(
              animation: _refreshSpinCtrl,
              builder: (_, child) => Transform.rotate(
                angle: _refreshSpinCtrl.value * 2 * 3.14159265,
                child: child,
              ),
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
            onPressed: _refreshWithSpin,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent))
          : Column(
              children: [
                if (_gpsWarning != null) _buildGpsWarningBanner(),
                Expanded(child: _buildBody()),
              ],
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: 'supply',
              backgroundColor: Colors.green[700],
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const SupplyRegistrationScreen()))
                    .then((_) => _loadAll());
              },
              icon: const Icon(Icons.add_box, color: Colors.white),
              label:
                  const Text('登記物資供給', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'request',
              backgroundColor: Colors.redAccent,
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const ResourceRequestScreen()))
                    .then((_) => _loadAll());
              },
              icon: const Icon(Icons.volunteer_activism, color: Colors.white),
              label:
                  const Text('發布物資需求', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadAll,
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (_myPublishes.isEmpty &&
        _matches.isEmpty &&
        _inboundMatches.isEmpty &&
        _communityItems.isEmpty) {
      return _buildEmpty();
    }

    return ListView(
      padding:
          const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 140),
      children: [
        // ── 我的發布 ──
        if (_myPublishes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('我的發布',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          ..._myPublishes.map((p) => _buildMyPublishCard(p)),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
        ],
        // ── 媒合結果：我能幫助 ──
        if (_matches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.volunteer_activism,
                    color: Colors.greenAccent, size: 18),
                const SizedBox(width: 6),
                const Text('我能幫助',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('${_matches.length} 筆',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('我的物資可以幫助以下需求者',
                style: TextStyle(color: Colors.white30, fontSize: 11)),
          ),
          ..._matches.map((m) => _buildMatchCard(m)),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
        ],
        // ── 媒合結果：可以幫我 ──
        if (_inboundMatches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.handshake,
                    color: Colors.amberAccent, size: 18),
                const SizedBox(width: 6),
                const Text('可以幫我',
                    style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('${_inboundMatches.length} 筆',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('他人的物資可以滿足我的需求',
                style: TextStyle(color: Colors.white30, fontSize: 11)),
          ),
          ..._inboundMatches.map((m) => _buildMatchCard(m)),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
        ],
        // ── 社區動態（同里/同鄉鎮他人的供給與需求）──
        if (_communityItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 6),
                const Text('社區動態',
                    style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('${_communityItems.length} 筆',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('同區域其他用戶透過 Mesh 同步的供給與需求',
                style: TextStyle(color: Colors.white30, fontSize: 11)),
          ),
          ..._communityItems.map((item) => _buildCommunityCard(item)),
        ],
        // ── 空狀態提示 ──
        if (_myPublishes.isNotEmpty &&
            _matches.isEmpty &&
            _inboundMatches.isEmpty &&
            _communityItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('尚無媒合結果，等待 Mesh 網路同步...',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text('目前沒有媒合項目',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            '發布物資需求或登記物資供給後\n項目會列在這裡，等待 Mesh 網路配對',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── 我的發布卡片 ──────────────────────────────────────────────

  Widget _buildMyPublishCard(MyPublish pub) {
    final time = DateTime.fromMillisecondsSinceEpoch(pub.timestamp);
    final timeStr =
        '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final isSupply = pub.isSupply;
    final displayTitle = getReadableName(pub.title);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: isSupply
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isSupply ? Colors.green : Colors.amber)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSupply ? Icons.inventory_2 : Icons.campaign,
                color: isSupply ? Colors.greenAccent : Colors.amber,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isSupply ? Colors.green : Colors.amber)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSupply ? '供給' : '需求',
                          style: TextStyle(
                            color: isSupply ? Colors.greenAccent : Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(timeStr,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (pub.subtitle.isNotEmpty)
                    Text(pub.subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined,
                  color: Colors.redAccent, size: 22),
              tooltip: isSupply ? '取消供給' : '取消需求',
              onPressed: () => _confirmCancelPublish(pub),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancelPublish(MyPublish pub) async {
    final displayTitle = getReadableName(pub.title);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          pub.isSupply ? '取消物資供給' : '取消物資需求',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          '確定要取消「$displayTitle」嗎？\n取消後將從 Mesh 網路移除。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確定取消', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      if (pub.isSupply) {
        await _eventManager.cancelSupply(pub.eventId);
      } else {
        await _eventManager.cancelRequest(pub.eventId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已取消${pub.isSupply ? "供給" : "需求"}：$displayTitle'),
            backgroundColor: Colors.grey[700],
          ),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('取消失敗: $e'), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  // ── 媒合結果卡片 ────────────────────────────────────────────────

  Widget _buildMatchCard(MatchEntry entry) {
    final urgencyColor = _urgencyColor(entry.urgency);
    final readableName = getReadableName(entry.resourceType);

    final pct = (entry.fulfillmentRatio * 100).toInt();
    final fulfillColor = pct >= 80 ? Colors.greenAccent : Colors.orange;
    final fulfillLabel = pct >= 80 ? '$pct%' : '$pct%';

    String deliveryLabel;
    IconData deliveryIcon;
    Color deliveryColor;
    if (entry.deliveryMode == 'DELIVER' && entry.mobilityMode == 'CAN_GO') {
      deliveryLabel = '供給者前往需求者';
      deliveryIcon = Icons.arrow_forward;
      deliveryColor = Colors.greenAccent;
    } else if (entry.deliveryMode == 'DELIVER' &&
        entry.mobilityMode == 'NEED_DELIVER') {
      deliveryLabel = '供給者送達';
      deliveryIcon = Icons.delivery_dining;
      deliveryColor = Colors.greenAccent;
    } else {
      deliveryLabel = '需求者自行前往';
      deliveryIcon = Icons.directions_walk;
      deliveryColor = Colors.blueAccent;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: urgencyColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openNavigation(entry),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _urgencyLabel(entry.urgency),
                      style: TextStyle(
                          color: urgencyColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        readableName,
                        style: const TextStyle(
                            color: Colors.greenAccent, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: fulfillColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      fulfillLabel,
                      style: TextStyle(
                          color: fulfillColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entry.score.toStringAsFixed(0)} 分',
                    style: const TextStyle(
                        color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '供給: ${entry.supplyQty.toInt()} 份  ←→  需求: ${entry.requestQty.toInt()} 份',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  if (entry.distanceMeters >= 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place,
                            size: 12, color: Colors.white38),
                        const SizedBox(width: 2),
                        Text(
                          LocationService.formatDistance(entry.distanceMeters),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '需求: ${getReadableName(entry.requestDesc)}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(deliveryIcon, size: 14, color: deliveryColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(deliveryLabel,
                        style: TextStyle(color: deliveryColor, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const Spacer(),
                  Icon(Icons.verified_user, size: 13, color: Colors.grey[400]),
                  Text(' L${entry.identityLevel}',
                      style:
                          TextStyle(color: Colors.grey[400], fontSize: 12)),
                  const SizedBox(width: 8),
                  const Icon(Icons.navigation, color: Colors.white38, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNavigation(MatchEntry entry) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => NavigationScreen(match: entry),
        ))
        .then((_) => _loadAll());
  }

  // ── 社區動態卡片 ────────────────────────────────────────────────

  Widget _buildCommunityCard(CommunityItem item) {
    final time = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
    final timeStr =
        '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final readableName = getReadableName(item.resourceType);
    final isSupply = item.isSupply;
    final urgencyColor = _urgencyColor(item.urgency);

    final typeColor = isSupply ? Colors.tealAccent : Colors.orangeAccent;
    final typeLabel = isSupply ? '有人可提供' : '有人需要';
    final typeIcon = isSupply ? Icons.volunteer_activism : Icons.front_hand;
    final actionLabel = isSupply ? '我需要' : '我可以提供';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFF12122a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: typeColor.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showCommunityResponseDialog(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(typeLabel,
                              style: TextStyle(
                                  color: typeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_urgencyLabel(item.urgency),
                              style: TextStyle(
                                  color: urgencyColor, fontSize: 9)),
                        ),
                        const SizedBox(width: 6),
                        Text(timeStr,
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$readableName  ${item.quantity.toInt()} 份',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description.isNotEmpty)
                      Text(item.description,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // 回應按鈕
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(actionLabel,
                    style: TextStyle(
                        color: typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 回應社區動態項目的確認對話框
  Future<void> _showCommunityResponseDialog(CommunityItem item) async {
    final readableName = getReadableName(item.resourceType);
    final isSupply = item.isSupply;
    final qtyController =
        TextEditingController(text: item.quantity.toInt().toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: Text(
            isSupply ? '確認需求數量' : '確認提供數量',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSupply
                    ? '有人可以提供「$readableName」${item.quantity.toInt()} 份'
                    : '有人需要「$readableName」${item.quantity.toInt()} 份',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                isSupply ? '您需要幾份？' : '您可以提供幾份？',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  hintText: '數量',
                  hintStyle: const TextStyle(color: Colors.white30),
                  suffixText: '份',
                  suffixStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isSupply ? Colors.orangeAccent : Colors.tealAccent,
                foregroundColor: Colors.black,
              ),
              child: Text(isSupply ? '確認需求' : '確認提供'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final qty = int.tryParse(qtyController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('數量必須大於 0'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final loc = _locationService.currentLocation;

    try {
      if (isSupply) {
        // 對方有供給 → 我發布需求
        await _eventManager.publishRequest(
          resourceType: item.resourceType,
          quantity: qty,
          note: '回應社區供給',
          maxRangeMeters: 5000,
          mobilityMode: 'CAN_GO',
          lat: loc?.latitude,
          lng: loc?.longitude,
        );
      } else {
        // 對方有需求 → 我登記供給
        await _eventManager.publishSupply(
          resourceType: item.resourceType,
          quantity: qty,
          maxRangeMeters: 5000,
          deliveryMode: 'PICKUP',
          lat: loc?.latitude,
          lng: loc?.longitude,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isSupply ? '已發布需求 $qty 份「$readableName」' : '已登記供給 $qty 份「$readableName」'),
            backgroundColor: Colors.green[700],
          ),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發布失敗: $e'), backgroundColor: Colors.red[700]),
        );
      }
    }
  }
}
