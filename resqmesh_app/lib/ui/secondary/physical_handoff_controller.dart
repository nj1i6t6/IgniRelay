import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/handoff_controller.dart';
import 'package:ignirelay_app/app/services/negotiation_repo.dart';

enum HandoffRole { provider, requester }

/// 依「身分」判定交接角色：本機公鑰 == 協商的 provider 公鑰 → [HandoffRole.provider]
/// （顯示 / 廣播 PIN），否則 [HandoffRole.requester]（輸入 PIN）。
///
/// 不可改用 deliveryMode 判定：deliveryMode 只描述「誰移動」，與「誰是供給方」無關。
/// 過去導航頁用 deliveryMode 判角色，而開導航時 deliveryMode 被塞成空字串，導致
/// 雙方都落入 requester、沒人顯示 PIN、PIN 永遠對不上、handshakeComplete(type16)
/// 永不送出，協商卡在 NAVIGATING 到不了 COMPLETED（Bug #2）。
HandoffRole handoffRoleForIdentity({
  required List<int>? myPubKey,
  required List<int>? providerPubKey,
}) {
  if (myPubKey != null &&
      providerPubKey != null &&
      myPubKey.isNotEmpty &&
      myPubKey.length == providerPubKey.length) {
    var equal = true;
    for (var i = 0; i < myPubKey.length; i++) {
      if (myPubKey[i] != providerPubKey[i]) {
        equal = false;
        break;
      }
    }
    if (equal) return HandoffRole.provider;
  }
  return HandoffRole.requester;
}

/// Stage 2A 拆分：physical_handoff_screen 的 FSM + business logic 容器。
///
/// 狀態機：[HandoffFsm.idle] → confirming → completing → done | failed
/// 對應原 god file 的 `_handoffComplete`/`_handoffCancelled`/PIN/BLE flow。
enum HandoffFsm { idle, completing, done, failed }

class PhysicalHandoffController extends ChangeNotifier {
  PhysicalHandoffController({
    required this.role,
    required this.resourceId,
    required this.resourceType,
    required this.negotiationId,
    required this.method,
    required this.requestId,
    required this.urgency,
    required this.providerDeviceId,
    required EventPublisher eventPublisher,
    required HandoffController handoffController,
    required NegotiationRepo negotiationRepo,
  })  : _publisher = eventPublisher,
        _handoff = handoffController,
        _negotiationRepo = negotiationRepo,
        _pin = (Random().nextInt(9000) + 1000).toString();

  final HandoffRole role;
  final String resourceId;
  final String resourceType;
  final String negotiationId;
  final String method;
  final String? requestId;
  final int urgency;
  final String? providerDeviceId;

  final EventPublisher _publisher;
  final HandoffController _handoff;
  final NegotiationRepo _negotiationRepo;

  final String _pin;
  String get pin => _pin;
  String get pinHash => sha256.convert(utf8.encode(_pin)).toString();

  HandoffFsm _state = HandoffFsm.idle;
  HandoffFsm get state => _state;
  bool get handoffComplete => _state == HandoffFsm.done;
  bool get handoffCancelled => _state == HandoffFsm.failed;

  int _wrongAttempts = 0;
  int _totalWrongAttempts = 0;
  bool _isLockedOut = false;
  int _lockoutSeconds = 0;
  bool _waitingForBle = false;

  // DROP_OFF state
  bool _dropOffPlaced = false;
  String _dropOffPhotoDesc = '';
  double? _dropOffLat;
  double? _dropOffLng;

  int get wrongAttempts => _wrongAttempts;
  int get totalWrongAttempts => _totalWrongAttempts;
  bool get isLockedOut => _isLockedOut;
  int get lockoutSeconds => _lockoutSeconds;
  bool get waitingForBle => _waitingForBle;
  bool get dropOffPlaced => _dropOffPlaced;
  String get dropOffPhotoDesc => _dropOffPhotoDesc;
  double? get dropOffLat => _dropOffLat;
  double? get dropOffLng => _dropOffLng;

  Timer? _lockoutTimer;
  Timer? _autoRevertTimer;
  StreamSubscription? _handoffSub;
  bool _disposed = false;

  Duration get pendingTimeout =>
      urgency >= 2 ? const Duration(minutes: 30) : const Duration(hours: 4);

  /// 由 widget initState 呼叫。
  void start() {
    if (method == 'DROP_OFF') return;
    if (role == HandoffRole.provider) {
      _startAutoRevertTimer();
      _startBleHandoffAdvertising();
    }
  }

  Future<void> _startBleHandoffAdvertising() async {
    try {
      await _handoff.startAdvertising(resourceId: resourceId, pinHash: pinHash);
      _handoffSub = _handoff.events.listen((event) {
        if (event['resourceId'] == resourceId && event['success'] == true) {
          _onBleVerificationSuccess();
        }
      });
    } catch (e) {
      debugPrint('[Handoff] BLE advertising failed: $e');
    }
  }

  Future<void> _onBleVerificationSuccess() async {
    if (_disposed || _state == HandoffFsm.done) return;
    await _publishHandshakeFromNegotiation();
    _state = HandoffFsm.done;
    _autoRevertTimer?.cancel();
    _handoffSub?.cancel();
    _handoff.stopAdvertising();
    notifyListeners();
  }

