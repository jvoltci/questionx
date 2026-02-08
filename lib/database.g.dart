// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $QuestionsTable extends Questions
    with TableInfo<$QuestionsTable, Question> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _examNameMeta = const VerificationMeta(
    'examName',
  );
  @override
  late final GeneratedColumn<String> examName = GeneratedColumn<String>(
    'exam_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionLatexMeta = const VerificationMeta(
    'questionLatex',
  );
  @override
  late final GeneratedColumn<String> questionLatex = GeneratedColumn<String>(
    'question_latex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionSvgMeta = const VerificationMeta(
    'questionSvg',
  );
  @override
  late final GeneratedColumn<String> questionSvg = GeneratedColumn<String>(
    'question_svg',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta(
    'optionsJson',
  );
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerKeyMeta = const VerificationMeta(
    'answerKey',
  );
  @override
  late final GeneratedColumn<String> answerKey = GeneratedColumn<String>(
    'answer_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _solutionMeta = const VerificationMeta(
    'solution',
  );
  @override
  late final GeneratedColumn<String> solution = GeneratedColumn<String>(
    'solution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    examName,
    year,
    subject,
    topic,
    difficulty,
    questionLatex,
    questionSvg,
    optionsJson,
    answerKey,
    solution,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Question> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exam_name')) {
      context.handle(
        _examNameMeta,
        examName.isAcceptableOrUnknown(data['exam_name']!, _examNameMeta),
      );
    } else if (isInserting) {
      context.missing(_examNameMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('topic')) {
      context.handle(
        _topicMeta,
        topic.isAcceptableOrUnknown(data['topic']!, _topicMeta),
      );
    } else if (isInserting) {
      context.missing(_topicMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('question_latex')) {
      context.handle(
        _questionLatexMeta,
        questionLatex.isAcceptableOrUnknown(
          data['question_latex']!,
          _questionLatexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionLatexMeta);
    }
    if (data.containsKey('question_svg')) {
      context.handle(
        _questionSvgMeta,
        questionSvg.isAcceptableOrUnknown(
          data['question_svg']!,
          _questionSvgMeta,
        ),
      );
    }
    if (data.containsKey('options_json')) {
      context.handle(
        _optionsJsonMeta,
        optionsJson.isAcceptableOrUnknown(
          data['options_json']!,
          _optionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_optionsJsonMeta);
    }
    if (data.containsKey('answer_key')) {
      context.handle(
        _answerKeyMeta,
        answerKey.isAcceptableOrUnknown(data['answer_key']!, _answerKeyMeta),
      );
    }
    if (data.containsKey('solution')) {
      context.handle(
        _solutionMeta,
        solution.isAcceptableOrUnknown(data['solution']!, _solutionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Question map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Question(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      examName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_name'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty'],
      )!,
      questionLatex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_latex'],
      )!,
      questionSvg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_svg'],
      ),
      optionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_json'],
      )!,
      answerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_key'],
      ),
      solution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}solution'],
      ),
    );
  }

  @override
  $QuestionsTable createAlias(String alias) {
    return $QuestionsTable(attachedDatabase, alias);
  }
}

