import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// A recognised piece of text and where it sits on the page.
class TextFragment {
  const TextFragment(this.text, this.box);
  final String text;
  final Rect box;
}

/// Rebuilds printed rows from ML Kit's fragments.
///
/// This exists because a receipt's layout defeats the naive reading order.
/// The description is left-aligned and the price right-aligned, so the wide
/// gap between them usually lands them in *different* blocks — and reading
/// block by block yields "GRAND TOTAL" and "4,985.50" as two separate lines,
/// with no amount attached to the keyword that identifies it. Grouping
/// fragments that share a horizontal band restores the row the shop printed.
abstract final class LineAssembler {
  /// Fraction of the shorter fragment's height that must overlap vertically
  /// for two fragments to count as the same printed row.
  static const _overlapThreshold = 0.5;

  static List<String> assemble(Iterable<TextFragment> fragments) {
    final items = fragments.where((f) => f.text.trim().isNotEmpty).toList()
      ..sort((a, b) => a.box.top.compareTo(b.box.top));

    final rows = <List<TextFragment>>[];
    for (final fragment in items) {
      if (rows.isNotEmpty && _sharesRow(rows.last, fragment)) {
        rows.last.add(fragment);
      } else {
        rows.add([fragment]);
      }
    }

    return [
      for (final row in rows)
        (row..sort((a, b) => a.box.left.compareTo(b.box.left)))
            // Two spaces keeps the description and the amount as distinct
            // tokens for the parser.
            .map((f) => f.text.trim())
            .join('  '),
    ];
  }

  static bool _sharesRow(List<TextFragment> row, TextFragment candidate) {
    final top = row.map((f) => f.box.top).reduce(math.min);
    final bottom = row.map((f) => f.box.bottom).reduce(math.max);
    final overlap = math.min(bottom, candidate.box.bottom) -
        math.max(top, candidate.box.top);
    final shorter = math.min(bottom - top, candidate.box.height);
    if (shorter <= 0) return false;
    return overlap / shorter > _overlapThreshold;
  }
}

/// On-device OCR via ML Kit Text Recognition v2 (Latin). No image or text
/// leaves the device at this stage.
class OcrService {
  OcrService([TextRecognizer? recognizer])
      : _recognizer =
            recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Returns reconstructed rows, top-to-bottom, ready for [ReceiptParser].
  Future<Result<List<String>>> recognizeLines(File image) => guard(() async {
        final input = InputImage.fromFile(image);
        final recognized = await _recognizer.processImage(input);
        final fragments = <TextFragment>[];
        for (final block in recognized.blocks) {
          for (final line in block.lines) {
            fragments.add(TextFragment(line.text, line.boundingBox));
          }
        }
        return LineAssembler.assemble(fragments);
      },
          onError: (e, _) => StorageFailure(
              "Couldn't read text from this image. Try better lighting or enter details manually.",
              cause: e));

  Future<void> dispose() => _recognizer.close();
}
