/// 廣播速率限制例外
///
/// Stage 1 corrective：原先放在 `app/mesh/event_manager.dart`，UI 端需要 catch
/// 此例外卻又被 `ui-cannot-import-mesh` 守則攔下。搬到此非 mesh 檔以解耦：
/// UI 與 EventManager / EventPublisher 共用同一個例外型別，但 UI 不再因為
/// 一個 exception class 被迫 import mesh 層。
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  @override
  String toString() => 'RateLimitException: $message';
}
