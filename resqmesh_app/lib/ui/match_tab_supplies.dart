import 'package:flutter/material.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/app/services/match_repository.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';

/// Tab 1: 我的物資 (My Supplies)
class MatchTabSupplies extends StatelessWidget {
  final List<DecodedSupply> mySupplies;
  final List<MyPublish> mySupplyPublishes;
  final Future<void> Function() onRefresh;
  final void Function(String msg, Color bg) onShowSnack;
  final Future<void> Function(DecodedSupply supply, MyPublish? pub) onCancelSupply;
  final Widget Function(IconData icon, String title, String subtitle) buildEmptyState;

  const MatchTabSupplies({
    super.key,
    required this.mySupplies,
    required this.mySupplyPublishes,
    required this.onRefresh,
    required this.onShowSnack,
    required this.onCancelSupply,
    required this.buildEmptyState,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Colors.redAccent,
      onRefresh: onRefresh,
      child: mySupplies.isEmpty
          ? buildEmptyState(Icons.inventory_2, S.of(context)!.suppliesEmptyTitle, S.of(context)!.suppliesEmptySubtitle)
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: mySupplies.length,
              itemBuilder: (_, i) => _buildSupplyCard(context, mySupplies[i]),
            ),
    );
  }

  Widget _buildSupplyCard(BuildContext context, DecodedSupply supply) {
    final readableName = getLocalizedReadableName(supply.resourceType, context);
    final totalQty = supply.quantity.toInt();
    final availQty = supply.availableQty.toInt();
    final committedQty = totalQty - availQty;

    Color statusColor;
    String statusLabel;
    if (availQty <= 0) {
      statusColor = Colors.red;
      statusLabel = S.of(context)!.suppliesStatusExhausted;
    } else if (committedQty > 0) {
      statusColor = Colors.orange;
      statusLabel = S.of(context)!.suppliesStatusPartial;
    } else {
      statusColor = Colors.green;
      statusLabel = S.of(context)!.suppliesStatusAvailable;
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
                        supply.deliveryMode == 'DELIVER' ? S.of(context)!.suppliesDeliveryDeliver : S.of(context)!.suppliesDeliveryPickup,
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
                _buildQtyChip(S.of(context)!.suppliesQtyTotal, '$totalQty ${supply.unit}', Colors.white54),
                const SizedBox(width: 8),
                _buildQtyChip(S.of(context)!.suppliesQtyAvailable, '$availQty ${supply.unit}', Colors.greenAccent),
                const SizedBox(width: 8),
                if (committedQty > 0)
                  _buildQtyChip(S.of(context)!.suppliesQtyCommitted, '$committedQty ${supply.unit}', Colors.orange),
              ],
            ),
            const SizedBox(height: 8),
            // Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cancelSupply(context, supply),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                  label: Text(S.of(context)!.suppliesCancelButton, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
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

  Future<void> _cancelSupply(BuildContext context, DecodedSupply supply) async {
    final readableName = getLocalizedReadableName(supply.resourceType, context);

    // Find the eventId from MyPublish data
    final pub = mySupplyPublishes.where((p) =>
        p.title == supply.resourceType).firstOrNull;
    if (pub == null) {
      onShowSnack(S.of(context)!.suppliesNotFoundSnack, Colors.orange);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(S.of(ctx)!.suppliesCancelDialogTitle, style: const TextStyle(color: Colors.white)),
        content: Text(
          S.of(ctx)!.suppliesCancelDialogContent(readableName),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx)!.suppliesCancelDialogBack),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(ctx)!.suppliesCancelDialogConfirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await onCancelSupply(supply, pub);
  }
}
