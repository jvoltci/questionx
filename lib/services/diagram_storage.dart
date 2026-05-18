import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Locates question-diagram image files on disk.
///
/// `question_svg` field in the dataset is now one of:
///   * `"AIPMT_2013_Phy_8.jpg"` — a filename pointing to `${docs}/diagrams/<file>`
///   * `"<svg ...>...</svg>"` — legacy inline SVG (still rendered by SvgPicture.string)
///
/// On first launch (when the diagrams directory is empty) we unpack the bundled
/// `assets/diagrams.zip` into `${docs}/diagrams/`. Subsequent app launches reuse
/// the files in-place. The SyncService's network sync also unzips the same
/// images into the same directory, so both code paths converge on a single
/// on-disk location.
class DiagramStorage {
  static Directory? _cachedDir;

  /// Returns the absolute directory where diagram JPEGs live.
  /// Lazily seeds the directory from the bundled zip on first call.
  static Future<Directory> ensureReady() async {
    if (_cachedDir != null) return _cachedDir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'diagrams'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // Seed from bundled assets if empty.
    final hasAny = await dir
        .list(followLinks: false)
        .any((e) => e is File);
    if (!hasAny) {
      await _unpackBundled(dir);
    }
    _cachedDir = dir;
    return dir;
  }

  /// Counts JPEG/PNG/WEBP files in the diagrams directory. Used by SyncService
  /// to detect a "version current but diagrams missing" state and force a
  /// re-download even when the throttle would normally skip the network check.
  static Future<int> countFiles() async {
    final dir = await ensureReady();
    var n = 0;
    await for (final e in dir.list(followLinks: false)) {
      if (e is File && _looksLikeFilename(e.path)) n++;
    }
    return n;
  }

  /// Returns null if the value is not a filename reference (e.g. legacy SVG).
  static Future<File?> fileFor(String? questionSvg) async {
    if (questionSvg == null || questionSvg.isEmpty) return null;
    if (!_looksLikeFilename(questionSvg)) return null;
    final dir = await ensureReady();
    final f = File(p.join(dir.path, questionSvg));
    if (await f.exists()) return f;
    return null;
  }

  /// Synchronous companion for callers that already have a cached dir path
  /// (used by render widgets to avoid a FutureBuilder rebuild every frame).
  static File? fileForSync(String? questionSvg, String? diagramsDirPath) {
    if (questionSvg == null || questionSvg.isEmpty || diagramsDirPath == null) {
      return null;
    }
    if (!_looksLikeFilename(questionSvg)) return null;
    return File(p.join(diagramsDirPath, questionSvg));
  }

  /// True if the value looks like a file reference (e.g. `"AIPMT_2013_Phy_8.jpg"`)
  /// rather than inline SVG markup.
  static bool _looksLikeFilename(String v) {
    final lower = v.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  static bool isFilenameReference(String? v) =>
      v != null && _looksLikeFilename(v);

  /// Unpacks a zip archive from disk into `${docs}/diagrams/`. Used by
  /// SyncService after a successful network download.
  static Future<int> unpackZipFrom(File zipFile) async {
    final dir = await ensureReady();
    final inputStream = InputFileStream(zipFile.path);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    int extracted = 0;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name;
      // Only pull image files out of the archive (the JSON is handled separately).
      if (!(name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.png') ||
          name.endsWith('.webp'))) {
        continue;
      }
      // Strip any leading "diagrams/" path prefix.
      final basename = p.basename(name);
      final outPath = p.join(dir.path, basename);
      final outFile = File(outPath);
      await outFile.writeAsBytes(file.content as List<int>, flush: true);
      extracted++;
    }
    return extracted;
  }

  /// Unpacks the app's bundled `assets/diagrams.zip` into `${docs}/diagrams/`.
  /// Called automatically by [ensureReady] on first launch.
  static Future<void> _unpackBundled(Directory dir) async {
    try {
      final data = await rootBundle.load('assets/diagrams.zip');
      final bytes = data.buffer.asUint8List();
      final archive = ZipDecoder().decodeBytes(bytes);
      var extracted = 0;
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final basename = p.basename(file.name);
        if (basename.isEmpty || basename.startsWith('.')) continue;
        final outPath = p.join(dir.path, basename);
        await File(outPath).writeAsBytes(file.content as List<int>, flush: true);
        extracted++;
      }
      debugPrint('📂 Seeded $extracted diagram(s) from bundled assets.');
    } catch (e) {
      // No bundle present yet (e.g. older app build) — that's fine; the
      // network sync will populate the directory.
      debugPrint('ℹ️ Bundled diagrams.zip not available ($e).');
    }
  }
}
