import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/data/cross_exam_topics.dart';
import 'package:questionx/utils/crypto.dart';

/// Guards the NEET <-> JEE topic map against the shipped banks.
///
/// Both directions matter. A JEE topic missing from the map means its questions
/// silently never reach a NEET student; a NEET name in the map that no longer
/// exists in the bank means a mapping that quietly does nothing. Either way the
/// failure is invisible at runtime, so it has to fail the build instead.

List<dynamic> bank(String path) =>
    json.decode(DataCrypto.decryptBytes(File(path).readAsBytesSync())) as List;

Set<String> topicsOf(List<dynamic> qs, String subjectPrefix) => qs
    .where((q) => ((q['subject'] ?? '') as String)
        .toLowerCase()
        .startsWith(subjectPrefix))
    .map((q) => q['topic'] as String)
    .toSet();

void main() {
  late List<dynamic> neet;
  late List<dynamic> jee;

  setUpAll(() {
    neet = bank('assets/neet.json.enc');
    jee = bank('assets/jee.json.enc');
  });

  test('every JEE Physics topic is mapped or explicitly out of scope', () {
    final accounted = kJeeToNeetPhysics.keys.toSet()
      ..addAll(kJeeTopicsOutOfNeetScope.keys);
    final unaccounted = topicsOf(jee, 'phys').difference(accounted);
    expect(unaccounted, isEmpty,
        reason: 'these JEE Physics topics would silently never reach a NEET '
            'student — map them, or record why not in '
            'kJeeTopicsOutOfNeetScope: $unaccounted');
  });

  test('every JEE Chemistry topic is mapped or explicitly out of scope', () {
    final accounted = kJeeToNeetChemistry.keys.toSet()
      ..addAll(kJeeTopicsOutOfNeetScope.keys);
    final unaccounted = topicsOf(jee, 'chem').difference(accounted);
    expect(unaccounted, isEmpty,
        reason: 'these JEE Chemistry topics would silently never reach a NEET '
            'student — map them, or record why not in '
            'kJeeTopicsOutOfNeetScope: $unaccounted');
  });

  test('out-of-scope topics are excluded, not merely forgotten', () {
    for (final t in kJeeTopicsOutOfNeetScope.keys) {
      expect(kJeeToNeetTopics.containsKey(t), isFalse,
          reason: '$t is both mapped and excluded');
      expect(kJeeTopicsOutOfNeetScope[t], isNotEmpty,
          reason: '$t is excluded without a recorded reason');
    }
    // The material genuinely is not NEET's; these must not surface.
    expect(jeeTopicsFor(['Communication Systems'], 'Physics'), isEmpty);
    expect(jeeTopicsFor(['Qualitative Analysis'], 'Chemistry'), isEmpty);
  });

  test('every NEET topic named in the map exists in the bank', () {
    final real = topicsOf(neet, 'phys').union(topicsOf(neet, 'chem'));
    final named = kJeeToNeetTopics.values.expand((v) => v).toSet();
    expect(named.difference(real), isEmpty,
        reason: 'mapped to NEET topics that do not exist (typo?)');
  });

  test('a Biology selection can never reach JEE questions', () {
    // `Biomolecules` is a topic name in NEET Biology AND NEET Chemistry, so the
    // lookup is scoped by subject rather than by topic name alone.
    for (final t in topicsOf(neet, 'bio')) {
      expect(jeeTopicsFor([t], 'Biology'), isEmpty, reason: t);
    }
    expect(jeeTopicsFor(['Biomolecules'], 'Biology'), isEmpty);
    expect(jeeTopicsFor(['Biomolecules'], 'Chemistry'), contains('Biomolecules'));
  });

  test('inversion round-trips within each subject', () {
    kJeeToNeetPhysics.forEach((jeeTopic, neetTopics) {
      for (final n in neetTopics) {
        expect(neetTopicToJeePhysics[n], contains(jeeTopic));
      }
    });
    kJeeToNeetChemistry.forEach((jeeTopic, neetTopics) {
      for (final n in neetTopics) {
        expect(neetTopicToJeeChemistry[n], contains(jeeTopic));
      }
    });
  });

  test('supportsCrossExam gates on subject', () {
    expect(supportsCrossExam('Physics'), isTrue);
    expect(supportsCrossExam('Chemistry'), isTrue);
    expect(supportsCrossExam('Biology'), isFalse);
  });

  test('jeeTopicsFor resolves a fragmented NEET topic to its JEE bucket', () {
    // The four "Dual Nature" spellings in the NEET bank all cover one JEE topic.
    for (final variant in const [
      'Dual Nature of Matter',
      'Dual Nature of Matter and Radiation',
      'Dual Nature of Radiation',
      'Dual Nature of Radiation and Matter',
    ]) {
      expect(jeeTopicsFor([variant], 'Physics'),
          contains('Dual Nature Of Radiation'));
    }
  });

  test('jeeTopicsFor returns nothing for Biology topics', () {
    expect(jeeTopicsFor(
        ['Reproductive Health', 'Human Physiology'], 'Biology'), isEmpty);
  });

  test('the map unlocks a real amount of practice', () {
    // Guards the premise of the feature: if a future bank made this marginal,
    // the switch would not be worth showing.
    var reachable = 0;
    final mapped = kJeeToNeetTopics.keys.toSet();
    for (final q in jee) {
      final subj = ((q['subject'] ?? '') as String).toLowerCase();
      if (!subj.startsWith('phys') && !subj.startsWith('chem')) continue;
      if (mapped.contains(q['topic'])) reachable++;
    }
    // ignore: avoid_print
    print('JEE Phy+Chem questions reachable by a NEET student: $reachable');
    expect(reachable, greaterThan(9000));
  });
}
