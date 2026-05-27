import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/match_repository.dart';
import 'package:ignirelay_app/app/services/negotiation_events.dart';
import 'package:ignirelay_app/app/services/negotiation_manager.dart';

/// Stage 2A 拆分：match_screen 的 state + business logic 容器。
///
/// 對齊 `MapScreenController` 模式：state 集中、不持 BuildContext、
/// 透過 outcome stream 通知 widget 顯示 snackbar。
class MatchScreenController extends ChangeNotifier {
  MatchScreenController({
    required EventPublisher eventPublisher,
    required EventStream eventStream,
    required NegotiationManager negotiationManager,
    required MatchRepository repository,
    required IdentityManager identity,
    required LocationService locationService,
  })  : _publisher = eventPublisher,
        _eventStream = eventStream,
        _negotiationManager = negotiationManager,
        _repo = repository,
        _identity = identity,
        _locService = locationService;

  final EventPublisher _publisher;
  final EventStream _eventStream;
  final NegotiationManager _negotiationManager;
  final MatchRepository _repo;
  final IdentityManager _identity;
  final LocationService _locService;

  // ── State ──
  List<DecodedSupply> _mySupplies = const [];
  List<DecodedRequest> _myRequests = const [];
  List<MyPublish> _mySupplyPublishes = const [];
  List<Map<String, dynamic>> _activeNegotiations = const [];
  List<CommunityItem> _communityItems = const [];

  bool _loading = true;
  String? _error;
  String? _gpsWarning;
  Uint8List? _myPubKey;

  List<DecodedSupply> get mySupplies => _mySupplies;
  List<DecodedRequest> get myRequests => _myRequests;
  List<MyPublish> get mySupplyPublishes => _mySupplyPublishes;
  List<Map<String, dynamic>> get activeNegotiations => _activeNegotiations;
  List<CommunityItem> get communityItems => _communityItems;
  bool get loading => _loading;
  String? get error => _error;
  String? get gpsWarning => _gpsWarning;
  Uint8List? get myPubKey => _myPubKey;
  Set<String> get staleNegotiationIds =>
      _negotiationManager.staleNegotiationIds;
  LocationService get locationService => _locService;

  // ── Outcome events (widget 端訂閱以顯示 snackbar / navigation) ──
  final _outcomes = StreamController<MatchOutcome>.broadcast();
  Stream<MatchOutcome> get outcomes => _outcomes.stream;

  StreamSubscription<NegotiationEvent>? _negotiationSub;
  StreamSubscription? _meshEventSub;
  Timer? _meshDebounce;
  bool _disposed = false;

  Future<void> init() async {
    _negotiationSub = _negotiationManager.events.listen(_onNegotiationEvent);
    final gpsFuture = _locService.init();
    final keyFuture = _identity.getPublicKeyBytes();
    final dataFuture = loadAll();
    final results = await Future.wait([gpsFuture, keyFuture, dataFuture]);
    if (_disposed) return;
    _gpsWarning = _locService.unavailableReason;
    _myPubKey = Uint8List.fromList(results[1] as List<int>);
    notifyListeners();
  }

  /// EventStream debounced refresh — widget 在 didChangeDependencies 取得
  /// context.read<EventStream>() 後 attach 一次。
  void attachEventStream() {
    _meshEventSub ??= _eventStream.anyEventChanges.listen((_) {
      _meshDebounce?.cancel();
      _meshDebounce = Timer(const Duration(seconds: 3), () {
        if (!_disposed) loadAll();
      });
    });
  }

