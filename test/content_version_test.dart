import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/content_version.dart';

/// Guards the "upgrade delivers corrected questions" path.
///
/// The app only imported the bundled bank into an EMPTY database, so shipping an
/// APK with corrected questions did nothing for anyone who already had the app —
/// their copy stayed stale until an OTA release happened to fire.
/// NEET_2024_Zoo_184 was fixed in v1.7.6 and still showed the old, garbled text
/// on an upgraded install. SyncService now re-imports whenever
/// `kBundledContentVersion` differs from the value it recorded last time, so
/// this test exists to make sure that constant actually tracks the banks.

String fingerprintOf(List<String> plaintexts) =>
    sha256.convert(utf8.encode(plaintexts.join())).toString().substring(0, 16);

void main() {
  test('kBundledContentVersion matches the current plaintext banks', () {
    final plaintexts = [
      File('assets/neet.json').readAsStringSync(),
      File('assets/jee.json').readAsStringSync(),
    ];
    expect(
      kBundledContentVersion,
      fingerprintOf(plaintexts),
      reason: 'lib/content_version.dart is stale — run '
          '`dart run tool/encrypt_assets.dart` after editing a bank, or an '
          'upgrade will not deliver the corrected questions',
    );
  });

  test('the fingerprint changes when a bank changes', () {
    final base = [
      File('assets/neet.json').readAsStringSync(),
      File('assets/jee.json').readAsStringSync(),
    ];
    final edited = [base[0].replaceFirst('Multiload', 'Multiload '), base[1]];
    expect(fingerprintOf(edited), isNot(fingerprintOf(base)));
  });

  test('the fingerprint ignores encryption, which uses a fresh IV each run', () {
    // Fingerprinting the .enc bytes instead would change on every build and
    // force a pointless re-import; it must be derived from the plaintext.
    final a = File('assets/neet.json.enc').readAsBytesSync();
    final b = File('assets/jee.json.enc').readAsBytesSync();
    expect(kBundledContentVersion, isNot(contains(sha256.convert(a).toString())));
    expect(kBundledContentVersion, isNot(contains(sha256.convert(b).toString())));
  });
}
