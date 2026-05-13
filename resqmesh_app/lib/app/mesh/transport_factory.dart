import 'package:ignirelay_app/platform/mesh_transport.dart';
import 'package:ignirelay_app/app/mesh/native_ble_transport_adapter.dart';

/// TransportFactory — 建立 MeshTransport 實例（NativeBLE）
class TransportFactory {
  TransportFactory._();

  static MeshTransport create() => NativeBleTransport();
}
