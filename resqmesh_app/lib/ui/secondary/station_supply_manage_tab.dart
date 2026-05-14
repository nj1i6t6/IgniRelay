import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_controller.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_models.dart';

/// Stage 2A 拆分：station_supply_screen 的「管理已註冊據點」分頁 + 卡片。
class StationSupplyManageTab extends StatelessWidget {
  const StationSupplyManageTab({super.key, required this.items, required this.onRefresh});

  final List<StationItem> items;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_mall_directory, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(context.l10n.stationManageEmptyTitle, style: const TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            Text(context.l10n.stationManageEmptySubtitle, style: const TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: Colors.orangeAccent,
      backgroundColor: const Color(0xFF1a1a2e),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => StationItemCard(item: items[index], onRefresh: onRefresh),
      ),
    );
  }
}

class StationItemCard extends StatelessWidget {
  const StationItemCard({super.key, required this.item, required this.onRefresh});

  final StationItem item;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final meta = item.meta;
    final totalUsedByAll = item.quotaRows.fold<int>(0, (sum, row) => sum + ((row['total_used'] as int?) ?? 0));
    final uniqueUsers = item.quotaRows.map((r) => r['user_pub_key']).toSet().length;
    final remaining = (item.quantity - totalUsedByAll).clamp(0, item.quantity);

    return Card(
      color: const Color(0xFF1a1a2e),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    getLocalizedReadableName(item.resourceType, context),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _statusBadge(context, remaining, item.quantity.toInt()),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),
            _infoRow(Icons.inventory_2, context.l10n.stationInfoTotalQty, context.l10n.stationInfoQtyUnit(item.quantity.toInt())),
            _infoRow(Icons.shopping_cart, context.l10n.stationInfoUsed, context.l10n.stationInfoQtyUnit(totalUsedByAll)),
            _infoRow(Icons.check_circle_outline, context.l10n.stationInfoRemaining, context.l10n.stationInfoQtyUnit(remaining.toInt())),
            _infoRow(Icons.people, context.l10n.stationInfoUsers, context.l10n.stationInfoUsersUnit(uniqueUsers)),
            const SizedBox(height: 8),
            Text(
              context.l10n.stationQuotaRulesLabel,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _infoRow(Icons.category, context.l10n.stationQuotaCategoryLimitInfo, context.l10n.stationInfoQtyUnit(meta.perUserCategoryLimit)),
            _infoRow(Icons.equalizer, context.l10n.stationQuotaTotalLimitInfo, context.l10n.stationInfoQtyUnit(meta.perUserTotalLimit)),
            _infoRow(
              Icons.timer,
              context.l10n.stationQuotaResetCycleInfo,
              meta.resetIntervalMs > 0
                  ? context.l10n.stationQuotaResetHours((meta.resetIntervalMs / 3600000).round())
                  : context.l10n.stationQuotaResetNone,
            ),
            const SizedBox(height: 4),
            if (meta.visibleZones != null && meta.visibleZones!.isNotEmpty)
              _infoRow(Icons.location_on, context.l10n.stationVisibleZones, context.l10n.stationVisibleZonesCount(meta.visibleZones!.length)),
            if (meta.visibleTownship != null)
              _infoRow(Icons.map, context.l10n.stationVisibleZones, context.l10n.stationVisibleTownship(meta.visibleTownship!)),
            const Divider(color: Colors.white12, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showQuotaDetails(context),
                  icon: const Icon(Icons.list_alt, color: Colors.blueAccent, size: 16),
                  label: Text(context.l10n.stationQuotaDetailButton, style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmResetQuotas(context),
                  icon: const Icon(Icons.refresh, color: Colors.orangeAccent, size: 16),
                  label: Text(context.l10n.stationQuotaResetButton, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmRemove(context),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                  label: Text(context.l10n.stationRemoveButton, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, num remaining, int total) {
    final ratio = total > 0 ? remaining / total : 0;
    Color color;
    String label;
    if (ratio > 0.5) {
      color = Colors.green;
      label = context.l10n.stationStatusSufficient;
    } else if (ratio > 0.1) {
      color = Colors.orange;
      label = context.l10n.stationStatusLow;
    } else if (remaining > 0) {
      color = Colors.red;
      label = context.l10n.stationStatusCritical;
    } else {
      color = Colors.grey;
      label = context.l10n.stationStatusDepleted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 14),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  void _showQuotaDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        if (item.quotaRows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(ctx.l10n.stationQuotaDetailEmpty, style: const TextStyle(color: Colors.white38, fontSize: 16)),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.stationQuotaDetailTitle(getLocalizedReadableName(item.resourceType, ctx)),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),
            ...item.quotaRows.map(_buildQuotaRow),
          ],
        );
      },
    );
  }

  Widget _buildQuotaRow(Map<String, dynamic> row) {
    final pubKey = row['user_pub_key'] as Uint8List;
    final keyHex = pubKey.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final cat = row['category'] as String? ?? '';
    final used = row['used_quantity'] as int? ?? 0;
    final total = row['total_used'] as int? ?? 0;
    final lastReset = row['last_reset_at'] as int? ?? 0;
    final resetTime = lastReset > 0 ? DateTime.fromMillisecondsSinceEpoch(lastReset) : null;

    return Builder(builder: (ctx) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Text(ctx.l10n.stationQuotaUserLabel(keyHex), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Text(cat, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text(ctx.l10n.stationQuotaUsedTotal(used, total), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (resetTime != null)
              Text(
                ctx.l10n.stationQuotaLastReset(
                  '${resetTime.month}/${resetTime.day} ${resetTime.hour}:${resetTime.minute.toString().padLeft(2, '0')}',
                ),
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
          ],
        ),
      );
    });
  }

  Future<void> _confirmResetQuotas(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(ctx.l10n.stationResetAllDialogTitle, style: const TextStyle(color: Colors.white)),
        content: Text(ctx.l10n.stationResetAllDialogContent, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.stationResetAllDialogCancel, style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.stationResetAllDialogConfirm, style: const TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await context.read<StationSupplyController>().resetStationUsage(item.resourceId);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.stationResetSuccessSnack), backgroundColor: Colors.green[700]),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.stationResetFailSnack(e.toString())), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(ctx.l10n.stationRemoveDialogTitle, style: const TextStyle(color: Colors.white)),
        content: Text(
          ctx.l10n.stationRemoveDialogContent(getLocalizedReadableName(item.resourceType, ctx)),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.stationRemoveDialogCancel, style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.stationRemoveDialogConfirm, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await context.read<StationSupplyController>().removeStation(item.eventId);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.stationRemoveSuccessSnack), backgroundColor: Colors.green[700]),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.stationRemoveFailSnack(e.toString())), backgroundColor: Colors.red[700]),
        );
      }
    }
  }
}