class Question extends DataClass implements Insertable<Question> {
  final String id;
  final String examName;
  final int year;
  final String subject;
  final String topic;
  final String difficulty;
  final String questionLatex;
  final String? questionSvg;
  final String optionsJson;
  final String? answerKey;
  final String? solution;
  const Question({
    required this.id,
    required this.examName,
    required this.year,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.questionLatex,
    this.questionSvg,
    required this.optionsJson,
    this.answerKey,
    this.solution,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exam_name'] = Variable<String>(examName);
    map['year'] = Variable<int>(year);
    map['subject'] = Variable<String>(subject);
    map['topic'] = Variable<String>(topic);
    map['difficulty'] = Variable<String>(difficulty);
    map['question_latex'] = Variable<String>(questionLatex);
    if (!nullToAbsent || questionSvg != null) {
      map['question_svg'] = Variable<String>(questionSvg);
    }
    map['options_json'] = Variable<String>(optionsJson);
    if (!nullToAbsent || answerKey != null) {
      map['answer_key'] = Variable<String>(answerKey);
    }
    if (!nullToAbsent || solution != null) {
      map['solution'] = Variable<String>(solution);
    }
    return map;
  }

  QuestionsCompanion toCompanion(bool nullToAbsent) {
    return QuestionsCompanion(
      id: Value(id),
      examName: Value(examName),
      year: Value(year),
      subject: Value(subject),
      topic: Value(topic),
      difficulty: Value(difficulty),
      questionLatex: Value(questionLatex),
      questionSvg: questionSvg == null && nullToAbsent
          ? const Value.absent()
          : Value(questionSvg),
      optionsJson: Value(optionsJson),
      answerKey: answerKey == null && nullToAbsent
          ? const Value.absent()
          : Value(answerKey),
      solution: solution == null && nullToAbsent
          ? const Value.absent()
          : Value(solution),
    );
  }

  factory Question.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Question(
      id: serializer.fromJson<String>(json['id']),
      examName: serializer.fromJson<String>(json['examName']),
      year: serializer.fromJson<int>(json['year']),
      subject: serializer.fromJson<String>(json['subject']),
      topic: serializer.fromJson<String>(json['topic']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      questionLatex: serializer.fromJson<String>(json['questionLatex']),
      questionSvg: serializer.fromJson<String?>(json['questionSvg']),
      optionsJson: serializer.fromJson<String>(json['optionsJson']),
      answerKey: serializer.fromJson<String?>(json['answerKey']),
      solution: serializer.fromJson<String?>(json['solution']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'examName': serializer.toJson<String>(examName),
      'year': serializer.toJson<int>(year),
      'subject': serializer.toJson<String>(subject),
      'topic': serializer.toJson<String>(topic),
      'difficulty': serializer.toJson<String>(difficulty),
      'questionLatex': serializer.toJson<String>(questionLatex),
      'questionSvg': serializer.toJson<String?>(questionSvg),
      'optionsJson': serializer.toJson<String>(optionsJson),
      'answerKey': serializer.toJson<String?>(answerKey),
      'solution': serializer.toJson<String?>(solution),
    };
  }

  Question copyWith({
    String? id,
    String? examName,
    int? year,
    String? subject,
    String? topic,
    String? difficulty,
    String? questionLatex,
    Value<String?> questionSvg = const Value.absent(),
    String? optionsJson,
    Value<String?> answerKey = const Value.absent(),
    Value<String?> solution = const Value.absent(),
  }) => Question(
    id: id ?? this.id,
    examName: examName ?? this.examName,
    year: year ?? this.year,
    subject: subject ?? this.subject,
    topic: topic ?? this.topic,
    difficulty: difficulty ?? this.difficulty,
    questionLatex: questionLatex ?? this.questionLatex,
    questionSvg: questionSvg.present ? questionSvg.value : this.questionSvg,
    optionsJson: optionsJson ?? this.optionsJson,
    answerKey: answerKey.present ? answerKey.value : this.answerKey,
    solution: solution.present ? solution.value : this.solution,
  );
  Question copyWithCompanion(QuestionsCompanion data) {
    return Question(
      id: data.id.present ? data.id.value : this.id,
      examName: data.examName.present ? data.examName.value : this.examName,
      year: data.year.present ? data.year.value : this.year,
      subject: data.subject.present ? data.subject.value : this.subject,
      topic: data.topic.present ? data.topic.value : this.topic,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      questionLatex: data.questionLatex.present
          ? data.questionLatex.value
          : this.questionLatex,
      questionSvg: data.questionSvg.present
          ? data.questionSvg.value
          : this.questionSvg,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
      answerKey: data.answerKey.present ? data.answerKey.value : this.answerKey,
      solution: data.solution.present ? data.solution.value : this.solution,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Question(')
          ..write('id: $id, ')
          ..write('examName: $examName, ')
          ..write('year: $year, ')
          ..write('subject: $subject, ')
          ..write('topic: $topic, ')
          ..write('difficulty: $difficulty, ')
          ..write('questionLatex: $questionLatex, ')
          ..write('questionSvg: $questionSvg, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('answerKey: $answerKey, ')
          ..write('solution: $solution')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    examName,
    year,
    subject,
    topic,
    difficulty,
    questionLatex,
    questionSvg,
    optionsJson,
    answerKey,
    solution,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Question &&
          other.id == this.id &&
          other.examName == this.examName &&
          other.year == this.year &&
          other.subject == this.subject &&
          other.topic == this.topic &&
          other.difficulty == this.difficulty &&
          other.questionLatex == this.questionLatex &&
          other.questionSvg == this.questionSvg &&
          other.optionsJson == this.optionsJson &&
          other.answerKey == this.answerKey &&
          other.solution == this.solution);
}

class QuestionsCompanion extends UpdateCompanion<Question> {
  final Value<String> id;
  final Value<String> examName;
  final Value<int> year;
  final Value<String> subject;
  final Value<String> topic;
  final Value<String> difficulty;
  final Value<String> questionLatex;
  final Value<String?> questionSvg;
  final Value<String> optionsJson;
  final Value<String?> answerKey;
  final Value<String?> solution;
  final Value<int> rowid;
  const QuestionsCompanion({
    this.id = const Value.absent(),
    this.examName = const Value.absent(),
    this.year = const Value.absent(),
    this.subject = const Value.absent(),
    this.topic = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.questionLatex = const Value.absent(),
    this.questionSvg = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.answerKey = const Value.absent(),
    this.solution = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuestionsCompanion.insert({
    required String id,
    required String examName,
    required int year,
    required String subject,
    required String topic,
    required String difficulty,
    required String questionLatex,
    this.questionSvg = const Value.absent(),
    required String optionsJson,
    this.answerKey = const Value.absent(),
    this.solution = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       examName = Value(examName),
       year = Value(year),
       subject = Value(subject),
       topic = Value(topic),
       difficulty = Value(difficulty),
       questionLatex = Value(questionLatex),
       optionsJson = Value(optionsJson);
  static Insertable<Question> custom({
    Expression<String>? id,
    Expression<String>? examName,
    Expression<int>? year,
    Expression<String>? subject,
    Expression<String>? topic,
    Expression<String>? difficulty,
    Expression<String>? questionLatex,
    Expression<String>? questionSvg,
    Expression<String>? optionsJson,
    Expression<String>? answerKey,
    Expression<String>? solution,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (examName != null) 'exam_name': examName,
      if (year != null) 'year': year,
      if (subject != null) 'subject': subject,
      if (topic != null) 'topic': topic,
      if (difficulty != null) 'difficulty': difficulty,
      if (questionLatex != null) 'question_latex': questionLatex,
      if (questionSvg != null) 'question_svg': questionSvg,
      if (optionsJson != null) 'options_json': optionsJson,
      if (answerKey != null) 'answer_key': answerKey,
      if (solution != null) 'solution': solution,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuestionsCompanion copyWith({
    Value<String>? id,
    Value<String>? examName,
    Value<int>? year,
    Value<String>? subject,
    Value<String>? topic,
    Value<String>? difficulty,
    Value<String>? questionLatex,
    Value<String?>? questionSvg,
    Value<String>? optionsJson,
    Value<String?>? answerKey,
    Value<String?>? solution,
    Value<int>? rowid,
  }) {
    return QuestionsCompanion(
      id: id ?? this.id,
      examName: examName ?? this.examName,
      year: year ?? this.year,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      questionLatex: questionLatex ?? this.questionLatex,
      questionSvg: questionSvg ?? this.questionSvg,
      optionsJson: optionsJson ?? this.optionsJson,
      answerKey: answerKey ?? this.answerKey,
      solution: solution ?? this.solution,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (examName.present) {
      map['exam_name'] = Variable<String>(examName.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (questionLatex.present) {
      map['question_latex'] = Variable<String>(questionLatex.value);
    }
    if (questionSvg.present) {
      map['question_svg'] = Variable<String>(questionSvg.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (answerKey.present) {
      map['answer_key'] = Variable<String>(answerKey.value);
    }
    if (solution.present) {
      map['solution'] = Variable<String>(solution.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestionsCompanion(')
          ..write('id: $id, ')
          ..write('examName: $examName, ')
          ..write('year: $year, ')
          ..write('subject: $subject, ')
          ..write('topic: $topic, ')
          ..write('difficulty: $difficulty, ')
          ..write('questionLatex: $questionLatex, ')
          ..write('questionSvg: $questionSvg, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('answerKey: $answerKey, ')
          ..write('solution: $solution, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeSessionsTable extends PracticeSessions
    with TableInfo<$PracticeSessionsTable, PracticeSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalQuestionsMeta = const VerificationMeta(
    'totalQuestions',
  );
  @override
  late final GeneratedColumn<int> totalQuestions = GeneratedColumn<int>(
    'total_questions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrongCountMeta = const VerificationMeta(
    'wrongCount',
  );
  @override
  late final GeneratedColumn<int> wrongCount = GeneratedColumn<int>(
    'wrong_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skippedCountMeta = const VerificationMeta(
    'skippedCount',
  );
  @override
  late final GeneratedColumn<int> skippedCount = GeneratedColumn<int>(
    'skipped_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startTime,
    durationSeconds,
    totalQuestions,
    correctCount,
    wrongCount,
    skippedCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('total_questions')) {
      context.handle(
        _totalQuestionsMeta,
        totalQuestions.isAcceptableOrUnknown(
          data['total_questions']!,
          _totalQuestionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalQuestionsMeta);
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctCountMeta);
    }
    if (data.containsKey('wrong_count')) {
      context.handle(
        _wrongCountMeta,
        wrongCount.isAcceptableOrUnknown(data['wrong_count']!, _wrongCountMeta),
      );
    } else if (isInserting) {
      context.missing(_wrongCountMeta);
    }
    if (data.containsKey('skipped_count')) {
      context.handle(
        _skippedCountMeta,
        skippedCount.isAcceptableOrUnknown(
          data['skipped_count']!,
          _skippedCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_skippedCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      totalQuestions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_questions'],
      )!,
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      )!,
      wrongCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wrong_count'],
      )!,
      skippedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skipped_count'],
      )!,
    );
  }

  @override
  $PracticeSessionsTable createAlias(String alias) {
    return $PracticeSessionsTable(attachedDatabase, alias);
  }
}

class PracticeSession extends DataClass implements Insertable<PracticeSession> {
  final int id;
  final DateTime startTime;
  final int durationSeconds;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  const PracticeSession({
    required this.id,
    required this.startTime,
    required this.durationSeconds,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.skippedCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start_time'] = Variable<DateTime>(startTime);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['total_questions'] = Variable<int>(totalQuestions);
    map['correct_count'] = Variable<int>(correctCount);
    map['wrong_count'] = Variable<int>(wrongCount);
    map['skipped_count'] = Variable<int>(skippedCount);
    return map;
  }

  PracticeSessionsCompanion toCompanion(bool nullToAbsent) {
    return PracticeSessionsCompanion(
      id: Value(id),
      startTime: Value(startTime),
      durationSeconds: Value(durationSeconds),
      totalQuestions: Value(totalQuestions),
      correctCount: Value(correctCount),
      wrongCount: Value(wrongCount),
      skippedCount: Value(skippedCount),
    );
  }

  factory PracticeSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeSession(
      id: serializer.fromJson<int>(json['id']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      totalQuestions: serializer.fromJson<int>(json['totalQuestions']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      wrongCount: serializer.fromJson<int>(json['wrongCount']),
      skippedCount: serializer.fromJson<int>(json['skippedCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startTime': serializer.toJson<DateTime>(startTime),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'totalQuestions': serializer.toJson<int>(totalQuestions),
      'correctCount': serializer.toJson<int>(correctCount),
      'wrongCount': serializer.toJson<int>(wrongCount),
      'skippedCount': serializer.toJson<int>(skippedCount),
    };
  }

  PracticeSession copyWith({
    int? id,
    DateTime? startTime,
    int? durationSeconds,
    int? totalQuestions,
    int? correctCount,
    int? wrongCount,
    int? skippedCount,
  }) => PracticeSession(
    id: id ?? this.id,
    startTime: startTime ?? this.startTime,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    totalQuestions: totalQuestions ?? this.totalQuestions,
    correctCount: correctCount ?? this.correctCount,
    wrongCount: wrongCount ?? this.wrongCount,
    skippedCount: skippedCount ?? this.skippedCount,
  );
  PracticeSession copyWithCompanion(PracticeSessionsCompanion data) {
    return PracticeSession(
      id: data.id.present ? data.id.value : this.id,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      totalQuestions: data.totalQuestions.present
          ? data.totalQuestions.value
          : this.totalQuestions,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      wrongCount: data.wrongCount.present
          ? data.wrongCount.value
          : this.wrongCount,
      skippedCount: data.skippedCount.present
          ? data.skippedCount.value
          : this.skippedCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSession(')
          ..write('id: $id, ')
          ..write('startTime: $startTime, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('totalQuestions: $totalQuestions, ')
          ..write('correctCount: $correctCount, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('skippedCount: $skippedCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startTime,
    durationSeconds,
    totalQuestions,
    correctCount,
    wrongCount,
    skippedCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeSession &&
          other.id == this.id &&
          other.startTime == this.startTime &&
          other.durationSeconds == this.durationSeconds &&
          other.totalQuestions == this.totalQuestions &&
          other.correctCount == this.correctCount &&
          other.wrongCount == this.wrongCount &&
          other.skippedCount == this.skippedCount);
}

class PracticeSessionsCompanion extends UpdateCompanion<PracticeSession> {
  final Value<int> id;
  final Value<DateTime> startTime;
  final Value<int> durationSeconds;
  final Value<int> totalQuestions;
  final Value<int> correctCount;
  final Value<int> wrongCount;
  final Value<int> skippedCount;
  const PracticeSessionsCompanion({
    this.id = const Value.absent(),
    this.startTime = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.totalQuestions = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.skippedCount = const Value.absent(),
  });
  PracticeSessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startTime,
    required int durationSeconds,
    required int totalQuestions,
    required int correctCount,
    required int wrongCount,
    required int skippedCount,
  }) : startTime = Value(startTime),
       durationSeconds = Value(durationSeconds),
       totalQuestions = Value(totalQuestions),
       correctCount = Value(correctCount),
       wrongCount = Value(wrongCount),
       skippedCount = Value(skippedCount);
  static Insertable<PracticeSession> custom({
    Expression<int>? id,
    Expression<DateTime>? startTime,
    Expression<int>? durationSeconds,
    Expression<int>? totalQuestions,
    Expression<int>? correctCount,
    Expression<int>? wrongCount,
    Expression<int>? skippedCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startTime != null) 'start_time': startTime,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (totalQuestions != null) 'total_questions': totalQuestions,
      if (correctCount != null) 'correct_count': correctCount,
      if (wrongCount != null) 'wrong_count': wrongCount,
      if (skippedCount != null) 'skipped_count': skippedCount,
    });
  }

  PracticeSessionsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startTime,
    Value<int>? durationSeconds,
    Value<int>? totalQuestions,
    Value<int>? correctCount,
    Value<int>? wrongCount,
    Value<int>? skippedCount,
  }) {
    return PracticeSessionsCompanion(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      skippedCount: skippedCount ?? this.skippedCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (totalQuestions.present) {
      map['total_questions'] = Variable<int>(totalQuestions.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (wrongCount.present) {
      map['wrong_count'] = Variable<int>(wrongCount.value);
    }
    if (skippedCount.present) {
      map['skipped_count'] = Variable<int>(skippedCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSessionsCompanion(')
          ..write('id: $id, ')
          ..write('startTime: $startTime, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('totalQuestions: $totalQuestions, ')
          ..write('correctCount: $correctCount, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('skippedCount: $skippedCount')
          ..write(')'))
        .toString();
  }
}

class $SessionAnswersTable extends SessionAnswers
    with TableInfo<$SessionAnswersTable, SessionAnswer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionAnswersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_sessions (id)',
    ),
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedOptionMeta = const VerificationMeta(
    'selectedOption',
  );
  @override
  late final GeneratedColumn<String> selectedOption = GeneratedColumn<String>(
    'selected_option',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCorrectMeta = const VerificationMeta(
    'isCorrect',
  );
  @override
  late final GeneratedColumn<bool> isCorrect = GeneratedColumn<bool>(
    'is_correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_correct" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    questionId,
    selectedOption,
    isCorrect,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_answers';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionAnswer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('selected_option')) {
      context.handle(
        _selectedOptionMeta,
        selectedOption.isAcceptableOrUnknown(
          data['selected_option']!,
          _selectedOptionMeta,
        ),
      );
    }
    if (data.containsKey('is_correct')) {
      context.handle(
        _isCorrectMeta,
        isCorrect.isAcceptableOrUnknown(data['is_correct']!, _isCorrectMeta),
      );
    } else if (isInserting) {
      context.missing(_isCorrectMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionAnswer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionAnswer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      selectedOption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_option'],
      ),
      isCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_correct'],
      )!,
    );
  }

  @override
  $SessionAnswersTable createAlias(String alias) {
    return $SessionAnswersTable(attachedDatabase, alias);
  }
}

class SessionAnswer extends DataClass implements Insertable<SessionAnswer> {
  final int id;
  final int sessionId;
  final String questionId;
  final String? selectedOption;
  final bool isCorrect;
  const SessionAnswer({
    required this.id,
    required this.sessionId,
    required this.questionId,
    this.selectedOption,
    required this.isCorrect,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['question_id'] = Variable<String>(questionId);
    if (!nullToAbsent || selectedOption != null) {
      map['selected_option'] = Variable<String>(selectedOption);
    }
    map['is_correct'] = Variable<bool>(isCorrect);
    return map;
  }

  SessionAnswersCompanion toCompanion(bool nullToAbsent) {
    return SessionAnswersCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      questionId: Value(questionId),
      selectedOption: selectedOption == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedOption),
      isCorrect: Value(isCorrect),
    );
  }

  factory SessionAnswer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionAnswer(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      questionId: serializer.fromJson<String>(json['questionId']),
      selectedOption: serializer.fromJson<String?>(json['selectedOption']),
      isCorrect: serializer.fromJson<bool>(json['isCorrect']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'questionId': serializer.toJson<String>(questionId),
      'selectedOption': serializer.toJson<String?>(selectedOption),
      'isCorrect': serializer.toJson<bool>(isCorrect),
    };
  }

  SessionAnswer copyWith({
    int? id,
    int? sessionId,
    String? questionId,
    Value<String?> selectedOption = const Value.absent(),
    bool? isCorrect,
  }) => SessionAnswer(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    questionId: questionId ?? this.questionId,
    selectedOption: selectedOption.present
        ? selectedOption.value
        : this.selectedOption,
    isCorrect: isCorrect ?? this.isCorrect,
  );
  SessionAnswer copyWithCompanion(SessionAnswersCompanion data) {
    return SessionAnswer(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      selectedOption: data.selectedOption.present
          ? data.selectedOption.value
          : this.selectedOption,
      isCorrect: data.isCorrect.present ? data.isCorrect.value : this.isCorrect,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionAnswer(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('selectedOption: $selectedOption, ')
          ..write('isCorrect: $isCorrect')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, questionId, selectedOption, isCorrect);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionAnswer &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.questionId == this.questionId &&
          other.selectedOption == this.selectedOption &&
          other.isCorrect == this.isCorrect);
}

class SessionAnswersCompanion extends UpdateCompanion<SessionAnswer> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> questionId;
  final Value<String?> selectedOption;
  final Value<bool> isCorrect;
  const SessionAnswersCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.questionId = const Value.absent(),
    this.selectedOption = const Value.absent(),
    this.isCorrect = const Value.absent(),
  });
  SessionAnswersCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String questionId,
    this.selectedOption = const Value.absent(),
    required bool isCorrect,
  }) : sessionId = Value(sessionId),
       questionId = Value(questionId),
       isCorrect = Value(isCorrect);
  static Insertable<SessionAnswer> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? questionId,
    Expression<String>? selectedOption,
    Expression<bool>? isCorrect,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (questionId != null) 'question_id': questionId,
      if (selectedOption != null) 'selected_option': selectedOption,
      if (isCorrect != null) 'is_correct': isCorrect,
    });
  }

  SessionAnswersCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<String>? questionId,
    Value<String?>? selectedOption,
    Value<bool>? isCorrect,
  }) {
    return SessionAnswersCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      questionId: questionId ?? this.questionId,
      selectedOption: selectedOption ?? this.selectedOption,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (selectedOption.present) {
      map['selected_option'] = Variable<String>(selectedOption.value);
    }
    if (isCorrect.present) {
      map['is_correct'] = Variable<bool>(isCorrect.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionAnswersCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('selectedOption: $selectedOption, ')
          ..write('isCorrect: $isCorrect')
          ..write(')'))
        .toString();
  }
}

class $MistakesTable extends Mistakes with TableInfo<$MistakesTable, Mistake> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MistakesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES questions (id)',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [questionId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mistakes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Mistake> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId};
  @override
  Mistake map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mistake(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $MistakesTable createAlias(String alias) {
    return $MistakesTable(attachedDatabase, alias);
  }
}

class Mistake extends DataClass implements Insertable<Mistake> {
  final String questionId;
  final DateTime addedAt;
  const Mistake({required this.questionId, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  MistakesCompanion toCompanion(bool nullToAbsent) {
    return MistakesCompanion(
      questionId: Value(questionId),
      addedAt: Value(addedAt),
    );
  }

  factory Mistake.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mistake(
      questionId: serializer.fromJson<String>(json['questionId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Mistake copyWith({String? questionId, DateTime? addedAt}) => Mistake(
    questionId: questionId ?? this.questionId,
    addedAt: addedAt ?? this.addedAt,
  );
  Mistake copyWithCompanion(MistakesCompanion data) {
    return Mistake(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mistake(')
          ..write('questionId: $questionId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(questionId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mistake &&
          other.questionId == this.questionId &&
          other.addedAt == this.addedAt);
}

class MistakesCompanion extends UpdateCompanion<Mistake> {
  final Value<String> questionId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const MistakesCompanion({
    this.questionId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MistakesCompanion.insert({
    required String questionId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId),
       addedAt = Value(addedAt);
  static Insertable<Mistake> custom({
    Expression<String>? questionId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MistakesCompanion copyWith({
    Value<String>? questionId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return MistakesCompanion(
      questionId: questionId ?? this.questionId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MistakesCompanion(')
          ..write('questionId: $questionId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $QuestionsTable questions = $QuestionsTable(this);
  late final $PracticeSessionsTable practiceSessions = $PracticeSessionsTable(
    this,
  );
  late final $SessionAnswersTable sessionAnswers = $SessionAnswersTable(this);
  late final $MistakesTable mistakes = $MistakesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    questions,
    practiceSessions,
    sessionAnswers,
    mistakes,
  ];
}

typedef $$QuestionsTableCreateCompanionBuilder =
    QuestionsCompanion Function({
      required String id,
      required String examName,
      required int year,
      required String subject,
      required String topic,
      required String difficulty,
      required String questionLatex,
      Value<String?> questionSvg,
      required String optionsJson,
      Value<String?> answerKey,
      Value<String?> solution,
      Value<int> rowid,
    });
typedef $$QuestionsTableUpdateCompanionBuilder =
    QuestionsCompanion Function({
      Value<String> id,
      Value<String> examName,
      Value<int> year,
      Value<String> subject,
      Value<String> topic,
      Value<String> difficulty,
      Value<String> questionLatex,
      Value<String?> questionSvg,
      Value<String> optionsJson,
      Value<String?> answerKey,
      Value<String?> solution,
      Value<int> rowid,
    });

final class $$QuestionsTableReferences
    extends BaseReferences<_$AppDatabase, $QuestionsTable, Question> {
  $$QuestionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MistakesTable, List<Mistake>> _mistakesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.mistakes,
    aliasName: $_aliasNameGenerator(db.questions.id, db.mistakes.questionId),
  );

  $$MistakesTableProcessedTableManager get mistakesRefs {
    final manager = $$MistakesTableTableManager(
      $_db,
      $_db.mistakes,
    ).filter((f) => f.questionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_mistakesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$QuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examName => $composableBuilder(
    column: $table.examName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionLatex => $composableBuilder(
    column: $table.questionLatex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionSvg => $composableBuilder(
    column: $table.questionSvg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerKey => $composableBuilder(
    column: $table.answerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get solution => $composableBuilder(
    column: $table.solution,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mistakesRefs(
    Expression<bool> Function($$MistakesTableFilterComposer f) f,
  ) {
    final $$MistakesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mistakes,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MistakesTableFilterComposer(
            $db: $db,
            $table: $db.mistakes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examName => $composableBuilder(
    column: $table.examName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionLatex => $composableBuilder(
    column: $table.questionLatex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionSvg => $composableBuilder(
    column: $table.questionSvg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerKey => $composableBuilder(
    column: $table.answerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get solution => $composableBuilder(
    column: $table.solution,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get examName =>
      $composableBuilder(column: $table.examName, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get questionLatex => $composableBuilder(
    column: $table.questionLatex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get questionSvg => $composableBuilder(
    column: $table.questionSvg,
    builder: (column) => column,
  );

  GeneratedColumn<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answerKey =>
      $composableBuilder(column: $table.answerKey, builder: (column) => column);

  GeneratedColumn<String> get solution =>
      $composableBuilder(column: $table.solution, builder: (column) => column);

  Expression<T> mistakesRefs<T extends Object>(
    Expression<T> Function($$MistakesTableAnnotationComposer a) f,
  ) {
    final $$MistakesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mistakes,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MistakesTableAnnotationComposer(
            $db: $db,
            $table: $db.mistakes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestionsTable,
          Question,
          $$QuestionsTableFilterComposer,
          $$QuestionsTableOrderingComposer,
          $$QuestionsTableAnnotationComposer,
          $$QuestionsTableCreateCompanionBuilder,
          $$QuestionsTableUpdateCompanionBuilder,
          (Question, $$QuestionsTableReferences),
          Question,
          PrefetchHooks Function({bool mistakesRefs})
        > {
  $$QuestionsTableTableManager(_$AppDatabase db, $QuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> examName = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> topic = const Value.absent(),
                Value<String> difficulty = const Value.absent(),
                Value<String> questionLatex = const Value.absent(),
                Value<String?> questionSvg = const Value.absent(),
                Value<String> optionsJson = const Value.absent(),
                Value<String?> answerKey = const Value.absent(),
                Value<String?> solution = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestionsCompanion(
                id: id,
                examName: examName,
                year: year,
                subject: subject,
                topic: topic,
                difficulty: difficulty,
                questionLatex: questionLatex,
                questionSvg: questionSvg,
                optionsJson: optionsJson,
                answerKey: answerKey,
                solution: solution,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String examName,
                required int year,
                required String subject,
                required String topic,
                required String difficulty,
                required String questionLatex,
                Value<String?> questionSvg = const Value.absent(),
                required String optionsJson,
                Value<String?> answerKey = const Value.absent(),
                Value<String?> solution = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestionsCompanion.insert(
                id: id,
                examName: examName,
                year: year,
                subject: subject,
                topic: topic,
                difficulty: difficulty,
                questionLatex: questionLatex,
                questionSvg: questionSvg,
                optionsJson: optionsJson,
                answerKey: answerKey,
                solution: solution,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$QuestionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mistakesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mistakesRefs) db.mistakes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mistakesRefs)
                    await $_getPrefetchedData<
                      Question,
                      $QuestionsTable,
                      Mistake
                    >(
                      currentTable: table,
                      referencedTable: $$QuestionsTableReferences
                          ._mistakesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$QuestionsTableReferences(
                            db,
                            table,
                            p0,
                          ).mistakesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.questionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$QuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestionsTable,
      Question,
      $$QuestionsTableFilterComposer,
      $$QuestionsTableOrderingComposer,
      $$QuestionsTableAnnotationComposer,
      $$QuestionsTableCreateCompanionBuilder,
      $$QuestionsTableUpdateCompanionBuilder,
      (Question, $$QuestionsTableReferences),
      Question,
      PrefetchHooks Function({bool mistakesRefs})
    >;
typedef $$PracticeSessionsTableCreateCompanionBuilder =
    PracticeSessionsCompanion Function({
      Value<int> id,
      required DateTime startTime,
      required int durationSeconds,
      required int totalQuestions,
      required int correctCount,
      required int wrongCount,
      required int skippedCount,
    });
typedef $$PracticeSessionsTableUpdateCompanionBuilder =
    PracticeSessionsCompanion Function({
      Value<int> id,
      Value<DateTime> startTime,
      Value<int> durationSeconds,
      Value<int> totalQuestions,
      Value<int> correctCount,
      Value<int> wrongCount,
      Value<int> skippedCount,
    });

final class $$PracticeSessionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PracticeSessionsTable, PracticeSession> {
  $$PracticeSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SessionAnswersTable, List<SessionAnswer>>
  _sessionAnswersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionAnswers,
    aliasName: $_aliasNameGenerator(
      db.practiceSessions.id,
      db.sessionAnswers.sessionId,
    ),
  );

  $$SessionAnswersTableProcessedTableManager get sessionAnswersRefs {
    final manager = $$SessionAnswersTableTableManager(
      $_db,
      $_db.sessionAnswers,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionAnswersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PracticeSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalQuestions => $composableBuilder(
    column: $table.totalQuestions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skippedCount => $composableBuilder(
    column: $table.skippedCount,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sessionAnswersRefs(
    Expression<bool> Function($$SessionAnswersTableFilterComposer f) f,
  ) {
    final $$SessionAnswersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionAnswers,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionAnswersTableFilterComposer(
            $db: $db,
            $table: $db.sessionAnswers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticeSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalQuestions => $composableBuilder(
    column: $table.totalQuestions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skippedCount => $composableBuilder(
    column: $table.skippedCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PracticeSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalQuestions => $composableBuilder(
    column: $table.totalQuestions,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get skippedCount => $composableBuilder(
    column: $table.skippedCount,
    builder: (column) => column,
  );

  Expression<T> sessionAnswersRefs<T extends Object>(
    Expression<T> Function($$SessionAnswersTableAnnotationComposer a) f,
  ) {
    final $$SessionAnswersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionAnswers,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionAnswersTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionAnswers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticeSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticeSessionsTable,
          PracticeSession,
          $$PracticeSessionsTableFilterComposer,
          $$PracticeSessionsTableOrderingComposer,
          $$PracticeSessionsTableAnnotationComposer,
          $$PracticeSessionsTableCreateCompanionBuilder,
          $$PracticeSessionsTableUpdateCompanionBuilder,
          (PracticeSession, $$PracticeSessionsTableReferences),
          PracticeSession,
          PrefetchHooks Function({bool sessionAnswersRefs})
        > {
  $$PracticeSessionsTableTableManager(
    _$AppDatabase db,
    $PracticeSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> totalQuestions = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> wrongCount = const Value.absent(),
                Value<int> skippedCount = const Value.absent(),
              }) => PracticeSessionsCompanion(
                id: id,
                startTime: startTime,
                durationSeconds: durationSeconds,
                totalQuestions: totalQuestions,
                correctCount: correctCount,
                wrongCount: wrongCount,
                skippedCount: skippedCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startTime,
                required int durationSeconds,
                required int totalQuestions,
                required int correctCount,
                required int wrongCount,
                required int skippedCount,
              }) => PracticeSessionsCompanion.insert(
                id: id,
                startTime: startTime,
                durationSeconds: durationSeconds,
                totalQuestions: totalQuestions,
                correctCount: correctCount,
                wrongCount: wrongCount,
                skippedCount: skippedCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PracticeSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionAnswersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionAnswersRefs) db.sessionAnswers,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionAnswersRefs)
                    await $_getPrefetchedData<
                      PracticeSession,
                      $PracticeSessionsTable,
                      SessionAnswer
                    >(
                      currentTable: table,
                      referencedTable: $$PracticeSessionsTableReferences
                          ._sessionAnswersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PracticeSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).sessionAnswersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PracticeSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticeSessionsTable,
      PracticeSession,
      $$PracticeSessionsTableFilterComposer,
      $$PracticeSessionsTableOrderingComposer,
      $$PracticeSessionsTableAnnotationComposer,
      $$PracticeSessionsTableCreateCompanionBuilder,
      $$PracticeSessionsTableUpdateCompanionBuilder,
      (PracticeSession, $$PracticeSessionsTableReferences),
      PracticeSession,
      PrefetchHooks Function({bool sessionAnswersRefs})
    >;
typedef $$SessionAnswersTableCreateCompanionBuilder =
    SessionAnswersCompanion Function({
      Value<int> id,
      required int sessionId,
      required String questionId,
      Value<String?> selectedOption,
      required bool isCorrect,
    });
typedef $$SessionAnswersTableUpdateCompanionBuilder =
    SessionAnswersCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<String> questionId,
      Value<String?> selectedOption,
      Value<bool> isCorrect,
    });

final class $$SessionAnswersTableReferences
    extends BaseReferences<_$AppDatabase, $SessionAnswersTable, SessionAnswer> {
  $$SessionAnswersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PracticeSessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.practiceSessions.createAlias(
        $_aliasNameGenerator(
          db.sessionAnswers.sessionId,
          db.practiceSessions.id,
        ),
      );

  $$PracticeSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$PracticeSessionsTableTableManager(
      $_db,
      $_db.practiceSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionAnswersTableFilterComposer
    extends Composer<_$AppDatabase, $SessionAnswersTable> {
  $$SessionAnswersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedOption => $composableBuilder(
    column: $table.selectedOption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCorrect => $composableBuilder(
    column: $table.isCorrect,
    builder: (column) => ColumnFilters(column),
  );

  $$PracticeSessionsTableFilterComposer get sessionId {
    final $$PracticeSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableFilterComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionAnswersTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionAnswersTable> {
  $$SessionAnswersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedOption => $composableBuilder(
    column: $table.selectedOption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCorrect => $composableBuilder(
    column: $table.isCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  $$PracticeSessionsTableOrderingComposer get sessionId {
    final $$PracticeSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionAnswersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionAnswersTable> {
  $$SessionAnswersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedOption => $composableBuilder(
    column: $table.selectedOption,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCorrect =>
      $composableBuilder(column: $table.isCorrect, builder: (column) => column);

  $$PracticeSessionsTableAnnotationComposer get sessionId {
    final $$PracticeSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionAnswersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionAnswersTable,
          SessionAnswer,
          $$SessionAnswersTableFilterComposer,
          $$SessionAnswersTableOrderingComposer,
          $$SessionAnswersTableAnnotationComposer,
          $$SessionAnswersTableCreateCompanionBuilder,
          $$SessionAnswersTableUpdateCompanionBuilder,
          (SessionAnswer, $$SessionAnswersTableReferences),
          SessionAnswer,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SessionAnswersTableTableManager(
    _$AppDatabase db,
    $SessionAnswersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionAnswersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionAnswersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionAnswersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<String> questionId = const Value.absent(),
                Value<String?> selectedOption = const Value.absent(),
                Value<bool> isCorrect = const Value.absent(),
              }) => SessionAnswersCompanion(
                id: id,
                sessionId: sessionId,
                questionId: questionId,
                selectedOption: selectedOption,
                isCorrect: isCorrect,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required String questionId,
                Value<String?> selectedOption = const Value.absent(),
                required bool isCorrect,
              }) => SessionAnswersCompanion.insert(
                id: id,
                sessionId: sessionId,
                questionId: questionId,
                selectedOption: selectedOption,
                isCorrect: isCorrect,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionAnswersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$SessionAnswersTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn:
                                    $$SessionAnswersTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SessionAnswersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionAnswersTable,
      SessionAnswer,
      $$SessionAnswersTableFilterComposer,
      $$SessionAnswersTableOrderingComposer,
      $$SessionAnswersTableAnnotationComposer,
      $$SessionAnswersTableCreateCompanionBuilder,
      $$SessionAnswersTableUpdateCompanionBuilder,
      (SessionAnswer, $$SessionAnswersTableReferences),
      SessionAnswer,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$MistakesTableCreateCompanionBuilder =
    MistakesCompanion Function({
      required String questionId,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$MistakesTableUpdateCompanionBuilder =
    MistakesCompanion Function({
      Value<String> questionId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$MistakesTableReferences
    extends BaseReferences<_$AppDatabase, $MistakesTable, Mistake> {
  $$MistakesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $QuestionsTable _questionIdTable(_$AppDatabase db) =>
      db.questions.createAlias(
        $_aliasNameGenerator(db.mistakes.questionId, db.questions.id),
      );

  $$QuestionsTableProcessedTableManager get questionId {
    final $_column = $_itemColumn<String>('question_id')!;

    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_questionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MistakesTableFilterComposer
    extends Composer<_$AppDatabase, $MistakesTable> {
  $$MistakesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$QuestionsTableFilterComposer get questionId {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MistakesTableOrderingComposer
    extends Composer<_$AppDatabase, $MistakesTable> {
  $$MistakesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$QuestionsTableOrderingComposer get questionId {
    final $$QuestionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableOrderingComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MistakesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MistakesTable> {
  $$MistakesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$QuestionsTableAnnotationComposer get questionId {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MistakesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MistakesTable,
          Mistake,
          $$MistakesTableFilterComposer,
          $$MistakesTableOrderingComposer,
          $$MistakesTableAnnotationComposer,
          $$MistakesTableCreateCompanionBuilder,
          $$MistakesTableUpdateCompanionBuilder,
          (Mistake, $$MistakesTableReferences),
          Mistake,
          PrefetchHooks Function({bool questionId})
        > {
  $$MistakesTableTableManager(_$AppDatabase db, $MistakesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MistakesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MistakesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MistakesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> questionId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MistakesCompanion(
                questionId: questionId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String questionId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => MistakesCompanion.insert(
                questionId: questionId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MistakesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({questionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (questionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.questionId,
                                referencedTable: $$MistakesTableReferences
                                    ._questionIdTable(db),
                                referencedColumn: $$MistakesTableReferences
                                    ._questionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MistakesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MistakesTable,
      Mistake,
      $$MistakesTableFilterComposer,
      $$MistakesTableOrderingComposer,
      $$MistakesTableAnnotationComposer,
      $$MistakesTableCreateCompanionBuilder,
      $$MistakesTableUpdateCompanionBuilder,
      (Mistake, $$MistakesTableReferences),
      Mistake,
      PrefetchHooks Function({bool questionId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db, _db.questions);
  $$PracticeSessionsTableTableManager get practiceSessions =>
      $$PracticeSessionsTableTableManager(_db, _db.practiceSessions);
  $$SessionAnswersTableTableManager get sessionAnswers =>
      $$SessionAnswersTableTableManager(_db, _db.sessionAnswers);
  $$MistakesTableTableManager get mistakes =>
      $$MistakesTableTableManager(_db, _db.mistakes);
}
