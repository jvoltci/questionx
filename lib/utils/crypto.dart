import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

/// AES-256-CBC for QuestionX's bundled + OTA question data.
///
/// Deterrence against casual scraping (unzip-APK / curl the public release
/// data.zip), NOT a vault: the key necessarily ships in the app. It raises the
/// bar from "5 seconds" to "real reverse engineering", which stops lazy cloning
/// of the verified PYQ bank + answer keys. Encrypt/decrypt live in one place so
/// the build-time encryptor and the on-device loader can never drift.
class DataCrypto {
  // 32-byte key, assembled from parts at runtime (mild obfuscation).
  static Key? _cached;
  static Key get _key {
    const a = 'SHCCwpDehmPS';
    const b = 'K1noF7ttQNS7Phed';
    const c = 'qvBFPMFxiiEb/9c=';
    return _cached ??= Key.fromBase64(a + b + c);
  }

  static final Encrypter _enc =
      Encrypter(AES(_key, mode: AESMode.cbc, padding: 'PKCS7'));

  /// Layout: bytes = 16-byte IV || ciphertext.
  static String decryptBytes(Uint8List bytes) {
    final iv = IV(Uint8List.fromList(bytes.sublist(0, 16)));
    final ct = Encrypted(Uint8List.fromList(bytes.sublist(16)));
    return _enc.decrypt(ct, iv: iv);
  }

  static Uint8List encryptString(String plain) {
    final iv = IV.fromSecureRandom(16);
    final ct = _enc.encrypt(plain, iv: iv);
    return Uint8List.fromList(<int>[...iv.bytes, ...ct.bytes]);
  }
}
