import 'dart:typed_data';
import 'package:ignirelay_app/app/crdt/hlc.dart';

class ConflictResolver {
  
  /// 取出兩個競爭同一筆物資的 MATCH_INTENT 事件，回傳最終勝出者。
  /// Double-Spending 排解邏輯：
  /// 1. 比較 HLC timestamp 較小者勝出 (先發生的先得)
  /// 2. HLC counter 較小者勝出
  /// 3. Urgency: SOS_RED(3) > SOS_YELLOW(2) > RESOURCE(1)
  /// 4. Tiebreaker: 比較 Requester PubKey 字典序
  static int resolveMatchConflict({
    required HLC hlc1,
    required int urgency1,
    required Uint8List pubKey1,
    required HLC hlc2,
    required int urgency2,
    required Uint8List pubKey2,
  }) {
    // 1 & 2. HLC 比較
    int hlcCompare = hlc1.compareTo(hlc2);
    if (hlcCompare != 0) {
      return hlcCompare < 0 ? 1 : 2; // 回傳 1 表示 event1 勝出，回傳 2 表示 event2 勝出
    }

    // 3. Urgency 比較 (數值越大優先級越高，但這裡要比較誰"更緊急"，所以大的勝出)
    if (urgency1 != urgency2) {
      return urgency1 > urgency2 ? 1 : 2;
    }

    // 4. Tiebreaker: PubKey Byte Array 的字典序
    for (int i = 0; i < pubKey1.length && i < pubKey2.length; i++) {
        if (pubKey1[i] != pubKey2[i]) {
            return pubKey1[i] < pubKey2[i] ? 1 : 2;
        }
    }
    return 1; // 絕對相同的情況，預設選 1
  }
}
