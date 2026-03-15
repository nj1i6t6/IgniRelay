import 'package:cryptography/cryptography.dart';
import 'dart:typed_data';
import 'identity_manager.dart';

class Signer {
  static final algorithm = Ed25519();

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
