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
        margin: 0 2px; }
.frac .fnum { display: block; border-bottom: 1px solid currentColor;
              padding: 0 3px; line-height: 1.25; }
.frac .fden { display: block; padding: 0 3px; line-height: 1.25; }
sub, sup { font-size: 0.72em; line-height: 0; }
''';