  Future<void> loadAll() async {
    if (_disposed) return;
    final wasEmpty = _mySupplies.isEmpty && _myRequests.isEmpty;
    _loading = wasEmpty;
    _error = null;
    notifyListeners();

    try {
      await _negotiationManager.expireStaleNegotiations();

      final results = await Future.wait([
        _repo.getAvailableSupplies(),
        _repo.getMyRequests(),
        _repo.getCommunityItems(),
        _repo.getRequests(),
        _repo.getOthersSupplies(),
        _repo.getMyPublishes(),
      ]);
      if (_disposed) return;

      final allMySupplies = results[0] as List<DecodedSupply>;
      final myRequests = results[1] as List<DecodedRequest>;
      final community = results[2] as List<CommunityItem>;
      final myPublishes = results[5] as List<MyPublish>;

      List<Map<String, dynamic>> activeNeg = const [];
      if (_myPubKey != null) {
        final all = await _negotiationManager.getMyNegotiations(_myPubKey!);
        final active = all.where((n) {
          final s = n['status'] as String;
          return s == 'PENDING' || s == 'ACCEPTED' || s == 'NAVIGATING';
        }).toList();
        // 補上物資名稱 / 配送模式等顯示用 metadata（Match_Negotiations 只存外鍵）。
        activeNeg = await _repo.enrichNegotiations(active);
      }
      if (_disposed) return;

      _mySupplies = allMySupplies;
      _myRequests = myRequests;
      _mySupplyPublishes = myPublishes.where((p) => p.isSupply).toList();
      _communityItems = community;
      _activeNegotiations = activeNeg;
      _loading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[MatchScreen] load failed: $e');
      if (_disposed) return;
      _error = '$e';
      _loading = false;
      notifyListeners();
    }
  }

  void _onNegotiationEvent(NegotiationEvent event) {
    if (_disposed) return;
    loadAll();
    if (event is NegotiationAccepted) {
      _outcomes.add(const MatchOutcome.negotiationAccepted());
    } else if (event is NegotiationDeclined) {
      _outcomes.add(const MatchOutcome.negotiationDeclined());
    } else if (event is NegotiationCancelled) {
      _outcomes.add(const MatchOutcome.negotiationCancelled());
    } else if (event is NegotiationCompleted) {
      _outcomes.add(const MatchOutcome.handoffComplete());
    } else if (event is NegotiationExpired) {
      _outcomes.add(const MatchOutcome.negotiationExpired());
    } else if (event is OversoldDetected) {
      _outcomes.add(const MatchOutcome.oversoldDetected());
    }
  }

  Future<void> cancelSupply(DecodedSupply supply, MyPublish? pub,
      {required String resourceName}) async {
    if (pub == null) return;
    try {
      await _publisher.cancelSupply(pub.eventId);
      _outcomes.add(MatchOutcome.cancelSupplyOk(resourceName));
      await loadAll();
    } catch (e) {
      _outcomes.add(MatchOutcome.cancelFail(e.toString()));
    }
  }

  Future<void> acceptNegotiation(Map<String, dynamic> neg) async {
    final negId = neg['negotiation_id'] as String? ?? '';
    final resourceId = neg['resource_id'] as String? ?? '';
    final requestId = neg['request_id'] as String? ?? '';
    final agreedQty = (neg['offered_qty'] as num?)?.toDouble() ??
        (neg['requested_qty'] as num?)?.toDouble() ??
        0;

    try {
      await _publisher.publishMatchAccept(
        negotiationId: negId,
        resourceId: resourceId,
        requestId: requestId,
        agreedQty: agreedQty,
      );
      _outcomes.add(const MatchOutcome.acceptOk());
      await loadAll();
    } catch (e) {
      _outcomes.add(MatchOutcome.acceptFail(e.toString()));
    }
  }

  Future<void> declineNegotiation(
      String negId, Map<String, dynamic> neg) async {
    final resourceId = neg['resource_id'] as String? ?? '';
    final requestId = neg['request_id'] as String? ?? '';
    try {
      await _publisher.publishMatchDecline(
        negotiationId: negId,
        resourceId: resourceId,
        requestId: requestId,
        reason: 'USER_DECLINED',
      );
      _outcomes.add(const MatchOutcome.declineOk());
      await loadAll();
    } catch (e) {
      _outcomes.add(MatchOutcome.declineFail(e.toString()));
    }
  }

  Future<void> cancelRequest(DecodedRequest request,
      {required String resourceName}) async {
    try {
      await _publisher.cancelRequest(request.eventId);
      _outcomes.add(MatchOutcome.cancelRequestOk(resourceName));
      await loadAll();
    } catch (e) {
      _outcomes.add(MatchOutcome.cancelFail(e.toString()));
    }
  }

