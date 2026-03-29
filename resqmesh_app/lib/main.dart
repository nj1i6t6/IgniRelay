import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/survival_mode_screen.dart';
import 'ui/map_screen.dart';
import 'ui/match_screen.dart';
import 'ui/chat_list_screen.dart';
import 'ui/onboarding_screen.dart';
import 'ui/battery_optimization_guide.dart';
import 'ui/medical_card_screen.dart';
import 'db/database_helper.dart';
import 'crypto/identity_manager.dart';
import 'mesh/event_manager.dart';
import 'geo/village_geofence.dart';
import 'mesh/mesh_transport.dart';
import 'mesh/mesh_event_handler.dart';
import 'mesh/transport_factory.dart';
import 'mesh/native_bridge.dart';
import 'services/location_service.dart';
import 'services/chat_service.dart';
import 'proto/mesh_protocol.pb.dart' as pb;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 直接 runApp，所有 init 在 _StartupRouter._init() 背景執行
  // 讓 Flutter 第一幀立即渲染 loading 畫面，不黑屏
  runApp(IgniRelayApp(transport: TransportFactory.create()));
}

class IgniRelayApp extends StatelessWidget {
  final MeshTransport transport;
  const IgniRelayApp({super.key, required this.transport});

  @override
  Widget build(BuildContext context) {
    return Provider<MeshTransport>.value(
      value: transport,
      child: MaterialApp(
        title: '烽傳 IgniRelay',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          primaryColor: Colors.red[900],
          scaffoldBackgroundColor: Colors.black,
          colorScheme: const ColorScheme.dark(
            primary: Colors.redAccent,
            secondary: Colors.cyanAccent,
            surface: Color(0xFF1a1a2e),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
          ),
        ),
        home: const _StartupRouter(),
      ),
    );
  }
}

/// 啟動時路由：檢查 onboarding 與權限
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  bool _initialized = false;
  bool _showOnboarding = false;

  late final MeshTransport _transport;

  @override
  void initState() {
    super.initState();
    _transport = Provider.of<MeshTransport>(context, listen: false);
    _init();
  }

  Future<void> _init() async {
    try {
      // 背景初始化（UI 已顯示 loading 畫面）
      await DatabaseHelper().database;
      await IdentityManager().initialize();
      await VillageGeofence.init();
      // GPS 就緒後自動加入所在里聊天室
      final locService = LocationService();
      locService.onFirstFix = () {
        ChatService().autoJoinVillageRoom().then((code) {
          if (code != null) {
            debugPrint('[Init] GPS 就緒，自動加入聊天室: $code');
          }
        }).catchError((e) {
          debugPrint('[Init] 自動加入聊天室失敗: $e');
        });
      };
      await locService.init(); // await 確保權限對話框完成
      // 如果 init 期間已取得定位但 onFirstFix 未觸發（lastKnownPosition 路徑），手動觸發
      if (locService.hasLocation && locService.onFirstFix != null) {
        locService.onFirstFix!();
        locService.onFirstFix = null;
      }

      // 過期配對自動釋放
      EventManager().expireStaleMatches().catchError((_) {});

      // 檢查是否需要 onboarding
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_done') ?? false;

      // ★ 先讓 UI 顯示，不等權限 ★
      // 真機上 permissions.request() 彈系統對話框時可能重建 Activity，
      // 導致 mounted=false，setState 永遠不執行 → 轉圈卡死。
      // 所以先 setState 讓畫面出來，權限對話框疊在上面。
      if (mounted) {
        setState(() {
          _showOnboarding = !done;
          _initialized = true;
        });
      }

      // 權限在 UI 已顯示後才請求（對話框會疊在 onboarding/主畫面上）
      await _requestPermissions();

      // 檢查藍牙硬體是否開啟
      bool btOn = false;
      try {
        btOn = await NativeBridge.isBluetoothEnabled();
      } catch (_) {}

      if (!btOn && mounted) {
        await _showBluetoothEnableDialog();
        // 再次檢查
        try {
          btOn = await NativeBridge.isBluetoothEnabled();
        } catch (_) {}
      }

      if (btOn) {
        try {
          await _transport.initialize();
          await _transport.start();
        } catch (e) {
          debugPrint('[Init] Mesh transport start failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('BLE Mesh 啟動失敗：$e'),
                  backgroundColor: Colors.red),
            );
          }
        }
      }

      // Android: 自動掛載前景服務
      if (Platform.isAndroid) {
        NativeBridge.startMeshForegroundService().catchError((e) {
          debugPrint('[Init] Foreground service failed: $e');
          return false;
        });
      }
    } catch (e) {
      debugPrint('[Init] Startup error: $e');
      // 即使初始化出錯也要讓 UI 顯示，避免永遠黑屏
      if (mounted) {
        setState(() {
          _initialized = true;
          _showOnboarding = true;
        });
      }
    }
  }

  Future<void> _showBluetoothEnableDialog() async {
    if (!mounted) return;
    final shouldEnable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('需要開啟藍牙', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          '烽傳需要藍牙才能建立 Mesh 網路，與周圍裝置交換求救與物資訊號。\n\n請開啟藍牙以啟用離線通訊功能。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('稍後', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('開啟藍牙'),
          ),
        ],
      ),
    );
    if (shouldEnable == true) {
      await NativeBridge.requestBluetoothEnable();
      // 等待藍牙開啟
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<bool> _requestPermissions() async {
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ];

    // Android 13+ 需要通知權限才能顯示前景服務通知
    if (Platform.isAndroid) {
      permissions.add(Permission.notification);
    }

    final statuses = await permissions.request();

    final allGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    if (!allGranted && mounted) {
      // 提示用戶需要權限
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('需要藍牙與位置權限才能啟用 Mesh 網路'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }

    return allGranted;
  }

  void _onOnboardingComplete() {
    setState(() => _showOnboarding = false);
    // Onboarding 完成後，引導電池優化設定
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          BatteryOptimizationGuide.checkAndGuide(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.redAccent),
              SizedBox(height: 16),
              Text(
                '烽傳 啟動中...',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: _onOnboardingComplete,
      );
    }

    return const MainTabController();
  }
}

