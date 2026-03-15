import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'mesh_transport.dart';
// import 'bridgefy_transport.dart';  // 暫時停用 — Bridgefy maven repo 500 error
import 'native_ble_transport.dart';

/// TransportFactory — 根據設定建立對應的 MeshTransport 實例
class TransportFactory {
  TransportFactory._();

  /// 根據 AppConfig.transportType 建立 transport
  /// 若選擇 Bridgefy 但無 API Key 或 SDK 未就緒，自動 fallback 到 NativeBLE
  static MeshTransport create({TransportType? override}) {
    final type = override ?? AppConfig.transportType;
    switch (type) {
      case TransportType.bridgefy:
        // TODO: Bridgefy maven repo 修復後取消註解
        // if (AppConfig.hasBridgefyKey) return BridgefyTransport();
        debugPrint('[TransportFactory] Bridgefy SDK 暫未就緒，fallback → NativeBLE');
        return NativeBleTransport();
      case TransportType.nativeBle:
        return NativeBleTransport();
    }
  }
}
