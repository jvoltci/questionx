/// Render-time repair of malformed LaTeX in the question banks.
///
/// This runs inside the widget, on every string it renders, so it is
/// set-and-forget: a bank added or re-scraped later is fixed automatically with
/// no migration script to remember and no second copy of the data to keep in
/// sync. Everything here is a pure function of the input string, guarded so a
/// repair can only ever improve a string or leave it byte-identical.
///
/// Two upstream defects are handled.
///
/// **1. Stray `$` delimiters.** The examside scrape (and the
/// `scripts/jee/normalize_latex.py` pass over it) wraps bare LaTeX fragments in
/// `$...$` without looking at what is next to them, so a fragment abutting an
/// existing block produces a run of delimiters:
///
/// ```
/// "$$\omega$$" + "$_{r}$"  ->  "$$\omega$$$_{r}$"
/// ```
///
/// Where that makes the effective count odd, a `$$` opens a span that runs to
/// the *next* `$$` and swallows the prose in between. In the worst observed case
/// the question lost the clause "and an unknown capacitor", which made it
/// unanswerable. [repairDelimiters] reads a 3+ run back as close-then-open,
/// demotes spans that are really prose, and fuses the fragments that belong
/// together.
///
/// **2. Prose typeset as math.** Some stems and fraction labels are stored
/// entirely inside math delimiters with `\,` thin spaces standing in for real
/// spaces (`{{mean\,\,of\,X} \over {s\tan dard\,\,deviation\,\,of\,X}}`). KaTeX
/// renders that as italic run-together variables. [textifyProse] wraps those
/// runs in `\text{}`.
///
/// What is deliberately NOT repaired: a separate upstream scrape bug dropped the
/// text after a bare `<`, cutting statements mid-comparison. That content is
/// absent from the source, so no render-time pass can recover it. Those spans
/// are detected ([hasSwallowedSentence]) and left alone rather than dressed up to
/// look intentional — `scripts/jee/repair_dollars.py --report-truncated` lists
/// them for manual repair against the official papers.
library;

import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Shared detectors
// ---------------------------------------------------------------------------

/// The renderer's own math scanner. Anything this matches is what the student
/// actually sees typeset as math, so every judgement here is made against it.
final RegExp appMathPattern = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);

final _dollarRun = RegExp(r'\$+');
final _textish = RegExp(
    r'\\(?:text|mathrm|mathbf|mathit|mathsf|rm|bf|it|hbox|operatorname)\s*\{[^{}]*\}');
final _env = RegExp(r'\\(?:begin|end)\{[a-zA-Z*]+\}');
final _cmdToken = RegExp(r'\\[a-zA-Z]+');
final _lowerWord = RegExp(r'\b[a-z]{4,}\b');

String _spanTex(RegExpMatch m) => m.group(1) ?? m.group(2) ?? '';

/// Replace each match with the same number of NULs, so offsets stay valid and
/// the masked text can never be read as prose.
String _mask(String s, RegExp re) =>
    s.replaceAllMapped(re, (m) => '\u0000' * m.group(0)!.length);

/// Lowercase words in math mode that no `\text{}`-style wrapper accounts for.
List<String> _proseWords(String tex) {
  var s = tex.replaceAll(_textish, ' ').replaceAll(_env, ' ');
  s = s.replaceAll(_cmdToken, ' ').replaceAll(RegExp(r'[{}^_&\\]'), ' ');
  return _lowerWord.allMatches(s).map((m) => m.group(0)!).toList();
}

/// True when a span the widget treats as math is really prose.
@visibleForTesting
bool isSwallowedProse(String tex) => _proseWords(tex).length >= 3;

/// Words separated by REAL spaces.
///
/// This is the signal that tells a swallowed *sentence* apart from a label that
/// was deliberately typeset in math: an author writing a fraction label uses
/// `\,` thin spaces (`{mean\,\,of\,X}`), whereas prose eaten by a runaway
/// delimiter keeps the ordinary spaces it had as prose
/// (`\mathrm{Na}Statement II : the correct order`).
final _realSpaceProse = RegExp(r'\b[a-z]{3,}\b(?:[ \t]+\b[a-z]{2,}\b){2,}');

