import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../utils/admin_photo_loader.dart';

/// Miniatura no painel admin — carrega via Firebase Storage (sem CORS do browser).
class AdminStorageImage extends StatefulWidget {
  const AdminStorageImage({
    super.key,
    this.data,
    this.httpsUrl,
    this.userId,
    this.babyId,
    this.badgeId,
    this.photoB64,
    this.publicMemoryDocId,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final Map<String, dynamic>? data;
  final String? httpsUrl;
  final String? userId;
  final String? babyId;
  final String? badgeId;
  final String? photoB64;
  final String? publicMemoryDocId;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  State<AdminStorageImage> createState() => _AdminStorageImageState();
}

class _AdminStorageImageState extends State<AdminStorageImage> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.httpsUrl != widget.httpsUrl ||
        oldWidget.userId != widget.userId ||
        oldWidget.babyId != widget.babyId ||
        oldWidget.badgeId != widget.badgeId ||
        oldWidget.photoB64 != widget.photoB64 ||
        oldWidget.publicMemoryDocId != widget.publicMemoryDocId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _bytes = null;
    });
    try {
      final bytes = await loadAdminPhotoBytes(
        data: widget.data,
        httpsUrl: widget.httpsUrl,
        userId: widget.userId,
        babyId: widget.babyId,
        badgeId: widget.badgeId,
        photoB64: widget.photoB64,
        publicMemoryDocId: widget.publicMemoryDocId,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_loading) {
      child = const Center(
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_bytes != null) {
      child = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    } else {
      child = Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: widget.width < 64 ? 24 : 36,
          color: Colors.black.withAlpha(90),
        ),
      );
    }

    final box = SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(12),
          borderRadius: widget.borderRadius,
        ),
        child: child,
      ),
    );

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: box);
    }
    return box;
  }
}
