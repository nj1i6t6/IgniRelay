import 'package:cryptography/cryptography.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';

class Signer {
  static final algorithm = Ed25519();

  /// 構建 canonical signing bytes = eventId(utf8) + eventType(4B LE) + payload
  /// 把 event_id / type 納入簽章範圍，防止攔截者竄改後重放。
  ///
  /// 注意：TTL **故意不簽**。TTL 是逐跳遞減的傳輸欄位（每次中繼會 -1，且 v1
  /// 送出路徑會把 wire ttl 正規化），把它納入簽章會在「第一跳之後」或「送出端
  /// 與簽署端 ttl 不一致」時造成 verify 失敗——這正是 match/negotiation 事件
  /// （簽 ttl=3/5/8）在 v1 收件端被判 sig-fail、無法跨機的根因。事件真實性由
  /// eventId + eventType + payload 綁定即足夠。
  static Uint8List buildCanonicalBytes({
    required String eventId,
    required int eventType,
    required List<int> payload,
  }) {
    final idBytes = utf8.encode(eventId);
    final buf = ByteData(4);
    buf.setInt32(0, eventType, Endian.little);
    final result = Uint8List(idBytes.length + 4 + payload.length);
    result.setRange(0, idBytes.length, idBytes);
    result.setRange(idBytes.length, idBytes.length + 4, buf.buffer.asUint8List());
    result.setRange(idBytes.length + 4, result.length, payload);
    return result;
  }

  /// 簽署完整 canonical event（推薦使用）
  static Future<Uint8List> signEvent({
    required String eventId,
    required int eventType,
    required List<int> payload,
  }) async {
    final canonical = buildCanonicalBytes(
      eventId: eventId,
      eventType: eventType,
      payload: payload,
    );
    return signPayload(canonical);
  }

  /// 驗證完整 canonical event 簽章
  static Future<bool> verifyEvent({
    required String eventId,
    required int eventType,
    required List<int> payload,
    required List<int> signatureBytes,
    required List<int> publicKeyBytes,
  }) async {
    final canonical = buildCanonicalBytes(
      eventId: eventId,
      eventType: eventType,
      payload: payload,
    );
    return verifySignature(
      payloadBytes: canonical,
      signatureBytes: signatureBytes,
      publicKeyBytes: publicKeyBytes,
    );
  }

  /// 簽署資料 (使用本機私鑰)
  /// 傳入原始 Payload bytes，回傳 64 bytes 的 Signature
  static Future<Uint8List> signPayload(List<int> payloadBytes) async {
    final keyPair = await IdentityManager().getOrCreateKeyPair();

    final signature = await algorithm.sign(
      payloadBytes,
      keyPair: keyPair,
    );

    return Uint8List.fromList(signature.bytes);
  }

  /// 驗證簽章
  /// 收到 MeshEvent 時，必須呼叫此函數驗證 sender_pub_key 是否確實簽署了 payload
  static Future<bool> verifySignature({
    required List<int> payloadBytes,
    required List<int> signatureBytes,
    required List<int> publicKeyBytes,
  }) async {
    try {
      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );

      final signature = Signature(
        signatureBytes,
        publicKey: publicKey,
      );

      final isVerified = await algorithm.verify(
        payloadBytes,
        signature: signature,
      );

      return isVerified;
    } catch (e) {
      // 解析金鑰或簽章格式錯誤
      return false;
    }
  }
}
