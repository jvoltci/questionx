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

  // -------------------------------------------------------------------------
  // Chemical reaction merger tests
  // -------------------------------------------------------------------------

  group('TexText.mergeChemReactions', () {
    test('merges fragmented reaction: M(s) + ½O₂ → MO(s)', () {
      const input =
          r'M(s) + $${1 \over 2}$$ $O_{2}(g)$ $$ \to $$ MO(s)';
      final out = TexText.mergeChemReactions(input);

      // Should produce a single $$...$$ block
      expect(out, startsWith(r'$$'));
      expect(out, endsWith(r'$$'));
      // Plain text parts wrapped in \text{}
      expect(out, contains(r'\text{M(s) + }'));
      expect(out, contains(r'\text{ MO(s)}'));
      // Math parts unwrapped
      expect(out, contains(r'\to'));
      expect(out, contains(r'O_{2}(g)'));
      // No nested $$ or $ delimiters
      final inner = out.substring(2, out.length - 2);
      expect(inner, isNot(contains(r'$$')));
    });

    test('merges electrochemistry half-reaction', () {
      const input =
          r'$Zn^{2+}$ + $2e^{–}$ $$ \to $$ Zn(s) ; $E^{o}$ = – 0.76 V';
      final out = TexText.mergeChemReactions(input);
      expect(out, startsWith(r'$$'));
      expect(out, contains(r'Zn^{2+}'));
      expect(out, contains(r'\to'));
      expect(out, contains(r'\text{ Zn(s) ; }'));
    });

    test('merges multi-species reaction', () {
      const input =
          r'$2N_{2}O_{5}(g)$ $$ \to $$ $4NO_{2}(g)$ + $O_{2}(g)$.';
      final out = TexText.mergeChemReactions(input);
      expect(out, startsWith(r'$$'));
      expect(out, contains(r'2N_{2}O_{5}(g)'));
      expect(out, contains(r'\to'));
      expect(out, contains(r'4NO_{2}(g)'));
    });

    test('does NOT merge non-chemistry lines with arrows', () {
      // Solution bullet points using → as a marker
      const input =
          r'$$\to$$ So we can say if an acid forms more $H^{+}$ ion';
      final out = TexText.mergeChemReactions(input);
      // Should NOT be merged (no state symbols / chem notation)
      expect(out, isNot(startsWith(r'$$\text')));
    });

    test('does NOT merge lines without arrows', () {
      const input = r'The value of $K_{p}$ at 300 K is 100.0';
      final out = TexText.mergeChemReactions(input);
      expect(out, equals(input));
    });

    test('collapses \\n\\n to \\n', () {
      const input = 'Line one\n\nLine two\n\n\nLine three';
      final out = TexText.mergeChemReactions(input);
      expect(out, equals('Line one\nLine two\nLine three'));
    });

    test('handles the reported question (AIPMT_2013 / JEE_2016 style)', () {
      // Simulate the actual data: after JSON parsing, backslashes are single.
      final input =
          'The plot shows the variation of −\$\$ln\$\$ \$K_{p}\$ versus '
          'temperature for the two reactions.\n\n'
          'M(s) + \$\${1 \\over 2}\$\$ \$O_{2}(g)\$ \$\$ \\to \$\$ MO(s) and \n\n'
          'C(s) + \$\${1 \\over 2}\$\$ \$O_{2}(g)\$ \$\$ \\to \$\$ CO(g)\n\n'
          'Identify the correct statement :';
      final out = TexText.mergeChemReactions(input);

      // Double newlines collapsed to single
      expect(out, isNot(contains('\n\n')));

      // Reaction lines merged into $$ blocks
      expect(out, contains(r'\text{M(s) + }'));
      expect(out, contains(r'\text{C(s) + }'));

      // Non-reaction lines preserved
      expect(out, contains('The plot shows'));
      expect(out, contains('Identify the correct statement'));
    });

    test('escapes braces in plain text', () {
      const input = r'A{s} + $B_{2}(g)$ $$ \to $$ C(g)';
      final out = TexText.mergeChemReactions(input);
      // The { } in "A{s}" should be escaped
      expect(out, contains(r'A\{s\}'));
    });
  });
}
