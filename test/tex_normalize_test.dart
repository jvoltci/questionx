import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/utils/crypto.dart';
import 'package:questionx/widgets/tex_normalize.dart';

/// Guards the render-time LaTeX repair.
///
/// These run against the SHIPPED banks as well as hand-picked strings, so the
/// gate holds for data added later — that is the whole point of doing the repair
/// in the widget instead of as a one-shot migration.

List<dynamic> bank(String encPath) =>
    json.decode(DataCrypto.decryptBytes(File(encPath).readAsBytesSync())) as List;

Iterable<String> fieldsOf(Map q) => [
      (q['question_latex'] ?? '') as String,
      (q['solution'] ?? '') as String,
      ...((q['options'] as List?) ?? []).map((o) => o.toString()),
    ].where((s) => s.isNotEmpty);

/// Word tokens with delimiters stripped — proves no text is lost or fused.
List<String> words(String s) => RegExp(r'[A-Za-z0-9]+')
    .allMatches(s.replaceAll(r'$', ''))
    .map((m) => m.group(0)!)
    .toList();

int swallowed(String s) => appMathPattern
    .allMatches(s)
    .where((m) => isSwallowedProse(m.group(1) ?? m.group(2) ?? ''))
    .length;

void main() {
  group('delimiter repair', () {
    test('restores a clause swallowed by a stray delimiter', () {
      // JEE_Main_2021_Aug26_S1_Phy_1 — the `$$$` run opened a span that ate
      // "and an unknown capacitor", leaving the question unanswerable.
      const src =
          'A series LCR circuit driven by 300 V at a frequency of 50 Hz contains '
          r'a resistance R = 3 k$$\Omega$$, an inductor of inductive reactance '
          r'$X_{L}$ = 250 $$\pi$$$\Omega$$$ and an unknown capacitor. The value of '
          r'capacitance to maximize the average power should be : (Take $$$\pi^{2}$ = 10)';
      final out = repairDelimiters(src);
      expect(out, contains('and an unknown capacitor'));
      expect(swallowed(src), greaterThan(0));
      expect(swallowed(out), 0);
      // X_L = 250 pi Ohm — the two fragments belong to one expression.
      expect(out, contains(r'$$\pi\Omega$$ and'));
      expect(out, contains(r'(Take $$\pi^{2}$$ = 10)'));
    });

    test('fuses a subscript the wrapper split off its symbol', () {
      expect(repairDelimiters(r'To the left of $$\omega$$$_{r}$, the circuit'),
          r'To the left of $$\omega_{r}$$, the circuit');
    });

    test('leaves well-formed text byte-identical', () {
      for (final s in [
        r'A ball of mass $m$ in a fluid of density $$\rho$$.',
        r'resistance of 110$$\Omega$$ and a supply of 220 V',
        r'lags behind the voltage by 45$$^\circ$$.',
        r'connected across 220V$$-$$50 Hz AC supply',
      ]) {
        expect(repairDelimiters(s), s, reason: s);
      }
    });

    test('does not touch an upstream `<` truncation', () {
      // Content after the bare `<` is absent from the source; nothing to recover.
      const src = r'first ionization enthalpy of $$\mathrm{Li}$$ is '
          r'$$\mathrm{Na}Statement II : the correct order of values';
      expect(repairDelimiters(src), src);
    });

    test(r'never fuses two words by deleting the `$` between them', () {
      for (final s in [
        r'$$\pi$$$\Omega$$$ and an unknown capacitor. The value of it should be',
        r'the change $$\Delta $$$\lambda$ $$ in de-Broglie wavelength of particle A',
      ]) {
        expect(words(repairDelimiters(s)), words(s), reason: s);
      }
    });

    test('is idempotent', () {
      const src = r'To the left of $$\omega$$$_{r}$, the circuit is capacitive.';
      final once = repairDelimiters(src);
      expect(repairDelimiters(once), once);
    });
  });

  group('prose typeset as math', () {
    test('wraps fraction labels and un-glues MathType word splits', () {
      final out = textifyProse(
          r'then $$\left( {{{mean\,\,of\,X} \over {s\tan dard\,\,deviation\,\,of\,X}}} \right)$$ is');
      expect(out, contains(r'\text{mean of}'));
      expect(out, contains(r'\text{standard deviation of}'));
      expect(out, isNot(contains(r's\tan dard')));
    });

    test('wraps each node of a food chain', () {
      final out = textifyProse(
          r'chain? $plant \rightarrow mice \rightarrow snake \rightarrow peacock$');
      expect(out, contains(r'\text{plant} \rightarrow \text{mice}'));
      expect(out, contains(r'\text{peacock}'));
    });

    test('un-glues \\Pr obability without touching the subscripts', () {
      final out = textifyProse(
          r'$${{\Pr obability\,\,of\,\,occurrence\,\,of\,\,{E_1}} \over {\Pr obability\,\,of\,\,occurrence\,\,of\,\,{E_3}}}$$');
      expect(out, contains(r'\text{Probability of occurrence of}'));
      expect(out, contains('{E_1}'));
      expect(out, contains('{E_3}'));
    });

    test('leaves real math alone — the allowlist must not become a pattern', () {
      // Every one of these matches the `\<func> <letters>` shape that a general
      // un-glue rule would rewrite, turning `x\cos x` into the variable `xcosx`.
      for (final s in [
        r'$$\int \sin x\,dx$$',
        r'$$y = x\tan \theta$$',
        r'$$\ln \left( {{{2 - x\cos x} \over {2 + x\cos x}}} \right)$$',
        r'$$k\sin kz$$',
        r'$$\cos ec\theta$$',
        r'$$u\cos 45\widehat i$$',
        r'$$ab\cos y$$',
        r'$$MgCl_2 + H_2O \rightarrow Mg(OH)_2$$',
        r'$$P_{\text {avg }}=V_{\text {rms }} I_{rms}\cos (\Delta \phi)$$',
        r'$$\begin{aligned}& \mathrm{X}_{\mathrm{c}}=\frac{1}{\omega \mathrm{C}}\end{aligned}$$',
        r'$$\lambda _{radio}$$',
      ]) {
        expect(textifyProse(s), s, reason: s);
      }
    });

    test('leaves an upstream truncation alone rather than dressing it up', () {
      const src =
          r'is $$\mathrm{Na}Statement II : the correct order of these values$$';
      expect(textifyProse(src), src);
    });
  });

  group('shipped banks', () {
    late List<dynamic> all;
    setUpAll(() {
      all = [
        ...bank('assets/neet.json.enc'),
        ...bank('assets/jee.json.enc'),
      ];
    });

    test('normalization never loses or fuses visible text', () {
      final bad = <String>[];
      for (final q in all) {
        for (final f in fieldsOf(q as Map)) {
          final out = repairDelimiters(f);
          if (!listEquals(words(out), words(f))) bad.add('${q['id']}');
        }
      }
      expect(bad, isEmpty, reason: 'text changed in: ${bad.take(10)}');
    });

    test('normalization never increases prose-rendered-as-math', () {
      final bad = <String>[];
      for (final q in all) {
        for (final f in fieldsOf(q as Map)) {
          if (swallowed(normalizeForRender(f)) > swallowed(f)) {
            bad.add('${q['id']}');
          }
        }
      }
      expect(bad, isEmpty, reason: 'regressed: ${bad.take(10)}');
    });

    test('normalization strictly reduces prose-rendered-as-math overall', () {
      var before = 0, after = 0;
      for (final q in all) {
        for (final f in fieldsOf(q as Map)) {
          before += swallowed(f);
          after += swallowed(normalizeForRender(f));
        }
      }
      // ignore: avoid_print
      print('prose rendered as math: $before -> $after');
      expect(after, lessThan(before ~/ 1.8),
          reason: 'normalization should roughly halve this');
      // The residue is upstream `<` truncation plus a few spans too mangled to
      // rewrite safely — no render-time pass can recover deleted source text.
      // Ratchet: if a bank added later makes this worse, this test says so.
      expect(after, lessThanOrEqualTo(220));
    });

    test('normalization is idempotent', () {
      final bad = <String>[];
      for (final q in all) {
        for (final f in fieldsOf(q as Map)) {
          final once = normalizeForRender(f);
          if (normalizeForRender(once) != once) bad.add('${q['id']}');
        }
      }
      expect(bad, isEmpty, reason: 'not a fixed point: ${bad.take(10)}');
    });

    // Not a failure gate — a visible inventory. A separate upstream scrape bug
    // dropped the text after a bare `<`, cutting statements mid-comparison
    // ("...first ionization enthalpy of Li, Na, F and Cl is $$\mathrm{Na}" then
    // straight into "Statement II"). That content is absent from the source and
    // from the pre-cleanup backup, so no render-time pass can recover it: these
    // need repairing by hand against the official papers. The count is capped so
    // a bank added later cannot quietly bring more of them along.
    test('inventory: questions with content lost upstream', () {
      final ids = <String>[];
      for (final q in all) {
        final text = (q as Map)['question_latex'] as String? ?? '';
        final opts = (((q['options'] as List?) ?? []).join('\n'));
        if (hasSwallowedSentence(normalizeForRender('$text\n$opts'))) {
          ids.add(q['id'] as String);
        }
      }
      // ignore: avoid_print
      print('questions needing manual repair (${ids.length}):\n  ${ids.join('\n  ')}');
      expect(ids.length, lessThanOrEqualTo(12));
    });

    test('stray delimiter runs are reduced and never introduced', () {
      // A `$$$` run that cannot be re-tokenized without losing text is left in
      // place on purpose — mangling it would be worse than rendering it. So the
      // gate is "strictly fewer, never more", not "zero".
      var before = 0, after = 0;
      final triple = RegExp(r'\${3,}');
      for (final q in all) {
        for (final f in fieldsOf(q as Map)) {
          final b = triple.allMatches(f).length;
          final a = triple.allMatches(normalizeForRender(f)).length;
          expect(a, lessThanOrEqualTo(b), reason: 'introduced in ${q['id']}');
          before += b;
          after += a;
        }
      }
      // ignore: avoid_print
      print('stray \$\$\$ runs: $before -> $after');
      expect(after, lessThan(before));
    });
  });
}
