import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:questionx/screens/about_screen.dart';
import 'main.dart';
import 'database.dart';
import 'detail_screen.dart';
import 'screens/practice_config_screen.dart';
import 'screens/history_screen.dart';
import 'screens/mistake_screen.dart';
import 'widgets/tex_view.dart';
import 'utils/colors.dart';
import 'package:drift/drift.dart' as drift;

final selectedExamProvider = StateProvider<String?>((ref) => null);
final subjectFilterProvider = StateProvider<String>((ref) => "Physics");
final searchProvider = StateProvider<String>((ref) => "");

final filteredQuestionsProvider = FutureProvider.autoDispose<List<Question>>((
  ref,
) async {
  final db = ref.read(databaseProvider);
  final exam = ref.watch(selectedExamProvider);
  final subject = ref.watch(subjectFilterProvider);
  final search = ref.watch(searchProvider);

  if (exam == null) return [];

  final query = db.select(db.questions)
    ..where((tbl) => tbl.examName.contains(exam))
    ..where((tbl) => tbl.subject.equals(subject));

  final subjectQuestions = await query.get();

  if (search.isEmpty) {
    return subjectQuestions;
  } else {
    final lowerSearch = search.toLowerCase();
    return subjectQuestions.where((q) {
      return q.questionLatex.toLowerCase().contains(lowerSearch) ||
          q.topic.toLowerCase().contains(lowerSearch);
    }).toList();
  }
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedExam();
  }

  Future<void> _loadSavedExam() async {
    final prefs = await SharedPreferences.getInstance();
    final savedExam = prefs.getString('selected_exam');

    if (savedExam != null) {
      ref.read(selectedExamProvider.notifier).state = savedExam;

      if (savedExam.contains("NEET")) {
        ref.read(subjectFilterProvider.notifier).state = "Biology";
      } else {
        ref.read(subjectFilterProvider.notifier).state = "Physics";
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B1120),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      );
    }

    final selectedExam = ref.watch(selectedExamProvider);

    if (selectedExam == null) {
      return const ExamSelectionScreen();
    }

    return const DashboardScreen();
  }
}

class ExamSelectionScreen extends ConsumerWidget {
  const ExamSelectionScreen({super.key});

