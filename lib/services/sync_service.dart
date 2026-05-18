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

class SyncService {
  final AppDatabase db;
  final Dio _dio = Dio();

  static const String _repoOwner = "jvoltci";
  static const String _repoName = "questionx";
  static const String _versionKey = "db_version_tag";
  static const String _lastCheckKey = "db_last_check_ms";
  static const Duration _checkInterval = Duration(hours: 6);

  SyncService(this.db);

  Future<void> initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getString(_versionKey);

    // Ensure the diagrams directory exists before any UI renders. The actual
    // JPEGs arrive via _downloadAndSync() below (from the GitHub release's
    // data.zip), not from a bundled asset.
    await DiagramStorage.ensureReady();

    // Self-heal: if a prior install recorded a version tag but the diagrams
    // directory is empty (e.g. earlier APK had no extraction code, or sync
    // crashed mid-write), force a re-sync regardless of the throttle.
    final diagramCount = await DiagramStorage.countFiles();
    final diagramsMissing = currentVersion != null && diagramCount == 0;
    if (diagramsMissing) {
      debugPrint("🩹 Version $currentVersion recorded but diagrams dir is "
          "empty — forcing re-sync.");
    }

    try {
      if (_shouldCheckOnline(prefs) || diagramsMissing) {
        debugPrint("🔍 Checking for updates...");
        final latestTag = await _checkForUpdates(
          diagramsMissing ? null : currentVersion,
        );
        await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

        if (latestTag != null) {
          await _downloadAndSync(latestTag);
          await prefs.setString(_versionKey, latestTag);
          return;
        }
      } else {
        debugPrint("⏭️ Skipping online check (within throttle window).");
      }
    } catch (e) {
      debugPrint("⚠️ Online check failed ($e). Proceeding with local checks.");
    }

    final questionCount = await db.countQuestions();
    if (questionCount == 0) {
      debugPrint("📦 Database empty. Loading from Bundled Assets...");
      await _loadFromAssets();
    } else {
      debugPrint("✅ Database is ready (Version: $currentVersion).");
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

    debugPrint("⬇️ Downloading $downloadUrl...");
    await _dio.download(downloadUrl, zipPath);

    debugPrint("📦 Unzipping...");
    final zipFile = File(zipPath);

    // 1. Extract any image files into the diagrams directory. The data.zip
    //    layout is: `neet.json`, `jee.json`, plus `diagrams/<qid>.jpg` for
    //    every figure-essential question.
    try {
      final imgCount = await DiagramStorage.unpackZipFrom(zipFile);
      if (imgCount > 0) {
        debugPrint("🖼️ Extracted $imgCount diagram(s).");
      }
    } catch (e) {
      debugPrint("⚠️ Diagram extraction failed: $e");
    }

    // 2. Process the JSON datasets into the database.
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    for (var file in archive.files) {
      if (!file.isFile) continue;
      final filename = file.name;
      if (filename.startsWith('.') ||
          filename.contains("__MACOSX") ||
          !filename.endsWith(".json")) {
        continue;
      }

      debugPrint("📄 Processing $filename...");
      final fileContent = utf8.decode(file.content as List<int>);
      final jsonData = await compute(jsonDecode, fileContent);
      await _insertBatch(jsonData, _examNameForFile(filename));
    }

    await zipFile.delete();
    debugPrint("🎉 Sync Complete!");
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
            examName: examSource,
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