class MainTabController extends StatefulWidget {
  const MainTabController({super.key});

  @override
  State<MainTabController> createState() => _MainTabControllerState();
}

class _MainTabControllerState extends State<MainTabController> {
  int _currentIndex = 0;
  StreamSubscription? _bleSub;
  final Set<String> _alertedEventIds = {};

  // 使用 IndexedStack 保留各頁面狀態
  final List<Widget> _pages = [
    const MapScreen(),
    const SurvivalModeScreen(),
    const ChatListScreen(),
    const MatchScreen(),
    const _ProfilePage(),
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

  /// 監聯 Mesh 收到的事件，彈出警報或媒合通知
  void _listenForSosAlerts() {
    _bleSub = MeshEventHandler().events.listen((event) {
      if (!mounted) return;
      _checkAndAlertSos(event.data, event.sourceNodeId);
      _checkAndAlertMatch();
    });
  }

  Future<void> _checkAndAlertSos(List<int> data, String deviceId) async {
    // 從 DB 查詢剛收到的高優先級事件
    final db = await DatabaseHelper().database;
    final cutoff = DateTime.now().millisecondsSinceEpoch - 60000; // 最近 1 分鐘
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
        // SOS_RED: 全螢幕警報
        _showSosRedAlert(desc);
      } else if (urgency >= 2) {
        // SOS_YELLOW: SnackBar 提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('收到求助訊號：$desc'),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: '查看地圖',
              textColor: Colors.white,
              onPressed: () => setState(() => _currentIndex = 0),
            ),
          ),
        );
      }
    }
  }

  /// 檢查是否收到媒合意向通知（有人願意提供物資給我）
  Future<void> _checkAndAlertMatch() async {
    final db = await DatabaseHelper().database;
    final cutoff = DateTime.now().millisecondsSinceEpoch - 60000;
    final recentMatch = await db.query(
      'Event_Logs',
      where: 'event_type = 2 AND hlc_timestamp > ?',
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

      try {
        final intent = pb.MatchIntentData.fromBuffer(payload);
        // 只通知需求者（requesterPubKey 匹配本機）
        final reqPubKey = intent.requesterPubKey;
        if (reqPubKey.isEmpty) continue;
        bool isMe = reqPubKey.length == myPubKey.length;
        if (isMe) {
          for (int i = 0; i < myPubKey.length; i++) {
            if (reqPubKey[i] != myPubKey[i]) { isMe = false; break; }
          }
        }
        if (!isMe) continue;

        _alertedEventIds.add(eventId);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('有人願意提供你需要的物資！點擊查看媒合結果。'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: '查看媒合',
              textColor: Colors.white,
              onPressed: () => setState(() => _currentIndex = 3),
            ),
          ),
        );
      } catch (_) {
        // payload 解碼失敗，忽略
      }
    }
  }

  void _showSosRedAlert(String desc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sos, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('緊急求救訊號！',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
                desc.isNotEmpty ? desc : '附近有人發出緊急求救',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '此訊號透過 Mesh 網路傳遞，發送者可能在附近。\n請前往地圖查看位置資訊。',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了', style: TextStyle(color: Colors.white38)),
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
            child: const Text('查看地圖'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      // match_screen 已自帶 FAB，不需外層重複
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0d0d1a),
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey[600],
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: '戰術地圖',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth_outlined),
            activeIcon: Icon(Icons.bluetooth),
            label: 'Mesh 守護',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
            label: '聊天',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.handshake_outlined),
            activeIcon: Icon(Icons.handshake),
            label: '物資媒合',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: '身分信任',
          ),
        ],
      ),
    );
  }
}

