import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/voice_record_interpretation.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_date_picker.dart';
import '../../utils/measurement_format.dart';

/// Preview de registro de saúde (febre, consulta, vacina) com campos editáveis.
class VoiceRecordHealthPreview extends StatefulWidget {
  const VoiceRecordHealthPreview({
    super.key,
    required this.transcript,
    required this.interpretation,
    required this.onConfirm,
    required this.onCancel,
    this.onAskAi,
    this.busy = false,
  });

  final String transcript;
  final VoiceRecordInterpretation interpretation;
  final void Function(VoiceRecordInterpretation merged) onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onAskAi;
  final bool busy;

  @override
  State<VoiceRecordHealthPreview> createState() =>
      _VoiceRecordHealthPreviewState();
}

class _VoiceRecordHealthPreviewState extends State<VoiceRecordHealthPreview> {
  late final TextEditingController _tempCtrl;
  late final TextEditingController _consultTitleCtrl;
  late final TextEditingController _consultPhoneCtrl;
  late final TextEditingController _consultAddressCtrl;
  late final TextEditingController _consultNotesCtrl;
  late final TextEditingController _vaccineNameCtrl;
  late final TextEditingController _vaccineDoseCtrl;
  late final TextEditingController _vaccineNotesCtrl;
  late DateTime _consultWhen;
  DateTime? _vaccineApplied;
  DateTime? _vaccineNextDue;

  @override
  void initState() {
    super.initState();
    final i = widget.interpretation;
    final s = i.symptom;
    _tempCtrl = TextEditingController(
      text: s?.tempCelsius != null
          ? s!.tempCelsius!.toStringAsFixed(1).replaceAll('.', ',')
          : '',
    );
    final c = i.consultation;
    _consultTitleCtrl = TextEditingController(text: c?.title ?? '');
    _consultPhoneCtrl = TextEditingController(text: c?.phone ?? '');
    _consultAddressCtrl = TextEditingController(text: c?.address ?? '');
    _consultNotesCtrl = TextEditingController(text: c?.notes ?? '');
    _consultWhen = c?.occurredAt ?? DateTime.now().add(const Duration(days: 1));
    final v = i.vaccine;
    _vaccineNameCtrl = TextEditingController(text: v?.name ?? '');
    _vaccineDoseCtrl = TextEditingController(text: v?.dose ?? '');
    _vaccineNotesCtrl = TextEditingController(text: v?.notes ?? '');
    _vaccineApplied = v?.appliedAt;
    _vaccineNextDue = v?.nextDueAt;
  }

  @override
  void dispose() {
    _tempCtrl.dispose();
    _consultTitleCtrl.dispose();
    _consultPhoneCtrl.dispose();
    _consultAddressCtrl.dispose();
    _consultNotesCtrl.dispose();
    _vaccineNameCtrl.dispose();
    _vaccineDoseCtrl.dispose();
    _vaccineNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickConsultWhen(S s) async {
    final now = DateTime.now();
    final d = await showAppDatePicker(
      context: context,
      initialDate: _consultWhen,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_consultWhen),
    );
    if (t == null || !mounted) return;
    setState(() {
      _consultWhen = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final understood = s.aiVoiceUnderstood(widget.transcript);

    return Material(
      color: Colors.white.withAlpha(245),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              understood,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D2A4F),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              s.aiVoiceHealthFieldsHint,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.black.withAlpha(170),
              ),
            ),
            const SizedBox(height: 12),
            ..._fieldsForType(s),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.busy ? null : widget.onCancel,
                    child: Text(s.cancel),
                  ),
                ),
                if (widget.onAskAi != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.busy ? null : widget.onAskAi,
                      child: Text(
                        s.aiVoiceAskAiInstead,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.busy ? null : _onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.ctaPrimary,
                    ),
                    child: widget.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(s.aiVoiceConfirm),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fieldsForType(S s) {
    switch (widget.interpretation.type) {
      case 'symptom':
        return [
          TextField(
            controller: _tempCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: s.aiVoiceHealthTempLabel,
              border: const OutlineInputBorder(),
            ),
          ),
        ];
      case 'consultation':
        return [
          TextField(
            controller: _consultTitleCtrl,
            decoration: InputDecoration(
              labelText: s.consultationTitleLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.consultationWhenLabel),
            subtitle: Text(_formatWhen(_consultWhen)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: widget.busy ? null : () => _pickConsultWhen(s),
          ),
          TextField(
            controller: _consultPhoneCtrl,
            decoration: InputDecoration(
              labelText: s.consultationPhoneLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _consultAddressCtrl,
            decoration: InputDecoration(
              labelText: s.consultationAddressLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _consultNotesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: s.consultationNotesHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ];
      case 'vaccine':
        return [
          TextField(
            controller: _vaccineNameCtrl,
            decoration: InputDecoration(
              labelText: s.aiVoiceHealthVaccineNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _vaccineDoseCtrl,
            decoration: InputDecoration(
              labelText: s.aiVoiceHealthVaccineDoseLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _vaccineNotesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: s.consultationNotesHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ];
      default:
        return const [];
    }
  }

  String _formatWhen(DateTime dt) {
    final d =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }

  void _onConfirm() {
    final base = widget.interpretation;
    VoiceRecordInterpretation merged = base;

    switch (base.type) {
      case 'symptom':
        final temp = MeasurementFormat.parseTempToC(_tempCtrl.text);
        if (base.symptom?.fever == true &&
            (temp == null || temp <= 0)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).symptomReportValidationFeverTemp)),
          );
          return;
        }
        merged = base.copyWith(
          symptom: VoiceSymptomPayload(
            fever: base.symptom?.fever ?? true,
            tempCelsius: temp ?? base.symptom?.tempCelsius,
            occurredAt: base.symptom?.occurredAt ?? DateTime.now(),
            otherNote: base.symptom?.otherNote,
            crying: base.symptom?.crying ?? false,
            pain: base.symptom?.pain ?? false,
            colic: base.symptom?.colic ?? false,
            reflux: base.symptom?.reflux ?? false,
          ),
        );
        break;
      case 'consultation':
        if (_consultTitleCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).consultationTitleEmpty)),
          );
          return;
        }
        merged = base.copyWith(
          consultation: VoiceConsultationPayload(
            title: _consultTitleCtrl.text.trim(),
            occurredAt: _consultWhen,
            phone: _consultPhoneCtrl.text.trim().isEmpty
                ? null
                : _consultPhoneCtrl.text.trim(),
            address: _consultAddressCtrl.text.trim().isEmpty
                ? null
                : _consultAddressCtrl.text.trim(),
            notes: _consultNotesCtrl.text.trim().isEmpty
                ? null
                : _consultNotesCtrl.text.trim(),
          ),
        );
        break;
      case 'vaccine':
        if (_vaccineNameCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).aiVoiceHealthVaccineNameRequired)),
          );
          return;
        }
        merged = base.copyWith(
          vaccine: VoiceVaccinePayload(
            name: _vaccineNameCtrl.text.trim(),
            dose: _vaccineDoseCtrl.text.trim().isEmpty
                ? null
                : _vaccineDoseCtrl.text.trim(),
            appliedAt: _vaccineApplied,
            nextDueAt: _vaccineNextDue,
            notes: _vaccineNotesCtrl.text.trim().isEmpty
                ? null
                : _vaccineNotesCtrl.text.trim(),
          ),
        );
        break;
    }

    widget.onConfirm(merged);
  }
}
