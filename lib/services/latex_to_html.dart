/// Converts LaTeX to plain HTML for the PDF export.
///
/// **Why not KaTeX.** The export goes through `Printing.convertHtml`, whose
/// Android implementation is `new WebView(context)` with no
/// `setJavaScriptEnabled(true)` (printing 5.14.3, PrintingJob.java:370), and it
/// prints on `onPageFinished`. JavaScript therefore never runs, so KaTeX could
/// never typeset anything — whether loaded from a CDN or bundled. Two earlier
/// attempts missed that and fixed the wrong layer.
///
/// HTML and CSS do render, so sub/superscripts and fractions come out properly
/// typeset here without a line of script.
library;

/// Commands whose braces are formatting only — keep the contents, drop the wrapper.
final _wrappers = RegExp(
    r'\\(?:mathrm|mathbf|mathit|mathsf|text|textbf|textit|rm|bf|it|operatorname|mbox|hbox)\s*\{');

const Map<String, String> _symbols = {
  r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
  r'\epsilon': 'ε', r'\varepsilon': 'ε', r'\zeta': 'ζ', r'\eta': 'η',
  r'\theta': 'θ', r'\vartheta': 'ϑ', r'\iota': 'ι', r'\kappa': 'κ',
  r'\lambda': 'λ', r'\mu': 'μ', r'\nu': 'ν', r'\xi': 'ξ', r'\pi': 'π',
  r'\rho': 'ρ', r'\sigma': 'σ', r'\tau': 'τ', r'\upsilon': 'υ', r'\phi': 'φ',
  r'\varphi': 'φ', r'\chi': 'χ', r'\psi': 'ψ', r'\omega': 'ω',
  r'\Gamma': 'Γ', r'\Delta': 'Δ', r'\Theta': 'Θ', r'\Lambda': 'Λ', r'\Xi': 'Ξ',
  r'\Pi': 'Π', r'\Sigma': 'Σ', r'\Upsilon': 'Υ', r'\Phi': 'Φ', r'\Psi': 'Ψ',
  r'\Omega': 'Ω',
  r'\times': '×', r'\cdot': '·', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
  r'\leq': '≤', r'\le': '≤', r'\geq': '≥', r'\ge': '≥', r'\neq': '≠',
  r'\ne': '≠', r'\approx': '≈', r'\equiv': '≡', r'\propto': '∝',
  r'\infty': '∞', r'\partial': '∂', r'\nabla': '∇', r'\degree': '°',
  r'\circ': '°', r'\prime': '′', r'\angle': '∠', r'\perp': '⊥',
  r'\parallel': '∥', r'\sum': '∑', r'\prod': '∏', r'\int': '∫',
  r'\rightarrow': '→', r'\to': '→', r'\leftarrow': '←',
  r'\leftrightarrow': '↔', r'\Rightarrow': '⇒', r'\Leftarrow': '⇐',
  r'\Leftrightarrow': '⇔', r'\rightleftharpoons': '⇌', r'\longrightarrow': '⟶',
  r'\in': '∈', r'\notin': '∉', r'\subset': '⊂', r'\cup': '∪', r'\cap': '∩',
  r'\forall': '∀', r'\exists': '∃', r'\therefore': '∴', r'\because': '∵',
  r'\ldots': '…', r'\cdots': '⋯', r'\dots': '…', r'\hbar': 'ℏ', r'\ell': 'ℓ',
  r'\AA': 'Å', r'\%': '%', r'\&': '&amp;', r'\_': '_',
};

/// Contents of the brace group starting at [open] (which must index a `{`).
String _group(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '{') depth++;
    if (s[i] == '}') {
      depth--;
      if (depth == 0) return s.substring(open + 1, i);
    }
  }
  return s.substring(open + 1);
}

/// Index just past the brace group starting at [open].
int _groupEnd(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '{') depth++;
    if (s[i] == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return s.length;
}

String _stripWrappers(String s) {
  var out = s;
  for (var guard = 0; guard < 30; guard++) {
    final m = _wrappers.firstMatch(out);
    if (m == null) break;
    final open = m.end - 1;
    out = out.substring(0, m.start) +
        _group(out, open) +
        out.substring(_groupEnd(out, open));
  }
  return out;
}

/// Plain-TeX `{A \over B}` -> fraction markup.
///
/// The banks are full of this form (`{V \over R}`, `{{{L_2}} \over {{L_1}+{L_2}}}`)
/// because MathType and examside emit it instead of `\frac`. Handling only
/// `\frac` left every one of these flattened to "V R" in the export, which is
/// what the user's Q12 screenshot showed. Innermost groups first, so nesting
/// works.
String _overFractions(String s) {
  const skip = '@@OVERCMD@@';
  var out = s;
  for (var guard = 0; guard < 40; guard++) {
    final idx = out.indexOf(r'\over');
    if (idx == -1) break;
    final after = idx + 5;
    // \overline, \overrightarrow etc. are not the primitive.
    if (after < out.length && RegExp(r'[a-zA-Z]').hasMatch(out[after])) {
      out = '${out.substring(0, idx)}$skip${out.substring(after)}';
      continue;
    }
    // Walk back to the `{` that opens the group containing this \over.
    var depth = 0;
    var open = -1;
    for (var i = idx - 1; i >= 0; i--) {
      if (out[i] == '}') depth++;
      if (out[i] == '{') {
        if (depth == 0) {
          open = i;
          break;
        }
        depth--;
      }
    }
    if (open == -1) {
      final num = out.substring(0, idx).trim();
      final den = out.substring(after).trim();
      return '<span class="frac"><span class="fnum">${latexToHtml(num)}</span>'
          '<span class="fden">${latexToHtml(den)}</span></span>';
    }
    final close = _groupEnd(out, open);
    final num = out.substring(open + 1, idx).trim();
    final den = out.substring(after, close - 1).trim();
    out = '${out.substring(0, open)}'
        '<span class="frac"><span class="fnum">${latexToHtml(num)}</span>'
        '<span class="fden">${latexToHtml(den)}</span></span>'
        '${out.substring(close)}';
  }
  return out.replaceAll(skip, r'\over');
}

