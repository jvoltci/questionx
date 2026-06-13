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

  group('TexText._sanitize legacy-TeX recovery', () {
    test('gathered -> aligned', () {
      final out = TexText.sanitizeForTest(r'\begin{gathered}a\\b\end{gathered}');
      expect(out, contains(r'\begin{aligned}'));
      expect(out, isNot(contains('gathered')));
    });

    test('plain-TeX \\matrix{..} -> \\begin{matrix}..\\end{matrix}', () {
      final out = TexText.sanitizeForTest(r'\matrix{1 & 2 \cr 3 & 4}');
      expect(out, contains(r'\begin{matrix}'));
      expect(out, contains(r'\end{matrix}'));
      expect(out, isNot(contains(r'\matrix{')));
    });

    test('strips \\limits / \\tag, maps \\AA and \\cdotp', () {
      expect(TexText.sanitizeForTest(r'\int_\limits0^1'), isNot(contains(r'\limits')));
      expect(TexText.sanitizeForTest(r'x=1\tag{3}'), isNot(contains(r'\tag')));
      expect(TexText.sanitizeForTest(r'\text{5 \AA}'), contains('Å'));
      expect(TexText.sanitizeForTest(r'a\cdotp b'), contains(r'\cdot'));
    });
  });
}
