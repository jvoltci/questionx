import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../database.dart';
import '../utils/answer_grading.dart';
import '../widgets/tex_normalize.dart';
import 'diagram_storage.dart';
import 'latex_to_html.dart';

class PdfService {
  /// Generates a Professional Exam PDF using KaTeX (High Performance)
  static Future<void> generateExamPdf({
    required List<Question> questions,
    required String title,
    required String subject,
  }) async {
    // 1. Prepare HTML
    final htmlContent = await _generateHtml(questions, title, subject);

    // 2. Convert to PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return await Printing.convertHtml(format: format, html: htmlContent);
      },
      name: 'QuestionX_Exam_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Test hook: the exported HTML is what students actually receive, so it is
  /// worth asserting on directly.
  @visibleForTesting
  static Future<String> generateHtmlForTest(
    List<Question> questions,
    String title,
    String subject,
  ) =>
      _generateHtml(questions, title, subject);

  static Future<String> _generateHtml(
    List<Question> questions,
    String title,
    String subject,
  ) async {
    StringBuffer bodyHtml = StringBuffer();

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      List<String> options = [];
      try {
        options = List<String>.from(jsonDecode(q.optionsJson));
      } catch (_) {}

      // Diagram handling: the question_svg field is either an external
      // filename (e.g. "AIPMT_2013_Phy_8.jpg") backed by a file under
      // ${docs}/diagrams/, or a legacy inline <svg>...</svg> blob. Render
      // both into self-contained HTML so the printing engine can embed them
      // without needing filesystem access.
      String svgHtml = '';
      if (q.questionSvg != null && q.questionSvg!.isNotEmpty) {
        final v = q.questionSvg!;
        if (DiagramStorage.isFilenameReference(v)) {
          final file = await DiagramStorage.fileFor(v);
          if (file != null) {
            final bytes = await file.readAsBytes();
            final lower = v.toLowerCase();
            final mime = lower.endsWith('.png')
                ? 'image/png'
                : lower.endsWith('.webp')
                    ? 'image/webp'
                    : 'image/jpeg';
            final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
            svgHtml =
                '<div class="q-img"><img src="$dataUrl" style="max-width:100%;"/></div>';
          }
        } else {
          // Legacy inline SVG (or any literal HTML) — pass through unchanged.
          svgHtml = '<div class="q-img">$v</div>';
        }
      }

      // Only render the options that exist. The old template always emitted
      // four slots and fell back to an empty string, so every integer/numeric
      // question printed a bare "(A) (B) (C) (D)" with nothing beside the
      // labels. Roughly a quarter of the JEE bank is numeric, so this was on a
      // lot of exported papers. Those get a ruled answer space instead.
      final isNumeric = AnswerGrading.typeOf(
            options: options,
            answerKey: q.answerKey,
          ) ==
          QType.numeric;

      final String answerBlock;
      if (isNumeric) {
        answerBlock = '<div class="numeric-answer">Answer: '
            '<span class="rule"></span></div>';
      } else {
        // Two columns only when every option is short prose. A fraction or a
        // long expression in a half-width cell wraps into unreadable pieces,
        // which is what the Q12 report showed.
        final rendered = options.map(_cleanForKaTeX).toList();
        final dense = rendered.any(
            (o) => o.contains('class="frac"') || o.length > 60);
        final buf = StringBuffer(dense
            ? '<div class="options-grid options-stack">'
            : '<div class="options-grid">');
        for (var o = 0; o < options.length; o++) {
          final label = String.fromCharCode(65 + o);
          // The body is ONE span on purpose. .opt is a flex row, and in a flex
          // container every bare text run, <sub> and fraction becomes its own
          // flex item laid out side by side as a column. That is how "L" wrapped
          // inside its own box while its subscript "1" sat at the top of the
          // next, and why long expressions overflowed (flex items default to
          // min-width:auto). One child restores normal inline flow.
          buf.write('<div class="opt"><span class="opt-label">($label)</span>'
              '<span class="opt-body">${rendered[o]}</span></div>');
        }
        buf.write('</div>');
        answerBlock = buf.toString();
      }

      bodyHtml.write("""
        <div class="question-box">
          <div class="q-header">
            <span class="q-num">Q${i + 1}.</span>
            <span class="q-meta">(${q.year})</span>
          </div>
          
          <div class="q-text">
            ${_cleanForKaTeX(q.questionLatex)}
          </div>

          $svgHtml

          $answerBlock
        </div>
      """);
    }

