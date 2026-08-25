import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Why a pick did not produce an image. The caller needs this distinction:
/// a cancelled pick is silent, a denied permission needs a prompt, and a
/// *permanently* denied one can only be resolved in system settings.
enum PickFailure {
  /// User backed out of the camera or picker. Not an error — say nothing.
  cancelled,

  /// Denied this time; asking again is allowed.
  permissionDenied,

  /// Denied with "don't ask again" (or blocked by policy). The only way
  /// forward is the system settings page, so offer to open it.
  permissionPermanentlyDenied,

  /// Device reports no usable camera (rare, and emulators without a
  /// configured camera back-end).
  noCamera,

  /// Picked, but the bytes could not be read as an image.
  unreadable,

  other,
}

/// Result of a capture attempt. Exactly one of [file] / [failure] is set.
class PickResult {
  const PickResult.success(this.file)
      : failure = null,
        message = null,
        diagnostic = null;
  const PickResult.failed(this.failure, this.message, {this.diagnostic})
      : file = null;

  final File? file;
  final PickFailure? failure;

  /// User-facing sentence. Never contains raw platform text.
  final String? message;

  /// Platform error code, kept for the debug console only — never shown.
  final String? diagnostic;

  bool get isSuccess => file != null;

  /// Whether the UI should offer an "Open settings" action.
  bool get needsSettings => failure == PickFailure.permissionPermanentlyDenied;
}

/// Camera / gallery acquisition for receipts, with the permission handling
/// that [ImagePicker] alone does not give us.
///
/// Two things matter here and both were previously wrong:
///
///  * **Camera needs an explicit runtime grant.** Because the manifest
///    declares `CAMERA`, Android refuses `ACTION_IMAGE_CAPTURE` until the
///    permission is granted — and once the user has picked "don't ask
///    again" the dialog never reappears, so the app must send them to
///    settings rather than silently failing forever.
///  * **Gallery needs no permission at all.** The system picker returns a
///    scoped URI, so requesting `READ_MEDIA_IMAGES`/`READ_EXTERNAL_STORAGE`
///    would prompt for storage access we neither declare nor need. We ask
///    for nothing and let the picker hand us the one file the user chose.
class ReceiptPicker {
  ReceiptPicker(
      {ImagePicker? picker, this.permissions = const _RealPermissions()})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final PermissionGate permissions;

  /// Wide enough that small print survives OCR, small enough to stay well
  /// inside the platform channel's comfort zone on cheap devices.
  static const _maxWidth = 2200.0;
  static const _quality = 92;

  Future<PickResult> fromCamera() async {
    final status = await permissions.ensureCamera();
    switch (status) {
      case CameraGrant.permanentlyDenied:
        return const PickResult.failed(
          PickFailure.permissionPermanentlyDenied,
          'Camera access is turned off for FinGenius. Open settings and allow '
          'Camera, then try again — or pick a photo from your gallery instead.',
        );
      case CameraGrant.denied:
        return const PickResult.failed(
          PickFailure.permissionDenied,
          'FinGenius needs the camera to photograph a receipt. Tap "Use '
          'camera" to allow it, or choose an existing photo instead.',
        );
      case CameraGrant.granted:
        break;
    }
    return _pick(ImageSource.camera);
  }

  /// No permission request: the system picker grants access to just the
  /// chosen image.
  Future<PickResult> fromGallery() => _pick(ImageSource.gallery);

  Future<PickResult> _pick(ImageSource source) async {
    final isCamera = source == ImageSource.camera;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: _maxWidth,
        imageQuality: _quality,
        // EXIF/location is irrelevant to OCR and requesting it drags in the
        // media-permission path on Android. Off is both leaner and more private.
        requestFullMetadata: false,
      );
      if (picked == null) {
        return const PickResult.failed(PickFailure.cancelled, null);
      }
      final file = File(picked.path);
      if (!await file.exists() || await file.length() == 0) {
        return const PickResult.failed(
          PickFailure.unreadable,
          'That image could not be read. Try taking the photo again, or enter '
          'the details manually.',
        );
      }
      return PickResult.success(file);
    } on PlatformException catch (e) {
      return _mapPlatformError(e, isCamera: isCamera);
    } catch (e) {
      debugPrint('ReceiptPicker unexpected error: $e');
      return PickResult.failed(
        PickFailure.other,
        isCamera
            ? 'The camera could not be opened. Try again, or pick a photo from '
                'your gallery instead.'
            : 'That photo could not be opened. Try a different one, or enter '
                'the details manually.',
        diagnostic: '$e',
      );
    }
  }

  /// Maps `image_picker`'s documented Android/iOS error codes onto messages
  /// that tell the user what to actually do.
  PickResult _mapPlatformError(PlatformException e, {required bool isCamera}) {
    debugPrint('ReceiptPicker PlatformException(${e.code}): ${e.message}');
    return switch (e.code) {
      'camera_access_denied' => const PickResult.failed(
          PickFailure.permissionPermanentlyDenied,
          'Camera access is turned off for FinGenius. Open settings and allow '
          'Camera, then try again — or pick a photo from your gallery instead.',
        ),
      'photo_access_denied' => const PickResult.failed(
          PickFailure.permissionPermanentlyDenied,
          'Photo access is turned off for FinGenius. Open settings and allow '
          'Photos, then try again.',
        ),
      'no_available_camera' => const PickResult.failed(
          PickFailure.noCamera,
          'This device has no camera available. Pick a photo from your gallery '
          'instead.',
        ),
      'already_active' => const PickResult.failed(
          PickFailure.other,
          'A photo is already being picked. Finish that first.',
        ),
      'invalid_image' || 'invalid_source' => const PickResult.failed(
          PickFailure.unreadable,
          'That file is not a supported image. Choose a JPG or PNG photo.',
        ),
      _ => PickResult.failed(
          PickFailure.other,
          isCamera
              ? 'The camera could not be opened. Try again, or pick a photo '
                  'from your gallery instead.'
              : 'That photo could not be opened. Try a different one, or enter '
                  'the details manually.',
          diagnostic: e.code,
        ),
    };
  }

  Future<void> openSettings() => permissions.openSettings();
}

enum CameraGrant { granted, denied, permanentlyDenied }

/// Seam so tests can exercise every branch without a platform channel.
abstract class PermissionGate {
  Future<CameraGrant> ensureCamera();
  Future<void> openSettings();
}

class _RealPermissions implements PermissionGate {
  const _RealPermissions();

  @override
  Future<CameraGrant> ensureCamera() async {
    var status = await Permission.camera.status;
    // `denied` covers both "never asked" and "asked and refused", so always
    // give the OS a chance to show the dialog; it is a no-op when the user
    // has permanently denied, and request() then reports that explicitly.
    if (!status.isGranted) status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) return CameraGrant.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraGrant.permanentlyDenied;
    }
    return CameraGrant.denied;
  }

  @override
  Future<void> openSettings() => openAppSettings();
}
