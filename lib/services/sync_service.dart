import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import '../database.dart';

class SyncService {
  final AppDatabase db;
  final Dio _dio = Dio();

  // --- CONFIGURATION ---
  static const String _repoOwner = "jvoltci";
  static const String _repoName = "questionx";
  static const String _versionKey = "db_version_tag";

  SyncService(this.db);

  /// 1. Main Entry Point
  Future<void> initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getString(_versionKey);

    // Step A: Check Online for Updates
    try {
      print("🔍 Checking for updates...");
      final latestTag = await _checkForUpdates(currentVersion);

      if (latestTag != null) {
        // Update found! Download and Sync
        await _downloadAndSync(latestTag);
        await prefs.setString(_versionKey, latestTag);
        return; // Exit, we are done
      }
    } catch (e) {
      print("⚠️ Online check failed ($e). Proceeding with local checks.");
    }

    // Step B: If no update or offline, check if DB is empty
    final questionCount = await db
        .select(db.questions)
        .get()
        .then((l) => l.length);
    if (questionCount == 0) {
      print("📦 Database empty. Loading from Bundled Assets...");
      await _loadFromAssets();
    } else {
      print("✅ Database is ready (Version: $currentVersion).");
    }
  }

  /// 2. Check GitHub API for latest release tag
  Future<String?> _checkForUpdates(String? currentVersion) async {
    const url =
        "https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest";
    final response = await _dio.get(url);

    if (response.statusCode == 200) {
      final latestTag = response.data['tag_name'];
      if (currentVersion == null || latestTag != currentVersion) {
        print("🚀 New Update Found: $latestTag");
        return latestTag;
      }
    }
    return null; // No update needed
  }

  /// 3. Download Zip, Extract, Filter Mac Junk, Insert to DB
  Future<void> _downloadAndSync(String tag) async {
    final dir = await getApplicationDocumentsDirectory();
    final zipPath = "${dir.path}/data.zip";

    // A. Download
    // Note: We use the 'download' URL format for releases
    final downloadUrl =
        "https://github.com/$_repoOwner/$_repoName/releases/download/$tag/data.zip";

    print("⬇️ Downloading $downloadUrl...");
    await _dio.download(downloadUrl, zipPath);

    // B. Unzip
    print("📦 Unzipping...");
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);

    // C. Process Files
    for (var file in archive.files) {
      if (file.isFile) {
        final filename = file.name;

        // --- CRITICAL FIX: IGNORE MAC TRASH FILES ---
        if (filename.startsWith('.') ||
            filename.contains("__MACOSX") ||
            !filename.endsWith(".json")) {
          continue;
        }
        // --------------------------------------------

        print("📄 Processing $filename...");

        // Extract content to memory directly
        final fileContent = utf8.decode(file.content as List<int>);

        // Parse in background
        final jsonData = await compute(jsonDecode, fileContent);

        // Detect Exam Source
        String examSource = filename.toLowerCase().contains("neet")
            ? "NEET"
            : "JEE Main";

        // Insert
        await _insertBatch(jsonData, examSource);
      }
    }

    // Cleanup
    File(zipPath).delete();
    print("🎉 Sync Complete!");
  }

  /// 4. Fallback: Load from local Assets (if offline/first run)
  Future<void> _loadFromAssets() async {
    try {
      // Assuming you have neet.json in assets. Add jee.json to assets if you want that too.
      final jsonString = await rootBundle.loadString('assets/neet.json');
      final jsonData = await compute(jsonDecode, jsonString);
      await _insertBatch(jsonData, "NEET (Bundled)");
    } catch (e) {
      print("❌ Asset Load Error: $e");
    }
  }

  /// 5. Database Insertion Logic
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
