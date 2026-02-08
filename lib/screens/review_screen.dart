import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../database.dart';
import '../widgets/tex_view.dart';

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
    Color statusColor = isSkipped
        ? Colors.grey
        : (isCorrect ? Colors.green : Colors.red);
    String statusText = isSkipped
        ? "Skipped"
        : (isCorrect ? "Correct" : "Wrong");

    List<dynamic> options = [];
    try {
      options = jsonDecode(q.optionsJson);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Column(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
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
          const SizedBox(height: 10),

          TexText(
            q.questionLatex,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 10),

          if (q.questionSvg != null)
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              color: Colors.white.withOpacity(0.05),
              child: SvgPicture.string(
                q.questionSvg!,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
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
                _row("Correct Answer:", q.answerKey ?? "-", Colors.green),
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
        ],
      ),
    );
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
