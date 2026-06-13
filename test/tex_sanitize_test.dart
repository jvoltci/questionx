import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/widgets/tex_view.dart';

void main() {
  group('TexText._sanitize \\over handling', () {
    test('does NOT mangle \\over* commands wrapped in braces', () {
      // Regression: JEE_Main_2020_Jan07_S2_Phy_22 rendered |R| as a fraction
      // bar over the literal text "rightarrowR".
      const input = r'\left| {\overrightarrow R } \right| = \left| {\overrightarrow P } \right|';
      final out = TexText.sanitizeForTest(input);
      expect(out, contains(r'\overrightarrow R'));
      expect(out, contains(r'\overrightarrow P'));
      expect(out, isNot(contains(r'\frac')),
          reason: 'a vector must not become a fraction');
    });

    test('leaves other \\over* commands intact too', () {
      for (final cmd in const [
        r'{\overline x}',
        r'{\overbrace{abc}}',
        r'{\overleftarrow v}',
      ]) {
        expect(TexText.sanitizeForTest(cmd), isNot(contains(r'\frac')),
            reason: cmd);
      }
    });

    test('STILL converts a genuine {a \\over b} fraction to \\frac', () {
      const input = r'{2P\sin \theta \over Q + 2P\cos \theta}';
      final out = TexText.sanitizeForTest(input);
      expect(out, startsWith(r'\frac{'));
      expect(out, contains(r'\sin'));
      expect(out, isNot(contains(r'\over ')));
    });
  });
}
