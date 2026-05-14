import 'package:flutter/material.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// Stage 2A 拆分：交接完成 / 取消的單純結果頁。
/// 純展示，由 [PhysicalHandoffScreen] 在 done / failed 狀態下顯示。
class HandoffSuccessView extends StatelessWidget {
  const HandoffSuccessView({super.key, required this.resourceType});

  final String resourceType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1a0d),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 100),
            const SizedBox(height: 24),
            Text(
              context.l10n.handoffSuccessTitle,
              style: const TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.handoffSuccessContent(resourceType),
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
              child: Text(context.l10n.handoffSuccessBack, style: const TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}

class HandoffCancelledView extends StatelessWidget {
  const HandoffCancelledView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a0d0d),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel, color: Colors.redAccent, size: 100),
            const SizedBox(height: 24),
            Text(
              context.l10n.handoffCancelledTitle,
              style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.handoffCancelledContent,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(context.l10n.handoffCancelledBack, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
