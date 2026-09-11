import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/services/latex_to_html.dart';

/// LaTeX -> HTML for the PDF export.
///
/// The export's WebView runs no JavaScript (printing 5.14.3 constructs a bare
/// `new WebView(context)` and never enables it), so KaTeX could never typeset
/// anything. Everything here has to come out as plain HTML.
void main() {
  test('no dollar signs or backslashes survive', () {
    for (final tex in [
      r'\mathrm{A}', r'20 \mathrm{~cm} / \mathrm{s}', r'\frac{1}{2}mv^2',
      r'K_{1}', r'\chi=\frac{1}{3}', r'2.5 \mu\mathrm{F}',
      r'\sqrt{2}', r'\alpha \times 10^{-5}', r'x \leq 5',
    ]) {
      final out = latexToHtml(tex);
      expect(out, isNot(contains(r'$')), reason: tex);
      expect(out, isNot(contains(r'\')), reason: tex);
    }
  });

  test('subscripts and superscripts become real HTML', () {
    expect(latexToHtml('K_{1}'), 'K<sub>1</sub>');
    expect(latexToHtml('x^2'), 'x<sup>2</sup>');
    expect(latexToHtml(r'10^{-5}'), '10<sup>-5</sup>');
  });

  test('fractions become stacked markup, not a slash', () {
    final out = latexToHtml(r'\frac{1}{2}');
    expect(out, contains('class="frac"'));
    expect(out, contains('<span class="fnum">1</span>'));
    expect(out, contains('<span class="fden">2</span>'));
  });

  test('nested fractions recurse', () {
    final out = latexToHtml(r'\frac{K_{1}}{2}');
    expect(out, contains('K<sub>1</sub>'));
  });

  test('greek and operators become unicode', () {
    expect(latexToHtml(r'\mu'), 'μ');
    expect(latexToHtml(r'\Omega'), 'Ω');
    expect(latexToHtml(r'\times'), '×');
    expect(latexToHtml(r'\leq'), '≤');
    expect(latexToHtml(r'\rightarrow'), '→');
  });

  test('formatting wrappers drop but keep their contents', () {
    expect(latexToHtml(r'\mathrm{NH}_3'), 'NH<sub>3</sub>');
    expect(latexToHtml(r'\text{hello}'), 'hello');
  });

  test('square roots read correctly', () {
    expect(latexToHtml(r'\sqrt{2}'), '√(2)');
  });

  test('a real question fragment from the report', () {
    // Q1 in the screenshot printed as raw "$$\mathrm{A}$$ ... $$\chi=\frac{1}{3}$$".
    final out = latexToHtml(r'\chi=\frac{1}{3}');
    expect(out, startsWith('χ='));
    expect(out, contains('class="frac"'));
    expect(out, isNot(contains(r'\')));
  });

  test('empty input is safe', () => expect(latexToHtml(''), ''));
}
