import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../crypto/identity_manager.dart';
import '../mesh/mesh_event_handler.dart';
import '../mesh/mesh_transport.dart';

/// Individual chat room screen with message list and input.
class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String roomType;
  final bool adminOnly;
  final int rateLimitSeconds;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.roomType,
    this.adminOnly = false,
    this.rateLimitSeconds = 180,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;
  String? _myPubKeyHex;
  String? _replyToEventId;
  StreamSubscription<MeshDataReceived>? _meshSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myPubKeyHex = await IdentityManager().getPublicKeyHex();
    await _loadMessages();
    await _chatService.markAsRead(widget.roomId);
    _startCooldownTimer();
    _listenForNewMessages();
  }

  void _listenForNewMessages() {
    _meshSub = MeshEventHandler().events.listen((_) {
      _loadMessages();
    });
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _chatService.getRemainingCooldown(
        widget.roomId,
        rateLimitSeconds: widget.rateLimitSeconds,
      );
      if (remaining != _cooldownRemaining) {
        setState(() => _cooldownRemaining = remaining);
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await _chatService.getMessages(widget.roomId);
      if (mounted) {
        setState(() {
          _messages = msgs.reversed.toList(); // oldest first for display
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final success = await _chatService.sendMessage(
      roomId: widget.roomId,
      roomType: widget.roomType,
      content: text,
      replyTo: _replyToEventId,
    );

    if (success && mounted) {
      _inputController.clear();
      setState(() => _replyToEventId = null);
      await _loadMessages();
      _scrollToBottom();
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('發送失敗，請等待 $_cooldownRemaining 秒後再試')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(int hlcTimestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(hlcTimestamp);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _shortenPubKey(String? hexKey) {
    if (hexKey == null || hexKey.length < 8) return '匿名';
    return hexKey.substring(0, 8);
  }

  /// Convert sender_pub_key BLOB (Uint8List) from DB to hex string
  String _pubKeyBlobToHex(dynamic senderPubKey) {
    if (senderPubKey == null) return '';
    if (senderPubKey is Uint8List) {
      return senderPubKey
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
    }
    if (senderPubKey is List<int>) {
      return senderPubKey
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
    }
    return senderPubKey.toString();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _meshSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.roomName, style: const TextStyle(fontSize: 16)),
            Text(
              '${_messages.length} 則訊息',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('還沒有訊息',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) =>
                            _buildMessageBubble(_messages[i]),
                      ),
          ),
          // Reply indicator
          if (_replyToEventId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.grey[200],
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('回覆訊息',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () =>
                        setState(() => _replyToEventId = null),
                  ),
                ],
              ),
            ),
          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final senderHex = _pubKeyBlobToHex(msg['sender_pub_key']);
    final isMe = senderHex == _myPubKeyHex;
    final content = msg['content'] as String? ?? '';
    final hlc = msg['hlc_timestamp'] as int? ?? 0;
    final eventId = msg['event_id'] as String? ?? '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          setState(() => _replyToEventId = eventId);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue[100] : Colors.grey[200],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 12),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Text(
                  _shortenPubKey(senderHex),
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold),
                ),
              Text(content, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                _formatTime(hlc),
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final canSend = _cooldownRemaining == 0;
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, -1))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: widget.adminOnly
                    ? '公告頻道（僅管理員可發言）'
                    : '輸入訊息...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                isDense: true,
              ),
              onSubmitted: (_) => canSend ? _sendMessage() : null,
            ),
          ),
          const SizedBox(width: 8),
          canSend
              ? IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.blue),
                )
              : SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value:
                            1 - (_cooldownRemaining / widget.rateLimitSeconds),
                        strokeWidth: 2,
                      ),
                      Text('$_cooldownRemaining',
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
