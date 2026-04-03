import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/proto/mesh_protocol.pb.dart' as pb;

void main() {
  group('Match notification payloads', () {
    test('MatchConfirmData encodes requester/provider pubkeys', () {
      final requesterKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final providerKey = Uint8List.fromList(List.generate(32, (i) => i + 33));

      final confirm = pb.MatchConfirmData()
        ..requestId = 'req-1'
        ..resourceId = 'res-1'
        ..requesterPubKey = requesterKey
        ..providerPubKey = providerKey;

      final decoded = pb.MatchConfirmData.fromBuffer(confirm.writeToBuffer());
      expect(decoded.requestId, equals('req-1'));
      expect(decoded.resourceId, equals('res-1'));
      expect(decoded.requesterPubKey, equals(requesterKey));
      expect(decoded.providerPubKey, equals(providerKey));
    });

    test('MatchRejectData preserves reason and pubkeys', () {
      final requesterKey = Uint8List.fromList(List.generate(32, (i) => i + 5));
      final providerKey = Uint8List.fromList(List.generate(32, (i) => i + 50));

      final reject = pb.MatchRejectData()
        ..requestId = 'req-2'
        ..resourceId = 'res-2'
        ..requesterPubKey = requesterKey
        ..providerPubKey = providerKey
        ..reason = 'REQUEST_UNAVAILABLE';

      final decoded = pb.MatchRejectData.fromBuffer(reject.writeToBuffer());
      expect(decoded.reason, equals('REQUEST_UNAVAILABLE'));
      expect(decoded.requesterPubKey, equals(requesterKey));
      expect(decoded.providerPubKey, equals(providerKey));
    });
  });
}
