import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;
import 'package:ignirelay_app/ui/map_screen.dart';
import 'package:ignirelay_app/ui/survival_mode_screen.dart';
import 'package:ignirelay_app/ui/chat_list_screen.dart';
import 'package:ignirelay_app/ui/match_screen.dart';
import 'package:ignirelay_app/ui/profile_page.dart';

class MainTabController extends StatefulWidget {
  const MainTabController({super.key});

  @override
  State<MainTabController> createState() => _MainTabControllerState();
}

class _MainTabControllerState extends State<MainTabController> {
  int _currentIndex = 0;
  StreamSubscription? _bleSub;
  final Set<String> _alertedEventIds = {};

  final List<Widget> _pages = [
    const MapScreen(),
    const SurvivalModeScreen(),
    const ChatListScreen(),
    const MatchScreen(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _listenForSosAlerts();
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    super.dispose();
  }

  /// 監聽 Mesh 收到的事件，彈出警報或媒合通知
  void _listenForSosAlerts() {
    _bleSub = MeshEventHandler().events.listen((event) {
      if (!mounted) return;
      _checkAndAlertSos(event.data, event.sourceNodeId);
      _checkAndAlertMatch();
    });
  }

  Future<void> _checkAndAlertSos(List<int> data, String deviceId) async {
    final db = await DatabaseHelper().database;
    final cutoff = DateTime.now().millisecondsSinceEpoch - 60000;
    final recentSos = await db.query(
      'Event_Logs',
      where: 'urgency >= 2 AND hlc_timestamp > ?',
      whereArgs: [cutoff],
      orderBy: 'hlc_timestamp DESC',
      limit: 5,
    );

    for (final evt in recentSos) {
      final eventId = evt['event_id'] as String? ?? '';
      if (_alertedEventIds.contains(eventId)) continue;
      _alertedEventIds.add(eventId);

      final urgency = (evt['urgency'] as int?) ?? 0;
      final payload = evt['payload'] as Uint8List?;
      String desc = '';
      if (payload != null) {
        try {
          desc = String.fromCharCodes(payload);
          if (desc.length > 80) desc = '${desc.substring(0, 80)}...';
        } catch (_) {}
      }

      if (!mounted) return;

      if (urgency >= 3) {
        _showSosRedAlert(desc);
      } else if (urgency >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.mainTabSosYellowSnack(desc)),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: S.of(context)!.mainTabSosYellowAction,
              textColor: Colors.white,
              onPressed: () => setState(() => _currentIndex = 0),
            ),
          ),
        );
      }
    }
  }

  Future<void> _checkAndAlertMatch() async {
    final db = await DatabaseHelper().database;
    final cutoff = DateTime.now().millisecondsSinceEpoch - 60000;
    final recentMatch = await db.query(
      'Event_Logs',
      where: '(event_type = 2 OR event_type = 15) AND hlc_timestamp > ?',
      whereArgs: [cutoff],
      orderBy: 'hlc_timestamp DESC',
      limit: 5,
    );

    final myPubKey = await IdentityManager().getPublicKeyBytes();

    for (final evt in recentMatch) {
      final eventId = evt['event_id'] as String? ?? '';
      if (_alertedEventIds.contains(eventId)) continue;

      final payload = evt['payload'] as Uint8List?;
      if (payload == null || payload.isEmpty) continue;
      final eventType = (evt['event_type'] as int?) ?? 0;

      try {
        List<int> targetPubKey = [];
        if (eventType == 2) {
          final data = pb.MatchOfferData.fromBuffer(payload);
          targetPubKey = data.requesterPubKey;
        } else if (eventType == 15) {
          final data = pb.MatchRequestData.fromBuffer(payload);
          targetPubKey = data.providerPubKey;
        }
        if (targetPubKey.isEmpty) continue;
        bool isMe = targetPubKey.length == myPubKey.length;
        if (isMe) {
          for (int i = 0; i < myPubKey.length; i++) {
            if (targetPubKey[i] != myPubKey[i]) { isMe = false; break; }
          }
        }
        if (!isMe) continue;

        _alertedEventIds.add(eventId);
        if (!mounted) return;

        final msg = eventType == 2
            ? S.of(context)!.mainTabMatchNotifProvider
            : S.of(context)!.mainTabMatchNotifRequester;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: S.of(context)!.mainTabMatchNotifAction,
              textColor: Colors.white,
              onPressed: () => setState(() => _currentIndex = 3),
            ),
          ),
        );
      } catch (_) {}
    }
  }

  void _showSosRedAlert(String desc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sos, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(S.of(context)!.mainTabSosRedDialogTitle,
                style:
                    const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                desc.isNotEmpty ? desc : S.of(context)!.mainTabSosRedDialogFallback,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              S.of(context)!.mainTabSosRedDialogContent,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.of(context)!.mainTabSosRedDialogDismiss, style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _currentIndex = 0);
            },
            child: Text(S.of(context)!.mainTabSosRedDialogViewMap),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0d0d1a),
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey[600],
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            activeIcon: const Icon(Icons.map),
            label: S.of(context)!.tabMap,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bluetooth_outlined),
            activeIcon: const Icon(Icons.bluetooth),
            label: S.of(context)!.tabMeshGuard,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_outlined),
            activeIcon: const Icon(Icons.chat),
            label: S.of(context)!.tabChat,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.handshake_outlined),
            activeIcon: const Icon(Icons.handshake),
            label: S.of(context)!.tabMatch,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_circle_outlined),
            activeIcon: const Icon(Icons.account_circle),
            label: S.of(context)!.tabProfile,
          ),
        ],
      ),
    );
  }
}
