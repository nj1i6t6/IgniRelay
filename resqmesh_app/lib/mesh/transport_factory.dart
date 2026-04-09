import 'mesh_transport.dart';
import 'native_ble_transport.dart';

/// TransportFactory — 建立 MeshTransport 實例（NativeBLE）
class TransportFactory {
  TransportFactory._();

  static MeshTransport create() => NativeBleTransport();
}
