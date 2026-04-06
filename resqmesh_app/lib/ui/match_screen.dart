import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/negotiation_manager.dart';
import '../services/negotiation_events.dart';
import '../services/match_repository.dart';
import '../services/match_service.dart';
import '../mesh/event_manager.dart';
import '../mesh/mesh_event_handler.dart';
import '../services/location_service.dart';
import '../crypto/identity_manager.dart';
import 'supply_registration.dart';
import 'resource_request_sheet.dart';
import 'navigation_screen.dart';
import 'supply_category_data.dart';

// =============================================================================
// MatchScreen — 4-tab layout following three-layer architecture
//
// UI -> NegotiationManager (Application Layer) -> Database
// UI does NOT import database_helper.dart
// UI gets data via NegotiationManager.events Stream + MatchRepository queries
// =============================================================================

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;
  final _negotiationManager = NegotiationManager();
  final _repo = MatchRepository();
  final _matchService = MatchService();
  final _eventManager = EventManager();
  final _locationService = LocationService();
  final _identity = IdentityManager();

  StreamSubscription? _negotiationSub;
  StreamSubscription? _meshEventSub;
  Timer? _meshDebounce;
  Timer? _countdownTimer;

  // Data
  List<DecodedSupply> _mySupplies = [];
  List<DecodedRequest> _myRequests = [];
  List<MyPublish> _mySupplyPublishes = [];
  List<MyPublish> _myRequestPublishes = [];
  List<Map<String, dynamic>> _activeNegotiations = [];
  List<CommunityItem> _communityItems = [];
  List<MatchEntry> _outboundMatches = [];
  List<MatchEntry> _inboundMatches = [];

  bool _loading = true;
  String? _error;
  String? _gpsWarning;
  Uint8List? _myPubKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initAndLoad();

    // Listen to NegotiationManager events for real-time updates
    _negotiationSub = _negotiationManager.events.listen(_onNegotiationEvent);

    // Listen to MeshEventHandler for new supplies/requests (non-negotiation)
    _meshEventSub = MeshEventHandler().events.listen((_) {
      _meshDebounce?.cancel();
      _meshDebounce = Timer(const Duration(seconds: 3), () {
        if (mounted) _loadAll();
      });
    });

    // Countdown timer for active negotiations (updates every second)
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _tabController.index == 2) {
        setState(() {}); // Refresh countdown display
      }
    });
  }

  @override
  void dispose() {
    _negotiationSub?.cancel();
    _meshEventSub?.cancel();
    _meshDebounce?.cancel();
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Initialization & data loading
  // ---------------------------------------------------------------------------

  Future<void> _initAndLoad() async {
    final gpsFuture = _locationService.init();
    final keyFuture = _identity.getPublicKeyBytes();
    final dataFuture = _loadAll();
    final results = await Future.wait([gpsFuture, keyFuture, dataFuture]);

    if (mounted) {
      setState(() {
        _gpsWarning = _locationService.unavailableReason;
        _myPubKey = Uint8List.fromList(results[1] as List<int>);
      });
    }
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = _mySupplies.isEmpty && _myRequests.isEmpty;
      _error = null;
    });
    try {
      // Expire stale negotiations via Application Layer
      await _negotiationManager.expireStaleNegotiations();

      final results = await Future.wait([
        _repo.getAvailableSupplies(), // 0: all available supplies
        _repo.getMyRequests(), // 1: my requests
        _repo.getCommunityItems(), // 2: community
        _repo.getRequests(), // 3: all requests (for matching)
        _repo.getOthersSupplies(), // 4: others' supplies (for matching)
        _repo.getMyPublishes(), // 5: my publishes (supply + request with eventId)
      ]);

      final allMySupplies = results[0] as List<DecodedSupply>;
      final myRequests = results[1] as List<DecodedRequest>;
      final community = results[2] as List<CommunityItem>;
      final allRequests = results[3] as List<DecodedRequest>;
      final othersSupplies = results[4] as List<DecodedSupply>;
      final myPublishes = results[5] as List<MyPublish>;

      // Compute matches
      final matchResult = _matchService.computeFullMatches(
        mySupplies: allMySupplies,
        allRequests: allRequests,
        othersSupplies: othersSupplies,
        myRequests: myRequests,
      );

      // Get active negotiations
      List<Map<String, dynamic>> activeNeg = [];
      if (_myPubKey != null) {
        activeNeg = await _negotiationManager.getMyNegotiations(_myPubKey!);
        // Filter to active statuses
        activeNeg = activeNeg.where((n) {
          final s = n['status'] as String;
          return s == 'PENDING' || s == 'ACCEPTED' || s == 'NAVIGATING';
        }).toList();
      }

      if (mounted) {
        setState(() {
          _mySupplies = allMySupplies;
          _myRequests = myRequests;
          _mySupplyPublishes = myPublishes.where((p) => p.isSupply).toList();
          _myRequestPublishes = myPublishes.where((p) => !p.isSupply).toList();
          _communityItems = community;
          _outboundMatches = matchResult.outboundMatches;
          _inboundMatches = matchResult.inboundMatches;
          _activeNegotiations = activeNeg;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[MatchScreen] load failed: $e');
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _onNegotiationEvent(NegotiationEvent event) {
    if (!mounted) return;
    _loadAll();
    // Show snackbar for key events
    if (event is NegotiationAccepted) {
      _showSnack('协商已接受', Colors.green);
    } else if (event is NegotiationDeclined) {
      _showSnack('协商已拒绝', Colors.orange);
    } else if (event is NegotiationCancelled) {
      _showSnack('协商已取消', Colors.grey);
    } else if (event is NegotiationCompleted) {
      _showSnack('交接完成', Colors.green);
    } else if (event is NegotiationExpired) {
      _showSnack('协商已逾期', Colors.orange);
    } else if (event is OversoldDetected) {
      _showSnack('物资超量警告', Colors.red);
    }
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, duration: const Duration(seconds: 2)),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: const Text('物资媒合', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: Colors.redAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: [
            _buildTab('我的物资', Icons.inventory_2, _mySupplies.length),
            _buildTab('我的需求', Icons.campaign, _myRequests.length),
            _buildTab('进行中', Icons.sync, _activeNegotiations.length),
            _buildTab('社区', Icons.people, _communityItems.length),
          ],
        ),
      ),
      body: _loading && _mySupplies.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Column(
              children: [
                if (_gpsWarning != null) _buildGpsWarningBanner(),
                if (_error != null) _buildErrorBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMySuppliesTab(),
                      _buildMyRequestsTab(),
                      _buildActiveTab(),
                      _buildCommunityTab(),
                    ],
                  ),
                ),
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
              label: const Text('登记物资供给', style: TextStyle(color: Colors.white)),
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
              label: const Text('发布物资需求', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count',
                  style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GPS Warning
  // ---------------------------------------------------------------------------

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
              child: const Text('开启设定',
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
              child: const Text('开启定位',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.red[900]!.withValues(alpha: 0.6),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('载入错误: $_error',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          TextButton(
            onPressed: _loadAll,
            child: const Text('重试', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab 1: 我的物资 (My Supplies)
  // ===========================================================================

  Widget _buildMySuppliesTab() {
    return RefreshIndicator(
      color: Colors.redAccent,
      onRefresh: _loadAll,
      child: _mySupplies.isEmpty
          ? _buildEmptyState(Icons.inventory_2, '尚未登记物资供给', '点击下方按钮登记您可提供的物资')
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: _mySupplies.length,
              itemBuilder: (_, i) => _buildSupplyCard(_mySupplies[i]),
            ),
    );
  }

  Widget _buildSupplyCard(DecodedSupply supply) {
    final readableName = getReadableName(supply.resourceType);
    final totalQty = supply.quantity.toInt();
    final availQty = supply.availableQty.toInt();
    final committedQty = totalQty - availQty;

    Color statusColor;
    String statusLabel;
    if (availQty <= 0) {
      statusColor = Colors.red;
      statusLabel = '已耗尽';
    } else if (committedQty > 0) {
      statusColor = Colors.orange;
      statusLabel = '部分承诺';
    } else {
      statusColor = Colors.green;
      statusLabel = '可用';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2,
                      color: Colors.greenAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(readableName,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        supply.deliveryMode == 'DELIVER' ? '可协助送达' : '需求者自取',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Quantity bar
            Row(
              children: [
                _buildQtyChip('总量', '$totalQty ${supply.unit}', Colors.white54),
                const SizedBox(width: 8),
                _buildQtyChip('可用', '$availQty ${supply.unit}', Colors.greenAccent),
                const SizedBox(width: 8),
                if (committedQty > 0)
                  _buildQtyChip('承诺中', '$committedQty ${supply.unit}', Colors.orange),
              ],
            ),
            const SizedBox(height: 8),
            // Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cancelSupply(supply),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                  label: const Text('取消', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _cancelSupply(DecodedSupply supply) async {
    final readableName = getReadableName(supply.resourceType);

    // Find the eventId from MyPublish data
    final pub = _mySupplyPublishes.where((p) =>
        p.title == supply.resourceType).firstOrNull;
    if (pub == null) {
      _showSnack('找不到对应的发布记录', Colors.orange);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('取消物资供给', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要取消「$readableName」吗？\n取消后将从 Mesh 网路移除。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定取消', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _eventManager.cancelSupply(pub.eventId);
      _showSnack('已取消供给：$readableName', Colors.grey[700]!);
      _loadAll();
    } catch (e) {
      _showSnack('取消失败: $e', Colors.red[700]!);
    }
  }

  // ===========================================================================
  // Tab 2: 我的需求 (My Requests)
  // ===========================================================================

  Widget _buildMyRequestsTab() {
    return RefreshIndicator(
      color: Colors.redAccent,
      onRefresh: _loadAll,
      child: _myRequests.isEmpty
          ? _buildEmptyState(Icons.campaign, '尚未发布物资需求', '点击下方按钮发布您需要的物资')
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: _myRequests.length,
              itemBuilder: (_, i) => _buildRequestCard(_myRequests[i]),
            ),
    );
  }

  Widget _buildRequestCard(DecodedRequest request) {
    final readableName = getReadableName(request.resourceType);
    final totalQty = request.quantityNeeded.toInt();
    final remaining = request.remainingNeed.toInt();
    final fulfilled = totalQty - remaining;

    Color statusColor;
    String statusLabel;
    if (request.status == 'MATCHED') {
      statusColor = Colors.blue;
      statusLabel = '媒合中';
    } else if (remaining <= 0) {
      statusColor = Colors.green;
      statusLabel = '已满足';
    } else {
      statusColor = Colors.amber;
      statusLabel = '等待中';
    }

    // Find incoming proposals for this request
    final incomingForThis = _activeNegotiations.where((n) {
      final reqId = n['request_id'] as String? ?? '';
      final initiatorRole = n['initiator_role'] as String? ?? '';
      final status = n['status'] as String? ?? '';
      return reqId == request.requestId && initiatorRole == 'PROVIDER' && status == 'PENDING';
    }).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _urgencyIcon(request.urgency),
                    color: _urgencyColor(request.urgency),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _urgencyColor(request.urgency).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(_urgencyLabel(request.urgency),
                                style: TextStyle(
                                    color: _urgencyColor(request.urgency),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(readableName,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (request.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(request.note,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildQtyChip('需求', '$totalQty 份', Colors.white54),
                const SizedBox(width: 8),
                _buildQtyChip('剩余', '$remaining 份', remaining > 0 ? Colors.amber : Colors.greenAccent),
                const SizedBox(width: 8),
                if (fulfilled > 0)
                  _buildQtyChip('已满足', '$fulfilled 份', Colors.greenAccent),
              ],
            ),
            // Incoming proposals
            if (incomingForThis.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('收到的提议：',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...incomingForThis.map((neg) => _buildIncomingProposal(neg)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cancelRequest(request),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                  label: const Text('取消', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingProposal(Map<String, dynamic> neg) {
    final negId = neg['negotiation_id'] as String? ?? '';
    final offeredQty = (neg['offered_qty'] as num?)?.toDouble() ?? 0;
    final expiresAt = (neg['expires_at'] as int?) ?? 0;
    final remaining = _formatCountdown(expiresAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.cyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.handshake, color: Colors.cyanAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('提供 ${offeredQty.toInt()} 份',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                Text('剩余 $remaining',
                    style: TextStyle(
                        color: _isExpiringSoon(expiresAt) ? Colors.redAccent : Colors.white38,
                        fontSize: 10)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _acceptNegotiation(neg),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('接受', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => _declineNegotiation(negId, neg),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('拒绝', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptNegotiation(Map<String, dynamic> neg) async {
    final negId = neg['negotiation_id'] as String? ?? '';
    final resourceId = neg['resource_id'] as String? ?? '';
    final requestId = neg['request_id'] as String? ?? '';
    final agreedQty = (neg['offered_qty'] as num?)?.toDouble() ??
        (neg['requested_qty'] as num?)?.toDouble() ?? 0;

    try {
      await _eventManager.publishMatchAccept(
        negotiationId: negId,
        resourceId: resourceId,
        requestId: requestId,
        agreedQty: agreedQty,
      );
      _showSnack('已接受协商', Colors.green);
      _loadAll();
    } catch (e) {
      _showSnack('接受失败: $e', Colors.red[700]!);
    }
  }

  Future<void> _declineNegotiation(String negId, Map<String, dynamic> neg) async {
    final resourceId = neg['resource_id'] as String? ?? '';
    final requestId = neg['request_id'] as String? ?? '';

    try {
      await _eventManager.publishMatchDecline(
        negotiationId: negId,
        resourceId: resourceId,
        requestId: requestId,
        reason: 'USER_DECLINED',
      );
      _showSnack('已拒绝协商', Colors.grey);
      _loadAll();
    } catch (e) {
      _showSnack('拒绝失败: $e', Colors.red[700]!);
    }
  }

  Future<void> _cancelRequest(DecodedRequest request) async {
    final readableName = getReadableName(request.resourceType);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('取消物资需求', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要取消「$readableName」吗？\n取消后将从 Mesh 网路移除。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定取消', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _eventManager.cancelRequest(request.eventId);
      _showSnack('已取消需求：$readableName', Colors.grey[700]!);
      _loadAll();
    } catch (e) {
      _showSnack('取消失败: $e', Colors.red[700]!);
    }
  }

  // ===========================================================================
  // Tab 3: 进行中 (Active Negotiations)
  // ===========================================================================

  Widget _buildActiveTab() {
    return RefreshIndicator(
      color: Colors.redAccent,
      onRefresh: _loadAll,
      child: _activeNegotiations.isEmpty
          ? _buildEmptyState(Icons.sync, '目前没有进行中的协商', '当有人回应您的物资或需求时，协商会显示在这里')
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: _activeNegotiations.length,
              itemBuilder: (_, i) => _buildNegotiationCard(_activeNegotiations[i]),
            ),
    );
  }

  Widget _buildNegotiationCard(Map<String, dynamic> neg) {
    final negId = neg['negotiation_id'] as String? ?? '';
    final status = neg['status'] as String? ?? 'PENDING';
    final resourceId = neg['resource_id'] as String? ?? '';
    final requestId = neg['request_id'] as String? ?? '';
    final initiatorRole = neg['initiator_role'] as String? ?? '';
    final offeredQty = (neg['offered_qty'] as num?)?.toDouble() ?? 0;
    final requestedQty = (neg['requested_qty'] as num?)?.toDouble() ?? 0;
    final expiresAt = (neg['expires_at'] as int?) ?? 0;
    final matchScore = (neg['match_score'] as num?)?.toDouble();

    // Determine my role
    final providerKey = neg['provider_pub_key'] as Uint8List?;
    final isProvider = _myPubKey != null && providerKey != null &&
        _bytesEqual(_myPubKey!, providerKey);
    final myRole = isProvider ? 'PROVIDER' : 'REQUESTER';
    final counterpartLabel = isProvider ? '需求方' : '供给方';

    // Status styling
    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'PENDING':
        statusColor = Colors.amber;
        statusIcon = Icons.hourglass_empty;
        statusLabel = '等待确认';
        break;
      case 'ACCEPTED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = '已接受';
        break;
      case 'NAVIGATING':
        statusColor = Colors.blue;
        statusIcon = Icons.navigation;
        statusLabel = '导航中';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusLabel = status;
    }

    final qty = offeredQty > 0 ? offeredQty : requestedQty;
    final countdown = _formatCountdown(expiresAt);
    final isStale = _negotiationManager.staleNegotiationIds.contains(negId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isStale
                ? Colors.red.withValues(alpha: 0.5)
                : statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (matchScore != null && matchScore > 0)
                  Text('${matchScore.toStringAsFixed(0)} 分',
                      style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            // Qty and role info
            Row(
              children: [
                const Icon(Icons.swap_horiz, color: Colors.white38, size: 16),
                const SizedBox(width: 6),
                Text('${qty.toInt()} 份',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isProvider ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isProvider ? '我提供' : '我需要',
                    style: TextStyle(
                        color: isProvider ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(counterpartLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            // Countdown timer
            Row(
              children: [
                Icon(Icons.timer,
                    size: 14,
                    color: _isExpiringSoon(expiresAt) ? Colors.redAccent : Colors.white38),
                const SizedBox(width: 4),
                Text(
                  countdown,
                  style: TextStyle(
                    color: _isExpiringSoon(expiresAt) ? Colors.redAccent : Colors.white38,
                    fontSize: 11,
                    fontWeight: _isExpiringSoon(expiresAt) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isStale) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('超时',
                        style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Accept button for PENDING where I am the responder
                if (status == 'PENDING' && _isResponderForNeg(neg)) ...[
                  TextButton(
                    onPressed: () => _acceptNegotiation(neg),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('接受', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _declineNegotiation(negId, neg),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('拒绝', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
                // Navigate button for ACCEPTED/NAVIGATING
                if (status == 'ACCEPTED' || status == 'NAVIGATING') ...[
                  TextButton.icon(
                    onPressed: () => _openNavigationForNeg(neg),
                    icon: const Icon(Icons.map, size: 16, color: Colors.cyanAccent),
                    label: const Text('查看地图', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.cyan.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Cancel button (always available for active)
                TextButton(
                  onPressed: () => _cancelNegotiation(neg),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('取消', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isResponderForNeg(Map<String, dynamic> neg) {
    final initiatorRole = neg['initiator_role'] as String? ?? '';
    if (initiatorRole == 'PROVIDER') {
      // Initiator is provider, I need to be the requester to respond
      final requesterKey = neg['requester_pub_key'] as Uint8List?;
      return _myPubKey != null && requesterKey != null && _bytesEqual(_myPubKey!, requesterKey);
    } else {
      // Initiator is requester, I need to be the provider to respond
      final providerKey = neg['provider_pub_key'] as Uint8List?;
      return _myPubKey != null && providerKey != null && _bytesEqual(_myPubKey!, providerKey);
    }
  }

  void _openNavigationForNeg(Map<String, dynamic> neg) {
    final negId = neg['negotiation_id'] as String? ?? '';
    final resourceId = neg['resource_id'] as String? ?? '';

    // Build a MatchEntry for NavigationScreen
    final entry = MatchEntry(
      resourceId: resourceId,
      resourceType: '',
      requestResourceType: '',
      requestDesc: '',
      requestEventId: '',
      requestId: neg['request_id'] as String? ?? '',
      urgency: 0,
      identityLevel: 0,
      score: (neg['match_score'] as num?)?.toDouble() ?? 0,
      hlcTimestamp: 0,
      supplyQty: (neg['offered_qty'] as num?)?.toDouble() ?? 0,
      requestQty: (neg['requested_qty'] as num?)?.toDouble() ?? 0,
      deliveryMode: '',
      mobilityMode: '',
      fulfillmentRatio: 1.0,
      distanceMeters: -1,
      supplyLat: (neg['provider_lat'] as num?)?.toDouble(),
      supplyLng: (neg['provider_lng'] as num?)?.toDouble(),
      requestLat: (neg['requester_lat'] as num?)?.toDouble(),
      requestLng: (neg['requester_lng'] as num?)?.toDouble(),
      requesterPubKey: (neg['requester_pub_key'] as Uint8List?)?.toList(),
      providerPubKey: (neg['provider_pub_key'] as Uint8List?)?.toList(),
    );

    // Start navigating if ACCEPTED
    final status = neg['status'] as String? ?? '';
    if (status == 'ACCEPTED') {
      _negotiationManager.startNavigating(negId);
    }

    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => NavigationScreen(match: entry, negotiationId: negId),
        ))
        .then((_) => _loadAll());
  }

  Future<void> _cancelNegotiation(Map<String, dynamic> neg) async {
    final negId = neg['negotiation_id'] as String? ?? '';
    final resourceId = neg['resource_id'] as String? ?? '';
    final requestId = neg['request_id'] as String? ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('取消协商', style: TextStyle(color: Colors.white)),
        content: const Text('确定要取消此协商吗？', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定取消', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _eventManager.publishMatchCancel(
        negotiationId: negId,
        resourceId: resourceId,
        requestId: requestId,
        reason: 'USER_CANCELLED',
      );
      _showSnack('已取消协商', Colors.grey);
      _loadAll();
    } catch (e) {
      _showSnack('取消失败: $e', Colors.red[700]!);
    }
  }

  // ===========================================================================
  // Tab 4: 社区 (Community)
  // ===========================================================================

  Widget _buildCommunityTab() {
    return RefreshIndicator(
      color: Colors.redAccent,
      onRefresh: _loadAll,
      child: _communityItems.isEmpty
          ? _buildEmptyState(Icons.people, '尚无社区动态', '同区域其他用户的物资供给与需求会显示在这里')
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: _communityItems.length,
              itemBuilder: (_, i) => _buildCommunityCard(_communityItems[i]),
            ),
    );
  }

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
    final actionLabel = isSupply ? '我需要' : '我想帮忙';

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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(typeLabel,
                              style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_urgencyLabel(item.urgency),
                              style: TextStyle(color: urgencyColor, fontSize: 9)),
                        ),
                        const SizedBox(width: 6),
                        Text(timeStr,
                            style: const TextStyle(color: Colors.white30, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$readableName  ${item.quantity.toInt()} 份',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description.isNotEmpty)
                      Text(item.description,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(actionLabel,
                    style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            isSupply ? '确认需求数量' : '确认提供数量',
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
                isSupply ? '您需要几份？' : '您可以提供几份？',
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
                  hintText: '数量',
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
                backgroundColor: isSupply ? Colors.orangeAccent : Colors.tealAccent,
                foregroundColor: Colors.black,
              ),
              child: Text(isSupply ? '确认需求' : '确认提供'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final qty = int.tryParse(qtyController.text) ?? 0;
    if (qty <= 0) {
      _showSnack('数量必须大于 0', Colors.red);
      return;
    }

    final loc = _locationService.currentLocation;

    try {
      if (isSupply) {
        // They have supply -> I publish request
        await _eventManager.publishRequest(
          resourceType: item.resourceType,
          quantity: qty,
          note: '回应社区供给',
          maxRangeMeters: 5000,
          mobilityMode: 'CAN_GO',
          lat: loc?.latitude,
          lng: loc?.longitude,
        );
      } else {
        // They have request -> I register supply
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
        _showSnack(
          isSupply
              ? '已发布需求 $qty 份「$readableName」'
              : '已登记供给 $qty 份「$readableName」',
          Colors.green[700]!,
        );
        _loadAll();
      }
    } catch (e) {
      _showSnack('发布失败: $e', Colors.red[700]!);
    }
  }

  // ===========================================================================
  // Shared UI helpers
  // ===========================================================================

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    // Must use ListView/CustomScrollView for RefreshIndicator to work
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white24, size: 56),
                const SizedBox(height: 14),
                Text(title, style: const TextStyle(color: Colors.white38, fontSize: 15)),
                const SizedBox(height: 6),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white24, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
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
        return '紧急求救';
      case 2:
        return '求助';
      case 1:
        return '物资';
      default:
        return '资讯';
    }
  }

  IconData _urgencyIcon(int urgency) {
    switch (urgency) {
      case 3:
        return Icons.emergency;
      case 2:
        return Icons.warning_amber;
      case 1:
        return Icons.campaign;
      default:
        return Icons.info_outline;
    }
  }

  String _formatCountdown(int expiresAtMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = expiresAtMs - now;
    if (diffMs <= 0) return '已逾期';
    final minutes = (diffMs / 60000).floor();
    final seconds = ((diffMs % 60000) / 1000).floor();
    if (minutes >= 60) {
      final hours = (minutes / 60).floor();
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  bool _isExpiringSoon(int expiresAtMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = expiresAtMs - now;
    return diffMs < 300000; // Less than 5 minutes
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
