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
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/ui/secondary/supply_registration.dart';
import 'package:ignirelay_app/ui/sheets/resource_request_sheet.dart';
import 'package:ignirelay_app/ui/secondary/navigation_screen.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/ui/screens/match/match_tab_supplies.dart';
import 'package:ignirelay_app/ui/screens/match/match_tab_requests.dart';
import 'package:ignirelay_app/ui/screens/match/match_tab_negotiations.dart';
import 'package:ignirelay_app/ui/screens/match/match_tab_community.dart';

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
    final p = context.igni;
    final s = S.of(context)!;

    return Stack(
      children: [
        Container(
          color: p.bg0,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── 頁首 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IgniSpacing.xl,
                    IgniSpacing.xl2,
                    IgniSpacing.xl,
                    IgniSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.matchTitle,
                                style: IgniTypography.display(p.text0)),
                            const SizedBox(height: 4),
                            Text(
                              '${_communityItems.length} 項社區資源',
                              style: IgniTypography.monoSmall(p.text2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Tabs ──
                _MatchTabStrip(
                  controller: _tabController,
                  items: [
                    _TabMeta(s.matchTabSupplies, Icons.inventory_2_outlined,
                        _mySupplies.length),
                    _TabMeta(s.matchTabRequests, Icons.campaign_outlined,
                        _myRequests.length,
                        highlight: _myRequests.isNotEmpty),
                    _TabMeta(s.matchTabNegotiations, Icons.sync,
                        _activeNegotiations.length),
                    _TabMeta(s.matchTabCommunity, Icons.people_alt_outlined,
                        _communityItems.length),
                  ],
                ),
                if (_gpsWarning != null) _buildGpsWarningBanner(),
                if (_error != null) _buildErrorBanner(),
                Expanded(
                  child: _loading && _mySupplies.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(color: p.brand),
                        )
                      : TabBarView(
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
                              staleNegotiationIds:
                                  _negotiationManager.staleNegotiationIds,
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
          ),
        ),
        // ── Floating actions（雙按鈕：需求 outline / 供給 brand glow）──
        Positioned(
          right: IgniSpacing.xl,
          bottom: IgniSpacing.bottomTabBarHeight + IgniSpacing.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _OutlineFab(
                color: p.sos,
                bg: p.bg1,
                icon: Icons.campaign_outlined,
                label: s.matchFabPublishRequest,
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => const ResourceRequestScreen()))
                      .then((_) => _loadAll());
                },
              ),
              const SizedBox(height: IgniSpacing.sm),
              _BrandFab(
                color: p.brand,
                icon: Icons.add,
                label: s.matchFabRegisterSupply,
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => const SupplyRegistrationScreen()))
                      .then((_) => _loadAll());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // GPS Warning
  // ---------------------------------------------------------------------------

  Widget _buildGpsWarningBanner() {
    final p = context.igni;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: IgniSpacing.lg, vertical: IgniSpacing.sm),
      color: p.warnSoft,
      child: Row(
        children: [
          Icon(Icons.location_off, color: p.warn, size: 18),
          const SizedBox(width: IgniSpacing.sm),
          Expanded(
            child: Text(
              _gpsWarning ?? '',
              style: IgniTypography.bodySmall(p.text1),
            ),
          ),
          TextButton(
            onPressed: _locationService.permDeniedForever
                ? Geolocator.openAppSettings
                : Geolocator.openLocationSettings,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.sm),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _locationService.permDeniedForever
                  ? S.of(context)!.matchGpsOpenSettings
                  : S.of(context)!.matchGpsEnableLocation,
              style: IgniTypography.labelSmall(p.warn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    final p = context.igni;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: IgniSpacing.lg, vertical: IgniSpacing.sm),
      color: p.sosSoft,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: p.sos, size: 18),
          const SizedBox(width: IgniSpacing.sm),
          Expanded(
            child: Text(S.of(context)!.matchLoadError(_error ?? ''),
                style: IgniTypography.bodySmall(p.text1)),
          ),
          TextButton(
            onPressed: _loadAll,
            child: Text(S.of(context)!.matchRetry,
                style: IgniTypography.labelSmall(p.sos)),
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
    final p = context.igni;
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
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: p.bg2,
                    borderRadius: const BorderRadius.all(IgniRadii.xl),
                  ),
                  child: Icon(icon, color: p.text3, size: 28),
                ),
                const SizedBox(height: IgniSpacing.md),
                Text(title, style: IgniTypography.titleMedium(p.text1)),
                const SizedBox(height: IgniSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: IgniSpacing.xl2),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: IgniTypography.bodySmall(p.text2),
                  ),
                ),
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

// ─────────────────────────── Tab strip ───────────────────────────

class _TabMeta {
  _TabMeta(this.label, this.icon, this.count, {this.highlight = false});
  final String label;
  final IconData icon;
  final int count;
  final bool highlight;
}

class _MatchTabStrip extends StatefulWidget {
  const _MatchTabStrip({required this.controller, required this.items});
  final TabController controller;
  final List<_TabMeta> items;

  @override
  State<_MatchTabStrip> createState() => _MatchTabStripState();
}

class _MatchTabStripState extends State<_MatchTabStrip> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final idx = widget.controller.index;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border0)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: IgniSpacing.lg, vertical: 4),
      child: Row(
        children: List.generate(widget.items.length, (i) {
          final t = widget.items[i];
          final active = idx == i;
          final pillBg = t.highlight
              ? p.sos
              : (active ? p.brandSoft : p.bg2);
          final pillFg = t.highlight
              ? Colors.white
              : (active ? p.brand : p.text2);
          return Expanded(
            child: InkWell(
              onTap: () => widget.controller.animateTo(i),
              borderRadius: const BorderRadius.all(IgniRadii.sm),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            t.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.w500,
                              color: active ? p.text0 : p.text2,
                            ),
                          ),
                        ),
                        if (t.count > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: pillBg,
                              borderRadius:
                                  const BorderRadius.all(IgniRadii.xs),
                            ),
                            child: Text(
                              '${t.count}',
                              style: IgniTypography.monoSmall(pillFg)
                                  .copyWith(fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (active)
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: -5,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: p.brand,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────── Floating actions ───────────────────────────

class _BrandFab extends StatelessWidget {
  const _BrandFab({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(IgniRadii.pill),
          boxShadow: IgniShadows.brandGlow(color),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(IgniRadii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineFab extends StatelessWidget {
  const _OutlineFab({
    required this.color,
    required this.bg,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Color color;
  final Color bg;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(IgniRadii.pill),
          border: Border.all(color: color, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(IgniRadii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
