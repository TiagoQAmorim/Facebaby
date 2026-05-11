import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../models/vaccine_record.dart';
import '../services/app_database.dart';
import '../services/firebase/vaccine_cloud_sync.dart';
import '../services/local_notifications_service.dart';
import '../services/vaccine_reminder_scheduler.dart';
import 'face_baby_loading.dart';

String _fmtCalendarDay(DateTime? dt) {
  if (dt == null) return '—';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

/// Folha com todos os dados da vacina e confirmação de dose aplicada (remove o aviso do banner).
Future<bool?> showVaccineDueConfirmSheet(
  BuildContext context, {
  required VaccineRecord record,
  required int babyId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _VaccineDueConfirmPanel(
      record: record,
      babyId: babyId,
      fmtDate: _fmtCalendarDay,
    ),
  );
}

class _VaccineDueConfirmPanel extends StatefulWidget {
  const _VaccineDueConfirmPanel({
    required this.record,
    required this.babyId,
    required this.fmtDate,
  });

  final VaccineRecord record;
  final int babyId;
  final String Function(DateTime?) fmtDate;

  @override
  State<_VaccineDueConfirmPanel> createState() => _VaccineDueConfirmPanelState();
}

class _VaccineDueConfirmPanelState extends State<_VaccineDueConfirmPanel> {
  bool _confirmed = false;
  bool _saving = false;

  Future<void> _save() async {
    if (!_confirmed || _saving) return;
    final loc = S.of(context);
    final now = DateTime.now();
    final appliedDay = DateTime(now.year, now.month, now.day);

    setState(() => _saving = true);
    try {
      await AppDatabase.instance.updateVaccine(
        id: widget.record.id,
        babyId: widget.babyId,
        name: widget.record.name,
        dose: widget.record.dose,
        appliedAt: appliedDay,
        nextDueAt: null,
        notes: widget.record.notes,
      );
      VaccineCloudSync.pushLocalSoon(localBabyId: widget.babyId, localVaccineId: widget.record.id);
      await VaccineReminderScheduler.instance.rescheduleForBaby(widget.babyId);
      if (!mounted) return;
      await LocalNotificationsService.instance
          .cancelNotificationIds([VaccineReminderScheduler.notificationId(widget.record.id)]);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text(loc.vaccDueSavedOk)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.commonCouldNotSave} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final r = widget.record;
    final padBottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + padBottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                r.name.trim().isEmpty ? loc.vaccinesTitle : r.name.trim(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              if (r.dose != null && r.dose!.trim().isNotEmpty) ...[
                Text(loc.vaccDoseOpt, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(r.dose!, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 12),
              ],
              Text(loc.vaccNext, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(widget.fmtDate(r.nextDueAt), style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              Text(loc.vaccApplied, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(widget.fmtDate(r.appliedAt), style: Theme.of(context).textTheme.bodyLarge),
              if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(loc.vaccNotesOpt, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(r.notes!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 18),
              CheckboxListTile(
                value: _confirmed,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _confirmed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(loc.vaccDueConfirmCheckbox),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: !_confirmed || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: FaceBabySpinner(size: 18, strokeWidth: 2.5))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_saving ? loc.commonSaving : loc.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
