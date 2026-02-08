import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Questions extends Table {
  TextColumn get id => text()();
  TextColumn get examName => text()();
  IntColumn get year => integer()();
  TextColumn get subject => text()();
  TextColumn get topic => text()();
  TextColumn get difficulty => text()();
  TextColumn get questionLatex => text()();
  TextColumn get questionSvg => text().nullable()();
  TextColumn get optionsJson => text()();
  TextColumn get answerKey => text().nullable()();
  TextColumn get solution => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PracticeSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startTime => dateTime()();
  IntColumn get durationSeconds => integer()();
  IntColumn get totalQuestions => integer()();
  IntColumn get correctCount => integer()();
  IntColumn get wrongCount => integer()();
  IntColumn get skippedCount => integer()();
}

class SessionAnswers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(PracticeSessions, #id)();
  TextColumn get questionId => text()();
  TextColumn get selectedOption => text().nullable()();
  BoolColumn get isCorrect => boolean()();
}

class Mistakes extends Table {
  TextColumn get questionId => text().references(Questions, #id)();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {questionId};
}

@DriftDatabase(tables: [Questions, PracticeSessions, SessionAnswers, Mistakes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(questions, questions.questionSvg);
        await m.addColumn(questions, questions.solution);
      }
      if (from < 3) {
        await m.createTable(practiceSessions);
        await m.createTable(sessionAnswers);
      }
      if (from < 4) {
        await m.createTable(mistakes);
      }
    },
  );

  Future<void> addMistake(String qId) {
    return into(mistakes).insert(
      MistakesCompanion.insert(questionId: qId, addedAt: DateTime.now()),
      mode: InsertMode.insertOrReplace,
    );
  }

  Stream<List<Question>> watchMistakeQuestions() {
    final query = select(questions).join([
      innerJoin(mistakes, mistakes.questionId.equalsExp(questions.id)),
    ])..orderBy([OrderingTerm.desc(mistakes.addedAt)]);

    return query.map((row) => row.readTable(questions)).watch();
  }

  Stream<bool> watchIsMistake(String qId) {
    return (selectOnly(mistakes)
          ..addColumns([mistakes.questionId])
          ..where(mistakes.questionId.equals(qId)))
        .watch()
        .map((rows) => rows.isNotEmpty);
  }

  Future<void> removeMistake(String qId) {
    return (delete(mistakes)..where((t) => t.questionId.equals(qId))).go();
  }

  Future<bool> isMistake(String qId) async {
    final count =
        await (selectOnly(mistakes)
              ..addColumns([mistakes.questionId])
              ..where(mistakes.questionId.equals(qId)))
            .get();
    return count.isNotEmpty;
  }

  Future<List<Question>> getMistakeQuestions() {
    final query = select(questions).join([
      innerJoin(mistakes, mistakes.questionId.equalsExp(questions.id)),
    ])..orderBy([OrderingTerm.desc(mistakes.addedAt)]);

    return query.map((row) => row.readTable(questions)).get();
  }

  Future<int> saveSession(
    PracticeSessionsCompanion session,
    List<SessionAnswersCompanion> answers,
  ) async {
    return transaction(() async {
      final sessionId = await into(practiceSessions).insert(session);
      for (var answer in answers) {
        await into(
          sessionAnswers,
        ).insert(answer.copyWith(sessionId: Value(sessionId)));
      }
      return sessionId;
    });
  }

  Future<List<PracticeSession>> getAllSessions() {
    return (select(practiceSessions)..orderBy([
          (t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.desc),
        ]))
        .get();
  }

  Future<List<QuestionWithAnswer>> getSessionDetails(int sessionId) async {
    final query = select(sessionAnswers).join([
      innerJoin(questions, questions.id.equalsExp(sessionAnswers.questionId)),
    ])..where(sessionAnswers.sessionId.equals(sessionId));

    final rows = await query.get();

    return rows.map((row) {
      return QuestionWithAnswer(
        question: row.readTable(questions),
        answer: row.readTable(sessionAnswers),
      );
    }).toList();
  }

  Future<List<Question>> getCustomQuestions({
    List<int>? years,
    List<String>? subjects,
    List<String>? topics,
    int limit = 500,
  }) {
    return (select(questions)
          ..where((t) {
            final List<Expression<bool>> predicates = [];
            if (years != null && years.isNotEmpty)
              predicates.add(t.year.isIn(years));
            if (subjects != null && subjects.isNotEmpty)
              predicates.add(t.subject.isIn(subjects));
            if (topics != null && topics.isNotEmpty)
              predicates.add(t.topic.isIn(topics));
            return predicates.isEmpty
                ? const Constant(true)
                : Expression.and(predicates);
          })
          ..limit(limit))
        .get();
  }

  Future<List<int>> getAvailableYears() async {
    final query = selectOnly(questions, distinct: true)
      ..addColumns([questions.year]);
    final result = await query.map((row) => row.read(questions.year)!).get();
    result.sort();
    return result;
  }

  Future<List<String>> getAvailableTopics(String? subject) async {
    final query = selectOnly(questions, distinct: true)
      ..addColumns([questions.topic]);
    if (subject != null) query.where(questions.subject.equals(subject));
    final result = await query.map((row) => row.read(questions.topic)!).get();
    result.sort();
    return result;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'questions_v4.sqlite'));
    return NativeDatabase(file);
  });
}

class QuestionWithAnswer {
  final Question question;
  final SessionAnswer answer;
  QuestionWithAnswer({required this.question, required this.answer});
}
