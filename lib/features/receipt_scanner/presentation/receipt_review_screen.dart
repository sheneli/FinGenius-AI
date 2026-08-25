import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/config/session_providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../insights/domain/categorizer.dart';
import '../../transactions/domain/transaction_entry.dart';
import '../../transactions/presentation/add_transaction_screen.dart';
import '../data/receipt_store.dart';
import '../domain/receipt_parser.dart';

/// OCR review & correction: every extracted value is editable, confidence is
/// visible, and saving persists a compressed receipt + hands off to the
/// transaction form for final confirmation.
class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.imageFile,
    required this.parsed,
    required this.rawLines,
    this.ocrFailed = false,
    this.store,
  });

  final File imageFile;
  final ParsedReceipt parsed;
  final List<String> rawLines;

  /// True when text recognition could not run at all — the photo is still
  /// attached, but nothing was pre-filled.
  final bool ocrFailed;

  /// Injectable for tests.
  final ReceiptStore? store;

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  late final TextEditingController _merchant;
  late final TextEditingController _total;
  late DateTime _date;
  bool _busy = false;

  /// Gates the save. OCR output is a guess, so the extracted total has to pass
  /// the same validation as a hand-typed one before any of it is persisted —
  /// otherwise a misread could write a null or nonsensical amount to the
  /// receipt record even though the transaction form would later reject it.
  final _formKey = GlobalKey<FormState>();
  // Uses the app's Firestore instance so overrides in tests apply here too.
  late final ReceiptStore _store =
      widget.store ?? ReceiptStore(firestore: ref.read(firestoreProvider));

  @override
  void initState() {
    super.initState();
    _merchant = TextEditingController(text: widget.parsed.merchant ?? '');
    _total = TextEditingController(
        text: widget.parsed.totalMinor == null
            ? ''
            : (widget.parsed.totalMinor! / 100).toStringAsFixed(2));
    _date = widget.parsed.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _merchant.dispose();
    _total.dispose();
    super.dispose();
  }

  Widget _confidenceChip(double confidence) {
    final label = confidence >= 0.7
        ? 'High'
        : confidence >= 0.4
            ? 'Check'
            : 'Low';
    final color = confidence >= 0.7
        ? FgTokens.success
        : confidence >= 0.4
            ? FgTokens.warning
            : FgTokens.error;
    return Semantics(
      label: 'Extraction confidence: $label',
      child: Chip(
        label: Text(label),
        labelStyle: Theme.of(context).textTheme.labelSmall,
        backgroundColor: color.withValues(alpha: 0.16),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _continueToSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _busy = true);

    final receiptId = const Uuid().v4();
    // Non-null past validation, but the fallback keeps the write total-safe.
    final totalMinor = Money.tryParseToMinor(_total.text);
    final merchant = _merchant.text.trim();
    final profileCurrency =
        ref.read(userProfileProvider).valueOrNull?.prefs.currency ?? 'LKR';

    // Everything the receipt gave us, kept with the receipt record.
    final outcome = await _store.save(
      source: widget.imageFile,
      uid: uid,
      receiptId: receiptId,
      metadata: {
        'merchant': merchant,
        'totalMinor': totalMinor,
        'taxMinor': widget.parsed.taxMinor,
        'currency': widget.parsed.currency ?? profileCurrency,
        'paymentMethod': widget.parsed.paymentMethod,
        'receiptNumber': widget.parsed.receiptNumber,
        'merchantPhone': widget.parsed.merchantPhone,
        'occurredAt': _date.toUtc().toIso8601String(),
        'ocrConfidence': {
          'merchant': widget.parsed.merchantConfidence,
          'total': widget.parsed.totalConfidence,
          'date': widget.parsed.dateConfidence,
        },
        'lineItems': [
          for (final i in widget.parsed.lineItems)
            {'description': i.description, 'amountMinor': i.amountMinor},
        ],
        'fingerprint': widget.parsed.fingerprint,
      },
    );

    // Opportunistically drain anything an earlier offline save left behind.
    _store.retryPending(uid).ignore();

    // The picker's temp file has been copied or uploaded by now.
    try {
      await widget.imageFile.delete();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _busy = false);

    final warning = outcome.warning;
    if (warning != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(warning)));
    }

    // Pre-categorise from the merchant plus the receipt body, so a pharmacy
    // slip lands in Health without the user picking.
    final suggestion = Categorizer()
        .suggest(merchant, note: widget.rawLines.take(40).join(' '));

    final prefill = TransactionEntry(
      id: const Uuid().v4(),
      clientId: const Uuid().v4(),
      type: TxType.expense,
      amountMinor: totalMinor ?? 0,
      currency: profileCurrency,
      categoryId:
          suggestion.confidence >= 0.5 ? suggestion.categoryId : 'other',
      accountId: '',
      occurredAt: _date,
      merchant: merchant,
      note: _noteFrom(widget.parsed),
      receiptId: receiptId,
      source: TxSource.ocr,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
          builder: (_) => AddTransactionScreen(prefill: prefill)),
    );
  }

  /// Detail worth carrying onto the transaction itself rather than burying in
  /// the receipt record.
  static String _noteFrom(ParsedReceipt p) {
    final parts = <String>[
      if (p.paymentMethod != null) 'Paid by ${p.paymentMethod}',
      if (p.taxMinor != null) 'Tax ${(p.taxMinor! / 100).toStringAsFixed(2)}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = widget.parsed;
    final currencyMismatch = parsed.currency != null &&
        parsed.currency !=
            (ref.watch(userProfileProvider).valueOrNull?.prefs.currency ??
                'LKR');

    return Scaffold(
      appBar: AppBar(title: const Text('Check the details')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(FgTokens.s4),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(FgTokens.rLg),
                child: Image.file(widget.imageFile,
                    height: 180, fit: BoxFit.cover),
              ),
              const SizedBox(height: FgTokens.s4),
              if (widget.ocrFailed)
                _Banner(
                  icon: Icons.text_fields_outlined,
                  message:
                      "Text couldn't be read from this photo, so nothing was "
                      'filled in. Type the amount and date below — the photo '
                      'stays attached.',
                )
              else
                Text(
                    'We read these values — please correct anything that looks wrong.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (currencyMismatch) ...[
                const SizedBox(height: FgTokens.s3),
                _Banner(
                  icon: Icons.currency_exchange,
                  message:
                      'This receipt looks like ${parsed.currency}. The entry will '
                      'be saved in your own currency — convert the amount first '
                      'if that matters.',
                ),
              ],
              const SizedBox(height: FgTokens.s4),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _merchant,
                    decoration: const InputDecoration(labelText: 'Merchant'),
                  ),
                ),
                const SizedBox(width: FgTokens.s2),
                _confidenceChip(parsed.merchantConfidence),
              ]),
              const SizedBox(height: FgTokens.s4),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _total,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Total'),
                    // Same rule the transaction form applies, enforced here so a
                    // misread never reaches storage: non-empty, > 0, not absurd.
                    validator: Validators.amount,
                  ),
                ),
                const SizedBox(width: FgTokens.s2),
                _confidenceChip(parsed.totalConfidence),
              ]),
              const SizedBox(height: FgTokens.s4),
              Row(children: [
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FgTokens.rMd)),
                    tileColor: theme.colorScheme.surfaceContainer,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(MaterialLocalizations.of(context)
                        .formatMediumDate(_date)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2015),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ),
                const SizedBox(width: FgTokens.s2),
                _confidenceChip(parsed.dateConfidence),
              ]),
              // Extra detail we extracted — shown so the user can see it was
              // captured, and it travels with the saved receipt.
              if (parsed.taxMinor != null || parsed.paymentMethod != null) ...[
                const SizedBox(height: FgTokens.s3),
                Wrap(spacing: FgTokens.s2, children: [
                  if (parsed.taxMinor != null)
                    Chip(
                      avatar: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: Text(
                          'Tax ${(parsed.taxMinor! / 100).toStringAsFixed(2)}'),
                    ),
                  if (parsed.paymentMethod != null)
                    Chip(
                      avatar: const Icon(Icons.payment_outlined, size: 16),
                      label: Text(parsed.paymentMethod!),
                    ),
                ]),
              ],
              if (parsed.lineItems.isNotEmpty) ...[
                const SizedBox(height: FgTokens.s5),
                Text('Line items we spotted',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: FgTokens.s2),
                for (final item in parsed.lineItems.take(8))
                  ListTile(
                    dense: true,
                    title: Text(item.description,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text((item.amountMinor / 100).toStringAsFixed(2)),
                  ),
              ],
              const SizedBox(height: FgTokens.s6),
              FilledButton(
                onPressed: _busy ? null : _continueToSave,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Looks right — continue'),
              ),
              const SizedBox(height: FgTokens.s2),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Rescan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(FgTokens.s3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(FgTokens.rMd),
      ),
      child: Row(children: [
        Icon(icon,
            size: FgTokens.iconSm,
            color: theme.colorScheme.onSecondaryContainer),
        const SizedBox(width: FgTokens.s2),
        Expanded(
          child: Text(message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
        ),
      ]),
    );
  }
}
