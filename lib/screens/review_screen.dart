import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../database.dart';
import '../widgets/tex_view.dart';
import '../widgets/question_diagram.dart';
import '../services/diagram_storage.dart';
import '../utils/answer_grading.dart';

final sessionDetailsProvider =
    FutureProvider.family<List<QuestionWithAnswer>, int>((
      ref,
      sessionId,
    ) async {
      return ref.read(databaseProvider).getSessionDetails(sessionId);
    });

class ReviewScreen extends ConsumerWidget {
  final int sessionId;
  const ReviewScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(sessionDetailsProvider(sessionId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Solution Review"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (details) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: details.length,
            itemBuilder: (context, index) {
              final item = details[index];
              return _ReviewCard(index: index + 1, qa: item);
            },
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final int index;
  final QuestionWithAnswer qa;

  const _ReviewCard({required this.index, required this.qa});

  @override
  Widget build(BuildContext context) {
    final q = qa.question;
    final ans = qa.answer;

    bool isSkipped = ans.selectedOption == null;
    bool isCorrect = ans.isCorrect;

    final int timeSpent = ans.timeSpent;

    Color statusColor = isSkipped
        ? Colors.grey
        : (isCorrect ? Colors.green : Colors.red);
    String statusText = isSkipped
        ? "Skipped"
        : (isCorrect ? "Correct" : "Wrong");

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 5px colored stripe on the leading edge so users can scan correct/
          // wrong/skipped at a glance.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 5,
            child: Container(color: statusColor),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: _cardBody(context, q, ans, isSkipped, isCorrect, timeSpent,
                statusColor, statusText),
          ),
        ],
      ),
    );
  }

  Widget _cardBody(
    BuildContext context,
    Question q,
    SessionAnswer ans,
    bool isSkipped,
    bool isCorrect,
    int timeSpent,
    Color statusColor,
    String statusText,
  ) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Q$index",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    "${timeSpent}s",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          TexText(
            q.questionLatex,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 10),

          if (q.questionSvg != null && q.questionSvg!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Material(
                color: DiagramStorage.isFilenameReference(q.questionSvg)
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.05),
                child: InkWell(
                  onTap: () =>
                      QuestionDiagram.openFullscreen(context, q.questionSvg!),
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    child: QuestionDiagram(
                      value: q.questionSvg!,
                      color: Colors.white,
                      cacheWidth: 600,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 15),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _row(
                  "Your Answer:",
                  ans.selectedOption ?? "-",
                  isCorrect
                      ? Colors.green
                      : (isSkipped ? Colors.grey : Colors.red),
                ),
                const SizedBox(height: 8),
                _row("Correct Answer:", _correctAnswerText(q), Colors.green),
              ],
            ),
          ),

          const SizedBox(height: 15),
          const Text(
            "Solution:",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          TexText(
            q.solution ?? "No explanation.",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ]);
  }

  String _correctAnswerText(Question q) {
    List<String> opts = const [];
    try {
      opts = List<String>.from(jsonDecode(q.optionsJson));
    } catch (_) {}
    final type = AnswerGrading.typeOf(options: opts, answerKey: q.answerKey);
    final t = AnswerGrading.correctAnswerText(type: type, answerKey: q.answerKey);
    return t.isEmpty ? "-" : t;
  }

  Widget _row(String label, String value, Color valColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(color: valColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
