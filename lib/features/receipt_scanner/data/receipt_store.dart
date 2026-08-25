import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// What actually happened to a receipt, reported honestly so the UI can say so.
class ReceiptSaveOutcome {
  const ReceiptSaveOutcome({
    required this.receiptId,
    required this.imageUploaded,
    required this.imageHeldLocally,
    required this.metadataAcked,
  });

  final String receiptId;

  /// Bytes are in Cloud Storage.
  final bool imageUploaded;

  /// Bytes are safe on this device, waiting for a later upload attempt.
  final bool imageHeldLocally;

  /// Firestore confirmed the write. `false` means it is persisted in the
  /// SDK's offline cache and will sync — not that it was lost.
  final bool metadataAcked;

  /// Non-null when the user deserves to know the photo hasn't landed yet.
  String? get warning {
    if (imageUploaded) return null;
    if (imageHeldLocally) {
      return 'Saved. The receipt photo is stored on your device and will '
          'upload when the connection is available.';
    }
    return 'Saved, but the receipt photo could not be kept. The amount and '
        'date below are still recorded.';
  }
}

/// Compresses, persists and uploads receipt images.
///
/// Every remote call is bounded by a timeout. That is the whole point of this
/// class: `Storage.putData` and `DocumentReference.set` both return futures
/// that do **not** complete while the backend is unreachable or the project's
/// API is disabled, so awaiting them bare — as the review screen used to —
/// left the save button spinning forever with no way out.
///
/// Failure never discards the photo. Bytes are written to the app's documents
/// directory *before* the upload is attempted, and only deleted once the
/// upload succeeds, so a receipt survives being offline.
class ReceiptStore {
  ReceiptStore({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    this.uploadTimeout = const Duration(seconds: 25),
    this.metadataTimeout = const Duration(seconds: 8),
    this.compressTimeout = const Duration(seconds: 20),
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final Duration uploadTimeout;
  final Duration metadataTimeout;
  final Duration compressTimeout;

  static String storagePathFor(String uid, String receiptId) =>
      'receipts/$uid/$receiptId.jpg';

  /// Saves [source] as receipt [receiptId] for [uid], writing [metadata] to
  /// `users/{uid}/receipts/{receiptId}`.
  Future<ReceiptSaveOutcome> save({
    required File source,
    required String uid,
    required String receiptId,
    required Map<String, Object?> metadata,
  }) async {
    final bytes = await _compress(source);

    // 1. Local first — this is what makes the operation survive failure.
    File? held;
    if (bytes != null) {
      held = await _hold(uid: uid, receiptId: receiptId, bytes: bytes);
    }

    // 2. Upload, bounded.
    var uploaded = false;
    if (bytes != null) {
      uploaded = await _upload(uid: uid, receiptId: receiptId, bytes: bytes);
      if (uploaded && held != null) {
        try {
          await held.delete(); // now redundant; reclaim the space
        } catch (_) {}
        held = null;
      }
    }

    // 3. Metadata, bounded. A timeout here is a queued write, not a loss.
    final acked = await _writeMetadata(
      uid: uid,
      receiptId: receiptId,
      metadata: {
        ...metadata,
        if (uploaded) 'storagePath': storagePathFor(uid, receiptId),
        'pendingUpload': !uploaded && held != null,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    return ReceiptSaveOutcome(
      receiptId: receiptId,
      imageUploaded: uploaded,
      imageHeldLocally: held != null,
      metadataAcked: acked,
    );
  }

  /// Re-attempts every image still waiting locally. Safe to call often and
  /// cheap when the queue is empty — the queue *is* the directory listing, so
  /// no reads are needed to discover pending work.
  Future<int> retryPending(String uid) async {
    final dir = await _pendingDir();
    if (!await dir.exists()) return 0;
    var sent = 0;
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final parsed = _parseHeldName(entity.path);
      if (parsed == null || parsed.uid != uid) continue;
      final Uint8List bytes;
      try {
        bytes = await entity.readAsBytes();
      } catch (_) {
        continue;
      }
      final ok =
          await _upload(uid: uid, receiptId: parsed.receiptId, bytes: bytes);
      if (!ok) continue;
      sent++;
      try {
        await entity.delete();
      } catch (_) {}
      await _writeMetadata(
        uid: uid,
        receiptId: parsed.receiptId,
        metadata: {
          'storagePath': storagePathFor(uid, parsed.receiptId),
          'pendingUpload': false,
        },
      );
    }
    return sent;
  }

  // ── internals ─────────────────────────────────────────────────────────────

  /// Compressed JPEG bytes, falling back to the original file so a
  /// compressor failure (unusual formats, low memory) never costs the photo.
  Future<Uint8List?> _compress(File source) async {
    try {
      final out = await FlutterImageCompress.compressWithFile(
        source.absolute.path,
        quality: 70,
        minWidth: 1280,
      ).timeout(compressTimeout);
      if (out != null && out.isNotEmpty) return out;
    } catch (e) {
      debugPrint('Receipt compress failed, using original: $e');
    }
    try {
      return await source.readAsBytes();
    } catch (e) {
      debugPrint('Receipt bytes unreadable: $e');
      return null;
    }
  }

  Future<Directory> _pendingDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/receipts/pending');
  }

  Future<File?> _hold({
    required String uid,
    required String receiptId,
    required Uint8List bytes,
  }) async {
    try {
      final dir = await _pendingDir();
      await dir.create(recursive: true);
      final file = File('${dir.path}/${uid}__$receiptId.jpg');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('Could not hold receipt locally: $e');
      return null;
    }
  }

  ({String uid, String receiptId})? _parseHeldName(String path) {
    final name = path.split(Platform.pathSeparator).last;
    if (!name.endsWith('.jpg')) return null;
    final parts = name.substring(0, name.length - 4).split('__');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
    return (uid: parts[0], receiptId: parts[1]);
  }

  Future<bool> _upload({
    required String uid,
    required String receiptId,
    required Uint8List bytes,
  }) async {
    try {
      await _storage
          .ref(storagePathFor(uid, receiptId))
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(uploadTimeout);
      return true;
    } catch (e) {
      debugPrint('Receipt upload deferred: $e');
      return false;
    }
  }

  Future<bool> _writeMetadata({
    required String uid,
    required String receiptId,
    required Map<String, Object?> metadata,
  }) async {
    try {
      await _firestore
          .doc('users/$uid/receipts/$receiptId')
          .set(metadata, SetOptions(merge: true))
          .timeout(metadataTimeout);
      return true;
    } catch (e) {
      // Offline persistence has the write; it syncs on reconnect.
      debugPrint('Receipt metadata queued locally: $e');
      return false;
    }
  }
}
