import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tex_normalize.dart';

class TexText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color textColor;

  /// Set to false to disable the double-tap → fullscreen zoom gesture
  /// (used internally by the fullscreen view to prevent recursion).
  final bool enableFullscreen;

  const TexText(
    this.text, {
    super.key,
    this.style,
    this.textColor = Colors.white,
    this.enableFullscreen = true,
  });

  static final _mathPattern = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);

  // ---------------------------------------------------------------------------
  // Chemistry reaction merger
  // ---------------------------------------------------------------------------

  /// Pre-process text to merge fragmented chemical-reaction lines into single
  /// display-math blocks and collapse excessive newlines.
  ///
  /// Scraped chemistry data often stores reactions like:
  ///   `M(s) + $${1\over2}$$ $O_2(g)$ $$\to$$ MO(s)`
  /// creating 7+ alternating Wrap children with mixed fonts/sizing.
  /// This collapses each such line into one `$$...$$` display block.
  @visibleForTesting
  static String mergeChemReactions(String input) {
    // Repair malformed source LaTeX before anything else looks at the
    // delimiters: stray `$` runs from the scrape would otherwise let a math span
    // swallow the surrounding prose. Doing this at render time (rather than as a
    // migration over assets/*.json) means any bank added or re-scraped later is
    // fixed automatically — see lib/widgets/tex_normalize.dart.
    var s = normalizeForRender(input);
    // Collapse \n\n+ → \n for compact rendering on small screens.
    s = s.replaceAll(RegExp(r'\n{2,}'), '\n');

    final lines = s.split('\n');
    final out = <String>[];
    for (final line in lines) {
      if (_isFragmentedReaction(line)) {
        out.add(_mergeReactionLine(line));
      } else {
        out.add(line);
      }
    }
    return out.join('\n');
  }

  /// A line is a "fragmented reaction" if it has a math-wrapped arrow AND
  /// chemical notation AND enough segments that merging improves rendering.
  static bool _isFragmentedReaction(String line) {
    // Must have a reaction arrow inside math delimiters.
    if (!RegExp(r'\$\$\s*\\(?:to|rightarrow)\s*\$\$').hasMatch(line)) {
      return false;
    }
    // Must show chemical notation: state symbols, subscripts, or ion charges.
    if (!RegExp(r'\([slg]\)|\(aq\)|_\{|\^\{[0-9]*[+-]').hasMatch(line)) {
      return false;
    }
    // Must have ≥ 4 non-empty segments to benefit from merging.
    int count = 0;
    int last = 0;
    for (final m in _mathPattern.allMatches(line)) {
      if (m.start > last && line.substring(last, m.start).trim().isNotEmpty) {
        count++;
      }
      count++;
      last = m.end;
    }
    if (last < line.length && line.substring(last).trim().isNotEmpty) count++;
    return count >= 4;
  }

  /// Merge all segments on a reaction line into a single `$$...$$` block.
  /// Plain text → `\text{...}`, math → unwrapped raw TeX.
  static String _mergeReactionLine(String line) {
    final buf = StringBuffer();
    int last = 0;
    for (final m in _mathPattern.allMatches(line)) {
      if (m.start > last) {
        final plain = line.substring(last, m.start);
        if (plain.trim().isNotEmpty) {
          buf.write('\\text{${_texEscape(plain)}}');
        }
      }
      // Unwrap: group(1) is display $$..$$, group(2) is inline $..$
      final tex = (m.group(1) ?? m.group(2) ?? '').trim();
      if (tex.isNotEmpty) buf.write(' $tex ');
      last = m.end;
    }
    if (last < line.length) {
      final tail = line.substring(last);
      if (tail.trim().isNotEmpty) {
        buf.write('\\text{${_texEscape(tail)}}');
      }
    }
    return '\$\$$buf\$\$';
  }

  /// Escape characters with special meaning inside LaTeX `\text{...}`.
  static String _texEscape(String s) {
    return s.replaceAll('{', r'\{').replaceAll('}', r'\}');
  }

  // ---------------------------------------------------------------------------
  // LaTeX sanitizer
  // ---------------------------------------------------------------------------

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
    // {a \over b} -> \frac{a}{b}. The negative lookahead is critical: without
    // it, the bare `\over` primitive also matched the `\over` *inside* commands
    // like \overrightarrow / \overline / \overbrace, turning `{\overrightarrow R }`
    // into `\frac{}{rightarrow R }` — i.e. a vector rendered as a fraction bar
    // over the literal text "rightarrowR". `\over` must be a standalone token.
    final over = RegExp(r'\{([^{}]*)\\over(?![a-zA-Z])([^{}]*)\}');
    for (var i = 0; i < 4 && over.hasMatch(s); i++) {
      s = s.replaceAllMapped(over, (m) => '\\frac{${m[1]}}{${m[2]}}');
    }
    // Legacy/plain-TeX constructs flutter_math rejects outright (verified to
    // recover 177 scraped questions/solutions with zero regressions):
    //  - \begin{gathered} isn't a known env; \begin{aligned} renders the same
    //    line-stacked layout (gathered content has no & alignment markers).
    s = s
        .replaceAll(r'\begin{gathered}', r'\begin{aligned}')
        .replaceAll(r'\end{gathered}', r'\end{aligned}');
    //  - \limits/\nolimits are positioning hints flutter_math can't take here
    //    (and the data often misplaces them, e.g. \int_\limits0).
    s = s.replaceAll(RegExp(r'\\(no)?limits(?![a-zA-Z])'), '');
    //  - \tag{..} (equation numbering) is unsupported and purely decorative.
    s = s.replaceAll(RegExp(r'\\tag\s*\{[^{}]*\}'), '');
    //  - symbol aliases flutter_math lacks.
    s = s.replaceAll(RegExp(r'\\AA(?![a-zA-Z])'), 'Å');
    s = s.replaceAll(RegExp(r'\\cdotp(?![a-zA-Z])'), r'\cdot');
    //  - plain-TeX \matrix{..} → the \begin{matrix}..\end{matrix} form.
    s = _convertMatrix(s);
    return s;
  }

  /// Test-only access to the sanitizer (it's the part most prone to regressions).
  @visibleForTesting
  static String sanitizeForTest(String t) => _sanitize(t);

  /// Plain-TeX `\matrix{..}` / `\pmatrix` / `\bmatrix` → the `\begin{env}..\end{env}`
  /// form flutter_math understands. Brace-depth matched because a regex can't
  /// balance the nested `{}` inside matrix cells.
  static String _convertMatrix(String s) {
    for (final name in const ['pmatrix', 'bmatrix', 'matrix']) {
      final open = RegExp('\\\\$name\\s*\\{');
      for (var guard = 0; guard < 50; guard++) {
        final m = open.firstMatch(s);
        if (m == null) break;
        var depth = 1, i = m.end;
        while (i < s.length && depth > 0) {
          if (s[i] == '{') {
            depth++;
          } else if (s[i] == '}') {
            depth--;
          }
          i++;
        }
        final inner = s.substring(m.end, i - 1);
        s = '${s.substring(0, m.start)}\\begin{$name}$inner\\end{$name}'
            '${s.substring(i)}';
      }
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

  // ---------------------------------------------------------------------------
  // Match-list table detection
  // ---------------------------------------------------------------------------

  /// Pattern: lines containing ` | ` that represent match-list table rows.
  static final _pipeRow = RegExp(r'\s+\|\s+');

  static bool _isTableRow(String line) {
    final trimmed = line.trim();
    if (!_pipeRow.hasMatch(trimmed)) return false;
    
    // Fast path: standard match-list labels
    if (RegExp(r'^\([a-eA-E]\)\s|^List|^Column', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }
    
    // Check if it's a data row (e.g. "0 | 0 | 0" or "22.2 cm | 32.2 cm")
    // A row is valid if ALL of its pipe-separated parts are short (< 50 chars)
    final parts = trimmed.split(_pipeRow);
    if (parts.length >= 2) {
      if (parts.every((p) => p.trim().length <= 50)) {
        return true;
      }
    }
    
    return false;
  }

  /// Render a single cell's content (may contain LaTeX math).
  Widget _buildCell(String cellText, TextStyle baseStyle) {
    final trimmed = cellText.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    return _buildInlineContent(trimmed, baseStyle);
  }

  /// Build the match-list as a styled table widget.
  Widget _buildMatchTable(
      List<String> tableLines, TextStyle baseStyle, BuildContext context) {
    const headerBg = Color(0xFF1E293B);
    const rowBg = Color(0xFF0F172A);
    const borderColor = Color(0xFF334155);
    final labelStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: const Color(0xFF94A3B8),
      fontSize: 12,
    );

    final rows = <TableRow>[];
    for (var i = 0; i < tableLines.length; i++) {
      final parts = tableLines[i].split(_pipeRow);
      if (parts.length < 2) continue;

      final isHeader = tableLines[i].trim().startsWith(RegExp(r'List|Column', caseSensitive: false));
      final bg = isHeader ? headerBg : rowBg;
      final cellStyle = isHeader ? labelStyle : baseStyle;

      rows.add(TableRow(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 0.5),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: _buildCell(parts[0], cellStyle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: _buildCell(parts[1], cellStyle),
          ),
        ],
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Table(
        border: TableBorder.all(color: borderColor, width: 0.5),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle =
        style ?? GoogleFonts.inter(color: textColor, fontSize: 15, height: 1.6);

    // Pre-process: merge fragmented chemistry reactions into single math blocks
    // and collapse excessive newlines.
    final processed = mergeChemReactions(text);

    // Check if this text contains a match-list table (lines with | separator).
    final lines = processed.split('\n');
    final hasTable = lines.any(_isTableRow);

    Widget content;
    if (hasTable) {
      // Split into segments: normal text and table rows.
      final segments = <Widget>[];
      final normalBuffer = <String>[];
      final tableBuffer = <String>[];

      void flushNormal() {
        if (normalBuffer.isEmpty) return;
        final text = normalBuffer.join('\n').trim();
        if (text.isNotEmpty) {
          segments.add(_buildInlineContent(text, baseStyle));
        }
        normalBuffer.clear();
      }

      void flushTable() {
        if (tableBuffer.isEmpty) return;
        segments.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _buildMatchTable(tableBuffer, baseStyle, context),
        ));
        tableBuffer.clear();
      }

      for (final line in lines) {
        if (_isTableRow(line)) {
          flushNormal();
          tableBuffer.add(line);
        } else {
          flushTable();
          normalBuffer.add(line);
        }
      }
      flushNormal();
      flushTable();

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: segments,
      );
    } else {
      content = _buildInlineContent(processed, baseStyle);
    }

    // Double-tap opens a fullscreen, pinch-to-zoom view of the content.
    if (enableFullscreen) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: () => _showFullscreen(context, processed, baseStyle),
        child: content,
      );
    }

    return content;
  }

  /// True when a math segment is a standalone equation that deserves its own
  /// line rather than flowing inside a sentence.
  ///
  /// The banks use `$$..$$` and `$..$` interchangeably for *inline* symbols
  /// (`3 k$$\Omega$$`, `2.56 $$\mu$$F`, `45$$^\circ$$`), so the delimiter itself
  /// says nothing about display-vs-inline — we classify on the TeX content.
  @visibleForTesting
  static bool isBlockMath(String tex) {
    if (tex.contains(r'\begin{')) return true; // aligned / matrix / cases / array
    if (tex.contains(r'\\')) return true; // explicit row breaks
    return tex.length > 100; // long derivation step, not a sentence fragment
  }

  /// Build a run of prose + math. Inline math is emitted as a [WidgetSpan] so it
  /// flows in the paragraph; standalone equations break out as block widgets.
  ///
  /// This must NOT be a `Wrap` of `Text`/math widgets: `Wrap` children are
  /// atomic boxes, so a multi-line `Text` fills its whole run and forces the
  /// next math child onto a new line — putting every `Ω`, `μ`, `λ` on a line of
  /// its own and shattering ~78% of the JEE bank mid-sentence.
  Widget _buildInlineContent(String processed, TextStyle baseStyle) {
    final blocks = <Widget>[];
    final spans = <InlineSpan>[];

    void flushSpans() {
      if (spans.isEmpty) return;
      blocks.add(Text.rich(
        TextSpan(children: List<InlineSpan>.of(spans)),
        style: baseStyle,
      ));
      spans.clear();
    }

    void addPlain(String s) {
      if (s.isEmpty) return;
      spans.add(TextSpan(text: s, style: baseStyle));
    }

    int last = 0;
    for (final m in _mathPattern.allMatches(processed)) {
      final tex = (m.group(1) ?? m.group(2) ?? '').trim();
      var plain = m.start > last ? processed.substring(last, m.start) : '';
      last = m.end;
      if (tex.isEmpty) {
        addPlain(plain);
        continue;
      }

      if (isBlockMath(tex)) {
        // Drop the whitespace that only existed to separate the equation from
        // surrounding prose, then break the paragraph.
        addPlain(plain.replaceFirst(RegExp(r'[ \t]*\n?[ \t]*$'), ''));
        flushSpans();
        blocks.add(_blockMathBox(tex, baseStyle));
      } else {
        addPlain(plain);
        spans.add(_inlineMathSpan(tex, baseStyle));
      }
    }
    if (last < processed.length) addPlain(processed.substring(last));
    flushSpans();

    if (blocks.length == 1) return blocks.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  /// Math that flows inside a sentence, on the surrounding text's baseline.
  InlineSpan _inlineMathSpan(String tex, TextStyle baseStyle) {
    return WidgetSpan(
      // Baseline alignment keeps `Ω`/`X_L`/`10^{-8}` sitting on the text line
      // instead of floating; `middle` would visibly bob for sub/superscripts.
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Math.tex(
        _sanitize(tex),
        textStyle: baseStyle.copyWith(fontFamily: 'SansSerif'),
        mathStyle: MathStyle.text,
        // Never dump raw LaTeX at the student: degrade to readable plain text.
        onErrorFallback: (err) => Text(_plainFallback(tex), style: baseStyle),
      ),
    );
  }

  /// A standalone equation: own line, horizontally scrollable with a fade hint
  /// so a wide derivation step doesn't silently clip at the screen edge.
  Widget _blockMathBox(String tex, TextStyle baseStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: _ScrollFade(
        child: Math.tex(
          _sanitize(tex),
          textStyle: baseStyle.copyWith(fontFamily: 'SansSerif'),
          mathStyle: MathStyle.display,
          onErrorFallback: (err) => Text(_plainFallback(tex), style: baseStyle),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Fullscreen zoom
  // ---------------------------------------------------------------------------

  void _showFullscreen(
      BuildContext context, String processedText, TextStyle baseStyle) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: const Color(0xE6000000), // ~90% black
        pageBuilder: (ctx, _, __) => _TexFullscreenView(
          text: processedText,
          baseStyle: baseStyle,
        ),
        transitionsBuilder: (ctx, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

/// Horizontally scrollable box that fades its right edge while more content
/// remains off-screen, so a wide equation reads as scrollable instead of
/// looking truncated.
class _ScrollFade extends StatefulWidget {
  final Widget child;
  const _ScrollFade({required this.child});

  @override
  State<_ScrollFade> createState() => _ScrollFadeState();
}

class _ScrollFadeState extends State<_ScrollFade> {
  final _controller = ScrollController();
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final more = p.maxScrollExtent - p.pixels > 1.0;
    if (more != _more && mounted) setState(() => _more = more);
  }

  @override
  void dispose() {
    _controller.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scroller = SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: widget.child,
    );
    if (!_more) return scroller;
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 1 - (24 / rect.width).clamp(0.02, 0.5), 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: scroller,
    );
  }
}

/// Fullscreen overlay with pinch-to-zoom for equation / question text.
class _TexFullscreenView extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;

  const _TexFullscreenView({required this.text, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xF2080E1C), // 95% opacity dark blue
      body: Stack(
        children: [
          // Zoomable content
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                child: TexText(
                  text,
                  style: baseStyle.copyWith(
                    fontSize: 20,
                    color: Colors.white,
                    height: 1.8,
                  ),
                  textColor: Colors.white,
                  enableFullscreen: false, // prevent recursion
                ),
              ),
            ),
          ),

          // Close button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),

          // Hint
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pinch_rounded, color: Colors.white54, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Pinch to zoom',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