/// Mask text-style wrappers and then command names.
///
/// Order matters: masking commands first replaces the `\text` in
/// `\text{Volume of sphere}` with NULs, after which `_textish` can no longer
/// match and the words inside it look like unwrapped prose — which produced
/// `\text{\text{Volume of sphere}}` on every re-render.
String _maskNonProse(String tex) => _mask(_mask(tex, _textish), _cmdToken);

@visibleForTesting
bool isSentenceText(String tex) =>
    _realSpaceProse.hasMatch(_maskNonProse(tex));

/// True when some span holds a swallowed sentence — an upstream `<` truncation.
/// Such a string is left untouched by [textifyProse].
bool hasSwallowedSentence(String s) {
  for (final m in appMathPattern.allMatches(s)) {
    final tex = _spanTex(m);
    if (isSwallowedProse(tex) && isSentenceText(tex)) return true;
  }
  return false;
}

/// How many spans the widget would render as math but which are really prose.
/// This is the metric the delimiter repair exists to reduce.
int _swallowedCount(String s) => appMathPattern
    .allMatches(s)
    .where((m) => isSwallowedProse(_spanTex(m)))
    .length;

/// Word tokens with delimiters stripped.
///
/// Guards both directions at once: a dropped clause changes the list, and so
/// does fusing two words by deleting the `$` that separated them
/// (`\Omega$$and` -> a single "Omegaand"). Merging two adjacent math spans only
/// removes whitespace between tokens, so it correctly compares equal.
List<String> _wordTokens(String s) => RegExp(r'[A-Za-z0-9]+')
    .allMatches(s.replaceAll(r'$', ''))
    .map((m) => m.group(0)!)
    .toList();

// ---------------------------------------------------------------------------
// 1. Delimiter repair
// ---------------------------------------------------------------------------

class _Tok {
  final bool math;
  final String text;
  const _Tok(this.math, this.text);
}

/// Split into text/math tokens, reading a run of N `$` as "close the open span,
/// then open a new one with whatever remains".
///
/// That is exactly how the damage was introduced, so reading it back the same
/// way recovers the spans that were intended.
List<_Tok> _tokenize(String s) {
  final out = <_Tok>[];
  var pos = 0;
  int? openerLen; // null while outside a span
  var start = 0;

  void push(bool math, String content) {
    if (content.isNotEmpty) out.add(_Tok(math, content));
  }

  for (final m in _dollarRun.allMatches(s)) {
    final run = m.group(0)!.length;
    if (openerLen == null) {
      push(false, s.substring(pos, m.start));
      final take = run >= 2 ? 2 : 1;
      openerLen = take;
      // Any extra `$` in a 3+ run here is stray; skip past the whole run.
      start = m.start + (run > take ? run : take);
      pos = start;
    } else {
      // Content is kept RAW: a span that turns out to be swallowed prose gets
      // demoted to text, and trimming here would eat the space that separated
      // it from the preceding equation.
      push(true, s.substring(start, m.start));
      final leftover = run - openerLen;
      if (leftover >= 1) {
        openerLen = leftover >= 2 ? 2 : 1;
        start = m.start + run;
        pos = start;
      } else {
        openerLen = null;
        pos = m.start + run;
      }
    }
  }
  // An unterminated span means the delimiter was noise; keep the content.
  push(false, s.substring(openerLen != null ? start : pos));
  return out;
}

/// Prefix of a demoted span that is still genuinely math — the tail of the real
/// expression, e.g. `\mathrm{Na}` in `\mathrm{Na}Statement II : ...`.
final _mathPrefix = RegExp(
    r'^((?:\\[a-zA-Z]+(?:\{[^{}]*\})*|[A-Za-z0-9^_{}\\+\-]){1,24}?)'
    r'(?=[A-Z][a-z]|\s[a-z]{4})');

