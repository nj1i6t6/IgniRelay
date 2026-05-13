import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

class HazardDialog extends StatefulWidget {
  final double lat;
  final double lng;

  const HazardDialog({super.key, required this.lat, required this.lng});

  @override
  State<HazardDialog> createState() => _HazardDialogState();
}

class _HazardDialogState extends State<HazardDialog> {
  String _selectedType = 'ROADBLOCK';
  double _severity = 3.0;
  double _radius = 200.0;
  final _descCtrl = TextEditingController();
  bool _publishing = false;

  Map<String, (String, IconData, Color)> _hazardTypes(BuildContext context) => {
    'ROADBLOCK': (context.l10n.mapHazardRoadblock, Icons.block, Colors.orange),
    'FIRE': (context.l10n.mapHazardFire, Icons.local_fire_department, Colors.red),
    'CHEMICAL': (context.l10n.mapHazardChemical, Icons.warning_amber, Colors.yellow),
    'FLOOD': (context.l10n.mapHazardFlood, Icons.water, Colors.blue),
    'BUILDING': (context.l10n.mapHazardCollapse, Icons.domain_disabled, Colors.brown),
    'LANDSLIDE': (context.l10n.mapHazardLandslide, Icons.landscape, Colors.grey),
  };

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      await context.read<EventPublisher>().publishHazard(
        type: _selectedType,
        severity: _severity.round(),
        lat: widget.lat,
        lng: widget.lng,
        radiusMeters: _radius,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        final p = context.igni;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.supplyRegFailSnack(e.toString())), backgroundColor: p.sos),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return AlertDialog(
      backgroundColor: p.bg1,
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: p.warn),
          const SizedBox(width: 8),
          Text(context.l10n.hazardDialogTitle, style: TextStyle(color: p.text0, fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.hazardDialogCoordinate(widget.lat.toStringAsFixed(4), widget.lng.toStringAsFixed(4)),
            style: TextStyle(color: p.text3, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.hazardDialogTypeLabel, style: TextStyle(color: p.text1)),
          const SizedBox(height: 8),
          ..._hazardTypes(context).entries.map((entry) {
            final (label, icon, color) = entry.value;
            return RadioListTile<String>(
              value: entry.key,
              // ignore: deprecated_member_use — pending RadioGroup migration (Stage 7+)
              groupValue: _selectedType,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _selectedType = v!),
              activeColor: color,
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(color: color, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(context.l10n.hazardDialogSeverityLabel, style: TextStyle(color: p.text1)),
          Row(
            children: [
              Text(context.l10n.hazardDialogSeverityMin,
                  style: TextStyle(color: p.text3, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _severity,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: p.sos,
                  inactiveColor: p.border0,
                  label: '${_severity.round()}',
                  onChanged: (v) => setState(() => _severity = v),
                ),
              ),
              Text(context.l10n.hazardDialogSeverityMax,
                  style: TextStyle(color: p.sos, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(context.l10n.hazardDialogRadiusLabel, style: TextStyle(color: p.text1)),
          Row(
            children: [
              Text('${_radius.round()}m',
                  style: TextStyle(color: p.text3, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _radius,
                  min: 50,
                  max: 2000,
                  divisions: 39,
                  activeColor: p.warn,
                  inactiveColor: p.border0,
                  label: '${_radius.round()}m',
                  onChanged: (v) => setState(() => _radius = v),
                ),
              ),
              Text('2km', style: TextStyle(color: p.warn, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          // 描述
          TextField(
            controller: _descCtrl,
            style: TextStyle(color: p.text0, fontSize: 13),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: context.l10n.hazardDialogDescHint,
              hintStyle: TextStyle(color: p.text3, fontSize: 13),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: p.border1),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: p.warn),
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.hazardDialogCancel, style: TextStyle(color: p.text3)),
        ),
        ElevatedButton(
          onPressed: _publishing ? null : _publish,
          style: ElevatedButton.styleFrom(
            backgroundColor: p.warn,
            foregroundColor: Colors.white,
          ),
          child: _publishing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(context.l10n.hazardDialogPublish, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
