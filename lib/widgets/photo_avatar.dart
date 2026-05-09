import 'package:flutter/material.dart';

import '../utils/photo_b64.dart';

/// Avatar circular com foto em base64, [photoUrl] (rede), ou [fallback].
///
/// Ordem: base64 → URL → fallback. Mantém a mesma instância de [MemoryImage]
/// enquanto [photoB64] não muda (ex.: timer da home).
class PhotoAvatar extends StatefulWidget {
  final String? photoB64;
  final String? photoUrl;
  final double radius;
  final Color backgroundColor;
  final Widget fallback;

  const PhotoAvatar({
    super.key,
    required this.photoB64,
    this.photoUrl,
    required this.radius,
    required this.backgroundColor,
    required this.fallback,
  });

  @override
  State<PhotoAvatar> createState() => _PhotoAvatarState();
}

class _PhotoAvatarState extends State<PhotoAvatar> {
  MemoryImage? _memoryImage;
  String? _cachedB64Key;

  @override
  Widget build(BuildContext context) {
    final urlKey = widget.photoUrl?.trim() ?? '';

    final b64Key = widget.photoB64?.trim() ?? '';
    final bytes = decodePhotoB64(widget.photoB64);
    if (bytes != null) {
      if (_cachedB64Key != b64Key) {
        _cachedB64Key = b64Key;
        _memoryImage = MemoryImage(bytes);
      }
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor,
        backgroundImage: _memoryImage,
      );
    }
    _cachedB64Key = null;
    _memoryImage = null;

    if (urlKey.isNotEmpty) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor,
        child: ClipOval(
          child: SizedBox.square(
            dimension: widget.radius * 2,
            child: Image.network(
              urlKey,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => SizedBox.square(
                dimension: widget.radius * 2,
                child: Center(child: widget.fallback),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                final h = widget.radius * 2;
                return SizedBox(
                  height: h,
                  width: h,
                  child: Center(
                    child: SizedBox(
                      height: widget.radius,
                      width: widget.radius,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      child: widget.fallback,
    );
  }
}
