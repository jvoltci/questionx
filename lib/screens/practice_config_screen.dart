import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:questionx/services/pdf_service.dart';
import '../home_screen.dart';
import '../main.dart';
import 'quiz_screen.dart';

final availableYearsProvider = FutureProvider.autoDispose<List<int>>((ref) {
  final exam = ref.watch(selectedExamProvider);
  return ref.read(databaseProvider).getAvailableYears(examName: exam);
});
final selectedYearsProvider =
    StateProvider.autoDispose<List<int>>((ref) => []);
final selectedSubjectProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final selectedTopicsProvider =
    StateProvider.autoDispose<List<String>>((ref) => []);

final availableTopicsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final subject = ref.watch(selectedSubjectProvider);
  final exam = ref.watch(selectedExamProvider);
  return ref
      .read(databaseProvider)
      .getAvailableTopics(subject, examName: exam);
});

/// Live count of questions matching the current filter selection. Drives the
/// match-count chip near the Start Practice button.
final liveMatchCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final exam = ref.watch(selectedExamProvider);
  final years = ref.watch(selectedYearsProvider);
  final subject = ref.watch(selectedSubjectProvider);
  final topics = ref.watch(selectedTopicsProvider);
  return ref.read(databaseProvider).countCustomQuestions(
        examName: exam,
        years: years,
        subjects: subject != null ? [subject] : null,
        topics: topics,
      );
});

List<Map<String, Object>> _subjectsForExam(String? exam) {
  if (exam != null && exam.toUpperCase().contains("JEE")) {
    return const [
      {'name': "Mathematics", 'icon': Icons.calculate_rounded},
      {'name': "Physics", 'icon': Icons.flash_on_rounded},
      {'name': "Chemistry", 'icon': Icons.science_rounded},
    ];
  }
  return const [
    {'name': "Physics", 'icon': Icons.flash_on_rounded},
    {'name': "Chemistry", 'icon': Icons.science_rounded},
    {'name': "Biology", 'icon': Icons.spa_rounded},
  ];
}

