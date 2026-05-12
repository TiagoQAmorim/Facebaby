import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../i18n/app_i18n.dart';
import '../models/baby_memory.dart';
import '../models/memory_badge.dart';
import 'measurement_format.dart';
import 'memory_moment_localizations.dart';
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
  // Texto longo da contracapa (corpo) + frase final em letra de mão.
  final String backCoverBody;
  final String backCoverFinale;

  const MemoryAlbumPdfStrings({
    required this.coverMainTitle,
    required this.coverTagline,
    required this.footer,
    required this.backCoverBody,
    required this.backCoverFinale,
  });
}

// ─── Page format ────────────────────────────────────────────────────────────
// Formato físico: 21 cm × 15 cm (paisagem).
PdfPageFormat _bookPageFormat() => const PdfPageFormat(
      21.0 * PdfPageFormat.cm,
      15.0 * PdfPageFormat.cm,
      marginAll: 0,
    );

// ─── Framing assets (cover / back cover / end) ──────────────────────────────
const String _kCoverAsset = 'assets/memories/book/cover.png';
const String _kBackCoverAsset = 'assets/memories/book/back_cover.png';
const String _kEndAsset = 'assets/memories/book/end.png';

// ─── Page themes (ciclam pelas páginas de memória) ──────────────────────────
class _PageTheme {
  final PdfColor background; // pastel suave do papel
  final PdfColor accent; // detalhes / icones
  final PdfColor accentDark; // títulos
  final PdfColor cardBg; // cartão branco translúcido
  const _PageTheme({
    required this.background,
    required this.accent,
    required this.accentDark,
    required this.cardBg,
  });
}

const List<_PageTheme> _kPageThemes = [
  _PageTheme(
    background: PdfColor.fromInt(0xFFFFF6E0),
    accent: PdfColor.fromInt(0xFFE5A645),
    accentDark: PdfColor.fromInt(0xFFB07720),
    cardBg: PdfColor.fromInt(0xFFFFFCF0),
  ),
  _PageTheme(
    background: PdfColor.fromInt(0xFFE7F1FA),
    accent: PdfColor.fromInt(0xFF6CA9D6),
    accentDark: PdfColor.fromInt(0xFF335A85),
    cardBg: PdfColor.fromInt(0xFFF7FBFF),
  ),
  _PageTheme(
    background: PdfColor.fromInt(0xFFEAF3E5),
    accent: PdfColor.fromInt(0xFF7BAA6D),
    accentDark: PdfColor.fromInt(0xFF42703A),
    cardBg: PdfColor.fromInt(0xFFF6FBF3),
  ),
  _PageTheme(
    background: PdfColor.fromInt(0xFFEEE6F6),
    accent: PdfColor.fromInt(0xFF9B7BC8),
    accentDark: PdfColor.fromInt(0xFF5E437C),
    cardBg: PdfColor.fromInt(0xFFF9F5FE),
  ),
];

// ─── Fonts ──────────────────────────────────────────────────────────────────
class _PdfFonts {
  final pw.Font body; // moderna / amigável (Nunito)
  final pw.Font bodyBold;
  final pw.Font script; // letra de mão (DancingScript)
  final pw.Font scriptBold;
  final List<pw.Font> fallbacks; // CJK + emoji

  _PdfFonts({
    required this.body,
    required this.bodyBold,
    required this.script,
    required this.scriptBold,
    required this.fallbacks,
  });
}

Future<_PdfFonts> _loadFonts() async {
  pw.Font? body, bodyBold, script, scriptBold;
  final fallbacks = <pw.Font>[];

  try {
    body = await PdfGoogleFonts.nunitoRegular();
  } catch (_) {}
  try {
    bodyBold = await PdfGoogleFonts.nunitoBold();
  } catch (_) {}
  try {
    script = await PdfGoogleFonts.dancingScriptRegular();
  } catch (_) {}
  try {
    scriptBold = await PdfGoogleFonts.dancingScriptBold();
  } catch (_) {}

  for (final loader in <Future<pw.Font> Function()>[
    PdfGoogleFonts.notoSansJPRegular,
    PdfGoogleFonts.notoSansKRRegular,
    PdfGoogleFonts.notoColorEmojiRegular,
  ]) {
    try {
      fallbacks.add(await loader());
    } catch (_) {
      // best effort
    }
  }

  return _PdfFonts(
    body: body ?? pw.Font.helvetica(),
    bodyBold: bodyBold ?? pw.Font.helveticaBold(),
    script: script ?? body ?? pw.Font.helvetica(),
    scriptBold: scriptBold ?? bodyBold ?? pw.Font.helveticaBold(),
    fallbacks: fallbacks,
  );
}

