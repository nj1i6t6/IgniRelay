import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/match_repository.dart';
import 'supply_category_data.dart';

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
    return RefreshIndicator(
      color: Colors.redAccent,
      onRefresh: onRefresh,
      child: communityItems.isEmpty
          ? buildEmptyState(Icons.people, S.of(context)!.communityEmptyTitle, S.of(context)!.communityEmptySubtitle)
          : ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 140),
              itemCount: communityItems.length,
              itemBuilder: (_, i) => _buildCommunityCard(context, communityItems[i]),
            ),
    );
  }

  Widget _buildCommunityCard(BuildContext context, CommunityItem item) {
    final time = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
    final timeStr =
        '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final readableName = getLocalizedReadableName(item.resourceType, context);
    final isSupply = item.isSupply;
    final urgColor = urgencyColor(item.urgency);

    final typeColor = isSupply ? Colors.tealAccent : Colors.orangeAccent;
    final typeLabel = isSupply ? S.of(context)!.communityTypeSupply : S.of(context)!.communityTypeRequest;
    final typeIcon = isSupply ? Icons.volunteer_activism : Icons.front_hand;
    final actionLabel = isSupply ? S.of(context)!.communityActionNeed : S.of(context)!.communityActionHelp;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFF12122a),
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
                            style: const TextStyle(color: Colors.white30, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$readableName  ${S.of(context)!.negQtyUnit(item.quantity.toInt())}',
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

  Future<void> _showCommunityResponseDialog(BuildContext context, CommunityItem item) async {
    final readableName = getLocalizedReadableName(item.resourceType, context);
    final isSupply = item.isSupply;
    final qtyController =
        TextEditingController(text: item.quantity.toInt().toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: Text(
            isSupply ? S.of(ctx)!.communityDialogConfirmNeed : S.of(ctx)!.communityDialogConfirmSupply,
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSupply
                    ? S.of(ctx)!.communityDialogSupplyInfo(readableName, item.quantity.toInt())
                    : S.of(ctx)!.communityDialogRequestInfo(readableName, item.quantity.toInt()),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                isSupply ? S.of(ctx)!.communityDialogHowManyNeed : S.of(ctx)!.communityDialogHowManySupply,
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
                  hintText: S.of(ctx)!.communityDialogQtyHint,
                  hintStyle: const TextStyle(color: Colors.white30),
                  suffixText: S.of(ctx)!.communityDialogQtySuffix,
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
              child: Text(S.of(ctx)!.communityDialogCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: isSupply ? Colors.orangeAccent : Colors.tealAccent,
                foregroundColor: Colors.black,
              ),
              child: Text(isSupply ? S.of(ctx)!.communityDialogConfirmNeedButton : S.of(ctx)!.communityDialogConfirmSupplyButton),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final qty = int.tryParse(qtyController.text) ?? 0;
    if (qty <= 0) {
      onShowSnack(S.of(context)!.communityDialogQtyError, Colors.red);
      return;
    }

    await onCommunityAction(item, qty);
  }
}
