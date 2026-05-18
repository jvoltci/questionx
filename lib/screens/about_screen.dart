import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 100,
                    spreadRadius: 50,
                    color: Color(0xFF38BDF8),
                  ),
                ],
              ),
            ),
          ),

          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'app_logo',
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF38BDF8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.hub,
                      size: 50,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Question X",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "v1.0.0 (Premium Build)",
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 30),

                Text(
                  "The ultimate offline practice tool for NEET & JEE aspirants. \nMaster Physics, Chemistry, and Biology.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
                ),

                const SizedBox(height: 40),
                const Divider(color: Colors.white10),
                const SizedBox(height: 20),

                _sectionTitle("Why QuestionX?"),
                const SizedBox(height: 15),
                _featureRow(
                  Icons.wifi_off,
                  "100% Offline",
                  "Practice anywhere without internet.",
                ),
                _featureRow(
                  Icons.picture_as_pdf,
                  "PDF Export",
                  "Generate print-ready exam papers.",
                ),
                _featureRow(
                  Icons.functions,
                  "LaTeX Engine",
                  "Crystal clear math & chemical formulas.",
                ),
                _featureRow(
                  Icons.book,
                  "Mistake Notebook",
                  "Auto-track weak areas for revision.",
                ),

                const SizedBox(height: 30),
                const Divider(color: Colors.white10),
                const SizedBox(height: 20),

                _sectionTitle("Developer"),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white10,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Built with ❤️ by JAI",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Aiming to democratize education.",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchEmail(),
                          icon: const Icon(Icons.mail_outline),
                          label: const Text("Contact Developer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: const Color(0xFF0B1120),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                Text(
                  '© ${DateFormat('yyyy').format(DateTime.now())} QuestionX Inc.',
                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri.parse(
      "mailto:jvoltci@gmail.com?subject=QuestionX Feedback",
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }
}
