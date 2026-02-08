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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No mistakes pending!",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            itemBuilder: (ctx, index) {
              return Dismissible(
                key: Key(questions[index].id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Colors.green,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.check, color: Colors.white),
                ),
                onDismissed: (_) {
                  ref.read(databaseProvider).removeMistake(questions[index].id);
                },
                child: QuestionCard(question: questions[index]),
              );
            },
          );
        },
      ),
    );
  }
}
