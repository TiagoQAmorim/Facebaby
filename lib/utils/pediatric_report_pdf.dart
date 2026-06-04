import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/pediatric_report_snapshot.dart';
import '../services/weekly_report_service.dart';
import 'pediatric_growth_chart_pdf.dart';
import 'pediatric_report_text.dart';

/// Textos para o PDF (construídos no ecrã a partir do `S`).
class PediatricReportPdfStrings {
  const PediatricReportPdfStrings({
    required this.title,
    required this.periodLabel,
    required this.sectionBaby,
    required this.sectionSummary,
    required this.sectionSleep,
    required this.sectionFeeding,
    required this.sectionSymptoms,
    required this.sectionObservations,
    required this.labelName,
    required this.labelBirth,
    required this.labelAge,
    required this.labelWeightStart,
    required this.labelWeightEnd,
    required this.labelWeightGain,
    required this.labelHeightStart,
    required this.labelHeightEnd,
    required this.labelHeightGain,
    required this.labelHeight,
    required this.labelAvgFeeds,
    required this.labelAvgSleep,
    required this.labelAvgDiapers,
    required this.labelVaccines,
    required this.labelSleepAvgDay,
    required this.labelSleepAwakenings,
    required this.labelSleepPattern,
    required this.labelSleepLongest,
    required this.labelFeedBreast,
    required this.labelFeedFormula,
    required this.labelFeedSolid,
    required this.labelFeedSessions,
    required this.labelAvgDuration,
    required this.symptomDetailsEmpty,
    required this.na,
    required this.footerDisclaimer,
    required this.noneRegistered,
    required this.sectionGrowthInsights,
    required this.sectionGrowthCurve,
  });

  final String title;
  final String periodLabel;
  final String sectionBaby;
  final String sectionSummary;
  final String sectionSleep;
  final String sectionFeeding;
  final String sectionSymptoms;
  final String sectionObservations;
  final String labelName;
  final String labelBirth;
  final String labelAge;
  final String labelWeightStart;
  final String labelWeightEnd;
  final String labelWeightGain;
  final String labelHeightStart;
  final String labelHeightEnd;
  final String labelHeightGain;
  final String labelHeight;
  final String labelAvgFeeds;
  final String labelAvgSleep;
  final String labelAvgDiapers;
  final String labelVaccines;
  final String labelSleepAvgDay;
  final String labelSleepAwakenings;
  final String labelSleepPattern;
  final String labelSleepLongest;
  final String labelFeedBreast;
  final String labelFeedFormula;
  final String labelFeedSolid;
  final String labelFeedSessions;
  final String labelAvgDuration;
  final String symptomDetailsEmpty;
  final String na;
  final String footerDisclaimer;
  final String noneRegistered;
  final String sectionGrowthInsights;
  final String sectionGrowthCurve;
}

class _PdfFonts {
  const _PdfFonts({required this.body, required this.bodyBold});

  final pw.Font body;
  final pw.Font bodyBold;
}

Future<_PdfFonts> _loadPdfFonts() async {
  pw.Font? body;
  pw.Font? bodyBold;
  try {
    body = await PdfGoogleFonts.nunitoRegular();
  } catch (_) {}
  try {
    bodyBold = await PdfGoogleFonts.nunitoBold();
  } catch (_) {}
  return _PdfFonts(
    body: body ?? pw.Font.helvetica(),
    bodyBold: bodyBold ?? pw.Font.helveticaBold(),
  );
}

pw.TextStyle _pdfStyle(
  _PdfFonts fonts, {
  required double fontSize,
  PdfColor? color,
  bool bold = false,
  bool italic = false,
  double lineSpacing = 1.2,
}) {
  return pw.TextStyle(
    font: bold ? fonts.bodyBold : fonts.body,
    fontSize: fontSize,
    color: color ?? PdfColors.black,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
    lineSpacing: lineSpacing,
  );
}

