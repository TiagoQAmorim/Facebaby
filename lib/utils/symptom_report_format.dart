import 'package:intl/intl.dart';

import '../i18n/app_i18n.dart';
import '../models/symptom_report.dart';
import 'measurement_format.dart';

abstract final class SymptomReportFormat {
  SymptomReportFormat._();

  /// Linha compacta para listas e PDF (uma entrada por relato).
  static String summaryLine(S s, SymptomReport r, String locale) {
    final parts = <String>[];
    final d = r.occurredAt;
    final datePart = DateFormat.yMMMd(locale).format(d);
    final timePart = DateFormat.Hm(locale).format(d);
    parts.add('$datePart $timePart');

    final med = r.medicationNote?.trim();
    if (med != null && med.isNotEmpty) {
      parts.add('${s.symptomReportMedication}: $med');
    }
    if (r.fever) {
      final t = r.tempCelsius != null ? MeasurementFormat.temperature(r.tempCelsius) : s.symptomReportFever;
      parts.add('${s.symptomReportFever}: $t');
    }
    if (r.unexplainedCrying) parts.add(s.symptomReportCrying);
    if (r.pain) parts.add(s.symptomReportPain);
    if (r.colic) parts.add(s.symptomReportColic);
    if (r.reflux) parts.add(s.symptomReportReflux);
    final other = r.otherNote?.trim();
    if (other != null && other.isNotEmpty) {
      parts.add('${s.symptomReportOther}: $other');
    }
    return parts.join(' · ');
  }
}
