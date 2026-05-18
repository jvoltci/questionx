import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/diagram_storage.dart';

/// Renders the per-question diagram referenced by `question_svg`.
///
/// Two storage formats are supported transparently:
///   * **External file** (post-v4 data format): the value is a filename like
///     `"AIPMT_2013_Phy_8.jpg"` and the actual image lives on disk under
///     `${appDocs}/diagrams/`. Rendered via [Image.file]. The [color] tint is
///     **ignored** for these — JPEGs are already black-text-on-white and
///     applying a BlendMode washes them out.
///   * **Inline SVG** (legacy data format from older releases): the value
///     contains a `<svg>...</svg>` literal. Rendered via [SvgPicture.string].
///     The [color] tint still applies, since legacy SVGs are single-stroke
///     line art designed to be re-coloured.
class QuestionDiagram extends StatelessWidget {
  const QuestionDiagram({
    super.key,
    required this.value,
    this.fit = BoxFit.contain,
    this.color,
    this.errorPlaceholder,
    this.cacheWidth,
  });

  /// The raw `question_svg` field value from the dataset.
  final String value;

  /// How the image should fit its container.
  final BoxFit fit;

  /// Tint applied to legacy SVGs. Ignored for file-backed JPEGs.
  final Color? color;

  /// Widget to show if the file cannot be located on disk.
  final Widget? errorPlaceholder;

  /// Downsamples raster decodes to this width. Set to ~600 for list thumbnails
  /// so 2000×2000 JPEGs don't blow the decode cache during scroll. Leave null
  /// for full-resolution renders (detail view, fullscreen).
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    if (DiagramStorage.isFilenameReference(value)) {
      return FutureBuilder<File?>(
        future: DiagramStorage.fileFor(value),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final file = snap.data;
          if (file == null) {
            return errorPlaceholder ??
                const Center(
                  child: Icon(Icons.broken_image, color: Colors.white24),
                );
          }
          return Image.file(
            file,
            fit: fit,
            cacheWidth: cacheWidth,
            errorBuilder: (_, __, ___) =>
                errorPlaceholder ??
                const Center(
                  child: Icon(Icons.broken_image, color: Colors.white24),
                ),
          );
        },
      );
    }
    // Legacy inline SVG path — keep the colour tint.
    return SvgPicture.string(
      value,
      fit: fit,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      placeholderBuilder: (_) => const Center(
        child: Icon(Icons.image, color: Colors.white24),
      ),
    );
  }

  /// Pushes a fullscreen diagram viewer with pinch-zoom and a close affordance.
  /// Use from any thumbnail tap handler.
  static Future<void> openFullscreen(BuildContext context, String value) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DiagramFullscreenView(value: value),
      ),
    );
  }
}

/// Fullscreen, zoomable diagram viewer. Pushed by [QuestionDiagram.openFullscreen].
class DiagramFullscreenView extends StatelessWidget {
  const DiagramFullscreenView({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final isFile = DiagramStorage.isFilenameReference(value);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Swipe-down to dismiss.
          if ((details.primaryVelocity ?? 0) > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Container(
          color: isFile ? Colors.white : Colors.transparent,
          width: double.infinity,
          height: double.infinity,
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 6.0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: QuestionDiagram(
                value: value,
                // For legacy SVGs, tint white so they're visible on the
                // black scaffold.
                color: isFile ? null : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
