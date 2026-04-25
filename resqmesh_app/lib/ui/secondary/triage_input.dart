import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _checkMedicalCard();
  }

  Future<void> _checkMedicalCard() async {
    final pubKey = await IdentityManager().getPublicKeyBytes();
    final json = await DatabaseHelper().getMedicalCard(pubKey);
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.triageTitle,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: S.of(context)!.triageDescHint,
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.redAccent),
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
                  color: _attachMedicalCard
                      ? Colors.redAccent.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _attachMedicalCard
                        ? Colors.redAccent.withValues(alpha: 0.5)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.medical_information,
                      color:
                          _attachMedicalCard ? Colors.redAccent : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        S.of(context)!.triageMedicalCardToggle,
                        style: TextStyle(
                          color: _attachMedicalCard
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      _attachMedicalCard ? S.of(context)!.triageMedicalCardOn : S.of(context)!.triageMedicalCardOff,
                      style: TextStyle(
                        color: _attachMedicalCard
                            ? Colors.redAccent
                            : Colors.white24,
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _submit(2),
              icon: const Icon(Icons.warning, color: Colors.black, size: 18),
              label: Text(S.of(context)!.triageSosYellowButton,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
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
                // Stage 5：鎖定態改用深紫 (0xFF222244) 對齊 dark palette；
                // Colors.grey[800] 在實機上偏褐，與 0xFF0d0d1a 底層撞色。
                color: _isSosRedUnlocked
                    ? Colors.red
                    : _isHolding
                        ? Colors.red
                            .withValues(alpha:0.3 + (3 - _sosCountdown) * 0.2)
                        : const Color(0xFF222244),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isSosRedUnlocked
                      ? Colors.red
                      : Colors.red.withValues(alpha:0.5),
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
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _isSosRedUnlocked
                                ? S.of(context)!.triageSosRedButton
                                : _isHolding
                                    ? S.of(context)!.triageSosRedCountdown(_sosCountdown)
                                    : S.of(context)!.triageSosRedHoldHint,
                            style: const TextStyle(
                              color: Colors.white,
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