class PracticeConfigScreen extends ConsumerWidget {
  const PracticeConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const bgDark = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgDark,
      extendBody: true,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -100,
            child: _glowCircle(const Color(0xFF7C3AED), 0.1),
          ),
          Positioned(
            top: 100,
            left: -150,
            child: _glowCircle(const Color(0xFF0EA5E9), 0.08),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, ref),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 120),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildSectionTitle("1. Select Subject"),
                      _buildSubjectSelector(ref),
                      const SizedBox(height: 32),

                      _buildSectionTitle("2. Select Years"),
                      _buildYearSelector(ref),
                      const SizedBox(height: 32),

                      _buildSectionTitle("3. Select Topics (Optional)"),
                      _buildTopicSelector(ref),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(Color color, double opacity) => Container(
    width: 400,
    height: 400,
    decoration: BoxDecoration(
      color: color.withValues(alpha: opacity),
      shape: BoxShape.circle,
    ),
  );

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Configure",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          TextButton.icon(
            onPressed: () {
              ref.read(selectedSubjectProvider.notifier).state = null;
              ref.read(selectedYearsProvider.notifier).state = [];
              ref.read(selectedTopicsProvider.notifier).state = [];

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Filters reset"),
                  duration: Duration(milliseconds: 500),
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
            label: Text(
              "Reset",
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSubjectSelector(WidgetRef ref) {
    final selected = ref.watch(selectedSubjectProvider);
    final exam = ref.watch(selectedExamProvider);
    final subjects = _subjectsForExam(exam);

    return Row(
      children: subjects.map((subMap) {
        final subName = subMap['name'] as String;
        final icon = subMap['icon'] as IconData;
        final isSelected = selected == subName;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              ref.read(selectedSubjectProvider.notifier).state = isSelected
                  ? null
                  : subName;
              ref.read(selectedTopicsProvider.notifier).state = [];
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF38BDF8)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.black87 : Colors.white70,
                    size: 26,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subName,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.black87 : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
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
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) =>
          const Text("Failed to load", style: TextStyle(color: Colors.red)),
      data: (years) {
        // Sort descending so newest years sit at the top — most aspirants
        // start with recent papers.
        final sorted = [...years]..sort((a, b) => b.compareTo(a));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick-pick presets so users don't have to tap 20+ year chips.
            _buildYearPresets(ref, sorted),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: sorted.map((year) {
                final isSelected = selectedYears.contains(year);
                return _buildMinimalChip(
                  label: "$year",
                  isSelected: isSelected,
                  onTap: () {
                    final current = [...ref.read(selectedYearsProvider)];
                    isSelected ? current.remove(year) : current.add(year);
                    ref.read(selectedYearsProvider.notifier).state = current;
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildYearPresets(WidgetRef ref, List<int> available) {
    if (available.isEmpty) return const SizedBox.shrink();
    final newest = available.first;
    // Effective "now" comes from the dataset itself so the presets stay
    // sensible whether the device clock is 2026 or a few years later.
    final last5 = available.where((y) => y >= newest - 4).toList();
    final last10 = available.where((y) => y >= newest - 9).toList();
    final selected = ref.watch(selectedYearsProvider);
    bool sameSet(List<int> a) =>
        a.length == selected.length && a.toSet().containsAll(selected);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPresetChip(
          label: "All (${available.length})",
          active: selected.isEmpty || sameSet(available),
          onTap: () =>
              ref.read(selectedYearsProvider.notifier).state = const [],
        ),
        _buildPresetChip(
          label: "Last 5",
          active: sameSet(last5),
          onTap: () =>
              ref.read(selectedYearsProvider.notifier).state = last5,
        ),
        _buildPresetChip(
          label: "Last 10",
          active: sameSet(last10),
          onTap: () =>
              ref.read(selectedYearsProvider.notifier).state = last10,
        ),
        _buildPresetChip(
          label: "Clear",
          active: false,
          onTap: () =>
              ref.read(selectedYearsProvider.notifier).state = const [],
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF38BDF8)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? Colors.black87 : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTopicSelector(WidgetRef ref) {
    final topicsAsync = ref.watch(availableTopicsProvider);
    final selectedTopics = ref.watch(selectedTopicsProvider);

    return topicsAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (topics) {
        if (topics.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white30, size: 20),
                SizedBox(width: 10),
                Text(
                  "Select a subject to view topics",
                  style: TextStyle(color: Colors.white30),
                ),
              ],
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topics.map((topic) {
            final isSelected = selectedTopics.contains(topic);
            return _buildMinimalChip(
              label: topic,
              isSelected: isSelected,
              onTap: () {
                final current = [...ref.read(selectedTopicsProvider)];
                isSelected ? current.remove(topic) : current.add(topic);
                ref.read(selectedTopicsProvider.notifier).state = current;
              },
              isSmall: true,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMinimalChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isSmall = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 20,
          vertical: isSmall ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF38BDF8)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
            fontSize: isSmall ? 12 : 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref) {
    final matchCount = ref.watch(liveMatchCountProvider);
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 34),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.filter_alt_outlined,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      matchCount.maybeWhen(
                        data: (n) => "$n question${n == 1 ? '' : 's'} match",
                        orElse: () => "Counting…",
                      ),
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => _handlePdfExport(context, ref),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38BDF8)
                                .withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => _handleStartQuiz(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Start Practice",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePdfExport(BuildContext context, WidgetRef ref) async {
    final years = ref.read(selectedYearsProvider);
    final subject = ref.read(selectedSubjectProvider);
    final topics = ref.read(selectedTopicsProvider);
    final exam = ref.read(selectedExamProvider);

    // Show a blocking modal so the user knows work is in progress and can't
    // double-tap the export button.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF38BDF8),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                "Generating PDF...",
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                "This can take a few seconds for large sets.",
                style: GoogleFonts.inter(
                    color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );

    final questions = await ref
        .read(databaseProvider)
        .getCustomQuestions(
          examName: exam,
          years: years,
          subjects: subject != null ? [subject] : null,
          topics: topics,
          limit: 100,
        );

    if (!context.mounted) return;
    if (questions.isEmpty) {
      Navigator.of(context, rootNavigator: true).pop(); // dismiss spinner
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No questions to export.")),
      );
      return;
    }

    await PdfService.generateExamPdf(
      questions: questions,
      title: "Custom Practice Set",
      subject: subject ?? "Mixed Subjects",
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss spinner
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Exported ${questions.length} questions."),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  void _handleStartQuiz(BuildContext context, WidgetRef ref) async {
    final years = ref.read(selectedYearsProvider);
    final subject = ref.read(selectedSubjectProvider);
    final topics = ref.read(selectedTopicsProvider);
    final exam = ref.read(selectedExamProvider);

    final questions = await ref
        .read(databaseProvider)
        .getCustomQuestions(
          examName: exam,
          years: years,
          subjects: subject != null ? [subject] : null,
          topics: topics,
          limit: 500,
        );

    if (questions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No questions found based on your selection."),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuizScreen(questions: questions)),
      );
    }
  }
}
