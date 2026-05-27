import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// Tab 3: 進行中 (Active Negotiations)
class MatchTabNegotiations extends StatelessWidget {
  final List<Map<String, dynamic>> activeNegotiations;
  final Uint8List? myPubKey;
  final Set<String> staleNegotiationIds;
  final Future<void> Function() onRefresh;
  final void Function(String msg, Color bg) onShowSnack;
  final Future<void> Function(Map<String, dynamic> neg) onAcceptNegotiation;
  final Future<void> Function(String negId, Map<String, dynamic> neg) onDeclineNegotiation;
  final Future<void> Function(Map<String, dynamic> neg) onCancelNegotiation;
  final void Function(Map<String, dynamic> neg) onOpenNavigation;
  final Widget Function(IconData icon, String title, String subtitle) buildEmptyState;
  final String Function(int expiresAtMs) formatCountdown;
  final bool Function(int expiresAtMs) isExpiringSoon;

  const MatchTabNegotiations({
    super.key,
    required this.activeNegotiations,
    required this.myPubKey,
    required this.staleNegotiationIds,
    required this.onRefresh,
    required this.onShowSnack,
    required this.onAcceptNegotiation,
    required this.onDeclineNegotiation,
    required this.onCancelNegotiation,
    required this.onOpenNavigation,
    required this.buildEmptyState,
    required this.formatCountdown,
    required this.isExpiringSoon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return RefreshIndicator(
      color: p.brand,
      backgroundColor: p.bg2,
      onRefresh: onRefresh,
      child: activeNegotiations.isEmpty
          ? buildEmptyState(Icons.sync, context.l10n.negEmptyTitle, context.l10n.negEmptySubtitle)
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: activeNegotiations.length,
              itemBuilder: (_, i) => _buildNegotiationCard(context, activeNegotiations[i]),
            ),
    );
  }

  Widget _buildNegotiationCard(BuildContext context, Map<String, dynamic> neg) {
    final p = context.igni;
    final negId = neg['negotiation_id'] as String? ?? '';
    final status = neg['status'] as String? ?? 'PENDING';
    final offeredQty = (neg['offered_qty'] as num?)?.toDouble() ?? 0;
    final requestedQty = (neg['requested_qty'] as num?)?.toDouble() ?? 0;
    final expiresAt = (neg['expires_at'] as int?) ?? 0;
    final matchScore = (neg['match_score'] as num?)?.toDouble();

    // 物資名稱：Match_Negotiations 不含 resourceType，由 enrichNegotiations 補進
    // 'resource_type'。多筆協商同時進行時，這是分辨「在媒合什麼」的關鍵。
    final resourceTypeCode = neg['resource_type'] as String? ?? '';
    final resourceName = resourceTypeCode.isNotEmpty
        ? getLocalizedReadableName(resourceTypeCode, context)
        : '—';

    // Determine my role
    final providerKey = neg['provider_pub_key'] as Uint8List?;
    final isProvider = myPubKey != null && providerKey != null &&
        _bytesEqual(myPubKey!, providerKey);
    final counterpartLabel = isProvider ? context.l10n.negRoleRequester : context.l10n.negRoleProvider;

    // Status styling — 語意色 tokens
    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'PENDING':
        statusColor = p.warn;
        statusIcon = Icons.hourglass_empty;
        statusLabel = context.l10n.negStatusPending;
        break;
      case 'ACCEPTED':
        statusColor = p.ok;
        statusIcon = Icons.check_circle;
        statusLabel = context.l10n.negStatusAccepted;
        break;
      case 'NAVIGATING':
        statusColor = p.info;
        statusIcon = Icons.navigation;
        statusLabel = context.l10n.negStatusNavigating;
        break;
      default:
        statusColor = p.text3;
        statusIcon = Icons.help_outline;
        statusLabel = status;
    }

    final qty = offeredQty > 0 ? offeredQty : requestedQty;
    final countdown = formatCountdown(expiresAt);
    final isStale = staleNegotiationIds.contains(negId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: p.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isStale
                ? p.sos.withValues(alpha: 0.5)
                : statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 物資名稱（讓多筆協商可分辨在媒合什麼）
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: p.text2, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    resourceName,
                    style: TextStyle(
                        color: p.text0,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                  Text('${matchScore.toStringAsFixed(0)} ${context.l10n.negScoreUnit}',
                      style: TextStyle(color: p.warn, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            // Qty and role info
            Row(
              children: [
                Icon(Icons.swap_horiz, color: p.text3, size: 16),
                const SizedBox(width: 6),
                Text(context.l10n.negQtyUnit(qty.toInt()),
                    style: TextStyle(color: p.text0, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isProvider ? p.ok : p.brand).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isProvider ? context.l10n.negRoleMeProvider : context.l10n.negRoleMeRequester,
                    style: TextStyle(
                        color: isProvider ? p.ok : p.brand,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(counterpartLabel,
                    style: TextStyle(color: p.text3, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            // Countdown timer
            Row(
              children: [
                Icon(Icons.timer,
                    size: 14,
                    color: isExpiringSoon(expiresAt) ? p.sos : p.text3),
                const SizedBox(width: 4),
                Text(
                  countdown,
                  style: TextStyle(
                    color: isExpiringSoon(expiresAt) ? p.sos : p.text3,
                    fontSize: 11,
                    fontWeight: isExpiringSoon(expiresAt) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isStale) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.sosSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(context.l10n.negStaleLabel,
                        style: TextStyle(color: p.sos, fontSize: 10, fontWeight: FontWeight.bold)),
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
                    onPressed: () => onAcceptNegotiation(neg),
                    style: TextButton.styleFrom(
                      backgroundColor: p.okSoft,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Text(context.l10n.requestsAcceptButton, style: TextStyle(color: p.ok, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => onDeclineNegotiation(negId, neg),
                    style: TextButton.styleFrom(
                      backgroundColor: p.sosSoft,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Text(context.l10n.requestsDeclineButton, style: TextStyle(color: p.sos, fontSize: 12)),
                  ),
                ],
                // Navigate button for ACCEPTED/NAVIGATING
                if (status == 'ACCEPTED' || status == 'NAVIGATING') ...[
                  TextButton.icon(
                    onPressed: () => onOpenNavigation(neg),
                    icon: Icon(Icons.map, size: 16, color: p.info),
                    label: Text(context.l10n.negViewMapButton, style: TextStyle(color: p.info, fontSize: 12)),
                    style: TextButton.styleFrom(
                      backgroundColor: p.infoSoft,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Cancel button (always available for active)
                TextButton(
                  onPressed: () => _cancelNegotiationDialog(context, neg),
                  style: TextButton.styleFrom(
                    backgroundColor: p.sos.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text(context.l10n.negCancelButton, style: TextStyle(color: p.sos, fontSize: 12)),
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
      return myPubKey != null && requesterKey != null && _bytesEqual(myPubKey!, requesterKey);
    } else {
      // Initiator is requester, I need to be the provider to respond
      final providerKey = neg['provider_pub_key'] as Uint8List?;
      return myPubKey != null && providerKey != null && _bytesEqual(myPubKey!, providerKey);
    }
  }

  Future<void> _cancelNegotiationDialog(BuildContext context, Map<String, dynamic> neg) async {
    final p = context.igni;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.bg2,
        title: Text(ctx.l10n.negCancelDialogTitle, style: TextStyle(color: p.text0)),
        content: Text(ctx.l10n.negCancelDialogContent, style: TextStyle(color: p.text1)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.negCancelDialogBack),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.negCancelDialogConfirm, style: TextStyle(color: p.sos)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await onCancelNegotiation(neg);
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
