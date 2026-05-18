import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum WeightageTier { high, medium, low, unknown }

WeightageTier _fromString(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'high':
      return WeightageTier.high;
    case 'medium':
    case 'med':
      return WeightageTier.medium;
    case 'low':
      return WeightageTier.low;
    default:
      return WeightageTier.unknown;
  }
}

/// Loads "Subject::Topic"-keyed weightage from FormulaX-style JSON,
/// then resolves messy QuestionX topic strings via substring matching.
class WeightageService {
  static final WeightageService _instance = WeightageService._();
  factory WeightageService() => _instance;
  WeightageService._();

  Map<String, WeightageTier> _byKey = const {};
  Map<String, List<MapEntry<String, WeightageTier>>> _bySubject = const {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw =
          await rootBundle.loadString('assets/topic_weightage.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _byKey = decoded.map(
        (k, v) => MapEntry(k, _fromString(v as String?)),
      );
      final grouped = <String, List<MapEntry<String, WeightageTier>>>{};
      for (final e in _byKey.entries) {
        final parts = e.key.split('::');
        if (parts.length != 2) continue;
        grouped.putIfAbsent(parts[0], () => []).add(MapEntry(parts[1], e.value));
      }
      _bySubject = grouped;
    } catch (e) {
      debugPrint("Weightage load failed: $e");
    }
    _loaded = true;
  }

  WeightageTier tierFor(String subject, String topic) {
    final exact = _byKey['$subject::$topic'];
    if (exact != null && exact != WeightageTier.unknown) return exact;

    final candidates = _bySubject[subject] ?? const [];
    final topicLower = topic.toLowerCase();
    for (final c in candidates) {
      final cLower = c.key.toLowerCase();
      if (topicLower.contains(cLower) || cLower.contains(topicLower)) {
        return c.value;
      }
    }
    final firstToken =
        topicLower.split(RegExp(r'[\s/:,&-]+')).firstWhere(
              (s) => s.length > 3,
              orElse: () => '',
            );
    if (firstToken.isNotEmpty) {
      for (final c in candidates) {
        if (c.key.toLowerCase().contains(firstToken)) return c.value;
      }
    }
    return WeightageTier.unknown;
  }
}