List<_Tok> _demote(List<_Tok> toks) {
  final out = <_Tok>[];
  for (final t in toks) {
    if (!t.math || !isSwallowedProse(t.text)) {
      out.add(t);
      continue;
    }
    final m = _mathPrefix.firstMatch(t.text);
    if (m != null && m.group(1)!.contains('\\')) {
      out.add(_Tok(true, m.group(1)!));
      out.add(_Tok(false, t.text.substring(m.end)));
    } else {
      out.add(_Tok(false, t.text));
    }
  }
  return out;
}

/// Fuse math spans that the wrapper split apart (nothing between them).
List<_Tok> _merge(List<_Tok> toks) {
  final out = <_Tok>[];
  for (final t in toks) {
    if (t.math && out.isNotEmpty && out.last.math) {
      out[out.length - 1] = _Tok(true, out.last.text + t.text);
    } else {
      out.add(t);
    }
  }
  return out;
}

String _emit(List<_Tok> toks) {
  final b = StringBuffer();
  for (final t in toks) {
    if (!t.math) {
      b.write(t.text);
    } else if (t.text.trim().isNotEmpty) {
      b.write('\$\$${t.text.trim()}\$\$');
    }
  }
  return b.toString();
}

/// Only strings that actually show damage are rewritten; everything else is
/// returned byte-identical.
bool _isDamaged(String s) {
  if (RegExp(r'\${3,}').hasMatch(s)) return true;
  var total = 0;
  for (final m in _dollarRun.allMatches(s)) {
    total += m.group(0)!.length;
  }
  // An even count can still be damaged — `$${\rm I}$${$\rm$ I}.$$` pairs off
  // into a span that eats the following sentence.
  return total.isOdd || _swallowedCount(s) > 0;
}

/// A line break the scrape wrapped into math: `Match List I with List II$\nList$
/// I: A. ...`, where `\n` is a literal backslash-n, not a newline.
///
/// `_sanitize` turns literal `\n` into a space, so the marker rendered as an
/// italic maths word mid-sentence and the line break was lost entirely — every
/// match-list and multi-statement question collapsed into one run-on paragraph
/// (179 questions, 530 spans; NEET_2024_Zoo_184 was reported as "unclear"
/// largely because of this).
///
/// `\n` is not a LaTeX command, so a span beginning with one is always this
/// artifact and never real maths.
final _wrappedNewline = RegExp(r'\$((?:\\n)+)([A-Za-z][A-Za-z \-]{0,20})\$');

String _unwrapNewlines(String s) => s.replaceAllMapped(
      _wrappedNewline,
      (m) => '\n' * (m.group(1)!.length ~/ 2) + m.group(2)!,
    );

/// A bare `$` inside a math span.
///
/// This can never be valid: `$` is not a character math mode accepts (it would
/// have to be `\$`). It appears because the wrapper put `$...$` around a fragment
/// that was already inside math — `{{s - x} $\over$ 4}`, `{{8$\pi$ } $\over$ 3}`.
/// Dropping the stray delimiters restores valid LaTeX.
final _bareInnerDollar = RegExp(r'(?<!\\)\$');

String _stripInnerDollars(String s) {
  if (!s.contains(r'$')) return s;
  return s.replaceAllMapped(appMathPattern, (match) {
    final m = match as RegExpMatch;
    final tex = _spanTex(m);
    if (!tex.contains(r'$')) return m.group(0)!;
    // If the span is really swallowed prose, the delimiters are mispaired and
    // stripping would cement the swallow. Leave it for the tokenizer.
    if (isSwallowedProse(tex)) return m.group(0)!;
    // Keep the original delimiter width. Re-emitting a `$..$` span as `$$..$$`
    // would butt new `$$` against its neighbours and re-pair the whole string.
    final d = m.group(1) != null ? r'$$' : r'$';
    return '$d${tex.replaceAll(_bareInnerDollar, '')}$d';
  });
}

String _repairParagraph(String s) {
  if (!s.contains(r'$') || !_isDamaged(s)) return s;
  final fixed = _emit(_merge(_demote(_tokenize(s))));
  // Never drop visible text or fuse two words together.
  return listEquals(_wordTokens(fixed), _wordTokens(s)) ? fixed : s;
}

