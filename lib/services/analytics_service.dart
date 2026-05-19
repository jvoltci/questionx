import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();

  static bool get _firebaseReady => Firebase.apps.isNotEmpty;

  static Future<void> _log(
    String name, [
    Map<String, Object?>? params,
  ]) async {
    if (!_firebaseReady) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: params?.cast<String, Object>(),
      );
    } catch (e) {
      debugPrint("Analytics log failed for $name: $e");
    }
  }

  static Future<void> logExamSelected(String exam) =>
      _log('exam_selected', {'exam': exam});

  static Future<void> logQuizStarted({
    required String exam,
    required String subject,
    required int questionCount,
  }) =>
      _log('quiz_started', {
        'exam': exam,
        'subject': subject,
        'count': questionCount,
      });

  static Future<void> logQuizFinished({
    required int correct,
    required int wrong,
    required int skipped,
    required int durationSeconds,
  }) =>
      _log('quiz_finished', {
        'correct': correct,
        'wrong': wrong,
        'skipped': skipped,
        'duration_s': durationSeconds,
      });

  static Future<void> logQuestionReport({
    required String questionId,
    required String reason,
    String? note,
  }) =>
      _log('question_reported', {
        'qid': questionId,
        'reason': reason,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  static void recordError(Object error, StackTrace stack, {String? reason}) {
    if (kDebugMode || !_firebaseReady) return;
    FirebaseCrashlytics.instance
        .recordError(error, stack, reason: reason, fatal: false);
  }
}
