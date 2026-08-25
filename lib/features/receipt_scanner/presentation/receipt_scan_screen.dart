import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../data/receipt_picker.dart';
import '../data/receipt_recognizer.dart';
import 'receipt_review_screen.dart';

/// Receipt capture: camera or gallery → on-device OCR → review screen.
///
/// The two stages are reported separately on purpose. A failed *pick*
/// (permission, cancelled, unreadable file) is a dead end the user must act
/// on; a failed *read* is not — we still carry the photo through to review so
/// the details can be typed in. Collapsing both into one message, as this
/// screen used to, made a permission problem indistinguishable from a blurry
/// photo.
class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key, this.picker, this.recognizer});

  /// Injectable for widget tests; production uses the real platform picker.
  final ReceiptPicker? picker;

  /// Injectable for tests; production reads with the on-device recogniser.
  final ReceiptRecognizer? recognizer;

  @override
  ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen> {
  late final ReceiptPicker _picker = widget.picker ?? ReceiptPicker();
  late final ReceiptRecognizer _recognizer =
      widget.recognizer ?? ReceiptRecognizer();

  /// Non-null while working; the text names the stage so a slow OCR pass
  /// doesn't look like a stuck camera.
  String? _stage;
  String? _error;
  bool _errorNeedsSettings = false;

  Future<void> _capture({required bool useCamera}) async {
    setState(() {
      _stage = useCamera ? 'Opening camera…' : 'Opening gallery…';
      _error = null;
      _errorNeedsSettings = false;
    });

    final picked =
        useCamera ? await _picker.fromCamera() : await _picker.fromGallery();
    if (!mounted) return;

    if (!picked.isSuccess) {
      setState(() {
        _stage = null;
        // A cancelled pick is a deliberate user action, not a failure.
        _error = picked.message;
        _errorNeedsSettings = picked.needsSettings;
      });
      return;
    }

    setState(() => _stage = 'Reading the receipt…');
    final file = picked.file!;
    final parsed = await _readReceipt(file);
    if (!mounted) return;

    setState(() => _stage = null);
    // `push`, never `pushReplacement`. This screen is a go_router page-based
    // route (/transactions/scan), and replacing one through the imperative API
    // trips a framework assertion:
    //   "A page-based route cannot be completed using imperative api"
    // which threw here on every capture — the photo was taken, OCR ran, and
    // then review never opened, so scanning looked broken. Pushing *on top of*
    // a page-based route is fine; only completing one this way is not.
    //
    // Back from review now returns here rather than to Activity, which is also
    // the more useful destination: the user can immediately retake a bad shot.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptReviewScreen(
          imageFile: file,
          parsed: parsed.receipt,
          rawLines: parsed.lines,
          ocrFailed: parsed.failed,
        ),
      ),
    );
  }

  /// OCR is best-effort: on failure we return an empty parse and flag it, so
  /// review still opens with the photo attached and every field editable.
  ///
  /// [ReceiptRecognizer] also retries at other orientations when the first
  /// reading looks unreliable, so a sideways photograph is read correctly
  /// instead of silently reporting the largest number on the page.
  Future<RecognitionOutcome> _readReceipt(File file) async {
    try {
      return await _recognizer.recognize(file);
    } catch (e) {
      debugPrint('OCR unavailable: $e');
      return const RecognitionOutcome.failure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _stage != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan receipt')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FgTokens.s6),
          children: [
            const SizedBox(height: FgTokens.s6),
            Icon(Icons.document_scanner_outlined,
                size: 96, color: theme.colorScheme.primary),
            const SizedBox(height: FgTokens.s5),
            Text('Snap or pick a receipt',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: FgTokens.s3),
            Text(
              'Tips: flatten the receipt, fill the frame, avoid shadows. '
              'Text is read on your device — the photo is not uploaded until you save.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: FgTokens.s4),
              _ErrorCard(
                message: _error!,
                onOpenSettings:
                    _errorNeedsSettings ? _picker.openSettings : null,
              ),
            ],
            const SizedBox(height: FgTokens.s8),
            FilledButton.icon(
              onPressed: busy ? null : () => _capture(useCamera: true),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Use camera'),
            ),
            const SizedBox(height: FgTokens.s3),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _capture(useCamera: false),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from gallery'),
            ),
            const SizedBox(height: FgTokens.s3),
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Enter manually instead'),
            ),
            // Progress sits below the actions so the buttons never jump.
            if (busy) ...[
              const SizedBox(height: FgTokens.s4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: FgTokens.s3),
                  Text(_stage!, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onOpenSettings});

  final String message;
  final Future<void> Function()? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(FgTokens.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.error_outline,
                  size: FgTokens.iconSm,
                  color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: FgTokens.s2),
              Expanded(
                child: Text(message,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onErrorContainer)),
              ),
            ]),
            if (onOpenSettings != null) ...[
              const SizedBox(height: FgTokens.s2),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Open settings'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
