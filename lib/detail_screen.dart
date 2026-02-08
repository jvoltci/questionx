import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../database.dart';
import '../screens/quiz_screen.dart';
import 'widgets/tex_view.dart';
import 'utils/colors.dart';

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
    final db = ref.read(databaseProvider);

    setState(() => _isBookmarked = !_isBookmarked);

    if (_isBookmarked) {
      db.addMistake(widget.question.id);
    } else {
      db.removeMistake(widget.question.id);
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    List<dynamic> options = [];
    try {
      options = jsonDecode(widget.question.optionsJson);
    } catch (_) {}
    final subjectColor = AppColors.getForSubject(widget.question.subject);

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
            ],
            onSelected: (val) {
              if (val == 'report') _reportQuestion();
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
                color: Colors.white.withOpacity(0.05),
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
                    "Q. ${widget.question.id.contains('_') ? widget.question.id.split('_').last : '?'}",
                  ),
                  _verticalDivider(),
                  _metaItem(Icons.book, widget.question.subject),
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
                  "Practice Topic: ${widget.question.topic}",
                  () => _launchQuickPractice(topics: [widget.question.topic]),
                  subjectColor,
                ),
                _actionChip(
                  context,
                  "Practice Year: ${widget.question.year}",
                  () => _launchQuickPractice(years: [widget.question.year]),
                  subjectColor,
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
              Container(
                height: 250,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SvgPicture.string(
                        widget.question.questionSvg!,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
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
                  ? _buildSolution(subjectColor)
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
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
      avatar: Icon(Icons.play_arrow, size: 16, color: color),
    );
  }

  Widget _buildOption(int index, String text, Color activeColor) {
    String label = String.fromCharCode(65 + index);
    bool isCorrect = label == widget.question.answerKey;

    Color borderColor = Colors.white10;
    Color bgColor = Colors.white.withOpacity(0.02);

    if (_isRevealed && isCorrect) {
      borderColor = Colors.green;
      bgColor = Colors.green.withOpacity(0.1);
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

  Widget _buildSolution(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    );
  }
}
