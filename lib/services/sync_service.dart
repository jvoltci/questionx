import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database.dart';
import '../utils/crypto.dart';
import 'diagram_storage.dart';

/// Top-level so it can run in a background isolate via compute(): decrypt the
/// AES blob, then JSON-decode. Keeps ~21MB of AES + parse off the UI thread.
dynamic _decryptAndDecodeBytes(Uint8List bytes) {
  return jsonDecode(DataCrypto.decryptBytes(bytes));
}

class SyncProgress {
  /// 0.0 → 1.0
  final double progress;
  /// Human-readable label shown under the bar.
  final String label;
  /// True when this is the final tick.
  final bool done;
  const SyncProgress(this.progress, this.label, {this.done = false});
}

class SyncService {
  final AppDatabase db;
  final Dio _dio = Dio();

  /// Listenable progress stream consumed by the splash screen.
  final ValueNotifier<SyncProgress> progress =
      ValueNotifier(const SyncProgress(0, "Initializing..."));

  static const String _repoOwner = "jvoltci";
  static const String _repoName = "questionx";
  static const String _versionKey = "db_version_tag";
  static const String _lastCheckKey = "db_last_check_ms";
  static const Duration _checkInterval = Duration(hours: 6);

  SyncService(this.db);

  void _emit(double p, String label, {bool done = false}) {
    progress.value = SyncProgress(p.clamp(0.0, 1.0), label, done: done);
  }

  Future<void> initializeData() async {
    _emit(0.02, "Initializing...");
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getString(_versionKey);

    await DiagramStorage.ensureReady();
    final diagramCount = await DiagramStorage.countFiles();
    final questionCount = await db.countQuestions();

    // FIRST LAUNCH (empty DB): open INSTANTLY from the bundled, encrypted bank.
    // The full question text renders offline immediately — we then pull diagrams
    // in the BACKGROUND instead of blocking the splash on a ~5MB download. The
    // bundled questions are the source of truth here, so the background fetch
    // grabs only the images (which aren't bundled) and never re-imports/overwrites
    // the questions.
    if (questionCount == 0) {
      _emit(0.4, "Loading question bank...");
      await _loadFromAssets();
      _emit(1.0, "Ready", done: true);
      unawaited(_backgroundSyncDiagrams(prefs, currentVersion));
      return;
    }

    // SUBSEQUENT LAUNCHES: periodic online update (content + diagrams), and
    // self-heal if the diagrams dir was wiped while a version is recorded.
    final diagramsMissing = currentVersion != null && diagramCount == 0;
    if (diagramsMissing) {
      debugPrint("🩹 Version $currentVersion recorded but diagrams dir is "
          "empty — forcing re-sync.");
    }
    try {
      if (_shouldCheckOnline(prefs) || diagramsMissing) {
        _emit(0.05, "Checking for updates...");
        final latestTag = await _checkForUpdates(
          diagramsMissing ? null : currentVersion,
        );
        await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

        if (latestTag != null) {
          await _downloadAndSync(latestTag);
          await prefs.setString(_versionKey, latestTag);
        }
      } else {
        debugPrint("✅ Database is ready (Version: $currentVersion).");
      }
    } catch (e) {
      debugPrint("⚠️ Online check failed ($e). Proceeding with current bank.");
    }
    _emit(1.0, "Ready", done: true);
  }

