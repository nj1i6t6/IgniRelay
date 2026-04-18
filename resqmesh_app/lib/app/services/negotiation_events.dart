/// NegotiationEvent — UI 訂閱用的事件類型
/// UI 層透過 NegotiationManager.events Stream 監聽這些事件
/// 屬於 Application Layer，不包含任何 UI/Widget 依賴
sealed class NegotiationEvent {
  final String negotiationId;
  const NegotiationEvent(this.negotiationId);
}

class NegotiationCreated extends NegotiationEvent {
  final String resourceId;
  final String requestId;
  final String initiatorRole;
  final double offeredQty;
  final double requestedQty;
  const NegotiationCreated({
    required String negotiationId,
    required this.resourceId,
    required this.requestId,
    required this.initiatorRole,
    required this.offeredQty,
    required this.requestedQty,
  }) : super(negotiationId);
}

class NegotiationAccepted extends NegotiationEvent {
  final double agreedQty;
  final String resourceId;
  final String requestId;
  const NegotiationAccepted({
    required String negotiationId,
    required this.agreedQty,
    required this.resourceId,
    required this.requestId,
  }) : super(negotiationId);
}

class NegotiationDeclined extends NegotiationEvent {
  final String reason;
  const NegotiationDeclined({
    required String negotiationId,
    required this.reason,
  }) : super(negotiationId);
}

class NegotiationCancelled extends NegotiationEvent {
  final String reason;
  const NegotiationCancelled({
    required String negotiationId,
    required this.reason,
  }) : super(negotiationId);
}

class NegotiationCompleted extends NegotiationEvent {
  final double actualQty;
  const NegotiationCompleted({
    required String negotiationId,
    required this.actualQty,
  }) : super(negotiationId);
}

class NegotiationExpired extends NegotiationEvent {
  const NegotiationExpired({required String negotiationId})
      : super(negotiationId);
}

class NegotiationNavigating extends NegotiationEvent {
  const NegotiationNavigating({required String negotiationId})
      : super(negotiationId);
}

class OversoldDetected extends NegotiationEvent {
  final String resourceId;
  final List<String> affectedIds;
  const OversoldDetected({
    required this.resourceId,
    required this.affectedIds,
  }) : super('');
}

class LocationUpdated extends NegotiationEvent {
  final double lat;
  final double lng;
  final bool isProvider;
  const LocationUpdated({
    required String negotiationId,
    required this.lat,
    required this.lng,
    required this.isProvider,
  }) : super(negotiationId);
}