String _fractions(String s) {
  var out = s;
  for (var guard = 0; guard < 30; guard++) {
    final m = RegExp(r'\\(?:d?frac|tfrac)\s*\{').firstMatch(out);
    if (m == null) break;
    final n1 = m.end - 1;
    final num = _group(out, n1);
    var after = _groupEnd(out, n1);
    while (after < out.length && out[after] == ' ') {
      after++;
    }
    if (after >= out.length || out[after] != '{') {
      // Malformed; drop the command so it cannot leak a backslash.
      out = out.substring(0, m.start) + num + out.substring(_groupEnd(out, n1));
      continue;
    }
    final den = _group(out, after);
    out = '${out.substring(0, m.start)}'
        '<span class="frac"><span class="fnum">${latexToHtml(num)}</span>'
        '<span class="fden">${latexToHtml(den)}</span></span>'
        '${out.substring(_groupEnd(out, after))}';
  }
  return out;
}

String _scripts(String s) {
  final b = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if ((c == '^' || c == '_') && i + 1 < s.length) {
      final tag = c == '^' ? 'sup' : 'sub';
      if (s[i + 1] == '{') {
        final inner = _group(s, i + 1);
        b.write('<$tag>${latexToHtml(inner)}</$tag>');
        i = _groupEnd(s, i + 1);
      } else {
        b.write('<$tag>${s[i + 1]}</$tag>');
        i += 2;
      }
      continue;
    }
    b.write(c);
    i++;
  }
  return b.toString();
}

/// LaTeX -> HTML. Safe to call on a fragment; recurses for nested groups.
String latexToHtml(String tex) {
  if (tex.isEmpty) return '';
  var s = tex;

  // \sqrt{x} -> √(x) before generic command stripping takes the backslash.
  for (var guard = 0; guard < 20; guard++) {
    final m = RegExp(r'\\sqrt\s*\{').firstMatch(s);
    if (m == null) break;
    final open = m.end - 1;
    s = '${s.substring(0, m.start)}√(${latexToHtml(_group(s, open))})'
        '${s.substring(_groupEnd(s, open))}';
  }

  s = _stripWrappers(s);
  s = _overFractions(s);
  s = _fractions(s);

  _symbols.forEach((k, v) {
    // Word boundary so \pi does not also match inside \pi... commands.
    s = s.replaceAll(RegExp('${RegExp.escape(k)}(?![a-zA-Z])'), v);
  });

  // Spacing commands, then anything else still unrecognised.
  s = s.replaceAll(RegExp(r'\\[,;:!> ]'), ' ');
  s = s.replaceAll(RegExp(r'\\left|\\right'), '');
  s = s.replaceAll(RegExp(r'\\[a-zA-Z]+\s*'), '');

  s = _scripts(s);
  s = s.replaceAll(RegExp(r'[{}]'), '');

  // Final sweep. The conversions above handle what is recognised; this catches
  // the residue from genuinely malformed source (unbalanced delimiters, commands
  // this table has never seen). Nothing with a backslash or a dollar in it may
  // reach the page, because that is precisely what users kept reporting.
  s = s.replaceAll(RegExp(r'\\[a-zA-Z]+\s*'), '');
  s = s.replaceAll(RegExp(r'[\\\$]'), '');
  return s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
}

/// CSS for the markup [latexToHtml] emits.
const String kLatexHtmlCss = '''
.frac { display: inline-block; vertical-align: middle; text-align: center;
        margin: 0 3px; white-space: nowrap; }
.frac .fnum { display: block; border-bottom: 1px solid currentColor;
              padding: 0 3px; line-height: 1.3; }
.frac .fden { display: block; padding: 0 3px; line-height: 1.3; }
/* No line-height:0 here. It stops the glyph occupying vertical space, so in
   tightly wrapped text the subscript is drawn over the line above, which is
   exactly how "L1" came out as a floating "1" in the user's screenshot. */
/* position:relative rather than vertical-align. A stacked fraction on the same
   line is a two-row inline-block aligned middle, which drags the line's baseline
   down; vertical-align:sub followed it and the "1" of L1 landed a row above its
   L. Relative offset leaves the baseline alone. */
sub, sup { font-size: 0.75em; line-height: 1; position: relative;
           vertical-align: baseline; }
sub { top: 0.35em; }
sup { top: -0.45em; }
''';
