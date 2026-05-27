import 'dart:async';

import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../models/ai/detected_baby_record.dart';
import '../../services/ai/ai_nanny_record_confirm_flow.dart';
import '../../services/ai/ai_nanny_structured_clarification.dart';
import '../../services/ai/ai_nanny_structured_mapper.dart';
import '../../services/ai/detected_record_builder.dart';
import '../../services/ai/pending_record_session_store.dart';

class AiNannyConfirmSheetResult {
  const AiNannyConfirmSheetResult({
    required this.mode,
    required this.bundle,
  });

  final AiNannyConfirmMode mode;
  final AiNannyRecordsBundle bundle;
}

typedef AiNannySpeakTextCallback = void Function(String text);

/// Card de confirmação com follow-up interativo antes de salvar.
Future<AiNannyConfirmSheetResult?> showAiNannyRecordsConfirmSheet({
  required BuildContext context,
  required AiNannyRecordsBundle bundle,
  AiNannySpeakTextCallback? onSpeakText,
  String? readyToSaveVoiceText,
}) {
  return showModalBottomSheet<AiNannyConfirmSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: true,
    builder: (ctx) => _AiNannyRecordsConfirmSheet(
      initial: bundle,
      onSpeakText: onSpeakText,
      readyToSaveVoiceText: readyToSaveVoiceText,
    ),
  );
}

class _AiNannyRecordsConfirmSheet extends StatefulWidget {
  const _AiNannyRecordsConfirmSheet({
    required this.initial,
    this.onSpeakText,
    this.readyToSaveVoiceText,
  });

  final AiNannyRecordsBundle initial;
  final AiNannySpeakTextCallback? onSpeakText;
  final String? readyToSaveVoiceText;

  @override
  State<_AiNannyRecordsConfirmSheet> createState() =>
      _AiNannyRecordsConfirmSheetState();
}

