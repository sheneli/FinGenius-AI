import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/config/session_providers.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// End-to-end profile-avatar pipeline:
/// pick (camera/gallery) → crop (square) → compress → upload to Firebase
/// Storage → persist download URL on the user doc → old image cleaned up.
/// Every step returns a typed [Result]; nothing here throws to the UI.
class AvatarService {
  AvatarService({
    required this.uid,
    required this.firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  final String uid;
  final FirebaseFirestore firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  /// Picks + crops + compresses an image. Returns null only when the user
  /// genuinely cancelled at the picker.
  ///
  /// The crop step is deliberately **best-effort**. uCrop runs as a separate
  /// Activity and can close without returning a result — a device-specific
  /// failure looks identical to a cancel from Dart's side. The old code treated
  /// any null crop as a cancel and returned silently, so the photo the user had
  /// just chosen was discarded with no upload, no error and no explanation.
  /// That is the "profile image does not work" report: the picker and cropper
  /// both opened, then nothing happened at all.
  ///
  /// Now a failed crop falls through to the picked image, which `pickImage`
  /// has already capped at 1024px and which the compression pass below squares
  /// off anyway. A cancel at the *picker* still aborts, because that is an
  /// unambiguous "no".
  Future<Result<File?>> pickAndPrepare(ImageSource source) => guard(() async {
        final picked = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 92,
        );
        if (picked == null) return null; // cancelled before choosing anything

        final sourcePath = await _cropOrFallback(picked.path);

        // Compress to a small square (avatars never need to be large).
        final dir = await getTemporaryDirectory();
        final target =
            '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final result = await FlutterImageCompress.compressAndGetFile(
          sourcePath,
          target,
          quality: 80,
          minWidth: 512,
          minHeight: 512,
        );
        return result == null ? File(sourcePath) : File(result.path);
      }, onError: (e, _) => const StorageFailure(
          "Couldn't prepare that image. Try another photo.", cause: null));

  /// Returns the cropped path, or the original when cropping is unavailable.
  Future<String> _cropOrFallback(String sourcePath) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
        ],
      );
      if (cropped != null) return cropped.path;
      debugPrint('Avatar crop returned no result — using the picked image');
    } catch (e) {
      // Never let a cropper problem cost the user their photo.
      debugPrint('Avatar crop unavailable: ${e.runtimeType}');
    }
    return sourcePath;
  }

  /// Uploads [file] to Storage and writes the URL to Firestore.
  /// [onProgress] reports 0..1. Old avatar files are removed afterwards.
  Future<Result<String>> uploadAndSave(File file, {void Function(double)? onProgress}) =>
      guard(() async {
        final ref = _storage.ref('profile_images/$uid/avatar.jpg');
        final task = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        task.snapshotEvents.listen((s) {
          if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
        });
        await task;
        // Cache-bust so the new image shows immediately.
        final url = '${await ref.getDownloadURL()}&v=${DateTime.now().millisecondsSinceEpoch}';
        await firestore.doc('users/$uid').set(
          {'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        try {
          await file.delete();
        } catch (_) {/* temp cleanup best-effort */}
        return url;
      }, onError: (e, _) => const StorageFailure(
          'Upload failed. Check your connection and try again.', cause: null));

  /// Removes the avatar from Storage and clears the URL on the user doc.
  Future<Result<void>> remove() => guard(() async {
        try {
          await _storage.ref('profile_images/$uid/avatar.jpg').delete();
        } on FirebaseException {
          // already gone — clearing the URL is what matters
        }
        await firestore.doc('users/$uid').set(
          {'photoUrl': FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }, onError: (e, _) => const StorageFailure('Could not remove the photo.', cause: null));
}

final avatarServiceProvider = Provider<AvatarService?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return AvatarService(uid: uid, firestore: ref.watch(firestoreProvider));
});
