import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../crypto/identity_manager.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _identity = IdentityManager();
  final _nicknameCtrl = TextEditingController();
  int _level = 0;
  String _pubKeyHex = '...';
  bool _loading = true;

  static const _badgeColors = [
    Color(0xFF9E9E9E), // L0 Gray
    Color(0xFFCD7F32), // L1 Bronze
    Color(0xFF9E9E9E), // L2 Silver
    Color(0xFFFFD700), // L3 Gold
  ];
  static const _badgeNames = ['匿名 (L0)', '手機驗證 (L1)', '社群背書 (L2)', '政府身分 (L3)'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pubKey = await _identity.getPublicKeyBytes();
    final hex = pubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final level = _identity.getIdentityLevel();
    final prefs = await SharedPreferences.getInstance();
    final savedNick = prefs.getString('nickname') ?? '';
    setState(() {
      _pubKeyHex = hex.substring(0, 16);
      _level = level;
      _nicknameCtrl.text = savedNick;
      _loading = false;
    });
  }

  Future<void> _upgradeToL1() async {
    // 實際環境：發送 SMS OTP → 驗證 → 升級
    // 此處模擬立即升級（後端 stub）
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('手機驗證 (L1)', style: TextStyle(color: Colors.white)),
        content: const Text(
          '後續版本將透過後端 SMS OTP 驗證。\n目前暫時允許手動升級至 L1。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _identity.upgradeIdentityLevel(1);
              setState(() => _level = 1);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已升級至 L1 (銅牌) - 手機驗證')),
                );
              }
            },
            child: const Text('確認升級', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', _nicknameCtrl.text);
    await prefs.setBool('onboarding_done', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    final color = _badgeColors[_level.clamp(0, 3)];
    final badgeName = _badgeNames[_level.clamp(0, 3)];

    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Logo / Badge
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha:0.15),
                  border: Border.all(color: color, width: 3),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha:0.4), blurRadius: 20)
                  ],
                ),
                child: Icon(Icons.shield, color: color, size: 56),
              ),
              const SizedBox(height: 16),
              Text(badgeName,
                  style: TextStyle(
                      color: color, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '裝置 ID: $_pubKeyHex...',
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 32),

              // 標題
              const Text(
                '烽傳 IgniRelay\n離線 Mesh 災難應急系統',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                '無網路時仍可透過 BLE Mesh 組成自組織網路，\n即時傳遞求救與物資配對訊息。',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 32),

              // 暱稱輸入
              TextField(
                controller: _nicknameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '設定你的暱稱（可選）',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.person, color: Colors.white54),
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
              const SizedBox(height: 24),

              // 身分升級
              if (_level == 0)
                OutlinedButton.icon(
                  onPressed: _upgradeToL1,
                  icon:
                      const Icon(Icons.verified_user, color: Color(0xFFCD7F32)),
                  label: const Text('升級至 L1（手機驗證）',
                      style: TextStyle(color: Color(0xFFCD7F32))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCD7F32)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),

              const Spacer(),

              // 開始按鈕
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _complete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    '開始使用烽傳',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }
}
