import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/database.dart';
import 'package:questionx/screens/practice_config_screen.dart';

/// Test length. Before this there was no control at all: a run took everything
/// that matched, so a student started what looked like a quick test and got 375
/// questions with no warning.

Future<void> seed(AppDatabase db, String subject, int n) async {
  for (var i = 0; i < n; i++) {
    await db.into(db.questions).insert(QuestionsCompanion.insert(
          id: '$subject$i', examName: 'NEET', subject: subject,
          topic: 'T', difficulty: 'Medium', questionLatex: 'q$i',
          optionsJson: '[]', year: 2024));
  }
}

Future<List<Question>> run(AppDatabase db, {String? subject, int? length,
    String exam = 'NEET', int seedVal = 1}) =>
    buildPracticeSet(db: db, exam: exam, years: const [], subject: subject,
        topics: const [], crossExamTopics: const [], length: length,
        seed: seedVal);

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seed(db, 'Physics', 200);
    await seed(db, 'Chemistry', 200);
    await seed(db, 'Biology', 200);
  });
  tearDown(() => db.close());

  test('a preset caps the run', () async {
    expect((await run(db, subject: 'Physics', length: 25)).length, 25);
    expect((await run(db, subject: 'Physics', length: 10)).length, 10);
  });

  test('null means everything, which is what caught the reporter out', () async {
    expect((await run(db, subject: 'Physics', length: null)).length, 200);
  });

  test('asking for more than exists returns what exists', () async {
    await db.delete(db.questions).go();
    await seed(db, 'Physics', 7);
    expect((await run(db, subject: 'Physics', length: 25)).length, 7);
  });

  test('NEET full mock is 180, split 45/45/90', () async {
    final set = await run(db, length: kFullMockLength);
    expect(set.length, 180);
    int of(String s) => set.where((q) => q.subject == s).length;
    expect(of('Physics'), 45);
    expect(of('Chemistry'), 45);
    expect(of('Biology'), 90);
  });

  test('JEE full mock is 75, 25 per subject', () async {
    await db.delete(db.questions).go();
    for (final s in ['Physics', 'Chemistry', 'Mathematics']) {
      await seed(db, s, 100);
    }
    await db.update(db.questions).write(
        const QuestionsCompanion(examName: Value('JEE Main')));
    final set = await run(db, exam: 'JEE Main', length: kFullMockLength);
    expect(set.length, 75);
    for (final s in ['Physics', 'Chemistry', 'Mathematics']) {
      expect(set.where((q) => q.subject == s).length, 25, reason: s);
    }
  });

  test('full mock with a subject chosen gives that subject its share', () async {
    expect((await run(db, subject: 'Physics', length: kFullMockLength)).length, 45);
  });

  test('the same length twice gives different questions', () async {
    // Without the shuffle, a length cap would turn a 200-question bank into the
    // same fixed 25 every single time.
    final a = (await run(db, subject: 'Physics', length: 25, seedVal: 1))
        .map((q) => q.id).toList();
    final b = (await run(db, subject: 'Physics', length: 25, seedVal: 2))
        .map((q) => q.id).toList();
    expect(a, isNot(equals(b)));
  });
}
