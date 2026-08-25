import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Seeds realistic, clearly-labelled demo data through the normal Firestore
/// model so every module has content during testing/marking. User-triggered
/// (Profile → Load demo data), idempotent (stable doc ids — reseeding
/// overwrites, never duplicates), and honest: docs carry `demo: true`.
class DemoDataSeeder {
  DemoDataSeeder(this._firestore);
  final FirebaseFirestore _firestore;

  static const _merchants = <String, List<(String, int, int)>>{
    // categoryId: [(merchant, minMinor, maxMinor)]
    'groceries': [('Keells Super', 250000, 850000), ('Cargills Food City', 180000, 620000), ('Arpico Super', 300000, 900000)],
    'dining': [('Pilawoos', 95000, 220000), ('Barista', 120000, 280000), ('KFC', 150000, 350000)],
    'transport': [('PickMe', 45000, 160000), ('Ceypetco Fuel', 500000, 1200000)],
    'utilities': [('Dialog', 250000, 400000), ('CEB Electricity', 350000, 850000), ('SLT Broadband', 390000, 390000)],
    'entertainment': [('Netflix', 149900, 149900), ('Spotify', 99900, 99900), ('Scope Cinemas', 200000, 450000)],
    'health': [('Healthguard Pharmacy', 80000, 300000), ('Fitness First Gym', 750000, 750000)],
    'shopping': [('Daraz', 150000, 800000), ('Fashion Bug', 250000, 600000)],
  };

