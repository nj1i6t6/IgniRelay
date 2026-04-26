import 'package:flutter/material.dart';
import 'package:ignirelay_app/app/services/match_repository.dart';
import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// Tab 4: 社區 (Community)
class MatchTabCommunity extends StatelessWidget {
  final List<CommunityItem> communityItems;
  final Future<void> Function() onRefresh;
  final void Function(String msg, Color bg) onShowSnack;
  final Future<void> Function(CommunityItem item, int qty) onCommunityAction;
  final Widget Function(IconData icon, String title, String subtitle) buildEmptyState;
  final Color Function(int urgency) urgencyColor;
  final String Function(int urgency) urgencyLabel;

  const MatchTabCommunity({
    super.key,
    required this.communityItems,
    required this.onRefresh,
    required this.onShowSnack,
    required this.onCommunityAction,
    required this.buildEmptyState,
    required this.urgencyColor,
    required this.urgencyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return RefreshIndicator(
      color: p.brand,
      backgroundColor: p.bg2,
      onRefresh: onRefresh,
      child: communityItems.isEmpty
          ? buildEmptyState(Icons.people, context.l10n.communityEmptyTitle, context.l10n.communityEmptySubtitle)
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: communityItems.length,
              itemBuilder: (_, i) => _buildCommunityCard(context, communityItems[i]),
            ),
    );
  }

  Widget _buildCommunityCard(BuildContext context, CommunityItem item) {
    final p = context.igni;
    final time = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
    final timeStr =
        '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final readableName = getLocalizedReadableName(item.resourceType, context);
    final isSupply = item.isSupply;
    final urgColor = urgencyColor(item.urgency);

    // supply → ok 綠（有東西可給）；request → brand 琥珀（需求求助）
    final typeColor = isSupply ? p.ok : p.brand;
    final typeLabel = isSupply ? context.l10n.communityTypeSupply : context.l10n.communityTypeRequest;
    final typeIcon = isSupply ? Icons.volunteer_activism : Icons.front_hand;
    final actionLabel = isSupply ? context.l10n.communityActionNeed : context.l10n.communityActionHelp;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: p.bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: typeColor.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showCommunityResponseDialog(context, item),
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
                            color: urgColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(urgencyLabel(item.urgency),
                              style: TextStyle(color: urgColor, fontSize: 9)),
                        ),
                        const SizedBox(width: 6),
                        Text(timeStr,
                            style: TextStyle(color: p.text3, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$readableName  ${context.l10n.negQtyUnit(item.quantity.toInt())}',
                      style: TextStyle(color: p.text0, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description.isNotEmpty)
                      Text(item.description,
                          style: TextStyle(color: p.text2, fontSize: 11),
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

  Future<void> _showCommunityResponseDialog(BuildContext context, CommunityItem item) async {
    final p = context.igni;
    final readableName = getLocalizedReadableName(item.resourceType, context);
    final isSupply = item.isSupply;
    final qtyController =
        TextEditingController(text: item.quantity.toInt().toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: p.bg2,
          title: Text(
            isSupply ? ctx.l10n.communityDialogConfirmNeed : ctx.l10n.communityDialogConfirmSupply,
            style: TextStyle(color: p.text0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSupply
                    ? ctx.l10n.communityDialogSupplyInfo(readableName, item.quantity.toInt())
                    : ctx.l10n.communityDialogRequestInfo(readableName, item.quantity.toInt()),
                style: TextStyle(color: p.text1, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                isSupply ? ctx.l10n.communityDialogHowManyNeed : ctx.l10n.communityDialogHowManySupply,
                style: TextStyle(color: p.text0, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: p.text0, fontSize: 18),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: p.bg3,
                  hintText: ctx.l10n.communityDialogQtyHint,
                  hintStyle: TextStyle(color: p.text3),
                  suffixText: ctx.l10n.communityDialogQtySuffix,
                  suffixStyle: TextStyle(color: p.text2),
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
              child: Text(ctx.l10n.communityDialogCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: isSupply ? p.brand : p.ok,
                foregroundColor: p.bg0,
              ),
              child: Text(isSupply ? ctx.l10n.communityDialogConfirmNeedButton : ctx.l10n.communityDialogConfirmSupplyButton),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final qty = int.tryParse(qtyController.text) ?? 0;
    if (qty <= 0) {
      onShowSnack(context.l10n.communityDialogQtyError, p.sos);
      return;
    }

    await onCommunityAction(item, qty);
  }
}
