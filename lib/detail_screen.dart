import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../database.dart';
import '../screens/quiz_screen.dart';
import 'widgets/tex_view.dart';
import 'widgets/question_diagram.dart';
import 'services/diagram_storage.dart';
import 'utils/colors.dart';
import 'utils/answer_grading.dart';
import 'services/weightage_service.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final Question question;
  const DetailScreen({super.key, required this.question});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  bool _isRevealed = false;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
  }

  void _checkBookmark() async {
    final exists = await ref
        .read(databaseProvider)
        .isMistake(widget.question.id);
    if (mounted) setState(() => _isBookmarked = exists);
  }

  void _toggleBookmark() {
    if (!mounted) return;
    final db = ref.read(databaseProvider);

    setState(() => _isBookmarked = !_isBookmarked);

    if (_isBookmarked) {
      db.addMistake(widget.question.id);
    } else {
      db.removeMistake(widget.question.id);
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(_isBookmarked ? "Saved to Notebook" : "Removed"),
        duration: const Duration(milliseconds: 800),
        backgroundColor: Colors.cyan,
      ),
    );
  }

  Future<void> _sendReportEmail() async {
    final String subject = Uri.encodeComponent(
      "Report Issue: QID ${widget.question.id}",
    );
    final String body = Uri.encodeComponent(
      "Hi Dev,\n\nI found an issue in Question ID: ${widget.question.id}\n"
      "Subject: ${widget.question.subject}\n"
      "Year: ${widget.question.year}\n\n"
      "Issue Description:\n"
      "- [ ] Typo in Question\n"
      "- [ ] Wrong Options\n"
      "- [ ] Diagram Missing\n"
      "- [ ] Other:\n\n",
    );

    final Uri emailUri = Uri.parse(
      "mailto:jvoltci@gmail.com?subject=$subject&body=$body",
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open email app.")),
        );
      }
    }
  }

  void _reportQuestion() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.amber),
            const SizedBox(width: 10),
            Text(
              "Report Issue",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "Found a mistake? This will open your email app to send a report directly to the developer.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 16),
            label: const Text("Send Email"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _sendReportEmail();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchQuickPractice({
    List<String>? topics,
    List<int>? years,
  }) async {
    final db = ref.read(databaseProvider);
    final questions = await db.getCustomQuestions(
      topics: topics,
      years: years,
      limit: 30,
    );

    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No similar questions found.")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(questions: questions)),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.greenAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'hard':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> options = [];
    try {
      options = jsonDecode(widget.question.optionsJson);
    } catch (_) {}
    final qType = AnswerGrading.typeOf(
      options: options.map((e) => e.toString()).toList(),
      answerKey: widget.question.answerKey,
    );
    final subjectColor = AppColors.getForSubject(widget.question.subject);

    final difficultyColor = _getDifficultyColor(widget.question.difficulty);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.question.subject,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: subjectColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            color: _isBookmarked ? subjectColor : Colors.white,
            onPressed: _toggleBookmark,
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppColors.cardDark,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'report',
                child: Text(
                  "Report Error",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              PopupMenuItem(
                value: 'copy_id',
                child: Row(
                  children: [
                    const Icon(Icons.copy_rounded,
                        size: 16, color: Colors.white54),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.question.id,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'report') _reportQuestion();
              if (val == 'copy_id') {
                Clipboard.setData(ClipboardData(text: widget.question.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('ID copied: ${widget.question.id}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _metaItem(Icons.calendar_today, "${widget.question.year}"),
                  _verticalDivider(),

                  _metaItem(
                    Icons.numbers,
                    "Q.${widget.question.id.contains('_') ? widget.question.id.split('_').last : '?'}",
                  ),
                  _verticalDivider(),

                  Row(
                    children: [
                      Icon(
                        Icons.signal_cellular_alt,
                        color: difficultyColor,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.question.difficulty,
                        style: TextStyle(
                          color: difficultyColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionChip(
                  context,
                  "Topic: ${widget.question.topic}",
                  () => _launchQuickPractice(topics: [widget.question.topic]),
                  subjectColor,
                ),
                _actionChip(
                  context,
                  "Year: ${widget.question.year}",
                  () => _launchQuickPractice(years: [widget.question.year]),
                  subjectColor,
                ),
                _WeightageChip(
                  tier: WeightageService().tierFor(
                    widget.question.subject,
                    widget.question.topic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TexText(
              widget.question.questionLatex,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),

            if (widget.question.questionSvg != null &&
                widget.question.questionSvg!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: DiagramStorage.isFilenameReference(
                      widget.question.questionSvg,
                    )
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.05),
                    child: InkWell(
                      onTap: () => QuestionDiagram.openFullscreen(
                        context,
                        widget.question.questionSvg!,
                      ),
                      child: Stack(
                        children: [
                          Container(
                            height: 250,
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            child: QuestionDiagram(
                              value: widget.question.questionSvg!,
                              color: Colors.white,
                              cacheWidth: 900,
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

            ...options.asMap().entries.map(
              (e) => _buildOption(e.key, e.value.toString(), subjectColor),
            ),

            const SizedBox(height: 30),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isRevealed
                  ? _buildSolution(subjectColor, qType)
                  : _buildRevealButton(subjectColor),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 14),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() =>
      Container(height: 20, width: 1, color: Colors.white24);

  Widget _actionChip(
    BuildContext context,
    String label,
    VoidCallback onTap,
    Color color,
  ) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
      avatar: Icon(Icons.play_arrow, size: 16, color: color),
    );
  }

  Widget _buildOption(int index, String text, Color activeColor) {
    String label = String.fromCharCode(65 + index);
    // Multi-correct keys are like "A,C" — highlight every correct letter.
    final correctSet = (widget.question.answerKey ?? '')
        .toUpperCase()
        .split(RegExp(r'[,\s]+'))
        .where((x) => x.isNotEmpty)
        .toSet();
    bool isCorrect = correctSet.contains(label);

    Color borderColor = Colors.white10;
    Color bgColor = Colors.white.withValues(alpha: 0.02);

    if (_isRevealed && isCorrect) {
      borderColor = Colors.green;
      bgColor = Colors.green.withValues(alpha: 0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _isRevealed && isCorrect
                ? Colors.green
                : Colors.white10,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TexText(
              text,
              style: const TextStyle(fontSize: 15, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealButton(Color color) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => setState(() => _isRevealed = true),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          "Reveal Answer",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildSolution(Color color, QType qType) {
    final answerText = AnswerGrading.correctAnswerText(
      type: qType,
      answerKey: widget.question.answerKey,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always show the correct answer explicitly — essential for numeric
          // and multi-correct questions where no single option tile conveys it.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text(
                  "Correct answer:  ",
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: TexText(
                    answerText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Color(0xFFEAB308), size: 20),
              const SizedBox(width: 8),
              Text(
                "Solution",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          TexText(
            widget.question.solution ?? "Explanation not available.",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          if (widget.question.solutionSvg != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => QuestionDiagram.openFullscreen(
                  context, widget.question.solutionSvg!),
              child: QuestionDiagram(
                value: widget.question.solutionSvg!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightageChip extends StatelessWidget {
  final WeightageTier tier;
  const _WeightageChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    if (tier == WeightageTier.unknown) return const SizedBox.shrink();
    final (label, icon, color) = switch (tier) {
      WeightageTier.high =>
        ("HIGH YIELD", Icons.local_fire_department, const Color(0xFFEF4444)),
      WeightageTier.medium =>
        ("MEDIUM", Icons.flash_on, const Color(0xFFF59E0B)),
      WeightageTier.low =>
        ("LOW", Icons.remove_circle_outline, const Color(0xFF64748B)),
      WeightageTier.unknown => ("", Icons.help_outline, Colors.transparent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