pw.TextStyle _styleBody(
  _PdfFonts f, {
  required double size,
  PdfColor color = PdfColors.black,
  bool bold = false,
  bool italic = false,
  double letterSpacing = 0,
  double height = 1.3,
}) {
  return pw.TextStyle(
    font: bold ? f.bodyBold : f.body,
    fontFallback: f.fallbacks,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
}

pw.TextStyle _styleScript(
  _PdfFonts f, {
  required double size,
  PdfColor color = PdfColors.black,
  bool bold = false,
  double letterSpacing = 0,
  double height = 1.3,
}) {
  return pw.TextStyle(
    font: bold ? f.scriptBold : f.script,
    fontFallback: f.fallbacks,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

// ─── Image helpers ──────────────────────────────────────────────────────────
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

Future<pw.MemoryImage?> _loadAsset(String path) async {
  try {
    final data = await rootBundle.load(path);
    return pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

// ─── Cover (full-image, sem corpo gerado por código) ────────────────────────
pw.Widget _coverBackground({
  required pw.MemoryImage? cover,
  required pw.MemoryImage? logoFallback,
  required MemoryAlbumPdfStrings strings,
  required String babyName,
  required double pageW,
  required double pageH,
  required _PdfFonts fonts,
}) {
  if (cover != null) {
    return pw.Container(
      width: pageW,
      height: pageH,
      color: PdfColors.white,
      child: pw.Image(cover, fit: pw.BoxFit.fill, alignment: pw.Alignment.center),
    );
  }
  return pw.Container(
    width: pageW,
    height: pageH,
    color: const PdfColor(0.992, 0.961, 0.902),
    child: pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          if (logoFallback != null) pw.Image(logoFallback, width: 90),
          pw.SizedBox(height: 16),
          pw.Text(
            strings.coverMainTitle,
            style: _styleBody(
              fonts,
              size: 24,
              bold: true,
              color: const PdfColor.fromInt(0xFF6B4F3F),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            strings.coverTagline.replaceAll('{name}', babyName),
            textAlign: pw.TextAlign.center,
            style: _styleBody(
              fonts,
              size: 12,
              color: const PdfColor.fromInt(0xFF8B7B6F),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Back cover ─────────────────────────────────────────────────────────────
pw.Widget _backCoverBackground({
  required pw.MemoryImage? template,
  required MemoryAlbumPdfStrings strings,
  required double pageW,
  required double pageH,
  required _PdfFonts fonts,
}) {
  const ink = PdfColor.fromInt(0xFF6B5A55);
  const accent = PdfColor.fromInt(0xFFD9637A);

  final overlay = pw.Stack(
    children: [
      pw.Positioned(
        left: 0.10 * pageW,
        top: 0.18 * pageH,
        child: pw.SizedBox(
          width: 0.80 * pageW,
          height: 0.46 * pageH,
          child: pw.Center(
            child: pw.Text(
              strings.backCoverBody,
              textAlign: pw.TextAlign.center,
              style: _styleBody(
                fonts,
                size: 8.5,
                color: ink,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
      pw.Positioned(
        left: 0.12 * pageW,
        top: 0.655 * pageH,
        child: pw.SizedBox(
          width: 0.76 * pageW,
          height: 0.12 * pageH,
          child: pw.Center(
            child: pw.Text(
              strings.backCoverFinale,
              textAlign: pw.TextAlign.center,
              style: _styleScript(
                fonts,
                size: 16,
                color: accent,
                bold: true,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  return pw.Stack(
    fit: pw.StackFit.expand,
    children: [
      if (template != null)
        pw.Image(template, fit: pw.BoxFit.fill, alignment: pw.Alignment.center)
      else
        pw.Container(color: const PdfColor(0.992, 0.961, 0.902)),
      overlay,
    ],
  );
}

// ─── Memory page (layout 100% em código, sem template de fundo) ─────────────
pw.Widget _memoryPage({
  required _PageTheme theme,
  required BabyMemory memory,
  required String badgeTitle,
  required String momentLabel, // "Conte sobre esse momento" (rótulo da badge)
  required String momentText, // descrição preenchida pela mãe
  required Uint8List? photoBytes,
  required String ageLabel,
  required String weightLabel,
  required String heightLabel,
  required String moodLabel,
  required String notesLabel,
  required String dateText,
  required double pageW,
  required double pageH,
  required _PdfFonts fonts,
}) {
  const ink = PdfColor.fromInt(0xFF3F3A4A);
  const inkSoft = PdfColor.fromInt(0xFF7B7686);
  final cardBorder = PdfColor(
    theme.accent.red * 0.85 + 0.15,
    theme.accent.green * 0.85 + 0.15,
    theme.accent.blue * 0.85 + 0.15,
    0.25,
  );

  pw.Widget statCard({required String label, required String value}) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 3),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: pw.BoxDecoration(
          color: theme.cardBg,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: cardBorder, width: 0.6),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              label.toUpperCase(),
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: _styleBody(
                fonts,
                size: 7,
                bold: true,
                color: theme.accentDark,
                letterSpacing: 0.4,
                height: 1.0,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Text(
                value.isEmpty ? '—' : value,
                maxLines: 1,
                textAlign: pw.TextAlign.center,
                style: _styleBody(
                  fonts,
                  size: 11,
                  bold: true,
                  color: ink,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget sectionCard({
    required String label,
    required pw.Widget child,
    int flex = 1,
  }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        margin: const pw.EdgeInsets.only(top: 6),
        padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 8),
        decoration: pw.BoxDecoration(
          color: theme.cardBg,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: cardBorder, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: _styleBody(
                fonts,
                size: 7.5,
                bold: true,
                color: theme.accentDark,
                letterSpacing: 0.6,
                height: 1.0,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Expanded(child: child),
          ],
        ),
      ),
    );
  }

  final ageValue = (memory.babyAgeAtMoment ?? '').trim();
  final weightShown = MeasurementFormat.weight(memory.weightAtMoment, decimalsKg: 2);
  final heightShown = MeasurementFormat.length(memory.heightAtMoment, decimalsCm: 1);
  final moodValue = (memory.moodAtMoment ?? '').trim();
  final notes = (memory.motherNotes ?? '').trim();
  final momentBody = momentText.trim();

  // ── Cabeçalho: "fita" com o título da badge + data subtil à direita ─────
  final header = pw.Container(
    height: 38,
    padding: const pw.EdgeInsets.symmetric(horizontal: 14),
    decoration: pw.BoxDecoration(
      color: theme.accent,
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Text(
            badgeTitle,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: _styleBody(
              fonts,
              size: 14,
              bold: true,
              color: PdfColors.white,
              letterSpacing: 0.3,
              height: 1.0,
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          dateText,
          maxLines: 1,
          style: _styleBody(
            fonts,
            size: 9,
            color: PdfColors.white,
            height: 1.0,
          ),
        ),
      ],
    ),
  );

  // ── Coluna esquerda: foto grande com moldura ────────────────────────────
  final photoCard = pw.Container(
    decoration: pw.BoxDecoration(
      color: theme.cardBg,
      borderRadius: pw.BorderRadius.circular(14),
      border: pw.Border.all(color: cardBorder, width: 0.8),
    ),
    padding: const pw.EdgeInsets.all(6),
    child: photoBytes == null
        ? pw.Center(
            child: pw.Text(
              '—',
              style: _styleBody(fonts, size: 24, color: inkSoft, height: 1.0),
            ),
          )
        : pw.ClipRRect(
            horizontalRadius: 10,
            verticalRadius: 10,
            child: pw.Image(
              pw.MemoryImage(photoBytes),
              fit: pw.BoxFit.cover,
              alignment: pw.Alignment.center,
            ),
          ),
  );

  // ── Coluna direita: momento + 3 stats + mood + notas ────────────────────
  final rightColumn = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // Linha das 3 pílulas (idade / peso / altura) — fora dos cards para terem altura própria.
      pw.SizedBox(
        height: 46,
        child: pw.Row(
          children: [
            statCard(label: ageLabel, value: ageValue),
            statCard(label: weightLabel, value: weightShown),
            statCard(label: heightLabel, value: heightShown),
          ],
        ),
      ),
      sectionCard(
        label: momentLabel,
        flex: 3,
        child: pw.Text(
          momentBody.isEmpty ? '—' : momentBody,
          maxLines: 4,
          overflow: pw.TextOverflow.clip,
          style: _styleBody(fonts, size: 10, color: ink, height: 1.35),
        ),
      ),
      sectionCard(
        label: moodLabel,
        flex: 1,
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            moodValue.isEmpty ? '—' : moodValue,
            maxLines: 1,
            style: _styleBody(fonts, size: 11, bold: true, color: ink, height: 1.0),
          ),
        ),
      ),
      sectionCard(
        label: notesLabel,
        flex: 3,
        child: pw.Text(
          notes.isEmpty ? '—' : notes,
          maxLines: 4,
          overflow: pw.TextOverflow.clip,
          style: _styleBody(fonts, size: 9.5, color: ink, height: 1.35),
        ),
      ),
    ],
  );

  return pw.Container(
    width: pageW,
    height: pageH,
    color: theme.background,
    padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 18),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        header,
        pw.SizedBox(height: 10),
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(flex: 48, child: photoCard),
              pw.SizedBox(width: 12),
              pw.Expanded(flex: 52, child: rightColumn),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Public API ─────────────────────────────────────────────────────────────
Future<Uint8List> buildMemoryAlbumMemoryBookPdf({
  required BuildContext context,
  required String babyName,
  required MemoryAlbumPdfStrings strings,
  required List<MemoryAlbumPageInput> pages,
}) async {
  final doc = pw.Document();
  final bookFmt = _bookPageFormat();
  // Capturamos as strings localizadas ANTES de qualquer `await` para evitar
  // usar [BuildContext] através de async gaps.
  final s = S.of(context);
  final momentLabel = s.memoryTellMomentTitle;
  final ageLabel = s.memoryStatAgeLabel;
  final weightLabel = s.memoryStatWeightLabel;
  final heightLabel = s.memoryStatHeightLabel;
  final moodLabel = s.memoryStatMoodLabel;
  final notesLabel = s.memoryMotherNotesLabel;

  final fonts = await _loadFonts();
  final coverImg = await _loadAsset(_kCoverAsset);
  final backCoverImg = await _loadAsset(_kBackCoverAsset);
  final endImg = await _loadAsset(_kEndAsset);
  final logoFallback = await _loadAsset('assets/logo.png');

  // Numeração apenas das páginas de memória (capa, contracapa e página final
  // saem sem número, como pedido).
  final memoryTotal = pages.length;

  void addFramingPage(pw.Widget Function(pw.Context ctx, double w, double h) builder) {
    doc.addPage(
      pw.Page(
        pageFormat: bookFmt,
        margin: pw.EdgeInsets.zero,
        theme: pw.ThemeData.withFont(
          base: fonts.body,
          bold: fonts.bodyBold,
          italic: fonts.body,
          fontFallback: fonts.fallbacks,
        ),
        build: (ctx) {
          final w = ctx.page.pageFormat.width;
          final h = ctx.page.pageFormat.height;
          return builder(ctx, w, h);
        },
      ),
    );
  }

  void addMemoryPage({
    required pw.Widget Function(pw.Context ctx, double w, double h) builder,
    required int idx,
  }) {
    doc.addPage(
      pw.Page(
        pageFormat: bookFmt,
        margin: pw.EdgeInsets.zero,
        theme: pw.ThemeData.withFont(
          base: fonts.body,
          bold: fonts.bodyBold,
          italic: fonts.body,
          fontFallback: fonts.fallbacks,
        ),
        build: (ctx) {
          final w = ctx.page.pageFormat.width;
          final h = ctx.page.pageFormat.height;
          return pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              builder(ctx, w, h),
              pw.Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                child: pw.Center(
                  child: pw.Text(
                    '$idx / $memoryTotal',
                    style: _styleBody(
                      fonts,
                      size: 7.5,
                      color: const PdfColor.fromInt(0xFF8C8C8C),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Capa (sem footer) ────────────────────────────────────────────────────
  addFramingPage(
    (ctx, w, h) => _coverBackground(
      cover: coverImg,
      logoFallback: logoFallback,
      strings: strings,
      babyName: babyName,
      pageW: w,
      pageH: h,
      fonts: fonts,
    ),
  );

  // ── Contracapa (2.ª página, sem footer) ──────────────────────────────────
  addFramingPage(
    (ctx, w, h) => _backCoverBackground(
      template: backCoverImg,
      strings: strings,
      pageW: w,
      pageH: h,
      fonts: fonts,
    ),
  );

  // ── Páginas de memória (ciclam pelos 4 temas, com numeração própria) ─────
  for (var i = 0; i < pages.length; i++) {
    final entry = pages[i];
    final theme = _kPageThemes[i % _kPageThemes.length];
    final photo = await _imageBytesForMemory(entry.memory);
    if (!context.mounted) {
      throw StateError('Exportação do álbum interrompida.');
    }
    final title = s.memoryBadgeTitle(entry.badge);
    final dateText = formatMemoryMomentDateTime(context, entry.memory.memoryDate);
    final descRaw = (entry.memory.description ?? '').trim();

    addMemoryPage(
      builder: (ctx, w, h) => _memoryPage(
        theme: theme,
        memory: entry.memory,
        badgeTitle: title,
        momentLabel: momentLabel,
        momentText: descRaw,
        photoBytes: photo,
        ageLabel: ageLabel,
        weightLabel: weightLabel,
        heightLabel: heightLabel,
        moodLabel: moodLabel,
        notesLabel: notesLabel,
        dateText: dateText,
        pageW: w,
        pageH: h,
        fonts: fonts,
      ),
      idx: i + 1,
    );
  }

  // ── Página final (sem footer) ────────────────────────────────────────────
  addFramingPage(
    (ctx, w, h) => pw.Container(
      width: w,
      height: h,
      color: const PdfColor(0.992, 0.961, 0.902),
      child: endImg != null
          ? pw.Image(endImg, fit: pw.BoxFit.fill, alignment: pw.Alignment.center)
          : (logoFallback != null
              ? pw.Center(child: pw.Image(logoFallback, width: 120))
              : pw.SizedBox.expand()),
    ),
  );

  return doc.save();
}
