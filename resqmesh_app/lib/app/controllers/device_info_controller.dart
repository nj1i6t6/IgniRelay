import 'package:ignirelay_app/platform/native_bridge.dart';

/// 裝置資訊與廠商電源設定的應用層 facade。
///
/// 包含電量、廠牌判斷、電池最佳化豁免等 UI 需要顯示或引導的狀態。
class DeviceInfoController {
  DeviceInfoController._();
  static final DeviceInfoController instance = DeviceInfoController._();

  Future<int> batteryLevel() => NativeBridge.getBatteryLevel();

  Future<String> manufacturer() => NativeBridge.getManufacturer();

  Future<bool> isBatteryOptimizationExempt() =>
      NativeBridge.isBatteryOptimizationExempt();

  Future<bool> requestBatteryOptimizationExemption() =>
      NativeBridge.requestBatteryOptimizationExemption();

  Future<bool> openBatterySettings() => NativeBridge.openBatterySettings();

  Future<bool> openManufacturerPowerSettings() =>
      NativeBridge.openManufacturerPowerSettings();
}