class _AiNannyRecordsConfirmSheetState extends State<_AiNannyRecordsConfirmSheet> {
  late List<AiNannyRecordDraft> _drafts;
  late List<AiFollowUpQuestion> _followUps;
  int _followUpIndex = 0;
  final _textAnswer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _drafts = List<AiNannyRecordDraft>.from(widget.initial.drafts);
    _rebuildFollowUps();
  }

  @override
  void dispose() {
    _textAnswer.dispose();
    super.dispose();
  }

  void _rebuildFollowUps() {
    final s = S.of(context);
    _followUps = DetectedRecordBuilder.followUpsForBundle(_drafts, s);
    if (_followUpIndex >= _followUps.length) {
      _followUpIndex = _followUps.isEmpty ? 0 : _followUps.length - 1;
    }
  }

  bool get _canSaveAll => _currentBundle.allRequiredFilled;

  bool get _hasMissing => !_canSaveAll;

  void _applyAnswer(String value) {
    if (_followUpIndex >= _followUps.length) return;
    final q = _followUps[_followUpIndex];
    final s = S.of(context);
    final old = _drafts[q.recordIndex];
    final updated = DetectedRecordBuilder.applyAnswer(
      rec: old.structured,
      field: q.field,
      value: value,
      sourceText: widget.initial.userMessage,
    );
    _drafts[q.recordIndex] = AiNannyStructuredMapper.draftFromRecord(
      updated,
      strings: s,
      sourceText: widget.initial.userMessage,
    );
    setState(() {
      _followUpIndex = 0;
      _rebuildFollowUps();
      _textAnswer.clear();
    });
    unawaited(
      PendingRecordSessionStore.instance.updateBundle(_currentBundle),
    );
    _scheduleFollowUpVoice();
  }

  void _scheduleFollowUpVoice() {
    final speak = widget.onSpeakText;
    if (speak == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_canSaveAll) {
        final ready = widget.readyToSaveVoiceText?.trim();
        if (ready != null && ready.isNotEmpty) speak(ready);
        return;
      }
      if (_followUps.isNotEmpty && _followUpIndex < _followUps.length) {
        final q = _followUps[_followUpIndex].question.trim();
        if (q.isNotEmpty) speak(q);
      }
    });
  }

  AiNannyRecordsBundle get _currentBundle => AiNannyRecordsBundle(
        drafts: _drafts,
        userMessage: widget.initial.userMessage,
        followUpQuestions: _followUps,
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  _hasMissing
                      ? s.aiConfirmNeedInfoTitle
                      : s.aiNannyRecordsFoundTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4A148C),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: [
                    for (final d in _drafts)
                      _RecordCard(
                        draft: d,
                        s: s,
                        sourceText: _currentBundle.userMessage,
                      ),
                    if (_followUps.isNotEmpty && _followUpIndex < _followUps.length)
                      _FollowUpPanel(
                        question: _followUps[_followUpIndex],
                        textController: _textAnswer,
                        onChoice: _applyAnswer,
                        onNumberSubmit: _applyAnswer,
                        s: s,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_canSaveAll)
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          AiNannyConfirmSheetResult(
                            mode: _drafts.any(
                              (d) =>
                                  d.status ==
                                  AiNannyRecordDraftStatus.needsConfirm,
                            )
                                ? AiNannyConfirmMode.allPossible
                                : AiNannyConfirmMode.completeOnly,
                            bundle: _currentBundle,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7B1FA2),
                        ),
                        child: Text(s.aiConfirmAndSaveRecords),
                      ),
                    if (_hasMissing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          s.aiConfirmCompleteToSaveHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withAlpha(170),
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text(
                        s.aiNannyCancelRecords,
                        style: const TextStyle(color: Color(0xFFC62828)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.draft,
    required this.s,
    this.sourceText,
  });

  final AiNannyRecordDraft draft;
  final S s;
  final String? sourceText;

  @override
  Widget build(BuildContext context) {
    final complete = draft.missingLines.isEmpty &&
        (draft.status == AiNannyRecordDraftStatus.complete ||
            draft.status == AiNannyRecordDraftStatus.needsConfirm);
    final badge = complete ? s.aiBadgeComplete : s.aiBadgeIncomplete;
    final badgeColor =
        complete ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    final title = draft.title.trim().isNotEmpty
        ? draft.title.trim()
        : AiNannyStructuredClarification.recordTitle(
            draft.structured,
            s,
            sourceText: sourceText,
          );

    final understood = draft.understoodLines.isNotEmpty
        ? draft.understoodLines
        : draft.detailLines
            .where((l) => !l.contains(s.aiRecordFieldMissing))
            .toList();

    final missing = draft.missingLines.isNotEmpty
        ? draft.missingLines
        : draft.detailLines
            .where((l) => l.contains(s.aiRecordFieldMissing))
            .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF3E5F5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            if (understood.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                s.aiCardUnderstood,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5E35B1),
                ),
              ),
              ...understood.map(
                (l) => Text(
                  l,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF3D2A4F),
                  ),
                ),
              ),
            ],
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                s.aiCardMissing,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC62828),
                ),
              ),
              ...missing.map(
                (l) => Text(
                  l,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFFB71C1C),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FollowUpPanel extends StatelessWidget {
  const _FollowUpPanel({
    required this.question,
    required this.textController,
    required this.onChoice,
    required this.onNumberSubmit,
    required this.s,
  });

  final AiFollowUpQuestion question;
  final TextEditingController textController;
  final ValueChanged<String> onChoice;
  final ValueChanged<String> onNumberSubmit;
  final S s;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB71C1C),
            ),
          ),
          const SizedBox(height: 10),
          if (question.inputType == AiFollowUpInputType.choice)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: question.options
                  .map(
                    (opt) => ActionChip(
                      label: Text(opt),
                      onPressed: () => onChoice(opt),
                    ),
                  )
                  .toList(),
            )
          else ...[
            TextField(
              controller: textController,
              keyboardType: question.inputType == AiFollowUpInputType.number
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                hintText: question.inputType == AiFollowUpInputType.number
                    ? s.aiFollowUpDurationQuestion
                    : s.aiRecordFieldTime,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                final v = textController.text.trim();
                if (v.isNotEmpty) onNumberSubmit(v);
              },
              child: Text(s.aiVoiceConfirm),
            ),
          ],
        ],
      ),
    );
  }
}
