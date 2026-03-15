import 'package:flutter/material.dart';
import '../mesh/event_manager.dart';

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

  static const _hazardTypes = {
    'ROADBLOCK': ('道路封閉', Icons.block, Colors.orange),
    'FIRE': ('火災', Icons.local_fire_department, Colors.red),
    'CHEMICAL': ('化學/毒氣', Icons.warning_amber, Colors.yellow),
    'FLOOD': ('水災/淹水', Icons.water, Colors.blue),
    'BUILDING': ('建物倒塌', Icons.domain_disabled, Colors.brown),
    'LANDSLIDE': ('土石流', Icons.landscape, Colors.grey),
  };

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      await EventManager().publishHazard(
        type: _selectedType,
        severity: _severity.round(),
        lat: widget.lat,
        lng: widget.lng,
        radiusMeters: _radius,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發布失敗: $e'), backgroundColor: Colors.red),
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
    return AlertDialog(
      backgroundColor: const Color(0xFF1a1a2e),
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('標記危險區域', style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '座標: ${widget.lat.toStringAsFixed(4)}, ${widget.lng.toStringAsFixed(4)}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text('危險類型', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          ..._hazardTypes.entries.map((entry) {
            final (label, icon, color) = entry.value;
            return RadioListTile<String>(
              value: entry.key,
              groupValue: _selectedType,
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
          const Text('嚴重程度', style: TextStyle(color: Colors.white70)),
          Row(
            children: [
              const Text('輕微',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _severity,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: Colors.redAccent,
                  inactiveColor: Colors.white12,
                  label: '${_severity.round()}',
                  onChanged: (v) => setState(() => _severity = v),
                ),
              ),
              const Text('致命',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          // 影響半徑
          const Text('影響半徑', style: TextStyle(color: Colors.white70)),
          Row(
            children: [
              Text('${_radius.round()}m',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _radius,
                  min: 50,
                  max: 2000,
                  divisions: 39,
                  activeColor: Colors.orange,
                  inactiveColor: Colors.white12,
                  label: '${_radius.round()}m',
                  onChanged: (v) => setState(() => _radius = v),
                ),
              ),
              const Text('2km',
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          // 描述
          TextField(
            controller: _descCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '簡述狀況 (選填)',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.orange),
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
          child: const Text('取消', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: _publishing ? null : _publish,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: _publishing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('發布至 Mesh', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
