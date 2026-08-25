import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/tokens.dart';
import '../data/avatar_service.dart';

/// Circular profile avatar with a camera overlay button and full image
/// management. Shows a cached network image, a coloured initial fallback,
/// and a live upload-progress ring. Locally cached so it renders instantly.
class ProfileAvatar extends ConsumerStatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.initial,
    this.size = 96,
    this.editable = true,
  });

  final String? photoUrl;
  final String initial;
  final double size;
  final bool editable;

  @override
  ConsumerState<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<ProfileAvatar> {
  bool _busy = false;
  double _progress = 0;

  Future<void> _pick(ImageSource source) async {
    final service = ref.read(avatarServiceProvider);
    if (service == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    final prepared = await service.pickAndPrepare(source);
    final file = prepared.valueOrNull;
    if (prepared.failureOrNull != null) {
      _snack(prepared.failureOrNull!.message);
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (file == null) {
      if (mounted) setState(() => _busy = false); // user cancelled
      return;
    }
    final uploaded = await service.uploadAndSave(
      file,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    uploaded.when(
      ok: (_) => _snack('Profile photo updated'),
      err: (f) => _snack(f.message),
    );
  }

  Future<void> _remove() async {
    final service = ref.read(avatarServiceProvider);
    if (service == null) return;
    setState(() => _busy = true);
    final r = await service.remove();
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(ok: (_) => _snack('Photo removed'), err: (f) => _snack(f.message));
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: FgTokens.s3),
            Text('Profile photo', style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: FgTokens.s2),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(ImageSource.gallery);
              },
            ),
            if (widget.photoUrl != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(sheetContext).colorScheme.error),
                title: Text('Remove photo',
                    style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _remove();
                },
              ),
            const SizedBox(height: FgTokens.s4),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: FgTokens.growthGradient,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: widget.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: widget.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _initialFallback(size),
                      errorWidget: (_, __, ___) => _initialFallback(size),
                    )
                  : _initialFallback(size),
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ClipOval(
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: size * 0.4,
                    height: size * 0.4,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      value: _progress > 0 && _progress < 1 ? _progress : null,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.editable && !_busy)
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _showOptions,
                  child: Padding(
                    padding: EdgeInsets.all(size * 0.06),
                    child: Icon(Icons.photo_camera, size: size * 0.18, color: Colors.black87),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialFallback(double size) => Container(
        alignment: Alignment.center,
        color: Colors.black.withValues(alpha: 0.15),
        child: Text(
          widget.initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
}
