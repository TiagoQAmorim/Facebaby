import '../data/growth_curves.dart';
import '../i18n/app_i18n.dart';
import '../models/daily_summary.dart';
import '../services/app_database.dart';
import '../services/growth_analyzer_service.dart';
import '../utils/growth_baseline.dart';
import '../utils/growth_measurements_builder.dart';

/// Texto compacto «IA Babá · ontem» — tom pediátrico e de vínculo (curto).
abstract final class HomeYesterdayBabaService {
  HomeYesterdayBabaService._();

  static const _analyzer = GrowthAnalyzerService();
  static const _lowSleepThresholdSec = 6 * 3600;

  static Future<String> bodyForToday({
    required int? babyId,
    required String babyName,
    required String? babySex,
    required DateTime? birthDate,
    required S strings,
  }) async {
    if (babyId == null) {
      return strings.homeYesterdayBabaFallback(babyName);
    }

    final yesterday =
        _dateOnly(DateTime.now().subtract(const Duration(days: 1)));
    await AppDatabase.instance.ensureYesterdayDailySummarySnapshot(
      babyId: babyId,
    );

    final summary = await AppDatabase.instance.dailySummaryForHomePicker(
      babyId: babyId,
      calendarDay: yesterday,
    );

    final line1 = _routineLine(strings, summary);
    final line2 = await _growthLine(
      strings: strings,
      babyId: babyId,
      babySex: babySex,
      birthDate: birthDate,
    );

    if (line2.isEmpty) return line1;
    return '$line1 · $line2';
  }

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static String _routineLine(S strings, DailySummary s) {
    final empty = s.feedings == 0 &&
        s.diapers == 0 &&
        s.sleepTotalSeconds == 0 &&
        s.sleepSessions == 0;
    if (empty) return strings.homeYesterdayBabaRoutineQuiet;

    final sleep = s.sleep.trim().isEmpty ? '—' : s.sleep.trim();
    final lowSleep = s.sleepTotalSeconds > 0 &&
        s.sleepTotalSeconds < _lowSleepThresholdSec;

    if (lowSleep) {
      return strings.homeYesterdayBabaRoutineLowSleep(
        feeds: s.feedings,
        sleep: sleep,
        diapers: s.diapers,
      );
    }

    return strings.homeYesterdayBabaRoutine(
      feeds: s.feedings,
      sleep: sleep,
      diapers: s.diapers,
    );
  }

  static Future<String> _growthLine({
    required S strings,
    required int babyId,
    required String? babySex,
    required DateTime? birthDate,
  }) async {
    if (birthDate == null) return strings.homeYesterdayBabaGrowthNoData;

    final sex = GrowthCurves.sexFromProfile(babySex);
    final baby = await AppDatabase.instance.getBabyById(babyId);
    final birthH = GrowthBaseline.birthHeightCm(baby);
    final birthW = GrowthBaseline.birthWeightKg(baby);

    final hRows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: 'height',
      limit: 400,
    );
    final wRows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: 'weight',
      limit: 400,
    );

    final heightPoints = GrowthMeasurementsBuilder.heightFromRows(
      birthDate: birthDate,
      heightRows: hRows,
      birthHeightCm: birthH,
    );
    final weightPoints = GrowthMeasurementsBuilder.weightFromRows(
      birthDate: birthDate,
      weightRows: wRows,
      birthWeightKg: birthW,
    );

    if (heightPoints.isEmpty && weightPoints.isEmpty) {
      return strings.homeYesterdayBabaGrowthNoData;
    }

    final wBand = weightPoints.isEmpty
        ? GrowthReferenceBand.unknown
        : _analyzer
            .analyzeWeight(sex: sex, measurements: weightPoints)
            .referenceBand;
    final hBand = heightPoints.isEmpty
        ? GrowthReferenceBand.unknown
        : _analyzer
            .analyzeHeight(sex: sex, measurements: heightPoints)
            .referenceBand;

    if (wBand == GrowthReferenceBand.unknown &&
        hBand == GrowthReferenceBand.unknown) {
      return strings.homeYesterdayBabaGrowthNoData;
    }

    final hasBelow = wBand == GrowthReferenceBand.belowHealthyMin ||
        hBand == GrowthReferenceBand.belowHealthyMin;
    final hasAbove = wBand == GrowthReferenceBand.aboveHealthyMax ||
        hBand == GrowthReferenceBand.aboveHealthyMax;

    if (hasBelow) return strings.homeYesterdayBabaGrowthBelow;
    if (hasAbove) return strings.homeYesterdayBabaGrowthAbove;

    if (wBand == GrowthReferenceBand.withinHealthy &&
        hBand == GrowthReferenceBand.withinHealthy) {
      return strings.homeYesterdayBabaGrowthBothWithin;
    }

    return strings.homeYesterdayBabaGrowthCombo(
      weight: _bandLabel(strings, wBand),
      height: _bandLabel(strings, hBand),
    );
  }

  static String _bandLabel(S strings, GrowthReferenceBand band) =>
      switch (band) {
        GrowthReferenceBand.withinHealthy =>
          strings.homeYesterdayBabaBandWithin,
        GrowthReferenceBand.belowHealthyMin =>
          strings.homeYesterdayBabaBandBelow,
        GrowthReferenceBand.aboveHealthyMax =>
          strings.homeYesterdayBabaBandAbove,
        GrowthReferenceBand.unknown => strings.homeYesterdayBabaBandUnknown,
      };
}
