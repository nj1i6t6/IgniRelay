import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/app/emergency/emergency_mode_controller.dart';
import 'package:ignirelay_app/ui/secondary/battery_optimization_guide.dart';
import 'package:ignirelay_app/ui/theme/app_theme.dart';
import 'package:ignirelay_app/ui/theme/igni_accent.dart';
import 'package:ignirelay_app/ui/secondary/onboarding_screen.dart';
import 'package:ignirelay_app/ui/screens/design_showcase_screen.dart';
import 'package:ignirelay_app/ui/shell/main_shell.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/geo/village_geofence.dart';
import 'package:ignirelay_app/platform/mesh_transport.dart';
import 'package:ignirelay_app/platform/transport_factory.dart';
import 'package:ignirelay_app/platform/native_bridge.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/chat_service.dart';
import 'package:ignirelay_app/app/crdt/hlc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const buildTimestamp = int.fromEnvironment(
    'BUILD_TIMESTAMP',
    defaultValue: 1712102400000, // 2024-04-03 fallback
  );
  HLC.setAppBuildTimestamp(buildTimestamp);
  runApp(IgniRelayApp(transport: TransportFactory.create()));
}

class IgniRelayApp extends StatefulWidget {
  final MeshTransport transport;
  const IgniRelayApp({super.key, required this.transport});

  static void setLocale(BuildContext context, Locale locale) {
    context.findAncestorStateOfType<_IgniRelayAppState>()?.setLocale(locale);
  }

  static void setThemeMode(BuildContext context, ThemeMode mode) {
    context.findAncestorStateOfType<_IgniRelayAppState>()?.setThemeMode(mode);
  }

  static void setAccent(BuildContext context, IgniAccent accent) {
    context.findAncestorStateOfType<_IgniRelayAppState>()?.setAccent(accent);
  }

  static IgniAccent accentOf(BuildContext context) {
    return context.findAncestorStateOfType<_IgniRelayAppState>()?._accent ??
        IgniAccent.amber;
  }

  @override
  State<IgniRelayApp> createState() => _IgniRelayAppState();
}

class _IgniRelayAppState extends State<IgniRelayApp> {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.dark;
  IgniAccent _accent = IgniAccent.amber;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_language');
    final themeStr = prefs.getString('app_theme_mode');
    final accentStr = prefs.getString('app_accent');
    if (!mounted) return;
    setState(() {
      if (code != null) _locale = Locale(code);
      _themeMode = _parseThemeMode(themeStr);
      _accent = IgniAccent.parse(accentStr);
    });
  }

  static ThemeMode _parseThemeMode(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.dark;
    }
  }

  void setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_mode', mode.name);
    if (mounted) setState(() => _themeMode = mode);
  }

  void setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', locale.languageCode);
    if (mounted) setState(() => _locale = locale);
  }

  void setAccent(IgniAccent accent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_accent', accent.storageKey);
    if (mounted) setState(() => _accent = accent);
  }

  @override
  Widget build(BuildContext context) {
    return Provider<MeshTransport>.value(
      value: widget.transport,
      child: AnimatedBuilder(
        animation: EmergencyModeController.instance,
        builder: (context, _) {
          final inEmergency = EmergencyModeController.instance.isEmergency;
          // 急難模式一律套用高對比主題，忽略 light/dark 偏好以保肌肉記憶。
          final themeMode = inEmergency ? ThemeMode.dark : _themeMode;
          return MaterialApp(
            title: '烽傳 IgniRelay',
            debugShowCheckedModeBanner: false,
            locale: _locale,
            supportedLocales: S.supportedLocales,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              if (_locale != null) return _locale;
              if (locale != null && locale.languageCode == 'zh') {
                return const Locale('zh');
              }
              return const Locale('en');
            },
            theme: AppTheme.light(accent: _accent),
            darkTheme: inEmergency
                ? AppTheme.emergency()
                : AppTheme.dark(accent: _accent),
            themeMode: themeMode,
            routes: {
              // 設計系統預覽頁：計畫 §Stage 2「Debug-only」要求，release build
              // 不註冊此路由以免誤入。kDebugMode 與 kProfileMode 皆視為「非正式」環境。
              if (kDebugMode || kProfileMode)
                '/design-showcase': (_) => const DesignShowcaseScreen(),
            },
            home: const _StartupRouter(),
          );
        },
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
      // ── 階段 1：核心基礎（失敗 = 無法啟動）──
      await DatabaseHelper().database;
      await IdentityManager().initialize();
      await VillageGeofence.init();

      // ── 階段 2：先確定 onboarding 狀態（不依賴後續服務）──
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_done') ?? false;
      if (mounted) {
        setState(() {
          _showOnboarding = !done;
          _initialized = true;
        });
      }

      // ── 階段 3：位置 & 聊天室（個別 try-catch 防止連鎖失敗）──
      try {
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
        await locService.init();
        if (locService.hasLocation && locService.onFirstFix != null) {
          locService.onFirstFix!();
          locService.onFirstFix = null;
        }
      } catch (e) {
        debugPrint('[Init] Location/Chat init failed: $e');
      }

      // ── 階段 4：Mesh 服務（失敗不影響 UI）──
      try {
        EventManager().expireStaleMatches().catchError((_) {});
      } catch (e) {
        debugPrint('[Init] EventManager init failed: $e');
      }

      // ── 階段 5：權限 & BLE ──
      await _requestPermissions();

      bool btOn = false;
      try {
        btOn = await NativeBridge.isBluetoothEnabled();
      } catch (_) {}

      if (!btOn && mounted) {
        await _showBluetoothEnableDialog();
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
                  content: Text(S.of(context)!.mainBleFailSnack(e.toString())),
                  backgroundColor: Colors.red),
            );
          }
        }
      }

      if (Platform.isAndroid) {
        NativeBridge.startMeshForegroundService().catchError((e) {
          debugPrint('[Init] Foreground service failed: $e');
          return false;
        });
      }
    } catch (e) {
      debugPrint('[Init] Startup error: $e');
      if (mounted && !_initialized) {
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
        title: Row(
          children: [
            const Icon(Icons.bluetooth_disabled, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Text(S.of(ctx)!.mainBluetoothDialogTitle, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          S.of(ctx)!.mainBluetoothDialogContent,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.of(ctx)!.mainBluetoothDialogCancel, style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.of(ctx)!.mainBluetoothDialogConfirm),
          ),
        ],
      ),
    );
    if (shouldEnable == true) {
      await NativeBridge.requestBluetoothEnable();
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

    if (Platform.isAndroid) {
      permissions.add(Permission.notification);
    }

    final statuses = await permissions.request();

    final allGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    if (!allGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.mainPermissionSnack),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    return allGranted;
  }

  void _onOnboardingComplete() {
    setState(() => _showOnboarding = false);
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
      final theme = Theme.of(context);
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                S.of(context)?.mainStartupLoading ?? '烽傳 啟動中...',
                style: theme.textTheme.bodyMedium,
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

    return const MainShell();
  }
}
