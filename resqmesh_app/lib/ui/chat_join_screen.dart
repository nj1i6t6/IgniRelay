import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart' as crypto_lib;
import '../services/chat_service.dart';
import '../services/location_service.dart';
import '../geo/village_geofence.dart';

/// Screen for joining chat rooms via GPS auto-detect, manual location, or invite code.
class ChatJoinScreen extends StatefulWidget {
  const ChatJoinScreen({super.key});

  @override
  State<ChatJoinScreen> createState() => _ChatJoinScreenState();
}

class _ChatJoinScreenState extends State<ChatJoinScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _codeController = TextEditingController();
  bool _joining = false;
  String? _statusMessage;

  // 手動選區
  List<VillageInfo> _searchResults = [];
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();

  /// Bug 12 Fix: GPS 偵測加入 — 等待 GPS 初始化完成 + 重試機制
  Future<void> _autoJoinVillage() async {
    setState(() {
      _joining = true;
      _statusMessage = '正在取得 GPS 位置...';
    });

    try {
      // 確保 LocationService 已初始化
      final locService = LocationService();
      if (!locService.hasLocation) {
        // 等待 GPS 初始化（最多 10 秒）
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (locService.hasLocation) break;
          if (!mounted) return;
          setState(() => _statusMessage = '等待 GPS 定位中... (${(i + 1) ~/ 2}s)');
        }
      }

      if (!locService.hasLocation) {
        if (mounted) {
          setState(() => _statusMessage = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locService.unavailableReason ?? 'GPS 定位失敗，請確認 GPS 已開啟，或使用下方手動設定'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      setState(() => _statusMessage = '正在查詢所在行政區...');

      final roomId = await _chatService.autoJoinVillageRoom();
      if (roomId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已加入所在里聊天室及公告頻道')),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法識別所在行政區，請使用手動設定')),
        );
      }
    } finally {
      if (mounted) setState(() {
        _joining = false;
        _statusMessage = null;
      });
    }
  }

  /// 手動搜尋村里
  Future<void> _searchVillage() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() => _searching = true);
    try {
      // 從 VillageGeofence 資料庫模糊搜尋
      final results = await _queryVillagesByName(keyword);
      if (mounted) {
        setState(() => _searchResults = results);
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('找不到符合的村里，請嘗試其他關鍵字')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// 從 SQLite 資料庫搜尋村里名稱
  Future<List<VillageInfo>> _queryVillagesByName(String keyword) async {
    try {
      await VillageGeofence.init();
      // 使用 raw SQL 搜尋
      final db = VillageGeofence.getDb();
      if (db == null) return [];
      final rows = db.select(
        '''SELECT villcode, towncode, countyname, townname, villname, villeng
           FROM villages
           WHERE countyname LIKE ? OR townname LIKE ? OR villname LIKE ?
           LIMIT 50''',
        ['%$keyword%', '%$keyword%', '%$keyword%'],
      );
      return rows.map((row) => VillageInfo(
        villcode: row['villcode'] as String,
        towncode: row['towncode'] as String,
        countyName: row['countyname'] as String,
        townName: row['townname'] as String,
        villName: row['villname'] as String,
        villEng: row['villeng'] as String,
        isOnBoundary: false,
      )).toList();
    } catch (e) {
      debugPrint('[ChatJoin] Village search failed: $e');
      return [];
    }
  }

  /// 選擇村里並加入聊天室
  Future<void> _joinWithVillage(VillageInfo village) async {
    setState(() => _joining = true);
    try {
      // 離開舊的地區頻道，加入新的
      await _chatService.changeVillageRoom(
        newVillageCode: village.villcode,
        countyName: village.countyName,
        townName: village.townName,
        villName: village.villName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已加入 ${village.fullName} 聊天室及公告頻道')),
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

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _joining = true);
    try {
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
        roomName: roomId,
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
    _searchController.dispose();
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
            // ── GPS 自動加入 ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('自動加入',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('根據 GPS 位置自動加入所在里聊天室及行政區公告頻道',
                        style: TextStyle(color: Colors.grey)),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(_statusMessage!, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _joining ? null : _autoJoinVillage,
                        icon: const Icon(Icons.my_location),
                        label: _joining
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('偵測並加入里聊天室'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 手動設定所在區域 ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('手動設定所在區域',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('輸入縣市、鄉鎮區或里名稱搜尋，選擇後加入對應聊天室',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: '例：新興區、安康里、高雄市',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _searchVillage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _searching ? null : _searchVillage,
                          child: _searching
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('搜尋'),
                        ),
                      ],
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('搜尋結果（${_searchResults.length} 筆）',
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (ctx, i) {
                            final v = _searchResults[i];
                            return ListTile(
                              dense: true,
                              title: Text(v.fullName),
                              subtitle: Text('代碼: ${v.villcode}', style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.add_circle_outline, size: 20),
                              onTap: _joining ? null : () => _joinWithVillage(v),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 邀請碼 ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('輸入邀請碼',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

            // ── 說明 ──
            Card(
              color: Colors.blue.withOpacity(0.1),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('聊天室說明', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('- 里聊天室：所有人皆可發言，每 3 分鐘可發一則'),
                    Text('- 鄉鎮區/縣市/全國：僅管理員（L3）可發布公告'),
                    Text('- 自訂頻道：需掃碼或輸入邀請碼加入'),
                    Text('- 所有訊息透過 BLE Mesh 傳播，48 小時後自動清除'),
                    Text('- 切換區域後，舊區域的聊天室會被移除'),
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
