import '../models/development_report_snapshot.dart';

/// Marco normativo (idade típica em meses). Valores orientativos para uma UX positiva.
abstract final class DevelopmentReportService {
  DevelopmentReportService._();

  static double ageInMonths(DateTime birth, DateTime referenceDay) {
    final b = DateTime(birth.year, birth.month, birth.day);
    final r = DateTime(referenceDay.year, referenceDay.month, referenceDay.day);
    if (!r.isAfter(b)) return 0;
    return r.difference(b).inDays / 30.437;
  }

  static final List<({String id, double months})> _motor = [
    (id: 'motor_head', months: 2),
    (id: 'motor_roll', months: 4),
    (id: 'motor_sit', months: 6),
    (id: 'motor_crawl', months: 9),
    (id: 'motor_walk', months: 12),
  ];

  static final List<({String id, double months})> _cognitive = [
    (id: 'cog_faces', months: 2),
    (id: 'cog_sounds', months: 2.5),
    (id: 'cog_track', months: 3),
    (id: 'cog_babble', months: 6),
    (id: 'cog_visual', months: 2),
  ];

  static final List<({String id, double months})> _social = [
    (id: 'soc_smile', months: 2),
    (id: 'soc_emotion_resp', months: 3),
    (id: 'soc_family', months: 4),
    (id: 'soc_emotion_react', months: 3),
  ];

  static DevelopmentMilestoneItem _item(({String id, double months}) def, double ageM) {
    return DevelopmentMilestoneItem(
      id: def.id,
      typicalAgeMonths: def.months,
      achieved: ageM + 0.01 >= def.months,
    );
  }

  /// Carrega marcos para [referenceDay] (calcula idade a partir de [birthDate]).
  static DevelopmentReportSnapshot load({
    required DateTime birthDate,
    required DateTime referenceDay,
  }) {
    final ageM = ageInMonths(birthDate, referenceDay);

    final motor = _motor.map((e) => _item(e, ageM)).toList();
    final cog = _cognitive.map((e) => _item(e, ageM)).toList();
    final soc = _social.map((e) => _item(e, ageM)).toList();

    final all = [...motor, ...cog, ...soc];
    final achieved = all.where((e) => e.achieved).length;
    final total = all.length;
    var score = total == 0 ? 0 : ((achieved / total) * 100).round();

    // Primeiros dias: manter suavidade sem “zero absoluto”.
    if (ageM < 0.25 && score < 25) {
      score = 25;
    }

    score = score.clamp(0, 100);

    String statusKey = 'watch';
    if (score >= 72) {
      statusKey = 'on_track';
    } else if (score < 48) {
      statusKey = 'early';
    }

    String insightKey = 'devReportInsightBalanced';
    if (ageM < 1) {
      insightKey = 'devReportInsightNewborn';
    } else if (score >= 72) {
      insightKey = 'devReportInsightOnTrack';
    } else if (score >= 48) {
      insightKey = 'devReportInsightVariety';
    } else {
      insightKey = 'devReportInsightPatience';
    }

    return DevelopmentReportSnapshot(
      referenceDay: DateTime(referenceDay.year, referenceDay.month, referenceDay.day),
      ageMonths: ageM,
      developmentScore: score,
      statusKey: statusKey,
      insightKey: insightKey,
      motor: motor,
      cognitive: cog,
      social: soc,
    );
  }
}
