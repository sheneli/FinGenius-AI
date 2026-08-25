import '../../../core/utils/money.dart';
import '../../insights/domain/categorizer.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/period.dart';
import '../../transactions/domain/transaction_entry.dart';

/// What the engine decided to do with one user utterance.
class EngineReply {
  const EngineReply(
    this.text, {
    this.handled = true,
    this.listed = const [],
    this.navigateTo,
    this.needsConfirmation = false,
    this.mutated = false,
  });

  /// Utterance was NOT an app command — caller should fall through to the
  /// free-form AI gateway.
  const EngineReply.unhandled()
      : text = '',
        handled = false,
        listed = const [],
        navigateTo = null,
        needsConfirmation = false,
        mutated = false;

  final String text;
  final bool handled;

  /// Transactions shown to the user by this reply — becomes the ordinal
  /// context for follow-ups like "delete the second one".
  final List<TransactionEntry> listed;
  final String? navigateTo; // GoRouter location
  final bool needsConfirmation;

  /// True when data was created/updated/deleted (caller may refresh/TTS etc.).
  final bool mutated;
}

/// A destructive action awaiting a "yes".
sealed class _Pending {
  const _Pending();
}

class _PendingDelete extends _Pending {
  const _PendingDelete(this.tx);
  final TransactionEntry tx;
}

class _PendingUpdate extends _Pending {
  const _PendingUpdate(this.tx, this.newAmountMinor);
  final TransactionEntry tx;
  final int newAmountMinor;
}

