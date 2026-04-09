import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../mesh/event_manager.dart';
import '../mesh/native_bridge.dart';
import '../l10n/generated/app_localizations.dart';

enum HandoffRole { provider, requester }

class PhysicalHandoffScreen extends StatefulWidget {
  final HandoffRole role;
  final String resourceId;
  final String? requestId;
  final String resourceType;
  final int urgency;
  final String negotiationId;

  /// 交接方法：'PIN_4DIGIT', 'QR_CODE', 'BLE', 'DROP_OFF'
  final String method;

  /// Requester 模式需要 Provider 的 BLE deviceId
  final String? providerDeviceId;

  const PhysicalHandoffScreen({
    super.key,
    required this.role,
    required this.resourceId,
    required this.resourceType,
    required this.negotiationId,
    this.method = 'PIN_4DIGIT',
    this.requestId,
    this.urgency = 1,
    this.providerDeviceId,
  });

  @override
  State<PhysicalHandoffScreen> createState() => _PhysicalHandoffScreenState();
}

class _PhysicalHandoffScreenState extends State<PhysicalHandoffScreen> {
  final _eventManager = EventManager();
  final _pinCtrl = TextEditingController();

  late final String _pin;
  String get _pinHash => sha256.convert(utf8.encode(_pin)).toString();

  int _wrongAttempts = 0;
  int _totalWrongAttempts = 0;
  bool _isLockedOut = false;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  Timer? _autoRevertTimer;
  bool _handoffComplete = false;
  bool _handoffCancelled = false;
  bool _waitingForBle = false;
  StreamSubscription? _handoffSub;

  // ── DROP_OFF 專用狀態 ──
  bool _dropOffPlaced = false;
  String _dropOffPhotoDesc = '';
  double? _dropOffLat;
  double? _dropOffLng;

  Duration get _pendingTimeout {
    return widget.urgency >= 2
        ? const Duration(minutes: 30)
        : const Duration(hours: 4);
  }

  @override
  void initState() {
    super.initState();
    _pin = (Random().nextInt(9000) + 1000).toString();

    // DROP_OFF 模式不需要 PIN 驗證或 BLE 廣播
    if (widget.method == 'DROP_OFF') return;

    if (widget.role == HandoffRole.provider) {
      _startAutoRevertTimer();
      _startBleHandoffAdvertising();
    }
  }

  /// Provider 端：在 GATT Server 上開啟交接廣播
  Future<void> _startBleHandoffAdvertising() async {
    try {
      await NativeBridge.startHandoffAdvertising(
        resourceId: widget.resourceId,
        pinHash: _pinHash,
      );
      // 監聽來自 Requester 的 BLE 驗證結果
      _handoffSub = NativeBridge.handoffEvents.listen((event) {
        if (event['resourceId'] == widget.resourceId &&
            event['success'] == true) {
          _onBleVerificationSuccess();
        }
      });
    } catch (e) {
      debugPrint('[Handoff] BLE advertising failed: $e');
    }
  }

  void _onBleVerificationSuccess() async {
    if (!mounted || _handoffComplete) return;
    HapticFeedback.heavyImpact();
    await _eventManager.publishHandshakeComplete(
      negotiationId: widget.negotiationId,
      resourceId: widget.resourceId,
      requestId: widget.requestId ?? '',
      providerPubKey: [],
      requesterPubKey: [],
      actualDeliveredQty: 0,
      method: widget.method,
    );
    setState(() => _handoffComplete = true);
    _autoRevertTimer?.cancel();
    _handoffSub?.cancel();
    NativeBridge.stopHandoffAdvertising();
  }

  void _startAutoRevertTimer() {
    _autoRevertTimer = Timer(_pendingTimeout, () async {
      if (!_handoffComplete && mounted) {
        await _eventManager.publishMatchCancel(
          negotiationId: widget.negotiationId,
          resourceId: widget.resourceId,
          requestId: widget.requestId ?? '',
          reason: 'TIMEOUT',
        );
        setState(() => _handoffCancelled = true);
      }
    });
  }

