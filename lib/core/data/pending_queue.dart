import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_ce/hive.dart';

/// A queued offline write. Idempotent: ops are keyed by `opId` and applied as
/// merge-sets / deletes, so replays are safe.
class PendingOp {
  const PendingOp({
    required this.opId,
    required this.collection,
    required this.docId,
    required this.kind, // 'set' | 'delete'
    required this.data,
    required this.createdAt,
    this.attempts = 0,
  });

  final String opId;
  final String collection;
  final String docId;
  final String kind;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int attempts;

  Map<String, dynamic> toMap() => {
        'opId': opId, 'collection': collection, 'docId': docId, 'kind': kind,
        'data': data, 'createdAt': createdAt.toIso8601String(), 'attempts': attempts,
      };

  static PendingOp fromMap(Map<dynamic, dynamic> m) => PendingOp(
        opId: m['opId'] as String,
        collection: m['collection'] as String,
        docId: m['docId'] as String,
        kind: m['kind'] as String,
        data: Map<String, dynamic>.from(m['data'] as Map),
        createdAt: DateTime.parse(m['createdAt'] as String),
        attempts: (m['attempts'] as num?)?.toInt() ?? 0,
      );

  PendingOp bumpAttempts() => PendingOp(
        opId: opId, collection: collection, docId: docId, kind: kind,
        data: data, createdAt: createdAt, attempts: attempts + 1,
      );
}

/// Flushes the queue to Firestore with exponential backoff. Emits queue size
/// so the UI can show "N changes waiting to sync".
class PendingQueue {
  PendingQueue({required this.box, required this.firestore, required this.userRoot});

  final Box<Map<dynamic, dynamic>> box;
  final FirebaseFirestore firestore;
  final String userRoot; // users/{uid}

  final _sizeController = StreamController<int>.broadcast();
  Stream<int> get size => _sizeController.stream;
  int get currentSize => box.length;
  bool _flushing = false;

  /// Firestore write futures only complete on server ack; this cap stops one
  /// slow or hung op from holding [_flushing] forever and silently blocking
  /// every write queued after it.
  static const _opTimeout = Duration(seconds: 15);

  Future<void> enqueue(PendingOp op) async {
    await box.put(op.opId, op.toMap());
    _sizeController.add(box.length);
    unawaited(flush());
  }

  /// Set of docIds with pending writes for a given collection (UI badges).
  Set<String> pendingDocIds(String collection) => box.values
      .map(PendingOp.fromMap)
      .where((op) => op.collection == collection)
      .map((op) => op.docId)
      .toSet();

  /// Set of docIds with pending set/upsert writes.
  Set<String> pendingSets(String collection) => box.values
      .map(PendingOp.fromMap)
      .where((op) => op.collection == collection && op.kind == 'set')
      .map((op) => op.docId)
      .toSet();

  /// Set of docIds with pending delete writes.
  Set<String> pendingDeletes(String collection) => box.values
      .map(PendingOp.fromMap)
      .where((op) => op.collection == collection && op.kind == 'delete')
      .map((op) => op.docId)
      .toSet();

  /// Attempts to push all queued ops. Safe to call repeatedly.
  Future<void> flush() async {
    if (_flushing || box.isEmpty) return;
    _flushing = true;
    try {
      final ops = box.values.map(PendingOp.fromMap).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final op in ops) {
        try {
          final ref = firestore.doc('$userRoot/${op.collection}/${op.docId}');
          if (op.kind == 'delete') {
            await ref.delete().timeout(_opTimeout);
          } else {
            await ref
                .set(
                  {...op.data, 'updatedAt': FieldValue.serverTimestamp()},
                  SetOptions(merge: true),
                )
                .timeout(_opTimeout);
          }
          await box.delete(op.opId);
          _sizeController.add(box.length);
        } on TimeoutException {
          developer.log(
              'flush timed out: ${op.collection}/${op.docId} '
              '(attempt ${op.attempts + 1}) — will retry',
              name: 'PendingQueue');
          await _backOff(op);
          break;
        } on FirebaseException catch (e) {
          developer.log(
              'flush failed: ${op.collection}/${op.docId} code=${e.code}',
              name: 'PendingQueue');
          if (e.code == 'permission-denied' || e.code == 'invalid-argument') {
            // Poison op — drop it rather than blocking the queue forever.
            await box.delete(op.opId);
            _sizeController.add(box.length);
            continue;
          }
          // Transient (offline/unavailable): back off and stop this pass.
          await _backOff(op);
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _backOff(PendingOp op) async {
    final bumped = op.bumpAttempts();
    await box.put(op.opId, bumped.toMap());
    final delay =
        Duration(seconds: math.min(60, math.pow(2, bumped.attempts).toInt()));
    Future<void>.delayed(delay, flush);
  }

  void dispose() => _sizeController.close();
}
