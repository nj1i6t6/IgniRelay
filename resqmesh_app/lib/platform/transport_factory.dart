import 'package:ignirelay_app/platform/mesh_transport.dart';
import 'package:ignirelay_app/platform/native_ble_transport.dart';

/// TransportFactory — 建立 MeshTransport 實例（NativeBLE）
class TransportFactory {
  TransportFactory._();

  static MeshTransport create() => NativeBleTransport();
}
