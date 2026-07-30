import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/widgets/tex_view.dart';

/// Guards the inline-math layout fix.
///
/// The bug: `_buildInlineContent` used a `Wrap` of `Text` + math widgets. Wrap
/// children are atomic boxes, so a multi-line `Text` consumed its whole run and
/// pushed the following math onto a new line — every `Ω`/`μ`/`λ`/`°` landed on
/// a line of its own, shattering ~78% of the JEE bank mid-sentence.
///
/// The fix: one `Text.rich` paragraph with `WidgetSpan` math. These tests pin
/// the paragraph structure so a Wrap can't come back.

Future<void> pump(WidgetTester tester, String text) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: TexText(text, enableFullscreen: false),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Every rendered glyph run, in visual order, from the paragraph's spans.
List<String> plainRuns(WidgetTester tester) {
  final runs = <String>[];
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final span = w.textSpan;
    if (span == null) continue;
    span.visitChildren((s) {
      if (s is TextSpan && (s.text ?? '').isNotEmpty) runs.add(s.text!);
      return true;
    });
  }
  return runs;
}

void main() {
  // Real source strings, taken verbatim from assets/jee.json.
  const q206 =
      'A certain metallic surface is illuminated by monochromatic radiation of '
      r'wavelength $$\lambda$$. The stopping potential for photoelectric current '
      r'for this radiation is $3V_{0}$. If the same surface is illuminated with a '
      r'radiation of wavelength 2$$\lambda$$, the stopping potential is $V_{0}$. '
      r'The threshold wavelength of this surface for photoelectric effect is '
      r'____________ $$\lambda$$.';

  const q22 =
      'A transmitting station releases waves of wavelength 960 m. A capacitor of '
      r'2.56 $$\mu$$F is used in the resonant circuit. The self inductance of coil '
      r'necessary for resonance is __________ $$\times$$ $10^{-8}$ H.';

  const q19 =
      r'An LCR circuit contains resistance of 110$$\Omega$$ and a supply of 220 V '
      r'at 300 rad/s angular frequency. If only capacitance is removed from the '
      r'circuit, current lags behind the voltage by 45$$^\circ$$.';

  testWidgets('a sentence with 4 inline math spans stays ONE paragraph',
      (tester) async {
    await pump(tester, q206);
    // A single Text.rich for the whole sentence — no Column, no Wrap.
    expect(find.byType(Wrap), findsNothing);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('inline math is a WidgetSpan, not a sibling block', (tester) async {
    await pump(tester, q206);
    final root = tester.widget<Text>(find.byType(Text));
    var widgetSpans = 0;
    root.textSpan!.visitChildren((s) {
      if (s is WidgetSpan) {
        widgetSpans++;
        expect(s.alignment, PlaceholderAlignment.baseline,
            reason: 'inline math must sit on the text baseline');
      }
      return true;
    });
    expect(widgetSpans, 5,
        reason: r'\lambda, 3V_0, 2\lambda, V_0, trailing \lambda');
  });

  testWidgets('prose around math keeps its spacing (no injected gaps)',
      (tester) async {
    await pump(tester, q22);
    final joined = plainRuns(tester).join();
    // The Wrap's `spacing: 4` used to render this as "2.56 μ F".
    expect(joined, contains('A capacitor of 2.56 '));
    expect(joined, contains('F is used in the resonant circuit'));
    // The blank and its unit must stay on the same paragraph as "resonance is".
    expect(joined, contains('necessary for resonance is __________ '));
  });

  testWidgets('degree symbol stays attached to its number', (tester) async {
    await pump(tester, q19);
    final joined = plainRuns(tester).join();
    expect(joined, contains('current lags behind the voltage by 45'));
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('renders without overflow at a narrow phone width',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    for (final t in [q206, q22, q19]) {
      await pump(tester, t);
      expect(tester.takeException(), isNull);
    }
  });

  group('block-vs-inline classification', () {
    test('single symbols and short expressions are inline', () {
      for (final t in [
        r'\Omega',
        r'\mu',
        r'^\circ',
        '3V_{0}',
        '10^{-8}',
        r'20 \mathrm{~cm} / \mathrm{s}',
        r'\frac{2 \mathrm{r}^2 \mathrm{~g}(\sigma-\rho)}{9 \eta}',
      ]) {
        expect(TexText.isBlockMath(t), isFalse, reason: t);
      }
    });

    test('environments, row breaks and long derivations are blocks', () {
      expect(TexText.isBlockMath(r'\begin{aligned}&a=b\end{aligned}'), isTrue);
      expect(TexText.isBlockMath(r'a=b \\ c=d'), isTrue);
      expect(TexText.isBlockMath('x' * 101), isTrue);
    });
  });

  testWidgets('a standalone equation breaks onto its own line', (tester) async {
    await pump(
      tester,
      r'At equilibrium : $$\begin{aligned}& W = F_B + F_v \\ & a = b\end{aligned}$$ '
      'and so the ball moves at constant speed.',
    );
    // prose paragraph + block equation + trailing prose paragraph
    expect(find.byType(Column), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
