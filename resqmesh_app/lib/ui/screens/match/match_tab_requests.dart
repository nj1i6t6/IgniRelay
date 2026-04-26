import 'package:flutter/material.dart';
import 'package:ignirelay_app/app/services/match_repository.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// Tab 2: 我的需求 (My Requests)
class MatchTabRequests extends StatelessWidget {
  final List<DecodedRequest> myRequests;
  final List<Map<String, dynamic>> activeNegotiations;
  final Future<void> Function() onRefresh;
  final void Function(String msg, Color bg) onShowSnack;
  final Future<void> Function(Map<String, dynamic> neg) onAcceptNegotiation;
  final Future<void> Function(String negId, Map<String, dynamic> neg) onDeclineNegotiation;
  final Future<void> Function(DecodedRequest request) onCancelRequest;
  final Widget Function(IconData icon, String title, String subtitle) buildEmptyState;
  final String Function(int expiresAtMs) formatCountdown;
  final bool Function(int expiresAtMs) isExpiringSoon;
  final Color Function(int urgency) urgencyColor;
  final String Function(int urgency) urgencyLabel;
  final IconData Function(int urgency) urgencyIcon;

  const MatchTabRequests({
    super.key,
    required this.myRequests,
    required this.activeNegotiations,
    required this.onRefresh,
    required this.onShowSnack,
    required this.onAcceptNegotiation,
    required this.onDeclineNegotiation,
    required this.onCancelRequest,
    required this.buildEmptyState,
    required this.formatCountdown,
    required this.isExpiringSoon,
    required this.urgencyColor,
    required this.urgencyLabel,
    required this.urgencyIcon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return RefreshIndicator(
      color: p.brand,
      backgroundColor: p.bg2,
      onRefresh: onRefresh,
      child: myRequests.isEmpty
          ? buildEmptyState(Icons.campaign, context.l10n.requestsEmptyTitle, context.l10n.requestsEmptySubtitle)
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: myRequests.length,
              itemBuilder: (_, i) => _buildRequestCard(context, myRequests[i]),
            ),
    );
  }

  Widget _buildRequestCard(BuildContext context, DecodedRequest request) {
    final p = context.igni;
    final readableName = getLocalizedReadableName(request.resourceType, context);
    final totalQty = request.quantityNeeded.toInt();
    final remaining = request.remainingNeed.toInt();
    final fulfilled = totalQty - remaining;

    Color statusColor;
    String statusLabel;
    if (request.status == 'MATCHED') {
      statusColor = p.info;
      statusLabel = context.l10n.requestsStatusMatching;
    } else if (remaining <= 0) {
      statusColor = p.ok;
      statusLabel = context.l10n.requestsStatusFulfilled;
    } else {
      statusColor = p.warn;
      statusLabel = context.l10n.requestsStatusWaiting;
    }

    // Find incoming proposals for this request
    final incomingForThis = activeNegotiations.where((n) {
      final reqId = n['request_id'] as String? ?? '';
      final initiatorRole = n['initiator_role'] as String? ?? '';
      final status = n['status'] as String? ?? '';
      return reqId == request.requestId && initiatorRole == 'PROVIDER' && status == 'PENDING';
    }).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: p.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: p.warn.withValues(alpha: 0.3)),
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
                    color: p.warnSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    urgencyIcon(request.urgency),
                    color: urgencyColor(request.urgency),
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
                              color: urgencyColor(request.urgency).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(urgencyLabel(request.urgency),
                                style: TextStyle(
                                    color: urgencyColor(request.urgency),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(readableName,
                                style: TextStyle(color: p.text0, fontSize: 14, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (request.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(request.note,
                              style: TextStyle(color: p.text3, fontSize: 11),
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
                _buildQtyChip(context.l10n.requestsQtyNeeded, '$totalQty ${context.l10n.requestsQtyUnit}', p.text2),
                const SizedBox(width: 8),
                _buildQtyChip(context.l10n.requestsQtyRemaining, '$remaining ${context.l10n.requestsQtyUnit}', remaining > 0 ? p.warn : p.ok),
                const SizedBox(width: 8),
                if (fulfilled > 0)
                  _buildQtyChip(context.l10n.requestsQtyFulfilled, '$fulfilled ${context.l10n.requestsQtyUnit}', p.ok),
              ],
            ),
            // Incoming proposals
            if (incomingForThis.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(context.l10n.requestsProposalsTitle,
                  style: TextStyle(color: p.info, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...incomingForThis.map((neg) => _buildIncomingProposal(context, neg)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cancelRequestDialog(context, request),
                  icon: Icon(Icons.cancel_outlined, size: 16, color: p.sos),
                  label: Text(context.l10n.requestsCancelButton, style: TextStyle(color: p.sos, fontSize: 12)),
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

  Widget _buildIncomingProposal(BuildContext context, Map<String, dynamic> neg) {
    final p = context.igni;
    final offeredQty = (neg['offered_qty'] as num?)?.toDouble() ?? 0;
    final expiresAt = (neg['expires_at'] as int?) ?? 0;
    final remaining = formatCountdown(expiresAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.infoSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.handshake, color: p.info, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.requestsProposalOffer(offeredQty.toInt()),
                    style: TextStyle(color: p.text0, fontSize: 12)),
                Text(context.l10n.requestsProposalRemaining(remaining),
                    style: TextStyle(
                        color: isExpiringSoon(expiresAt) ? p.sos : p.text3,
                        fontSize: 10)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => onAcceptNegotiation(neg),
            style: TextButton.styleFrom(
              backgroundColor: p.okSoft,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(context.l10n.requestsAcceptButton, style: TextStyle(color: p.ok, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () {
              final negId = neg['negotiation_id'] as String? ?? '';
              onDeclineNegotiation(negId, neg);
            },
            style: TextButton.styleFrom(
              backgroundColor: p.sosSoft,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(context.l10n.requestsDeclineButton, style: TextStyle(color: p.sos, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRequestDialog(BuildContext context, DecodedRequest request) async {
    final p = context.igni;
    final readableName = getLocalizedReadableName(request.resourceType, context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.bg2,
        title: Text(ctx.l10n.requestsCancelDialogTitle, style: TextStyle(color: p.text0)),
        content: Text(
          ctx.l10n.requestsCancelDialogContent(readableName),
          style: TextStyle(color: p.text1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.requestsCancelDialogBack),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.requestsCancelDialogConfirm, style: TextStyle(color: p.sos)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await onCancelRequest(request);
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
}
