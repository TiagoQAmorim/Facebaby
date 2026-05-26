import 'package:flutter/material.dart';

import '../utils/app_date_picker.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/consultation_record.dart';
import '../services/app_database.dart';
import '../services/consultation_reminder_scheduler.dart';
import '../services/firebase/consultation_cloud_sync.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/card_box.dart';
import '../widgets/consultation_detail_sheet.dart';
import '../widgets/loading_scope.dart';
import '../utils/input_formatters.dart';

class ConsultationsPage extends StatefulWidget {
  /// Abre o detalhe desta consulta após carregar (ex.: notificação).
  final int? openConsultationId;

  const ConsultationsPage({super.key, this.openConsultationId});

  @override
  State<ConsultationsPage> createState() => _ConsultationsPageState();
}

class _ConsultationEditorSheet extends StatefulWidget {
  final int babyId;
  final ConsultationRecord? edit;
  final BuildContext pageContext;
  final S loc;
  final Future<T> Function<T>(Future<T> Function() action, {String? label}) runLoading;

  const _ConsultationEditorSheet({
    required this.babyId,
    required this.edit,
    required this.pageContext,
    required this.loc,
    required this.runLoading,
  });

  @override
  State<_ConsultationEditorSheet> createState() => _ConsultationEditorSheetState();
}

class _ConsultationEditorSheetState extends State<_ConsultationEditorSheet> {
  late final TextEditingController _titleCtrl = TextEditingController(text: widget.edit?.title ?? '');
  late final TextEditingController _notesCtrl = TextEditingController(text: widget.edit?.notes ?? '');
  late final TextEditingController _phoneCtrl = TextEditingController(text: widget.edit?.phone ?? '');
  late final TextEditingController _addressCtrl = TextEditingController(text: widget.edit?.address ?? '');

