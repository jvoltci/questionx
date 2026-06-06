import 'dart:math' as math;

/// How a question is answered & graded. Derived from (options, answerKey):
/// - [mcqSingle]  : 4 options, single-letter key ("C")            → tap one
/// - [mcqMulti]   : options present, comma key ("A,C")            → tap many
/// - [numeric]    : no options, numeric/range/OR key ("400","40TO41","2OR8") → type a number
/// - [bonus]      : no options, key is BONUS                      → any answer accepted
enum QType { mcqSingle, mcqMulti, numeric, bonus }

/// Pure, isolated grading logic for QuestionX. No Flutter deps so it's unit-testable.
///
/// Previously the engine graded everything with `userAnswer == answerKey`, which
/// left ~27% of JEE (numeric/integer) unanswerable and marked every multi-correct
/// question wrong (and filed a false Mistake). This classifies the question and
/// grades each type correctly.
class AnswerGrading {
  static QType typeOf({required List<String> options, String? answerKey}) {
    final ak = (answerKey ?? '').trim();
    final hasOptions = options.any((o) => o.trim().isNotEmpty);
    if (!hasOptions) {
      if (RegExp(r'^bonus$', caseSensitive: false).hasMatch(ak)) return QType.bonus;
      return QType.numeric;
    }
    return ak.contains(',') ? QType.mcqMulti : QType.mcqSingle;
  }

  /// userAnswer encoding: single letter "C", sorted letters "A,C", or a typed number.
  static bool isCorrect({
    required QType type,
    required String? userAnswer,
    required String? answerKey,
  }) {
    final ua = (userAnswer ?? '').trim();
    final ak = (answerKey ?? '').trim();
    if (type == QType.bonus) return ua.isNotEmpty; // attempted ⇒ credited
    if (ua.isEmpty || ak.isEmpty) return false;
    switch (type) {
      case QType.mcqSingle:
        return ua.toUpperCase() == ak.toUpperCase();
      case QType.mcqMulti:
        final u = _letters(ua);
        final k = _letters(ak);
        return u.isNotEmpty && u.length == k.length && u.containsAll(k);
      case QType.numeric:
        return _numericMatches(ua, ak);
      case QType.bonus:
        return true;
    }
  }

  static Set<String> _letters(String s) => s
      .toUpperCase()
      .split(RegExp(r'[,\s]+'))
      .where((x) => x.isNotEmpty)
      .toSet();

  /// Matches numeric keys of the forms: "400", "4.5", "-5.2", "40TO41" (range,
  /// inclusive), "3730OR6460"/"2OR8" (alternatives), and combinations. LaTeX/$
  /// noise is stripped. Small tolerance so 3.99 ≈ 4.
  static bool _numericMatches(String ua, String ak) {
    final u = _parseNum(ua);
    if (u == null) return false;
    final key = ak.toUpperCase().replaceAll(RegExp(r'[\$\\\s]'), '');
    for (final alt in key.split('OR')) {
      if (alt.contains('TO')) {
        final parts = alt.split('TO');
        final a = _parseNum(parts.first);
        final b = _parseNum(parts.last);
        if (a != null && b != null) {
          final lo = math.min(a, b) - 1e-6;
          final hi = math.max(a, b) + 1e-6;
          if (u >= lo && u <= hi) return true;
        }
      } else {
        final v = _parseNum(alt);
        if (v != null && (u - v).abs() <= math.max(1e-2, v.abs() * 1e-3)) {
          return true;
        }
      }
    }
    return false;
  }

  static double? _parseNum(String s) {
    final m = RegExp(r'-?\d+(\.\d+)?')
        .firstMatch(s.replaceAll(RegExp(r'[\$\\\s]'), ''));
    return m == null ? null : double.tryParse(m.group(0)!);
  }

  /// Human-readable correct answer for review/detail screens.
  static String correctAnswerText({
    required QType type,
    String? answerKey,
  }) {
    final ak = (answerKey ?? '').trim();
    switch (type) {
      case QType.bonus:
        return 'Bonus — all answers accepted';
      case QType.numeric:
        return ak.replaceAll(RegExp(r'[\$\\]'), '').replaceAll('TO', ' to ').replaceAll('OR', ' or ');
      case QType.mcqSingle:
      case QType.mcqMulti:
        return ak.toUpperCase();
    }
  }
}
