import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;

class RequestData {
  final String resourceType;
  final int quantity;
  final String note;
  final String mobilityMode;
  RequestData(
      {required this.resourceType,
      required this.quantity,
      required this.note,
      required this.mobilityMode});
}

class MatchOfferData {
  final String resourceId;
  final String requestId;
  final List<int> providerPubKey;
  final List<int> requesterPubKey;
  final double offeredQty;
  final double matchScore;
  MatchOfferData(
      {required this.resourceId,
      required this.requestId,
      required this.providerPubKey,
      required this.requesterPubKey,
      required this.offeredQty,
      required this.matchScore});
}

class MatchRequestData {
  final String resourceId;
  final String requestId;
  final List<int> providerPubKey;
  final double requestedQty;
  MatchRequestData(
      {required this.resourceId,
      required this.requestId,
      required this.providerPubKey,
      required this.requestedQty});
}

class ResourceData {
  final String resourceType;
  final int quantity;
  final String unit;
  final String deliveryMode;
  ResourceData(
      {required this.resourceType,
      required this.quantity,
      required this.unit,
      required this.deliveryMode});
}

class HazardDataDecoded {
  final String hazardId;
  final String hazardType;
  final int severity;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final int observedAt;
  final String description;
  final bool isConfirmation;
  HazardDataDecoded({
    required this.hazardId,
    required this.hazardType,
    required this.severity,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.observedAt,
    required this.description,
    required this.isConfirmation,
  });
}

class MatchOfferDecoded {
  final String negotiationId;
  final String resourceId;
  final String requestId;
  final double agreedQty;
  MatchOfferDecoded(
      {required this.negotiationId,
      required this.resourceId,
      required this.requestId,
      required this.agreedQty});
}

class MatchDeclineDecoded {
  final String negotiationId;
  final String resourceId;
  final String requestId;
  final String reason;
  MatchDeclineDecoded(
      {required this.negotiationId,
      required this.resourceId,
      required this.requestId,
      required this.reason});
}

class HandshakeCompleteDecoded {
  final String negotiationId;
  final String resourceId;
  final String requestId;
  final List<int> providerPubKey;
  final List<int> requesterPubKey;
  final double actualDeliveredQty;
  final String method;
  HandshakeCompleteDecoded({
    required this.negotiationId,
    required this.resourceId,
    required this.requestId,
    required this.providerPubKey,
    required this.requesterPubKey,
    required this.actualDeliveredQty,
    required this.method,
  });
}

class MatchCancelDecoded {
  final String negotiationId;
  final String resourceId;
  final String requestId;
  final String reason;
  MatchCancelDecoded({
    required this.negotiationId,
    required this.resourceId,
    required this.requestId,
    required this.reason,
  });
}

class EventDecoder {
  EventDecoder();

  RequestData? decodeRequestData(List<int> payload) {
    try {
      final pb.RequestData rd = pb.RequestData.fromBuffer(payload);
      return RequestData(
        resourceType: rd.resourceType,
        quantity: rd.quantityNeeded.toInt(),
        note: rd.note,
        mobilityMode: rd.mobilityMode,
      );
    } catch (_) {
      return null;
    }
  }

  MatchOfferData? decodeMatchOfferData(List<int> payload) {
    try {
      final pb.MatchOfferData d = pb.MatchOfferData.fromBuffer(payload);
      return MatchOfferData(
        resourceId: d.resourceId,
        requestId: d.requestId,
        providerPubKey: d.providerPubKey,
        requesterPubKey: d.requesterPubKey,
        offeredQty: d.offeredQty,
        matchScore: d.matchScore,
      );
    } catch (_) {
      return null;
    }
  }

  MatchRequestData? decodeMatchRequestData(List<int> payload) {
    try {
      final pb.MatchRequestData d = pb.MatchRequestData.fromBuffer(payload);
      return MatchRequestData(
        resourceId: d.resourceId,
        requestId: d.requestId,
        providerPubKey: d.providerPubKey,
        requestedQty: d.requestedQty,
      );
    } catch (_) {
      return null;
    }
  }

  ResourceData? decodeResourceData(List<int> payload) {
    try {
      final pb.ResourceData d = pb.ResourceData.fromBuffer(payload);
      return ResourceData(
        resourceType: d.resourceType,
        quantity: d.quantity.toInt(),
        unit: d.unit,
        deliveryMode: d.deliveryMode,
      );
    } catch (_) {
      return null;
    }
  }

  HazardDataDecoded? decodeHazardData(List<int> payload) {
    try {
      final pb.HazardData d = pb.HazardData.fromBuffer(payload);
      return HazardDataDecoded(
        hazardId: d.hazardId,
        hazardType: d.hazardType,
        severity: d.severity,
        centerLat: d.centerLat,
        centerLng: d.centerLng,
        radiusMeters: d.radiusMeters,
        observedAt: d.observedAt.toInt(),
        description: d.description,
        isConfirmation: d.isConfirmation,
      );
    } catch (_) {
      return null;
    }
  }

  MatchOfferDecoded? decodeMatchAccept(List<int> payload) {
    try {
      final pb.MatchAcceptData d = pb.MatchAcceptData.fromBuffer(payload);
      return MatchOfferDecoded(
        negotiationId: d.negotiationId,
        resourceId: d.resourceId,
        requestId: d.requestId,
        agreedQty: d.agreedQty,
      );
    } catch (_) {
      return null;
    }
  }

  MatchDeclineDecoded? decodeMatchDecline(List<int> payload) {
    try {
      final pb.MatchDeclineData d = pb.MatchDeclineData.fromBuffer(payload);
      return MatchDeclineDecoded(
        negotiationId: d.negotiationId,
        resourceId: d.resourceId,
        requestId: d.requestId,
        reason: d.reason,
      );
    } catch (_) {
      return null;
    }
  }

  HandshakeCompleteDecoded? decodeHandshakeComplete(List<int> payload) {
    try {
      final pb.HandshakeCompleteData d =
          pb.HandshakeCompleteData.fromBuffer(payload);
      return HandshakeCompleteDecoded(
        negotiationId: d.negotiationId,
        resourceId: d.resourceId,
        requestId: d.requestId,
        providerPubKey: d.providerPubKey,
        requesterPubKey: d.requesterPubKey,
        actualDeliveredQty: d.actualDeliveredQty,
        method: d.method,
      );
    } catch (_) {
      return null;
    }
  }

  MatchCancelDecoded? decodeMatchCancel(List<int> payload) {
    try {
      final pb.MatchCancelData d = pb.MatchCancelData.fromBuffer(payload);
      return MatchCancelDecoded(
        negotiationId: d.negotiationId,
        resourceId: d.resourceId,
        requestId: d.requestId,
        reason: d.reason,
      );
    } catch (_) {
      return null;
    }
  }

  Object? decodeByType(int eventType, List<int> payload) {
    switch (eventType) {
      case EventType.resourceRegister:
        return decodeResourceData(payload);
      case EventType.requestBroadcast:
        return decodeRequestData(payload);
      case EventType.hazardMarker:
        return decodeHazardData(payload);
      case EventType.matchOffer:
        return decodeMatchOfferData(payload);
      case EventType.matchRequest:
        return decodeMatchRequestData(payload);
      case EventType.matchAccept:
        return decodeMatchAccept(payload);
      case EventType.matchDecline:
        return decodeMatchDecline(payload);
      case EventType.matchCancel:
        return decodeMatchCancel(payload);
      case EventType.handshakeComplete:
        return decodeHandshakeComplete(payload);
      default:
        return null;
    }
  }
}