/// Repair stray `$` delimiters so no span can swallow prose.
///
/// Each paragraph is repaired independently: no math span in these banks
/// legitimately crosses a blank line, and an unpaired delimiter would otherwise
/// let [_merge] fuse two separate display equations and eat the prose line
/// between them.
String repairDelimiters(String s) {
  if (s.isEmpty || !s.contains(r'$')) return s;
  final fixed = s.split('\n\n').map(_repairParagraph).join('\n\n');
  // Final guard on the WHOLE string: the widget's scanner is dotAll and pairs
  // delimiters across blank lines, so a per-paragraph rewrite that looks neutral
  // in isolation can still leave the string worse once rejoined. Tokenizing
  // damaged input is ambiguous, so only accept a strict improvement.
  return _swallowedCount(fixed) > _swallowedCount(s) ? s : fixed;
}

// ---------------------------------------------------------------------------
// 2. Prose typeset as math
// ---------------------------------------------------------------------------

/// MathType split a word wherever it happened to contain a function name, so
/// "standard" was stored as `s\tan dard`.
///
/// This MUST be an explicit allowlist, not an inferred pattern: `x\cos x`,
/// `\sin xdx`, `k\sin kz` and `\cos ec` all match the same shape and are real
/// math, so a general rule silently rewrites `x\cos x` to the variable `xcosx`
/// and destroys the cosine. Below is the complete set found in both banks — every
/// `\<func> <word>` whose merge forms an English word.
const Map<String, String> _glueFixes = {
  r'Dis\tan ce': 'Distance',
  r'dis\tan ce': 'distance',
  r'Resis\tan ce': 'Resistance',
  r'resis\tan ce': 'resistance',
  r'Cons\tan t': 'Constant',
  r'cons\tan t': 'constant',
  r'S\tan dard': 'Standard',
  r's\tan dard': 'standard',
  r'\Pr obability': 'Probability',
  r'\Pr imary': 'Primary',
  r'\max well': 'Maxwell',
  r'lu\min ous': 'luminous',
  r'\sup eroxide': 'superoxide',
  r'pas\sin g': 'passing',
  r'Mis\sin g': 'Missing',
  r'mis\sin g': 'missing',
  r'Glu\cos e': 'Glucose',
  r'glu\cos e': 'glucose',
  r'Ch\arg e': 'Charge',
  r'ch\arg e': 'charge',
};

/// Words that are math operators, not prose.
const Set<String> _operators = {
  'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'log', 'exp', 'max', 'min',
  'lim', 'sup', 'inf', 'det', 'mod', 'arg', 'gcd', 'lcm', 'ln',
};

const String _sep = r'(?:\\[,;:!]|\\ |\s)+';
final _proseRun = RegExp(r'[A-Za-z]{2,}(?:' + _sep + r'[A-Za-z]{2,})+');
final _sepRe = RegExp(_sep);

/// A bare lowercase word standing alone between operators, e.g. each node of
/// `plant \rightarrow mice \rightarrow snake \rightarrow peacock`. Individually
/// these are not runs, but a span full of them is still prose.
final _loneWord = RegExp(r'(?<![A-Za-z\\}])[a-z]{4,}(?![A-Za-z}])');

String _unglue(String s) {
  var out = s;
  _glueFixes.forEach((broken, fixed) {
    if (out.contains(broken)) out = out.replaceAll(broken, fixed);
  });
  return out;
}

/// Two or more English-looking words, at least one of them substantial.
///
/// The length-4 floor is what keeps `mean of X` (prose) apart from `MgCl` or
/// `rms` (math): a bare 2-3 letter cluster never qualifies on its own, so a
/// fraction's numerator and denominator are judged the same way and don't end up
/// one wrapped and the other italic.
bool _isProse(String run) {
  final englishy = RegExp(r'[A-Za-z]{2,}')
      .allMatches(run)
      .map((m) => m.group(0)!)
      .where((w) => !_operators.contains(w.toLowerCase()))
      .where((w) => w.substring(1) == w.substring(1).toLowerCase())
      .toList();
  return englishy.length >= 2 && englishy.any((w) => w.length >= 4);
}

