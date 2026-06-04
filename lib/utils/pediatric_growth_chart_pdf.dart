import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/growth_curves.dart';
import '../models/growth_measurement_point.dart';
import '../utils/growth_measurements_builder.dart';
import 'pediatric_report_text.dart';

/// Rótulos para gráficos de crescimento no PDF pediátrico.
class PediatricGrowthChartPdfLabels {
  const PediatricGrowthChartPdfLabels({
    required this.sectionTitle,
    required this.heightTitle,
    required this.weightTitle,
    required this.axisMonths,
    required this.legendMin,
    required this.legendAvg,
    required this.legendMax,
    required this.legendBaby,
    required this.disclaimer,
    required this.emptyHeight,
    required this.emptyWeight,
  });

  final String sectionTitle;
  final String heightTitle;
  final String weightTitle;
  final String axisMonths;
  final String legendMin;
  final String legendAvg;
  final String legendMax;
  final String legendBaby;
  final String disclaimer;
  final String emptyHeight;
  final String emptyWeight;
}

/// Gráficos de curva de crescimento (referência + bebê) para o PDF.
List<pw.Widget> buildPediatricGrowthChartsPdf({
  required GrowthCurveSex sex,
  required List<GrowthMeasurementPoint> heightMeasurements,
  required List<GrowthMeasurementPoint> weightMeasurements,
  required PediatricGrowthChartPdfLabels labels,
  PdfColor accent = const PdfColor.fromInt(0xFF4A3F6B),
  pw.Font? bodyFont,
  pw.Font? bodyBoldFont,
  bool includeSectionTitle = true,
}) {
  String t(String s) => PediatricReportText.forPdf(s);
  final body = bodyFont ?? pw.Font.helvetica();
  final bodyBold = bodyBoldFont ?? pw.Font.helveticaBold();

  final out = <pw.Widget>[];
  if (includeSectionTitle) {
    out.addAll([
      pw.SizedBox(height: 4),
      pw.Text(
        t(labels.sectionTitle),
        style: pw.TextStyle(
          font: bodyBold,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: accent,
        ),
      ),
      pw.SizedBox(height: 8),
    ]);
  }

  void addChart({
    required String title,
    required GrowthChartMetric metric,
    required List<GrowthMeasurementPoint> measurements,
    required String emptyLabel,
  }) {
    out.add(
      pw.Text(
        t(title),
        style: pw.TextStyle(
          font: bodyBold,
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
    out.add(pw.SizedBox(height: 4));
    final chart = _GrowthPdfChart(
      sex: sex,
      metric: metric,
      measurements: measurements,
      axisMonthsLabel: labels.axisMonths,
      legendMin: labels.legendMin,
      legendAvg: labels.legendAvg,
      legendMax: labels.legendMax,
      legendBaby: labels.legendBaby,
      emptyLabel: emptyLabel,
    );
    if (chart.isEmpty) {
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 12),
          child: pw.Text(
            t(emptyLabel),
            style: pw.TextStyle(
              font: body,
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColor.fromInt(0xFF757575),
            ),
          ),
        ),
      );
    } else {
      out.add(chart.build());
      out.add(pw.SizedBox(height: 6));
      out.add(chart.buildLegend());
    }
    out.add(pw.SizedBox(height: 8));
  }

  addChart(
    title: labels.heightTitle,
    metric: GrowthChartMetric.height,
    measurements: heightMeasurements,
    emptyLabel: labels.emptyHeight,
  );
  addChart(
    title: labels.weightTitle,
    metric: GrowthChartMetric.weight,
    measurements: weightMeasurements,
    emptyLabel: labels.emptyWeight,
  );

  out.add(
    pw.SizedBox(
      width: double.infinity,
      child: pw.Text(
        t(labels.disclaimer),
        style: pw.TextStyle(
          font: body,
          fontSize: 8,
          fontStyle: pw.FontStyle.italic,
          color: PdfColor.fromInt(0xFF757575),
        ),
      ),
    ),
  );
  return out;
}

class _GrowthPdfChart {
  _GrowthPdfChart({
    required this.sex,
    required this.metric,
    required this.measurements,
    required this.axisMonthsLabel,
    required this.legendMin,
    required this.legendAvg,
    required this.legendMax,
    required this.legendBaby,
    required this.emptyLabel,
  });

