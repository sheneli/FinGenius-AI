import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../../core/data/owned_collection_repository.dart';
import '../../core/data/pending_queue.dart';
import '../../core/storage/hive_boxes.dart';
import '../../features/accounts/domain/account.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/bills/domain/bill.dart';
import '../../features/budgets/domain/budget.dart';
import '../../features/goals/domain/goal.dart';
import '../../features/profile/domain/user_profile.dart';
import '../../features/transactions/domain/category.dart';
import '../../features/transactions/domain/transaction_entry.dart';

/// Session wiring: everything downstream of "who is signed in".
final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

/// Opens the per-user Hive boxes; disposed providers close nothing — boxes are
/// closed and wiped explicitly on logout via [SessionCleaner].
final userBoxesProvider = FutureProvider<({Box<Map<dynamic, dynamic>> cache, Box<Map<dynamic, dynamic>> queue, Box<dynamic> meta})>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('No signed-in user');
  return (cache: await HiveBoxes.cache(uid), queue: await HiveBoxes.queue(uid), meta: await HiveBoxes.meta(uid));
});

final pendingQueueProvider = Provider<PendingQueue?>((ref) {
  final uid = ref.watch(currentUidProvider);
  final boxes = ref.watch(userBoxesProvider).valueOrNull;
  if (uid == null || boxes == null) return null;
  final queue = PendingQueue(
    box: boxes.queue,
    firestore: ref.watch(firestoreProvider),
    userRoot: 'users/$uid',
  );
  // Drain writes queued in previous sessions (e.g. while offline) as soon as
  // the session is ready — nothing else triggers a flush until the next write.
  unawaited(queue.flush());
  ref.onDispose(queue.dispose);
  return queue;
});

OwnedCollectionRepository<T>? _repo<T>(
  Ref ref,
  String collection,
  T Function(String, Map<String, dynamic>) fromMap,
  Map<String, dynamic> Function(T) toMap,
) {
  final uid = ref.watch(currentUidProvider);
  final boxes = ref.watch(userBoxesProvider).valueOrNull;
  final queue = ref.watch(pendingQueueProvider);
  if (uid == null || boxes == null || queue == null) return null;
  return OwnedCollectionRepository<T>(
    uid: uid,
    collection: collection,
    fromMap: fromMap,
    toMap: toMap,
    firestore: ref.watch(firestoreProvider),
    cache: boxes.cache,
    queue: queue,
  );
}

final accountsRepoProvider = Provider<OwnedCollectionRepository<Account>?>(
  (ref) => _repo(ref, 'accounts', Account.fromMap, (a) => a.toMap()),
);
final transactionsRepoProvider = Provider<OwnedCollectionRepository<TransactionEntry>?>(
  (ref) => _repo(ref, 'transactions', TransactionEntry.fromMap, (t) => t.toMap()),
);
final categoriesRepoProvider = Provider<OwnedCollectionRepository<Category>?>(
  (ref) => _repo(ref, 'categories', Category.fromMap, (c) => c.toMap()),
);
final budgetsRepoProvider = Provider<OwnedCollectionRepository<Budget>?>(
  (ref) => _repo(ref, 'budgets', Budget.fromMap, (b) => b.toMap()),
);
final goalsRepoProvider = Provider<OwnedCollectionRepository<Goal>?>(
  (ref) => _repo(ref, 'goals', Goal.fromMap, (g) => g.toMap()),
);
final billsRepoProvider = Provider<OwnedCollectionRepository<Bill>?>(
  (ref) => _repo(ref, 'bills', Bill.fromMap, (b) => b.toMap()),
);

/// User profile doc (users/{uid}) — separate from subcollections.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .doc('users/$uid')
      .snapshots()
      .map((snap) => snap.exists ? UserProfile.fromMap(uid, snap.data()!) : null);
});

/// Logout hygiene: closes and wipes per-user local data.
class SessionCleaner {
  const SessionCleaner();
  Future<void> onLogout(String uid) => HiveBoxes.clearUser(uid);
}

final sessionCleanerProvider = Provider<SessionCleaner>((_) => const SessionCleaner());
