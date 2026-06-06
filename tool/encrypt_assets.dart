import 'dart:io';
import 'package:questionx/utils/crypto.dart';

/// Build-time encryptor. Reads plaintext question banks (local source of truth)
/// and writes AES-encrypted `*.json.enc` that get bundled into the app.
/// Run: `dart run tool/encrypt_assets.dart`
void main() {
  for (final f in const ['neet', 'jee']) {
    final src = File('assets/$f.json');
    if (!src.existsSync()) {
      stderr.writeln('missing assets/$f.json');
      exit(1);
    }
    final plain = src.readAsStringSync();
    final bytes = DataCrypto.encryptString(plain);
    File('assets/$f.json.enc').writeAsBytesSync(bytes);
    final back = DataCrypto.decryptBytes(
        File('assets/$f.json.enc').readAsBytesSync());
    if (back != plain) {
      stderr.writeln('ROUND-TRIP FAILED for $f');
      exit(1);
    }
    stdout.writeln('encrypted $f.json -> $f.json.enc '
        '(${bytes.length} bytes, round-trip OK)');
  }
}