  final GrowthCurveSex sex;
  final GrowthChartMetric metric;
  final List<GrowthMeasurementPoint> measurements;
  final String axisMonthsLabel;
  final String legendMin;
  final String legendAvg;
  final String legendMax;
  final String legendBaby;
  final String emptyLabel;

  bool get isEmpty => _normalized().isEmpty;

  bool get _isWeight => metric == GrowthChartMetric.weight;

  List<GrowthMeasurementPoint> _normalized() {
    final list = _isWeight
        ? measurements.where((m) => m.weightKg != null).toList()
        : measurements.where((m) => m.heightCm != null).toList();
    if (list.isEmpty) return const [];
    return GrowthMeasurementsBuilder.normalizeAgesForChart(list);
  }

  static double _monthsFromDays(int days) => days / 30.4375;

  List<({double x, double y})> _babyPoints(List<GrowthMeasurementPoint> points) {
    final raw = <({double x, double y})>[];
    for (final m in points) {
      final y = _isWeight ? m.weightKg : m.heightCm;
      if (y == null) continue;
      raw.add((x: _monthsFromDays(math.max(0, m.ageDays)), y: y));
    }
    raw.sort((a, b) => a.x.compareTo(b.x));
    if (raw.length <= 1) return raw;
    final merged = <({double x, double y})>[raw.first];
    for (var i = 1; i < raw.length; i++) {
      final prev = merged.last;
      final cur = raw[i];
      if ((cur.x - prev.x).abs() < 0.02) {
        merged[merged.length - 1] = cur.y >= prev.y ? cur : prev;
      } else {
        merged.add(cur);
      }
    }
    return merged;
  }

  List<({double x, double y})> _refPoints(
    double Function(GrowthCurvePoint p) pickY,
    double maxXMonths,
  ) {
    final curve = GrowthCurves.curveFor(sex);
    final out = <({double x, double y})>[];
    for (final p in curve) {
      final x = _monthsFromDays(p.ageDays);
      if (x > maxXMonths + 0.5) break;
      out.add((x: x, y: pickY(p)));
    }
    return out;
  }

  pw.Widget build() {
    final normalized = _normalized();
    final baby = _babyPoints(normalized);
    final maxBabyAgeDays =
        normalized.map((m) => math.max(0, m.ageDays)).reduce(math.max);
    final maxX = math.min(
      48.0,
      math.max(3.0, _monthsFromDays(maxBabyAgeDays) + 1.5),
    );

    final minPts = _refPoints(
      (p) => _isWeight ? p.minWeightKg : p.minHeightCm,
      maxX,
    );
    final avgPts = _refPoints(
      (p) => _isWeight ? p.avgWeightKg : p.avgHeightCm,
      maxX,
    );
    final maxPts = _refPoints(
      (p) => _isWeight ? p.maxWeightKg : p.maxHeightCm,
      maxX,
    );

    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final list in [minPts, avgPts, maxPts, baby]) {
      for (final s in list) {
        minY = math.min(minY, s.y);
        maxY = math.max(maxY, s.y);
      }
    }
    final yPad = math.max((maxY - minY) * 0.08, _isWeight ? 0.4 : 2.0);
    minY -= yPad;
    maxY += yPad;