  Future<void> cancelNegotiation(Map<String, dynamic> neg) async {
    final negId = neg['negotiation_id'] as String? ?? '';
    final resourceId = neg['resource_id'] as String? ?? '';
    final requestId = neg['request_id'] as String? ?? '';
    try {
      await _publisher.publishMatchCancel(
        negotiationId: negId,
        resourceId: resourceId,
        requestId: requestId,
        reason: 'USER_CANCELLED',
      );
      _outcomes.add(const MatchOutcome.negotiationCancelled());
      await loadAll();
    } catch (e) {
      _outcomes.add(MatchOutcome.cancelFail(e.toString()));
    }
  }

  Future<void> communityAction(
    CommunityItem item,
    int qty, {
    required String resourceName,
    required String communityNote,
  }) async {
    final loc = _locService.currentLocation;
    try {
      if (item.isSupply) {
        final providerPubKey = item.senderPubKey;
        if (item.resourceId.isEmpty ||
            providerPubKey == null ||
            providerPubKey.isEmpty) {
          throw StateError(
              'remote supply is missing resource id or provider key');
        }
        final requestId = await _publisher.publishRequest(
          resourceType: item.resourceType,
          quantity: qty,
          note: communityNote,
          maxRangeMeters: 5000,
          mobilityMode: 'CAN_GO',
          lat: loc?.latitude,
          lng: loc?.longitude,
        );
        await _publisher.publishMatchRequest(
          resourceId: item.resourceId,
          requestId: requestId,
          providerPubKey: providerPubKey,
          requestedQty: qty.toDouble(),
        );
        _outcomes.add(MatchOutcome.communityRequestOk(qty, resourceName));
      } else {
        final requesterPubKey = item.senderPubKey;
        if (item.requestId.isEmpty ||
            requesterPubKey == null ||
            requesterPubKey.isEmpty) {
          throw StateError(
              'remote request is missing request id or requester key');
        }
        final resourceId = await _publisher.publishSupply(
          resourceType: item.resourceType,
          quantity: qty,
          maxRangeMeters: 5000,
          deliveryMode: 'PICKUP',
          lat: loc?.latitude,
          lng: loc?.longitude,
        );
        await _publisher.publishMatchOffer(
          resourceId: resourceId,
          requestId: item.requestId,
          requesterPubKey: requesterPubKey,
          offeredQty: qty.toDouble(),
          matchScore: 100.0,
        );
        _outcomes.add(MatchOutcome.communitySupplyOk(qty, resourceName));
      }
      await loadAll();
    } catch (e) {
      _outcomes.add(MatchOutcome.communityFail(e.toString()));
    }
  }

  /// ACCEPTED → NAVIGATING transition triggered when user opens navigation.
  void startNavigatingIfAccepted(Map<String, dynamic> neg) {
    final status = neg['status'] as String? ?? '';
    final negId = neg['negotiation_id'] as String? ?? '';
    if (status == 'ACCEPTED' && negId.isNotEmpty) {
      _negotiationManager.startNavigating(negId);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _negotiationSub?.cancel();
    _meshEventSub?.cancel();
    _meshDebounce?.cancel();
    _outcomes.close();
    super.dispose();
  }
}

/// Outcome events emitted by [MatchScreenController]. Widget 端對映 l10n + snackbar。
sealed class MatchOutcome {
  const MatchOutcome();