  Future<void> _submitPin() async {
    if (_isLockedOut) return;
    final entered = _pinCtrl.text.trim();

    // 嘗試透過 BLE 跨裝置驗證 PIN
    if (widget.providerDeviceId != null &&
        widget.providerDeviceId!.isNotEmpty) {
      setState(() => _waitingForBle = true);
      try {
        final success = await NativeBridge.sendHandoffPin(
          deviceId: widget.providerDeviceId!,
          resourceId: widget.resourceId,
          pin: entered,
        );
        if (success) {
          HapticFeedback.heavyImpact();
          await _eventManager.publishHandshakeComplete(
            negotiationId: widget.negotiationId,
            resourceId: widget.resourceId,
            requestId: widget.requestId ?? '',
            providerPubKey: [],
            requesterPubKey: [],
            actualDeliveredQty: 0,
            method: widget.method,
          );
          setState(() {
            _handoffComplete = true;
            _waitingForBle = false;
          });
          return;
        } else {
          _handleWrongPin();
          setState(() => _waitingForBle = false);
          return;
        }
      } catch (e) {
        debugPrint('[Handoff] BLE PIN verify failed: $e');
        setState(() => _waitingForBle = false);
        // fallback 到本地驗證
      }
    }

    // 本地驗證 (同裝置 fallback 或無 BLE 時)
    if (entered == _pin) {
      HapticFeedback.heavyImpact();
      await _eventManager.publishHandshakeComplete(
        negotiationId: widget.negotiationId,
        resourceId: widget.resourceId,
        requestId: widget.requestId ?? '',
        providerPubKey: [],
        requesterPubKey: [],
        actualDeliveredQty: 0,
        method: widget.method,
      );
      setState(() => _handoffComplete = true);
      _autoRevertTimer?.cancel();
    } else {
      _handleWrongPin();
    }
  }

  void _handleWrongPin() {
    HapticFeedback.mediumImpact();
    _pinCtrl.clear();
    _wrongAttempts++;
    _totalWrongAttempts++;

    if (_totalWrongAttempts >= 6) {
      _eventManager.publishMatchCancel(
        negotiationId: widget.negotiationId,
        resourceId: widget.resourceId,
        requestId: widget.requestId ?? '',
        reason: 'TOO_MANY_ATTEMPTS',
      );
      setState(() => _handoffCancelled = true);
    } else if (_wrongAttempts >= 3) {
      _startLockout();
    } else {
      setState(() {});
    }
  }

  void _startLockout() {
    _wrongAttempts = 0;
    _lockoutSeconds = 30;
    setState(() => _isLockedOut = true);

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_lockoutSeconds <= 1) {
        t.cancel();
        setState(() {
          _isLockedOut = false;
          _lockoutSeconds = 0;
        });
      } else {
        setState(() => _lockoutSeconds--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_handoffComplete) return _buildSuccess();
    if (_handoffCancelled) return _buildCancelled();

    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: Text(S.of(context)!.handoffTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: widget.method == 'DROP_OFF'
          ? (widget.role == HandoffRole.provider
              ? _buildDropOffProviderView()
              : _buildDropOffRequesterView())
          : (widget.role == HandoffRole.provider
              ? _buildProviderView()
              : _buildRequesterView()),
    );
  }

