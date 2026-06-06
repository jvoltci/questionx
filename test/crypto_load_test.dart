import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/utils/crypto.dart';

/// Verifies the on-device load path: the bundled encrypted banks decrypt to
/// valid, non-empty question lists. Guards against a key/format drift between
/// the build-time encryptor (tool/encrypt_assets.dart) and the runtime loader.
void main() {
  test('encrypted banks decrypt + parse to non-empty lists', () {
    for (final f in ['assets/neet.json.enc', 'assets/jee.json.enc']) {
      final enc = File(f);
      expect(enc.existsSync(), isTrue, reason: '$f must be built (dart run tool/encrypt_assets.dart)');
      final decoded = json.decode(DataCrypto.decryptBytes(enc.readAsBytesSync()));
      expect(decoded, isA<List<dynamic>>());
      expect((decoded as List).length, greaterThan(100));
    }
  });

  test('crypto round-trips arbitrary content', () {
    const s = r'{"q":"E=mc^2 ünïçødé 🚀","answer_key":"A,C","val":"400"}';
    expect(DataCrypto.decryptBytes(DataCrypto.encryptString(s)), s);
  });
}
