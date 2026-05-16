import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/photo_b64.dart';

final CacheManager profilePhotoCacheManager = CacheManager(
  Config(
    'facebaby_profile_photos_v1',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 80,
  ),
);

/// Avatar circular com foto em base64, [photoUrl] (rede), ou [fallback].
///
/// Ordem: base64 → URL → fallback. O cache estático evita decodificar novamente
/// as fotos da mãe/bebê a cada rebuild da Home.
class PhotoAvatar extends StatelessWidget {
  static const int _maxMemoryImages = 12;
  static final LinkedHashMap<String, MemoryImage> _memoryImages =
      LinkedHashMap<String, MemoryImage>();

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

  static MemoryImage? _memoryImageFor(String? rawB64) {
    final key = rawB64?.trim();
    if (key == null || key.isEmpty) return null;

    final cached = _memoryImages.remove(key);
    if (cached != null) {
      _memoryImages[key] = cached;
      return cached;
    }

    final bytes = decodePhotoB64(key);
    if (bytes == null) return null;
    final image = MemoryImage(bytes);
    _memoryImages[key] = image;
    while (_memoryImages.length > _maxMemoryImages) {
      _memoryImages.remove(_memoryImages.keys.first);
    }
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final urlKey = photoUrl?.trim() ?? '';

    final memoryImage = _memoryImageFor(photoB64);
    if (memoryImage != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        backgroundImage: memoryImage,
      );
    }

    if (urlKey.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: ClipOval(
          child: SizedBox.square(
            dimension: radius * 2,
            child: CachedNetworkImage(
              imageUrl: urlKey,
              cacheManager: profilePhotoCacheManager,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              fadeOutDuration: Duration.zero,
              errorWidget: (_, __, ___) => SizedBox.square(
                dimension: radius * 2,
                child: Center(child: fallback),
              ),
              placeholder: (context, _) {
                final h = radius * 2;
                return SizedBox(
                  height: h,
                  width: h,
                  child: Center(
                    child: SizedBox(
                      height: radius,
                      width: radius,
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
      radius: radius,
      backgroundColor: backgroundColor,
      child: fallback,
    );
  }
}
