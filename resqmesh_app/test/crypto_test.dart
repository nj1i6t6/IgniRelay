import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:ignirelay_app/app/crypto/signer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Cryptography Ed25519', () {
    late SimpleKeyPair keyPair;
    late List<int> pubKeyBytes;

    setUp(() async {
      // 直接生成測試用金鑰對（不走 IdentityManager 完整初始化流程）
      final algorithm = Ed25519();
      keyPair = await algorithm.newKeyPair();
      final pubKey = await keyPair.extractPublicKey();
      pubKeyBytes = pubKey.bytes;
    });

    test('Signer should generate and verify valid signature', () async {
      const String mockPayload = "urgent_sos_message_data";
      final List<int> payloadBytes = utf8.encode(mockPayload);

      // 使用測試金鑰對簽名
      final algorithm = Ed25519();
      final sig = await algorithm.sign(payloadBytes, keyPair: keyPair);
      final signature = Uint8List.fromList(sig.bytes);

      // 驗證
      final bool isValid = await Signer.verifySignature(
        payloadBytes: payloadBytes,
        signatureBytes: signature,
        publicKeyBytes: pubKeyBytes,
      );

      expect(isValid, isTrue);
    });

    test('Signer should reject tampered payload', () async {
      const String mockPayload = "urgent_sos_message_data";
      final List<int> payloadBytes = utf8.encode(mockPayload);

      // 使用測試金鑰對簽名
      final algorithm = Ed25519();
      final sig = await algorithm.sign(payloadBytes, keyPair: keyPair);
      final signature = Uint8List.fromList(sig.bytes);

      // 竄改後的 payload
      const String tamperedPayload = "urgent_sos_message_data_hacked";
      final List<int> tamperedBytes = utf8.encode(tamperedPayload);

      // 驗證應失敗
      final bool isValid = await Signer.verifySignature(
        payloadBytes: tamperedBytes,
        signatureBytes: signature,
        publicKeyBytes: pubKeyBytes,
      );

      expect(isValid, isFalse);
    });
  });
}
