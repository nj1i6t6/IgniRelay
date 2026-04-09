/// IgniRelay (烽傳) 應用程式設定
class AppConfig {
  AppConfig._();

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
}