  void _startAutoRevertTimer() {
    _autoRevertTimer = Timer(pendingTimeout, () async {
      if (_disposed || _state == HandoffFsm.done) return;
      await _publisher.publishMatchCancel(
        negotiationId: negotiationId,
        resourceId: resourceId,
        requestId: requestId ?? '',
        reason: 'TIMEOUT',
      );
      if (_disposed) return;
      _state = HandoffFsm.failed;
      notifyListeners();
    });
  }

  /// Stage 6 (commit #10)：從 `Match_Negotiations` 讀回真實值（若 row 不在 / 欄位為 null
  /// 則 fallback 為空 list / 0；publishHandshakeComplete 對 fallback 不會崩）。
  Future<void> _publishHandshakeFromNegotiation({String? overrideMethod}) async {
    List<int> providerPubKey = const [];
    List<int> requesterPubKey = const [];
    double deliveredQty = 0;
    try {
      final row = await _negotiationRepo.getById(negotiationId);
      if (row != null) {
        final pBlob = row['provider_pub_key'];
        if (pBlob is Uint8List) providerPubKey = pBlob.toList();
        final rBlob = row['requester_pub_key'];
        if (rBlob is Uint8List) requesterPubKey = rBlob.toList();
        deliveredQty =
            (row['actual_delivered_qty'] as num?)?.toDouble() ??
                (row['agreed_qty'] as num?)?.toDouble() ??
                (row['offered_qty'] as num?)?.toDouble() ??
                0.0;
      }
    } catch (e) {
      debugPrint('[Handoff] negotiation lookup failed: $e — fallback to empties');
    }
    await _publisher.publishHandshakeComplete(
      negotiationId: negotiationId,
      resourceId: resourceId,
      requestId: requestId ?? '',
      providerPubKey: providerPubKey,
      requesterPubKey: requesterPubKey,
      actualDeliveredQty: deliveredQty,
      method: overrideMethod ?? method,
    );
  }

  /// Requester 端：submit PIN。回傳 [PinSubmitResult]，widget 端決定 haptic / UI。
  Future<PinSubmitResult> submitPin(String entered) async {
    if (_isLockedOut) return PinSubmitResult.lockedOut;

    if (providerDeviceId != null && providerDeviceId!.isNotEmpty) {
      _waitingForBle = true;
      notifyListeners();
      try {
        final success = await _handoff.sendPin(
          deviceId: providerDeviceId!,
          resourceId: resourceId,
          pin: entered,
        );
        if (_disposed) return PinSubmitResult.success;
        if (success) {
          await _publishHandshakeFromNegotiation();
          if (_disposed) return PinSubmitResult.success;
          _state = HandoffFsm.done;
          _waitingForBle = false;
          notifyListeners();
          return PinSubmitResult.success;
        } else {
          _waitingForBle = false;
          _handleWrongPin();
          return PinSubmitResult.wrong;
        }
      } catch (e) {
        debugPrint('[Handoff] BLE PIN verify failed: $e');
        if (_disposed) return PinSubmitResult.wrong;
        _waitingForBle = false;
        notifyListeners();
      }
    }

    // Stage 6-fix：BLE 不可達或 deviceId 缺失時，視為輸入錯誤並走 _handleWrongPin。
    // 詳見原檔註解 L202-L213。
    _handleWrongPin();
    return PinSubmitResult.wrong;
  }

  void _handleWrongPin() {
    _wrongAttempts++;
    _totalWrongAttempts++;

    if (_totalWrongAttempts >= 6) {
      _publisher.publishMatchCancel(
        negotiationId: negotiationId,
        resourceId: resourceId,
        requestId: requestId ?? '',
        reason: 'TOO_MANY_ATTEMPTS',
      );
      _state = HandoffFsm.failed;
    } else if (_wrongAttempts >= 3) {
      _startLockout();
    }
    notifyListeners();
  }

  void _startLockout() {
    _wrongAttempts = 0;
    _lockoutSeconds = 30;
    _isLockedOut = true;
    notifyListeners();

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      if (_lockoutSeconds <= 1) {
        t.cancel();
        _isLockedOut = false;
        _lockoutSeconds = 0;
      } else {
        _lockoutSeconds--;
      }
      notifyListeners();
    });
  }

  void setDropOffLocation(double lat, double lng) {
    _dropOffLat = lat;
    _dropOffLng = lng;
    notifyListeners();
  }

  void setDropOffPhotoDesc(String value) {
    _dropOffPhotoDesc = value;
    // 不 notifyListeners — TextField 自己管 cursor。
  }

  /// DROP_OFF 完成（單邊確認）：publish handshake complete + 轉 done。
  Future<void> completeDropOff() async {
    if (_dropOffPlaced && role == HandoffRole.provider) return;
    _dropOffPlaced = true;
    notifyListeners();
    await _publishHandshakeFromNegotiation(overrideMethod: 'DROP_OFF');
    if (_disposed) return;
    _state = HandoffFsm.done;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _lockoutTimer?.cancel();
    _autoRevertTimer?.cancel();
    _handoffSub?.cancel();
    if (role == HandoffRole.provider && method != 'DROP_OFF') {
      _handoff.stopAdvertising();
    }
    super.dispose();
  }
}

enum PinSubmitResult { success, wrong, lockedOut }
