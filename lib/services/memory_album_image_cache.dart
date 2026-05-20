import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/baby_memory.dart';
import '../utils/photo_b64.dart';
import 'memory_album_pdf_quality.dart';

/// Exceções específicas da exportação do álbum.
class MemoryAlbumCanceledException implements Exception {
  const MemoryAlbumCanceledException();
}

class MemoryAlbumNetworkException implements Exception {
  const MemoryAlbumNetworkException([this.message]);
  final String? message;
}

class MemoryAlbumStorageException implements Exception {
  const MemoryAlbumStorageException([this.message]);
  final String? message;
}

class MemoryAlbumImageCache {
  MemoryAlbumImageCache._();
  static final MemoryAlbumImageCache instance = MemoryAlbumImageCache._();

  String? _rootDir;

  Future<String> _root() async {
    if (_rootDir != null) return _rootDir!;
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'memory_album_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _rootDir = dir.path;
    return _rootDir!;
  }

  int _cacheKey(BabyMemory memory) =>
      memory.id ??
      Object.hash(memory.badgeId, memory.createdAt.millisecondsSinceEpoch);

  String _cacheFileName(int cacheKey, MemoryAlbumPdfQuality quality) =>
      'mem_${cacheKey}_${quality.fileSuffix}.jpg';

  Future<String> pathFor(BabyMemory memory, MemoryAlbumPdfQuality quality) async {
    final root = await _root();
    return p.join(root, _cacheFileName(_cacheKey(memory), quality));
  }

  Future<bool> hasCached(BabyMemory memory, MemoryAlbumPdfQuality quality) async {
    final file = File(await pathFor(memory, quality));
    if (!await file.exists()) return false;
    final len = await file.length();
    return len > 0;
  }

  /// Obtém bytes do cache em disco ou processa a partir da memória (rede/b64).
  Future<String?> ensureFile({
    required BabyMemory memory,
    required MemoryAlbumPdfQuality quality,
    required bool Function() isCanceled,
  }) async {
    if (isCanceled()) throw const MemoryAlbumCanceledException();

    final outPath = await pathFor(memory, quality);
    final existing = File(outPath);
    if (await existing.exists() && await existing.length() > 0) {
      return outPath;
    }

    final raw = await _loadRawBytes(memory, isCanceled: isCanceled);
    if (raw == null || raw.isEmpty) return null;

    final processed = await compute(
      _processImageInIsolate,
      _ProcessImageRequest(
        raw: raw,
        maxWidth: quality.maxImageWidth,
        jpegQuality: quality.jpegQuality,
      ),
    );

    if (isCanceled()) throw const MemoryAlbumCanceledException();

    try {
      await existing.writeAsBytes(processed, flush: true);
    } on FileSystemException catch (e) {
      throw MemoryAlbumStorageException(e.message);
    }
    return outPath;
  }

  Future<Uint8List?> _loadRawBytes(
    BabyMemory memory, {
    required bool Function() isCanceled,
  }) async {
    final b64 = decodePhotoB64(memory.photoB64);
    if (b64 != null && b64.isNotEmpty) return b64;

    final url = memory.photoUrl?.trim();
    if (url == null || url.isEmpty) return null;

    if (isCanceled()) throw const MemoryAlbumCanceledException();

    try {
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200 || r.bodyBytes.isEmpty) {
        return null;
      }
      return Uint8List.fromList(r.bodyBytes);
    } on http.ClientException {
      throw const MemoryAlbumNetworkException();
    } on SocketException {
      throw const MemoryAlbumNetworkException();
    }
  }
}

class _ProcessImageRequest {
  const _ProcessImageRequest({
    required this.raw,
    required this.maxWidth,
    required this.jpegQuality,
  });

  final Uint8List raw;
  final int maxWidth;
  final int jpegQuality;
}

Uint8List _processImageInIsolate(_ProcessImageRequest req) {
  try {
    final decoded = img.decodeImage(req.raw);
    if (decoded == null) {
      return req.raw;
    }
    img.Image out = decoded;
    if (decoded.width > req.maxWidth) {
      out = img.copyResize(
        decoded,
        width: req.maxWidth,
        interpolation: img.Interpolation.linear,
      );
    }
    return Uint8List.fromList(
      img.encodeJpg(out, quality: req.jpegQuality.clamp(50, 95)),
    );
  } catch (_) {
    return req.raw;
  }
}