Future<Uint8List> buildPediatricReportPdf({
  required PediatricReportSnapshot snap,
  required String babyName,
  required String birthFormatted,
  required String ageLine,
  required String periodRangeFormatted,
  required String parentsNotes,
  required String weightStartFmt,
  required String weightEndFmt,
  required String weightGainFmt,
  required String heightStartFmt,
  required String heightEndFmt,
  required String heightGainFmt,
  required String heightFmt,
  required String sleepPatternText,
  required List<String> symptomDetailBlocks,
  required PediatricReportPdfStrings str,
  PediatricGrowthChartPdfLabels? growthChartLabels,
}) async {
  final fonts = await _loadPdfFonts();
  String t(String s) => PediatricReportText.forPdf(s);

  final doc = pw.Document();
  final muted = PdfColor.fromInt(0xFF616161);
  final accent = PdfColor.fromInt(0xFF4A3F6B);
  final softLine = PdfColor.fromInt(0xFFE8E4F5);

  pw.Widget kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Text(
                t(k),
                style: _pdfStyle(fonts, fontSize: 9.5, color: muted),
              ),
            ),
            pw.Expanded(
              flex: 5,
              child: pw.Text(
                t(v),
                style: _pdfStyle(fonts, fontSize: 9.5, bold: true),
              ),
            ),
          ],
        ),
      );

  String fmtMin(double? m) {
    if (m == null || m <= 0) return t(str.na);
    return t('${m.round()} min');
  }

  final sleepInner = <pw.Widget>[
    kv(
      str.labelSleepAvgDay,
      WeeklyReportService.formatHoursMinutes(snap.avgSleepHoursPerDay),
    ),
    kv(
      str.labelSleepAwakenings,
      snap.sleepAwakeningsAvg <= 0
          ? t(str.na)
          : snap.sleepAwakeningsAvg.toStringAsFixed(1),
    ),
    if (snap.hasSleepPatternBasis)
      kv(str.labelSleepPattern, sleepPatternText),
    kv(
      str.labelSleepLongest,
      WeeklyReportService.formatHoursMinutes(snap.longestSleepSec / 3600.0),
    ),
  ];

  final growthSectionChildren = <pw.Widget>[];
  if (growthChartLabels != null && snap.hasGrowthChartData) {
    growthSectionChildren.addAll(
      buildPediatricGrowthChartsPdf(
        sex: snap.growthCurveSex,
        heightMeasurements: snap.heightMeasurements,
        weightMeasurements: snap.weightMeasurements,
        labels: growthChartLabels,
        accent: accent,
        bodyFont: fonts.body,
        bodyBoldFont: fonts.bodyBold,
        includeSectionTitle: false,
      ),
    );
  }
  if (snap.growthInsightLines.isNotEmpty) {
    if (growthSectionChildren.isNotEmpty) {
      growthSectionChildren.add(pw.SizedBox(height: 8));
    }
    growthSectionChildren.add(
      pw.Text(
        t(str.sectionGrowthInsights),
        style: _pdfStyle(fonts, fontSize: 10, bold: true, color: accent),
      ),
    );
    growthSectionChildren.add(pw.SizedBox(height: 4));
    for (final line in snap.growthInsightLines) {
      growthSectionChildren.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            '${PediatricReportText.bulletPrefix}${t(line)}',
            style: _pdfStyle(fonts, fontSize: 9.5, lineSpacing: 1.25),
          ),
        ),
      );
    }
  }

  final showGrowthSection = growthSectionChildren.isNotEmpty;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(
        base: fonts.body,
        bold: fonts.bodyBold,
      ),
      build: (ctx) {
        final pageW = ctx.page.pageFormat.availableWidth;
        pw.Widget section({
          required String title,
          required List<pw.Widget> children,
        }) =>
            pw.SizedBox(
              width: pageW,
              child: _boxed(
                fonts: fonts,
                borderColor: softLine,
                title: title,
                accent: accent,
                children: children,
              ),
            );

        return [
        pw.Text(
          t(str.title),
          style: _pdfStyle(fonts, fontSize: 16, bold: true, color: accent),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${t(str.periodLabel)} ${t(periodRangeFormatted)}',
          style: _pdfStyle(fonts, fontSize: 9.5, color: muted),
        ),
        pw.SizedBox(height: 14),
        section(
          title: t(str.sectionBaby),
          children: [
            kv(str.labelName, babyName),
            kv(str.labelBirth, birthFormatted),
            kv(str.labelAge, ageLine),
            kv(str.labelWeightStart, weightStartFmt),
            kv(str.labelWeightEnd, weightEndFmt),
            kv(str.labelWeightGain, weightGainFmt),
            kv(str.labelHeight, heightFmt),
            kv(str.labelHeightStart, heightStartFmt),
            kv(str.labelHeightEnd, heightEndFmt),
            kv(str.labelHeightGain, heightGainFmt),
          ],
        ),
        pw.SizedBox(height: 10),
        section(
          title: t(str.sectionSummary),
          children: [
            kv(str.labelAvgFeeds, snap.avgFeedingsPerDay.toStringAsFixed(1)),
            kv(
              str.labelAvgSleep,
              WeeklyReportService.formatHoursMinutes(
                snap.avgSleepHoursPerDay,
              ),
            ),
            kv(str.labelAvgDiapers, snap.avgDiapersPerDay.toStringAsFixed(1)),
            kv(
              str.labelVaccines,
              snap.vaccinesInPeriodLines.isEmpty
                  ? t(str.noneRegistered)
                  : t(snap.vaccinesInPeriodLines.join('; ')),
            ),
          ],
        ),
        if (showGrowthSection) ...[
          pw.SizedBox(height: 10),
          section(
            title: t(str.sectionGrowthCurve),
            children: growthSectionChildren,
          ),
        ],
        pw.SizedBox(height: 10),
        section(
          title: t(str.sectionSleep),
          children: sleepInner,
        ),
        pw.SizedBox(height: 10),
        section(
          title: t(str.sectionFeeding),
          children: [
            kv(
              '${str.labelFeedBreast} (${str.labelFeedSessions})',
              '${snap.breastfeedingSessions}${PediatricReportText.midDot}${t(str.labelAvgDuration)}: ${fmtMin(snap.avgBreastMinutes)}',
            ),
            kv(
              '${str.labelFeedFormula} (${str.labelFeedSessions})',
              '${snap.formulaSessions}${PediatricReportText.midDot}${t(str.labelAvgDuration)}: ${fmtMin(snap.avgFormulaMinutes)}',
            ),
            kv(
              '${str.labelFeedSolid} (${str.labelFeedSessions})',
              '${snap.solidFoodSessions}${PediatricReportText.midDot}${t(str.labelAvgDuration)}: ${fmtMin(snap.avgSolidMinutes)}',
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        section(
          title: t(str.sectionSymptoms),
          children: [
            if (symptomDetailBlocks.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  t(str.symptomDetailsEmpty),
                  style: _pdfStyle(
                    fonts,
                    fontSize: 9,
                    color: muted,
                    italic: true,
                  ),
                ),
              )
            else
              ...symptomDetailBlocks.map(
                (block) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    t(block),
                    style: _pdfStyle(fonts, fontSize: 9.5, lineSpacing: 1.25),
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 10),
        section(
          title: t(str.sectionObservations),
          children: [
            pw.SizedBox(
              width: double.infinity,
              child: pw.Text(
                parentsNotes.trim().isEmpty
                    ? t(str.na)
                    : t(parentsNotes.trim()),
                style: _pdfStyle(fonts, fontSize: 9.5, lineSpacing: 1.25),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          t(str.footerDisclaimer),
          style: _pdfStyle(
            fonts,
            fontSize: 8,
            color: muted,
            italic: true,
          ),
        ),
      ];
      },
    ),
  );

  return doc.save();
}

pw.Widget _boxed({
  required _PdfFonts fonts,
  required PdfColor borderColor,
  required String title,
  required PdfColor accent,
  required List<pw.Widget> children,
}) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(11),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: borderColor),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          title,
          style: _pdfStyle(fonts, fontSize: 11, bold: true, color: accent),
        ),
        pw.SizedBox(height: 7),
        ...children,
      ],
    ),
  );
}
