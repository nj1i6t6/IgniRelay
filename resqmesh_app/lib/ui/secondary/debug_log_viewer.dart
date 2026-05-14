import 'package:flutter/material.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// Stage 2A 拆分：survival_mode_screen 的 debug panel。
///
/// 純展示 widget；所有資料由 `SurvivalModeScreen` 注入。
class DebugLogViewer extends StatelessWidget {
  const DebugLogViewer({
    super.key,
    required this.transportActive,
    required this.connectedPeers,
    required this.seenEventsCount,
    required this.sentCount,
    required this.receivedCount,
    required this.gattLogs,
    required this.transportLogs,
    required this.onExport,
  });

  final bool transportActive;
  final int connectedPeers;
  final int seenEventsCount;
  final int sentCount;
  final int receivedCount;
  final List<String> gattLogs;
  final List<String> transportLogs;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.withValues(alpha: 0.2),
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: onExport,
              icon: const Icon(Icons.download, size: 16),
              label: Text(context.l10n.survivalExportButton, style: const TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Transport State', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _debugRow('active', '$transportActive'),
          _debugRow('connected peers', '$connectedPeers'),
          _debugRow('seenEvents (mem)', '$seenEventsCount'),
          _debugRow('sent total', '$sentCount'),
          _debugRow('recv total', '$receivedCount'),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('GATT Server', style: TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${gattLogs.length} events', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          if (gattLogs.isEmpty)
            const Text('(no GATT events yet)', style: TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'))
          else
            ...gattLogs.reversed.take(10).map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(l, style: const TextStyle(color: Colors.cyan, fontSize: 9, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Transport Logs', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${transportLogs.length} entries', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          if (transportLogs.isEmpty)
            const Text('(no logs yet)', style: TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'))
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                reverse: true,
                itemCount: transportLogs.length,
                itemBuilder: (_, i) {
                  final log = transportLogs[transportLogs.length - 1 - i];
                  Color c = Colors.greenAccent.withValues(alpha: 0.7);
                  if (log.contains('ERROR')) {
                    c = Colors.red;
                  } else if (log.contains('SKIP')) {
                    c = Colors.orange;
                  } else if (log.contains('SENT')) {
                    c = Colors.lightBlueAccent;
                  } else if (log.contains('RECV')) {
                    c = Colors.purpleAccent;
                  } else if (log.contains('SCAN') || log.contains('BLOOM')) {
                    c = Colors.yellow;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(log, style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace'), maxLines: 2, overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
