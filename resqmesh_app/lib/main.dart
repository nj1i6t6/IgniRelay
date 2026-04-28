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
import 'package:ignirelay_app/ui/theme/igni_text_scale.dart';
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
import 'package:ignirelay_app/app/controllers/mesh_runtime_controller.dart';
import 'package:ignirelay_app/app/crdt/hlc.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// 版本字面值（與 pubspec.yaml 的 `version:` 對齊）。
///
/// 沒有引入 `package_info_plus` 是因為 Stage 2 整理依賴清單時已決定避開，
/// 而我們又不希望走「在每個顯示版本的位置都各自寫一次」的舊路。
/// 規範：每次 release bump 同步更新 [kAppVersionName] / [kAppBuildNumber]。
const String kAppVersionName = '0.2.0';
const String kAppBuildNumber = '30';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // BUILD_TIMESTAMP fallback：跟隨 release 節奏更新，HLC 偏差保護用。
  // 正式 build 應透過 `--dart-define=BUILD_TIMESTAMP=$(date +%s%3N)` 注入；
  // 詳見 README「Release build」一節。fallback 設為「靠近今天」即可，
  // 因為 HLC 只用它做「不可低於此基準」的鬆綁判斷，過大反而傷及格 1。
  const buildTimestamp = int.fromEnvironment(
    'BUILD_TIMESTAMP',
    defaultValue: 1777334400000, // 2026-04-28 fallback (v0.2.0)
  );
  HLC.setAppBuildTimestamp(buildTimestamp);
  final transport = TransportFactory.create();
  // UI 層透過 MeshRuntimeController 操作 transport，不直接持有實例。
  MeshRuntimeController.instance.attachTransport(transport);

  // 啟動時自動清 24h 前的 Debug_Logs，避免正式版無限增長。
  // 在 background 跑，不阻塞 UI 啟動。
  unawaited(_purgeOldDebugLogs());

  runApp(IgniRelayApp(transport: transport));
}

Future<void> _purgeOldDebugLogs() async {
  try {
    final n = await DatabaseHelper().purgeDebugLogs();
    if (n > 0) debugPrint('[main] purged $n old debug logs');
  } catch (e) {
    debugPrint('[main] purgeDebugLogs failed: $e');
  }
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

  /// Stage 7-r3：accent 固定 amber，不再讓使用者切換。Profile 設定頁的
  /// `_AccentPicker` 已移除，但若日後產品再需要 multi-brand，這裡可以再開回。
  static void setTextScale(BuildContext context, IgniTextScale scale) {
    context.findAncestorStateOfType<_IgniRelayAppState>()?.setTextScale(scale);
  }

  static IgniTextScale textScaleOf(BuildContext context) {
    return context
            .findAncestorStateOfType<_IgniRelayAppState>()
            ?._textScale ??
        IgniTextScale.standard;
  }

  @override
  State<IgniRelayApp> createState() => _IgniRelayAppState();
}

class _IgniRelayAppState extends State<IgniRelayApp> {
  Locale? _locale;
  // Stage 7-r3：預設改為 light（產品決策：第一次使用較舒適；急難模式仍會
  // 在 build() 動態切回深色高對比）。
  ThemeMode _themeMode = ThemeMode.light;
  IgniTextScale _textScale = IgniTextScale.standard;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_language');
    final themeStr = prefs.getString('app_theme_mode');
    final textScaleStr = prefs.getString('app_text_scale');
    if (!mounted) return;
    setState(() {
      if (code != null) _locale = Locale(code);
      _themeMode = _parseThemeMode(themeStr);
      _textScale = IgniTextScale.parse(textScaleStr);
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
        // Stage 7-r3：未設定過時預設淺色。
        return ThemeMode.light;
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

  void setTextScale(IgniTextScale scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_text_scale', scale.storageKey);
    if (mounted) setState(() => _textScale = scale);
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
            theme: AppTheme.light(),
            darkTheme: inEmergency
                ? AppTheme.emergency()
                : AppTheme.dark(),
            themeMode: themeMode,
            // Stage 7-r3：以 [MediaQuery] 包一層，把使用者設定的字體大小（取代
            // 舊的「密度」）套到整個 widget 樹。系統字體偏好仍會被尊重——
            // 我們是在系統 textScaler 之上再乘一個係數。
            builder: (ctx, child) {
              final base = MediaQuery.textScalerOf(ctx);
              final scaled =
                  TextScaler.linear(base.scale(1.0) * _textScale.factor);
              return MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: scaled),
                child: child ?? const SizedBox.shrink(),
              );
            },
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
                  content: Text(context.l10n.mainBleFailSnack(e.toString())),
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
            Text(ctx.l10n.mainBluetoothDialogTitle, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          ctx.l10n.mainBluetoothDialogContent,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.mainBluetoothDialogCancel, style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.mainBluetoothDialogConfirm),
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
          content: Text(context.l10n.mainPermissionSnack),
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
