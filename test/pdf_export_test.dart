import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/database.dart';
import 'package:questionx/services/pdf_service.dart';

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
    expect(html, isNot(contains('cdn.jsdelivr')),
        reason: 'a remote asset makes offline export print raw LaTeX');
    // Note: KaTeX's source contains w3.org MathML/SVG namespace URIs. Those are
    // identifiers, never fetched, so a blanket "no http" assertion is wrong.
    expect(html, isNot(contains('src="http')),
        reason: 'no remotely-loaded script');
    expect(html, isNot(contains('href="http')),
        reason: 'no remotely-loaded stylesheet');
    expect(html, contains('renderMathInElement(document.body'),
        reason: 'nothing typesets the maths without this call');
    expect(RegExp(r'url\(fonts/').hasMatch(html), isFalse,
        reason: 'relative font URLs cannot resolve in a bare HTML string');
    expect(RegExp(r'data:font/woff2').allMatches(html).length, greaterThan(10),
        reason: 'KaTeX fonts must be embedded, not linked');
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