/// 身分 / 信任 Profile 頁面
class _ProfilePage extends StatefulWidget {
  const _ProfilePage();

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _identity = IdentityManager();
  final _db = DatabaseHelper();
  int _level = 0;
  String _pubKeyHex = '';
  String _nickname = '';
  bool _hasMedicalCard = false;

  static const _badgeColors = [
    Color(0xFF9E9E9E),
    Color(0xFFCD7F32),
    Color(0xFFB0B0B0),
    Color(0xFFFFD700),
  ];
  static const _badgeNames = ['匿名 (L0)', '手機驗證 (L1)', '社群背書 (L2)', '政府身分 (L3)'];
  static const _badgeDesc = [
    '自動生成 Ed25519 金鑰，無需網路',
    '已綁定手機號碼，信任度提升',
    '已獲 3 位以上用戶背書',
    '已通過 TW FidO 政府身分驗證',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('修改暱稱', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '輸入新暱稱',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.redAccent),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nickname', result);
      setState(() => _nickname = result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.isNotEmpty ? '暱稱已更新為「$result」' : '已清除暱稱'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    }
  }

  Future<void> _load() async {
    final pubKey = await _identity.getPublicKeyBytes();
    final hex = pubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final prefs = await SharedPreferences.getInstance();
    final mcJson = await _db.getMedicalCard(pubKey);
    if (mounted) {
      setState(() {
        _level = _identity.getIdentityLevel();
        _pubKeyHex = hex;
        _nickname = prefs.getString('nickname') ?? '';
        _hasMedicalCard = mcJson != null && mcJson.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final color = _badgeColors[_level.clamp(0, 3)];
    final badgeName = _badgeNames[_level.clamp(0, 3)];
    final badgeDesc = _badgeDesc[_level.clamp(0, 3)];

    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: const Text('身分與信任', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
            const SizedBox(height: 24),
            // 徽章
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20)
                ],
              ),
              child: Icon(Icons.shield, color: color, size: 50),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _editNickname,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _nickname.isNotEmpty ? _nickname : '匿名用戶',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, color: Colors.white38, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(badgeName, style: TextStyle(color: color, fontSize: 14)),
            const SizedBox(height: 8),
            Text(badgeDesc,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('公鑰 (Ed25519)',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    _pubKeyHex.isNotEmpty
                        ? '${_pubKeyHex.substring(0, 16)}...${_pubKeyHex.substring(_pubKeyHex.length - 8)}'
                        : '載入中...',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 背景執行設定按鈕
            if (Platform.isAndroid)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () =>
                    BatteryOptimizationGuide.showGuideManually(context),
                icon: const Icon(Icons.battery_saver, size: 18),
                label:
                    const Text('背景執行 / 電池優化設定', style: TextStyle(fontSize: 13)),
              ),

            const SizedBox(height: 12),

            // 醫療卡按鈕
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const MedicalCardScreen()))
                    .then((saved) {
                  if (saved == true) _load();
                });
              },
              icon: Icon(
                _hasMedicalCard
                    ? Icons.medical_information
                    : Icons.medical_information_outlined,
                size: 18,
              ),
              label: Text(
                _hasMedicalCard ? '編輯醫療卡' : '建立醫療卡',
                style: const TextStyle(fontSize: 13),
              ),
            ),

            const SizedBox(height: 16),

            // 信任升級路徑
            ...[0, 1, 2, 3].map((lvl) {
              final lvlColor = _badgeColors[lvl];
              final isReached = _level >= lvl;
              final isCurrent = _level == lvl;
              final canUpgrade = _level == lvl - 1;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isReached
                      ? lvlColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: isReached ? lvlColor : Colors.white12,
                    width: isCurrent ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReached
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isReached ? lvlColor : Colors.white24,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _badgeNames[lvl],
                      style: TextStyle(
                        color: isReached ? lvlColor : Colors.white38,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    // L0→L1: 允許升級（暫時手動，等後端 SMS OTP）
                    if (canUpgrade && lvl == 1) ...[
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await _identity.upgradeIdentityLevel(1);
                          setState(() => _level = 1);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('已升級至 手機驗證 (L1)（待後端 SMS OTP 串接）')),
                            );
                          }
                        },
                        child: Text(
                          '手機驗證',
                          style: TextStyle(color: lvlColor, fontSize: 12),
                        ),
                      ),
                    ],
                    // L2, L3: 尚未開放
                    if (canUpgrade && lvl >= 2) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '尚未開放',
                          style: TextStyle(color: Colors.white24, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            ],
          ),
        ),
      ),
    );
  }
}
