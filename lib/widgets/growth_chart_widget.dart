import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/growth_curves.dart';
import '../i18n/app_i18n.dart';
import '../models/growth_measurement_point.dart';
import '../utils/growth_measurements_builder.dart';

/// Paleta de cores por sexo — alto contraste entre faixa e evolução do bebê.
class _GrowthChartColors {
  const _GrowthChartColors({
    required this.min,
    required this.avg,
    required this.max,
    required this.baby,
  });

  final Color min;
  final Color avg;
  final Color max;
  final Color baby;

  static _GrowthChartColors forSex(GrowthCurveSex sex) {
    if (sex == GrowthCurveSex.male) {
      return const _GrowthChartColors(
        min: Color(0xFF90CAF9),
        avg: Color(0xFF1565C0),
        max: Color(0xFF0D47A1),
        baby: Color(0xFFE65100),
      );
    }
    return const _GrowthChartColors(
      min: Color(0xFFCE93D8),
      avg: Color(0xFF8E24AA),
      max: Color(0xFF4A148C),
      baby: Color(0xFF00897B),
    );
  }
}

/// Premium growth chart: baby line + min / avg / max healthy reference (by sex).
class GrowthChartWidget extends StatelessWidget {
  const GrowthChartWidget({
    super.key,
    required this.sex,
    required this.measurements,
    required this.strings,
    this.metric = GrowthChartMetric.height,
    this.showSexHint = false,
    this.maxAgeMonths = 48,
  });

  final GrowthCurveSex sex;
  final List<GrowthMeasurementPoint> measurements;
  final S strings;
  final GrowthChartMetric metric;
  final bool showSexHint;
  final int maxAgeMonths;

  bool get _isWeight => metric == GrowthChartMetric.weight;

  static double _monthsFromDays(int days) => days / 30.4375;

  List<FlSpot> _babySpots(List<GrowthMeasurementPoint> points) {
    final spots = <FlSpot>[];
    for (final m in points) {
      final y = _isWeight ? m.weightKg : m.heightCm;
      if (y == null) continue;
      final x = _monthsFromDays(math.max(0, m.ageDays));
      spots.add(FlSpot(x, y));
    }
    spots.sort((a, b) => a.x.compareTo(b.x));

    if (spots.length <= 1) return spots;

    final merged = <FlSpot>[spots.first];
    for (var i = 1; i < spots.length; i++) {
      final prev = merged.last;
      final cur = spots[i];
      if ((cur.x - prev.x).abs() < 0.02) {
        // Mesma idade: manter nascimento no 1.º ponto; medições novas com leve deslocamento.
        if ((cur.y - prev.y).abs() > 0.001) {
          merged.add(FlSpot(cur.x + 0.05, cur.y));
        }
        continue;
      }
      merged.add(cur);
    }
    return merged;
  }

  List<FlSpot> _referenceSpots(
    List<GrowthCurvePoint> curve,
    double Function(GrowthCurvePoint p) pickY,
    double maxXMonths,
  ) {
    final spots = <FlSpot>[];
    for (final p in curve) {
      final x = _monthsFromDays(p.ageDays);
      if (x > maxXMonths + 0.5) break;
      spots.add(FlSpot(x, pickY(p)));
    }
    return spots;
  }

