import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import 'pending_queue.dart';

/// Generic repository for a user-owned Firestore subcollection with an
/// offline-first contract:
///  * reads: Firestore snapshots (server truth) mirrored into Hive; when the
///    stream errors or on cold offline start, the Hive mirror is served
///  * writes: optimistic Hive write + queued op (idempotent merge-set/delete)
///  * conflicts: last-write-wins on `updatedAt` (server timestamp); deletes win
class OwnedCollectionRepository<T> {
  OwnedCollectionRepository({
    required this.uid,
    required this.collection,
    required this.fromMap,
    required this.toMap,
    required this.firestore,
    required this.cache,
    required this.queue,
  });

  final String uid;
  final String collection;
  final T Function(String id, Map<String, dynamic> data) fromMap;
  final Map<String, dynamic> Function(T entity) toMap;
  final FirebaseFirestore firestore;
  final Box<Map<dynamic, dynamic>> cache;
  final PendingQueue queue;

  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _ref =>
      firestore.collection('users/$uid/$collection');

  String _cacheKey(String docId) => '$collection/$docId';

  /// Live list. Emits the local mirror immediately (fast, offline-safe), then
  /// server snapshots as they arrive. Optimistic writes stay visible: every
  /// emission merges cache entries that are still waiting in the pending
  /// queue, and queue-size changes re-emit — so a record saved a moment ago
  /// appears instantly instead of only after the server acknowledges it.
  Stream<List<T>> watchAll({Query<Map<String, dynamic>> Function(CollectionReference<Map<String, dynamic>>)? build}) {
    final controller = StreamController<List<T>>();
    List<(String, Map<String, dynamic>)>? serverDocs;

    void emit() {
      if (controller.isClosed) return;
      final pendingSet = queue.pendingSets(collection);
      final pendingDel = queue.pendingDeletes(collection);
      if (serverDocs == null) {
        controller.add(_readCache(excludedIds: pendingDel));
        return;
      }
      final serverIds = serverDocs!.map((d) => d.$1).toSet();
      final merged = <T>[
        for (final (id, data) in serverDocs!)
          if (!pendingDel.contains(id)) fromMap(id, data),
        // Optimistic: queued writes the server has not confirmed yet.
        for (final id in pendingSet)
          if (!serverIds.contains(id) && !pendingDel.contains(id) && cache.get(_cacheKey(id)) != null)
            fromMap(id, Map<String, dynamic>.from(cache.get(_cacheKey(id))!)),
      ];
      controller.add(merged);
    }

    controller.add(_readCache());

    final query = build?.call(_ref) ?? _ref;
    final snapSub = query.snapshots(includeMetadataChanges: true).listen(
      (snap) {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.removed) {
            cache.delete(_cacheKey(change.doc.id));
          } else {
            cache.put(_cacheKey(change.doc.id), _sanitize(change.doc.data()!));
          }
        }
        serverDocs = [for (final d in snap.docs) (d.id, d.data())];
        emit();
      },
      onError: (Object _) => controller.add(_readCache()),
    );
    // Re-emit when queued writes are added or land, so optimistic entries
    // appear/settle without waiting for a fresh server snapshot.
    final queueSub = queue.size.listen((_) => emit());
    controller.onCancel = () async {
      await snapSub.cancel();
      await queueSub.cancel();
    };
    return controller.stream;
  }

  Future<T?> getById(String docId) async {
    try {
      final doc = await _ref.doc(docId).get();
      if (doc.exists) return fromMap(doc.id, doc.data()!);
    } on FirebaseException {
      // fall through to cache
    }
    final cached = cache.get(_cacheKey(docId));
    return cached == null ? null : fromMap(docId, Map<String, dynamic>.from(cached));
  }

  /// Creates or updates. Returns the document id.
  Future<String> upsert(T entity, {String? docId}) async {
    final id = docId ?? _uuid.v4();
    final data = toMap(entity);
    await cache.put(_cacheKey(id), data);
    await queue.enqueue(PendingOp(
      opId: _uuid.v4(),
      collection: collection,
      docId: id,
      kind: 'set',
      data: data,
      createdAt: DateTime.now(),
    ));
    return id;
  }

  Future<void> delete(String docId) async {
    await cache.delete(_cacheKey(docId));
    await queue.enqueue(PendingOp(
      opId: _uuid.v4(),
      collection: collection,
      docId: docId,
      kind: 'delete',
      data: const {},
      createdAt: DateTime.now(),
    ));
  }

  Set<String> pendingDocIds() => queue.pendingDocIds(collection);

  List<T> _readCache({Set<String>? excludedIds}) {
    final prefix = '$collection/';
    final out = <T>[];
    for (final key in cache.keys.whereType<String>()) {
      if (!key.startsWith(prefix)) continue;
      final docId = key.substring(prefix.length);
      if (excludedIds != null && excludedIds.contains(docId)) continue;
      final data = cache.get(key);
      if (data != null) {
        out.add(fromMap(docId, Map<String, dynamic>.from(data)));
      }
    }
    return out;
  }

  /// Firestore Timestamps are not Hive-serialisable — convert defensively.
  static Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) {
      out[k] = v is Timestamp ? v.toDate().toIso8601String() : v;
    });
    return out;
  }
}
