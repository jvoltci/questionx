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

  @override
  Widget build(BuildContext context) {
    List<String> parts = text.split(r'$');
    List<Widget> widgets = [];

    TextStyle baseStyle =
        style ?? GoogleFonts.inter(color: textColor, fontSize: 15, height: 1.6);

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;

      if (i % 2 == 0) {
        widgets.add(Text(parts[i], style: baseStyle));
      } else {
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(maxWidth: double.infinity),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Math.tex(
                parts[i],
                textStyle: baseStyle.copyWith(fontFamily: 'SansSerif'),
                mathStyle: MathStyle.text,
                onErrorFallback: (err) => Text(
                  parts[i],
                  style: baseStyle.copyWith(color: Colors.red),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.start,
      runSpacing: 6,
      spacing: 4,
      children: widgets,
    );
  }
}
