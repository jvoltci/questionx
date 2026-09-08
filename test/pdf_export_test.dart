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

void main() {
  test('an integer question prints no empty option slots', () async {
    final html = await PdfService.generateHtmlForTest(
      [q(id: 'n1', stem: 'Value of x is ____', optionsJson: '[]', answerKey: '5')],
      'T',
      'Physics',
    );
    for (final l in ['(A)', '(B)', '(C)', '(D)']) {
      expect(html, isNot(contains(l)),
          reason: 'numeric question must not print an empty $l slot');
    }
    expect(html, contains('Answer:'), reason: 'give it a space to write in');
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
      expect(html, contains(l));
    }
  });

  test('a 2-option question prints exactly two', () async {
    final html = await PdfService.generateHtmlForTest(
      [q(id: 'n3', stem: 'True or false', optionsJson: '["True","False"]', answerKey: 'A')],
      'T',
      'Physics',
    );
    expect(html, contains('(A)'));
    expect(html, contains('(B)'));
    expect(html, isNot(contains('(C)')));
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
    expect(html, isNot(contains(r'$$$')),
        reason: 'a triple-dollar run reaching KaTeX renders as garbage');
  });
}
