import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/geo/admin_name_resolver.dart';
import 'package:ignirelay_app/app/services/chat_service.dart';
import 'package:ignirelay_app/app/services/room_display_name_resolver.dart';
import 'package:ignirelay_app/ui/screens/chat/chat_join_screen.dart';
import 'package:ignirelay_app/ui/screens/chat/chat_room_screen.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// 烽傳 Ignirelay 聊天室列表分頁（Stage 4b）。
///
/// 對應原型 [ChatScreen.jsx] 中的房間列表區段：
///   - 置頂標題區，mono 副標顯示 N ROOMS · M UNREAD
///   - 垂直清單（圖示色塊 + 名稱 + 時間 + 最後訊息預覽 + 未讀徽章）
///   - 右下 FAB（brand 發光陰影），進入 ChatJoinScreen
///   - 長按提供離開選項（沿用既有流程）
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  final RoomDisplayNameResolver _nameResolver = RoomDisplayNameResolver();

  List<_RoomTile> _tiles = [];
  bool _loading = true;
  Locale? _locale;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_locale != locale) {
      _locale = locale;
      _loadRooms();
    }
  }

  Future<void> _loadRooms() async {
    if (!_loading) setState(() => _loading = true);
    try {
      final locale = _locale ?? Localizations.localeOf(context);
      final chatService = context.read<ChatService>();
      await AdminNameResolver().ensureLoaded();
      final rooms = await chatService.getJoinedRooms();

      // Batch resolve all display names before updating UI
      final resolvedNames = await Future.wait(
        rooms.map((room) => _nameResolver.resolve(
          roomId: room['room_id'] as String,
          roomType: room['room_type'] as String? ?? 'custom',
          fallbackRoomName: room['room_name'] as String? ?? room['room_id'] as String,
          locale: locale,
        )),
      );

      final tiles = <_RoomTile>[];
      final roomMeta = await Future.wait(
        rooms.map((room) async {
          final roomId = room['room_id'] as String;
          final unread = await chatService.getUnreadCount(roomId);
          final last = await chatService.getLastMessage(roomId);
          return (unread: unread, last: last);
        }),
      );
      for (var i = 0; i < rooms.length; i++) {
        final room = rooms[i];
        final meta = roomMeta[i];
        tiles.add(_RoomTile(
          roomId: room['room_id'] as String,
          roomName: resolvedNames[i],
          roomType: room['room_type'] as String? ?? 'custom',
          adminOnly: (room['admin_only'] as int? ?? 0) == 1,
          rateLimitSeconds: room['rate_limit_seconds'] as int? ?? 180,
          unread: meta.unread,
          lastContent: meta.last?.content,
          lastHlc: meta.last?.hlcTimestamp,
        ));
      }
      // 排序：未讀優先 → 最新訊息優先 → 加入時間倒序（DB 本身已是 joined_at DESC）
      tiles.sort((a, b) {
        if ((a.unread > 0) != (b.unread > 0)) {
          return b.unread.compareTo(a.unread);
        }
        return (b.lastHlc ?? 0).compareTo(a.lastHlc ?? 0);
      });
      if (!mounted) return;
      setState(() {
        _tiles = tiles;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _autoJoin() async {
    final roomId = await context.read<ChatService>().autoJoinVillageRoom();
    if (!mounted) return;
    final s = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(roomId != null ? s.chatListAutoJoinSuccess : s.chatListAutoJoinFail),
    ));
    if (roomId != null) _loadRooms();
  }

  Future<void> _openJoin() async {
    final joined = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ChatJoinScreen()),
    );
    if (joined == true) _loadRooms();
  }

  Future<void> _openRoom(_RoomTile t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId: t.roomId,
          roomName: t.roomName,
          roomType: t.roomType,
          adminOnly: t.adminOnly,
          rateLimitSeconds: t.rateLimitSeconds,
        ),
      ),
    );
    _loadRooms();
  }

  Future<void> _confirmLeave(_RoomTile t) async {
    final s = context.l10n;
    final p = context.igni;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.chatListLeaveTitle),
        content: Text(s.chatListLeaveContent(t.roomName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.chatListLeaveCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.chatListLeaveConfirm,
                style: IgniTypography.labelLarge(p.sos)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<ChatService>().leaveRoom(t.roomId);
      _loadRooms();
    }
  }

  void _showRoomActions(_RoomTile t) {
    final s = context.l10n;
    final p = context.igni;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: IgniRadii.xl),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.exit_to_app, color: p.sos),
              title: Text(s.chatListLeaveTitle,
                  style: IgniTypography.bodyMedium(p.sos)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmLeave(t);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = context.l10n;
    final p = context.igni;
    final unreadTotal = _tiles.fold<int>(0, (sum, t) => sum + t.unread);

    return Container(
      color: p.bg0,
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── 頁首 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IgniSpacing.xl,
                    IgniSpacing.xl2,
                    IgniSpacing.xl,
                    IgniSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.chatListTitle,
                          style: IgniTypography.display(p.text0)),
                      const SizedBox(height: 4),
                      Text(
                        '${_tiles.length} ROOMS · $unreadTotal UNREAD',
                        style: IgniTypography.monoSmall(p.text2),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(color: p.brand),
                        )
                      : _tiles.isEmpty
                          ? _EmptyState(onAutoJoin: _autoJoin)
                          : RefreshIndicator(
                              color: p.brand,
                              onRefresh: _loadRooms,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                  left: IgniSpacing.lg,
                                  right: IgniSpacing.lg,
                                  bottom: IgniSpacing.bottomTabBarHeight +
                                      IgniSpacing.xl2,
                                ),
                                itemCount: _tiles.length,
                                itemBuilder: (ctx, i) {
                                  final t = _tiles[i];
                                  return _RoomRow(
                                    tile: t,
                                    isLast: i == _tiles.length - 1,
                                    onTap: () => _openRoom(t),
                                    onLongPress: () => _showRoomActions(t),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
          // ── FAB ──
          Positioned(
            right: IgniSpacing.xl,
            bottom: IgniSpacing.bottomTabBarHeight + IgniSpacing.xl,
            child: Semantics(
              button: true,
              label: s.chatListFabTooltip,
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    color: p.brand,
                    borderRadius: const BorderRadius.all(IgniRadii.xl),
                    boxShadow: IgniShadows.brandGlow(p.brand),
                  ),
                  child: InkWell(
                    borderRadius: const BorderRadius.all(IgniRadii.xl),
                    onTap: _openJoin,
                    child: const SizedBox(
                      width: 54,
                      height: 54,
                      child: Icon(Icons.add, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ───────────────────────── Room row ─────────────────────────
class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.tile,
    required this.isLast,
    required this.onTap,
    required this.onLongPress,
  });

  final _RoomTile tile;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final accent = _typeColor(p, tile.roomType);
    final typeIcon = _typeIcon(tile.roomType);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: const BorderRadius.all(IgniRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: IgniSpacing.sm, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: p.border0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: const BorderRadius.all(IgniRadii.lg),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: Icon(typeIcon, size: 22, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tile.roomName,
                          style: IgniTypography.bodyLarge(p.text0)
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: IgniSpacing.sm),
                      Text(
                        _formatTime(tile.lastHlc),
                        style: IgniTypography.monoSmall(p.text2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (tile.adminOnly) ...[
                        _OfficialBadge(accent: p.brand),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          tile.lastContent?.isNotEmpty == true
                              ? tile.lastContent!
                              : _fallbackSubtitle(context, tile.roomType),
                          style: IgniTypography.bodySmall(p.text2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (tile.unread > 0) ...[
              const SizedBox(width: IgniSpacing.sm),
              _UnreadBadge(count: tile.unread, color: p.brand),
            ],
          ],
        ),
      ),
    );
  }

  String _fallbackSubtitle(BuildContext context, String type) {
    final s = context.l10n;
    switch (type) {
      case 'nation':
        return s.chatListRoomNational;
      case 'county':
        return s.chatListRoomCounty;
      case 'township':
        return s.chatListRoomTownship;
      case 'village':
        return s.chatListRoomVillage;
      default:
        return s.chatListRoomCustom;
    }
  }

  Color _typeColor(IgniPalette p, String type) {
    switch (type) {
      case 'nation':
        return p.sos;
      case 'county':
        return p.brand;
      case 'township':
        return p.info;
      case 'village':
        return p.ok;
      default:
        return p.text2;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'nation':
        return Icons.flag_outlined;
      case 'county':
        return Icons.account_balance_outlined;
      case 'township':
        return Icons.location_city_outlined;
      case 'village':
        return Icons.home_outlined;
      default:
        return Icons.chat_outlined;
    }
  }

  String _formatTime(int? ms) {
    if (ms == null || ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return '昨天';
    }
    return '${dt.month}/${dt.day}';
  }
}

/// 官方頻道徽章 — Stage 4b 改為圖示優先（verified shield）。
///
/// 列表項目的橫向空間有限，原本「官方」兩字的文字徽章佔用過多寬度。
/// 改以 Material `verified` 圖示表示官方認證，語意清楚且跨語系自然。
class _OfficialBadge extends StatelessWidget {
  const _OfficialBadge({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '官方',
      child: Icon(
        Icons.verified,
        size: 14,
        color: accent,
        semanticLabel: '官方',
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(11)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// ───────────────────────── Empty state ─────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAutoJoin});
  final VoidCallback onAutoJoin;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final p = context.igni;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.xl),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 64),
        Icon(Icons.chat_bubble_outline, size: 64, color: p.text3),
        const SizedBox(height: IgniSpacing.md),
        Text(
          s.chatListEmptyTitle,
          textAlign: TextAlign.center,
          style: IgniTypography.titleMedium(p.text1),
        ),
        const SizedBox(height: IgniSpacing.sm),
        Text(
          s.chatListEmptySubtitle,
          textAlign: TextAlign.center,
          style: IgniTypography.bodyMedium(p.text2),
        ),
        const SizedBox(height: IgniSpacing.xl2),
        Center(
          child: TextButton.icon(
            onPressed: onAutoJoin,
            icon: Icon(Icons.my_location, color: p.brand),
            label: Text(
              s.chatListAutoJoin,
              style: IgniTypography.labelLarge(p.brand),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomTile {
  const _RoomTile({
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.adminOnly,
    required this.rateLimitSeconds,
    required this.unread,
    this.lastContent,
    this.lastHlc,
  });

  final String roomId;
  final String roomName;
  final String roomType;
  final bool adminOnly;
  final int rateLimitSeconds;
  final int unread;
  final String? lastContent;
  final int? lastHlc;
}
