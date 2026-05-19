import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../database.dart';
import 'result_screen.dart';

final historyProvider = FutureProvider<List<PracticeSession>>((ref) async {
  return ref.read(databaseProvider).getAllSessions();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          "History",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 64, color: Colors.white24),
                    const SizedBox(height: 20),
                    Text(
                      "No quizzes yet",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Once you finish a practice session, you'll see "
                      "scores, durations, and a breakdown here.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _HistoryCard(session: session);
            },
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PracticeSession session;
  const _HistoryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    // Locale-aware: yMMMd respects the device's date convention (US 11/20/26
    // vs IN 20-Nov-2026 vs UK 20 Nov 2026), Hm gives 24h time in locales that
    // use it.
    final dateStr =
        "${DateFormat.yMMMd().format(session.startTime)} • "
        "${DateFormat.Hm().format(session.startTime)}";
    final score = (session.correctCount / session.totalQuestions) * 100;
    Color scoreColor = score >= 50 ? Colors.green : Colors.orange;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              sessionId: session.id,
              total: session.totalQuestions,
              correct: session.correctCount,
              wrong: session.wrongCount,
              skipped: session.skippedCount,
              duration: session.durationSeconds,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                "${score.toInt()}%",
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Practice Session",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
