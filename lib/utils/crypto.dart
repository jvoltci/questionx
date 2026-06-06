import 'dart:convert';
import 'dart:io';
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

  /// Pipeline: gzip(utf8(plain)) → AES-CBC. gzip FIRST keeps the bundled/OTA
  /// payload small (JSON compresses ~5:1) — encrypted bytes are incompressible,
  /// so without this the .enc would bloat the APK by ~18MB. Layout: IV(16) || ct.
  static String decryptBytes(Uint8List bytes) {
    final iv = IV(Uint8List.fromList(bytes.sublist(0, 16)));
    final ct = Encrypted(Uint8List.fromList(bytes.sublist(16)));
    final gzipped = _enc.decryptBytes(ct, iv: iv);
    return utf8.decode(gzip.decode(gzipped));
  }

  static Uint8List encryptString(String plain) {
    final gzipped = gzip.encode(utf8.encode(plain));
    final iv = IV.fromSecureRandom(16);
    final ct = _enc.encryptBytes(gzipped, iv: iv);
    return Uint8List.fromList(<int>[...iv.bytes, ...ct.bytes]);
  }
}