  Future<void> _selectExam(
    WidgetRef ref,
    String exam,
    String defaultSubject,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_exam', exam);
    ref.read(subjectFilterProvider.notifier).state = defaultSubject;
    ref.read(selectedExamProvider.notifier).state = exam;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: _glowCircle(const Color(0xFF38BDF8)),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: _glowCircle(const Color(0xFF10B981)),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.hub, size: 60, color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    "Choose Your Goal",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Select your target exam to customize\nyour practice experience.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 50),
                  _ExamCard(
                    title: "JEE Main",
                    subtitle: "Engineering Entrance",
                    icon: Icons.engineering,
                    color1: const Color(0xFF3B82F6),
                    color2: const Color(0xFF2563EB),
                    onTap: () => _selectExam(ref, "JEE Main", "Physics"),
                  ),
                  const SizedBox(height: 20),
                  _ExamCard(
                    title: "NEET",
                    subtitle: "Medical Entrance",
                    icon: Icons.medical_services,
                    color1: const Color(0xFF10B981),
                    color2: const Color(0xFF059669),
                    onTap: () => _selectExam(ref, "NEET", "Biology"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color1;
  final Color color2;
  final VoidCallback onTap;

  const _ExamCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color1,
    required this.color2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1.withOpacity(0.2), color2.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color1.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: color1.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color1,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: color1.withOpacity(0.5),
              size: 16,
            ),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showDbStats(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final all = await db.select(db.questions).get();

    final exams = all.map((e) => e.examName).toSet().toList();
    final subjects = all.map((e) => e.subject).toSet().toList();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Database Debugger",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total Questions: ${all.length}",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            const Text(
              "Exams Found:",
              style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
            ),
            Text(exams.toString(), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            const Text(
              "Subjects Found:",
              style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
            ),
            Text(
              subjects.toString(),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSubject = ref.watch(subjectFilterProvider);
    final selectedExam = ref.watch(selectedExamProvider);
    final questionsAsync = ref.watch(filteredQuestionsProvider);
    final activeColor = AppColors.getForSubject(selectedSubject);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PracticeConfigScreen()),
        ),
        backgroundColor: activeColor,
        foregroundColor: Colors.black,
        elevation: 10,
        icon: const Icon(Icons.tune),
        label: const Text(
          "Custom Test",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            top: -100,
            left: -100,
            child: _glowCircle(activeColor),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            bottom: -100,
            right: -100,
            child: _glowCircle(activeColor.withOpacity(0.5)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, ref, activeColor, selectedExam ?? "Exam"),
                _buildTabs(ref, selectedSubject, selectedExam ?? ""),
                const SizedBox(height: 20),
                Expanded(
                  child: questionsAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(color: activeColor),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        "Error: $e",
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    data: (questions) {
                      if (questions.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 50,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No questions found.",
                                style: GoogleFonts.inter(color: Colors.white38),
                              ),
                              const SizedBox(height: 20),

                              TextButton.icon(
                                icon: const Icon(Icons.bug_report),
                                label: const Text("Check DB Data"),
                                onPressed: () => _showDbStats(context, ref),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        physics: const BouncingScrollPhysics(),
                        itemCount: questions.length,
                        itemBuilder: (ctx, index) =>
                            QuestionCard(question: questions[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    Color accentColor,
    String examName,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('selected_exam');
                  ref.read(selectedExamProvider.notifier).state = null;
                },
                child: Row(
                  children: [
                    Text(
                      examName,
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "CHANGE",
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // IconButton(
                  //   icon: const Icon(
                  //     Icons.bug_report,
                  //     color: Colors.white24,
                  //     size: 20,
                  //   ),
                  //   onPressed: () => _showDbStats(context, ref),
                  // ),
                  _iconBtn(
                    Icons.history,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  _iconBtn(
                    Icons.bookmark_outline,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MistakeScreen()),
                    ),
                  ),
                  _iconBtn(
                    Icons.info_outline,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            onChanged: (val) => ref.read(searchProvider.notifier).state = val,
            style: const TextStyle(color: Colors.white),
            cursorColor: accentColor,
            decoration: InputDecoration(
              hintText: 'Search anything...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: Icon(Icons.search, color: accentColor),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(
                  color: accentColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70),
      onPressed: onTap,
      splashRadius: 20,
    );
  }

  Widget _buildTabs(WidgetRef ref, String selected, String examName) {
    List<String> subjects = examName.contains("NEET")
        ? ["Biology", "Physics", "Chemistry"]
        : ["Mathematics", "Physics", "Chemistry"];

    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final sub = subjects[index];
          final isSelected = selected == sub;
          final color = AppColors.getForSubject(sub);
          return GestureDetector(
            onTap: () => ref.read(subjectFilterProvider.notifier).state = sub,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(25),
                border: isSelected ? null : Border.all(color: Colors.white10),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                sub,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  final Question question;
  const QuestionCard({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    final subjectColor = AppColors.getForSubject(question.subject);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(question: question)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.cardDark.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: Container(color: subjectColor),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _badge(
                            question.topic.isNotEmpty
                                ? question.topic
                                : "General",
                            subjectColor,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${question.year}",
                              style: GoogleFonts.robotoMono(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (question.questionSvg != null &&
                          question.questionSvg!.isNotEmpty)
                        Container(
                          height: 80,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: SvgPicture.string(
                            question.questionSvg!,
                            colorFilter: const ColorFilter.mode(
                              Colors.white70,
                              BlendMode.srcIn,
                            ),
                            placeholderBuilder: (_) => const Center(
                              child: Icon(Icons.image, color: Colors.white24),
                            ),
                          ),
                        ),
                      TexText(
                        question.questionLatex,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
