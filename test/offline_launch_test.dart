import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:questionx/database.dart';
import 'package:questionx/services/sync_service.dart';

/// Offline launch must never wedge the splash screen.
///
/// Reported from the field: with no network the app sat on "Checking for
/// updates..." with no way past it. Cause was a bare `Dio()`, which has NO
/// connect timeout and so inherits the OS behaviour. Android retries SYNs to an
/// unreachable host for a minute or more, and behind a captive portal it can
/// stall indefinitely. The splash awaits that call, and the surrounding
/// try/catch was useless because nothing ever threw.
void main() {
  test('HTTP client has the timeouts that keep offline launch bounded', () {
    final s = SyncService(AppDatabase.forTesting(NativeDatabase.memory()));
    final o = s.httpOptions;

    expect(o.connectTimeout, isNotNull,
        reason: 'without this an offline launch hangs on the splash forever');
    expect(o.receiveTimeout, isNotNull, reason: 'a stalled socket must die');
    expect(o.sendTimeout, isNotNull);

    // Connect must fail well inside a student's patience.
    expect(o.connectTimeout!.inSeconds, lessThanOrEqualTo(10));
    // Receive is Dio's per-chunk idle limit, not a total budget, so it has to be
    // generous enough that a slow 78 MB data.zip on 2G still completes.
    expect(o.receiveTimeout!.inSeconds, greaterThanOrEqualTo(20));
  });
}
