import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/physical_handoff_controller.dart';

/// Stage 2A 拆分：DROP_OFF 交接方法的 provider / requester 步驟視圖。
/// 由 [PhysicalHandoffScreen] thin shell 依角色挑選；state 全在 controller。

/// Provider 端：設定放置地點 + 照片描述，確認放置。
class HandoffDropOffProviderView extends StatelessWidget {
  const HandoffDropOffProviderView({
    super.key,
    required this.controller,
    required this.resourceType,
    required this.onComplete,
  });

  final PhysicalHandoffController controller;
  final String resourceType;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.inventory_2, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          Text(
            context.l10n.handoffProviderResource(resourceType),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.handoffDropoffProviderTitle,
            style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.handoffDropoffLocationLabel,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.cyan, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.dropOffLat != null
                            ? '${c.dropOffLat!.toStringAsFixed(5)}, ${c.dropOffLng!.toStringAsFixed(5)}'
                            : context.l10n.handoffDropoffUseCurrentLocation,
                        style: TextStyle(
                          color:
                              c.dropOffLat != null ? Colors.white : Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => c.setDropOffLocation(25.045, 121.543),
                      child: Text(context.l10n.handoffDropoffLocateButton,
                          style: const TextStyle(
                              color: Colors.cyan, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: c.setDropOffPhotoDesc,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.l10n.handoffDropoffDescLabel,
              labelStyle: const TextStyle(color: Colors.white54),
              hintText: context.l10n.handoffDropoffDescHint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon:
                  const Icon(Icons.photo_camera, color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.amber),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: c.dropOffPlaced ? null : onComplete,
              icon: c.dropOffPlaced
                  ? const Icon(Icons.check, color: Colors.white)
                  : const Icon(Icons.place, color: Colors.white),
              label: Text(
                c.dropOffPlaced
                    ? context.l10n.handoffDropoffWaitingButton
                    : context.l10n.handoffDropoffConfirmButton,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    c.dropOffPlaced ? Colors.grey[700] : Colors.amber[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Requester 端：DROP_OFF 說明 + 確認領取按鈕。
class HandoffDropOffRequesterView extends StatelessWidget {
  const HandoffDropOffRequesterView({
    super.key,
    required this.resourceType,
    required this.onComplete,
  });

  final String resourceType;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.inventory_2, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          Text(
            context.l10n.handoffProviderResource(resourceType),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.handoffDropoffRequesterTitle,
            style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 24),
                const SizedBox(height: 8),
                Text(
                  context.l10n.handoffDropoffRequesterContent,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                context.l10n.handoffDropoffRequesterConfirm,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