    return """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>$title</title>
      
      <style>$kLatexHtmlCss</style>

      <style>
        /* Use system fonts to avoid network hangs */
        body { font-family: Helvetica, Arial, sans-serif; padding: 20px; color: #000; font-size: 12px; }
        
        h1 { text-align: center; font-size: 24px; border-bottom: 2px solid #000; padding-bottom: 10px; margin-bottom: 5px; text-transform: uppercase; }
        .sub-header { text-align: center; margin-bottom: 30px; font-style: italic; color: #444; font-size: 12px; }
        
        .container { column-count: 2; column-gap: 30px; column-rule: 1px solid #ccc; }
        
        .question-box { break-inside: avoid; margin-bottom: 20px; padding-bottom: 15px; border-bottom: 1px dashed #ddd; }
        .q-header { font-weight: bold; margin-bottom: 5px; color: #000; }
        .q-num { font-size: 1.1em; margin-right: 5px; }
        .q-meta { font-size: 0.85em; color: #555; }
        
        .q-text { margin-bottom: 10px; line-height: 1.4; text-align: justify; }
        
        /* Force Diagrams to fit */
        .q-img { margin: 10px auto; text-align: center; max-width: 100%; }
        .q-img svg { max-width: 100% !important; height: auto !important; max-height: 150px; }
        
        .numeric-answer { margin-top: 6px; font-size: 12px; color: #333; }
        .rule { display: inline-block; border-bottom: 1px solid #555; width: 120px; }
        .options-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 5px; }
        .options-stack { grid-template-columns: 1fr; }
        .opt { font-size: 1em; display: flex; align-items: flex-start; }
        .opt-label { font-weight: bold; margin-right: 5px; min-width: 20px; }
        .opt-body { flex: 1; min-width: 0; overflow-wrap: anywhere; }
      </style>
    </head>
    <body>
      <h1>$title</h1>
      <div class="sub-header">Subject: $subject  •  Total Questions: ${questions.length}</div>
      

      <div class="container">
        $bodyHtml
      </div>
    </body>
    </html>
    """;
  }

  // Helper to ensure LaTeX format is friendly to KaTeX auto-render
  /// Question or option text, ready to drop into the exported HTML.
  ///
  /// Math spans are converted to HTML here rather than left as `$...$` for
  /// KaTeX, because the export's WebView runs no JavaScript (see
  /// latex_to_html.dart). Anything left in delimiters would print as raw LaTeX,
  /// which is exactly what users kept reporting.
  /// Test hook for the exact text pipeline the export uses.
  @visibleForTesting
  static String cleanForTest(String text) => _cleanForKaTeX(text);

  static String _cleanForKaTeX(String text) {
    if (text.isEmpty) return "";
    // Run the SAME repair the on-screen renderer uses, so the export starts from
    // the corrected LaTeX rather than the raw scraped source.
    String clean = normalizeForRender(text).replaceAll('\n', ' ');

    final buf = StringBuffer();
    var pos = 0;
    for (final m in appMathPattern.allMatches(clean)) {
      buf.write(_escapeText(clean.substring(pos, m.start)));
      buf.write(latexToHtml((m.group(1) ?? m.group(2) ?? '').trim()));
      pos = m.end;
    }
    final tail = clean.substring(pos);
    // Prose with no delimiters can still carry bare commands; convert those too
    // so a stray backslash never reaches the page.
    buf.write(tail.contains(r'\') ? latexToHtml(tail) : _escapeText(tail));

    // Final guarantee. Where the source delimiters are broken outright, LaTeX
    // ends up in the prose segments rather than the math ones, so neither branch
    // above sees it. Sweeping the assembled string is the only place that
    // catches every case. The markup emitted above contains no backslash or
    // dollar, so this cannot damage it.
    return buf
        .toString()
        .replaceAll(RegExp(r'\\[a-zA-Z]+\s*'), '')
        .replaceAll(RegExp(r'[\\\$]'), '')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  }

  /// Escapes the characters a browser would read as markup. Questions contain
  /// real text arrows ("A -> B") and inequalities ("index < 1").
  static String _escapeText(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

}
