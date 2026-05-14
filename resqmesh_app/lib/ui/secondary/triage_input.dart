import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/services/profile_repo.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/widgets/igni_button.dart';

class TriageInputWidget extends StatefulWidget {
  final Function(int urgencyLevel, String description,
      {bool attachMedicalCard}) onSubmit;
  final double? lat;
  final double? lng;

  const TriageInputWidget({
    super.key,
    required this.onSubmit,
    this.lat,
    this.lng,
  });

  @override
  State<TriageInputWidget> createState() => _TriageInputWidgetState();
}

class _TriageInputWidgetState extends State<TriageInputWidget> {
  final TextEditingController _descController = TextEditingController();
  bool _isSosRedUnlocked = false;
  int _sosCountdown = 3;
  Timer? _holdTimer;
  bool _isHolding = false;
  bool _attachMedicalCard = true;
  bool _hasMedicalCard = false;
  bool _medicalCardChecked = false;
  late final IdentityManager _identity = context.read<IdentityManager>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_medicalCardChecked) {
      _medicalCardChecked = true;
      _checkMedicalCard();
    }
  }

  Future<void> _checkMedicalCard() async {
    final pubKey = await _identity.getPublicKeyBytes();
    final json = await context.read<ProfileRepo>().getMedicalCard(pubKey);
    if (mounted) {
      setState(() {
        _hasMedicalCard = json != null && json.isNotEmpty;
        _attachMedicalCard = _hasMedicalCard;
      });
    }
  }

  void _submit(int urgency) {
    widget.onSubmit(urgency, _descController.text,
        attachMedicalCard: _attachMedicalCard && _hasMedicalCard);
    _descController.clear();
    Navigator.of(context).pop();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (_isSosRedUnlocked) return;
    setState(() {
      _isHolding = true;
      _sosCountdown = 3;
    });

    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _sosCountdown--);
      if (_sosCountdown <= 0) {
        timer.cancel();
        HapticFeedback.heavyImpact();
        setState(() {
          _isSosRedUnlocked = true;
          _isHolding = false;
        });
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_isSosRedUnlocked) return;
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _sosCountdown = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.igni;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: p.border1, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            context.l10n.triageTitle,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: p.text0),
          ),
          const SizedBox(height: 16),
          // Description text field
          TextField(
            controller: _descController,
            style: TextStyle(color: p.text0),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: context.l10n.triageDescHint,
              hintStyle: TextStyle(color: p.text3),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: p.border1),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: p.sos),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 醫療卡附帶開關
          if (_hasMedicalCard)
            GestureDetector(
              onTap: () =>
                  setState(() => _attachMedicalCard = !_attachMedicalCard),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _attachMedicalCard ? p.sosSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _attachMedicalCard
                        ? p.sos.withValues(alpha: 0.5)
                        : p.border0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.medical_information,
                      color: _attachMedicalCard ? p.sos : p.text3,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.triageMedicalCardToggle,
                        style: TextStyle(
                          color: _attachMedicalCard ? p.text0 : p.text2,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      _attachMedicalCard
                          ? context.l10n.triageMedicalCardOn
                          : context.l10n.triageMedicalCardOff,
                      style: TextStyle(
                        color: _attachMedicalCard ? p.sos : p.text3,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          // SOS_YELLOW 求助按鈕
          IgniButton(
            label: context.l10n.triageSosYellowButton,
            onPressed: () => _submit(2),
            variant: IgniButtonVariant.warn,
            icon: Icons.warning,
            fullWidth: true,
            size: IgniButtonSize.large,
          ),
          const SizedBox(height: 12),
          // SOS_RED：真實 3 秒長按倒數解鎖
          GestureDetector(
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                color: _isSosRedUnlocked
                    ? p.sos
                    : _isHolding
                        ? p.sos.withValues(
                            alpha: 0.3 + (3 - _sosCountdown) * 0.2)
                        : p.sosSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isSosRedUnlocked
                      ? p.sos
                      : p.sos.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isSosRedUnlocked ? () => _submit(3) : null,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSosRedUnlocked ? Icons.sos : Icons.lock_outline,
                          // White on solid sos-red when unlocked; p.text0 on
                          // sosSoft/semi-transparent bg to stay readable in
                          // both light and dark themes.
                          color: _isSosRedUnlocked ? Colors.white : p.text0,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _isSosRedUnlocked
                                ? context.l10n.triageSosRedButton
                                : _isHolding
                                    ? context.l10n
                                        .triageSosRedCountdown(_sosCountdown)
                                    : context.l10n.triageSosRedHoldHint,
                            style: TextStyle(
                              color: _isSosRedUnlocked ? Colors.white : p.text0,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _descController.dispose();
    super.dispose();
  }
}