/// Natural-language command engine for the assistant.
///
/// Deterministic and fully offline — free-form questions fall through to the
/// AI gateway. Every operation runs through the caller-supplied callbacks,
/// which are the same uid-scoped repositories the manual UI uses, so the
/// engine can never touch another user's data. Destructive operations always
/// require an explicit confirmation turn.
class AssistantEngine {
  AssistantEngine({
    required this.transactions,
    required this.categories,
    required this.currency,
    required this.upsertTransaction,
    required this.deleteTransaction,
    required this.defaultAccountId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Current snapshot of the signed-in user's transactions (newest first).
  final List<TransactionEntry> Function() transactions;
  final List<Category> Function() categories;
  final String currency;
  final Future<void> Function(TransactionEntry tx) upsertTransaction;
  final Future<void> Function(String txId) deleteTransaction;
  final String Function() defaultAccountId;
  final DateTime Function() _clock;

  static const int maxAmountMinor = 100000000 * 100; // sanity cap

  // Conversation context.
  List<TransactionEntry> _lastListed = const [];
  TransactionEntry? _lastAdded;
  _Pending? _pending;

  /// Externally provided listing context (e.g. after a UI-rendered list).
  set listedContext(List<TransactionEntry> value) => _lastListed = value;

  Future<EngineReply> handle(String utterance) async {
    final raw = utterance.trim();
    final lower = raw.toLowerCase();
    if (lower.isEmpty) return const EngineReply.unhandled();

    // ── Confirmation turn ────────────────────────────────────────────────
    if (_pending != null) {
      if (_isYes(lower)) return _executePending();
      if (_isNo(lower)) {
        _pending = null;
        return const EngineReply('Okay, cancelled — nothing was changed.');
      }
      // Any other utterance abandons the pending action.
      _pending = null;
    }

    // ── Navigation ───────────────────────────────────────────────────────
    final nav = _parseNavigate(lower);
    if (nav != null) {
      return EngineReply('Opening ${nav.$2}…', navigateTo: nav.$1);
    }

    // ── Delete (before create: "remove the expense I added") ─────────────
    if (_looksLike(lower, ['delete', 'remove', 'undo'])) {
      return _handleDelete(lower);
    }

    // ── Update ───────────────────────────────────────────────────────────
    if (_looksLike(lower, ['change', 'update', 'edit', 'correct', 'set']) &&
        _mentionsMoneyRecord(lower)) {
      return _handleUpdate(lower);
    }

    // ── Create ───────────────────────────────────────────────────────────
    if (_looksLike(lower, ['add', 'record', 'log', 'create', 'new']) &&
        _mentionsMoneyRecord(lower)) {
      return _handleAdd(raw, lower);
    }

    // ── Read: listings ───────────────────────────────────────────────────
    if ((_looksLike(lower, ['show', 'list', 'view', 'display', 'get', 'see', 'fetch']) &&
            _mentionsMoneyRecord(lower)) ||
        lower.contains('latest expenses') ||
        lower.contains('recent expenses') ||
        lower.contains('my expenses') ||
        lower.contains('my transactions') ||
        lower.contains('list of expenses') ||
        lower.contains('list expenses') ||
        lower.contains('show transactions')) {
      return _handleList(lower);
    }

    // ── Read: totals ─────────────────────────────────────────────────────
    // Every figure needed is already on the device, so these must be answered
    // locally. "how much did I spend", "can I know the today expenses",
    // "what is my expense yesterday", "tell me my spending" must be answered
    // reliably without falling through to cloud AI. Explanatory questions
    // starting with "why" or "explain" fall through to the AI gateway.
    if (!lower.startsWith('why ') &&
        !lower.contains('why did') &&
        !lower.contains('why is') &&
        !lower.startsWith('explain ') &&
        !lower.startsWith('how to ')) {
      if (lower.contains('how much') ||
          lower.contains('how many') ||
          lower.startsWith('total') ||
          lower.contains('spend on') ||
          lower.contains('spent on') ||
          lower.contains('total spent') ||
          ((lower.contains('what is') ||
                  lower.contains('what was') ||
                  lower.contains('what are') ||
                  lower.contains("what's") ||
                  lower.contains('what did') ||
                  lower.contains('can i know') ||
                  lower.contains('could i know') ||
                  lower.contains('may i know') ||
                  lower.contains('let me know') ||
                  lower.contains('tell me') ||
                  lower.contains('know the') ||
                  lower.contains('know my') ||
                  lower.contains('check my') ||
                  lower.contains('give me') ||
                  lower.startsWith('today ') ||
                  lower.startsWith('yesterday ') ||
                  lower == 'today expenses' ||
                  lower == 'today expense' ||
                  lower == 'yesterday expenses' ||
                  lower == 'yesterday expense') &&
              _mentionsMoneyRecord(lower))) {
        return _handleTotal(lower);
      }
    }

    return const EngineReply.unhandled();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Create
  // ───────────────────────────────────────────────────────────────────────

  Future<EngineReply> _handleAdd(String raw, String lower) async {
    final amountMinor = _parseAmountMinor(lower);
    if (amountMinor == null) {
      return const EngineReply(
          "I couldn't find an amount. Try: \"Add an expense of 500 for groceries.\"");
    }
    if (amountMinor <= 0 || amountMinor > maxAmountMinor) {
      return const EngineReply(
          'That amount looks out of range — use a value above zero.');
    }

    final isIncome = _looksLike(lower, ['income', 'salary', 'earned', 'received', 'payment from']);
    final type = isIncome ? TxType.income : TxType.expense;
    final date = _parseDate(lower);
    final description = _extractDescription(raw, lower) ??
        (isIncome ? 'Income' : 'Expense');
    final categoryId = _matchCategory(description, lower, type);

    final accountId = defaultAccountId();
    if (accountId.isEmpty) {
      return const EngineReply(
          'You need at least one account first — open Home → Accounts to add one.');
    }

    final tx = TransactionEntry(
      id: _newId(),
      clientId: _newId(),
      type: type,
      amountMinor: amountMinor,
      currency: currency,
      categoryId: categoryId,
      accountId: accountId,
      occurredAt: date,
      merchant: description,
      note: 'Added via assistant',
      source: TxSource.voice,
    );
    await upsertTransaction(tx);
    _lastAdded = tx;
    final money = Money(amountMinor, currency).format();
    final catName = _categoryName(categoryId);
    return EngineReply(
      '${isIncome ? 'Income' : 'Expense'} added: $description, $money '
      '($catName, ${_friendlyDate(date)}). Say "delete the last expense" to undo.',
      mutated: true,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Delete / update (with confirmation)
  // ───────────────────────────────────────────────────────────────────────

  Future<EngineReply> _handleDelete(String lower) async {
    final target = _resolveTarget(lower);
    if (target == null) {
      return const EngineReply(
          "I couldn't tell which record you mean. Say \"show my latest expenses\" "
          'first, then "delete the second one" — or name it, like "delete my coffee expense".');
    }
    _pending = _PendingDelete(target);
    return EngineReply(
      'Delete "${target.merchant}" — ${Money(target.amountMinor, currency).format()} '
      'on ${_friendlyDate(target.occurredAt)}? Reply "yes" to confirm.',
      needsConfirmation: true,
    );
  }

  Future<EngineReply> _handleUpdate(String lower) async {
    // "change my grocery expense from 50 to 60" / "update X to 60"
    final toMatch = RegExp(r'\bto\s+(?:rs\.?|lkr|\$|usd)?\s*([\d,]+(?:\.\d{1,2})?)')
        .firstMatch(lower);
    final newAmountMinor = toMatch == null
        ? null
        : Money.tryParseToMinor(toMatch.group(1)!, currency: currency);
    if (newAmountMinor == null || newAmountMinor <= 0 || newAmountMinor > maxAmountMinor) {
      return const EngineReply(
          'Tell me the new amount, e.g. "change my grocery expense to 600".');
    }
    // Strip the "to <amount>" clause so it can't pollute target matching.
    final targetClause = lower.replaceAll(RegExp(r'\bfrom\s+[\d,.]+'), '').replaceAll(toMatch!.group(0)!, '');
    final target = _resolveTarget(targetClause);
    if (target == null) {
      return const EngineReply(
          "I couldn't find that record. List your expenses first, or name the merchant.");
    }
    _pending = _PendingUpdate(target, newAmountMinor);
    return EngineReply(
      'Change "${target.merchant}" from ${Money(target.amountMinor, currency).format()} '
      'to ${Money(newAmountMinor, currency).format()}? Reply "yes" to confirm.',
      needsConfirmation: true,
    );
  }

  Future<EngineReply> _executePending() async {
    final pending = _pending;
    _pending = null;
    switch (pending) {
      case _PendingDelete(:final tx):
        await deleteTransaction(tx.id);
        _lastListed = [..._lastListed]..removeWhere((t) => t.id == tx.id);
        if (_lastAdded?.id == tx.id) _lastAdded = null;
        return EngineReply('Deleted "${tx.merchant}" '
            '(${Money(tx.amountMinor, currency).format()}).', mutated: true);
      case _PendingUpdate(:final tx, :final newAmountMinor):
        await upsertTransaction(tx.copyWith(amountMinor: newAmountMinor));
        return EngineReply(
            '"${tx.merchant}" updated to ${Money(newAmountMinor, currency).format()}.',
            mutated: true);
      case null:
        return const EngineReply('Nothing to confirm.');
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Read
  // ───────────────────────────────────────────────────────────────────────

  Future<EngineReply> _handleList(String lower) async {
    final period = _parsePeriod(lower);
    final categoryQuery = _extractCategoryQuery(lower);
    var txs = transactions().where((t) => t.categoryId != 'transfer').toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    if (period != null) {
      txs = txs.where((t) => period.contains(t.occurredAt)).toList();
    }
    if (categoryQuery != null) {
      txs = txs.where((t) => _matchesQuery(t, categoryQuery)).toList();
    }
    if (lower.contains('income')) {
      txs = txs.where((t) => t.type == TxType.income).toList();
    } else if (lower.contains('expense') || lower.contains('spending')) {
      txs = txs.where((t) => t.type == TxType.expense).toList();
    }

    if (txs.isEmpty) {
      return EngineReply(
          'No matching transactions${period != null ? ' for ${period.label().toLowerCase()}' : ''}.');
    }

    final shown = txs.take(5).toList();
    _lastListed = shown;
    final lines = <String>[
      'Here ${shown.length == 1 ? 'is' : 'are'} your '
          '${period != null ? '${period.label().toLowerCase()} ' : 'latest '}'
          'transactions:',
      for (var i = 0; i < shown.length; i++)
        '${i + 1}. ${shown[i].merchant} — '
            '${shown[i].type == TxType.income ? '+' : ''}'
            '${Money(shown[i].amountMinor, currency).format()} '
            '(${_friendlyDate(shown[i].occurredAt)})',
      if (txs.length > shown.length) '…and ${txs.length - shown.length} more in Activity.',
      'You can say "delete the second one" or "change number 1 to 500".',
    ];
    return EngineReply(lines.join('\n'), listed: shown);
  }

  Future<EngineReply> _handleTotal(String lower) async {
    final parsed = _parsePeriod(lower);
    // An unrecognised or misspelt period still gets a real answer; the reply
    // says which range was measured so the number is never ambiguous.
    final period =
        parsed ?? Period.containing(_clock(), PeriodGranularity.month);
    final categoryQuery = _extractCategoryQuery(lower);

    var txs = transactions().where(
        (t) => period.contains(t.occurredAt) && t.categoryId != 'transfer');
    final wantIncome = lower.contains('earn') || lower.contains('income');
    txs = txs.where(
        (t) => t.type == (wantIncome ? TxType.income : TxType.expense));
    if (categoryQuery != null) {
      txs = txs.where((t) => _matchesQuery(t, categoryQuery));
    }

    final matches = txs.toList();
    final total = matches.fold<int>(0, (s, t) => s + t.amountMinor);
    final what = wantIncome ? 'earned' : 'spent';
    final scope = categoryQuery != null ? ' on $categoryQuery' : '';
    final when = period.label(now: _clock()).toLowerCase();

    final count = '${matches.length} '
        'transaction${matches.length == 1 ? '' : 's'}';
    // "for <period>" reads correctly for every label Period produces —
    // "for today", "for yesterday", "for this month", "for August 2026" —
    // unlike the previous "in $when", which produced "in yesterday".
    if (matches.isEmpty) {
      // "You spent 0.00" reads like a computed fact; saying nothing is recorded
      // correctly suggests the range or the filter may be the surprise.
      return EngineReply(parsed == null
          ? "I couldn't read the period in that question, so I checked $when: "
              'nothing $what$scope is recorded.'
          : 'Nothing $what$scope is recorded for $when.');
    }

    final amount = Money(total, currency).format();
    return EngineReply(
      // When the period had to be guessed, lead with that rather than tacking
      // it on — the old form said "in this month … I assumed this month".
      parsed == null
          ? "I couldn't read the period in that question, so here is $when: "
              'you $what $amount$scope across $count.'
          : 'You $what $amount$scope for $when across $count.',
      // Populated so an ordinal follow-up — "delete the second one" — works
      // after a totals answer, as it already does after a listing.
      listed: matches.take(10).toList(),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Parsing helpers
  // ───────────────────────────────────────────────────────────────────────

  /// Maps "open reports", "go to plans", "show my dashboard"… to app routes.
  (String, String)? _parseNavigate(String lower) {
    if (!_looksLike(lower, ['open', 'go to', 'take me', 'navigate', 'show me the', 'show the'])) {
      return null;
    }
    const routes = <String, (String, String)>{
      'report': ('/plans/reports', 'Reports & analytics'),
      'analytic': ('/plans/reports', 'Reports & analytics'),
      'dashboard': ('/home', 'your dashboard'),
      'home': ('/home', 'your dashboard'),
      'activity': ('/transactions', 'Activity'),
      'transaction': ('/transactions', 'Activity'),
      'budget': ('/plans/budgets', 'Budgets'),
      'goal': ('/plans/goals', 'Savings goals'),
      'bill': ('/plans/bills', 'Bills & calendar'),
      'subscription': ('/plans/subscriptions', 'Subscriptions'),
      'plan': ('/plans', 'Plans'),
      'profile': ('/profile', 'your profile'),
      'setting': ('/profile/preferences', 'Preferences'),
      'preference': ('/profile/preferences', 'Preferences'),
      'account': ('/home/accounts', 'Accounts'),
      'scan': ('/transactions/scan', 'the receipt scanner'),
      'receipt': ('/transactions/scan', 'the receipt scanner'),
    };
    for (final e in routes.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return null;
  }

  /// Whole-word verb matching — "added" must not trigger the "add" intent.
  bool _looksLike(String lower, List<String> verbs) =>
      verbs.any((v) => RegExp('\\b${RegExp.escape(v)}\\b').hasMatch(lower));

  bool _mentionsMoneyRecord(String lower) =>
      lower.contains('expense') ||
      lower.contains('income') ||
      lower.contains('transaction') ||
      lower.contains('spending') ||
      RegExp(r'\b(spent|paid|bought|cost)\b').hasMatch(lower);

  bool _isYes(String lower) => RegExp(
          r'^(yes|yeah|yep|confirm|do it|ok(ay)?|sure|go ahead)\b')
      .hasMatch(lower);

  bool _isNo(String lower) =>
      RegExp(r'^(no|nope|cancel|stop|never ?mind|don.?t)\b').hasMatch(lower);

  int? _parseAmountMinor(String lower) {
    // Prefer an amount attached to a currency marker or "of".
    final patterns = [
      RegExp(r'(?:rs\.?|lkr|\$|usd)\s*([\d,]+(?:\.\d{1,2})?)'),
      RegExp(r'\bof\s+([\d,]+(?:\.\d{1,2})?)'),
      RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:rupees|dollars|bucks|rs)\b'),
      RegExp(r'([\d,]+(?:\.\d{1,2})?)'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(lower);
      if (m != null) {
        final minor = Money.tryParseToMinor(m.group(1)!, currency: currency);
        if (minor != null) return minor;
      }
    }
    return null;
  }

  DateTime _parseDate(String lower) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    if (lower.contains('yesterday')) {
      return DateTime(now.year, now.month, now.day - 1, 12);
    }
    final daysAgo = RegExp(r'(\d+)\s+days?\s+ago').firstMatch(lower);
    if (daysAgo != null) {
      return DateTime(
          now.year, now.month, now.day - int.parse(daysAgo.group(1)!), 12);
    }
    return today;
  }

  Period? _parsePeriod(String lower) {
    final now = _clock();
    if (lower.contains('today')) {
      return Period.containing(now, PeriodGranularity.day);
    }
    if (lower.contains('yesterday')) {
      return Period.containing(
          DateTime(now.year, now.month, now.day - 1), PeriodGranularity.day);
    }
    if (lower.contains('this week')) {
      return Period.containing(now, PeriodGranularity.week);
    }
    if (lower.contains('last week')) {
      return Period.containing(now, PeriodGranularity.week).previous();
    }
    if (lower.contains('this month')) {
      return Period.containing(now, PeriodGranularity.month);
    }
    if (lower.contains('last month')) {
      return Period.containing(now, PeriodGranularity.month).previous();
    }
    if (lower.contains('this year')) {
      return Period.containing(now, PeriodGranularity.year);
    }
    return null;
  }

  /// "for groceries", "on food" → the trailing description words.
  String? _extractDescription(String raw, String lower) {
    final m = RegExp(r'\b(?:for|on)\s+(.+)$').firstMatch(lower);
    if (m == null) return null;
    var desc = m.group(1)!;
    desc = desc
        .replaceAll(RegExp(r'\b(today|yesterday|this (week|month|year))\b'), '')
        .replaceAll(RegExp(r'\d+\s+days?\s+ago'), '')
        .replaceAll(RegExp(r'[.?!]+$'), '')
        .trim();
    if (desc.isEmpty) return null;
    return desc[0].toUpperCase() + desc.substring(1);
  }

  String? _extractCategoryQuery(String lower) {
    final m = RegExp(r'\bon\s+([a-z ]+?)(?:\s+(?:this|last)\s+\w+)?[.?!]?$')
        .firstMatch(lower);
    var q = m?.group(1)?.trim();
    if (q == null || q.isEmpty) return null;
    // Strip any trailing time expression. Without this, "on groceries
    // yesterday" searched for the literal text "groceries yesterday", matched
    // no transaction, and reported a confident zero.
    q = q
        .replaceAll(
            RegExp(r'\b(today|yesterday|this|last|week|month|year|day)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (q.isEmpty) return null;
    const stop = {'my', 'the', 'me', 'it', 'expenses', 'expense', 'income'};
    if (stop.contains(q)) return null;
    return q;
  }

  String _matchCategory(String description, String lower, TxType type) {
    final cats = categories().where((c) => c.kind == type).toList();
    final needle = description.toLowerCase();
    for (final c in cats) {
      if (needle.contains(c.name.toLowerCase()) ||
          needle.contains(c.id.toLowerCase()) ||
          lower.contains(c.name.toLowerCase())) {
        return c.id;
      }
    }
    if (type == TxType.expense) {
      final suggestion = Categorizer().suggest(description);
      return suggestion.categoryId;
    }
    return cats.isNotEmpty ? cats.first.id : 'other';
  }

  String _categoryName(String id) =>
      categories().where((c) => c.id == id).map((c) => c.name).firstOrNull ??
      id;

  /// Resolve a delete/update target from ordinals, "last", or a name query.
  TransactionEntry? _resolveTarget(String lower) {
    // "the last expense I added"
    if (RegExp(r'\blast\b').hasMatch(lower) &&
        (lower.contains('added') || lower.contains('entered') || _lastListed.isEmpty)) {
      if (_lastAdded != null) return _lastAdded;
    }
    // Ordinals into the last listing: "the second one", "number 3", "#1"
    final ordinal = _parseOrdinal(lower);
    if (ordinal != null && ordinal >= 1 && ordinal <= _lastListed.length) {
      return _lastListed[ordinal - 1];
    }
    // Name query: "my coffee expense"
    final m = RegExp(r'(?:my|the)\s+(.+?)\s+(?:expense|income|transaction)')
        .firstMatch(lower);
    final query = m?.group(1)?.trim();
    if (query != null && query.isNotEmpty && query != 'last') {
      final all = transactions().toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      final dateFilter = _parsePeriod(lower);
      for (final t in all) {
        if (dateFilter != null && !dateFilter.contains(t.occurredAt)) continue;
        if (_matchesQuery(t, query)) return t;
      }
    }
    if (_lastAdded != null && RegExp(r'\blast\b').hasMatch(lower)) {
      return _lastAdded;
    }
    return null;
  }

  bool _matchesQuery(TransactionEntry t, String query) {
    final q = query.toLowerCase();
    return t.merchant.toLowerCase().contains(q) ||
        t.note.toLowerCase().contains(q) ||
        t.categoryId.toLowerCase().contains(q) ||
        _categoryName(t.categoryId).toLowerCase().contains(q);
  }

  int? _parseOrdinal(String lower) {
    const words = {
      'first': 1, '1st': 1,
      'second': 2, '2nd': 2,
      'third': 3, '3rd': 3,
      'fourth': 4, '4th': 4,
      'fifth': 5, '5th': 5,
    };
    for (final e in words.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    final m = RegExp(r'(?:number|no\.?|#)\s*(\d+)').firstMatch(lower);
    if (m != null) return int.parse(m.group(1)!);
    return null;
  }

  String _friendlyDate(DateTime d) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return '${d.day}/${d.month}';
  }

  static int _idCounter = 0;
  String _newId() =>
      'ast_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