  late DateTime _occurredAt = widget.edit?.occurredAt ?? DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: loc.consultationTitleLabel,
                prefixIcon: const Icon(Icons.medical_services_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                PhoneBrFormatter(),
              ],
              decoration: InputDecoration(
                labelText: loc.consultationPhoneLabel,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: loc.consultationAddressLabel,
                prefixIcon: const Icon(Icons.place_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: loc.consultationNotesHint,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate: _occurredAt,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                      );
                      if (picked == null || !mounted) return;
                      setState(() {
                        _occurredAt = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          _occurredAt.hour,
                          _occurredAt.minute,
                        );
                      });
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      '${_occurredAt.day.toString().padLeft(2, '0')}/'
                      '${_occurredAt.month.toString().padLeft(2, '0')}/'
                      '${_occurredAt.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_occurredAt),
                      );
                      if (picked == null || !mounted) return;
                      setState(() {
                        _occurredAt = DateTime(
                          _occurredAt.year,
                          _occurredAt.month,
                          _occurredAt.day,
                          picked.hour,
                          picked.minute,
                        );
                      });
                    },
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(
                      '${_occurredAt.hour.toString().padLeft(2, '0')}:'
                      '${_occurredAt.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final title = _titleCtrl.text.trim();
                        if (title.isEmpty) {
                          if (widget.pageContext.mounted) {
                            ScaffoldMessenger.of(widget.pageContext).showSnackBar(
                              SnackBar(content: Text(loc.consultationTitleEmpty)),
                            );
                          }
                          return;
                        }

                        setState(() => _saving = true);
                        try {
                          await widget.runLoading(() async {
                            if (widget.edit == null) {
                              final newId = await AppDatabase.instance.insertConsultation(
                                babyId: widget.babyId,
                                title: title,
                                occurredAt: _occurredAt,
                                notes: _notesCtrl.text,
                                phone: _phoneCtrl.text,
                                address: _addressCtrl.text,
                              );
                              ConsultationCloudSync.pushLocalSoon(
                                localBabyId: widget.babyId,
                                localConsultationId: newId,
                              );
                            } else {
                              await AppDatabase.instance.updateConsultation(
                                id: widget.edit!.id,
                                babyId: widget.babyId,
                                title: title,
                                occurredAt: _occurredAt,
                                notes: _notesCtrl.text,
                                phone: _phoneCtrl.text,
                                address: _addressCtrl.text,
                              );
                              ConsultationCloudSync.pushLocalSoon(
                                localBabyId: widget.babyId,
                                localConsultationId: widget.edit!.id,
                              );
                            }
                          }, label: loc.commonSaving);

                          await ConsultationReminderScheduler.instance.rescheduleForBaby(widget.babyId);
                          if (mounted) Navigator.of(context).pop(true);
                        } catch (e) {
                          if (widget.pageContext.mounted) {
                            ScaffoldMessenger.of(widget.pageContext).showSnackBar(
                              SnackBar(content: Text('${loc.commonCouldNotSave} $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? loc.commonSaving : loc.commonSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsultationsPageState extends State<ConsultationsPage> {
  List<ConsultationRecord> _items = [];
  bool _loading = true;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  bool _handledOpenPayload = false;

  int? get _babyId => CurrentBabyController.instance.currentBabyId;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _focusedDay = DateTime(n.year, n.month, n.day);
    _selectedDay = _focusedDay;
    CurrentBabyController.instance.addListener(_onBabyChanged);
    _load();
  }

  @override
  void dispose() {
    CurrentBabyController.instance.removeListener(_onBabyChanged);
    super.dispose();
  }

  void _onBabyChanged() {
    _handledOpenPayload = false;
    _load();
  }

  Map<DateTime, List<ConsultationRecord>> _groupByDay(List<ConsultationRecord> items) {
    final m = <DateTime, List<ConsultationRecord>>{};
    for (final c in items) {
      final d = DateTime(c.occurredAt.year, c.occurredAt.month, c.occurredAt.day);
      (m[d] ??= []).add(c);
    }
    for (final list in m.values) {
      list.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    }
    return m;
  }

  List<ConsultationRecord> _eventsForDay(DateTime day) {
    final k = DateTime(day.year, day.month, day.day);
    return _groupByDay(_items)[k] ?? [];
  }

  Future<T> _runLoading<T>(Future<T> Function() action, {String? label}) async {
    final loading = LoadingScope.maybeOf(context);
    if (loading == null) return await action();
    return await loading.run(action, label: label);
  }

  Future<void> _load() async {
    final babyId = _babyId;
    if (babyId == null) {
      if (mounted) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await AppDatabase.instance.listConsultations(babyId: babyId);
      if (!mounted) return;
      setState(() {
        _items = rows.map(ConsultationRecord.fromRow).toList();
        _loading = false;
      });
      _maybeOpenFromPayload();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  void _maybeOpenFromPayload() {
    final oid = widget.openConsultationId;
    if (oid == null || _handledOpenPayload || !mounted) return;
    ConsultationRecord? found;
    for (final x in _items) {
      if (x.id == oid) {
        found = x;
        break;
      }
    }
    if (found == null) return;
    _handledOpenPayload = true;
    final f = found;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final day = DateTime(f.occurredAt.year, f.occurredAt.month, f.occurredAt.day);
      setState(() {
        _selectedDay = day;
        _focusedDay = day;
      });
      showConsultationDetailSheet(context, f);
    });
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} · '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _openSheet({ConsultationRecord? edit}) async {
    final pageContext = context;
    final babyId = _babyId;
    if (babyId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text(S.of(pageContext).dailyJournalNoBaby)));
      return;
    }

    final loc = S.of(pageContext);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ConsultationEditorSheet(
        babyId: babyId,
        edit: edit,
        pageContext: pageContext,
        loc: loc,
        runLoading: _runLoading,
      ),
    );

    if (saved == true && mounted) await _load();
  }

  Future<void> _confirmDelete(ConsultationRecord r) async {
    final babyId = _babyId;
    if (babyId == null || r.id <= 0) return;
    final loc = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.delete),
        content: Text(loc.confirmDelete),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final cloudId = await AppDatabase.instance.getRowCloudId(table: 'consultations', id: r.id, babyId: babyId);
      await _runLoading(
        () => AppDatabase.instance.deleteConsultation(id: r.id, babyId: babyId),
        label: loc.commonSaving,
      );
      if (cloudId != null) {
        try {
          await FirestoreService.instance.deleteEvent(cloudId);
        } catch (_) {}
      }
      await ConsultationReminderScheduler.instance.rescheduleForBaby(babyId);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.deleteFail} $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final selectedList = _eventsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(title: Text(s.consultationsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        icon: const Icon(Icons.add),
        label: Text(s.add),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.consultationsIntro,
                          style: TextStyle(color: Colors.black.withAlpha(140), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                        CardBox(
                          child: TableCalendar<ConsultationRecord>(
                            firstDay: DateTime(2020, 1, 1),
                            lastDay: DateTime(2035, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            eventLoader: (day) => _eventsForDay(day),
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            calendarFormat: CalendarFormat.month,
                            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                            onDaySelected: (selected, focused) {
                              setState(() {
                                _selectedDay = selected;
                                _focusedDay = focused;
                              });
                            },
                            onPageChanged: (focused) {
                              setState(() => _focusedDay = focused);
                            },
                            calendarStyle: CalendarStyle(
                              outsideDaysVisible: false,
                              markersMaxCount: 3,
                              markerDecoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(230),
                                shape: BoxShape.circle,
                              ),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${_selectedDay.day.toString().padLeft(2, '0')}/${_selectedDay.month.toString().padLeft(2, '0')}/${_selectedDay.year}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (selectedList.isEmpty)
                          CardBox(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                _items.isEmpty ? s.consultationsEmpty : s.consultationsDayEmpty,
                                style: TextStyle(color: Colors.black.withAlpha(160)),
                              ),
                            ),
                          )
                        else
                          ...selectedList.map((r) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: CardBox(
                                child: InkWell(
                                  onTap: () => showConsultationDetailSheet(context, r),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                r.title,
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _fmtDateTime(r.occurredAt),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.secondary.withAlpha(230),
                                                ),
                                              ),
                                              if (r.phone != null && r.phone!.trim().isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  r.phone!,
                                                  style: TextStyle(fontSize: 13, color: Colors.black.withAlpha(170)),
                                                ),
                                              ],
                                              if (r.address != null && r.address!.trim().isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  r.address!,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 13, color: Colors.black.withAlpha(150)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: s.edit,
                                          icon: const Icon(Icons.edit_outlined, size: 22),
                                          onPressed: () => _openSheet(edit: r),
                                        ),
                                        IconButton(
                                          tooltip: s.delete,
                                          icon: Icon(Icons.delete_outline, size: 22, color: Colors.red.shade400),
                                          onPressed: () => _confirmDelete(r),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
