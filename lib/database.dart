import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

@TableIndex(name: 'questions_index', columns: {#examName, #subject, #topic})
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
  TextColumn get solutionSvg => text().nullable()();

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
  IntColumn get timeSpent => integer().withDefault(const Constant(0))();
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

  /// In-memory instance for tests, so query logic can be exercised without
  /// touching the on-device database file.
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

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
      if (from < 5) {
        // Add timeSpent column
        await m.addColumn(sessionAnswers, sessionAnswers.timeSpent);

        // Add the Performance Index
        await m.createIndex(
          Index(
            'questions_index',
            "CREATE INDEX questions_index ON questions (exam_name, subject, topic)",
          ),
        );
      }
      if (from < 6) {
        await m.addColumn(questions, questions.solutionSvg);
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
    String? examName,
    List<int>? years,
    List<String>? subjects,
    List<String>? topics,
    int limit = 500,
  }) async {
    final rows = await (select(questions)
          ..where((t) {
            final List<Expression<bool>> predicates = [];
            if (examName != null) {
              predicates.add(t.examName.like('$examName%'));
            }
            if (years != null && years.isNotEmpty) {
              predicates.add(t.year.isIn(years));
            }
            if (subjects != null && subjects.isNotEmpty) {
              predicates.add(t.subject.isIn(subjects));
            }
            if (topics != null && topics.isNotEmpty) {
              predicates.add(t.topic.isIn(topics));
            }
            return predicates.isEmpty
                ? const Constant(true)
                : Expression.and(predicates);
          })
          ..limit(limit))
        .get();
    return _dedupeByContent(rows);
  }

  // Collapses content-identical duplicates (Set-A/Set-B paper variants and
  // intra-paper repeats) so practice sessions never show the same question
  // twice. First occurrence wins. See AUDIT_PROGRESS.json session_13_summary.
  List<Question> _dedupeByContent(List<Question> qs) {
    final seen = <String>{};
    final out = <Question>[];
    for (final q in qs) {
      final fp = _contentFingerprint(q);
      if (seen.add(fp)) out.add(q);
    }
    return out;
  }

  static final RegExp _reDollar = RegExp(r'\$+');
  static final RegExp _reLatexDelim = RegExp(r'\\\(|\\\)|\\\[|\\\]');
  static final RegExp _reLatexCmd = RegExp(r'\\[a-zA-Z]+\*?');
  static final RegExp _reBraces = RegExp(r'[{}~]');
  static final RegExp _reArrow = RegExp(r'[→⟶←⇐⇒⇌]');
  static final RegExp _reNonAlnum =
      RegExp(r'[^a-z0-9\s\-\+\=/\.\^]');
  static final RegExp _reWs = RegExp(r'\s+');

  static String _normalize(String s) {
    var t = s.toLowerCase();
    t = t.replaceAll(_reDollar, ' ');
    t = t.replaceAll(_reLatexDelim, ' ');
    t = t.replaceAll(_reArrow, ' ');
    t = t.replaceAll(_reLatexCmd, ' ');
    t = t.replaceAll(_reBraces, ' ');
    t = t.replaceAll(_reNonAlnum, ' ');
    t = t.replaceAll(_reWs, ' ').trim();
    return t;
  }

  String _contentFingerprint(Question q) {
    final stem = _normalize(q.questionLatex);
    final raw = jsonDecode(q.optionsJson);
    final List<String> opts;
    if (raw is List) {
      opts = raw.map((e) => _normalize(e.toString())).toList();
    } else if (raw is Map) {
      final keys = raw.keys.map((k) => k.toString()).toList()..sort();
      opts = keys.map((k) => _normalize(raw[k].toString())).toList();
    } else {
      opts = const [];
    }
    opts.sort();
    return '$stem || ${opts.where((o) => o.isNotEmpty).join(' | ')}';
  }

  Future<List<Question>> searchQuestions({
    required String examName,
    required String subject,
    String? search,
    int limit = 500,
  }) {
    final q = select(questions)
      ..where((t) => t.examName.like('$examName%'))
      ..where((t) => t.subject.equals(subject));
    if (search != null && search.isNotEmpty) {
      final like = '%$search%';
      q.where((t) => t.questionLatex.like(like) | t.topic.like(like));
    }
    q.limit(limit);
    return q.get();
  }

  /// Global lookup by question ID — deliberately IGNORES exam/subject scope so a
  /// question ID pasted from a bug report (e.g. `JEE_Main_2020_Jan07_S2_Phy_22`)
  /// resolves from any bank, regardless of which tab is open. Substring match so
  /// a partial ID still narrows down. See [looksLikeQuestionId].
  Future<List<Question>> findByIdFragment(String fragment, {int limit = 50}) {
    final f = fragment.trim();
    final q = select(questions)
      ..where((t) => t.id.like('%$f%'))
      ..orderBy([(t) => OrderingTerm(expression: t.id)])
      ..limit(limit);
    return q.get();
  }

  /// Wipe the entire questions table. Called at the start of an OTA sync so
  /// that records DROPPED in the new release stop appearing to the user
  /// (insertOrReplace would only touch IDs present in the new payload).
  Future<void> deleteAllQuestions() async {
    await delete(questions).go();
  }

  Future<int> countQuestions() async {
    final exp = questions.id.count();
    final query = selectOnly(questions)..addColumns([exp]);
    final row = await query.getSingle();
    return row.read(exp) ?? 0;
  }

  /// A sample of diagram filenames the bank references, spread across exams.
  ///
  /// SyncService checks these against the files actually on disk to decide
  /// whether the diagram set is intact. Stratifying by exam is the point: a
  /// broken `data.zip` typically loses one whole family (v1.7.4 shipped every
  /// JEE figure and no NEET one), and a flat sample of 4,348 references is
  /// ~97% JEE, so it would almost always miss that.
  ///
  /// Legacy inline `<svg>` blobs are excluded — they render from the record and
  /// need no file on disk.
  Future<List<String>> sampleDiagramFilenames({int perExam = 25}) async {
    final exams = await (selectOnly(questions, distinct: true)
          ..addColumns([questions.examName]))
        .map((r) => r.read(questions.examName))
        .get();

    final out = <String>[];
    for (final exam in exams.whereType<String>()) {
      final rows = await (selectOnly(questions, distinct: true)
            ..addColumns([questions.questionSvg])
            ..where(questions.examName.equals(exam) &
                questions.questionSvg.isNotNull() &
                questions.questionSvg.isNotValue('') &
                questions.questionSvg.like('<%').not())
            ..limit(perExam))
          .map((r) => r.read(questions.questionSvg))
          .get();
      out.addAll(rows.whereType<String>());
    }
    return out;
  }

  /// Count rows whose `examName` matches the given label (LIKE semantics, same
  /// shape as the filter used by [searchQuestions]). Used for the exam-card
  /// Q-count badges on the home screen.
  Future<int> countQuestionsByExam(String examName) async {
    final exp = questions.id.count();
    final query = selectOnly(questions)
      ..addColumns([exp])
      ..where(questions.examName.like('$examName%'));
    final row = await query.getSingle();
    return row.read(exp) ?? 0;
  }

  /// Count rows matching an arbitrary filter set — mirrors getCustomQuestions
  /// but returns only the count, for the live "X questions match" indicator.
  Future<int> countCustomQuestions({
    String? examName,
    List<int> years = const [],
    List<String>? subjects,
    List<String> topics = const [],
  }) async {
    final exp = questions.id.count();
    final query = selectOnly(questions)..addColumns([exp]);
    final filters = <Expression<bool>>[];
    if (examName != null) filters.add(questions.examName.like('$examName%'));
    if (years.isNotEmpty) filters.add(questions.year.isIn(years));
    if (subjects != null && subjects.isNotEmpty) {
      filters.add(questions.subject.isIn(subjects));
    }
    if (topics.isNotEmpty) filters.add(questions.topic.isIn(topics));
    if (filters.isNotEmpty) query.where(Expression.and(filters));
    final row = await query.getSingle();
    return row.read(exp) ?? 0;
  }

  Future<({int total, List<String> exams, List<String> subjects})>
      getDbStats() async {
    final total = await countQuestions();
    final examQuery = selectOnly(questions, distinct: true)
      ..addColumns([questions.examName]);
    final exams =
        await examQuery.map((r) => r.read(questions.examName)!).get();
    final subjectQuery = selectOnly(questions, distinct: true)
      ..addColumns([questions.subject]);
    final subjects =
        await subjectQuery.map((r) => r.read(questions.subject)!).get();
    return (total: total, exams: exams, subjects: subjects);
  }

  Future<List<int>> getAvailableYears({String? examName}) async {
    final query = selectOnly(questions, distinct: true)
      ..addColumns([questions.year]);
    if (examName != null) {
      query.where(questions.examName.like('$examName%'));
    }
    final result = await query.map((row) => row.read(questions.year)!).get();
    result.sort();
    return result;
  }

  Future<List<String>> getAvailableTopics(
    String? subject, {
    String? examName,
  }) async {
    final query = selectOnly(questions, distinct: true)
      ..addColumns([questions.topic]);
    final filters = <Expression<bool>>[];
    if (subject != null) filters.add(questions.subject.equals(subject));
    if (examName != null) filters.add(questions.examName.like('$examName%'));
    if (filters.isNotEmpty) query.where(Expression.and(filters));
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

/// Heuristic: does [term] look like a question ID rather than free-text search?
/// Every bank ID begins with an exam token + underscore
/// (`JEE_Main_…`, `JEE_Adv_…`, `NEET_…`, `AIPMT_…`, `CBSE_…`), so we match that
/// prefix scheme. Used by the home search to switch a pasted ID into a global
/// [AppDatabase.findByIdFragment] lookup. Kept pure + top-level so it's unit
/// testable without the DB or widgets.
bool looksLikeQuestionId(String term) {
  final t = term.trim().toUpperCase();
  if (t.isEmpty || t.contains(' ')) return false;
  const prefixes = ['JEE_MAIN_', 'JEE_ADV_', 'NEET_', 'AIPMT_', 'CBSE_'];
  return prefixes.any(t.startsWith);
}