  String _formatY(double v) {
    if (_isWeight) {
      return v >= 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(2);
    }
    return '${v.round()}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _GrowthChartColors.forSex(sex);
    final curve = GrowthCurves.curveFor(sex);
    final refTitle = sex == GrowthCurveSex.male
        ? strings.growthCurveReferenceBoys
        : strings.growthCurveReferenceGirls;

    final normalized = GrowthMeasurementsBuilder.normalizeAgesForChart(
      _isWeight
          ? measurements.where((m) => m.weightKg != null).toList()
          : measurements.where((m) => m.heightCm != null).toList(),
    );

    if (normalized.isEmpty) {
      final emptyLabel =
          _isWeight ? strings.labelWeight : strings.labelHeight;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            refTitle,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.black.withAlpha(160),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: Center(
              child: Text(
                strings.growthEmpty(emptyLabel),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black.withAlpha(140)),
              ),
            ),
          ),
        ],
      );
    }

    final babySpots = _babySpots(normalized);
    final maxBabyAgeDays =
        normalized.map((m) => math.max(0, m.ageDays)).reduce(math.max);
    final maxXMonths = math.min(
      maxAgeMonths.toDouble(),
      math.max(3.0, _monthsFromDays(maxBabyAgeDays) + 1.5),
    );

    final minSpots = _referenceSpots(
      curve,
      (p) => _isWeight ? p.minWeightKg : p.minHeightCm,
      maxXMonths,
    );
    final avgSpots = _referenceSpots(
      curve,
      (p) => _isWeight ? p.avgWeightKg : p.avgHeightCm,
      maxXMonths,
    );
    final maxSpots = _referenceSpots(
      curve,
      (p) => _isWeight ? p.maxWeightKg : p.maxHeightCm,
      maxXMonths,
    );

    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final list in [minSpots, avgSpots, maxSpots, babySpots]) {
      for (final s in list) {
        minY = math.min(minY, s.y);
        maxY = math.max(maxY, s.y);
      }
    }
    final yPad = math.max((maxY - minY) * 0.08, _isWeight ? 0.4 : 2.0);
    minY -= yPad;
    maxY += yPad;

    final yInterval = _niceInterval(maxY - minY);

    final chart = AspectRatio(
      aspectRatio: 1.55,
      child: Padding(
        padding: const EdgeInsets.only(right: 6, top: 8),
        child: LineChart(
          LineChartData(
            clipData: const FlClipData.all(),
            minX: 0,
            maxX: maxXMonths,
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.black.withAlpha(22), strokeWidth: 1),
              getDrawingVerticalLine: (_) =>
                  FlLine(color: Colors.black.withAlpha(16), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: yInterval,
                  getTitlesWidget: (v, _) => Text(
                    _formatY(v),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black.withAlpha(130),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: Text(
                  strings.growthCurveAxisMonths,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withAlpha(120),
                  ),
                ),
                axisNameSize: 18,
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: maxXMonths <= 6 ? 1 : (maxXMonths <= 14 ? 2 : 6),
                  getTitlesWidget: (v, _) => Text(
                    '${v.round()}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.black.withAlpha(120),
                    ),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              _refLine(minSpots, colors.min, dashed: true),
              _refLine(avgSpots, colors.avg),
              _refLine(maxSpots, colors.max, dashed: true),
              LineChartBarData(
                spots: babySpots,
                isCurved: babySpots.length >= 3,
                curveSmoothness: 0.28,
                preventCurveOverShooting: true,
                color: colors.baby,
                barWidth: 3.4,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 5,
                    color: colors.baby,
                    strokeWidth: 2.5,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: babySpots.length >= 2,
                  gradient: LinearGradient(
                    colors: [
                      colors.baby.withAlpha(55),
                      colors.baby.withAlpha(6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          refTitle,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.black.withAlpha(170),
          ),
        ),
        if (showSexHint) ...[
          const SizedBox(height: 6),
          Text(
            strings.growthCurveSexHint,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.3,
              color: Colors.black.withAlpha(120),
            ),
          ),
        ],
        const SizedBox(height: 8),
        chart,
        const SizedBox(height: 10),
        _LegendRow(
          items: [
            _LegendItem(
              color: colors.min,
              label: strings.growthCurveLegendMin,
              dashed: true,
            ),
            _LegendItem(
              color: colors.avg,
              label: strings.growthCurveLegendAvg,
            ),
            _LegendItem(
              color: colors.max,
              label: strings.growthCurveLegendMax,
              dashed: true,
            ),
            _LegendItem(
              color: colors.baby,
              label: strings.growthCurveLegendBaby,
              thick: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          strings.growthCurveDisclaimer,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.35,
            fontStyle: FontStyle.italic,
            color: Colors.black.withAlpha(110),
          ),
        ),
      ],
    );
  }

  LineChartBarData _refLine(List<FlSpot> spots, Color color,
      {bool dashed = false}) {
    return LineChartBarData(
      spots: spots,
      isCurved: spots.length >= 3,
      curveSmoothness: 0.35,
      color: color,
      barWidth: dashed ? 2.0 : 2.6,
      dotData: const FlDotData(show: false),
      dashArray: dashed ? [7, 5] : null,
    );
  }

  double _niceInterval(double span) {
    if (_isWeight) {
      if (span <= 2) return 0.5;
      if (span <= 5) return 1;
      if (span <= 12) return 2;
      return 4;
    }
    if (span <= 8) return 2;
    if (span <= 16) return 4;
    if (span <= 40) return 5;
    return 10;
  }
}

class _LegendItem {
  const _LegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
    this.thick = false,
  });

  final Color color;
  final String label;
  final bool dashed;
  final bool thick;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.items});

  final List<_LegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: items.map((e) => _LegendChip(item: e)).toList(),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.item});

  final _LegendItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 14,
          child: CustomPaint(
            painter: _LegendLinePainter(
              color: item.color,
              dashed: item.dashed,
              thick: item.thick,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.black.withAlpha(175),
          ),
        ),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  _LegendLinePainter({
    required this.color,
    required this.dashed,
    required this.thick,
  });

  final Color color;
  final bool dashed;
  final bool thick;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick ? 3.2 : 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    if (dashed) {
      const dash = 5.0;
      const gap = 4.0;
      var x = 0.0;
      while (x < size.width) {
        final end = math.min(x + dash, size.width);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
        x += dash + gap;
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dashed != dashed ||
      oldDelegate.thick != thick;
}
