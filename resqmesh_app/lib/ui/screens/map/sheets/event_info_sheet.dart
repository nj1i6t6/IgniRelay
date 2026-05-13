import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:ignirelay_app/app/data/supply_category_data.dart';
import 'package:provider/provider.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// Stage 4d Round 2：Mesh 事件詳情 BottomSheet。
///
/// 原位：`map_screen.dart` 原 `_showEventInfo`（L1360-1510）。純顯示；
/// 需要使用者座標才能計算距離，由 caller 以 prop 傳入，避免耦合
/// `_MapScreenState`。
///
/// 使用：`EventInfoSheet.show(context, evt, userLocation: _userLocation)`。
class EventInfoSheet {
  EventInfoSheet._();

  static void show(
    BuildContext context,
    Map<String, dynamic> evt, {
    required LatLng? userLocation,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.igni.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          _EventInfoSheetBody(evt: evt, userLocation: userLocation),
    );
  }
}

class _EventInfoSheetBody extends StatelessWidget {
  const _EventInfoSheetBody({required this.evt, required this.userLocation});

  final Map<String, dynamic> evt;
  final LatLng? userLocation;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final eventType = (evt['event_type'] as int?) ?? 0;
    final urgency = (evt['urgency'] as int?) ?? 0;
    final hlcTs = (evt['hlc_timestamp'] as int?) ?? 0;
    final lat = (evt['received_lat'] as num?)?.toDouble() ?? 0;
    final lng = (evt['received_lng'] as num?)?.toDouble() ?? 0;
    final eventId = (evt['event_id'] as String?) ?? '';

    final l = context.l10n;

    // 事件類型（顏色用 palette 對應，淺/深主題下都仍可讀）
    String typeName;
    IconData typeIcon;
    Color typeColor;
    switch (eventType) {
      case 0:
        typeName = l.mapEventTypeSupply;
        typeIcon = Icons.inventory_2;
        typeColor = p.ok;
        break;
      case 1:
        typeName = l.mapEventTypeRequest;
        typeIcon = Icons.volunteer_activism;
        typeColor = p.warn;
        break;
      default:
        typeName = l.mapEventTypeUnknown(eventType);
        typeIcon = Icons.info_outline;
        typeColor = p.info;
    }

    // 緊急度
    String urgencyLabel;
    Color urgencyColor;
    switch (urgency) {
      case 3:
        urgencyLabel = l.mapEventSosRed;
        urgencyColor = p.sos;
        break;
      case 2:
        urgencyLabel = l.mapEventSosYellow;
        urgencyColor = p.warn;
        break;
      case 1:
        urgencyLabel = l.mapEventSupply;
        urgencyColor = p.ok;
        break;
      default:
        urgencyLabel = l.mapEventInfo;
        urgencyColor = p.info;
    }

    // 時間
    String timeAgo = '';
    if (hlcTs > 0) {
      final diff = DateTime.now().millisecondsSinceEpoch - hlcTs;
      final mins = diff ~/ 60000;
      if (mins < 60) {
        timeAgo = l.mapTimeAgoMinutes(mins);
      } else if (mins < 1440) {
        timeAgo = l.mapTimeAgoHours(mins ~/ 60);
      } else {
        timeAgo = l.mapTimeAgoDays(mins ~/ 1440);
      }
    }

    // 解析 payload
    String payloadDesc = '';
    final payload = evt['payload'] as Uint8List?;
    if (payload != null) {
      try {
        if (eventType == 0) {
          final rd = context.read<EventDecoder>().decodeResourceData(payload);
          if (rd != null) {
            payloadDesc = l.mapPayloadQtyUnit(
                getLocalizedReadableName(rd.resourceType, context),
                rd.quantity,
                rd.unit);
          }
        } else if (eventType == 1) {
          final rd = context.read<EventDecoder>().decodeRequestData(payload);
          if (rd != null) {
            payloadDesc = l.mapPayloadQtyPcs(
                getLocalizedReadableName(rd.resourceType, context),
                rd.quantity);
          }
        } else {
          payloadDesc = String.fromCharCodes(payload);
          if (payloadDesc.length > 100) {
            payloadDesc = '${payloadDesc.substring(0, 100)}...';
          }
        }
      } catch (_) {
        payloadDesc = '${payload.length} bytes';
      }
    }

    // 距離
    String distStr = '';
    final myLoc = userLocation;
    if (myLoc != null && lat != 0 && lng != 0) {
      final dist = LocationService.haversineMeters(myLoc, LatLng(lat, lng));
      distStr = LocationService.formatDistance(dist);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: p.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(children: [
            Icon(typeIcon, color: typeColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
                child: Text(typeName,
                    style: TextStyle(
                        color: p.text0,
                        fontSize: 18,
                        fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(urgencyLabel,
                  style: TextStyle(color: urgencyColor, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 12),
          if (payloadDesc.isNotEmpty)
            Text(payloadDesc,
                style: TextStyle(color: p.text1, fontSize: 14)),
          const SizedBox(height: 8),
          if (distStr.isNotEmpty)
            Row(children: [
              Icon(Icons.place, size: 14, color: p.text3),
              const SizedBox(width: 4),
              Text(l.mapEventInfoDistance(distStr),
                  style: TextStyle(color: p.text2, fontSize: 13)),
            ]),
          if (timeAgo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(l.mapEventInfoTime(timeAgo),
                style: TextStyle(color: p.text3, fontSize: 12)),
          ],
          const SizedBox(height: 4),
          Text(
              'ID: ${eventId.length > 8 ? eventId.substring(0, 8) : eventId}...',
              style: TextStyle(color: p.text3, fontSize: 10)),
        ],
      ),
    );
  }
}
