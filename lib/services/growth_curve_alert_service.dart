import '../data/growth_curves.dart';
import '../i18n/app_i18n.dart';
import '../models/growth_measurement_point.dart';
import '../utils/growth_measurements_builder.dart';
import 'app_database.dart';
import 'growth_analyzer_service.dart';

/// Medição fora da faixa saudável da curva de referência (OMS / FaceBaby).
class GrowthCurveOutOfBand {
  const GrowthCurveOutOfBand({
    required this.kind,
    required this.band,
    required this.value,
    required this.recordId,
    required this.refMin,
    required this.refMax,
    required this.ageMonths,
  });

  final String kind;
  final GrowthReferenceBand band;
  final double value;
  final int recordId;
  final double refMin;
  final double refMax;
  final int ageMonths;

  String get signature => '${kind}_${band.name}_$recordId';

  bool get isBelow => band == GrowthReferenceBand.belowHealthyMin;
  bool get isAbove => band == GrowthReferenceBand.aboveHealthyMax;
}

/// Analisa peso e altura vs curva de referência para alertas urgentes.
class GrowthCurveAlertService {
  const GrowthCurveAlertService({GrowthAnalyzerService? analyzer})
      : _analyzer = analyzer ?? const GrowthAnalyzerService();

  final GrowthAnalyzerService _analyzer;

  Future<List<GrowthCurveOutOfBand>> outOfBandForBaby({
    required int babyId,
    String? babySex,
    DateTime? birthDate,
  }) async {
    if (birthDate == null) return const [];

    final baby = await AppDatabase.instance.getBabyById(babyId);
    final birthH = (baby?['height_cm'] as num?)?.toDouble();
    final birthW = (baby?['weight_kg'] as num?)?.toDouble();
    final sex = GrowthCurves.sexFromProfile(babySex);

    final out = <GrowthCurveOutOfBand>[];

    final wRows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: 'weight',
      limit: 400,
    );
    final weightPoints = GrowthMeasurementsBuilder.weightFromRows(
      birthDate: birthDate,
      weightRows: wRows,
      birthWeightKg: birthW,
    );
    final w = _latestOutOfBand(
      kind: 'weight',
      sex: sex,
      points: weightPoints,
      readValue: (p) => p.weightKg,
      analyze: (s, m) => _analyzer.analyzeWeight(sex: s, measurements: m),
      refMin: (r) => r.minWeightKg,
      refMax: (r) => r.maxWeightKg,
      rows: wRows,
    );
    if (w != null) out.add(w);

