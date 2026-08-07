import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/data/cross_exam_topics.dart';
import 'package:questionx/database.dart';

/// Behaviour of the cross-exam practice query.
///
/// The risk this guards is contamination: a JEE row matching on a NEET topic
/// name, or a Biology session pulling Chemistry questions. Both would show a
/// student off-syllabus material with no signal that anything is wrong.

Future<void> add(
  AppDatabase db, {
  required String id,
  required String exam,
  required String subject,
  required String topic,
  int year = 2023,
}) =>
    db.into(db.questions).insert(QuestionsCompanion.insert(
          id: id,
          examName: exam,
          subject: subject,
          topic: topic,
          difficulty: 'Medium',
          questionLatex: 'stem $id',
          optionsJson: '[]',
          year: year,
        ));

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // NEET names its topic "Thermodynamics"; JEE calls the same syllabus
    // "Heat And Thermodynamics".
    await add(db, id: 'n1', exam: 'NEET', subject: 'Physics', topic: 'Thermodynamics');
    await add(db, id: 'n2', exam: 'NEET', subject: 'Physics', topic: 'Gravitation');
    await add(db, id: 'j1', exam: 'JEE Main', subject: 'Physics', topic: 'Heat And Thermodynamics');
    await add(db, id: 'j2', exam: 'JEE Advanced', subject: 'Physics', topic: 'Heat And Thermodynamics');
    await add(db, id: 'j3', exam: 'JEE Main', subject: 'Physics', topic: 'Gravitation');
    await add(db, id: 'b1', exam: 'NEET', subject: 'Biology', topic: 'Biomolecules');
    await add(db, id: 'c1', exam: 'JEE Main', subject: 'Chemistry', topic: 'Biomolecules');
  });
  tearDown(() => db.close());

  Future<List<String>> ids({
    List<String>? topics,
    List<String>? cross,
    List<String>? subjects,
    String exam = 'NEET',
  }) async {
    final rows = await db.getCustomQuestions(
      examName: exam,
      topics: topics,
      crossExamTopics: cross,
      subjects: subjects,
    );
    return rows.map((r) => r.id).toList()..sort();
  }

  test('off: NEET only, unchanged behaviour', () async {
    expect(await ids(topics: ['Thermodynamics']), ['n1']);
  });

  test('on: adds the mapped JEE questions, both Main and Advanced', () async {
    expect(
      await ids(topics: ['Thermodynamics'], cross: ['Heat And Thermodynamics']),
      ['j1', 'j2', 'n1'],
    );
  });

  test('a JEE row must match a MAPPED topic, not the NEET topic name', () async {
    // 'Gravitation' is spelled identically in both banks. Selecting only
    // Thermodynamics must not drag in the Gravitation rows from either side.
    final got =
        await ids(topics: ['Thermodynamics'], cross: ['Heat And Thermodynamics']);
    expect(got, isNot(contains('j3')));
    expect(got, isNot(contains('n2')));
  });

  test('the subject filter still applies to the JEE side', () async {
    final got = await ids(
      topics: ['Thermodynamics'],
      cross: ['Heat And Thermodynamics'],
      subjects: ['Physics'],
    );
    expect(got, ['j1', 'j2', 'n1']);
    expect(got, isNot(contains('c1')));
  });

  test('a Biology session pulls nothing, even on a shared topic name', () async {
    // 'Biomolecules' exists in NEET Biology and JEE Chemistry.
    final cross = jeeTopicsFor(['Biomolecules'], 'Biology');
    expect(cross, isEmpty);
    final got = await ids(
        topics: ['Biomolecules'], cross: cross, subjects: ['Biology']);
    expect(got, ['b1']);
  });

  test('empty cross list behaves exactly like the flag being off', () async {
    expect(await ids(topics: ['Thermodynamics'], cross: const []),
        await ids(topics: ['Thermodynamics']));
  });

  test('no topic selected still scopes to the exam', () async {
    final got = await ids();
    expect(got, ['b1', 'n1', 'n2']);
  });
}
