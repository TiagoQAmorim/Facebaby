import 'dart:async';
import 'dart:math' as math;

import '../utils/memory_album_pdf.dart';
import '../utils/memory_share_transport.dart';
import 'memory_album_image_cache.dart';
import 'memory_album_pdf_quality.dart';

/// Token para cancelar a geração do álbum.
class MemoryAlbumCancelToken {
  bool _canceled = false;

  bool get isCanceled => _canceled;

  void cancel() => _canceled = true;
}

enum MemoryAlbumGenerationPhase {
  preparing,
  images,
  building,
  saving,
}

class MemoryAlbumGenerationProgress {
  const MemoryAlbumGenerationProgress({
    required this.phase,
    required this.overallFraction,
    this.imageCurrent,
    this.imageTotal,
    this.buildCurrent,
    this.buildTotal,
  });

  final MemoryAlbumGenerationPhase phase;
  final double overallFraction;
  final int? imageCurrent;
  final int? imageTotal;
  final int? buildCurrent;
  final int? buildTotal;
}

class MemoryAlbumGenerateResult {
  const MemoryAlbumGenerateResult({
    required this.filePath,
    required this.fileName,
    required this.skippedImages,
    required this.pageCount,
  });

  final String filePath;
  final String fileName;
  final int skippedImages;
  final int pageCount;
}

/// Orquestra download em lotes, cache, montagem do PDF e gravação em disco.
class MemoryAlbumPdfGenerator {
  MemoryAlbumPdfGenerator._();
  static final MemoryAlbumPdfGenerator instance = MemoryAlbumPdfGenerator._();

  static const int _imageBatchSize = 2;

  Future<MemoryAlbumGenerateResult> generate({
    required String babyName,
    required MemoryAlbumPdfStrings strings,
    required MemoryAlbumPdfPageLabels labels,
    required List<MemoryAlbumPageInput> pages,
    required MemoryAlbumPdfQuality quality,
    required MemoryAlbumCancelToken cancelToken,
    required void Function(MemoryAlbumGenerationProgress progress) onProgress,
  }) async {
    void report(
      MemoryAlbumGenerationPhase phase,
      double fraction, {
      int? imageCurrent,
      int? imageTotal,
      int? buildCurrent,
      int? buildTotal,
    }) {
      onProgress(
        MemoryAlbumGenerationProgress(
          phase: phase,
          overallFraction: fraction.clamp(0.0, 1.0),
          imageCurrent: imageCurrent,
          imageTotal: imageTotal,
          buildCurrent: buildCurrent,
          buildTotal: buildTotal,
        ),
      );
    }

    if (cancelToken.isCanceled) {
      throw const MemoryAlbumCanceledException();
    }

    report(MemoryAlbumGenerationPhase.preparing, 0.02);

    final prepared = <MemoryAlbumPreparedPageInput>[];
    for (final entry in pages) {
      prepared.add(
        MemoryAlbumPreparedPageInput(
          memory: entry.memory,
          badgeTitle: labels.badgeTitle(entry.badge),
          dateText: labels.dateText(entry.memory),
          momentText: (entry.memory.description ?? '').trim(),
        ),
      );
    }

    final imageIndices = <int>[];
    for (var i = 0; i < pages.length; i++) {
      final m = pages[i].memory;
      final hasPhoto = (m.photoB64?.trim().isNotEmpty == true) ||
          (m.photoUrl?.trim().isNotEmpty == true);
      if (hasPhoto) imageIndices.add(i);
    }

    var skippedImages = 0;
    final imageTotal = imageIndices.length;

    for (var start = 0; start < imageIndices.length; start += _imageBatchSize) {
      if (cancelToken.isCanceled) {
        throw const MemoryAlbumCanceledException();
      }

      final end = math.min(start + _imageBatchSize, imageIndices.length);
      final batch = imageIndices.sublist(start, end);

      await Future.wait(
        batch.map((index) async {
          final memory = pages[index].memory;
          try {
            final path = await MemoryAlbumImageCache.instance.ensureFile(
              memory: memory,
              quality: quality,
              isCanceled: () => cancelToken.isCanceled,
            );
            prepared[index] = prepared[index].copyWith(imageFilePath: path);
            if (path == null) skippedImages++;
          } on MemoryAlbumCanceledException {
            rethrow;
          } on MemoryAlbumNetworkException {
            rethrow;
          } on MemoryAlbumStorageException {
            rethrow;
          } catch (_) {
            skippedImages++;
            prepared[index] = prepared[index].copyWith(imageFilePath: null);
          }
        }),
      );

      final done = end;
      final frac = imageTotal == 0
          ? 0.65
          : 0.05 + (done / imageTotal) * 0.60;
      report(
        MemoryAlbumGenerationPhase.images,
        frac,
        imageCurrent: done,
        imageTotal: imageTotal,
      );
      await Future<void>.delayed(Duration.zero);
    }

    if (cancelToken.isCanceled) {
      throw const MemoryAlbumCanceledException();
    }

    report(
      MemoryAlbumGenerationPhase.building,
      0.68,
      buildCurrent: 0,
      buildTotal: prepared.length,
    );

    final pdfBytes = await buildMemoryAlbumMemoryBookPdfFromPrepared(
      babyName: babyName,
      strings: strings,
      labels: labels,
      pages: prepared,
      isCanceled: () => cancelToken.isCanceled,
      onBuildProgress: (built, total) {
        final frac = 0.68 + (built / math.max(total, 1)) * 0.22;
        report(
          MemoryAlbumGenerationPhase.building,
          frac,
          buildCurrent: built,
          buildTotal: total,
        );
      },
    );

    if (cancelToken.isCanceled) {
      throw const MemoryAlbumCanceledException();
    }

    report(MemoryAlbumGenerationPhase.saving, 0.94);

    final stamp =
        DateTime.now().toIso8601String().replaceAll(':', '').split('.').first;
    final qualityTag = quality.fileSuffix;
    final fileName = 'facebaby_album_${qualityTag}_$stamp.pdf';

    try {
      final filePath = await savePdfBytes(pdfBytes, fileName);
      report(MemoryAlbumGenerationPhase.saving, 1.0);
      return MemoryAlbumGenerateResult(
        filePath: filePath,
        fileName: fileName,
        skippedImages: skippedImages,
        pageCount: prepared.length,
      );
    } on Object catch (e) {
      if (e is MemoryAlbumStorageException) rethrow;
      throw MemoryAlbumStorageException(e.toString());
    }
  }
}
