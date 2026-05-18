import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../database.dart';
import '../services/analytics_service.dart';
import '../widgets/tex_view.dart';
import '../widgets/question_diagram.dart';
import '../services/diagram_storage.dart';
import 'result_screen.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final List<Question> questions;
  const QuizScreen({super.key, required this.questions});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _currentIndex = 0;
  final Map<int, String> _userAnswers = {};
  final Map<int, int> _timeSpentPerQuestion = {};

  late final Timer _timer;
  final ValueNotifier<int> _elapsed = ValueNotifier(0);
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    if (widget.questions.isNotEmpty) {
      final first = widget.questions.first;
      AnalyticsService.logQuizStarted(
        exam: first.examName,
        subject: first.subject,
        questionCount: widget.questions.length,
      );
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed.value++;
      _timeSpentPerQuestion[_currentIndex] =
          (_timeSpentPerQuestion[_currentIndex] ?? 0) + 1;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _elapsed.dispose();
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    if (_isSubmitting) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Exit quiz?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Your answers will not be saved.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Stay"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Exit",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _submitQuiz() async {
    _timer.cancel();
    setState(() => _isSubmitting = true);

    final db = ref.read(databaseProvider);
    int correct = 0;
    int wrong = 0;
    int skipped = 0;

    final List<SessionAnswersCompanion> answerEntries = [];

    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final userAnswer = _userAnswers[i];
      final timeSpent = _timeSpentPerQuestion[i] ?? 0;
      bool isCorrect = false;

      if (userAnswer == null) {
        skipped++;
      } else if (userAnswer == q.answerKey) {
        correct++;
        isCorrect = true;
      } else {
        wrong++;
        await db.addMistake(q.id);
      }

      answerEntries.add(
        SessionAnswersCompanion.insert(
          questionId: q.id,
          isCorrect: isCorrect,
          selectedOption: drift.Value(userAnswer),
          sessionId: 0,
          timeSpent: drift.Value(timeSpent),
        ),
      );
    }

    final session = PracticeSessionsCompanion.insert(
      startTime: DateTime.now(),
      durationSeconds: _elapsed.value,
      totalQuestions: widget.questions.length,
      correctCount: correct,
      wrongCount: wrong,
      skippedCount: skipped,
    );

    final newSessionId = await db.saveSession(session, answerEntries);

    AnalyticsService.logQuizFinished(
      correct: correct,
      wrong: wrong,
      skipped: skipped,
      durationSeconds: _elapsed.value,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          sessionId: newSessionId,
          total: widget.questions.length,
          correct: correct,
          wrong: wrong,
          skipped: skipped,
          duration: _elapsed.value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_currentIndex];

    List<String> options = [];
    try {
      options = List<String>.from(jsonDecode(q.optionsJson));
    } catch (_) {}

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await _confirmExit();
        if (!exit) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "Question ${_currentIndex + 1}/${widget.questions.length}",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          actions: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ValueListenableBuilder<int>(
                  valueListenable: _elapsed,
                  builder: (_, seconds, __) => Text(
                    _formatTime(seconds),
                    style: GoogleFonts.robotoMono(
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) / widget.questions.length,
                backgroundColor: Colors.white10,
                color: Colors.cyan,
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TexText(
                        q.questionLatex,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (q.questionSvg != null && q.questionSvg!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Material(
                              color: DiagramStorage.isFilenameReference(
                                q.questionSvg,
                              )
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.05),
                              child: InkWell(
                                onTap: () => QuestionDiagram.openFullscreen(
                                  context,
                                  q.questionSvg!,
                                ),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 250,
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      child: QuestionDiagram(
                                        value: q.questionSvg!,
                                        fit: BoxFit.contain,
                                        cacheWidth: 900,
                                        errorPlaceholder: const Center(
                                          child: Text(
                                            "Error loading diagram",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Icon(
                                        Icons.zoom_out_map,
                                        size: 18,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      ...List.generate(options.length, (index) {
                        final optionChar = String.fromCharCode(65 + index);
                        final isSelected =
                            _userAnswers[_currentIndex] == optionChar;
                        final optionText = options[index];

                        return GestureDetector(
                          onTap: () => setState(
                            () => _userAnswers[_currentIndex] = optionChar,
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.cyan.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.cyan
                                    : Colors.white10,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isSelected
                                      ? Colors.cyan
                                      : Colors.white10,
                                  child: Text(
                                    optionChar,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: TexText(
                                    optionText,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentIndex > 0)
                    ElevatedButton(
                      onPressed: () => setState(() => _currentIndex--),
                      child: const Text("Previous"),
                    )
                  else
                    const SizedBox(width: 10),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentIndex == widget.questions.length - 1
                          ? Colors.green
                          : Colors.blue,
                    ),
                    onPressed: () {
                      if (_currentIndex < widget.questions.length - 1) {
                        setState(() => _currentIndex++);
                      } else {
                        _submitQuiz();
                      }
                    },
                    child: Text(
                      _currentIndex == widget.questions.length - 1
                          ? "Submit"
                          : "Next",
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

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
