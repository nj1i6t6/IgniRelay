import 'package:flutter/material.dart';
import 'package:ignirelay_app/app/services/match_repository.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

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
    final p = context.igni;
    return RefreshIndicator(
      color: p.brand,
      backgroundColor: p.bg2,
      onRefresh: onRefresh,
      child: mySupplies.isEmpty
          ? buildEmptyState(Icons.inventory_2, context.l10n.suppliesEmptyTitle, context.l10n.suppliesEmptySubtitle)
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: mySupplies.length,
              itemBuilder: (_, i) => _buildSupplyCard(context, mySupplies[i]),
            ),
    );
  }

  Widget _buildSupplyCard(BuildContext context, DecodedSupply supply) {
    final p = context.igni;
    final readableName = getLocalizedReadableName(supply.resourceType, context);
    final totalQty = supply.quantity.toInt();
    final availQty = supply.availableQty.toInt();
    final committedQty = totalQty - availQty;

    Color statusColor;
    String statusLabel;
    if (availQty <= 0) {
      statusColor = p.sos;
      statusLabel = context.l10n.suppliesStatusExhausted;
    } else if (committedQty > 0) {
      statusColor = p.warn;
      statusLabel = context.l10n.suppliesStatusPartial;
    } else {
      statusColor = p.ok;
      statusLabel = context.l10n.suppliesStatusAvailable;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: p.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: p.ok.withValues(alpha: 0.3)),
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
                    color: p.okSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.inventory_2, color: p.ok, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(readableName,
                          style: TextStyle(color: p.text0, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        supply.deliveryMode == 'DELIVER' ? context.l10n.suppliesDeliveryDeliver : context.l10n.suppliesDeliveryPickup,
                        style: TextStyle(color: p.text3, fontSize: 11),
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
                _buildQtyChip(context.l10n.suppliesQtyTotal, '$totalQty ${supply.unit}', p.text2),
                const SizedBox(width: 8),
                _buildQtyChip(context.l10n.suppliesQtyAvailable, '$availQty ${supply.unit}', p.ok),
                const SizedBox(width: 8),
                if (committedQty > 0)
                  _buildQtyChip(context.l10n.suppliesQtyCommitted, '$committedQty ${supply.unit}', p.warn),
              ],
            ),
            const SizedBox(height: 8),
            // Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cancelSupply(context, supply),
                  icon: Icon(Icons.cancel_outlined, size: 16, color: p.sos),
                  label: Text(context.l10n.suppliesCancelButton, style: TextStyle(color: p.sos, fontSize: 12)),
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
    final p = context.igni;
    final readableName = getLocalizedReadableName(supply.resourceType, context);

    // Find the eventId from MyPublish data
    final pub = mySupplyPublishes.where((pb) =>
        pb.title == supply.resourceType).firstOrNull;
    if (pub == null) {
      onShowSnack(context.l10n.suppliesNotFoundSnack, p.warn);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.bg2,
        title: Text(ctx.l10n.suppliesCancelDialogTitle, style: TextStyle(color: p.text0)),
        content: Text(
          ctx.l10n.suppliesCancelDialogContent(readableName),
          style: TextStyle(color: p.text1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.suppliesCancelDialogBack),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.suppliesCancelDialogConfirm, style: TextStyle(color: p.sos)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await onCancelSupply(supply, pub);
  }
}
