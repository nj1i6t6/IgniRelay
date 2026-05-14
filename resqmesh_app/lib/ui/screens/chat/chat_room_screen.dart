import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/geo/admin_name_resolver.dart';
import 'package:ignirelay_app/app/services/chat_service.dart';
import 'package:ignirelay_app/app/services/room_display_name_resolver.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

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
  final RoomDisplayNameResolver _nameResolver = RoomDisplayNameResolver();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;
  String? _myPubKeyHex;
  String? _replyToEventId;
  StreamSubscription<ChatMessage>? _meshSub;
  String? _displayRoomName;
  Locale? _locale;
  late final IdentityManager _identity = context.read<IdentityManager>();

  @override
  void initState() {
    super.initState();
    _displayRoomName = widget.roomName;
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_locale != locale) {
      _locale = locale;
      _resolveDisplayName();
    }
    if (_meshSub == null) {
      _listenForNewMessages();
    }
  }

  Future<void> _resolveDisplayName() async {
    final locale = _locale ?? Localizations.localeOf(context);
    await AdminNameResolver().ensureLoaded();
    final name = await _nameResolver.resolve(
      roomId: widget.roomId,
      roomType: widget.roomType,
      fallbackRoomName: widget.roomName,
      locale: locale,
    );
    if (mounted && name != _displayRoomName) {
      setState(() => _displayRoomName = name);
    }
  }

  Future<void> _init() async {
    _myPubKeyHex = await _identity.getPublicKeyHex();
    await _loadMessages();
    await context.read<ChatService>().markAsRead(widget.roomId);
    _startCooldownTimer();
  }

  void _listenForNewMessages() {
    _meshSub = context.read<EventStream>().chatMessages.listen((msg) {
      // 其他房間的訊息對本畫面無意義，過濾掉避免不必要的 DB 重撈。
      if (msg.roomId != widget.roomId) return;
      _loadMessages();
    });
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = context.read<ChatService>().getRemainingCooldown(
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
      final msgs = await context.read<ChatService>().getMessages(widget.roomId);
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

    final success = await context.read<ChatService>().sendMessage(
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
        SnackBar(content: Text(context.l10n.chatRoomSendCooldown(_cooldownRemaining))),
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

  String _shortenPubKey(String? hexKey, BuildContext ctx) {
    if (hexKey == null || hexKey.length < 8) return ctx.l10n.chatRoomAnonymous;
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
    // 離開聊天室時標記已讀，避免自己發的訊息產生紅點
    context.read<ChatService>().markAsRead(widget.roomId);
    _cooldownTimer?.cancel();
    _meshSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Scaffold(
      backgroundColor: p.bg0,
      appBar: AppBar(
        backgroundColor: p.bg0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_displayRoomName ?? widget.roomName,
                style: IgniTypography.titleMedium(p.text0)),
            Text(
              context.l10n.chatRoomMessageCount(_messages.length),
              style: IgniTypography.monoSmall(p.text2),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: p.text1),
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
                    ? Center(
                        child: Text(context.l10n.chatRoomEmpty,
                            style: IgniTypography.bodyMedium(p.text2)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: IgniSpacing.sm,
                            vertical: IgniSpacing.xs),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          // 連續同發言者合併：只有首則顯示 sender label。
                          final prev = i > 0 ? _messages[i - 1] : null;
                          final curSender =
                              _pubKeyBlobToHex(msg['sender_pub_key']);
                          final prevSender = prev == null
                              ? null
                              : _pubKeyBlobToHex(prev['sender_pub_key']);
                          final showSender = curSender != prevSender;
                          return _buildMessageBubble(msg, showSender: showSender);
                        },
                      ),
          ),
          // Reply indicator
          if (_replyToEventId != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: IgniSpacing.md, vertical: IgniSpacing.xs),
              color: p.bg2,
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: p.text2),
                  const SizedBox(width: IgniSpacing.sm),
                  Expanded(
                      child: Text(context.l10n.chatRoomReply,
                          style: IgniTypography.bodySmall(p.text2))),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: p.text2),
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

  Widget _buildMessageBubble(Map<String, dynamic> msg,
      {required bool showSender}) {
    final p = context.igni;
    final senderHex = _pubKeyBlobToHex(msg['sender_pub_key']);
    final isMe = senderHex == _myPubKeyHex;
    final content = msg['content'] as String? ?? '';
    final hlc = msg['hlc_timestamp'] as int? ?? 0;
    final eventId = msg['event_id'] as String? ?? '';

    // 同發言者連續訊息：縮小垂直間距，avatar 僅第一則顯示。
    final topMargin = showSender ? IgniSpacing.sm : 2.0;
    final bubbleColor = isMe ? p.brandSoft : p.bg2;
    final textColor = p.text0;

    final bubble = GestureDetector(
      onLongPress: () {
        setState(() => _replyToEventId = eventId);
      },
      child: Container(
        margin: EdgeInsets.only(top: topMargin, bottom: 2),
        padding: const EdgeInsets.symmetric(
            horizontal: IgniSpacing.md, vertical: IgniSpacing.sm),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.70),
        decoration: BoxDecoration(
          color: bubbleColor,
          border: Border.all(color: p.border1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && showSender)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  _shortenPubKey(senderHex, context),
                  style: IgniTypography.monoSmall(p.text2),
                ),
              ),
            Text(content, style: IgniTypography.bodyMedium(textColor)),
            const SizedBox(height: 2),
            Text(
              _formatTime(hlc),
              style: IgniTypography.monoSmall(p.text3),
            ),
          ],
        ),
      ),
    );

    if (isMe) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }
    // 非自己訊息：連續同發言者的第一則顯示 avatar，其餘以等寬 SizedBox
    // 保留左側對齊縮排。
    return Padding(
      padding: const EdgeInsets.only(right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: topMargin),
            child: showSender
                ? _SenderAvatar(senderHex: senderHex)
                : const SizedBox(width: 32, height: 32),
          ),
          const SizedBox(width: IgniSpacing.sm),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final p = context.igni;
    // Bug 12 Fix: admin-only 頻道完全禁止一般用戶發言
    // TODO: 未來可根據 IdentityManager.getIdentityLevel() >= 3 判斷是否為管理員
    if (widget.adminOnly) {
      return Container(
        padding: EdgeInsets.only(
          left: IgniSpacing.lg, right: IgniSpacing.lg, top: IgniSpacing.md,
          bottom: MediaQuery.of(context).padding.bottom + IgniSpacing.md,
        ),
        decoration: BoxDecoration(
          color: p.bg1,
          border: Border(top: BorderSide(color: p.border1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 16, color: p.text2),
            const SizedBox(width: IgniSpacing.sm),
            Text(
              context.l10n.chatRoomAdminLock,
              style: IgniTypography.bodySmall(p.text2),
            ),
          ],
        ),
      );
    }

    final canSend = _cooldownRemaining == 0;
    return Container(
      padding: EdgeInsets.only(
        left: IgniSpacing.sm,
        right: IgniSpacing.sm,
        top: IgniSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + IgniSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: p.bg1,
        border: Border(top: BorderSide(color: p.border1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: context.l10n.chatRoomInputHint,
                isDense: true,
              ),
              onSubmitted: (_) => canSend ? _sendMessage() : null,
            ),
          ),
          const SizedBox(width: IgniSpacing.sm),
          canSend
              ? IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(Icons.send, color: p.brand),
                )
              // Cooldown（廣播冷卻）使用 semantic.ok 降飽和版，避免誤判為錯誤狀態
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
                        valueColor: AlwaysStoppedAnimation<Color>(p.ok),
                        backgroundColor: p.okSoft,
                      ),
                      Text('$_cooldownRemaining',
                          style: IgniTypography.monoSmall(p.text1)),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

/// 聊天訊息的發言者 avatar：以 sender pubkey hex 前 2 字為縮寫，
/// 底色由 hex 前 6 碼雜湊映射到 IgniPalette 的 hazard 色盤，
/// 以降飽和度呈現，避免搶過訊息本體。
class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.senderHex});
  final String senderHex;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final initials = senderHex.length >= 2
        ? senderHex.substring(0, 2).toUpperCase()
        : '··';
    final palette = <Color>[
      p.hazardWater,
      p.hazardFood,
      p.hazardMed,
      p.hazardShelter,
      p.hazardTool,
    ];
    int seed = 0;
    for (final c in senderHex.codeUnits.take(6)) {
      seed = (seed * 31 + c) & 0x7FFFFFFF;
    }
    final bg = palette[seed % palette.length].withValues(alpha: 0.22);
    final fg = palette[seed % palette.length];
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: fg.withValues(alpha: 0.45), width: 1),
      ),
      child: Text(
        initials,
        style: IgniTypography.monoSmall(fg)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
