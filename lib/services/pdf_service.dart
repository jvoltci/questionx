import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../database.dart';
import '../utils/answer_grading.dart';
import '../widgets/tex_normalize.dart';
import 'diagram_storage.dart';

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
        final buf = StringBuffer('<div class="options-grid">');
        for (var o = 0; o < options.length; o++) {
          final label = String.fromCharCode(65 + o);
          buf.write('<div class="opt"><span class="opt-label">($label)</span> '
              '${_cleanForKaTeX(options[o])}</div>');
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
      
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
      <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
      <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"
        onload="renderMathInElement(document.body, {
          delimiters: [
            {left: '\$\$', right: '\$\$', display: true},
            {left: '\$', right: '\$', display: false},
            {left: '\\\\(', right: '\\\\)', display: false},
            {left: '\\\\[', right: '\\\\]', display: true}
          ],
          throwOnError: false
        });"></script>

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
        .opt { font-size: 1em; display: flex; align-items: flex-start; }
        .opt-label { font-weight: bold; margin-right: 5px; min-width: 20px; }
      </style>
    </head>
    <body>
      <h1>$title</h1>
      <div class="sub-header">Subject: $subject  •  Total Questions: ${questions.length}</div>
      
      <div id="network-warning" style="display:none; color:red; text-align:center; border:2px solid red; padding:10px; margin-bottom:20px;">
        <strong>⚠️ RENDERING FAILED</strong><br>
        Check your internet connection.
      </div>
      <script>
        // Failsafe: If KaTeX doesn't load in 2 seconds, stop waiting so PDF generates anyway
        setTimeout(() => {
          if (document.getElementsByClassName('katex').length === 0) {
             const test = document.body.innerText;
             if(test.includes('\$')) {
                document.getElementById('network-warning').style.display = 'block';
             }
          }
        }, 2000);
      </script>

      <div class="container">
        $bodyHtml
      </div>
    </body>
    </html>
    """;
  }

  // Helper to ensure LaTeX format is friendly to KaTeX auto-render
  static String _cleanForKaTeX(String text) {
    if (text.isEmpty) return "";
    // Run the SAME repair the on-screen renderer uses. Without this the PDF got
    // the raw scraped LaTeX -- stray `\$` runs, line breaks wrapped into maths,
    // prose typeset as maths -- so exported options came out mangled while the
    // identical question looked fine in the app. Reusing it beats maintaining a
    // second, weaker heuristic here.
    String clean = normalizeForRender(text).replaceAll('\n', ' ');

    // Many source questions encode line breaks as the literal 2-char
    // sequences "\\" or "\n" (backslash + n) — common in Match-the-columns
    // and Assertion-Reason items. If the stem has no other LaTeX commands,
    // these are not math — convert them to real HTML breaks. Otherwise the
    // math-wrap heuristic below would treat the stray backslash as math
    // and wrap the whole English prose in $$...$$.
    final stripped = clean
        .replaceAll(r'\\', '')
        .replaceAll(r'\n', '')
        .replaceAll(r'\t', '');
    final hasRealLatex = stripped.contains(r'\');

    // HTML-escape <,> outside math FIRST — questions sometimes contain text
    // arrows like "A -> B" or inequalities like "modulation index < 1" that
    // the browser would otherwise parse as the start of an HTML tag.
    // Doing this before inserting <br/> ensures our injected tags survive.
    clean = _escapeOutsideMath(clean);

    if (!hasRealLatex) {
      clean = clean
          .replaceAll(r'\\', '<br/>')
          .replaceAll(r'\n', '<br/>')
          .replaceAll(r'\t', '  ');
    }

    // KaTeX auto-render needs explicit delimiters if they are missing
    final hasDelimiter = clean.contains(r'$') || clean.contains(r'\(');
    final hasMathCommand = clean.contains(r'\');

    if (!hasDelimiter && hasMathCommand) {
      return r'$$' + clean + r'$$';
    }
    return clean;
  }

  static String _escapeOutsideMath(String s) {
    final buf = StringBuffer();
    int i = 0;
    while (i < s.length) {
      if (s[i] == r'$') {
        final close = s.indexOf(r'$', i + 1);
        if (close == -1) {
          buf.write(s.substring(i));
          break;
        }
        buf.write(s.substring(i, close + 1));
        i = close + 1;
      } else {
        final c = s[i];
        if (c == '<') {
          buf.write('&lt;');
        } else if (c == '>') {
          buf.write('&gt;');
        } else {
          buf.write(c);
        }
        i++;
      }
    }
    return buf.toString();
  }
}
