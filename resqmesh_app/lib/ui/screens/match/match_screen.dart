import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/match_repository.dart';
import 'package:ignirelay_app/app/services/match_service.dart';
import 'package:ignirelay_app/app/services/negotiation_manager.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/screens/match/match_screen_controller.dart';
import 'package:ignirelay_app/ui/screens/match/match_screen_widgets.dart';
import 'package:ignirelay_app/ui/screens/match/match_tab_community.dart';
import 'package:ignirelay_app/ui/screens/match/match_tab_negotiations.dart';
import 'package:ignirelay_app/ui/screens/match/match_tab_requests.dart';
import 'package:ignirelay_app/ui/screens/match/match_tab_supplies.dart';
import 'package:ignirelay_app/ui/secondary/navigation_screen.dart';
import 'package:ignirelay_app/ui/secondary/supply_registration.dart';
import 'package:ignirelay_app/ui/sheets/resource_request_sheet.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

// =============================================================================
// MatchScreen — 4-tab layout following three-layer architecture
//
// Stage 2A：本檔由 god file 拆出來後改為 thin shell。data state + action handlers
// 在 [MatchScreenController]；snackbar / navigation 留在 widget 端。
// UI -> NegotiationManager (Application Layer) -> Database
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

  late final TabController _tabController;
  MatchScreenController? _c;
  StreamSubscription<MatchOutcome>? _outcomeSub;
  Timer? _countdownTimer;
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _tabController.index == 2) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initDone) {
      _initDone = true;
      _c = MatchScreenController(
        eventPublisher: context.read<EventPublisher>(),
        eventStream: context.read<EventStream>(),
        negotiationManager: context.read<NegotiationManager>(),
        repository: context.read<MatchRepository>(),
        identity: context.read<IdentityManager>(),
        locationService: context.read<LocationService>(),
      );
      _c!.init();
      _c!.attachEventStream();
      _outcomeSub = _c!.outcomes.listen(_handleOutcome);
    }
  }

  @override
  void dispose() {
    _outcomeSub?.cancel();
    _countdownTimer?.cancel();
    _tabController.dispose();
    _c?.dispose();
    super.dispose();
  }

  void _handleOutcome(MatchOutcome outcome) {
    if (!mounted) return;
    whenMatchOutcome<void>(
      outcome,
      negotiationAccepted: () => _showSnack(context.l10n.matchNegAcceptedSnack, Colors.green),
      negotiationDeclined: () => _showSnack(context.l10n.matchNegDeclinedSnack, Colors.orange),
      negotiationCancelled: () => _showSnack(context.l10n.matchNegCancelledSnack, Colors.grey),
      handoffComplete: () => _showSnack(context.l10n.matchHandoffCompleteSnack, Colors.green),
      negotiationExpired: () => _showSnack(context.l10n.matchNegExpiredSnack, Colors.orange),
      oversoldDetected: () => _showSnack(context.l10n.matchOverQuantityWarning, Colors.red),
      acceptOk: () => _showSnack(context.l10n.matchAcceptSnack, Colors.green),
      declineOk: () => _showSnack(context.l10n.matchDeclineSnack, Colors.grey),
      cancelSupplyOk: (n) => _showSnack(context.l10n.matchCancelSupplySnack(n), Colors.grey[700]!),
      cancelRequestOk: (n) => _showSnack(context.l10n.matchCancelRequestSnack(n), Colors.grey[700]!),
      acceptFail: (e) => _showSnack(context.l10n.matchAcceptFailSnack(e), Colors.red[700]!),
      declineFail: (e) => _showSnack(context.l10n.matchDeclineFailSnack(e), Colors.red[700]!),
      cancelFail: (e) => _showSnack(context.l10n.matchCancelFailSnack(e), Colors.red[700]!),
      communityRequestOk: (q, n) => _showSnack(context.l10n.matchCommunityRequestSnack(q, n), Colors.green[700]!),
      communitySupplyOk: (q, n) => _showSnack(context.l10n.matchCommunitySupplySnack(q, n), Colors.green[700]!),
      communityFail: (e) => _showSnack(context.l10n.matchCommunityFailSnack(e), Colors.red[700]!),
    );
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, duration: const Duration(seconds: 2)),
    );
  }

  void _openNavigationForNeg(Map<String, dynamic> neg) {
    final negId = neg['negotiation_id'] as String? ?? '';
    final resourceId = neg['resource_id'] as String? ?? '';

    final entry = MatchEntry(
      resourceId: resourceId,
      // enrichNegotiations 補上的顯示 / 配送 metadata（見 MatchScreenController.loadAll）。
      resourceType: neg['resource_type'] as String? ?? '',
      requestResourceType: neg['resource_type'] as String? ?? '',
      requestDesc: '',
      requestEventId: neg['request_event_id'] as String? ?? '',
      requestId: neg['request_id'] as String? ?? '',
      urgency: (neg['urgency'] as int?) ?? 0,
      identityLevel: 0,
      score: (neg['match_score'] as num?)?.toDouble() ?? 0,
      hlcTimestamp: 0,
      supplyQty: (neg['offered_qty'] as num?)?.toDouble() ?? 0,
      requestQty: (neg['requested_qty'] as num?)?.toDouble() ?? 0,
      deliveryMode: neg['delivery_mode'] as String? ?? 'PICKUP',
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

    _c!.startNavigatingIfAccepted(neg);

    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => NavigationScreen(match: entry, negotiationId: negId),
        ))
        .then((_) => _c!.loadAll());
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AnimatedBuilder(
      animation: _c!,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final p = context.igni;
    final s = context.l10n;
    final c = _c!;

    return Stack(
      children: [
        Container(
          color: p.bg0,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(IgniSpacing.xl, IgniSpacing.xl2, IgniSpacing.xl, IgniSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.matchTitle, style: IgniTypography.display(p.text0)),
                            const SizedBox(height: 4),
                            Text(
                              s.matchHeaderItemsSubtitle(c.communityItems.length),
                              style: IgniTypography.monoSmall(p.text2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                MatchTabStrip(
                  controller: _tabController,
                  items: [
                    MatchTabMeta(s.matchTabSupplies, Icons.inventory_2_outlined, c.mySupplies.length),
                    MatchTabMeta(s.matchTabRequests, Icons.campaign_outlined, c.myRequests.length, highlight: c.myRequests.isNotEmpty),
                    MatchTabMeta(s.matchTabNegotiations, Icons.sync, c.activeNegotiations.length),
                    MatchTabMeta(s.matchTabCommunity, Icons.people_alt_outlined, c.communityItems.length),
                  ],
                ),
                if (c.gpsWarning != null) _buildGpsWarningBanner(c.gpsWarning!),
                if (c.error != null) _buildErrorBanner(c.error!),
                Expanded(
                  child: c.loading && c.mySupplies.isEmpty
                      ? Center(child: CircularProgressIndicator(color: p.brand))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            MatchTabSupplies(
                              mySupplies: c.mySupplies,
                              mySupplyPublishes: c.mySupplyPublishes,
                              onRefresh: c.loadAll,
                              onShowSnack: _showSnack,
                              onCancelSupply: (supply, pub) => c.cancelSupply(
                                supply,
                                pub,
                                resourceName: getLocalizedReadableName(supply.resourceType, context),
                              ),
                              buildEmptyState: _buildEmptyState,
                            ),
                            MatchTabRequests(
                              myRequests: c.myRequests,
                              activeNegotiations: c.activeNegotiations,
                              onRefresh: c.loadAll,
                              onShowSnack: _showSnack,
                              onAcceptNegotiation: c.acceptNegotiation,
                              onDeclineNegotiation: c.declineNegotiation,
                              onCancelRequest: (req) => c.cancelRequest(
                                req,
                                resourceName: getLocalizedReadableName(req.resourceType, context),
                              ),
                              buildEmptyState: _buildEmptyState,
                              formatCountdown: _formatCountdown,
                              isExpiringSoon: _isExpiringSoon,
                              urgencyColor: _urgencyColor,
                              urgencyLabel: _urgencyLabel,
                              urgencyIcon: _urgencyIcon,
                            ),
                            MatchTabNegotiations(
                              activeNegotiations: c.activeNegotiations,
                              myPubKey: c.myPubKey,
                              staleNegotiationIds: c.staleNegotiationIds,
                              onRefresh: c.loadAll,
                              onShowSnack: _showSnack,
                              onAcceptNegotiation: c.acceptNegotiation,
                              onDeclineNegotiation: c.declineNegotiation,
                              onCancelNegotiation: c.cancelNegotiation,
                              onOpenNavigation: _openNavigationForNeg,
                              buildEmptyState: _buildEmptyState,
                              formatCountdown: _formatCountdown,
                              isExpiringSoon: _isExpiringSoon,
                            ),
                            MatchTabCommunity(
                              communityItems: c.communityItems,
                              onRefresh: c.loadAll,
                              onShowSnack: _showSnack,
                              onCommunityAction: (item, qty) => c.communityAction(
                                item,
                                qty,
                                resourceName: getLocalizedReadableName(item.resourceType, context),
                                communityNote: context.l10n.matchCommunityNote,
                              ),
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
        Positioned(
          right: IgniSpacing.xl,
          bottom: IgniSpacing.bottomTabBarHeight + IgniSpacing.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              MatchOutlineFab(
                color: p.sos,
                bg: p.bg1,
                icon: Icons.campaign_outlined,
                label: s.matchFabPublishRequest,
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ResourceRequestScreen()))
                      .then((_) => c.loadAll());
                },
              ),
              const SizedBox(height: IgniSpacing.sm),
              MatchBrandFab(
                color: p.brand,
                icon: Icons.add,
                label: s.matchFabRegisterSupply,
                onTap: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SupplyRegistrationScreen()))
                      .then((_) => c.loadAll());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGpsWarningBanner(String warning) {
    final p = context.igni;
    final locService = context.read<LocationService>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.lg, vertical: IgniSpacing.sm),
      color: p.warnSoft,
      child: Row(
        children: [
          Icon(Icons.location_off, color: p.warn, size: 18),
          const SizedBox(width: IgniSpacing.sm),
          Expanded(child: Text(warning, style: IgniTypography.bodySmall(p.text1))),
          TextButton(
            onPressed: locService.permDeniedForever ? Geolocator.openAppSettings : Geolocator.openLocationSettings,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.sm),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              locService.permDeniedForever ? context.l10n.matchGpsOpenSettings : context.l10n.matchGpsEnableLocation,
              style: IgniTypography.labelSmall(p.warn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    final p = context.igni;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.lg, vertical: IgniSpacing.sm),
      color: p.sosSoft,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: p.sos, size: 18),
          const SizedBox(width: IgniSpacing.sm),
          Expanded(child: Text(context.l10n.matchLoadError(error), style: IgniTypography.bodySmall(p.text1))),
          TextButton(
            onPressed: _c!.loadAll,
            child: Text(context.l10n.matchRetry, style: IgniTypography.labelSmall(p.sos)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    final p = context.igni;
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
                  padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.xl2),
                  child: Text(subtitle, textAlign: TextAlign.center, style: IgniTypography.bodySmall(p.text2)),
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
      case 3: return Colors.red;
      case 2: return Colors.orange;
      case 1: return Colors.green;
      default: return Colors.blue;
    }
  }

  String _urgencyLabel(int urgency) {
    switch (urgency) {
      case 3: return context.l10n.matchUrgencyEmergency;
      case 2: return context.l10n.matchUrgencyHelp;
      case 1: return context.l10n.matchUrgencySupply;
      default: return context.l10n.matchUrgencyInfo;
    }
  }

  IconData _urgencyIcon(int urgency) {
    switch (urgency) {
      case 3: return Icons.emergency;
      case 2: return Icons.warning_amber;
      case 1: return Icons.campaign;
      default: return Icons.info_outline;
    }
  }

  String _formatCountdown(int expiresAtMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = expiresAtMs - now;
    if (diffMs <= 0) return context.l10n.matchCountdownExpired;
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
    return diffMs < 300000;
  }
}
