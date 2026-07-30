import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questionx/database.dart';

/// Guards the diagram self-heal.
///
/// v1.7.3 and v1.7.4 shipped a `data.zip` holding all 6,150 JEE figures and
/// zero NEET ones. Every NEET question with a diagram rendered "Error loading
/// diagram", yet the old health check (`diagramCount == 0`) saw 6,150 files and
/// reported healthy, so the app never re-synced.
///
/// `sampleDiagramFilenames` is what makes that detectable: it stratifies by
/// exam, so a wholly-missing family always shows up in the sample. A flat
/// sample would be ~97% JEE and would have missed it.

AppDatabase memDb() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> seed(AppDatabase db, String exam, int n, {required bool svg}) async {
  for (var i = 0; i < n; i++) {
    await db.into(db.questions).insert(QuestionsCompanion.insert(
          id: '${exam}_$i',
          examName: exam,
          subject: 'Physics',
          topic: 'Optics',
          difficulty: 'Easy',
          questionLatex: 'q$i',
          optionsJson: '[]',
          year: 2024,
          questionSvg: Value(svg ? '${exam}_$i.png' : null),
        ));
  }
}

void main() {
  late AppDatabase db;
  setUp(() => db = memDb());
  tearDown(() => db.close());

  test('samples every exam, not just the dominant one', () async {
    // Mirrors the real ratio: JEE dwarfs NEET.
    await seed(db, 'JEE_Main', 400, svg: true);
    await seed(db, 'NEET', 12, svg: true);

    final sample = await db.sampleDiagramFilenames();
    final neet = sample.where((s) => s.startsWith('NEET')).toList();
    final jee = sample.where((s) => s.startsWith('JEE')).toList();

    expect(neet, isNotEmpty,
        reason: 'a NEET-only outage must be visible in the sample');
    expect(jee, isNotEmpty);
    // Bounded per exam so startup stays cheap.
    expect(jee.length, lessThanOrEqualTo(25));
  });

  test('the v1.7.4 outage is detectable from the sample', () async {
    await seed(db, 'JEE_Main', 200, svg: true);
    await seed(db, 'NEET', 30, svg: true);

    // On-disk set as v1.7.4 actually shipped: every JEE figure, no NEET one.
    final onDisk = <String>{
      for (var i = 0; i < 200; i++) 'JEE_Main_$i.png',
    };

    final sample = await db.sampleDiagramFilenames();
    final absent = sample.where((s) => !onDisk.contains(s)).toList();

    expect(absent, isNotEmpty,
        reason: 'sample must reveal the missing NEET figures');
    expect(absent.every((s) => s.startsWith('NEET')), isTrue);
  });

  test('a complete diagram set reports nothing absent', () async {
    await seed(db, 'JEE_Main', 50, svg: true);
    await seed(db, 'NEET', 50, svg: true);
    final sample = await db.sampleDiagramFilenames();
    final onDisk = sample.toSet();
    expect(sample.where((s) => !onDisk.contains(s)), isEmpty);
  });

  test('questions without diagrams are never sampled', () async {
    await seed(db, 'JEE_Main', 20, svg: false);
    expect(await db.sampleDiagramFilenames(), isEmpty);
  });

  test('legacy inline <svg> blobs are excluded — they need no file', () async {
    await db.into(db.questions).insert(QuestionsCompanion.insert(
          id: 'inline_1',
          examName: 'AIPMT',
          subject: 'Physics',
          topic: 'Optics',
          difficulty: 'Easy',
          questionLatex: 'q',
          optionsJson: '[]',
          year: 2024,
          questionSvg: const Value('<svg viewBox="0 0 10 10"></svg>'),
        ));
    expect(await db.sampleDiagramFilenames(), isEmpty);
  });
}
