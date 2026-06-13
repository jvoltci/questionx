import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_math_fork/src/parser/tex/settings.dart';
import 'package:questionx/utils/crypto.dart';
import 'package:questionx/widgets/tex_view.dart';

/// Render-safety net for QuestionX. Validates the SHIPPED (encrypted) banks the
/// same way TexText does — sanitize() then Math.tex/TexParser — and gates the
/// user-facing breakage so the "raw \sqrt in the question" regression can't
/// silently return. (QuestionX shipped with zero tests; this is the floor.)

// Use the REAL sanitizer (no mirror to drift out of sync).
String sanitize(String t) => TexText.sanitizeForTest(t);

void main() {
  final mathPattern = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);
  bool fieldOk(String s) {
    for (final m in mathPattern.allMatches(s)) {
      final t = (m.group(1) ?? m.group(2) ?? '').trim();
      if (t.isEmpty) continue;
      try {
        TexParser(sanitize(t), const TexParserSettings()).parse();
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  List<dynamic> bank(String encPath) =>
      json.decode(DataCrypto.decryptBytes(File(encPath).readAsBytesSync())) as List;

  test('no question contains \\begin{tabular} (Match-List regression guard)', () {
    final bad = <String>[];
    for (final f in ['assets/neet.json.enc', 'assets/jee.json.enc']) {
      for (final q in bank(f)) {
        if (((q['question_latex'] ?? '') as String).contains('tabular')) bad.add('${q['id']}');
      }
    }
    expect(bad, isEmpty, reason: 'tabular survives in: ${bad.take(10)}');
  });

  test('no question_latex contains leftover CSS/HTML (Match-List regression guard)', () {
    final css = RegExp(
        r'border-collapse|border-spacing|data-theme|\.tg[\s.{]|'
        r'text-align\s*:|background-color\s*:|font-family\s*:|<style');
    final bad = <String>[];
    for (final f in ['assets/neet.json.enc', 'assets/jee.json.enc']) {
      for (final q in bank(f)) {
        if (css.hasMatch((q['question_latex'] ?? '') as String)) bad.add('${q['id']}');
      }
    }
    expect(bad, isEmpty, reason: 'raw CSS/HTML leaked into: ${bad.take(10)}');
  });

  // USER-FACING gate: question text + options must render (after sanitize).
  // Residual = 17 after the sanitizer pass added \over-lookahead + gathered/
  // \matrix/\limits/\tag/\AA/\cdotp handling (was ~62). The rest are genuinely
  // truncated/garbled source (e.g. a bare "\left") that degrade to readable
  // plain text. Threshold catches a real regression without flapping.
  test('user-facing (question + options) render breakage stays bounded', () {
    int broken = 0;
    final ex = <String>[];
    for (final f in ['assets/neet.json.enc', 'assets/jee.json.enc']) {
      for (final q in bank(f)) {
        final okQ = fieldOk((q['question_latex'] ?? '') as String);
        final okO = ((q['options'] as List?) ?? []).every((o) => fieldOk(o.toString()));
        if (!okQ || !okO) {
          broken++;
          if (ex.length < 12) ex.add('${q['id']}');
        }
      }
    }
    // ignore: avoid_print
    print('user-facing broken question/option render: $broken (residual -> readable fallback)');
    expect(broken, lessThanOrEqualTo(25), reason: 'regression; examples: $ex');
  });

  // SOLUTION (reveal screen) gate. Solutions render via the same TexText path;
  // unparseable ones degrade to readable plain text (never raw LaTeX). Residual
  // = 64 after the sanitizer pass (was ~284); the rest are genuinely garbled
  // source (truncated envs, stray $, mhchem \ce, etc.). Bound catches a bad
  // re-sync without flapping on the known residual.
  test('solution render breakage stays bounded (fallback covers the rest)', () {
    int broken = 0;
    for (final f in ['assets/neet.json.enc', 'assets/jee.json.enc']) {
      for (final q in bank(f)) {
        final sol = (q['solution'] ?? '') as String;
        if (sol.isNotEmpty && !fieldOk(sol)) broken++;
      }
    }
    // ignore: avoid_print
    print('solution render breakage: $broken (residual -> readable fallback)');
    expect(broken, lessThanOrEqualTo(75), reason: 'solution regression');
  });
}
