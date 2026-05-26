import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../services/ai/ai_nanny_record_confirm_flow.dart';

/// Card de confirmação antes de salvar registros estruturados.
Future<AiNannyConfirmMode?> showAiNannyRecordsConfirmSheet({
  required BuildContext context,
  required AiNannyRecordsBundle bundle,
}) {
  return showModalBottomSheet<AiNannyConfirmMode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AiNannyRecordsConfirmSheet(bundle: bundle),
  );
}

class _AiNannyRecordsConfirmSheet extends StatelessWidget {
  const _AiNannyRecordsConfirmSheet({required this.bundle});

  final AiNannyRecordsBundle bundle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
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
                  s.aiNannyRecordsFoundTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4A148C),
                  ),
                ),
              ),
              if (bundle.drafts.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '🤖 ${bundle.drafts.length} registros',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withAlpha(140),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: bundle.drafts.length,
                  itemBuilder: (context, index) {
                    final d = bundle.drafts[index];
                    return _RecordTile(draft: d);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (bundle.completeCount > 0 ||
                        bundle.confirmCount > 0)
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          bundle.confirmCount > 0
                              ? AiNannyConfirmMode.allPossible
                              : AiNannyConfirmMode.completeOnly,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7B1FA2),
                        ),
                        child: Text(s.aiNannyConfirmCompleteRecords),
                      ),
                    if (bundle.incompleteCount > 0) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(context, null),
                        child: Text(s.aiNannyCompleteMissingData),
                      ),
                    ],
                    if (bundle.confirmCount > 0 && bundle.completeCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () => Navigator.pop(
                            context,
                            AiNannyConfirmMode.allPossible,
                          ),
                          child: Text(s.aiNannySaveAllPossible),
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

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.draft});

  final AiNannyRecordDraft draft;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (draft.status) {
      AiNannyRecordDraftStatus.complete => ('✓', const Color(0xFF2E7D32)),
      AiNannyRecordDraftStatus.needsConfirm => ('?', const Color(0xFFF57C00)),
      AiNannyRecordDraftStatus.incomplete => ('…', const Color(0xFFC62828)),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: const Color(0xFFF3E5F5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                draft.displayLine,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Color(0xFF3D2A4F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