  Widget _buildProviderView() {
    final timeout = widget.urgency >= 2 ? S.of(context)!.handoffTimeout30min : S.of(context)!.handoffTimeout4hr;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.qr_code_2, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.handoffProviderResource(widget.resourceType),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Text(
            S.of(context)!.handoffProviderPinLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 12),
          // PIN 大字顯示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.black38,
              border: Border.all(color: Colors.amber, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _pin,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha:0.1),
              border: Border.all(color: Colors.orange.withValues(alpha:0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)!.handoffProviderTimeout(timeout),
                    style: const TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.handoffProviderWaiting,
            style: const TextStyle(color: Colors.white30, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context)!.handoffProviderGattNote,
            style: const TextStyle(color: Colors.cyan, fontSize: 11),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
        ],
      ),
    );
  }

  Widget _buildRequesterView() {
    final remaining = 6 - _totalWrongAttempts;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.pin, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.handoffProviderResource(widget.resourceType),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context)!.handoffRequesterPinPrompt,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // PIN 輸入
          TextField(
            controller: _pinCtrl,
            enabled: !_isLockedOut,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              letterSpacing: 16,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: '----',
              hintStyle: const TextStyle(color: Colors.white12, fontSize: 40),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.amber, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.black26,
            ),
          ),
          const SizedBox(height: 16),

          if (_isLockedOut)
            Text(
              S.of(context)!.handoffRequesterLockout(_lockoutSeconds),
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            )
          else if (_wrongAttempts > 0)
            Text(
              S.of(context)!.handoffRequesterWrong(remaining),
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (_isLockedOut || _waitingForBle || _pinCtrl.text.length < 4)
                      ? null
                      : _submitPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.white12,
              ),
              child: Text(
                S.of(context)!.handoffRequesterConfirmButton,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// DROP_OFF 完成時呼叫 publishHandshakeComplete
  Future<void> _completeDropOff() async {
    HapticFeedback.heavyImpact();
    await _eventManager.publishHandshakeComplete(
      negotiationId: widget.negotiationId,
      resourceId: widget.resourceId,
      requestId: widget.requestId ?? '',
      providerPubKey: [],
      requesterPubKey: [],
      actualDeliveredQty: 0,
      method: 'DROP_OFF',
    );
    setState(() => _handoffComplete = true);
  }

  // ── DROP_OFF Provider：放置物資 + GPS + 照片描述 ──
  Widget _buildDropOffProviderView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.inventory_2, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.handoffProviderResource(widget.resourceType),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Text(
            S.of(context)!.handoffDropoffProviderTitle,
            style: const TextStyle(
                color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // GPS 位置選擇
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.of(context)!.handoffDropoffLocationLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.my_location,
                        color: Colors.cyan, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dropOffLat != null
                            ? '${_dropOffLat!.toStringAsFixed(5)}, ${_dropOffLng!.toStringAsFixed(5)}'
                            : S.of(context)!.handoffDropoffUseCurrentLocation,
                        style: TextStyle(
                          color: _dropOffLat != null
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // 使用預設位置（實際可接入定位服務）
                        setState(() {
                          _dropOffLat = 25.045;
                          _dropOffLng = 121.543;
                        });
                      },
                      child: Text(S.of(context)!.handoffDropoffLocateButton,
                          style: const TextStyle(color: Colors.cyan, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 照片描述 (選填)
          TextField(
            onChanged: (v) => _dropOffPhotoDesc = v,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: S.of(context)!.handoffDropoffDescLabel,
              labelStyle: const TextStyle(color: Colors.white54),
              hintText: S.of(context)!.handoffDropoffDescHint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon:
                  const Icon(Icons.photo_camera, color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.amber),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 放置物資按鈕
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _dropOffPlaced
                  ? null
                  : () async {
                      setState(() => _dropOffPlaced = true);
                      await _completeDropOff();
                    },
              icon: _dropOffPlaced
                  ? const Icon(Icons.check, color: Colors.white)
                  : const Icon(Icons.place, color: Colors.white),
              label: Text(
                _dropOffPlaced ? S.of(context)!.handoffDropoffWaitingButton : S.of(context)!.handoffDropoffConfirmButton,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _dropOffPlaced ? Colors.grey[700] : Colors.amber[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── DROP_OFF Requester：單邊確認已取得 ──
  Widget _buildDropOffRequesterView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.inventory_2, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.handoffProviderResource(widget.resourceType),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Text(
            S.of(context)!.handoffDropoffRequesterTitle,
            style: const TextStyle(
                color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 24),
                const SizedBox(height: 8),
                Text(
                  S.of(context)!.handoffDropoffRequesterContent,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 已取得按鈕（單邊確認）
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _completeDropOff,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                S.of(context)!.handoffDropoffRequesterConfirm,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1a0d),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle,
                color: Colors.greenAccent, size: 100),
            const SizedBox(height: 24),
            Text(
              S.of(context)!.handoffSuccessTitle,
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              S.of(context)!.handoffSuccessContent(widget.resourceType),
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
              child: Text(S.of(context)!.handoffSuccessBack, style: const TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelled() {
    return Scaffold(
      backgroundColor: const Color(0xFF1a0d0d),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel, color: Colors.redAccent, size: 100),
            const SizedBox(height: 24),
            Text(
              S.of(context)!.handoffCancelledTitle,
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              S.of(context)!.handoffCancelledContent,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(S.of(context)!.handoffCancelledBack, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _autoRevertTimer?.cancel();
    _handoffSub?.cancel();
    _pinCtrl.dispose();
    if (widget.role == HandoffRole.provider && widget.method != 'DROP_OFF') {
      NativeBridge.stopHandoffAdvertising();
    }
    super.dispose();
  }
}