  /// Cold-start background diagram fetch. Runs AFTER the splash has handed off
  /// to the home screen (fire-and-forget), so the user is already practising
  /// while images stream in. Pulls the release `data.zip` and extracts ONLY the
  /// diagrams — questions stay exactly as loaded from the bundled bank, so a
  /// stale release can never overwrite the shipped (repaired) content. Records
  /// the version tag so later launches don't repeat this. Fully best-effort:
  /// any failure just leaves diagrams to retry on the next launch.
  Future<void> _backgroundSyncDiagrams(
      SharedPreferences prefs, String? currentVersion) async {
    try {
      final latestTag = await _checkForUpdates(currentVersion);
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
      final tag = latestTag ?? currentVersion;
      if (tag == null) return; // no release to pull diagrams from yet

      final dir = await getApplicationDocumentsDirectory();
      final zipPath = "${dir.path}/data.zip";
      final downloadUrl =
          "https://github.com/$_repoOwner/$_repoName/releases/download/$tag/data.zip";
      await _dio.download(downloadUrl, zipPath);

      final zipFile = File(zipPath);
      final imgCount = await DiagramStorage.unpackZipFrom(zipFile);
      debugPrint("🖼️ Background-fetched $imgCount diagram(s) for $tag.");
      if (await zipFile.exists()) await zipFile.delete();

      await prefs.setString(_versionKey, tag);
    } catch (e) {
      debugPrint(
          "⚠️ Background diagram sync failed ($e) — will retry next launch.");
    }
  }

  bool _shouldCheckOnline(SharedPreferences prefs) {
    final lastMs = prefs.getInt(_lastCheckKey);
    if (lastMs == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(last) >= _checkInterval;
  }

  Future<String?> _checkForUpdates(String? currentVersion) async {
    const url =
        "https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest";
    final response = await _dio.get(url);

    if (response.statusCode == 200) {
      final latestTag = response.data['tag_name'];
      if (currentVersion == null || latestTag != currentVersion) {
        debugPrint("🚀 New Update Found: $latestTag");
        return latestTag;
      }
    }
    return null;
  }

  Future<void> _downloadAndSync(String tag) async {
    final dir = await getApplicationDocumentsDirectory();
    final zipPath = "${dir.path}/data.zip";

    final downloadUrl =
        "https://github.com/$_repoOwner/$_repoName/releases/download/$tag/data.zip";

    // Phase 1: download (0.05 → 0.60).
    _emit(0.05, "Downloading content...");
    await _dio.download(
      downloadUrl,
      zipPath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        final frac = received / total;
        final mb = (received / 1024 / 1024).toStringAsFixed(1);
        final totalMb = (total / 1024 / 1024).toStringAsFixed(0);
        _emit(0.05 + 0.55 * frac, "Downloading content... $mb / $totalMb MB");
      },
    );

    final zipFile = File(zipPath);

    // Phase 2: extract diagrams (0.60 → 0.85).
    try {
      _emit(0.60, "Unpacking diagrams...");
      final imgCount = await DiagramStorage.unpackZipFrom(zipFile);
      if (imgCount > 0) {
        debugPrint("🖼️ Extracted $imgCount diagram(s).");
        _emit(0.85, "Unpacked $imgCount diagrams");
      } else {
        _emit(0.85, "No new diagrams");
      }
    } catch (e) {
      debugPrint("⚠️ Diagram extraction failed: $e");
    }

    // Phase 3: process JSON datasets into the DB (0.85 → 0.99).
    // CRITICAL: nuke all existing question rows first. We need this because a
    // new release can both ADD records and DROP records (e.g. v1.3.0 trimmed
    // 4K JEE rows from v1.2.0). Without a delete pass, dropped records keep
    // showing up to the user because `insertOrReplace` only touches IDs
    // present in the new payload.
    _emit(0.85, "Indexing questions...");
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    final jsonFiles = archive.files
        .where((f) => f.isFile &&
            (f.name.endsWith(".json") || f.name.endsWith(".json.enc")))
        .where((f) => !f.name.startsWith('.') && !f.name.contains("__MACOSX"))
        .toList();

    // Decode + validate the ENTIRE payload BEFORE touching the live DB. A
    // corrupt/partial download must never leave the user with an empty bank.
    // Supports both plaintext (current release) and encrypted .json.enc payloads.
    final decoded = <MapEntry<String, List<dynamic>>>[];
    for (var i = 0; i < jsonFiles.length; i++) {
      final file = jsonFiles[i];
      final raw = file.content as List<int>;
      final jsonData = file.name.endsWith('.enc')
          ? await compute(_decryptAndDecodeBytes, Uint8List.fromList(raw))
          : await compute(jsonDecode, utf8.decode(raw));
      final list = _asQuestionList(jsonData);
      if (list == null || list.isEmpty) {
        throw StateError("Empty/invalid dataset in ${file.name} — aborting sync");
      }
      decoded.add(MapEntry(_examNameForFile(file.name), list));
      _emit(0.85 + (0.10 / jsonFiles.length) * (i + 1),
          "Validated ${_friendlyName(file.name)}");
    }
    if (decoded.isEmpty) {
      throw StateError("No datasets in update payload — keeping current bank");
    }

    // Everything validated → swap atomically so a mid-write failure rolls back.
    _emit(0.96, "Updating question bank...");
    await db.transaction(() async {
      await db.deleteAllQuestions();
      for (final entry in decoded) {
        await _insertBatch(entry.value, entry.key);
      }
    });

    await zipFile.delete();
    debugPrint("🎉 Sync Complete!");
  }