    final refMinColor = sex == GrowthCurveSex.male
        ? const PdfColor.fromInt(0xFF90CAF9)
        : const PdfColor.fromInt(0xFFCE93D8);
    final refAvgColor = sex == GrowthCurveSex.male
        ? const PdfColor.fromInt(0xFF1565C0)
        : const PdfColor.fromInt(0xFF8E24AA);
    final refMaxColor = sex == GrowthCurveSex.male
        ? const PdfColor.fromInt(0xFF0D47A1)
        : const PdfColor.fromInt(0xFF4A148C);
    final babyColor = sex == GrowthCurveSex.male
        ? const PdfColor.fromInt(0xFFE65100)
        : const PdfColor.fromInt(0xFF00897B);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(
          height: 145,
          child: pw.CustomPaint(
            size: const PdfPoint(500, 145),
            painter: (canvas, size) {
          const left = 38.0;
          const top = 10.0;
          final w = size.x - left - 10;
          final h = size.y - top - 8;

          double xPos(double months) => left + (months / maxX) * w;
          double yPos(double v) =>
              top + h - ((v - minY) / (maxY - minY)) * h;

          canvas
            ..setLineWidth(0.4)
            ..setStrokeColor(const PdfColor.fromInt(0xFFE0E0E0));
          for (var m = 0.0; m <= maxX; m += maxX <= 6 ? 1 : 2) {
            final x = xPos(m);
            canvas
              ..moveTo(x, top)
              ..lineTo(x, top + h)
              ..strokePath();
          }

          void drawSeries(
            List<({double x, double y})> pts,
            PdfColor color, {
            double width = 2,
            bool dashed = false,
          }) {
            if (pts.isEmpty) return;
            canvas
              ..setLineWidth(width)
              ..setStrokeColor(color);
            if (dashed) {
              for (var i = 0; i < pts.length - 1; i++) {
                _dashedLine(
                  canvas,
                  xPos(pts[i].x),
                  yPos(pts[i].y),
                  xPos(pts[i + 1].x),
                  yPos(pts[i + 1].y),
                );
              }
            } else {
              canvas.moveTo(xPos(pts.first.x), yPos(pts.first.y));
              for (var i = 1; i < pts.length; i++) {
                canvas.lineTo(xPos(pts[i].x), yPos(pts[i].y));
              }
              canvas.strokePath();
            }
          }

          drawSeries(minPts, refMinColor, width: 1.2, dashed: true);
          drawSeries(avgPts, refAvgColor, width: 1.6);
          drawSeries(maxPts, refMaxColor, width: 1.2, dashed: true);
          drawSeries(baby, babyColor, width: 2.8);

          for (final p in baby) {
            final cx = xPos(p.x);
            final cy = yPos(p.y);
            canvas
              ..setFillColor(babyColor)
              ..drawEllipse(cx - 2.5, cy - 2.5, 5, 5)
              ..setFillColor(PdfColors.white)
              ..drawEllipse(cx - 1.2, cy - 1.2, 2.4, 2.4)
              ..setFillColor(babyColor)
              ..drawEllipse(cx - 0.8, cy - 0.8, 1.6, 1.6);
          }
        },
      ),
    ),
        pw.SizedBox(height: 2),
        pw.Text(
          PediatricReportText.forPdf(axisMonthsLabel),
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColor.fromInt(0xFF757575),
          ),
        ),
      ],
    );
  }

  pw.Widget buildLegend() {
    final refMinColor = sex == GrowthCurveSex.male
        ? const PdfColor.fromInt(0xFF90CAF9)
        : const PdfColor.fromInt(0xFFCE93D8);
    final refAvgColor = sex == GrowthCurveSex.male
        ? const PdfColor.fromInt(0xFF1565C0)
        : const PdfColor.fromInt(0xFF8E24AA);
    final refMaxColor = sex == GrowthCurveSex.male
        ? const PdfColor.fromInt(0xFF0D47A1)
        : const PdfColor.fromInt(0xFF4A148C);
    final babyColor = sex == GrowthCurveSex.male
        ? const PdfColor.fromInt(0xFFE65100)
        : const PdfColor.fromInt(0xFF00897B);
    return pw.Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        _legendChip(legendMin, refMinColor),
        _legendChip(legendAvg, refAvgColor),
        _legendChip(legendMax, refMaxColor),
        _legendChip(legendBaby, babyColor),
      ],
    );
  }

  pw.Widget _legendChip(String label, PdfColor color) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 18,
          height: 3,
          color: color,
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          PediatricReportText.forPdf(label),
          style: const pw.TextStyle(fontSize: 7.5),
        ),
      ],
    );
  }

  static void _dashedLine(
    PdfGraphics canvas,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    const dash = 4.0;
    const gap = 3.0;
    final dx = x2 - x1;
    final dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len <= 0) return;
    var dist = 0.0;
    var draw = true;
    while (dist < len) {
      final seg = draw ? dash : gap;
      final next = math.min(dist + seg, len);
      final t0 = dist / len;
      final t1 = next / len;
      final ax = x1 + dx * t0;
      final ay = y1 + dy * t0;
      final bx = x1 + dx * t1;
      final by = y1 + dy * t1;
      if (draw) {
        canvas
          ..moveTo(ax, ay)
          ..lineTo(bx, by)
          ..strokePath();
      }
      dist = next;
      draw = !draw;
    }
  }
}
