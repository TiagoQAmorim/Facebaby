import 'package:flutter/foundation.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/pending_record_session.dart';
import 'ai_nanny_structured_clarification.dart';

/// Gera texto claro sobre registros pendentes — nunca mensagem genérica vazia.
abstract final class PendingRecordsExplanation {
  /// Retorna `null` se não há pendência real (estado inválido / vazio).
  static String? buildPendingRecordsExplanation({
    required AiNannyRecordsBundle? bundle,
    required S strings,
    PendingRecordSession? pendingState,
    double? lastWeightKg,
    bool compactForChat = false,
  }) {
    final effectiveBundle = pendingState?.bundle ?? bundle;
    if (effectiveBundle == null || effectiveBundle.drafts.isEmpty) {
      _log(
        pendingState: pendingState,
        reason: 'empty_bundle',
        pending: const [],
        missing: const [],
      );
      return null;
    }

    final blocks = <String>[];
    for (var i = 0; i < effectiveBundle.drafts.length; i++) {
      final draft = effectiveBundle.drafts[i];
      final block = _blockForDraft(
        draft: draft,
        index: i,
        bundle: effectiveBundle,
        strings: strings,
        lastWeightKg: lastWeightKg,
      );
      if (block != null) blocks.add(block);
    }

    if (blocks.isEmpty) {
      _log(
        pendingState: pendingState,
        reason: 'no_pending_drafts',
        pending: effectiveBundle.drafts.map((d) => d.title).toList(),
        missing: effectiveBundle.drafts
            .expand((d) => d.structured.missingFields)
            .toList(),
      );
      return null;
    }

    final question = _objectiveQuestion(
      bundle: effectiveBundle,
      pendingState: pendingState,
      strings: strings,
      lastWeightKg: lastWeightKg,
    );
    if (compactForChat) {
      return question?.trim().isEmpty == true ? null : question!.trim();
    }

    final intro = blocks.length == 1
        ? strings.aiPendingRecordsIntroSingle
        : strings.aiPendingRecordsIntroPlural(blocks.length);

    final buf = StringBuffer()..writeln(intro);
    for (final b in blocks) {
      buf.writeln(b);
    }
    if (question != null && question.trim().isNotEmpty) {
      buf.writeln(question.trim());
    }

    final text = buf.toString().trim();
    _log(
      pendingState: pendingState,
      reason: 'generated',
      pending: blocks,
      missing: effectiveBundle.drafts
          .expand((d) => d.structured.missingFields)
          .toList(),
      generatedQuestion: question,
    );
    return text.isEmpty ? null : text;
  }

  /// Há rascunhos incompletos, confirmação pendente ou follow-ups ativos.
  static bool hasRealPending({
    AiNannyRecordsBundle? bundle,
    PendingRecordSession? session,
  }) {
    final b = session?.bundle ?? bundle;
    if (b == null || b.drafts.isEmpty) return false;
    if (b.followUpQuestions.isNotEmpty) return true;
    for (final d in b.drafts) {
      if (d.status == AiNannyRecordDraftStatus.incomplete) return true;
      if (d.status == AiNannyRecordDraftStatus.needsConfirm) return true;
      if (d.structured.missingFields.isNotEmpty) return true;
    }
    return false;
  }

  /// Evita “Pode me dizer de novo…” quando não há pergunta objetiva pendente.
  static String fallbackRetry(S strings) => '';

  static String? _blockForDraft({
    required AiNannyRecordDraft draft,
    required int index,
    required AiNannyRecordsBundle bundle,
    required S strings,
    double? lastWeightKg,
  }) {
    final rec = draft.structured;
    if (!_draftIsPending(draft)) return null;

    final title = AiNannyStructuredClarification.recordTitle(
      rec,
      strings,
      sourceText: bundle.userMessage,
    );
    final status = _statusLine(draft, strings, lastWeightKg: lastWeightKg);
    final missing = _missingLine(rec, strings);

    final buf = StringBuffer()..writeln('$title.');
    if (status != null && status.isNotEmpty) {
      buf.writeln(status);
    }
    if (missing != null && missing.isNotEmpty) {
      buf.writeln(missing);
    }
    return buf.toString().trim();
  }

