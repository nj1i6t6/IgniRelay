import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart' as crypto_lib;
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/app/services/chat_service.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/geo/village_geofence.dart';

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
      _statusMessage = S.of(context)!.chatJoinGpsLocating;
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
          setState(() => _statusMessage = S.of(context)!.chatJoinGpsWaiting((i + 1) ~/ 2));
        }
      }

      if (!locService.hasLocation) {
        if (mounted) {
          setState(() => _statusMessage = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locService.unavailableReason ?? S.of(context)!.chatJoinGpsFail),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      setState(() => _statusMessage = S.of(context)!.chatJoinGpsQuerying);

      final roomId = await _chatService.autoJoinVillageRoom();
      if (roomId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.chatJoinAutoSuccess)),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.chatJoinAutoFailRegion)),
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
            SnackBar(content: Text(S.of(context)!.chatJoinSearchNoResults)),
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
          SnackBar(content: Text(S.of(context)!.chatJoinSuccess(village.fullName))),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.chatJoinFail(e.toString()))),
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
          SnackBar(content: Text(S.of(context)!.chatJoinInviteSuccess)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.chatJoinFail(e.toString()))),
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
      appBar: AppBar(title: Text(S.of(context)!.chatJoinTitle)),
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
                    Text(S.of(context)!.chatJoinAutoSection,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(S.of(context)!.chatJoinAutoDesc,
                        style: const TextStyle(color: Colors.grey)),
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
                            : Text(S.of(context)!.chatJoinAutoButton),
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
                    Text(S.of(context)!.chatJoinManualSection,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(S.of(context)!.chatJoinManualDesc,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: S.of(context)!.chatJoinSearchHint,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.search),
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
                              : Text(S.of(context)!.chatJoinSearchButton),
                        ),
                      ],
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(S.of(context)!.chatJoinSearchResults(_searchResults.length),
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
                              subtitle: Text(S.of(context)!.chatJoinSearchVillcode(v.villcode), style: const TextStyle(fontSize: 11)),
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
                    Text(S.of(context)!.chatJoinInviteSection,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(S.of(context)!.chatJoinInviteDesc,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        hintText: S.of(context)!.chatJoinInviteHint,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.vpn_key),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _joining ? null : _joinByCode,
                        icon: const Icon(Icons.login),
                        label: Text(S.of(context)!.chatJoinInviteButton),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.of(context)!.chatJoinInfoSection, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(S.of(context)!.chatJoinInfoVillage),
                    Text(S.of(context)!.chatJoinInfoAdmin),
                    Text(S.of(context)!.chatJoinInfoCustom),
                    Text(S.of(context)!.chatJoinInfoMesh),
                    Text(S.of(context)!.chatJoinInfoSwitch),
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
