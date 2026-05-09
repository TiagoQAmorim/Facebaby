import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Scaffold FaceBaby (`0xFFF7F8FC`) — fundo ao achatar PNG→JPG e páginas do livro PDF.
const PdfColor kMemoryPdfAlbumPageBg = PdfColor.fromInt(0xFFF7F8FC);

/// Captura PNG a partir de um [RepaintBoundary] identificado por [key].
Future<Uint8List> repaintBoundaryToPngBytes(GlobalKey key, {double pixelRatio = 3}) async {
  final ctx = key.currentContext;
  if (ctx == null) throw StateError('Export: widget ainda não desenhado');
  final ro = ctx.findRenderObject();
  if (ro is! RenderRepaintBoundary) throw StateError('Export: esperado RepaintBoundary');
  final image = await ro.toImage(pixelRatio: pixelRatio);
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bd == null) throw StateError('Export: falha ao gerar PNG');
  return bd.buffer.asUint8List();
}

Uint8List encodePngBytesToJpg(Uint8List pngBytes, {int quality = 90}) {
  final decoded = img.decodeImage(pngBytes);
  if (decoded == null) throw StateError('Export: PNG inválido');

  final img.Image toEncode;
  if (decoded.hasAlpha) {
    final bg = img.Image(width: decoded.width, height: decoded.height, numChannels: 3);
    img.fill(bg, color: img.ColorRgb8(247, 248, 252));
    img.compositeImage(bg, decoded, blend: img.BlendMode.alpha);
    toEncode = bg;
  } else {
    toEncode = decoded.numChannels == 3 ? decoded : decoded.convert(numChannels: 3);
  }

  final jpg = img.encodeJpg(toEncode, quality: quality.clamp(60, 100));
  return Uint8List.fromList(jpg);
}

Future<Uint8List> buildSinglePagePdfWithImage(Uint8List imageBytes) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) {
        const fmt = PdfPageFormat.a4;
        final image = pw.MemoryImage(imageBytes);
        return pw.Container(
          width: fmt.width,
          height: fmt.height,
          color: kMemoryPdfAlbumPageBg,
          child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        );
      },
    ),
  );
  return doc.save();
}