  static bool _draftIsPending(AiNannyRecordDraft draft) {
    if (draft.status == AiNannyRecordDraftStatus.incomplete) return true;
    if (draft.status == AiNannyRecordDraftStatus.needsConfirm) return true;
    if (draft.structured.missingFields.isNotEmpty) return true;
    final rec = draft.structured;
    if ((rec.type == 'growth_weight' || rec.type == 'growth_height') &&
        rec.fields['mode'] == 'delta' &&
        rec.fields['value'] != null &&
        draft.growthPreview == null) {
      return true;
    }
    return false;
  }

  static String? _statusLine(
    AiNannyRecordDraft draft,
    S strings, {
    double? lastWeightKg,
  }) {
    final rec = draft.structured;
    if (rec.type == 'vaccine') {
      return _vaccineStatus(rec, strings);
    }
    if (rec.type == 'growth_weight' && rec.fields['mode'] == 'delta') {
      final grams = (rec.fields['value'] as num?)?.toInt() ?? 0;
      if (draft.growthPreview != null) {
        final g = draft.growthPreview!;
        return strings.aiPendingGrowthStatusDelta(grams);
      }
      if ((lastWeightKg ?? 0) <= 0) {
        return strings.aiPendingGrowthStatusDelta(grams);
      }
    }
    if (rec.type == 'growth_height' && rec.fields['mode'] == 'delta') {
      final delta = (rec.fields['value'] as num?)?.toInt() ?? 0;
      return strings.aiPendingGrowthStatusHeightDelta(delta);
    }
    final line = draft.displayLine.trim();
    if (line.isNotEmpty &&
        !line.contains(strings.aiRecordFieldMissing) &&
        line != strings.aiGrowthNeedBaselineWeight &&
        line != strings.aiGrowthNeedBaselineHeight) {
      return line.endsWith('.') ? line : '$line.';
    }
    return null;
  }

  static String? _vaccineStatus(AiNannyStructuredRecord rec, S strings) {
    final status = '${rec.fields['status'] ?? ''}'.toLowerCase();
    final when = _formatVaccineWhen(rec, strings);
    if (status == 'scheduled' && when.isNotEmpty) {
      return strings.aiPendingVaccineScheduledStatus(when);
    }
    if ('${rec.fields['vaccineName'] ?? ''}'.trim().isNotEmpty) {
      return strings.aiPendingVaccineNamedStatus(
        '${rec.fields['vaccineName']}'.trim(),
        when,
      );
    }
    if (status == 'taken' && when.isNotEmpty) {
      return strings.aiPendingVaccineNamedStatus(
        '${rec.fields['vaccineName'] ?? strings.aiRecordLabelVaccine}'.trim(),
        when,
      );
    }
    return when.isNotEmpty ? strings.aiPendingVaccineScheduledStatus(when) : null;
  }

  static String _formatVaccineWhen(AiNannyStructuredRecord rec, S strings) {
    final dateRaw = '${rec.fields['date'] ?? ''}'.trim().toLowerCase();
    final timeRaw = '${rec.fields['time'] ?? ''}'.trim();

    String? dateLabel;
    if (dateRaw == 'tomorrow' || dateRaw.contains('amanh')) {
      dateLabel = strings.aiRecordWhenTomorrow;
    } else if (dateRaw == 'today' || dateRaw.contains('hoje')) {
      dateLabel = strings.aiRecordFieldNow;
    } else if (dateRaw.isNotEmpty) {
      dateLabel = dateRaw;
    }

    String? timeLabel;
    if (timeRaw.isNotEmpty && timeRaw != 'now') {
      timeLabel = timeRaw;
    }

    if (dateLabel != null && timeLabel != null) {
      return '$dateLabel ${strings.aiRecordAtConnector} $timeLabel';
    }
    return dateLabel ?? timeLabel ?? '';
  }