  Future<int> seed(String uid, {String currency = 'LKR'}) async {
    final rng = Random(42); // deterministic → reproducible screenshots
    final now = DateTime.now();
    var batch = _firestore.batch();
    var ops = 0;
    var total = 0;

    Future<void> put(String path, Map<String, dynamic> data) async {
      batch.set(_firestore.doc(path), {...data, 'demo': true}, SetOptions(merge: true));
      ops++;
      total++;
      if (ops >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        ops = 0;
      }
    }

    String iso(DateTime d) => d.toUtc().toIso8601String();
    final root = 'users/$uid';

    // Accounts (bank, cash, card, savings)
    final accounts = <(String, String, String, int)>[
      ('demo_acc_bank', 'Commercial Bank', 'bank', 18450000),
      ('demo_acc_cash', 'Cash wallet', 'cash', 1250000),
      ('demo_acc_card', 'Visa credit card', 'card', -4520000),
      ('demo_acc_savings', 'NSB Savings', 'savings', 32500000),
    ];
    for (final (id, name, type, balance) in accounts) {
      await put('$root/accounts/$id', {
        'name': name, 'type': type, 'balanceMinor': balance,
        'currency': currency, 'archived': false, 'schemaVersion': 1,
      });
    }

    // 3 months of transactions: salary + freelance income, weighted expenses
    var txIndex = 0;
    for (var monthBack = 2; monthBack >= 0; monthBack--) {
      final monthStart = DateTime(now.year, now.month - monthBack, 1);
      // income
      await put('$root/transactions/demo_tx_${txIndex++}', {
        'clientId': 'demo_tx_salary_$monthBack', 'type': 'income',
        'amountMinor': 24500000, 'currency': currency, 'categoryId': 'salary',
        'accountId': 'demo_acc_bank', 'merchant': 'Acme Analytics (Pvt) Ltd',
        'note': 'Monthly salary', 'occurredAt': iso(monthStart.add(const Duration(days: 24))),
        'source': 'manual', 'schemaVersion': 1,
      });
      if (monthBack != 1) {
        await put('$root/transactions/demo_tx_${txIndex++}', {
          'clientId': 'demo_tx_freelance_$monthBack', 'type': 'income',
          'amountMinor': 3500000 + rng.nextInt(2000000), 'currency': currency,
          'categoryId': 'freelance', 'accountId': 'demo_acc_bank',
          'merchant': 'Upwork client', 'note': 'Dashboard project',
          'occurredAt': iso(monthStart.add(Duration(days: 8 + rng.nextInt(10)))),
          'source': 'manual', 'schemaVersion': 1,
        });
      }
      // expenses: 22-30 per month
      final txCount = 22 + rng.nextInt(9);
      final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
      final maxDay = monthBack == 0 ? now.day : daysInMonth;
      for (var i = 0; i < txCount; i++) {
        final catKeys = _merchants.keys.toList();
        final cat = catKeys[rng.nextInt(catKeys.length)];
        final options = _merchants[cat]!;
        final (merchant, lo, hi) = options[rng.nextInt(options.length)];
        final amount = lo + rng.nextInt(max(1, hi - lo + 1));
        final accountId = cat == 'utilities' || amount > 700000
            ? 'demo_acc_bank'
            : (rng.nextBool() ? 'demo_acc_cash' : 'demo_acc_card');
        await put('$root/transactions/demo_tx_${txIndex++}', {
          'clientId': 'demo_tx_c$txIndex', 'type': 'expense',
          'amountMinor': amount, 'currency': currency, 'categoryId': cat,
          'accountId': accountId, 'merchant': merchant, 'note': '',
          'occurredAt': iso(DateTime(monthStart.year, monthStart.month,
              1 + rng.nextInt(maxDay), 8 + rng.nextInt(12), rng.nextInt(60))),
          'source': 'manual', 'schemaVersion': 1,
        });
      }
    }

    // Budgets for the current month
    final periodKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    for (final (cat, limit) in [('groceries', 4500000), ('dining', 1500000), ('transport', 2500000), ('entertainment', 800000)]) {
      await put('$root/budgets/${cat}_$periodKey', {
        'categoryId': cat, 'periodKey': periodKey, 'limitMinor': limit,
        'currency': currency, 'alert80Sent': false, 'alert100Sent': false, 'schemaVersion': 1,
      });
    }

    // Goals with contribution history
    await put('$root/goals/demo_goal_emergency', {
      'name': 'Emergency fund', 'targetMinor': 75000000, 'savedMinor': 32500000,
      'currency': currency, 'iconKey': 'shield', 'archived': false, 'schemaVersion': 1,
      'contributions': [
        for (var m = 5; m >= 0; m--)
          {'amountMinor': 5000000 + rng.nextInt(1500000),
           'at': iso(DateTime(now.year, now.month - m, 26)), 'note': 'Monthly saving'},
      ],
    });
    await put('$root/goals/demo_goal_japan', {
      'name': 'Trip to Japan', 'targetMinor': 45000000, 'savedMinor': 12000000,
      'currency': currency, 'iconKey': 'flag', 'archived': false, 'schemaVersion': 1,
      'contributions': [
        for (var m = 3; m >= 0; m--)
          {'amountMinor': 3000000, 'at': iso(DateTime(now.year, now.month - m, 5)), 'note': ''},
      ],
    });

    // Recurring bills
    for (final (id, name, amount, cat, day) in [
      ('demo_bill_rent', 'Apartment rent', 8500000, 'housing', 1),
      ('demo_bill_electricity', 'CEB electricity', 650000, 'utilities', 12),
      ('demo_bill_internet', 'SLT broadband', 390000, 'utilities', 18),
    ]) {
      final nextDue = DateTime(now.year, now.month + (now.day >= day ? 1 : 0), day);
      await put('$root/bills/$id', {
        'name': name, 'amountMinor': amount, 'currency': currency,
        'categoryId': cat, 'recurrence': 'monthly',
        'anchorDate': iso(DateTime(now.year, now.month - 3, day)),
        'nextDueAt': iso(nextDue), 'autopay': false,
        'lastPaidAt': iso(DateTime(now.year, now.month - 1, day)), 'schemaVersion': 1,
      });
    }

    // Notifications
    for (final (i, (type, title, body)) in [
      ('budget', 'Dining budget at 82%', 'You have used most of this month\'s dining budget.'),
      ('bill', 'SLT broadband due soon', 'Rs 3,900.00 due in 3 days.'),
      ('nudge', 'Payday tomorrow', 'A good moment to review budgets and move savings first.'),
      ('ai', 'Monthly summary ready', 'Your spending review for last month is available.'),
      ('system', 'Welcome to FinGenius AI', 'Demo data loaded — explore every screen.'),
    ].indexed) {
      await put('$root/notifications/demo_notif_$i', {
        'type': type, 'title': title, 'body': body, 'read': i > 2,
        'createdAt': Timestamp.fromDate(now.subtract(Duration(hours: 6 * (i + 1)))),
        'payload': <String, dynamic>{},
      });
    }

    // Note: we deliberately do NOT write a marker onto users/{uid} — the
    // security rules lock that doc to a fixed key set. Idempotency comes from
    // the stable demo_* document ids used above.
    if (ops > 0) await batch.commit();
    return total;
  }

  /// Removes all demo-tagged data (demo: true) across all modules for this user.
  Future<int> clearDemoData(String uid) async {
    final root = 'users/$uid';
    final collections = ['accounts', 'transactions', 'budgets', 'goals', 'bills', 'notifications'];
    var deleted = 0;
    var batch = _firestore.batch();
    var ops = 0;

    for (final col in collections) {
      final snap = await _firestore.collection('$root/$col').where('demo', isEqualTo: true).get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        ops++;
        deleted++;
        if (ops >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          ops = 0;
        }
      }
    }

    if (ops > 0) await batch.commit();
    return deleted;
  }

  /// Checks if any demo-tagged data exists for this user.
  Future<bool> hasDemoData(String uid) async {
    final snap = await _firestore
        .collection('users/$uid/transactions')
        .where('demo', isEqualTo: true)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
