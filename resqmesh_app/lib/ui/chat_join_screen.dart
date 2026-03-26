import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart' as crypto_lib;
import '../services/chat_service.dart';

/// Screen for joining chat rooms via GPS auto-detect, QR code, or manual code.
class ChatJoinScreen extends StatefulWidget {
  const ChatJoinScreen({super.key});

  @override
  State<ChatJoinScreen> createState() => _ChatJoinScreenState();
}

class _ChatJoinScreenState extends State<ChatJoinScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _codeController = TextEditingController();
  bool _joining = false;

  Future<void> _autoJoinVillage() async {
    setState(() => _joining = true);
    try {
      final roomId = await _chatService.autoJoinVillageRoom();
      if (roomId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已加入所在里聊天室')),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法取得位置，請確認 GPS 已開啟')),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _joining = true);
    try {
      // Code format: "roomId:secret" or just "roomId"
      String roomId;
      String? joinTokenHash;

      if (code.contains(':')) {
        final parts = code.split(':');
        roomId = parts[0];
        final secret = parts.sublist(1).join(':');
        final bytes = utf8.encode('$roomId$secret');
        joinTokenHash = crypto_lib.sha256.convert(bytes).toString();
      } else {
        roomId = code;
      }

      await _chatService.joinRoom(
        roomId: roomId,
        roomName: roomId, // Will be updated when receiving ChatRoomConfig
        roomType: 'custom',
        joinTokenHash: joinTokenHash,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已加入聊天室')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加入聊天室')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Auto-join section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('自動加入',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('根據 GPS 位置自動加入所在里的聊天室',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _joining ? null : _autoJoinVillage,
                        icon: const Icon(Icons.my_location),
                        label: _joining
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('偵測並加入里聊天室'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Manual code section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('輸入邀請碼',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('輸入聊天室 ID 或邀請碼加入自訂頻道',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        hintText: '聊天室 ID 或 ID:密碼',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _joining ? null : _joinByCode,
                        icon: const Icon(Icons.login),
                        label: const Text('加入'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Info section
            Card(
              color: Colors.blue.withOpacity(0.1),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('聊天室說明',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('- 里聊天室：所有人皆可發言，每 3 分鐘可發一則'),
                    Text('- 鄉鎮區/縣市/全國：僅管理員可發布公告'),
                    Text('- 自訂頻道：需掃碼或輸入邀請碼加入'),
                    Text('- 所有訊息透過 BLE Mesh 傳播，48 小時後自動清除'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
