import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../utils/ai_nanny_parse_normalize.dart';
import 'ai_nanny_structured_clarification.dart';
import 'ai_nanny_structured_mapper.dart';

/// Durações por seio (amamentação «ambos» → dois registros).
class BreastBothDurations {
  const BreastBothDurations({required this.left, required this.right});

  final int left;
  final int right;
}

/// «Ambos os peitos» nunca vira um único registro final — divide em esquerdo + direito.
abstract final class BreastfeedingBothHelper {
  static bool shouldSplit(AiNannyStructuredRecord r) =>
      r.type == 'feeding' &&
      '${r.fields['feedingType'] ?? ''}'.toLowerCase() == 'breastfeeding' &&
      '${r.fields['breastSide'] ?? ''}' == 'both';

  static List<AiNannyStructuredRecord> splitToLeftRight(
    AiNannyStructuredRecord r,
  ) {
    final shared = Map<String, dynamic>.from(r.fields)
      ..remove('breastSide')
      ..remove('durationMinutes')
      ..remove('fromActiveTimer');
    shared['feedingType'] = 'breastfeeding';

    const needDuration = ['durationMinutes'];
    return [
      AiNannyStructuredRecord(
        type: 'feeding',
        fields: {...shared, 'breastSide': 'left', 'sideConfirmed': true},
        missingFields: needDuration,
      ),
      AiNannyStructuredRecord(
        type: 'feeding',
        fields: {...shared, 'breastSide': 'right', 'sideConfirmed': true},
        missingFields: needDuration,
      ),
    ];
  }

  /// Expande rascunhos com `breastSide: both` em dois cards (esquerdo + direito).
  static List<AiNannyRecordDraft> expandDrafts(
    List<AiNannyRecordDraft> drafts, {
    required S strings,
    required String sourceText,
    double? lastWeightKg,
    double? lastHeightCm,
  }) {
    final out = <AiNannyRecordDraft>[];
    for (final d in drafts) {
      if (shouldSplit(d.structured)) {
        for (final rec in splitToLeftRight(d.structured)) {
          final enforced = AiNannyStructuredClarification.enforce(
            rec,
            sourceText,
          );
          out.add(
            AiNannyStructuredMapper.draftFromRecord(
              enforced,
              strings: strings,
              sourceText: sourceText,
              lastWeightKg: lastWeightKg,
              lastHeightCm: lastHeightCm,
            ),
          );
        }
      } else {
        out.add(d);
      }
    }
    return out;
  }

  /// Substitui o rascunho no índice [atIndex] por dois (após escolher «ambos»).
  static List<AiNannyRecordDraft> expandAtIndex(
    List<AiNannyRecordDraft> drafts,
    int atIndex, {
    required S strings,
    required String sourceText,
    double? lastWeightKg,
    double? lastHeightCm,
  }) {
    if (atIndex < 0 || atIndex >= drafts.length) return drafts;
    if (!shouldSplit(drafts[atIndex].structured)) return drafts;

    final split = splitToLeftRight(drafts[atIndex].structured);
    final replacement = split
        .map(
          (rec) => AiNannyStructuredMapper.draftFromRecord(
            AiNannyStructuredClarification.enforce(rec, sourceText),
            strings: strings,
            sourceText: sourceText,
            lastWeightKg: lastWeightKg,
            lastHeightCm: lastHeightCm,
          ),
        )
        .toList();

    return [
      ...drafts.sublist(0, atIndex),
      ...replacement,
      ...drafts.sublist(atIndex + 1),
    ];
  }

  /// Pergunta de duração com lado explícito.
  static String durationQuestionForSide(String? side, S strings) {
    switch (side) {
      case 'left':
        return strings.aiFollowUpBreastLeftDuration;
      case 'right':
        return strings.aiFollowUpBreastRightDuration;
      default:
        return strings.aiFollowUpDurationQuestion;
    }
  }

