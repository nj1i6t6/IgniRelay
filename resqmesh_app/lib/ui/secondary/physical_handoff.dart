import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/handoff_controller.dart';
import 'package:ignirelay_app/app/services/negotiation_repo.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/handoff_dropoff_views.dart';
import 'package:ignirelay_app/ui/secondary/handoff_pin_views.dart';
import 'package:ignirelay_app/ui/secondary/handoff_result_views.dart';
import 'package:ignirelay_app/ui/secondary/physical_handoff_controller.dart';

export 'package:ignirelay_app/ui/secondary/physical_handoff_controller.dart'
    show HandoffRole;

/// Stage 2A：thin shell。state + FSM 在 [PhysicalHandoffController]；
/// 各步驟視圖在 handoff_pin_views / handoff_dropoff_views / handoff_result_views。
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
  final _pinCtrl = TextEditingController();
  PhysicalHandoffController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c ??= PhysicalHandoffController(
      role: widget.role,
      resourceId: widget.resourceId,
      resourceType: widget.resourceType,
      negotiationId: widget.negotiationId,
      method: widget.method,
      requestId: widget.requestId,
      urgency: widget.urgency,
      providerDeviceId: widget.providerDeviceId,
      eventPublisher: context.read<EventPublisher>(),
      handoffController: context.read<HandoffController>(),
      negotiationRepo: context.read<NegotiationRepo>(),
    )..start();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _c?.dispose();
    super.dispose();
  }

  Future<void> _onSubmitPin() async {
    final result = await _c!.submitPin(_pinCtrl.text.trim());
    if (!mounted) return;
    switch (result) {
      case PinSubmitResult.success:
        HapticFeedback.heavyImpact();
        break;
      case PinSubmitResult.wrong:
        HapticFeedback.mediumImpact();
        _pinCtrl.clear();
        break;
      case PinSubmitResult.lockedOut:
        break;
    }
  }

  Future<void> _onCompleteDropOff() async {
    HapticFeedback.heavyImpact();
    await _c!.completeDropOff();
  }

  @override
  Widget build(BuildContext context) {
    if (_c == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0d0d1a),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AnimatedBuilder(
      animation: _c!,
      builder: (context, _) {
        final c = _c!;
        if (c.handoffComplete) {
          return HandoffSuccessView(resourceType: widget.resourceType);
        }
        if (c.handoffCancelled) return const HandoffCancelledView();
        return Scaffold(
          backgroundColor: const Color(0xFF0d0d1a),
          appBar: AppBar(
            title: Text(context.l10n.handoffTitle,
                style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1a1a2e),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _buildStepView(c),
        );
      },
    );
  }

  Widget _buildStepView(PhysicalHandoffController c) {
    final isProvider = widget.role == HandoffRole.provider;
    if (widget.method == 'DROP_OFF') {
      return isProvider
          ? HandoffDropOffProviderView(
              controller: c,
              resourceType: widget.resourceType,
              onComplete: _onCompleteDropOff,
            )
          : HandoffDropOffRequesterView(
              resourceType: widget.resourceType,
              onComplete: _onCompleteDropOff,
            );
    }
    return isProvider
        ? HandoffProviderPinView(
            controller: c,
            resourceType: widget.resourceType,
            urgency: widget.urgency,
          )
        : HandoffRequesterPinView(
            controller: c,
            pinController: _pinCtrl,
            resourceType: widget.resourceType,
            onSubmit: _onSubmitPin,
          );
  }
}
