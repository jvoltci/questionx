import 'package:flutter/material.dart';

class AppColors {
  static const bgDark = Color(0xFF0B1120);
  static const cardDark = Color(0xFF1E293B);

  static const physics = Color.fromARGB(255, 0, 221, 255);
  static const chemistry = Color(0xFFF59E0B);
  static const biology = Color(0xFF10B981);
  static const math = Color(0xFFF43F5E);
  static const def = Color(0xFF38BDF8);

  static Color getForSubject(String subject) {
    switch (subject.toLowerCase()) {
      case 'physics':
        return physics;
      case 'chemistry':
        return chemistry;
      case 'biology':
        return biology;
      case 'mathematics':
      case 'maths':
        return math;
      default:
        return def;
    }
  }
}
