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
import 'diagram_storage.dart';

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
          _emit(1.0, "Ready", done: true);
          return;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Online check failed ($e). Proceeding with local checks.");
    }

    final questionCount = await db.countQuestions();
    if (questionCount == 0) {
      _emit(0.4, "Loading question bank...");
      await _loadFromAssets();
    } else {
      debugPrint("✅ Database is ready (Version: $currentVersion).");
    }
    _emit(1.0, "Ready", done: true);
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
    await db.deleteAllQuestions();
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    final jsonFiles = archive.files
        .where((f) => f.isFile && f.name.endsWith(".json"))
        .where((f) => !f.name.startsWith('.') && !f.name.contains("__MACOSX"))
        .toList();
    for (var i = 0; i < jsonFiles.length; i++) {
      final file = jsonFiles[i];
      final fileContent = utf8.decode(file.content as List<int>);
      final jsonData = await compute(jsonDecode, fileContent);
      final perFile = 0.14 / jsonFiles.length;
      _emit(0.85 + perFile * i, "Indexing ${_friendlyName(file.name)}...");
      await _insertBatch(jsonData, _examNameForFile(file.name));
      _emit(0.85 + perFile * (i + 1), "Indexed ${_friendlyName(file.name)}");
    }

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
    for (final asset in const ['assets/neet.json', 'assets/jee.json']) {
      try {
        final jsonString = await rootBundle.loadString(asset);
        if (jsonString.trim().isEmpty) continue;
        final jsonData = await compute(jsonDecode, jsonString);
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
