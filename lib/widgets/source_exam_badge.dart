import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../database.dart';

/// Marks which exam a question came from, for practice sets that mix them.
///
/// A NEET student who turns on cross-exam practice must always be able to tell
/// what they are attempting — an unlabelled JEE question looks like a NEET
/// question they should have been able to answer.
///
/// Shown only when the set actually spans more than one exam ([isMixedSet]), so
/// a plain NEET or plain JEE session carries no extra chrome.
class SourceExamBadge extends StatelessWidget {
  final String examName;
  const SourceExamBadge(this.examName, {super.key});

  /// True when [questions] come from more than one exam.
  static bool isMixedSet(Iterable<Question> questions) =>
      questions.map((q) => _family(q.examName)).toSet().length > 1;

  static String _family(String exam) {
    final e = exam.toUpperCase();
    if (e.startsWith('JEE ADV') || e.startsWith('JEE_ADV')) return 'JEE ADV';
    if (e.startsWith('JEE')) return 'JEE MAIN';
    return 'NEET';
  }

  @override
  Widget build(BuildContext context) {
    final label = _family(examName);
    // JEE Advanced is the genuinely harder pool (24% of its questions are rated
    // Hard, against 3-4% for NEET and JEE Main), so it gets its own colour
    // rather than being lumped in with Main.
    final (bg, fg) = switch (label) {
      'JEE ADV' => (const Color(0xFFF59E0B), const Color(0xFFF59E0B)),
      'JEE MAIN' => (const Color(0xFF38BDF8), const Color(0xFF38BDF8)),
      _ => (const Color(0xFF22C55E), const Color(0xFF22C55E)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
  }
}
