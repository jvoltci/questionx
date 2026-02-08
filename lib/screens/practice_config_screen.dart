import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:questionx/services/pdf_service.dart';
import '../main.dart';
import '../database.dart';
import 'quiz_screen.dart';

final availableYearsProvider = FutureProvider<List<int>>(
  (ref) => ref.read(databaseProvider).getAvailableYears(),
);
final selectedYearsProvider = StateProvider<List<int>>((ref) => []);
final selectedSubjectProvider = StateProvider<String?>((ref) => null);
final selectedTopicsProvider = StateProvider<List<String>>((ref) => []);

final availableTopicsProvider = FutureProvider<List<String>>((ref) async {
  final subject = ref.watch(selectedSubjectProvider);
  return ref.read(databaseProvider).getAvailableTopics(subject);
});

class PracticeConfigScreen extends ConsumerWidget {
  const PracticeConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Stack(
        children: [
          Positioned(top: -100, right: -100, child: _glowCircle(Colors.purple)),
          Positioned(bottom: -100, left: -100, child: _glowCircle(Colors.blue)),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSectionTitle("1. Select Subject"),
                      _buildSubjectSelector(ref),
                      const SizedBox(height: 30),

                      _buildSectionTitle("2. Select Years"),
                      _buildYearSelector(ref),
                      const SizedBox(height: 30),

                      _buildSectionTitle("3. Select Topics (Optional)"),
                      _buildTopicSelector(ref),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildStartButton(context, ref),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _glowCircle(Color color) => Container(
    width: 300,
    height: 300,
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      shape: BoxShape.circle,
    ),
  );

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            "Custom Practice",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(0xFF38BDF8),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSubjectSelector(WidgetRef ref) {
    final selected = ref.watch(selectedSubjectProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ["Physics", "Chemistry", "Biology"].map((sub) {
        final isSelected = selected == sub;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              ref.read(selectedSubjectProvider.notifier).state = isSelected
                  ? null
                  : sub;
              ref.read(selectedTopicsProvider.notifier).state = [];
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF38BDF8)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white10,
                ),
              ),
              child: Center(
                child: Text(
                  sub,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildYearSelector(WidgetRef ref) {
    final yearsAsync = ref.watch(availableYearsProvider);
    final selectedYears = ref.watch(selectedYearsProvider);

    return yearsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => const Text("Error loading years"),
      data: (years) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: years.map((year) {
          final isSelected = selectedYears.contains(year);
          return FilterChip(
            label: Text("$year"),
            selected: isSelected,
            onSelected: (val) {
              final current = [...ref.read(selectedYearsProvider)];
              if (val) {
                current.add(year);
              } else {
                current.remove(year);
              }
              ref.read(selectedYearsProvider.notifier).state = current;
            },
            backgroundColor: Colors.white.withOpacity(0.05),
            selectedColor: const Color(0xFF8B5CF6),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide.none,
            ),
            checkmarkColor: Colors.white,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopicSelector(WidgetRef ref) {
    final topicsAsync = ref.watch(availableTopicsProvider);
    final selectedTopics = ref.watch(selectedTopicsProvider);

    return topicsAsync.when(
      loading: () => const SizedBox(),
      error: (e, _) => const SizedBox(),
      data: (topics) {
        if (topics.isEmpty)
          return const Text(
            "Select a subject first.",
            style: TextStyle(color: Colors.grey),
          );
        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topics.map((topic) {
                final isSelected = selectedTopics.contains(topic);
                return FilterChip(
                  label: Text(topic, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (val) {
                    final current = [...ref.read(selectedTopicsProvider)];
                    if (val) {
                      current.add(topic);
                    } else {
                      current.remove(topic);
                    }
                    ref.read(selectedTopicsProvider.notifier).state = current;
                  },
                  backgroundColor: Colors.white.withOpacity(0.05),
                  selectedColor: const Color(0xFF38BDF8).withOpacity(0.3),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : Colors.white60,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF38BDF8)
                          : Colors.white10,
                    ),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStartButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  final years = ref.read(selectedYearsProvider);
                  final subject = ref.read(selectedSubjectProvider);
                  final topics = ref.read(selectedTopicsProvider);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Generating PDF... Please wait."),
                    ),
                  );

                  final questions = await ref
                      .read(databaseProvider)
                      .getCustomQuestions(
                        years: years,
                        subjects: subject != null ? [subject] : null,
                        topics: topics,
                        limit: 100,
                      );

                  if (questions.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No questions to export!")),
                    );
                    return;
                  }

                  await PdfService.generateExamPdf(
                    questions: questions,
                    title: "QuestionX Custom Test",
                    subject: subject ?? "Mixed Subjects",
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.white70),
                    SizedBox(height: 4),
                    Text("PDF", style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 3,
            child: SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  final years = ref.read(selectedYearsProvider);
                  final subject = ref.read(selectedSubjectProvider);
                  final topics = ref.read(selectedTopicsProvider);

                  final questions = await ref
                      .read(databaseProvider)
                      .getCustomQuestions(
                        years: years,
                        subjects: subject != null ? [subject] : null,
                        topics: topics,
                        limit: 500,
                      );

                  if (questions.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No questions found!")),
                    );
                    return;
                  }

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(questions: questions),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0B1120),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFF38BDF8).withOpacity(0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "START PRACTICE",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.rocket_launch),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
