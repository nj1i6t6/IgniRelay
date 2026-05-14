import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/handoff_controller.dart';
import 'package:ignirelay_app/app/services/negotiation_repo.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/handoff_result_views.dart';
import 'package:ignirelay_app/ui/secondary/physical_handoff_controller.dart';

export 'package:ignirelay_app/ui/secondary/physical_handoff_controller.dart'
    show HandoffRole;

/// Stage 2A：thin shell。state + FSM 在 [PhysicalHandoffController]。
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
        if (_c!.handoffComplete) return HandoffSuccessView(resourceType: widget.resourceType);
        if (_c!.handoffCancelled) return const HandoffCancelledView();
        return Scaffold(
          backgroundColor: const Color(0xFF0d0d1a),
          appBar: AppBar(
            title: Text(context.l10n.handoffTitle, style: const TextStyle(color: Colors.white)),
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
      },
    );
  }

  Widget _buildProviderView() {
    final timeout = widget.urgency >= 2 ? context.l10n.handoffTimeout30min : context.l10n.handoffTimeout4hr;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.qr_code_2, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            context.l10n.handoffProviderResource(widget.resourceType),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Text(
            context.l10n.handoffProviderPinLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 12),
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
                _c!.pin,
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
              color: Colors.orange.withValues(alpha: 0.1),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.handoffProviderTimeout(timeout),
                    style: const TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.handoffProviderWaiting,
            style: const TextStyle(color: Colors.white30, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.handoffProviderGattNote,
            style: const TextStyle(color: Colors.cyan, fontSize: 11),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
        ],
      ),
    );
  }

  Widget _buildRequesterView() {
    final c = _c!;
    final remaining = 6 - c.totalWrongAttempts;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.pin, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            context.l10n.handoffProviderResource(widget.resourceType),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.handoffRequesterPinPrompt,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _pinCtrl,
            enabled: !c.isLockedOut,
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
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (c.isLockedOut)
            Text(
              context.l10n.handoffRequesterLockout(c.lockoutSeconds),
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            )
          else if (c.wrongAttempts > 0)
            Text(
              context.l10n.handoffRequesterWrong(remaining),
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (c.isLockedOut || c.waitingForBle || _pinCtrl.text.length < 4) ? null : _onSubmitPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.white12,
              ),
              child: Text(
                context.l10n.handoffRequesterConfirmButton,
                style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropOffProviderView() {
    final c = _c!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.inventory_2, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          Text(
            context.l10n.handoffProviderResource(widget.resourceType),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.handoffDropoffProviderTitle,
            style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
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
                Text(context.l10n.handoffDropoffLocationLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.cyan, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.dropOffLat != null
                            ? '${c.dropOffLat!.toStringAsFixed(5)}, ${c.dropOffLng!.toStringAsFixed(5)}'
                            : context.l10n.handoffDropoffUseCurrentLocation,
                        style: TextStyle(
                          color: c.dropOffLat != null ? Colors.white : Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => c.setDropOffLocation(25.045, 121.543),
                      child: Text(context.l10n.handoffDropoffLocateButton,
                          style: const TextStyle(color: Colors.cyan, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: c.setDropOffPhotoDesc,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.l10n.handoffDropoffDescLabel,
              labelStyle: const TextStyle(color: Colors.white54),
              hintText: context.l10n.handoffDropoffDescHint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon: const Icon(Icons.photo_camera, color: Colors.white54),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: c.dropOffPlaced ? null : _onCompleteDropOff,
              icon: c.dropOffPlaced
                  ? const Icon(Icons.check, color: Colors.white)
                  : const Icon(Icons.place, color: Colors.white),
              label: Text(
                c.dropOffPlaced ? context.l10n.handoffDropoffWaitingButton : context.l10n.handoffDropoffConfirmButton,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.dropOffPlaced ? Colors.grey[700] : Colors.amber[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropOffRequesterView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.inventory_2, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          Text(
            context.l10n.handoffProviderResource(widget.resourceType),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.handoffDropoffRequesterTitle,
            style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
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
                  context.l10n.handoffDropoffRequesterContent,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _onCompleteDropOff,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                context.l10n.handoffDropoffRequesterConfirm,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
