import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart' as crypto_lib;
import 'package:ignirelay_app/app/geo/admin_name_resolver.dart';
import 'package:ignirelay_app/app/services/chat_service.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/room_display_name_resolver.dart';
import 'package:ignirelay_app/app/geo/village_geofence.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:provider/provider.dart';

/// Screen for joining chat rooms via GPS auto-detect, manual location, or invite code.
class ChatJoinScreen extends StatefulWidget {
  const ChatJoinScreen({super.key});

  @override
  State<ChatJoinScreen> createState() => _ChatJoinScreenState();
}

class _ChatJoinScreenState extends State<ChatJoinScreen> {
  final RoomDisplayNameResolver _nameResolver = RoomDisplayNameResolver();
  final TextEditingController _codeController = TextEditingController();
  bool _joining = false;
  String? _statusMessage;

  List<VillageInfo> _searchResults = [];
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();

  Future<void> _autoJoinVillage() async {
    setState(() {
      _joining = true;
      _statusMessage = context.l10n.chatJoinGpsLocating;
    });

    try {
      final chatService = context.read<ChatService>();
      final locService = context.read<LocationService>();
      if (!locService.hasLocation) {
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (locService.hasLocation) break;
          if (!mounted) return;
          setState(() => _statusMessage = context.l10n.chatJoinGpsWaiting((i + 1) ~/ 2));
        }
      }

      if (!locService.hasLocation) {
        if (mounted) {
          setState(() => _statusMessage = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locService.unavailableReason ?? context.l10n.chatJoinGpsFail),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      setState(() => _statusMessage = context.l10n.chatJoinGpsQuerying);

      final roomId = await chatService.autoJoinVillageRoom();
      if (roomId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatJoinAutoSuccess)),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatJoinAutoFailRegion)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _searchVillage() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() => _searching = true);
    try {
      await AdminNameResolver().ensureLoaded();
      final results = await _queryVillagesByName(keyword);
      if (mounted) {
        setState(() => _searchResults = results);
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.chatJoinSearchNoResults)),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<List<VillageInfo>> _queryVillagesByName(String keyword) async {
    try {
      await VillageGeofence.init();
      final db = VillageGeofence.getDb();
      if (db == null) return [];
      final rows = db.select(
        '''SELECT villcode, towncode, countyname, townname, villname, villeng
           FROM villages
           WHERE countyname LIKE ? OR townname LIKE ? OR villname LIKE ? OR villeng LIKE ?
           LIMIT 50''',
        ['%$keyword%', '%$keyword%', '%$keyword%', '%$keyword%'],
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

  Future<void> _joinWithVillage(VillageInfo village) async {
    setState(() => _joining = true);
    try {
      await context.read<ChatService>().changeVillageRoom(
        newVillageCode: village.villcode,
        countyName: village.countyName,
        townName: village.townName,
        villName: village.villName,
      );
      if (mounted) {
        final locale = Localizations.localeOf(context);
        final displayName = await _nameResolver.resolve(
          roomId: village.villcode,
          roomType: 'village',
          fallbackRoomName: village.fullName,
          locale: locale,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatJoinSuccess(displayName))),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatJoinFail(e.toString()))),
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

      await context.read<ChatService>().joinRoom(
        roomId: roomId,
        roomName: roomId,
        roomType: 'custom',
        joinTokenHash: joinTokenHash,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatJoinInviteSuccess)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatJoinFail(e.toString()))),
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
    final p = context.igni;
    final s = context.l10n;
    return Scaffold(
      backgroundColor: p.bg0,
      appBar: AppBar(
        backgroundColor: p.bg0,
        title: Text(s.chatJoinTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(IgniSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Section(
              title: s.chatJoinAutoSection,
              desc: s.chatJoinAutoDesc,
              children: [
                if (_statusMessage != null) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(p.brand),
                        ),
                      ),
                      const SizedBox(width: IgniSpacing.sm),
                      Text(_statusMessage!,
                          style: IgniTypography.bodySmall(p.text1)),
                    ],
                  ),
                  const SizedBox(height: IgniSpacing.sm),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _joining ? null : _autoJoinVillage,
                    icon: const Icon(Icons.my_location),
                    label: _joining
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(s.chatJoinAutoButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: IgniSpacing.lg),

            _Section(
              title: s.chatJoinManualSection,
              desc: s.chatJoinManualDesc,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: s.chatJoinSearchHint,
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _searchVillage(),
                      ),
                    ),
                    const SizedBox(width: IgniSpacing.sm),
                    ElevatedButton(
                      onPressed: _searching ? null : _searchVillage,
                      child: _searching
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(s.chatJoinSearchButton),
                    ),
                  ],
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: IgniSpacing.md),
                  Text(s.chatJoinSearchResults(_searchResults.length),
                      style: IgniTypography.monoSmall(p.text2)),
                  const SizedBox(height: IgniSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (ctx, i) {
                        final v = _searchResults[i];
                        final locale = Localizations.localeOf(context);
                        final useZh = locale.languageCode.toLowerCase() == 'zh';
                        final displayName = useZh
                            ? v.fullName
                            : _formatVillageNameEnglish(v);
                        return ListTile(
                          dense: true,
                          title: Text(displayName,
                              style: IgniTypography.bodyMedium(p.text0)),
                          subtitle: Text(
                              s.chatJoinSearchVillcode(v.villcode),
                              style: IgniTypography.monoSmall(p.text2)),
                          trailing: Icon(Icons.add_circle_outline,
                              size: 20, color: p.brand),
                          onTap: _joining ? null : () => _joinWithVillage(v),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: IgniSpacing.lg),

            _Section(
              title: s.chatJoinInviteSection,
              desc: s.chatJoinInviteDesc,
              children: [
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText: s.chatJoinInviteHint,
                    prefixIcon: const Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: IgniSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _joining ? null : _joinByCode,
                    icon: const Icon(Icons.login),
                    label: Text(s.chatJoinInviteButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: IgniSpacing.lg),

            Container(
              padding: const EdgeInsets.all(IgniSpacing.lg),
              decoration: BoxDecoration(
                color: p.infoSoft,
                border: Border.all(color: p.info.withValues(alpha: 0.35)),
                borderRadius: const BorderRadius.all(IgniRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.chatJoinInfoSection,
                      style: IgniTypography.labelLarge(p.text0)),
                  const SizedBox(height: IgniSpacing.sm),
                  Text(s.chatJoinInfoVillage,
                      style: IgniTypography.bodySmall(p.text1)),
                  Text(s.chatJoinInfoAdmin,
                      style: IgniTypography.bodySmall(p.text1)),
                  Text(s.chatJoinInfoCustom,
                      style: IgniTypography.bodySmall(p.text1)),
                  Text(s.chatJoinInfoMesh,
                      style: IgniTypography.bodySmall(p.text1)),
                  Text(s.chatJoinInfoSwitch,
                      style: IgniTypography.bodySmall(p.text1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// English display for village search results.
  /// Delegates to RoomDisplayNameResolver.formatVillageEnglish (sync)
  /// to avoid duplicating formatting logic.
  String _formatVillageNameEnglish(VillageInfo v) {
    final countyCode = v.villcode.length >= 5 ? v.villcode.substring(0, 5) : null;
    final townCode = v.villcode.length >= 8 ? v.villcode.substring(0, 8) : null;
    return RoomDisplayNameResolver.formatVillageEnglish(
      countyEn: countyCode != null ? AdminNameResolver().county(countyCode)?.en : null,
      townEn: townCode != null ? AdminNameResolver().town(townCode)?.en : null,
      villEng: v.villEng,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.desc,
    required this.children,
  });

  final String title;
  final String desc;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Container(
      padding: const EdgeInsets.all(IgniSpacing.lg),
      decoration: BoxDecoration(
        color: p.bg1,
        border: Border.all(color: p.border1),
        borderRadius: const BorderRadius.all(IgniRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: IgniTypography.titleMedium(p.text0)),
          const SizedBox(height: IgniSpacing.xs),
          Text(desc, style: IgniTypography.bodySmall(p.text2)),
          const SizedBox(height: IgniSpacing.md),
          ...children,
        ],
      ),
    );
  }
}
