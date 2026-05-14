import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/physical_handoff_controller.dart';

/// Stage 2A 拆分：PIN 交接的 provider / requester 步驟視圖。
/// 由 [PhysicalHandoffScreen] thin shell 依角色挑選；state 全在 controller。

/// Provider 端：顯示 PIN、等待 requester 輸入。
class HandoffProviderPinView extends StatelessWidget {
  const HandoffProviderPinView({
    super.key,
    required this.controller,
    required this.resourceType,
    required this.urgency,
  });

  final PhysicalHandoffController controller;
  final String resourceType;
  final int urgency;

  @override
  Widget build(BuildContext context) {
    final timeout = urgency >= 2
        ? context.l10n.handoffTimeout30min
        : context.l10n.handoffTimeout4hr;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.qr_code_2, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            context.l10n.handoffProviderResource(resourceType),
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
                controller.pin,
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
}

/// Requester 端：輸入 PIN、錯誤次數 / lockout 提示、送出按鈕。
class HandoffRequesterPinView extends StatefulWidget {
  const HandoffRequesterPinView({
    super.key,
    required this.controller,
    required this.pinController,
    required this.resourceType,
    required this.onSubmit,
  });

  final PhysicalHandoffController controller;
  final TextEditingController pinController;
  final String resourceType;
  final VoidCallback onSubmit;

  @override
  State<HandoffRequesterPinView> createState() =>
      _HandoffRequesterPinViewState();
}

class _HandoffRequesterPinViewState extends State<HandoffRequesterPinView> {
  @override
  void initState() {
    super.initState();
    widget.pinController.addListener(_onPinChanged);
  }

  @override
  void dispose() {
    widget.pinController.removeListener(_onPinChanged);
    super.dispose();
  }

  void _onPinChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
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
            controller: widget.pinController,
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
              onPressed: (c.isLockedOut ||
                      c.waitingForBle ||
                      widget.pinController.text.length < 4)
                  ? null
                  : widget.onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.white12,
              ),
              child: Text(
                context.l10n.handoffRequesterConfirmButton,
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
}
