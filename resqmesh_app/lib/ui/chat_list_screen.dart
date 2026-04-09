import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/chat_service.dart';
import 'chat_room_screen.dart';
import 'chat_join_screen.dart';

/// Chat room list screen showing all joined rooms.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _rooms = [];
  Map<String, int> _unreadCounts = {};
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    try {
      final rooms = await _chatService.getJoinedRooms();
      final counts = <String, int>{};
      for (final room in rooms) {
        final roomId = room['room_id'] as String;
        counts[roomId] = await _chatService.getUnreadCount(roomId);
      }
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _unreadCounts = counts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roomTypeLabel(String type, S l10n) {
    switch (type) {
      case 'nation':
        return l10n.chatListRoomNational;
      case 'county':
        return l10n.chatListRoomCounty;
      case 'township':
        return l10n.chatListRoomTownship;
      case 'village':
        return l10n.chatListRoomVillage;
      case 'custom':
        return l10n.chatListRoomCustom;
      default:
        return type;
    }
  }

  IconData _roomTypeIcon(String type) {
    switch (type) {
      case 'nation':
        return Icons.flag;
      case 'county':
        return Icons.account_balance;
      case 'township':
        return Icons.location_city;
      case 'village':
        return Icons.home;
      case 'custom':
        return Icons.group;
      default:
        return Icons.chat;
    }
  }

  Color _roomTypeColor(String type) {
    switch (type) {
      case 'nation':
        return Colors.red;
      case 'county':
        return Colors.orange;
      case 'township':
        return Colors.blue;
      case 'village':
        return Colors.green;
      case 'custom':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context)!.chatListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
            tooltip: S.of(context)!.chatListRefreshTooltip,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRooms,
                  child: ListView.builder(
                    itemCount: _rooms.length,
                    itemBuilder: (ctx, i) => _buildRoomTile(_rooms[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final joined = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ChatJoinScreen()),
          );
          if (joined == true) _loadRooms();
        },
        tooltip: S.of(context)!.chatListFabTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = S.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(l10n.chatListEmptyTitle,
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(l10n.chatListEmptySubtitle,
              style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final roomId = await _chatService.autoJoinVillageRoom();
              if (roomId != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(S.of(context)!.chatListAutoJoinSuccess)),
                );
                _loadRooms();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(S.of(context)!.chatListAutoJoinFail)),
                );
              }
            },
            icon: const Icon(Icons.my_location),
            label: Text(l10n.chatListAutoJoin),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final roomId = room['room_id'] as String;
    final roomName = room['room_name'] as String? ?? roomId;
    final roomType = room['room_type'] as String? ?? 'custom';
    final adminOnly = (room['admin_only'] as int? ?? 0) == 1;
    final unread = _unreadCounts[roomId] ?? 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _roomTypeColor(roomType).withOpacity(0.2),
        child: Icon(_roomTypeIcon(roomType), color: _roomTypeColor(roomType)),
      ),
      title: Text(roomName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        adminOnly
            ? '${_roomTypeLabel(roomType, S.of(context)!)} · ${S.of(context)!.chatListAdminBadge}'
            : _roomTypeLabel(roomType, S.of(context)!),
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      trailing: unread > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            )
          : null,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              roomId: roomId,
              roomName: roomName,
              roomType: roomType,
              adminOnly: adminOnly,
              rateLimitSeconds: room['rate_limit_seconds'] as int? ?? 180,
            ),
          ),
        );
        _loadRooms(); // Refresh unread counts
      },
      onLongPress: () => _showRoomOptions(roomId, roomName),
    );
  }

  void _showRoomOptions(String roomId, String roomName) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: Text(S.of(context)!.chatListLeaveTitle,
                  style: const TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(S.of(context)!.chatListLeaveTitle),
                    content: Text(S.of(context)!.chatListLeaveContent(roomName)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(S.of(context)!.chatListLeaveCancel)),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(S.of(context)!.chatListLeaveConfirm,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _chatService.leaveRoom(roomId);
                  _loadRooms();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
