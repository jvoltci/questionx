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
          tex,
          textStyle: baseStyle.copyWith(fontFamily: 'SansSerif'),
          mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
          onErrorFallback: (err) =>
              Text(tex, style: baseStyle.copyWith(color: Colors.red)),
        ),
      ),
    );
  }
}
