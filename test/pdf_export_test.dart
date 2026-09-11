import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/database.dart';
import 'package:questionx/services/pdf_service.dart';
import 'package:questionx/utils/crypto.dart';

/// What the exported PDF actually contains.
///
/// Two field reports drove these. Integer questions printed a bare
/// "(A) (B) (C) (D)" with nothing beside the labels, because the template always
/// emitted four slots and fell back to an empty string. And option text came out
/// mangled with stray dollar signs, because this path never ran the LaTeX repair
/// the on-screen renderer uses.

Question q({
  required String id,
  required String stem,
  required String optionsJson,
  String? answerKey,
}) =>
    Question(
      id: id,
      examName: 'NEET',
      year: 2024,
      subject: 'Physics',
      topic: 'Optics',
      difficulty: 'Medium',
      questionLatex: stem,
      optionsJson: optionsJson,
      answerKey: Value(answerKey).present ? answerKey : null,
    );

/// Only the rendered questions. The bundled KaTeX source is ~600 KB of minified
/// JS that happens to contain literals like "(C)", so asserting against the whole
/// document gives false matches.
String body(String html) {
  final start = html.indexOf('<div class="question-box">');
  final end = html.lastIndexOf('</div>');
  return start == -1 ? '' : html.substring(start, end == -1 ? html.length : end);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF export needs no network', () async {
    // The real cause of "options show dollar signs": KaTeX was pulled from
    // jsdelivr, so generating a paper offline left every formula as raw
    // "\$...\$" because nothing was there to typeset it. Repairing the LaTeX
    // beforehand did not help, and could not.
    final html = await PdfService.generateHtmlForTest(
      [q(id: 'k', stem: r'Speed is $20 \mathrm{~cm}/\mathrm{s}$', optionsJson: r'["$2\,\Omega$"]', answerKey: 'A')],
      'T',
      'Physics',
    );
    expect(html, isNot(contains('cdn.jsdelivr')));
    // Note: KaTeX's source contains w3.org MathML/SVG namespace URIs. Those are
    // identifiers, never fetched, so a blanket "no http" assertion is wrong.
    expect(html, isNot(contains('src="http')),
        reason: 'no remotely-loaded script');
    expect(html, isNot(contains('href="http')),
        reason: 'no remotely-loaded stylesheet');
    expect(html, isNot(contains('<script')),
        reason: 'the export WebView runs no JavaScript, so a script is a lie');
    expect(body(html), isNot(contains(r'$')),
        reason: 'a surviving delimiter prints as raw LaTeX');
    expect(body(html), isNot(contains(r'\\math')),
        reason: 'a surviving command prints as raw LaTeX');
  });

  test('an integer question prints no empty option slots', () async {
    final html = await PdfService.generateHtmlForTest(
      [q(id: 'n1', stem: 'Value of x is ____', optionsJson: '[]', answerKey: '5')],
      'T',
      'Physics',
    );
    for (final l in ['(A)', '(B)', '(C)', '(D)']) {
      expect(body(html), isNot(contains(l)),
          reason: 'numeric question must not print an empty $l slot');
    }
    expect(body(html), contains('Answer:'), reason: 'give it a space to write in');
  });

  test('a 4-option MCQ still prints all four', () async {
    final html = await PdfService.generateHtmlForTest(
      [
        q(
          id: 'n2',
          stem: 'Pick one',
          optionsJson: '["1 A","2.5 A","2 A","1.5 A"]',
          answerKey: 'C',
        )
      ],
      'T',
      'Physics',
    );
    for (final l in ['(A)', '(B)', '(C)', '(D)']) {
      expect(body(html), contains(l));
    }
  });

  test('a 2-option question prints exactly two', () async {
    final html = await PdfService.generateHtmlForTest(
      [q(id: 'n3', stem: 'True or false', optionsJson: '["True","False"]', answerKey: 'A')],
      'T',
      'Physics',
    );
    expect(body(html), contains('(A)'));
    expect(body(html), contains('(B)'));
    expect(body(html), isNot(contains('(C)')));
  });

  test('no raw LaTeX survives anywhere in either bank', () {
    // Both earlier attempts at this bug passed hand-written tests and still
    // shipped raw LaTeX to users, so this sweeps every question and option in
    // both shipped banks through the exact pipeline the export uses.
    var fields = 0, dollars = 0, commands = 0;
    final examples = <String>[];
    for (final f in ['assets/neet.json.enc', 'assets/jee.json.enc']) {
      final bank = json.decode(
          DataCrypto.decryptBytes(File(f).readAsBytesSync())) as List;
      for (final q in bank) {
        for (final t in <String>[
          (q['question_latex'] ?? '') as String,
          ...((q['options'] as List?) ?? []).map((o) => o.toString()),
        ].where((t) => t.isNotEmpty)) {
          fields++;
          final out = PdfService.cleanForTest(t);
          if (out.contains(r'$')) {
            dollars++;
            if (examples.length < 5) examples.add('\$ in ${q['id']}');
          }
          if (RegExp(r'\\[a-zA-Z]{2,}').hasMatch(out)) {
            commands++;
            if (examples.length < 10) examples.add('cmd in ${q['id']}');
          }
        }
      }
    }
    // ignore: avoid_print
    print('PDF text pipeline: $fields fields swept');
    expect(dollars, 0, reason: 'raw delimiter would print as-is: $examples');
    expect(commands, 0, reason: 'raw LaTeX command would print as-is: $examples');
  });

  test('option body is a single flex item, so inline maths flows', () async {
    // .opt is display:flex. Left as bare children, every text run, <sub> and
    // fraction became its own flex item laid out as a column: "L" wrapped
    // inside its box while its subscript "1" sat atop the next. Seen in the
    // rendered Q12, invisible in the HTML text.
    final html = await PdfService.generateHtmlForTest(
      [q(id: 'f', stem: 'x', optionsJson: r'["through $L_{1}$ will be $${V \\over R}$$"]', answerKey: 'A')],
      'T', 'Physics',
    );
    final b = body(html);
    expect(b, contains('<span class="opt-body">'));
    // label and body must be the ONLY two children of .opt
    final opt = RegExp(r'<div class="opt">(.*?)</div>', dotAll: true).firstMatch(b)!.group(1)!;
    expect(opt, startsWith('<span class="opt-label">'));
    expect(opt, contains('</span><span class="opt-body">'),
        reason: 'no bare text may sit between label and body');
  });

  test('dense options stack in one column', () async {
    final html = await PdfService.generateHtmlForTest(
      [q(id: 'd', stem: 'x', optionsJson: r'["$${V \\over R}$$","1 A","2 A","3 A"]', answerKey: 'A')],
      'T', 'Physics',
    );
    expect(body(html), contains('options-stack'),
        reason: 'a fraction in a half-width cell wraps into pieces');
  });

  test('short plain options keep the two-column grid', () async {
    final html = await PdfService.generateHtmlForTest(
      [q(id: 's', stem: 'x', optionsJson: '["1 A","2.5 A","2 A","1.5 A"]', answerKey: 'C')],
      'T', 'Physics',
    );
    expect(body(html), isNot(contains('options-stack')));
  });

  test('stray dollar-sign damage is repaired before export', () async {
    // The exact shape reported in the app: a `\$\$\$` run left by the scrape.
    final html = await PdfService.generateHtmlForTest(
      [
        q(
          id: 'n4',
          stem: r'To the left of $$\omega$$$_{r}$, the circuit is capacitive.',
          optionsJson: r'["2.56 $$\mu$$F"]',
          answerKey: 'A',
        )
      ],
      'T',
      'Physics',
    );
    expect(body(html), isNot(contains(r'$$$')),
        reason: 'a triple-dollar run reaching KaTeX renders as garbage');
  });
}
