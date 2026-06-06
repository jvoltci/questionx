import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analytics_service.dart';

/// Cross-promo for the sibling app Formula X (NEET/JEE formula revision).
/// Practice (here) ↔ revision (Formula X) is the loop. Opens its Play listing
/// (installed users get "Open"). Mirrors the Question X card in Formula X.
class FormulaXCard extends StatelessWidget {
  const FormulaXCard({super.key});

  static const _package = 'com.blueshift.formulax';
  static const _color = Color(0xFF38BDF8); // Formula X accent (sky blue)

  Future<void> _open() async {
    AnalyticsService.logCrossPromoTap('formulax');
    final market = Uri.parse('market://details?id=$_package');
    final web =
        Uri.parse('https://play.google.com/store/apps/details?id=$_package');
    try {
      if (await canLaunchUrl(market)) {
        await launchUrl(market, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(web, mode: LaunchMode.externalApplication);
      } catch (_) {/* offline / no browser */}
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_color.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.04)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _color.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.functions, color: _color),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Formula X',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      SizedBox(width: 6),
                      Icon(Icons.open_in_new, color: Colors.white54, size: 14),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Revising? Get 3,500+ verified NEET/JEE formulas — instant & offline. From the makers of Question X.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
