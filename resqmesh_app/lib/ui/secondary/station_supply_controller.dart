import 'package:flutter/foundation.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/station_supply_repo.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_models.dart';

/// Stage 2A 拆分：station_supply_screen 的 state + business logic 容器。
class StationSupplyController extends ChangeNotifier {
  StationSupplyController({
    required EventStore eventStore,
    required EventDecoder decoder,
    required StationSupplyRepo repo,
    required EventPublisher publisher,
    required IdentityManager identity,
  })  : _eventStore = eventStore,
        _decoder = decoder,
        _repo = repo,
        _publisher = publisher,
        _identity = identity;

  final EventStore _eventStore;
  final EventDecoder _decoder;
  final StationSupplyRepo _repo;
  final EventPublisher _publisher;
  final IdentityManager _identity;

  bool _disposed = false;
  bool _checked = false;
  bool _authorized = false;
  bool _loading = true;
  List<StationItem> _items = const [];

  bool get authorized => _authorized;
  bool get loading => _loading;
  bool get checked => _checked;
  int get identityLevel => _identity.getIdentityLevel();
  List<StationItem> get items => _items;

  Future<void> checkAccessAndLoad() async {
    final level = _identity.getIdentityLevel();
    if (_disposed) return;
    _authorized = level >= 2;
    _checked = true;
    _loading = false;
    notifyListeners();
    if (_authorized) {
      await loadStationItems();
    }
  }

  Future<void> loadStationItems() async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final allRegisters = await _eventStore.queryResourceRegisters();
    final rows = allRegisters.where((row) {
      final senderKey = row['sender_pub_key'] as Uint8List?;
      if (senderKey == null || senderKey.length != pubKeyBytes.length) return false;
      for (int i = 0; i < pubKeyBytes.length; i++) {
        if (senderKey[i] != pubKeyBytes[i]) return false;
      }
      return true;
    }).toList();

    final items = <StationItem>[];
    for (final row in rows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;
      try {
        final rd = _decoder.decodeResourceData(payload);
        if (rd == null) continue;
        final meta = StationMeta.tryParse(rd.deliveryMode);
        if (meta == null || !meta.isStation) continue;

        final quotas = await _repo.queryStationQuotas(stationId: rd.resourceType);

        items.add(StationItem(
          eventId: row['event_id'] as String,
          resourceId: rd.resourceType,
          resourceType: rd.resourceType,
          quantity: rd.quantity.toDouble(),
          meta: meta,
          quotaRows: quotas,
          hlcTimestamp: row['hlc_timestamp'] as int,
        ));
      } catch (_) {
        continue;
      }
    }

    if (_disposed) return;
    _items = items;
    notifyListeners();
  }

  Future<void> resetStationUsage(String resourceId) =>
      _repo.resetStationUsage(resourceId);

  Future<void> removeStation(String eventId) =>
      _publisher.cancelSupply(eventId);

  Future<void> publishStationSupply({
    required String resourceType,
    required int quantity,
    required StationMeta meta,
  }) {
    return _publisher.publishSupply(
      resourceType: resourceType,
      quantity: quantity,
      maxRangeMeters: 50000,
      deliveryMode: 'STATION:${meta.toJson()}',
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
