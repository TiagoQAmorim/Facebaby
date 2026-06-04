import 'package:intl/intl.dart';

import '../i18n/app_i18n.dart';
import '../models/pediatric_symptom_occurrence.dart';

/// Texto do relatório pediátrico: sintomas com contagem e data/hora por ocorrência.
abstract final class PediatricReportSymptomLines {
  PediatricReportSymptomLines._();

  static const List<String> kindOrder = [
    'reflux',
    'colic',
    'crying',
    'pain',
    'fever',
    'medication',
    'other',
  ];

  static String _labelForKind(S s, String kind) {
    return switch (kind) {
      'reflux' => s.reportPediatricSymptomReflux,
      'colic' => s.reportPediatricSymptomColic,
      'crying' => s.reportPediatricSymptomCrying,
      'pain' => s.reportPediatricSymptomPain,
      'fever' => s.symptomReportFever,
      'medication' => s.symptomReportMedication,
      'other' => s.symptomReportOther,
      _ => kind,
    };
  }

  static String formatOccurrenceLine(PediatricSymptomOccurrence o, String locale, S s) {
    final date = DateFormat('dd/MM/yyyy', locale).format(o.at);
    if (o.journalDayOnly) {
      return '$date - ${s.reportPediatricSymptomFromJournal}';
    }
    final time = DateFormat.jm(locale).format(o.at);
    final d = o.detail?.trim();
    if (d != null && d.isNotEmpty) {
      return '$date - $time, $d';
    }
    return '$date - $time';
  }

  /// Blocos multi-linha (título com contagem + linhas de data/hora).
  static List<String> buildBlocks(S s, Map<String, List<PediatricSymptomOccurrence>> map, String locale) {
    final out = <String>[];
    for (final kind in kindOrder) {
      final list = map[kind] ?? const <PediatricSymptomOccurrence>[];
      if (list.isEmpty) continue;
      final label = _labelForKind(s, kind);
      final lines = <String>['$label - ${list.length}'];
      for (final o in list) {
        lines.add(formatOccurrenceLine(o, locale, s));
      }
      out.add(lines.join('\n'));
    }
    return out;
  }

  static bool hasAnyOccurrence(Map<String, List<PediatricSymptomOccurrence>> map) {
    for (final list in map.values) {
      if (list.isNotEmpty) return true;
    }
    return false;
  }
}
