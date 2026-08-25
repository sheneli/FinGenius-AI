import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/receipt_parser.dart';
import 'ocr_service.dart';

/// How much a parse can be trusted, used to decide whether to try again at a
/// different orientation.
///
/// The signal that matters is not "did we find a number" — a sideways receipt
/// still yields plenty of numbers — but "did we find a number *anchored to the
/// word that identifies it*". When the page is rotated, row reconstruction
/// breaks, `GRAND TOTAL` never meets `4,985.50`, and the parser falls back to
/// the largest amount on the page. On a receipt that shows the cash tendered
/// or the card payment, that fallback is confidently wrong — which is far more
/// damaging than reading nothing at all.
abstract final class ReceiptQuality {
  /// Above this, the parse is trusted and no rotation is attempted.
  static const trusted = 4;

  static int score(ParsedReceipt r) {
    var score = 0;
    // A keyword-anchored total is the strongest evidence the layout was read
    // correctly; the 0.5 fallback score explicitly does not count.
    if (r.totalConfidence >= 0.85) score += 3;
    if (r.merchant != null) score++;
    if (r.date != null) score++;
    if (r.taxMinor != null) score++;
    if (r.receiptNumber != null) score++;
    if (r.lineItems.isNotEmpty) score++;
    return score;
  }
}

/// The best reading of a receipt, and how it was obtained.
class RecognitionOutcome {
  const RecognitionOutcome({
    required this.receipt,
    required this.lines,
    required this.failed,
    this.rotationApplied = 0,
  });

  const RecognitionOutcome.failure()
      : receipt = const ParsedReceipt(),
        lines = const [],
        failed = true,
        rotationApplied = 0;

  final ParsedReceipt receipt;
  final List<String> lines;

  /// True when text recognition could not run at all.
  final bool failed;

  /// Degrees the image had to be rotated to read it (0, 90, 180 or 270).
  final int rotationApplied;
}

/// Reads a receipt, correcting for photographs that are not upright.
///
/// Tries the image as-is first, which is the overwhelmingly common case and
/// costs one OCR pass. Only when that reading looks unreliable does it rotate
/// and retry, keeping whichever orientation scores best.
class ReceiptRecognizer {
  ReceiptRecognizer({
    OcrService Function()? ocrFactory,
    this.rotator = const _CompressRotator(),
    this.parser = const ReceiptParser(),
  }) : _ocrFactory = ocrFactory ?? OcrService.new;

  final OcrService Function() _ocrFactory;
  final ImageRotator rotator;
  final ReceiptParser parser;

  /// Orientations attempted, in order, after the upright pass disappoints.
  static const _fallbackRotations = [90, 270, 180];

  Future<RecognitionOutcome> recognize(File image) async {
    final upright = await _readAt(image, 0);
    if (upright == null) return const RecognitionOutcome.failure();
    if (ReceiptQuality.score(upright.receipt) >= ReceiptQuality.trusted) {
      return upright;
    }

    var best = upright;
    var bestScore = ReceiptQuality.score(upright.receipt);
    for (final degrees in _fallbackRotations) {
      final candidate = await _readAt(image, degrees);
      if (candidate == null) continue;
      final score = ReceiptQuality.score(candidate.receipt);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
        // Nothing can beat a fully-anchored read, so stop early.
        if (score >= ReceiptQuality.trusted + 2) break;
      }
    }
    if (best.rotationApplied != 0) {
      debugPrint('Receipt read after rotating ${best.rotationApplied}°');
    }
    return best;
  }

  /// One OCR pass at [degrees]. Null means the recogniser itself failed.
  Future<RecognitionOutcome?> _readAt(File image, int degrees) async {
    File? target = image;
    File? temp;
    if (degrees != 0) {
      temp = await rotator.rotate(image, degrees);
      if (temp == null) return null;
      target = temp;
    }

    OcrService? ocr;
    try {
      ocr = _ocrFactory();
      final result = await ocr.recognizeLines(target);
      final lines = result.valueOrNull;
      if (lines == null) return null;
      return RecognitionOutcome(
        receipt: parser.parse(lines),
        lines: lines,
        failed: false,
        rotationApplied: degrees,
      );
    } catch (e) {
      debugPrint('OCR pass at $degrees° failed: $e');
      return null;
    } finally {
      try {
        await ocr?.dispose();
      } catch (_) {}
      if (temp != null) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }
}

/// Seam so the rotation strategy can be faked in tests.
abstract class ImageRotator {
  /// Returns a temporary file containing [image] rotated by [degrees],
  /// or null if it could not be produced.
  Future<File?> rotate(File image, int degrees);
}

class _CompressRotator implements ImageRotator {
  const _CompressRotator();

  @override
  Future<File?> rotate(File image, int degrees) async {
    try {
      // minWidth/minHeight are a *target*, not a floor: the library scales the
      // image down by max(srcW/minWidth, srcH/minHeight). Passing 1 therefore
      // collapses the page to a single pixel. Passing the source dimensions
      // gives a scale factor of 1 — a pure rotation, full detail preserved,
      // which is what OCR needs.
      final size = await _dimensions(image);
      if (size == null) return null;
      final bytes = await FlutterImageCompress.compressWithFile(
        image.absolute.path,
        rotate: degrees,
        quality: 95,
        minWidth: size.$1,
        minHeight: size.$2,
      ).timeout(const Duration(seconds: 20));
      if (bytes == null || bytes.isEmpty) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/ocr_rot${degrees}_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('Could not rotate for OCR retry: $e');
      return null;
    }
  }

  /// Pixel dimensions read from the encoded header — no full decode, so this
  /// stays cheap even for a large photograph.
  Future<(int, int)?> _dimensions(File image) async {
    ui.ImageDescriptor? descriptor;
    try {
      final buffer =
          await ui.ImmutableBuffer.fromUint8List(await image.readAsBytes());
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = (descriptor.width, descriptor.height);
      buffer.dispose();
      return size;
    } catch (e) {
      debugPrint('Could not read image dimensions: $e');
      return null;
    } finally {
      descriptor?.dispose();
    }
  }
}
