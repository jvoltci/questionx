import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/screens/practice_config_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two persisted bits behind the cross-exam switch.
///
/// Both defaults matter. The switch must start OFF so a slow disk read cannot
/// flash JEE questions on for a student who never asked for them; the NEW pill
/// must start HIDDEN for the same reason in reverse — it should never blink into
/// view for someone who has already dismissed it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('switch defaults off and survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    var c = ProviderContainer();
    expect(c.read(crossExamEnabledProvider), isFalse);

    await c.read(crossExamEnabledProvider.notifier).set(true);
    expect(c.read(crossExamEnabledProvider), isTrue);
    c.dispose();

    // fresh container == app restart
    c = ProviderContainer();
    expect(c.read(crossExamEnabledProvider), isFalse, reason: 'pre-restore');
    await c.read(crossExamEnabledProvider.notifier).restored;
    expect(c.read(crossExamEnabledProvider), isTrue, reason: 'restored');
    c.dispose();
  });

  test('NEW pill shows once for an existing user, then never again', () async {
    SharedPreferences.setMockInitialValues({});
    var c = ProviderContainer();
    await c.read(crossExamSeenProvider.notifier).restored;
    expect(c.read(crossExamSeenProvider), isFalse, reason: 'pill should show');

    await c.read(crossExamSeenProvider.notifier).markSeen();
    expect(c.read(crossExamSeenProvider), isTrue);
    c.dispose();

    c = ProviderContainer();
    // starts true so it cannot flash in before prefs load
    expect(c.read(crossExamSeenProvider), isTrue);
    await c.read(crossExamSeenProvider.notifier).restored;
    expect(c.read(crossExamSeenProvider), isTrue, reason: 'stays dismissed');
    c.dispose();
  });

  test('a student who already dismissed it never sees the pill', () async {
    SharedPreferences.setMockInitialValues({kCrossExamSeenKey: true});
    final c = ProviderContainer();
    await c.read(crossExamSeenProvider.notifier).restored;
    expect(c.read(crossExamSeenProvider), isTrue);
    c.dispose();
  });
}
