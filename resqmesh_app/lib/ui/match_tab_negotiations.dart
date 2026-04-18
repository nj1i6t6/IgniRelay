import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';

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
    return RefreshIndicator(
      color: Colors.redAccent,
      onRefresh: onRefresh,
      child: activeNegotiations.isEmpty
          ? buildEmptyState(Icons.sync, S.of(context)!.negEmptyTitle, S.of(context)!.negEmptySubtitle)
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: activeNegotiations.length,
              itemBuilder: (_, i) => _buildNegotiationCard(context, activeNegotiations[i]),
            ),
    );
  }

  Widget _buildNegotiationCard(BuildContext context, Map<String, dynamic> neg) {
    final negId = neg['negotiation_id'] as String? ?? '';
    final status = neg['status'] as String? ?? 'PENDING';
    final offeredQty = (neg['offered_qty'] as num?)?.toDouble() ?? 0;
    final requestedQty = (neg['requested_qty'] as num?)?.toDouble() ?? 0;
    final expiresAt = (neg['expires_at'] as int?) ?? 0;
    final matchScore = (neg['match_score'] as num?)?.toDouble();

    // Determine my role
    final providerKey = neg['provider_pub_key'] as Uint8List?;
    final isProvider = myPubKey != null && providerKey != null &&
        _bytesEqual(myPubKey!, providerKey);
    final counterpartLabel = isProvider ? S.of(context)!.negRoleRequester : S.of(context)!.negRoleProvider;

    // Status styling
    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'PENDING':
        statusColor = Colors.amber;
        statusIcon = Icons.hourglass_empty;
        statusLabel = S.of(context)!.negStatusPending;
        break;
      case 'ACCEPTED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = S.of(context)!.negStatusAccepted;
        break;
      case 'NAVIGATING':
        statusColor = Colors.blue;
        statusIcon = Icons.navigation;
        statusLabel = S.of(context)!.negStatusNavigating;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusLabel = status;
    }

    final qty = offeredQty > 0 ? offeredQty : requestedQty;
    final countdown = formatCountdown(expiresAt);
    final isStale = staleNegotiationIds.contains(negId);

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
                  Text('${matchScore.toStringAsFixed(0)} ${S.of(context)!.negScoreUnit}',
                      style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            // Qty and role info
            Row(
              children: [
                const Icon(Icons.swap_horiz, color: Colors.white38, size: 16),
                const SizedBox(width: 6),
                Text(S.of(context)!.negQtyUnit(qty.toInt()),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isProvider ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isProvider ? S.of(context)!.negRoleMeProvider : S.of(context)!.negRoleMeRequester,
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
                    color: isExpiringSoon(expiresAt) ? Colors.redAccent : Colors.white38),
                const SizedBox(width: 4),
                Text(
                  countdown,
                  style: TextStyle(
                    color: isExpiringSoon(expiresAt) ? Colors.redAccent : Colors.white38,
                    fontSize: 11,
                    fontWeight: isExpiringSoon(expiresAt) ? FontWeight.bold : FontWeight.normal,
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
                    child: Text(S.of(context)!.negStaleLabel,
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
                    onPressed: () => onAcceptNegotiation(neg),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Text(S.of(context)!.requestsAcceptButton, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => onDeclineNegotiation(negId, neg),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Text(S.of(context)!.requestsDeclineButton, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
                // Navigate button for ACCEPTED/NAVIGATING
                if (status == 'ACCEPTED' || status == 'NAVIGATING') ...[
                  TextButton.icon(
                    onPressed: () => onOpenNavigation(neg),
                    icon: const Icon(Icons.map, size: 16, color: Colors.cyanAccent),
                    label: Text(S.of(context)!.negViewMapButton, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.cyan.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Cancel button (always available for active)
                TextButton(
                  onPressed: () => _cancelNegotiationDialog(context, neg),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text(S.of(context)!.negCancelButton, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(S.of(ctx)!.negCancelDialogTitle, style: const TextStyle(color: Colors.white)),
        content: Text(S.of(ctx)!.negCancelDialogContent, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx)!.negCancelDialogBack),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(ctx)!.negCancelDialogConfirm, style: const TextStyle(color: Colors.red)),
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
