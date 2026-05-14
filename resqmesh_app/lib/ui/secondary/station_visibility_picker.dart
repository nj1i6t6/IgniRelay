import 'package:flutter/material.dart';

import 'package:ignirelay_app/app/geo/village_geofence.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// Stage 2A 拆分：station_supply 註冊表單中「可見範圍」選擇器。
///
/// 自管理 state（mode、village pick、town display）並透過 [onChanged] 通知
/// parent 最終選擇。
class StationVisibilitySelection {
  final String mode; // 'village' | 'township'
  final List<String> villcodes;
  final String? towncode;

  const StationVisibilitySelection({
    required this.mode,
    required this.villcodes,
    required this.towncode,
  });
}

class StationVisibilityPicker extends StatefulWidget {
  const StationVisibilityPicker({super.key, required this.onChanged});

  final ValueChanged<StationVisibilitySelection> onChanged;

  @override
  State<StationVisibilityPicker> createState() => _StationVisibilityPickerState();
}

class _StationVisibilityPickerState extends State<StationVisibilityPicker> {
  String _mode = 'village';
  List<VillageInfo> _nearby = const [];
  final Set<String> _selectedVillcodes = <String>{};
  String? _selectedTowncode;
  String? _townDisplayName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await VillageGeofence.init();
      final villages = await VillageGeofence.query(25.045, 121.543);
      if (mounted) {
        setState(() {
          _nearby = villages;
          if (villages.isNotEmpty) {
            _selectedVillcodes
              ..clear()
              ..add(villages.first.villcode);
            _selectedTowncode = villages.first.towncode;
            _townDisplayName = '${villages.first.countyName}${villages.first.townName}';
          }
          _loading = false;
        });
        _emit();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _emit();
      }
    }
  }

  void _emit() {
    widget.onChanged(StationVisibilitySelection(
      mode: _mode,
      villcodes: _selectedVillcodes.toList(),
      towncode: _selectedTowncode,
    ));
  }

  void _setMode(String m) {
    setState(() => _mode = m);
    _emit();
  }

  void _toggleVill(String code, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedVillcodes.add(code);
      } else {
        _selectedVillcodes.remove(code);
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _modeCard('village', Icons.location_city, Colors.blueAccent, context.l10n.stationVisibilityVillage, context.l10n.stationVisibilityVillageDesc)),
            const SizedBox(width: 12),
            Expanded(child: _modeCard('township', Icons.map, Colors.greenAccent, context.l10n.stationVisibilityTownship, context.l10n.stationVisibilityTownshipDesc)),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: Colors.orangeAccent, strokeWidth: 2)),
          )
        else if (_mode == 'village')
          _buildVillagePicker(context)
        else
          _buildTownshipDisplay(context),
      ],
    );
  }

  Widget _modeCard(String mode, IconData icon, Color accent, String title, String subtitle) {
    final active = _mode == mode;
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.25) : const Color(0xFF1a1a2e),
          border: Border.all(color: active ? accent : Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? accent : Colors.white54, size: 28),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(color: active ? accent : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: active ? Colors.white54 : Colors.white30, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildVillagePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_nearby.isEmpty)
          Text(context.l10n.stationVisibilityNoVillages, style: const TextStyle(color: Colors.white38, fontSize: 13))
        else
          ..._nearby.map((v) => CheckboxListTile(
                title: Text(v.fullName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text('代碼: ${v.villcode}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                value: _selectedVillcodes.contains(v.villcode),
                activeColor: Colors.blueAccent,
                checkColor: Colors.white,
                onChanged: (val) => _toggleVill(v.villcode, val),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
        const SizedBox(height: 4),
        Text(context.l10n.stationVisibilityVillageNote, style: const TextStyle(color: Colors.white30, fontSize: 11)),
      ],
    );
  }

  Widget _buildTownshipDisplay(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.map, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _townDisplayName ?? context.l10n.stationVisibilityTownNotLocated,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              if (_selectedTowncode != null)
                Text(_selectedTowncode!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(context.l10n.stationVisibilityTownNote, style: const TextStyle(color: Colors.white30, fontSize: 11)),
      ],
    );
  }
}
