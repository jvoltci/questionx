import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../database.dart';

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

      // Diagram handling
      String svgHtml = '';
      if (q.questionSvg != null && q.questionSvg!.isNotEmpty) {
        svgHtml = '<div class="q-img">${q.questionSvg}</div>';
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

          <div class="options-grid">
            <div class="opt"><span class="opt-label">(A)</span> ${_cleanForKaTeX(options.isNotEmpty ? options[0] : '')}</div>
            <div class="opt"><span class="opt-label">(B)</span> ${_cleanForKaTeX(options.length > 1 ? options[1] : '')}</div>
            <div class="opt"><span class="opt-label">(C)</span> ${_cleanForKaTeX(options.length > 2 ? options[2] : '')}</div>
            <div class="opt"><span class="opt-label">(D)</span> ${_cleanForKaTeX(options.length > 3 ? options[3] : '')}</div>
          </div>
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
    String clean = text.replaceAll('\n', ' ');

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
