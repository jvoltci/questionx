import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_math_fork/src/parser/tex/settings.dart';
import 'package:questionx/utils/crypto.dart';

/// Render-safety net for QuestionX (it shipped with ZERO tests). Parses every
/// question's inline math the same way TexText does (Math.tex → TexParser) and:
///  1. hard-fails if any question still contains \begin{tabular} (the Match-List
///     regression that rendered as a red raw-LaTeX dump), and
///  2. fails if the overall math parse-failure rate exceeds a small threshold
///     (catches a systemic break while tolerating rare scraped-data quirks).
void main() {
  final mathPattern = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);

  bool parses(String tex) {
    try {
      TexParser(tex, const TexParserSettings()).parse();
      return true;
    } catch (_) {
      return false;
    }
  }

  Iterable<String> mathSegments(String s) sync* {
    for (final m in mathPattern.allMatches(s)) {
      final t = (m.group(1) ?? m.group(2) ?? '').trim();
      if (t.isNotEmpty) yield t;
    }
  }

  test('no question contains \\begin{tabular} (Match-List regression guard)', () {
    final offenders = <String>[];
    for (final f in ['assets/neet.json.enc', 'assets/jee.json.enc']) {
      final list = json.decode(DataCrypto.decryptBytes(File(f).readAsBytesSync()))
          as List<dynamic>;
      for (final q in list) {
        final t = (q['question_latex'] ?? '') as String;
        if (t.contains('tabular')) offenders.add('${q['id']}');
      }
    }
    expect(offenders, isEmpty, reason: 'tabular survives in: ${offenders.take(10)}');
  });

  // ~1.66% of math segments across the 18k scraped bank fail to parse (stray
  // single `$`, exotic commands). That's pre-existing content noise, mostly
  // minor (TexText renders the raw text as a fallback). This gate is a
  // SYSTEMIC-break detector: it tolerates the baseline but trips if a change
  // (or bad re-sync) breaks rendering broadly.
  test('inline math parse-failure rate stays near baseline (systemic guard)', () {
    int total = 0, failed = 0;
    final examples = <String>[];
    for (final f in ['assets/neet.json.enc', 'assets/jee.json.enc']) {
      final list = json.decode(DataCrypto.decryptBytes(File(f).readAsBytesSync()))
          as List<dynamic>;
      for (final q in list) {
        final texts = <String>[
          (q['question_latex'] ?? '') as String,
          ...((q['options'] as List<dynamic>?) ?? []).map((e) => e.toString()),
        ];
        for (final txt in texts) {
          for (final seg in mathSegments(txt)) {
            total++;
            if (!parses(seg)) {
              failed++;
              if (examples.length < 15) examples.add('${q['id']}: $seg');
            }
          }
        }
      }
    }
    final rate = total == 0 ? 0.0 : failed / total;
    // ignore: avoid_print
    print('math segments: $total, failed: $failed (${(rate * 100).toStringAsFixed(2)}%)');
    if (examples.isNotEmpty) {
      // ignore: avoid_print
      print('first failures:\n${examples.join('\n')}');
    }
    expect(rate, lessThan(0.025), reason: '$failed/$total math segments unrenderable');
  });
}
