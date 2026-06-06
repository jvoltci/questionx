import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';

class TexText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color textColor;

  const TexText(
    this.text, {
    super.key,
    this.style,
    this.textColor = Colors.white,
  });

  static final _mathPattern = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);

  /// Convert the legacy-TeX constructs flutter_math (KaTeX subset) can't parse
  /// into supported equivalents, so scraped MathType/Word LaTeX still renders.
  static String _sanitize(String t) {
    var s = t;
    s = s.replaceAll(r'\n', ' '); // literal backslash-n artifacts in list/statement Qs
    s = s.replaceAll(
        RegExp(r'\\(displaystyle|scriptstyle|textstyle|scriptscriptstyle)\b'), '');
    s = s.replaceAll(RegExp(r'\\(raise|lower)[0-9.]+ex'), '');
    s = s.replaceAll(RegExp(r'\\kern-?[0-9.]+em'), '');
    s = s.replaceAllMapped(RegExp(r'\\hbox\{([^{}]*)\}'), (m) => '\\text{${m[1]}}');
    s = s.replaceAllMapped(
        RegExp(r'\\operatorname\s*\{([^{}]*)\}'), (m) => '\\mathrm{${m[1]}}');
    final over = RegExp(r'\{([^{}]*)\\over([^{}]*)\}');
    for (var i = 0; i < 4 && over.hasMatch(s); i++) {
      s = s.replaceAllMapped(over, (m) => '\\frac{${m[1]}}{${m[2]}}');
    }
    return s;
  }

  /// Last-resort readable plain text when a segment still won't parse — far
  /// better than dumping raw red "\sqrt{1+\mu}" at the student.
  static String _plainFallback(String tex) {
    var s = tex.replaceAll(r'\n', ' ');
    s = s.replaceAllMapped(
        RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}'), (m) => '(${m[1]})/(${m[2]})');
    s = s.replaceAllMapped(RegExp(r'\\sqrt\s*\{([^{}]*)\}'), (m) => '√(${m[1]})');
    const sym = {
      r'\times': '×', r'\cdot': '·', r'\pm': '±', r'\div': '÷', r'\sqrt': '√',
      r'\theta': 'θ', r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\mu': 'μ',
      r'\pi': 'π', r'\omega': 'ω', r'\lambda': 'λ', r'\Delta': 'Δ', r'\sigma': 'σ',
      r'\infty': '∞', r'\rightarrow': '→', r'\circ': '°', r'\le': '≤', r'\ge': '≥',
      r'\sin': 'sin', r'\cos': 'cos', r'\tan': 'tan', r'\log': 'log',
    };
    sym.forEach((k, v) => s = s.replaceAll(k, v));
    s = s
        .replaceAll(RegExp(r'\\[a-zA-Z]+'), '') // strip remaining commands
        .replaceAll(RegExp(r'[{}$]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle =
        style ?? GoogleFonts.inter(color: textColor, fontSize: 15, height: 1.6);

    final widgets = <Widget>[];
    int last = 0;
    for (final m in _mathPattern.allMatches(text)) {
      if (m.start > last) {
        final plain = text.substring(last, m.start);
        if (plain.isNotEmpty) widgets.add(Text(plain, style: baseStyle));
      }
      final isDisplay = m.group(1) != null;
      final tex = (m.group(1) ?? m.group(2) ?? '').trim();
      if (tex.isNotEmpty) widgets.add(_mathBox(tex, baseStyle, isDisplay));
      last = m.end;
    }
    if (last < text.length) {
      final tail = text.substring(last);
      if (tail.isNotEmpty) widgets.add(Text(tail, style: baseStyle));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.start,
      runSpacing: 6,
      spacing: 4,
      children: widgets,
    );
  }

  Widget _mathBox(String tex, TextStyle baseStyle, bool isDisplay) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      constraints: const BoxConstraints(maxWidth: double.infinity),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Math.tex(
          _sanitize(tex),
          textStyle: baseStyle.copyWith(fontFamily: 'SansSerif'),
          mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
          // Never dump raw LaTeX at the student: degrade to readable plain text.
          onErrorFallback: (err) => Text(_plainFallback(tex), style: baseStyle),
        ),
      ),
    );
  }
}
