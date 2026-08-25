import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../app/theme/tokens.dart';

/// Result of a reviewed voice capture. Nothing is saved from speech alone —
/// values flow back into the form for explicit user confirmation.
class VoiceEntryResult {
  const VoiceEntryResult({this.merchant, this.amountMinor});
  final String? merchant;
  final int? amountMinor;
}

/// Parses utterances like "1200 rupees at Keells" / "coffee 450".
VoiceEntryResult parseVoiceExpense(String transcript) {
  final t = transcript.toLowerCase();
  final amountMatch = RegExp(r'(\d+(?:[.,]\d{1,2})?)').firstMatch(t);
  int? minor;
  if (amountMatch != null) {
    final v = double.tryParse(amountMatch.group(1)!.replaceAll(',', '.'));
    if (v != null && v > 0) minor = (v * 100).round();
  }
  String? merchant;
  final atMatch = RegExp(r'\b(?:at|from|to)\s+([a-z][a-z ]{2,40})').firstMatch(t);
  if (atMatch != null) {
    merchant = atMatch.group(1)!.trim();
  } else if (amountMatch != null) {
    final before = t.substring(0, amountMatch.start).trim();
    if (before.length >= 3) merchant = before;
  }
  if (merchant != null) {
    merchant = merchant.replaceAll(RegExp(r'\b(rupees?|dollars?|lkr|usd|spent|paid|for)\b'), '').trim();
    if (merchant.isEmpty) merchant = null;
  }
  return VoiceEntryResult(merchant: merchant, amountMinor: minor);
}

Future<VoiceEntryResult?> showVoiceEntrySheet(BuildContext context) =>
    showModalBottomSheet<VoiceEntryResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _VoiceEntrySheet(),
    );

class _VoiceEntrySheet extends StatefulWidget {
  const _VoiceEntrySheet();

  @override
  State<_VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends State<_VoiceEntrySheet> {
  final _speech = SpeechToText();
  String _transcript = '';
  String _status = 'idle'; // idle | listening | review | denied | error

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final available = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' && mounted && _transcript.isNotEmpty) {
          setState(() => _status = 'review');
        }
      },
      onError: (_) {
        if (mounted) setState(() => _status = 'error');
      },
    );
    if (!available) {
      if (mounted) setState(() => _status = 'denied');
      return;
    }
    // Both guards matter. `initialize` above is awaited, and `onResult` fires
    // asynchronously from the platform channel for as long as the engine is
    // listening — dismissing the sheet mid-capture landed a setState on a
    // disposed State and threw.
    if (!mounted) return;
    setState(() => _status = 'listening');
    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _transcript = r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = parseVoiceExpense(_transcript);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: FgTokens.s6, right: FgTokens.s6, top: FgTokens.s6,
          bottom: MediaQuery.of(context).viewInsets.bottom + FgTokens.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Semantics(
                label: _status == 'listening' ? 'Recording in progress' : 'Not recording',
                child: Icon(
                  _status == 'listening' ? Icons.mic : Icons.mic_none,
                  color: _status == 'listening' ? FgTokens.error : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: FgTokens.s3),
              Expanded(
                child: Text(
                  switch (_status) {
                    'listening' => 'Listening… say something like "1,200 at Keells"',
                    'review' => 'Check what we heard',
                    'denied' => 'Microphone unavailable or permission denied',
                    'error' => "Couldn't hear that — try again or type instead",
                    _ => 'Preparing microphone…',
                  },
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ]),
            const SizedBox(height: FgTokens.s4),
            if (_transcript.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(FgTokens.s4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(FgTokens.rMd),
                ),
                child: Text('"$_transcript"', style: theme.textTheme.bodyLarge),
              ),
            if (_status == 'review') ...[
              const SizedBox(height: FgTokens.s3),
              Text(
                'Understood: ${parsed.merchant ?? 'unknown merchant'}'
                '${parsed.amountMinor != null ? ' · ${(parsed.amountMinor! / 100).toStringAsFixed(2)}' : ' · no amount'}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: FgTokens.s5),
            if (_status == 'review')
              FilledButton(
                onPressed: () => Navigator.of(context).pop(parsed),
                child: const Text('Use these values'),
              )
            else if (_status == 'denied' || _status == 'error')
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Type it instead'),
              ),
            const SizedBox(height: FgTokens.s2),
            OutlinedButton(
              onPressed: () {
                _speech.stop();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