/// Wrap multi-word prose runs. Offsets come from a freshly masked probe of
/// [tex], so this is safe to apply repeatedly.
String _wrapRuns(String tex) {
  final probe = _maskNonProse(tex);
  final b = StringBuffer();
  var pos = 0;
  for (final m in _proseRun.allMatches(probe)) {
    final run = m.group(0)!;
    if (!_isProse(run)) continue;
    final pretty = run.split(_sepRe).where((w) => w.isNotEmpty).join(' ');
    b.write(tex.substring(pos, m.start));
    b.write('\\text{$pretty}');
    pos = m.end;
  }
  b.write(tex.substring(pos));
  return b.toString();
}

/// Wrap bare words left standing alone between operators.
String _wrapLoneWords(String tex) {
  final probe = _maskNonProse(tex);
  final words = _loneWord
      .allMatches(probe)
      .where((m) => !_operators.contains(m.group(0)!))
      .toList();
  if (words.length < 2) return tex;
  final b = StringBuffer();
  var pos = 0;
  for (final m in words) {
    b.write(tex.substring(pos, m.start));
    b.write('\\text{${m.group(0)}}');
    pos = m.end;
  }
  b.write(tex.substring(pos));
  return b.toString();
}

@visibleForTesting
String textifySpan(String rawTex) {
  // Run to a fixed point. Wrapping a run shifts every later offset and re-masks
  // what is now inside `\text{}`, which can expose a neighbouring fragment
  // (`{\text{Weight of solute}\,(compound\,A)}`) that the first sweep could not
  // see. Converging here is what makes the whole pass idempotent.
  var tex = _unglue(rawTex);
  for (var i = 0; i < 4; i++) {
    final next = _wrapLoneWords(_wrapRuns(tex));
    if (next == tex) break;
    tex = next;
  }
  return tex;
}

/// Wrap prose that was typeset as math in `\text{}` so it renders upright and
/// spaced instead of as italic run-together variables.
String textifyProse(String s) {
  if (s.isEmpty || !s.contains(r'$')) return s;
  // A string with an upstream `<` truncation is left completely alone: wrapping
  // its runaway span would make missing content look intentional.
  if (hasSwallowedSentence(s)) return s;

  final out = s.replaceAllMapped(appMathPattern, (m) {
    final tex = _spanTex(m as RegExpMatch);
    final fixed = textifySpan(tex);
    return fixed == tex ? m.group(0)! : '\$\$$fixed\$\$';
  });
  // Re-emitting `$..$` as `$$..$$` must not disturb the delimiter balance of a
  // string whose spans the widget pairs differently than we just did.
  final parityChanged =
      out.split(r'$').length.isOdd != s.split(r'$').length.isOdd;
  if (parityChanged || RegExp(r'\${3,}').hasMatch(out)) return s;
  // Wrapping is only ever meant to reduce prose-rendered-as-math; if a span's
  // rewrite made the widget read *more* of the string as math, keep the original.
  if (_swallowedCount(out) > _swallowedCount(s)) return s;
  return out;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

final Map<String, String> _cache = {};

/// Full render-time normalization, memoized because a widget rebuilds far more
/// often than the string changes.
///
/// The two passes are run to a fixed point: [textifyProse] rewrites delimiters
/// when it wraps a span, which can expose damage [repairDelimiters] could not
/// safely act on the first time round. Converging here means the output never
/// depends on how many times a string happens to be normalized.
String normalizeForRender(String raw) {
  final hit = _cache[raw];
  if (hit != null) return hit;
  var s = raw;
  for (var i = 0; i < 4; i++) {
    final next =
        textifyProse(repairDelimiters(_stripInnerDollars(_unwrapNewlines(s))));
    if (next == s) break;
    s = next;
  }
  if (_cache.length > 512) _cache.clear();
  return _cache[raw] = s;
}