  const factory MatchOutcome.negotiationAccepted() = _OutNegotiationAccepted;
  const factory MatchOutcome.negotiationDeclined() = _OutNegotiationDeclined;
  const factory MatchOutcome.negotiationCancelled() = _OutNegotiationCancelled;
  const factory MatchOutcome.handoffComplete() = _OutHandoffComplete;
  const factory MatchOutcome.negotiationExpired() = _OutNegotiationExpired;
  const factory MatchOutcome.oversoldDetected() = _OutOversoldDetected;
  const factory MatchOutcome.acceptOk() = _OutAcceptOk;
  const factory MatchOutcome.declineOk() = _OutDeclineOk;
  const factory MatchOutcome.cancelSupplyOk(String resourceName) =
      _OutCancelSupplyOk;
  const factory MatchOutcome.cancelRequestOk(String resourceName) =
      _OutCancelRequestOk;
  const factory MatchOutcome.acceptFail(String error) = _OutAcceptFail;
  const factory MatchOutcome.declineFail(String error) = _OutDeclineFail;
  const factory MatchOutcome.cancelFail(String error) = _OutCancelFail;
  const factory MatchOutcome.communityRequestOk(int qty, String resourceName) =
      _OutCommunityRequestOk;
  const factory MatchOutcome.communitySupplyOk(int qty, String resourceName) =
      _OutCommunitySupplyOk;
  const factory MatchOutcome.communityFail(String error) = _OutCommunityFail;
}

class _OutNegotiationAccepted extends MatchOutcome {
  const _OutNegotiationAccepted();
}

class _OutNegotiationDeclined extends MatchOutcome {
  const _OutNegotiationDeclined();
}

class _OutNegotiationCancelled extends MatchOutcome {
  const _OutNegotiationCancelled();
}

class _OutHandoffComplete extends MatchOutcome {
  const _OutHandoffComplete();
}

class _OutNegotiationExpired extends MatchOutcome {
  const _OutNegotiationExpired();
}

class _OutOversoldDetected extends MatchOutcome {
  const _OutOversoldDetected();
}

class _OutAcceptOk extends MatchOutcome {
  const _OutAcceptOk();
}

class _OutDeclineOk extends MatchOutcome {
  const _OutDeclineOk();
}

class _OutCancelSupplyOk extends MatchOutcome {
  const _OutCancelSupplyOk(this.resourceName);
  final String resourceName;
}

class _OutCancelRequestOk extends MatchOutcome {
  const _OutCancelRequestOk(this.resourceName);
  final String resourceName;
}

class _OutAcceptFail extends MatchOutcome {
  const _OutAcceptFail(this.error);
  final String error;
}

class _OutDeclineFail extends MatchOutcome {
  const _OutDeclineFail(this.error);
  final String error;
}

class _OutCancelFail extends MatchOutcome {
  const _OutCancelFail(this.error);
  final String error;
}

class _OutCommunityRequestOk extends MatchOutcome {
  const _OutCommunityRequestOk(this.qty, this.resourceName);
  final int qty;
  final String resourceName;
}

class _OutCommunitySupplyOk extends MatchOutcome {
  const _OutCommunitySupplyOk(this.qty, this.resourceName);
  final int qty;
  final String resourceName;
}

class _OutCommunityFail extends MatchOutcome {
  const _OutCommunityFail(this.error);
  final String error;
}

T whenMatchOutcome<T>(
  MatchOutcome o, {
  required T Function() negotiationAccepted,
  required T Function() negotiationDeclined,
  required T Function() negotiationCancelled,
  required T Function() handoffComplete,
  required T Function() negotiationExpired,
  required T Function() oversoldDetected,
  required T Function() acceptOk,
  required T Function() declineOk,
  required T Function(String resourceName) cancelSupplyOk,
  required T Function(String resourceName) cancelRequestOk,
  required T Function(String error) acceptFail,
  required T Function(String error) declineFail,
  required T Function(String error) cancelFail,
  required T Function(int qty, String resourceName) communityRequestOk,
  required T Function(int qty, String resourceName) communitySupplyOk,
  required T Function(String error) communityFail,
}) {
  return switch (o) {
    _OutNegotiationAccepted() => negotiationAccepted(),
    _OutNegotiationDeclined() => negotiationDeclined(),
    _OutNegotiationCancelled() => negotiationCancelled(),
    _OutHandoffComplete() => handoffComplete(),
    _OutNegotiationExpired() => negotiationExpired(),
    _OutOversoldDetected() => oversoldDetected(),
    _OutAcceptOk() => acceptOk(),
    _OutDeclineOk() => declineOk(),
    _OutCancelSupplyOk(:final resourceName) => cancelSupplyOk(resourceName),
    _OutCancelRequestOk(:final resourceName) => cancelRequestOk(resourceName),
    _OutAcceptFail(:final error) => acceptFail(error),
    _OutDeclineFail(:final error) => declineFail(error),
    _OutCancelFail(:final error) => cancelFail(error),
    _OutCommunityRequestOk(:final qty, :final resourceName) =>
      communityRequestOk(qty, resourceName),
    _OutCommunitySupplyOk(:final qty, :final resourceName) =>
      communitySupplyOk(qty, resourceName),
    _OutCommunityFail(:final error) => communityFail(error),
  };
}
