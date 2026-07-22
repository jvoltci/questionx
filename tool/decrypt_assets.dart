import 'dart:io';
import 'package:questionx/utils/crypto.dart';

/// Decrypts *.json.enc files back to plaintext JSON for editing.
/// Run: `dart run tool/decrypt_assets.dart`
void main() {
  for (final f in const ['neet', 'jee']) {
    final src = File('assets/$f.json.enc');
    if (!src.existsSync()) {
      stderr.writeln('missing assets/$f.json.enc');
      continue;
    }
    final plain = DataCrypto.decryptBytes(src.readAsBytesSync());
    File('assets/$f.json').writeAsStringSync(plain);
    stdout.writeln('decrypted $f.json.enc -> $f.json '
        '(${plain.length} chars)');
  }
}
