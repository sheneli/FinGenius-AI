/// Immutable transaction entity. Pure Dart — no Flutter/Firebase imports —
/// so the analytics/forecasting/detection domain code is unit-testable.
enum TxType { income, expense }

enum TxSource { manual, ocr, voice, recurring }

class TransactionEntry {
  const TransactionEntry({
    required this.id,
    required this.clientId,
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.categoryId,
    required this.accountId,
    required this.occurredAt,
    this.merchant = '',
    this.note = '',
    this.receiptId,
    this.source = TxSource.manual,
    this.categoryConfidence,
    this.pendingSync = false,
    this.updatedAt,
    this.schemaVersion = 1,
  });

  final String id;
  final String clientId; // uuid minted on device; idempotency key for offline sync
  final TxType type;
  final int amountMinor;
  final String currency;
  final String categoryId;
  final String accountId;
  final DateTime occurredAt;
  final String merchant;
  final String note;
  final String? receiptId;
  final TxSource source;
  final double? categoryConfidence;
  final bool pendingSync;
  final DateTime? updatedAt;
  final int schemaVersion;

  int get signedMinor => type == TxType.expense ? -amountMinor : amountMinor;

  TransactionEntry copyWith({
    String? id,
    TxType? type,
    int? amountMinor,
    String? categoryId,
    String? accountId,
    DateTime? occurredAt,
    String? merchant,
    String? note,
    String? receiptId,
    TxSource? source,
    double? categoryConfidence,
    bool? pendingSync,
  }) =>
      TransactionEntry(
        id: id ?? this.id,
        clientId: clientId,
        type: type ?? this.type,
        amountMinor: amountMinor ?? this.amountMinor,
        currency: currency,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        occurredAt: occurredAt ?? this.occurredAt,
        merchant: merchant ?? this.merchant,
        note: note ?? this.note,
        receiptId: receiptId ?? this.receiptId,
        source: source ?? this.source,
        categoryConfidence: categoryConfidence ?? this.categoryConfidence,
        pendingSync: pendingSync ?? this.pendingSync,
        updatedAt: updatedAt,
        schemaVersion: schemaVersion,
      );

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'type': type.name,
        'amountMinor': amountMinor,
        'currency': currency,
        'categoryId': categoryId,
        'accountId': accountId,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'merchant': merchant,
        'note': note,
        'receiptId': receiptId,
        'source': source.name,
        'categoryConfidence': categoryConfidence,
        'schemaVersion': schemaVersion,
      };

  static TransactionEntry fromMap(String id, Map<String, dynamic> m, {bool pendingSync = false}) =>
      TransactionEntry(
        id: id,
        clientId: (m['clientId'] as String?) ?? id,
        type: TxType.values.byName((m['type'] as String?) ?? 'expense'),
        amountMinor: (m['amountMinor'] as num?)?.toInt() ?? 0,
        currency: (m['currency'] as String?) ?? 'LKR',
        categoryId: (m['categoryId'] as String?) ?? 'other',
        accountId: (m['accountId'] as String?) ?? '',
        occurredAt: DateTime.tryParse((m['occurredAt'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
        merchant: (m['merchant'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
        receiptId: m['receiptId'] as String?,
        source: TxSource.values.byName((m['source'] as String?) ?? 'manual'),
        categoryConfidence: (m['categoryConfidence'] as num?)?.toDouble(),
        pendingSync: pendingSync,
        schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
      );
}
