import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'memory_badge_icon.dart';

/// Gestor de cache em disco para URLs de fotos de memórias (grelha, detalhe, edição).
final CacheManager memoryPhotoCacheManager = CacheManager(
  Config(
    'facebaby_memory_photos_v1',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 500,
  ),
);

/// [ImageProvider] com cache (ex.: [PhotoView], [DecorationImage]).
ImageProvider<Object> memoryPhotoNetworkImageProvider(String url) {
  return CachedNetworkImageProvider(
    url,
    cacheManager: memoryPhotoCacheManager,
  );
}

/// Miniatura ou preview com cache; substitui [Image.network] nas memórias.
class CachedMemoryPhoto extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final void Function(String url, Object error)? onError;

  const CachedMemoryPhoto({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.placeholder,
    this.errorWidget,
    this.onError,
  });

  static Widget _defaultPlaceholder(BuildContext context, String url) {
    return ColoredBox(
      color: MemoryBadgeIcon.mutedDiskBackground.withAlpha(200),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  static Widget _defaultError(BuildContext context, String url, Object error) {
    return ColoredBox(
      color: MemoryBadgeIcon.mutedDiskBackground,
      child: Center(
        child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.black.withAlpha(100)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: memoryPhotoCacheManager,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      fadeInDuration: const Duration(milliseconds: 140),
      fadeOutDuration: Duration.zero,
      placeholder: placeholder ?? _defaultPlaceholder,
      errorWidget: (context, url, error) {
        onError?.call(url, error);
        if (errorWidget != null) {
          return errorWidget!(context, url, error);
        }
        return _defaultError(context, url, error);
      },
    );
  }
}
