import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:questionx/database.dart';
import 'package:questionx/widgets/source_exam_badge.dart';

Question q(String exam) => Question(
      id: exam, examName: exam, year: 2023, subject: 'Physics',
      topic: 'Thermodynamics', difficulty: 'Medium', questionLatex: 'x',
      optionsJson: '[]');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('a single-exam set is not mixed', () {
    expect(SourceExamBadge.isMixedSet([q('NEET'), q('NEET')]), isFalse);
    expect(SourceExamBadge.isMixedSet([q('JEE Main'), q('JEE Main')]), isFalse);
  });

  test('NEET + JEE is mixed', () {
    expect(SourceExamBadge.isMixedSet([q('NEET'), q('JEE Main')]), isTrue);
  });

  test('JEE Main + JEE Advanced is mixed', () {
    expect(SourceExamBadge.isMixedSet([q('JEE Main'), q('JEE Advanced')]), isTrue);
  });

  testWidgets('labels each family distinctly', (tester) async {
    for (final e in {'NEET': 'NEET', 'JEE Main': 'JEE MAIN',
                     'JEE Advanced': 'JEE ADV'}.entries) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SourceExamBadge(e.key))));
      expect(find.text(e.value), findsOneWidget, reason: e.key);
    }
  });
}
