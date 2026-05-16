import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  FirebaseStorage get _storage => FirebaseStorage.instance;

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Usuário não autenticado');
    return uid;
  }

  Future<String> uploadBabyPhotoBytes({
    required String babyId,
    required Uint8List bytes,
    required String fileExt, // ex: "jpg" | "png"
  }) async {
    final path = 'users/$_uid/babies/$babyId/photo.$fileExt';
    return _uploadWithRetry(path: path, bytes: bytes, fileExt: fileExt);
  }

  Future<String> uploadMotherPhotoBytes({
    required String motherId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    // New schema: profile photo is stored at users/{uid}/profile/photo.ext
    // Keep the method name/signature for backward compatibility.
    final path = 'users/$_uid/profile/photo.$fileExt';
    return _uploadWithRetry(path: path, bytes: bytes, fileExt: fileExt);
  }

  Future<String> uploadFatherPhotoBytes({
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final path = 'users/$_uid/profile/father_photo.$fileExt';
    return _uploadWithRetry(path: path, bytes: bytes, fileExt: fileExt);
  }

  Future<String> uploadMemoryPhotoBytes({
    required String babyId,
    required String badgeId,
    required Uint8List bytes,
    required String fileExt,
    String? versionToken,
  }) async {
    // IMPORTANT: usar caminho versionado para evitar cache agressivo (URL igual) ao trocar a foto do badge.
    final v = (versionToken ?? '').trim();
    final suffix = v.isEmpty ? '' : '_$v';
    final path = 'users/$_uid/babies/$babyId/memories/$badgeId$suffix.$fileExt';
    return _uploadWithRetry(path: path, bytes: bytes, fileExt: fileExt);
  }

  Future<String> _uploadWithRetry({
    required String path,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final ref = _storage.ref(path);
    final compressed = await _compressIfImage(bytes: bytes, fileExt: fileExt);
    final meta = SettableMetadata(
      contentType: _contentTypeForExt(fileExt),
      cacheControl: 'no-cache',
    );

    Object? lastErr;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await ref.putData(compressed, meta);
        return await ref.getDownloadURL();
      } on FirebaseException catch (e) {
        lastErr = e;
        // Erro comum em Android: sessão de upload resumível termina e o SDK tenta retomar em URL 404.
        final retryable = e.code == 'object-not-found' ||
            e.code == 'retry-limit-exceeded' ||
            e.code == 'unknown' ||
            e.code == 'canceled';
        debugPrint('Storage upload failed attempt=$attempt code=${e.code} path=$path');
        if (!retryable || attempt == 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      } catch (e) {
        lastErr = e;
        if (attempt == 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
    throw lastErr ?? StateError('Storage upload failed: $path');
  }

  Future<Uint8List> _compressIfImage({
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final e = fileExt.toLowerCase().replaceAll('.', '');

    // Primeiro: redimensiona para um tamanho "otimizado" (maior lado).
    // Isso reduz muito upload/armazenamento e evita imagens gigantes no perfil/badges.
    final resized = _resizeIfNeeded(bytes: bytes, fileExt: e, maxSide: 1080);

    // Web: faz só o resize (encode) e retorna.
    if (kIsWeb) return resized;

    // Só comprime se tiver tamanho "significativo" para evitar perder qualidade à toa.
    if (resized.lengthInBytes < 220 * 1024) return resized;

    try {
      // Preferimos JPEG para perfis/badges (fotos). Se for PNG (ícone/screenshot),
      // ainda comprimimos mantendo formato.
      final isJpg = e == 'jpg' || e == 'jpeg';
      final isPng = e == 'png';
      if (!isJpg && !isPng) return resized;

      final format = isPng ? CompressFormat.png : CompressFormat.jpeg;

      // 72–82 é um bom trade-off para fotos de perfil em mobile.
      final out = await FlutterImageCompress.compressWithList(
        resized,
        quality: 78,
        format: format,
        keepExif: false,
      );

      final outBytes = Uint8List.fromList(out);
      // Se por algum motivo "aumentar" ou ficar muito pequeno/ruim, volta no original.
      if (outBytes.isEmpty) return resized;
      if (outBytes.lengthInBytes >= resized.lengthInBytes) return resized;
      return outBytes;
    } catch (e) {
      debugPrint('Image compress failed: $e');
      return resized;
    }
  }

  Uint8List _resizeIfNeeded({
    required Uint8List bytes,
    required String fileExt,
    required int maxSide,
  }) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      final w = decoded.width;
      final h = decoded.height;
      final biggest = w > h ? w : h;
      if (biggest <= maxSide) return bytes;

      final resized = img.copyResize(
        decoded,
        width: w >= h ? maxSide : null,
        height: h > w ? maxSide : null,
        interpolation: img.Interpolation.cubic,
      );

      // Mantém formato quando possível. Para fotos comuns, JPEG é mais leve.
      if (fileExt == 'png') {
        return Uint8List.fromList(img.encodePng(resized, level: 6));
      }
      return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
    } catch (e) {
      debugPrint('Image resize failed: $e');
      return bytes;
    }
  }

  String _contentTypeForExt(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    return switch (e) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  /// Apaga todos os arquivos de um "diretório" (prefixo) do Storage.
  /// O Firebase Storage não tem delete recursivo nativo: listamos e apagamos.
  Future<void> deleteFolder(String prefix) async {
    final ref = _storage.ref(prefix);
    final result = await ref.listAll();
    for (final item in result.items) {
      try {
        await item.delete();
      } catch (_) {}
    }
    for (final sub in result.prefixes) {
      await deleteFolder(sub.fullPath);
    }
  }
}

