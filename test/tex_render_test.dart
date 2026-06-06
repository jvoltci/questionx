import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_math_fork/src/parser/tex/settings.dart';
import 'package:questionx/utils/crypto.dart';

/// Render-safety net for QuestionX. Validates the SHIPPED (encrypted) banks the
/// same way TexText does — sanitize() then Math.tex/TexParser — and gates the
/// user-facing breakage so the "raw \sqrt in the question" regression can't
/// silently return. (QuestionX shipped with zero tests; this is the floor.)

// Mirror of TexText._sanitize — keep in sync.
String sanitize(String t) {
  var s = t;
  s = s.replaceAll(r'\n', ' ');
  s = s.replaceAll(RegExp(r'\\(displaystyle|scriptstyle|textstyle|scriptscriptstyle)\b'), '');
  s = s.replaceAll(RegExp(r'\\(raise|lower)[0-9.]+ex'), '');
  s = s.replaceAll(RegExp(r'\\kern-?[0-9.]+em'), '');
  s = s.replaceAllMapped(RegExp(r'\\hbox\{([^{}]*)\}'), (m) => '\\text{${m[1]}}');
  s = s.replaceAllMapped(RegExp(r'\\operatorname\s*\{([^{}]*)\}'), (m) => '\\mathrm{${m[1]}}');
  final over = RegExp(r'\{([^{}]*)\\over([^{}]*)\}');
  for (var i = 0; i < 4 && over.hasMatch(s); i++) {
    s = s.replaceAllMapped(over, (m) => '\\frac{${m[1]}}{${m[2]}}');
  }
  return s;
}

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

  // USER-FACING gate: question text + options must render (after sanitize).
  // Baseline after the LaTeX-repair pass: ~62 residual (rendered as readable
  // plain-text fallback, never raw LaTeX). Threshold catches a real regression
  // (e.g. a bad re-sync) without flapping on the known residual.
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
    expect(broken, lessThanOrEqualTo(80), reason: 'regression; examples: $ex');
  });
}