  static String _friendlyName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains("neet")) return "NEET questions";
    if (lower.contains("jee")) return "JEE questions";
    return filename;
  }

  Future<void> _loadFromAssets() async {
    for (final asset in const ['assets/neet.json.enc', 'assets/jee.json.enc']) {
      try {
        final bd = await rootBundle.load(asset);
        final bytes =
            bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
        // Decrypt + decode off the UI isolate.
        final jsonData = await compute(_decryptAndDecodeBytes, bytes);
        await _insertBatch(jsonData, _examNameForFile(asset));
      } catch (e) {
        debugPrint("❌ Asset Load Error ($asset): $e");
      }
    }
  }

  static String _examNameForFile(String filename) {
    return filename.toLowerCase().contains("neet") ? "NEET" : "JEE Main";
  }

  /// Per-record exam-name mapping. JEE records carry `exam: "JEE_Main"` or
  /// `"JEE_Advanced"`, so a single jee.json populates both display buckets.
  /// Falls back to the file-level label for records lacking the field
  /// (e.g. all NEET rows, which we keep grouped under "NEET").
  static String _examNameForRecord(Map<String, dynamic> q, String fileLabel) {
    final raw = q['exam'];
    if (raw is String) {
      if (raw == 'JEE_Advanced') return 'JEE Advanced';
      if (raw == 'JEE_Main') return 'JEE Main';
    }
    return fileLabel;
  }

  /// Extracts the question list from either a bare List or a {"questions": [...]}
  /// wrapper. Returns null for anything else.
  List<dynamic>? _asQuestionList(dynamic jsonData) {
    if (jsonData is Map && jsonData['questions'] is List) {
      return jsonData['questions'] as List<dynamic>;
    }
    if (jsonData is List) return jsonData;
    return null;
  }

  Future<void> _insertBatch(dynamic jsonData, String examSource) async {
    List<dynamic> list;
    if (jsonData is Map && jsonData.containsKey('questions')) {
      list = jsonData['questions'];
    } else if (jsonData is List) {
      list = jsonData;
    } else {
      return;
    }

    await db.batch((batch) {
      for (var q in list) {
        batch.insert(
          db.questions,
          QuestionsCompanion.insert(
            id: q['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            examName: _examNameForRecord(q, examSource),
            year: q['year'] is int
                ? q['year']
                : int.tryParse(q['year'].toString()) ?? 2024,
            subject: q['subject'] ?? "General",
            topic: q['topic'] ?? "General",
            difficulty: q['difficulty'] ?? "Medium",
            questionLatex: q['question_latex'] ?? "",
            questionSvg: drift.Value(q['question_svg']),
            optionsJson: jsonEncode(q['options']),
            answerKey: drift.Value(q['answer_key']),
            solution: drift.Value(q['solution']),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      }
    });
  }
}
