// map_action_results.dart
//
// Stage 7-r2：MapScreenController command 的結果型別。
//
// 邊界規則：
//   - controller 永遠不直接做 UI side effect（snackbar / dialog / Navigator）；
//   - 改回傳結果物件，讓 widget 依結果決定 UI 呈現。
//   - 結果型別本身不依賴 BuildContext / Flutter widget 類別，便於單元測試。

import 'package:flutter/foundation.dart';

/// 發布或更新危險標記的結果。
@immutable
sealed class PublishHazardOutcome {
  const PublishHazardOutcome();
}

/// 新建成功。
class PublishHazardPublished extends PublishHazardOutcome {
  const PublishHazardPublished();
}

/// 編輯模式下成功更新既有 hazard。
class PublishHazardUpdated extends PublishHazardOutcome {
  const PublishHazardUpdated();
}

/// 在 marking 範圍內偵測到既有 hazard，需要使用者選擇 confirm / new / cancel。
class PublishHazardNearbyConflict extends PublishHazardOutcome {
  const PublishHazardNearbyConflict({
    required this.distanceMeters,
    required this.confirmCount,
    required this.typeKey,
    required this.nearbyId,
  });

  final int distanceMeters;
  final int confirmCount;

  /// `ROADBLOCK` / `FIRE` / ... 大寫鍵；UI 自行 i18n。
  final String typeKey;
  final String nearbyId;
}

/// 確認既有 hazard 取代新建（`PublishHazardNearbyConflict` 後選 confirm）。
class PublishHazardConfirmedExisting extends PublishHazardOutcome {
  const PublishHazardConfirmedExisting({required this.typeKey});
  final String typeKey;
}

/// 失敗（exception 訊息已序列化為字串）。
class PublishHazardFailure extends PublishHazardOutcome {
  const PublishHazardFailure(this.errorMessage);
  final String errorMessage;
}

/// 沒實際發布也沒失敗（例如 marking 中 center 為 null）。
class PublishHazardNoop extends PublishHazardOutcome {
  const PublishHazardNoop();
}

/// 觸發 SOS / 一般廣播的結果。
@immutable
sealed class TriageOutcome {
  const TriageOutcome();
}

class TriagePublished extends TriageOutcome {
  const TriagePublished({required this.urgency, required this.description});
  final int urgency;
  final String description;
}

class TriageRateLimited extends TriageOutcome {
  const TriageRateLimited(this.message);
  final String message;
}

class TriageFailure extends TriageOutcome {
  const TriageFailure(this.errorMessage);
  final String errorMessage;
}

/// 取消 SOS 的結果。
@immutable
sealed class CancelSosOutcome {
  const CancelSosOutcome();
}

class CancelSosSucceeded extends CancelSosOutcome {
  const CancelSosSucceeded();
}

class CancelSosFailure extends CancelSosOutcome {
  const CancelSosFailure(this.errorMessage);
  final String errorMessage;
}

/// 確認他人 hazard 的結果。
@immutable
sealed class ConfirmHazardOutcome {
  const ConfirmHazardOutcome();
}

class ConfirmHazardSucceeded extends ConfirmHazardOutcome {
  const ConfirmHazardSucceeded({required this.newCount, required this.typeKey});
  final int newCount;
  final String typeKey;
}

class ConfirmHazardFailure extends ConfirmHazardOutcome {
  const ConfirmHazardFailure(this.errorMessage);
  final String errorMessage;
}

/// 刪除自己 hazard 的結果。
@immutable
sealed class DeleteHazardOutcome {
  const DeleteHazardOutcome();
}

class DeleteHazardSucceeded extends DeleteHazardOutcome {
  const DeleteHazardSucceeded();
}

class DeleteHazardFailure extends DeleteHazardOutcome {
  const DeleteHazardFailure(this.errorMessage);
  final String errorMessage;
}
