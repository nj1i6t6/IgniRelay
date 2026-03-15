/// IgniRelay (烽傳) 應用程式設定
///
/// Bridgefy API Key 透過編譯時環境變數注入：
/// flutter run --dart-define=BRIDGEFY_API_KEY=xxx
class AppConfig {
  AppConfig._();

  /// Bridgefy SDK API Key（編譯時注入）
  static const String bridgefyApiKey = String.fromEnvironment(
    'BRIDGEFY_API_KEY',
    defaultValue: '',
  );

  /// 當前使用的傳輸層類型
  static TransportType transportType = TransportType.bridgefy;

  /// Bloom Filter 廣播間隔（秒）
  static const int bloomBroadcastIntervalSec = 30;

  /// SOS_RED 時 Bloom Filter 加速間隔（秒）
  static const int bloomBroadcastSosIntervalSec = 10;

  /// Bloom Filter 隨機抖動範圍（秒）
  static const int bloomJitterSec = 5;

  /// Bloom Filter 包含的最大事件 ID 數量
  static const int bloomMaxEventIds = 50;

  /// 預設 TTL 跳數
  static const int defaultTtl = 10;

  /// 是否有有效的 Bridgefy API Key
  static bool get hasBridgefyKey => bridgefyApiKey.isNotEmpty;
}

/// 傳輸層類型
enum TransportType {
  bridgefy,
  nativeBle,
}