  /// Interpreta respostas combinadas de duração dos dois seios.
  static BreastBothDurations? parseDualDurations(String text) {
    final low = text.toLowerCase();

    final explicitPair = RegExp(
      r'(\d{1,3})\s*(?:min(?:utos?)?)?\s*(?:no|em|na|on)?\s*(?:peito\s+)?esquerd[oa]?\b[\s\S]*?(\d{1,3})\s*(?:min(?:utos?)?)?\s*(?:no|em|na|on)?\s*(?:peito\s+)?direit[oa]?\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (explicitPair != null) {
      final l = int.tryParse(explicitPair.group(1)!);
      final r = int.tryParse(explicitPair.group(2)!);
      if (l != null && r != null && l > 0 && r > 0) {
        return BreastBothDurations(left: l, right: r);
      }
    }

    final each = RegExp(
      r'(\d{1,3})\s*(?:min(?:utos?)?)?\s*(?:em\s+)?cada\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (each != null) {
      final n = int.tryParse(each.group(1)!);
      if (n != null && n > 0 && n <= 180) {
        return BreastBothDurations(left: n, right: n);
      }
    }

    final bothSame = RegExp(
      r'(\d{1,3})\s*(?:min(?:utos?)?)?\s*(?:nos?\s+)?(?:dois|2|ambos)\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (bothSame != null) {
      final n = int.tryParse(bothSame.group(1)!);
      if (n != null && n > 0 && n <= 180) {
        return BreastBothDurations(left: n, right: n);
      }
    }

    final leftM = RegExp(
      r'(\d{1,3})\s*(?:min(?:utos?)?)?\s*(?:no|em|na|on)?\s*(?:peito\s+)?esquerd[oa]?\b',
      caseSensitive: false,
    ).firstMatch(low);
    final rightM = RegExp(
      r'(\d{1,3})\s*(?:min(?:utos?)?)?\s*(?:no|em|na|on)?\s*(?:peito\s+)?direit[oa]?\b',
      caseSensitive: false,
    ).firstMatch(low);
    if (leftM != null && rightM != null) {
      final l = int.tryParse(leftM.group(1)!);
      final r = int.tryParse(rightM.group(1)!);
      if (l != null && r != null && l > 0 && r > 0) {
        return BreastBothDurations(left: l, right: r);
      }
    }

    final twoNums = RegExp(
      r'(\d{1,3})\s*(?:min(?:utos?)?)?\s*e\s*(\d{1,3})',
      caseSensitive: false,
    ).firstMatch(low);
    if (twoNums != null &&
        !low.contains('esquer') &&
        !low.contains('direit')) {
      final l = int.tryParse(twoNums.group(1)!);
      final r = int.tryParse(twoNums.group(2)!);
      if (l != null && r != null && l > 0 && r > 0) {
        return BreastBothDurations(left: l, right: r);
      }
    }

    return null;
  }

  /// Aplica durações aos rascunhos esquerdo/direito se a frase tiver os dois tempos.
  static List<AiNannyRecordDraft>? tryApplyDualDurations({
    required List<AiNannyRecordDraft> drafts,
    required String sourceText,
    required S strings,
    double? lastWeightKg,
    double? lastHeightCm,
  }) {
    final dual = parseDualDurations(sourceText);
    if (dual == null) return null;

    final leftIdx = _indexForSide(drafts, 'left');
    final rightIdx = _indexForSide(drafts, 'right');
    if (leftIdx == null || rightIdx == null) return null;

    final updated = List<AiNannyRecordDraft>.from(drafts);

    updated[leftIdx] = AiNannyStructuredMapper.draftFromRecord(
      AiNannyStructuredClarification.enforce(
        _withDuration(updated[leftIdx].structured, dual.left),
        sourceText,
      ),
      strings: strings,
      sourceText: sourceText,
      lastWeightKg: lastWeightKg,
      lastHeightCm: lastHeightCm,
    );

    updated[rightIdx] = AiNannyStructuredMapper.draftFromRecord(
      AiNannyStructuredClarification.enforce(
        _withDuration(updated[rightIdx].structured, dual.right),
        sourceText,
      ),
      strings: strings,
      sourceText: sourceText,
      lastWeightKg: lastWeightKg,
      lastHeightCm: lastHeightCm,
    );

    return updated;
  }

  static int? _indexForSide(List<AiNannyRecordDraft> drafts, String side) {
    for (var i = 0; i < drafts.length; i++) {
      final r = drafts[i].structured;
      if (r.type != 'feeding') continue;
      if ('${r.fields['feedingType'] ?? ''}' != 'breastfeeding') continue;
      if ('${r.fields['breastSide'] ?? ''}' == side) return i;
    }
    return null;
  }

  static AiNannyStructuredRecord _withDuration(
    AiNannyStructuredRecord r,
    int minutes,
  ) {
    final fields = Map<String, dynamic>.from(r.fields)
      ..['durationMinutes'] = minutes
      ..['feedingType'] = 'breastfeeding';
    return AiNannyStructuredRecord(
      type: r.type,
      fields: fields,
      missingFields: const [],
    );
  }

  static int? parseSingleDuration(String text) {
    return AiNannyParseNormalize.parseDurationMinutes(text) ??
        AiNannyParseNormalize.parseDurationHoursAsMinutes(text) ??
        int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  }
}
