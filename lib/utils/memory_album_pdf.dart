import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../i18n/app_i18n.dart';
import '../models/baby_memory.dart';
import '../models/memory_badge.dart';
import '../theme/app_theme.dart';
import '../widgets/memories/memory_share_card.dart';
import 'memory_share_file.dart';
import 'photo_b64.dart';

/// Um momento do álbum: mesmos dados usados no cartão de partilha individual.
class MemoryAlbumPageInput {
  final MemoryBadge badge;
  final BabyMemory memory;

  const MemoryAlbumPageInput({
    required this.badge,
    required this.memory,
  });
}

class MemoryAlbumPdfStrings {
  final String coverMainTitle;
  final String coverTagline;
  final String footer;

  const MemoryAlbumPdfStrings({
    required this.coverMainTitle,
    required this.coverTagline,
    required this.footer,
  });
}

Future<Uint8List?> _imageBytesForMemory(BabyMemory m) async {
  final b = decodePhotoB64(m.photoB64);
  if (b != null && b.isNotEmpty) return _resizeForPdf(b);
  final url = m.photoUrl?.trim();
  if (url == null || url.isEmpty) return null;
  try {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;
    return _resizeForPdf(Uint8List.fromList(r.bodyBytes));
  } catch (_) {
    return null;
  }
}

Uint8List _resizeForPdf(Uint8List raw) {
  try {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return raw;
    const maxW = 1400;
    if (decoded.width <= maxW) return raw;
    final scaled = img.copyResize(decoded, width: maxW, interpolation: img.Interpolation.cubic);
    return Uint8List.fromList(img.encodeJpg(scaled, quality: 86));
  } catch (_) {
    return raw;
  }
}

PdfColor _c(double r, double g, double b) => PdfColor(r, g, b);

