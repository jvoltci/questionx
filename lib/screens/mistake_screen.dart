import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../database.dart';
import '../home_screen.dart';

final mistakeStreamProvider = StreamProvider.autoDispose<List<Question>>((ref) {
  return ref.read(databaseProvider).watchMistakeQuestions();
});

class MistakeScreen extends ConsumerWidget {
  const MistakeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mistakesAsync = ref.watch(mistakeStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          "Mistake Notebook",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: mistakesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text("Error: $e", style: const TextStyle(color: Colors.red)),
        ),
        data: (questions) {
          if (questions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "No mistakes pending",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Wrong answers from your quizzes show up here for "
                      "review. Swipe a card to mark it done.",
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
            itemCount: questions.length,
            itemBuilder: (ctx, index) {
              final q = questions[index];
              return Dismissible(
                key: Key(q.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Colors.green,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.check, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await ref.read(databaseProvider).removeMistake(q.id);
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: const Text("Removed from notebook"),
                        backgroundColor: const Color(0xFF1E293B),
                        duration: const Duration(seconds: 3),
                        action: SnackBarAction(
                          label: "Undo",
                          textColor: const Color(0xFF38BDF8),
                          onPressed: () =>
                              ref.read(databaseProvider).addMistake(q.id),
                        ),
                      ),
                    );
                },
                child: QuestionCard(question: q),
              );
            },
          );
        },
      ),
    );
  }
}
