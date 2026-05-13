import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:provider/provider.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/emergency/emergency_mode_controller.dart';
import 'package:ignirelay_app/ui/screens/chat/chat_list_screen.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/ui/screens/map/map_screen.dart';
import 'package:ignirelay_app/ui/screens/match/match_screen.dart';
import 'package:ignirelay_app/ui/screens/me/profile_screen.dart';
import 'package:ignirelay_app/ui/shell/igni_bottom_tab_bar.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// 烽傳 Ignirelay 主 App 殼（4 分頁）。
///
/// 取代舊的 [MainTabController]（5 tabs）。分頁：地圖 / 聊天 / 媒合 / 我。
/// 生存模式在 Stage 4a 併入「我」分頁（IgniProfileScreen），保留完整控制面板作為 SubPage。
///
/// 職責：
///   - IndexedStack 管理 4 個 tab 頁面
///   - 監聽 Mesh 事件 → SOS 紅/黃警報、媒合通知
///   - 紅色警報同步設定 [EmergencyModeController.nearbyRed]
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  StreamSubscription? _bleSub;
  // 已 alert 過的事件 ID（去重用）。Dart 的 default Set 是 LinkedHashSet，
  // 保留插入順序，所以超過上限時直接 remove first（最早插入）即可 FIFO。
  final Set<String> _alertedEventIds = <String>{};
  static const int _kAlertedIdsCap = 256;
  Timer? _nearbyRedClear;
  bool _eventStreamSubscribed = false;

  /// 記錄一個 event id 已 alert 過；若超過上限則丟掉最早的，避免無界成長。
  void _markAlerted(String id) {
    _alertedEventIds.add(id);
    while (_alertedEventIds.length > _kAlertedIdsCap) {
      _alertedEventIds.remove(_alertedEventIds.first);
    }
  }

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = const [
      MapScreen(),
      ChatListScreen(),
      MatchScreen(),
      IgniProfileScreen(),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_eventStreamSubscribed) {
      _eventStreamSubscribed = true;
      _listenForSosAlerts();
    }
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _nearbyRedClear?.cancel();
    super.dispose();
  }

  void _listenForSosAlerts() {
    _bleSub = context.read<EventStream>().rawEvents.listen((event) {
      if (!mounted) return;
      _checkAndAlertSos(event.data, event.sourceNodeId);
      _checkAndAlertMatch();
    });
  }

  Future<void> _checkAndAlertSos(List<int> data, String deviceId) async {
    final eventStore = context.read<EventStore>();
    final decoder = context.read<EventDecoder>();
    final recentSos = await eventStore.queryRecentSos(
        window: const Duration(seconds: 60), minUrgency: 2);

    for (final evt in recentSos) {
      final eventId = evt['event_id'] as String? ?? '';
      if (_alertedEventIds.contains(eventId)) continue;
      _markAlerted(eventId);

      final urgency = (evt['urgency'] as int?) ?? 0;
      final payload = evt['payload'] as Uint8List?;
      String desc = '';
      if (payload != null && payload.isNotEmpty) {
        try {
          final rd = decoder.decodeRequestData(payload);
          desc = rd?.note ?? '';
          if (desc.length > 80) desc = '${desc.substring(0, 80)}...';
        } catch (e) {
          debugPrint('[SOS] RequestData decode failed for $eventId: $e');
        }
      }

      if (!mounted) return;

      if (urgency >= 3) {
        _triggerNearbyRed();
        _showSosRedAlert(desc);
      } else if (urgency >= 2) {
        _showSosYellowSnack(desc);
      }
    }
  }

  Future<void> _checkAndAlertMatch() async {
    final eventStore = context.read<EventStore>();
    final decoder = context.read<EventDecoder>();
    final cutoff = DateTime.now().millisecondsSinceEpoch - 60000;
    final offers = await eventStore.queryByType(2, limit: 5);
    final requests = await eventStore.queryByType(15, limit: 5);
    final recentMatch = [...offers, ...requests]
        .where((e) => (e['hlc_timestamp'] as int? ?? 0) > cutoff)
        .toList()
      ..sort((a, b) => (b['hlc_timestamp'] as int? ?? 0).compareTo(a['hlc_timestamp'] as int? ?? 0));
    if (recentMatch.length > 5) recentMatch.length = 5;

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
          final data = decoder.decodeMatchOfferData(payload);
          targetPubKey = data?.requesterPubKey ?? [];
        } else if (eventType == 15) {
          final data = decoder.decodeMatchRequestData(payload);
          targetPubKey = data?.providerPubKey ?? [];
        }
        if (targetPubKey.isEmpty) continue;
        bool isMe = targetPubKey.length == myPubKey.length;
        if (isMe) {
          for (int i = 0; i < myPubKey.length; i++) {
            if (targetPubKey[i] != myPubKey[i]) {
              isMe = false;
              break;
            }
          }
        }
        if (!isMe) continue;

        _markAlerted(eventId);
        if (!mounted) return;

        _showMatchSnack(eventType);
      } catch (_) {}
    }
  }

  /// 觸發附近紅色事件的急難模式；2 分鐘後自動解除。
  void _triggerNearbyRed() {
    context.read<EmergencyModeController>().set(EmergencyTrigger.nearbyRed, true);
    _nearbyRedClear?.cancel();
    _nearbyRedClear = Timer(const Duration(minutes: 2), () {
      context.read<EmergencyModeController>()
          .set(EmergencyTrigger.nearbyRed, false);
    });
  }

  void _showSosYellowSnack(String desc) {
    final p = context.igni;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.mainTabSosYellowSnack(desc),
          style: IgniTypography.bodyMedium(Colors.white),
        ),
        backgroundColor: p.warn,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: context.l10n.mainTabSosYellowAction,
          textColor: Colors.black,
          onPressed: () => setState(() => _index = 0),
        ),
      ),
    );
  }

  void _showMatchSnack(int eventType) {
    final p = context.igni;
    final msg = eventType == 2
        ? context.l10n.mainTabMatchNotifProvider
        : context.l10n.mainTabMatchNotifRequester;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: IgniTypography.bodyMedium(Colors.white)),
        backgroundColor: p.ok,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: context.l10n.mainTabMatchNotifAction,
          textColor: Colors.white,
          onPressed: () => setState(() => _index = 2),
        ),
      ),
    );
  }

  void _showSosRedAlert(String desc) {
    final p = context.igni;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final s = ctx.l10n;
        return AlertDialog(
          backgroundColor: p.bg1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(IgniRadii.xl),
          ),
          title: Row(
            children: [
              Icon(Icons.sos, color: p.sos, size: 28),
              const SizedBox(width: IgniSpacing.sm),
              Text(
                s.mainTabSosRedDialogTitle,
                style: IgniTypography.titleMedium(p.sos),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(IgniSpacing.md),
                decoration: BoxDecoration(
                  color: p.sosSoft,
                  borderRadius: const BorderRadius.all(IgniRadii.sm),
                  border: Border.all(color: p.sos.withValues(alpha: 0.3)),
                ),
                child: Text(
                  desc.isNotEmpty ? desc : s.mainTabSosRedDialogFallback,
                  style: IgniTypography.bodyMedium(p.text0),
                ),
              ),
              const SizedBox(height: IgniSpacing.md),
              Text(
                s.mainTabSosRedDialogContent,
                style: IgniTypography.bodySmall(p.text2),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                s.mainTabSosRedDialogDismiss,
                style: IgniTypography.bodyMedium(p.text3),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: p.sos,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _index = 0);
              },
              child: Text(s.mainTabSosRedDialogViewMap),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final p = context.igni;

    final tabs = <IgniTabItem>[
      IgniTabItem(
        label: s.tabMap,
        icon: Icons.map_outlined,
        activeIcon: Icons.map,
      ),
      IgniTabItem(
        label: s.tabChat,
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
      ),
      IgniTabItem(
        label: s.tabMatch,
        icon: Icons.handshake_outlined,
        activeIcon: Icons.handshake,
      ),
      IgniTabItem(
        label: s.tabProfile,
        icon: Icons.person_outline,
        activeIcon: Icons.person,
      ),
    ];

    return Scaffold(
      backgroundColor: p.bg0,
      // extendBody=false（預設）：tab bar 不會覆蓋內容，避免各分頁
      // 各自硬補 72/140 padding 仍被擋住的問題（見 Stage 7-r2 hotfix）。
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: IgniBottomTabBar(
        items: tabs,
        activeIndex: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
