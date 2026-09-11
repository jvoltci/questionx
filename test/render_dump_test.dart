import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/database.dart';
import 'package:questionx/services/pdf_service.dart';
import 'package:questionx/utils/crypto.dart';

/// Dumps the real export HTML for chosen questions so headless Chrome can
/// render it. Android's print WebView is the same Blink engine, so this is a
/// faithful stand-in for what a student's PDF looks like.
///
/// Driven by tool/render_check.sh. Skipped in a normal test run.
///
/// Why this exists: three PDF fixes in a row passed their HTML-level tests and
/// still shipped broken to users, because nothing ever looked at the rendered
/// page. The fourth defect (flex fragmenting inline maths) was invisible in
/// the HTML and obvious in one glance at a render.
void main() {
  test('dump export HTML for visual check', () async {
    final env = Platform.environment['QX_IDS'];
    if (env == null || env.isEmpty) {
      markTestSkipped('set QX_IDS=<id,id,...> (see tool/render_check.sh)');
      return;
    }
    final ids = env.split(',');
    final bank = json.decode(DataCrypto.decryptBytes(
        File('assets/jee.json.enc').readAsBytesSync())) as List;
    final qs = <Question>[];
    for (final id in ids) {
      final q = bank.firstWhere((x) => x['id'] == id);
      qs.add(Question(
        id: id, examName: 'JEE Main', year: q['year'] ?? 2023,
        subject: q['subject'] ?? 'Physics', topic: q['topic'] ?? 'x',
        difficulty: 'Medium', questionLatex: q['question_latex'],
        optionsJson: jsonEncode(q['options'] ?? []),
        answerKey: q['answer_key']));
    }
    final html = await PdfService.generateHtmlForTest(qs, 'Render check', 'Physics');
    File('/tmp/qx_render.html').writeAsStringSync(html);
    // ignore: avoid_print
    print('WROTE /tmp/qx_render.html (${html.length} bytes)');
  });
}