  static String? _missingLine(AiNannyStructuredRecord rec, S strings) {
    if (rec.missingFields.isEmpty) {
      if (rec.type == 'growth_weight' &&
          rec.fields['mode'] == 'delta' &&
          rec.fields['value'] != null) {
        return strings.aiPendingGrowthMissingBaseline;
      }
      return null;
    }
    final labels = rec.missingFields
        .map((f) => _missingFieldLabel(rec.type, f, strings))
        .where((l) => l.isNotEmpty)
        .toList();
    if (labels.isEmpty) return null;
    return strings.aiPendingMissingFieldsLine(labels.join(', '));
  }

  static String _missingFieldLabel(String type, String field, S strings) {
    return switch (field) {
      'vaccineName' => strings.aiRecordFieldName,
      'date' => strings.aiRecordFieldDate,
      'time' => strings.aiRecordFieldTime,
      'value' => strings.aiRecordFieldValue,
      'breastSide' => strings.aiRecordFieldSide,
      'durationMinutes' => strings.aiRecordFieldDuration,
      'feedingType' => strings.aiRecordFieldMethod,
      'pee' || 'poop' => strings.aiRecordFieldType,
      'reasonOrSpecialty' => strings.aiRecordFieldReason,
      'symptoms' => strings.aiRecordFieldSymptoms,
      'temperatureCelsius' => strings.symptomReportTemp,
      'sleepStatus' => strings.aiRecordFieldAction,
      'startedAt' => strings.aiRecordFieldTime,
      'action' => strings.aiRecordFieldAction,
      _ => field,
    };
  }

  static String? _objectiveQuestion({
    required AiNannyRecordsBundle bundle,
    PendingRecordSession? pendingState,
    required S strings,
    double? lastWeightKg,
  }) {
    final q = pendingState?.currentQuestion ?? bundle.followUpQuestions.firstOrNull;
    if (q != null) {
      return q.question.trim();
    }

    for (final d in bundle.drafts) {
      if (!_draftIsPending(d)) continue;
      final rec = d.structured;

      if (rec.type == 'vaccine' && rec.missingFields.contains('vaccineName')) {
        final when = _formatVaccineWhen(rec, strings);
        if (when.isNotEmpty) {
          return strings.aiPendingVaccineAskNameWithWhen(when);
        }
        return strings.aiClarifyVaccineName;
      }

      if (rec.type == 'growth_weight' && rec.fields['mode'] == 'delta') {
        final grams = (rec.fields['value'] as num?)?.toInt() ?? 0;
        if (d.growthPreview != null) {
          final g = d.growthPreview!;
          return strings.aiPendingGrowthWeightDeltaConfirm(
            _fmtKg(g.previousValue),
            grams,
            _fmtKg(g.newValue),
          );
        }
        return strings.aiPendingGrowthNeedLastWeight(grams);
      }

      final follow = d.followUpQuestion ??
          AiNannyStructuredClarification.followUpQuestion(rec, strings);
      if (follow != null && follow.trim().isNotEmpty) {
        return follow.trim();
      }
    }
    return null;
  }

  static String _fmtKg(double kg) =>
      kg.toStringAsFixed(3).replaceAll('.', ',');

  static void _log({
    PendingRecordSession? pendingState,
    required String reason,
    required List<dynamic> pending,
    required List<String> missing,
    String? generatedQuestion,
  }) {
    debugPrint(
      'PendingRecordsExplanation: reason=$reason '
      'sessionId=${pendingState?.sessionId ?? 'none'} '
      'pending=$pending missingFields=$missing '
      'question=${generatedQuestion ?? '—'}',
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