/// Captura o mesmo layout que o PDF individual ([MemoryShareCard]) em PNG.
Future<Uint8List> _captureMemoryShareCardPng({
  required BuildContext context,
  required MemoryBadge badge,
  required BabyMemory memory,
  required String tipText,
  Uint8List? photoBytesOverride,
}) async {
  final key = GlobalKey();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return Positioned(
        left: -9000,
        top: 0,
        child: MediaQuery(
          data: MediaQuery.of(context),
          child: Theme(
            data: Theme.of(context),
            child: Directionality(
              textDirection: Directionality.of(context),
              child: Material(
                color: AppTheme.background,
                child: RepaintBoundary(
                  key: key,
                  child: MemoryShareCard(
                    badge: badge,
                    memory: memory,
                    tipText: tipText,
                    photoBytesOverride: photoBytesOverride,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    for (var i = 0; i < 5; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (i < 3) await Future<void>.delayed(const Duration(milliseconds: 24));
    }
    return await repaintBoundaryToPngBytes(key, pixelRatio: 3);
  } finally {
    entry.remove();
  }
}

/// PDF: capa em arte scrapbook + páginas [MemoryShareCard] + folha em branco.
const String _memoryAlbumCoverAsset = 'assets/memories/memory_album_cover.png';

/// Fator >1 amplia a arte em relação à folha A4 (clip centrado), ficando um pouco maior
/// que a área útil das páginas interiores (que têm margem extra no PDF).
///
/// Nota: a arte da capa já inclui bordas. Para não cortar lateralmente no PDF,
/// mantemos a escala em 1.0 e usamos `contain` na imagem.
const double _memoryAlbumCoverBleedScale = 1.0;

/// Capa “álbum físico” em arte fixa (A4); personalização do nome na faixa inferior.
pw.Widget _memoryAlbumCoverPage(
  pw.MemoryImage coverImage,
  MemoryAlbumPdfStrings strings,
  String babyName,
  double pageW,
  double pageH,
) {
  final tag = strings.coverTagline.replaceAll('{name}', babyName);
  const brown = PdfColor(0.42, 0.32, 0.26);

  final coverLayer = pw.Transform.scale(
    scale: _memoryAlbumCoverBleedScale,
    alignment: pw.Alignment.center,
    child: pw.SizedBox(
      width: pageW,
      height: pageH,
      child: pw.Image(
        coverImage,
        fit: pw.BoxFit.contain,
        alignment: pw.Alignment.center,
      ),
    ),
  );

  return pw.Container(
    width: pageW,
    height: pageH,
    color: const PdfColor(0.992, 0.961, 0.902), // #FDF5E6 aprox.
    child: pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        pw.ClipRect(
          child: pw.SizedBox(
            width: pageW,
            height: pageH,
            child: coverLayer,
          ),
        ),
        pw.Positioned(
          left: 28,
          right: 28,
          bottom: 26,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.99, 0.98, 0.97),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  tag,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 13.5,
                    color: brown,
                    height: 1.35,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  strings.footer,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 9.2, color: _c(0.52, 0.44, 0.48)),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _fallbackCoverPage(
  MemoryAlbumPdfStrings strings,
  String babyName,
  pw.MemoryImage logo,
  double pageW,
  double pageH,
) {
  final purple = _c(0.42, 0.36, 0.58);
  final cream = _c(0.97, 0.975, 0.99);
  final bgHi = _c(0.94, 0.92, 0.98);
  final cardW = (pageW * 0.72).clamp(280.0, 420.0);
  final cardH = (pageH * 0.52).clamp(360.0, 460.0);
  return pw.Container(
    width: pageW,
    height: pageH,
    decoration: pw.BoxDecoration(
      gradient: pw.LinearGradient(
        colors: [cream, bgHi],
        begin: pw.Alignment.topLeft,
        end: pw.Alignment.bottomRight,
      ),
    ),
    child: pw.Center(
      child: pw.Container(
        width: cardW,
        height: cardH,
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(20),
        ),
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(11),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(14),
              color: PdfColors.white,
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: PdfColors.white,
                  ),
                  child: pw.Image(logo, width: 58, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 18),
                pw.Text(
                  strings.coverMainTitle,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: purple,
                    letterSpacing: 0.4,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 8),
                  padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor(0.93, 0.91, 0.97),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    strings.coverTagline.replaceAll('{name}', babyName),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 12.5, color: _c(0.28, 0.24, 0.38)),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  strings.footer,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 9.5, color: _c(0.5, 0.47, 0.58)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<Uint8List> buildMemoryAlbumMemoryBookPdf({
  required BuildContext context,
  required String babyName,
  required MemoryAlbumPdfStrings strings,
  required List<MemoryAlbumPageInput> pages,
}) async {
  final doc = pw.Document();
  const a4 = PdfPageFormat.a4;

  pw.MemoryImage? coverImg;
  pw.MemoryImage? logoImg;
  try {
    coverImg = pw.MemoryImage((await rootBundle.load(_memoryAlbumCoverAsset)).buffer.asUint8List());
  } catch (_) {
    logoImg = pw.MemoryImage((await rootBundle.load('assets/logo.png')).buffer.asUint8List());
  }

  // ——— Capa: arte dedicada (scrapbook 3D) em tela cheia A4, com faixa para o nome. ———
  doc.addPage(
    pw.Page(
      pageFormat: a4,
      margin: pw.EdgeInsets.zero,
      build: (pdfContext) {
        final pageW = pdfContext.page.pageFormat.width;
        final pageH = pdfContext.page.pageFormat.height;
        final cover = coverImg;
        if (cover != null) {
          return _memoryAlbumCoverPage(cover, strings, babyName, pageW, pageH);
        }
        final logo = logoImg;
        if (logo == null) {
          return pw.Container(
            width: pageW,
            height: pageH,
            color: PdfColors.white,
            child: pw.Center(child: pw.Text(strings.coverMainTitle)),
          );
        }
        return _fallbackCoverPage(strings, babyName, logo, pageW, pageH);
      },
    ),
  );

  // ——— Páginas: mesma composição que “PDF (uma página)” no detalhe. ———
  for (final p in pages) {
    final imgBytes = await _imageBytesForMemory(p.memory);
    if (!context.mounted) {
      throw StateError('Exportação do álbum interrompida.');
    }
    final tip = S.of(context).memoryTipForBadgeId(p.badge.id);
    final png = await _captureMemoryShareCardPng(
      context: context,
      badge: p.badge,
      memory: p.memory,
      tipText: tip,
      photoBytesOverride: imgBytes,
    );
    if (!context.mounted) {
      throw StateError('Exportação do álbum interrompida.');
    }
    final jpg = encodePngBytesToJpg(png, quality: 88);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) {
          final w = ctx.page.pageFormat.width;
          final h = ctx.page.pageFormat.height;
          final image = pw.MemoryImage(jpg);
          return pw.Container(
            width: w,
            height: h,
            color: kMemoryPdfAlbumPageBg,
            child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          );
        },
      ),
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Container(color: kMemoryPdfAlbumPageBg),
    ),
  );

  return doc.save();
}