    final hRows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: 'height',
      limit: 400,
    );
    final heightPoints = GrowthMeasurementsBuilder.heightFromRows(
      birthDate: birthDate,
      heightRows: hRows,
      birthHeightCm: birthH,
    );
    final h = _latestOutOfBand(
      kind: 'height',
      sex: sex,
      points: heightPoints,
      readValue: (p) => p.heightCm,
      analyze: (s, m) => _analyzer.analyzeHeight(sex: s, measurements: m),
      refMin: (r) => r.minHeightCm,
      refMax: (r) => r.maxHeightCm,
      rows: hRows,
    );
    if (h != null) out.add(h);

    return out;
  }

  GrowthCurveOutOfBand? _latestOutOfBand({
    required String kind,
    required GrowthCurveSex sex,
    required List<GrowthMeasurementPoint> points,
    required double? Function(GrowthMeasurementPoint) readValue,
    required GrowthAnalysisResult Function(
      GrowthCurveSex sex,
      List<GrowthMeasurementPoint> measurements,
    ) analyze,
    required double Function(GrowthCurvePoint) refMin,
    required double Function(GrowthCurvePoint) refMax,
    required List<Map<String, Object?>> rows,
  }) {
    if (points.isEmpty || rows.isEmpty) return null;

    final analysis = analyze(sex, points);
    final band = analysis.referenceBand;
    if (band != GrowthReferenceBand.belowHealthyMin &&
        band != GrowthReferenceBand.aboveHealthyMax) {
      return null;
    }

    final latestPoint = points.last;
    final value = readValue(latestPoint);
    if (value == null || value <= 0) return null;

    final ref = analysis.referenceAtAge;
    if (ref == null) return null;

    final sortedRows = List<Map<String, Object?>>.from(rows)
      ..sort((a, b) {
        final am = a['measured_at'] as String? ?? '';
        final bm = b['measured_at'] as String? ?? '';
        return bm.compareTo(am);
      });
    final recordId = (sortedRows.first['id'] as num?)?.toInt();
    if (recordId == null) return null;

    return GrowthCurveOutOfBand(
      kind: kind,
      band: band,
      value: value,
      recordId: recordId,
      refMin: refMin(ref),
      refMax: refMax(ref),
      ageMonths: ref.ageMonths,
    );
  }

  /// Prioridade do balão (menor = mais urgente). Abaixo da curva ligeiramente
  /// mais prioritário que acima.
  static int bubblePriority(GrowthCurveOutOfBand item) {
    final base = item.kind == 'weight' ? 0 : 2;
    if (item.isBelow) return 8 + base;
    return 9 + base;
  }

  static String bubbleText({
    required GrowthCurveOutOfBand item,
    required String babyName,
    required S strings,
  }) {
    final name = babyName.trim().isEmpty ? strings.baby : babyName.trim();
    final valueStr = item.kind == 'weight'
        ? _fmtKg(item.value)
        : _fmtCm(item.value);
    final minStr = item.kind == 'weight'
        ? _fmtKg(item.refMin)
        : _fmtCm(item.refMin);
    final maxStr = item.kind == 'weight'
        ? _fmtKg(item.refMax)
        : _fmtCm(item.refMax);

    if (item.kind == 'weight') {
      if (item.isBelow) {
        return strings.aiBubbleGrowthWeightBelow(
          name,
          valueStr,
          minStr,
          maxStr,
        );
      }
      return strings.aiBubbleGrowthWeightAbove(
        name,
        valueStr,
        minStr,
        maxStr,
      );
    }
    if (item.isBelow) {
      return strings.aiBubbleGrowthHeightBelow(
        name,
        valueStr,
        minStr,
        maxStr,
      );
    }
    return strings.aiBubbleGrowthHeightAbove(
      name,
      valueStr,
      minStr,
      maxStr,
    );
  }

  static String notifyTitle(GrowthCurveOutOfBand item, S strings) {
    if (item.kind == 'weight') {
      return item.isBelow
          ? strings.notifyGrowthWeightBelowTitle
          : strings.notifyGrowthWeightAboveTitle;
    }
    return item.isBelow
        ? strings.notifyGrowthHeightBelowTitle
        : strings.notifyGrowthHeightAboveTitle;
  }

  static String notifyBody(GrowthCurveOutOfBand item, S strings) {
    final valueStr = item.kind == 'weight'
        ? _fmtKg(item.value)
        : _fmtCm(item.value);
    final minStr = item.kind == 'weight'
        ? _fmtKg(item.refMin)
        : _fmtCm(item.refMin);
    final maxStr = item.kind == 'weight'
        ? _fmtKg(item.refMax)
        : _fmtCm(item.refMax);

    if (item.kind == 'weight') {
      if (item.isBelow) {
        return strings.notifyGrowthWeightBelowBody(
          valueStr,
          minStr,
          maxStr,
        );
      }
      return strings.notifyGrowthWeightAboveBody(
        valueStr,
        minStr,
        maxStr,
      );
    }
    if (item.isBelow) {
      return strings.notifyGrowthHeightBelowBody(
        valueStr,
        minStr,
        maxStr,
      );
    }
    return strings.notifyGrowthHeightAboveBody(
      valueStr,
      minStr,
      maxStr,
    );
  }

  static int notifyId(GrowthCurveOutOfBand item) => switch (item.kind) {
        'weight' when item.isBelow => 1010,
        'weight' => 1011,
        'height' when item.isBelow => 1012,
        _ => 1013,
      };

  static String _fmtKg(double kg) =>
      kg.toStringAsFixed(2).replaceAll('.', ',');

  static String _fmtCm(double cm) =>
      cm.toStringAsFixed(1).replaceAll('.', ',');
}
