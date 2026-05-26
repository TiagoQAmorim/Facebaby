import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../utils/ai_nanny_parse_normalize.dart';

/// Pós-processamento do JSON (cloud ou local) para valores canónicos.
abstract final class AiNannyParseResultNormalizer {
  static AiNannyParseResult normalize(AiNannyParseResult raw, String sourceText) {
    if (!raw.hasRecords) return raw;
    final records = raw.records
        .map((r) => _normalizeRecord(r, sourceText))
        .toList();
    return AiNannyParseResult(
      classification: raw.classification,
      records: records,
      needsConfirmation: raw.needsConfirmation,
    );
  }

  static AiNannyStructuredRecord _normalizeRecord(
    AiNannyStructuredRecord r,
    String text,
  ) {
    final fields = Map<String, dynamic>.from(r.fields);

    if (r.type == 'feeding') {
      final ft = '${fields['feedingType'] ?? ''}'.toLowerCase();
      if (ft == 'breast' || ft == 'peito') {
        fields['feedingType'] = 'breastfeeding';
      }
      final side = fields['breastSide'];
      if (side is String) {
        fields['breastSide'] = _normalizeSide(side);
      } else {
        final parsed = AiNannyParseNormalize.parseBreastSideCanonical(text);
        if (parsed != null) fields['breastSide'] = parsed;
      }
      final mins = fields['durationMinutes'];
      if (mins == null) {
        final p = AiNannyParseNormalize.parseDurationMinutes(text);
        if (p != null) fields['durationMinutes'] = p;
      }
    }

    if (r.type == 'health_symptom') {
      final t = fields['temperatureCelsius'];
      if (t is String) {
        fields['temperatureCelsius'] =
            double.tryParse(t.replaceAll(',', '.'));
      }
      if (fields['temperatureCelsius'] == null) {
        final p = AiNannyParseNormalize.parseTemperatureCelsius(text);
        if (p != null) fields['temperatureCelsius'] = p;
      }
    }

    if (fields['time'] is String) {
      final t = AiNannyParseNormalize.parseTime24h(text);
      if (t != null) fields['time'] = t;
    }

    return AiNannyStructuredRecord(
      type: r.type,
      missingFields: r.missingFields,
      fields: fields,
    );
  }

  static String _normalizeSide(String side) {
    final s = side.toLowerCase();
    if (s == 'e' || s == 'l' || s.contains('left') || s.contains('esquer')) {
      return 'left';
    }
    if (s == 'd' || s == 'r' || s.contains('right') || s.contains('direit')) {
      return 'right';
    }
    if (s.contains('both') || s.contains('ambos') || s.contains('deux')) {
      return 'both';
    }
    return side;
  }
}
