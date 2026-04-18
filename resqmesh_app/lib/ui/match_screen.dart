import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/app/services/negotiation_manager.dart';
import 'package:ignirelay_app/app/services/negotiation_events.dart';
import 'package:ignirelay_app/app/services/match_repository.dart';
import 'package:ignirelay_app/app/services/match_service.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/ui/supply_registration.dart';
import 'package:ignirelay_app/ui/resource_request_sheet.dart';
import 'package:ignirelay_app/ui/navigation_screen.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/ui/match_tab_supplies.dart';
import 'package:ignirelay_app/ui/match_tab_requests.dart';
import 'package:ignirelay_app/ui/match_tab_negotiations.dart';
import 'package:ignirelay_app/ui/match_tab_community.dart';

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
      _showSnack(S.of(context)!.matchNegAcceptedSnack, Colors.green);
    } else if (event is NegotiationDeclined) {
      _showSnack(S.of(context)!.matchNegDeclinedSnack, Colors.orange);
    } else if (event is NegotiationCancelled) {
      _showSnack(S.of(context)!.matchNegCancelledSnack, Colors.grey);
    } else if (event is NegotiationCompleted) {
      _showSnack(S.of(context)!.matchHandoffCompleteSnack, Colors.green);
    } else if (event is NegotiationExpired) {
      _showSnack(S.of(context)!.matchNegExpiredSnack, Colors.orange);
    } else if (event is OversoldDetected) {
      _showSnack(S.of(context)!.matchOverQuantityWarning, Colors.red);
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
        title: Text(S.of(context)!.matchTitle, style: const TextStyle(color: Colors.white)),
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
            _buildTab(S.of(context)!.matchTabSupplies, Icons.inventory_2, _mySupplies.length),
            _buildTab(S.of(context)!.matchTabRequests, Icons.campaign, _myRequests.length),
            _buildTab(S.of(context)!.matchTabNegotiations, Icons.sync, _activeNegotiations.length),
            _buildTab(S.of(context)!.matchTabCommunity, Icons.people, _communityItems.length),
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
                      MatchTabSupplies(
                        mySupplies: _mySupplies,
                        mySupplyPublishes: _mySupplyPublishes,
                        onRefresh: _loadAll,
                        onShowSnack: _showSnack,
                        onCancelSupply: _handleCancelSupply,
                        buildEmptyState: _buildEmptyState,
                      ),
                      MatchTabRequests(
                        myRequests: _myRequests,
                        activeNegotiations: _activeNegotiations,
                        onRefresh: _loadAll,
                        onShowSnack: _showSnack,
                        onAcceptNegotiation: _acceptNegotiation,
                        onDeclineNegotiation: _declineNegotiation,
                        onCancelRequest: _handleCancelRequest,
                        buildEmptyState: _buildEmptyState,
                        formatCountdown: _formatCountdown,
                        isExpiringSoon: _isExpiringSoon,
                        urgencyColor: _urgencyColor,
                        urgencyLabel: _urgencyLabel,
                        urgencyIcon: _urgencyIcon,
                      ),
                      MatchTabNegotiations(
                        activeNegotiations: _activeNegotiations,
                        myPubKey: _myPubKey,
                        staleNegotiationIds: _negotiationManager.staleNegotiationIds,
                        onRefresh: _loadAll,
                        onShowSnack: _showSnack,
                        onAcceptNegotiation: _acceptNegotiation,
                        onDeclineNegotiation: _declineNegotiation,
                        onCancelNegotiation: _handleCancelNegotiation,
                        onOpenNavigation: _openNavigationForNeg,
                        buildEmptyState: _buildEmptyState,
                        formatCountdown: _formatCountdown,
                        isExpiringSoon: _isExpiringSoon,
                      ),
                      MatchTabCommunity(
                        communityItems: _communityItems,
                        onRefresh: _loadAll,
                        onShowSnack: _showSnack,
                        onCommunityAction: _handleCommunityAction,
                        buildEmptyState: _buildEmptyState,
                        urgencyColor: _urgencyColor,
                        urgencyLabel: _urgencyLabel,
                      ),
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
              label: Text(S.of(context)!.matchFabRegisterSupply, style: const TextStyle(color: Colors.white)),
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
              label: Text(S.of(context)!.matchFabPublishRequest, style: const TextStyle(color: Colors.white)),
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
              child: Text(S.of(context)!.matchGpsOpenSettings,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            )
          else
            TextButton(
              onPressed: () => Geolocator.openLocationSettings(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(S.of(context)!.matchGpsEnableLocation,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
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
            child: Text(S.of(context)!.matchLoadError(_error ?? ''),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          TextButton(
            onPressed: _loadAll,
            child: Text(S.of(context)!.matchRetry, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action handlers (delegated from tab widgets)
  // ---------------------------------------------------------------------------

  Future<void> _handleCancelSupply(DecodedSupply supply, MyPublish? pub) async {
    if (pub == null || !mounted) return;
    final readableName = getLocalizedReadableName(supply.resourceType, context);
    try {
      await _eventManager.cancelSupply(pub.eventId);
      _showSnack(S.of(context)!.matchCancelSupplySnack(readableName), Colors.grey[700]!);
      _loadAll();
    } catch (e) {
      _showSnack(S.of(context)!.matchCancelFailSnack(e.toString()), Colors.red[700]!);
    }
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
      _showSnack(S.of(context)!.matchAcceptSnack, Colors.green);
      _loadAll();
    } catch (e) {
      _showSnack(S.of(context)!.matchAcceptFailSnack(e.toString()), Colors.red[700]!);
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
      _showSnack(S.of(context)!.matchDeclineSnack, Colors.grey);
      _loadAll();
    } catch (e) {
      _showSnack(S.of(context)!.matchDeclineFailSnack(e.toString()), Colors.red[700]!);
    }
  }

  Future<void> _handleCancelRequest(DecodedRequest request) async {
    final readableName = getLocalizedReadableName(request.resourceType, context);
    try {
      await _eventManager.cancelRequest(request.eventId);
      _showSnack(S.of(context)!.matchCancelRequestSnack(readableName), Colors.grey[700]!);
      _loadAll();
    } catch (e) {
      _showSnack(S.of(context)!.matchCancelFailSnack(e.toString()), Colors.red[700]!);
    }
  }

  Future<void> _handleCancelNegotiation(Map<String, dynamic> neg) async {
    final negId = neg['negotiation_id'] as String? ?? '';
    final resourceId = neg['resource_id'] as String? ?? '';
    final requestId = neg['request_id'] as String? ?? '';

    try {
      await _eventManager.publishMatchCancel(
        negotiationId: negId,
        resourceId: resourceId,
        requestId: requestId,
        reason: 'USER_CANCELLED',
      );
      _showSnack(S.of(context)!.matchNegCancelledSnack, Colors.grey);
      _loadAll();
    } catch (e) {
      _showSnack(S.of(context)!.matchCancelFailSnack(e.toString()), Colors.red[700]!);
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

  Future<void> _handleCommunityAction(CommunityItem item, int qty) async {
    final readableName = getLocalizedReadableName(item.resourceType, context);
    final isSupply = item.isSupply;
    final loc = _locationService.currentLocation;

    try {
      if (isSupply) {
        // They have supply -> I publish request
        await _eventManager.publishRequest(
          resourceType: item.resourceType,
          quantity: qty,
          note: S.of(context)!.matchCommunityNote,
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
              ? S.of(context)!.matchCommunityRequestSnack(qty, readableName)
              : S.of(context)!.matchCommunitySupplySnack(qty, readableName),
          Colors.green[700]!,
        );
        _loadAll();
      }
    } catch (e) {
      _showSnack(S.of(context)!.matchCommunityFailSnack(e.toString()), Colors.red[700]!);
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
        return S.of(context)!.matchUrgencyEmergency;
      case 2:
        return S.of(context)!.matchUrgencyHelp;
      case 1:
        return S.of(context)!.matchUrgencySupply;
      default:
        return S.of(context)!.matchUrgencyInfo;
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
    if (diffMs <= 0) return S.of(context)!.matchCountdownExpired;
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
}
