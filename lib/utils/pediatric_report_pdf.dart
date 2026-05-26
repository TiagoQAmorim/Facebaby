import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/pediatric_report_snapshot.dart';
import '../services/weekly_report_service.dart';

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
}) async {
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
                child: pw.Text(k,
                    style: pw.TextStyle(fontSize: 9.5, color: muted))),
            pw.Expanded(
                flex: 5,
                child: pw.Text(v,
                    style: pw.TextStyle(
                        fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
          ],
        ),
      );

  String fmtMin(double? m) {
    if (m == null || m <= 0) return str.na;
    return '${m.round()} min';
  }

  final sleepInner = <pw.Widget>[
    kv(str.labelSleepAvgDay,
        WeeklyReportService.formatHoursMinutes(snap.avgSleepHoursPerDay)),
    kv(
        str.labelSleepAwakenings,
        snap.sleepAwakeningsAvg <= 0
            ? str.na
            : snap.sleepAwakeningsAvg.toStringAsFixed(1)),
    if (snap.hasSleepPatternBasis) kv(str.labelSleepPattern, sleepPatternText),
    kv(str.labelSleepLongest,
        WeeklyReportService.formatHoursMinutes(snap.longestSleepSec / 3600.0)),
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        pw.Text(str.title,
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold, color: accent)),
        pw.SizedBox(height: 4),
        pw.Text('${str.periodLabel} $periodRangeFormatted',
            style: pw.TextStyle(fontSize: 9.5, color: muted)),
        pw.SizedBox(height: 14),
        _boxed(
          softLine,
          str.sectionBaby,
          accent,
          [
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
        _boxed(
          softLine,
          str.sectionSummary,
          accent,
          [
            kv(str.labelAvgFeeds, snap.avgFeedingsPerDay.toStringAsFixed(1)),
            kv(
                str.labelAvgSleep,
                WeeklyReportService.formatHoursMinutes(
                    snap.avgSleepHoursPerDay)),
            kv(str.labelAvgDiapers, snap.avgDiapersPerDay.toStringAsFixed(1)),
            kv(
              str.labelVaccines,
              snap.vaccinesInPeriodLines.isEmpty
                  ? str.noneRegistered
                  : snap.vaccinesInPeriodLines.join('; '),
            ),
          ],
        ),
        if (snap.growthInsightLines.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _boxed(
            softLine,
            str.sectionGrowthInsights,
            accent,
            snap.growthInsightLines
                .map((line) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text('• $line',
                          style: const pw.TextStyle(fontSize: 9.5)),
                    ))
                .toList(),
          ),
        ],
        pw.SizedBox(height: 10),
        _boxed(
          softLine,
          str.sectionSleep,
          accent,
          sleepInner,
        ),
        pw.SizedBox(height: 10),
        _boxed(
          softLine,
          str.sectionFeeding,
          accent,
          [
            kv(
              '${str.labelFeedBreast} (${str.labelFeedSessions})',
              '${snap.breastfeedingSessions} · ${str.labelAvgDuration}: ${fmtMin(snap.avgBreastMinutes)}',
            ),
            kv(
              '${str.labelFeedFormula} (${str.labelFeedSessions})',
              '${snap.formulaSessions} · ${str.labelAvgDuration}: ${fmtMin(snap.avgFormulaMinutes)}',
            ),
            kv(
              '${str.labelFeedSolid} (${str.labelFeedSessions})',
              '${snap.solidFoodSessions} · ${str.labelAvgDuration}: ${fmtMin(snap.avgSolidMinutes)}',
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        _boxed(
          softLine,
          str.sectionSymptoms,
          accent,
          [
            if (symptomDetailBlocks.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  str.symptomDetailsEmpty,
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: muted,
                      fontStyle: pw.FontStyle.italic),
                ),
              )
            else
              ...symptomDetailBlocks.map(
                (block) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    block,
                    style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.25),
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 10),
        _boxed(
          softLine,
          str.sectionObservations,
          accent,
          [
            pw.Text(
              parentsNotes.trim().isEmpty ? str.na : parentsNotes.trim(),
              style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.25),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(str.footerDisclaimer,
            style: pw.TextStyle(
                fontSize: 8, color: muted, fontStyle: pw.FontStyle.italic)),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _boxed(
  PdfColor borderColor,
  String title,
  PdfColor accent,
  List<pw.Widget> children,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(11),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: borderColor),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: accent)),
        pw.SizedBox(height: 7),
        ...children,
      ],
    ),
  );
}
