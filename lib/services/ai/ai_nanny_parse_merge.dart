import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../utils/ai_nanny_parse_normalize.dart';
import 'ai_nanny_intent_lexicon.dart';
import 'routine_absence_detection.dart';

/// União cloud + local — preserva vários tipos na mesma frase (ex.: acordou + cresceu).
abstract final class AiNannyParseMerge {
  static AiNannyParseResult merge(
    AiNannyParseResult primary,
    AiNannyParseResult local,
    String message,
  ) {
    if (!local.hasRecords) {
      final filtered = dropNegatedRoutineObservations(
        _filterSpurious(primary.records),
        message,
      );
      if (filtered.isEmpty) {
        return const AiNannyParseResult(classification: 'chat_only');
      }
      return AiNannyParseResult(
        classification: primary.classification,
        records: filtered,
        needsConfirmation: primary.needsConfirmation,
      );
    }
    if (!primary.hasRecords) return local;

    final byType = <String, AiNannyStructuredRecord>{};
    for (final r in primary.records) {
      final key = _mergeKey(r);
      byType[key] = r;
    }
    for (final r in local.records) {
      final key = _mergeKey(r);
      final existing = byType[key];
      if (existing == null) {
        byType[key] = r;
        continue;
      }
      byType[key] = _pickRicher(existing, r);
    }

    var merged = dropSpuriousDiaperWhenGrowthPresent(
      byType.values.toList(),
      local,
      message,
    );
    merged = dropNegatedRoutineObservations(merged, message);
    merged = _filterSpurious(merged);
    if (merged.isEmpty) {
      return const AiNannyParseResult(classification: 'chat_only');
    }
    return AiNannyParseResult(
      classification: 'create_records',
      records: merged,
      needsConfirmation: true,
    );
  }

  /// Cloud pode devolver registro mesmo em negação — filtra observação de ausência.
  static List<AiNannyStructuredRecord> dropNegatedRoutineObservations(
    List<AiNannyStructuredRecord> records,
    String message,
  ) {
    final blocked = RoutineAbsenceDetection.blockedRecordTypes(message);
    if (blocked.isEmpty) return records;
    return records
        .where(
          (r) => !blocked.contains(
            AiNannyParseNormalize.canonicalRecordType(r.type, r.fields),
          ),
        )
        .toList();
  }

  static String _mergeKey(AiNannyStructuredRecord r) =>
      AiNannyParseNormalize.canonicalRecordType(r.type, r.fields);

  static List<AiNannyStructuredRecord> _filterSpurious(
    List<AiNannyStructuredRecord> records,
  ) {
    if (records.length <= 1) return records;
    final typed = records
        .where((r) => !AiNannyParseNormalize.isLowInformationRecord(r))
        .toList();
    return typed.isNotEmpty ? typed : records;
  }

  /// Cloud às vezes devolve fralda incompleta em frases de altura/peso.
  static List<AiNannyStructuredRecord> dropSpuriousDiaperWhenGrowthPresent(
    List<AiNannyStructuredRecord> records,
    AiNannyParseResult local,
    String message,
  ) {
    final low = message.toLowerCase();
    final localGrowth = local.records.any(
      (r) =>
          r.type == 'growth_height' ||
          r.type == 'growth_weight' ||
          AiNannyParseNormalize.parseHeightDeltaCm(message) != null ||
          AiNannyParseNormalize.parseWeightDeltaGrams(message) != null,
    );
    if (!localGrowth) return records;

    final hasDiaperCue = AiNannyIntentLexicon.hasDiaperCue(low) ||
        AiNannyIntentLexicon.hasPeeCue(low) ||
        AiNannyIntentLexicon.hasPooCue(low);

    return records.where((r) {
      if (r.type != 'diaper') return true;
      if (hasDiaperCue) return true;
      final incomplete =
          r.missingFields.contains('pee') || r.missingFields.contains('poop');
      return !incomplete;
    }).toList();
  }

  static AiNannyStructuredRecord _pickRicher(
    AiNannyStructuredRecord a,
    AiNannyStructuredRecord b,
  ) {
    if (a.missingFields.length != b.missingFields.length) {
      return a.missingFields.length < b.missingFields.length ? a : b;
    }
    int score(AiNannyStructuredRecord r) {
      var s = r.fields.length;
      if ('${r.fields['vaccineName'] ?? ''}'.trim().isNotEmpty) s += 3;
      if ('${r.fields['reasonOrSpecialty'] ?? ''}'.trim().isNotEmpty) s += 3;
      if ('${r.fields['value'] ?? ''}'.trim().isNotEmpty) s += 3;
      if ('${r.fields['date'] ?? ''}'.trim().isNotEmpty) s += 2;
      if (r.fields['nextDueDate'] != null || r.fields['nextDueInDays'] != null) {
        s += 4;
      }
      return s;
    }
    return score(a) >= score(b) ? a : b;
  }
}
