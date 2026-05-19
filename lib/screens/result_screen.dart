import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'review_screen.dart';
import '../home_screen.dart';

class ResultScreen extends StatelessWidget {
  final int sessionId;
  final int total;
  final int correct;
  final int wrong;
  final int skipped;
  final int duration;

  const ResultScreen({
    super.key,
    required this.sessionId,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final double accuracy = total > 0 ? (correct / total) * 100 : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "Result Analysis",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 60,
                        sections: [
                          _chartSection(
                            Colors.green,
                            correct.toDouble(),
                            "Correct",
                          ),
                          _chartSection(Colors.red, wrong.toDouble(), "Wrong"),
                          _chartSection(
                            Colors.grey.withValues(alpha: 0.3),
                            skipped.toDouble(),
                            "Skip",
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${accuracy.toStringAsFixed(1)}%",
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "Score",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      Icons.check_circle,
                      "$correct",
                      "Correct",
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _statCard(
                      Icons.cancel,
                      "$wrong",
                      "Wrong",
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      Icons.timer,
                      _formatDuration(duration),
                      "Time Taken",
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _statCard(
                      Icons.help_outline,
                      "$skipped",
                      "Skipped",
                      Colors.grey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(sessionId: sessionId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text("Review Answers"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (r) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Go Home",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PieChartSectionData _chartSection(Color color, double value, String title) {
    return PieChartSectionData(
      color: color,
      value: value > 0 ? value : 0.001,
      title: value > 0 ? '${value.toInt()}' : '',
      radius: 25,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return "${seconds}s";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return s == 0 ? "${m}m" : "${m}m ${s}s";
    final h = m ~/ 60;
    final remM = m % 60;
    return remM == 0 ? "${h}h" : "${h}h ${remM}m";
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
