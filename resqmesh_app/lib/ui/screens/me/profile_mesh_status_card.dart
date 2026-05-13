import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/controllers/device_info_controller.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/ui/widgets/igni_card.dart';

/// 精簡 Mesh 狀態卡（顯示於「我」分頁）。
///
/// 只讀資料；點 [onOpenDetail] 可進入完整 SurvivalModeScreen 作控制。
/// Stage 4a：先以電量為 MVP；transport / peer count / GATT 狀態之後由
/// 進一步拉出的 controller 提供（不直接觸 platform 層）。
class ProfileMeshStatusCard extends StatefulWidget {
  const ProfileMeshStatusCard({super.key, required this.onOpenDetail});
  final VoidCallback onOpenDetail;

  @override
  State<ProfileMeshStatusCard> createState() => _ProfileMeshStatusCardState();
}

class _ProfileMeshStatusCardState extends State<ProfileMeshStatusCard> {
  int _battery = -1;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final b = await context.read<DeviceInfoController>().batteryLevel();
      if (!mounted) return;
      setState(() => _battery = b);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final batteryColor = _battery < 0
        ? p.text3
        : _battery < 20
            ? p.sos
            : _battery < 40
                ? p.warn
                : p.ok;

    return IgniCard(
      onTap: widget.onOpenDetail,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: batteryColor.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.all(IgniRadii.sm),
            ),
            child: Icon(Icons.bolt, size: 20, color: batteryColor),
          ),
          const SizedBox(width: IgniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.profileMeshBatteryLabel,
                    style: IgniTypography.bodyMedium(p.text0)
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  _battery < 0 ? '—' : '$_battery %',
                  style: IgniTypography.monoMedium(batteryColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(context.l10n.profileMeshAdvancedLabel,
                  style: IgniTypography.labelSmall(p.text2)),
              const SizedBox(height: 2),
              Icon(Icons.chevron_right, size: 16, color: p.text3),
            ],
          ),
        ],
      ),
    );
  }
}
