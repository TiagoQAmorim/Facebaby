import 'package:flutter/material.dart';

import '../models/vaccine_record.dart';
import '../services/app_database.dart';
import '../i18n/app_i18n.dart';
import '../widgets/card_box.dart';
import '../widgets/loading_scope.dart';
import '../widgets/face_baby_loading.dart';
import '../widgets/section_title.dart';
import '../services/firebase/vaccine_cloud_sync.dart';
import '../services/vaccine_reminder_scheduler.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/portal_night_ui.dart';
import '../utils/portal_time_of_day.dart';
import '../widgets/vaccine_due_confirm_sheet.dart';

class VaccinesPage extends StatefulWidget {
  const VaccinesPage({super.key, this.openVaccineId});

  /// Abre o fluxo de confirmação desta vacina (ex.: notificação).
  final int? openVaccineId;

  @override
  State<VaccinesPage> createState() => _VaccinesPageState();
}

class _VaccinesPageState extends State<VaccinesPage> {
  int? _selectedBabyId;
  Future<List<Map<String, Object?>>>? _babiesFuture;
  Future<List<Map<String, Object?>>>? _vaccinesFuture;
  bool _handledOpenPayload = false;

  @override
  void initState() {
    super.initState();
    _babiesFuture = AppDatabase.instance.listBabies().then((babies) async {
      if (!mounted) return babies;
      if (widget.openVaccineId != null) {
        final row = await AppDatabase.instance.getVaccineRowById(widget.openVaccineId!);
        if (row != null && mounted) {
          _selectedBabyId = (row['baby_id'] as num).toInt();
          _reloadVaccines();
        }
      } else if (_selectedBabyId == null && babies.isNotEmpty) {
        _selectedBabyId = (babies.first['id'] as num).toInt();
        _reloadVaccines();
      }
      if (mounted) setState(() {});
      return babies;
    });
  }

  Future<void> _maybeOpenFromNotification(List<VaccineRecord> records) async {
    final oid = widget.openVaccineId;
    if (oid == null || _handledOpenPayload || !mounted) return;
    VaccineRecord? found;
    for (final x in records) {
      if (x.id == oid) {
        found = x;
        break;
      }
    }
    if (found == null) return;
    final rec = found;
    _handledOpenPayload = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final babyId = _selectedBabyId;
      if (babyId == null) return;
      final saved = await showVaccineDueConfirmSheet(context, record: rec, babyId: babyId);
      if (!mounted) return;
      if (saved == true && widget.openVaccineId != null) {
        Navigator.of(context).maybePop();
      }
    });
  }

  void _reloadVaccines() {
    final babyId = _selectedBabyId;
    if (babyId == null) {
      _vaccinesFuture = null;
      return;
    }
    _vaccinesFuture = AppDatabase.instance.listVaccines(babyId: babyId);
  }

  Future<void> _selectBaby(int? id) async {
    setState(() {
      _selectedBabyId = id;
      _reloadVaccines();
    });
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<T> _runLoading<T>(Future<T> Function() action, {String? label}) async {
    final loading = LoadingScope.maybeOf(context);
    if (loading == null) return await action();
    return await loading.run(action, label: label);
  }

  static final List<VaccineRecord> _exampleRecords = [
    VaccineRecord(
      id: -1,
      babyId: -1,
      name: 'BCG',
      dose: 'Dose única',
      appliedAt: DateTime(2026, 1, 6),
      nextDueAt: null,
      notes: 'Maternidade',
      createdAt: DateTime(2026, 1, 6),
    ),
    VaccineRecord(
      id: -2,
      babyId: -1,
      name: 'Hepatite B',
      dose: 'Ao nascer',
      appliedAt: DateTime(2026, 1, 6),
      nextDueAt: DateTime(2026, 3, 6),
      notes: 'OK',
      createdAt: DateTime(2026, 1, 6),
    ),
    VaccineRecord(
      id: -3,
      babyId: -1,
      name: 'Pentavalente',
      dose: '1ª dose (2 meses)',
      appliedAt: DateTime(2026, 3, 10),
      nextDueAt: DateTime(2026, 5, 10),
      notes: 'Postinho',
      createdAt: DateTime(2026, 3, 10),
    ),
  ];

  Future<void> _addVaccine() async {
    await _openVaccineSheet();
  }

  Future<void> _openVaccineSheet({VaccineRecord? edit}) async {
    final babyId = _selectedBabyId;
    if (babyId == null) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (modalContext) {
        return _VaccineEditorSheet(
          babyId: babyId,
          edit: edit,
          fmtDate: _fmtDate,
          runLoading: _runLoading,
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {
        _reloadVaccines();
      });
      if (edit != null) {
        final loc = S.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.vaccUpdatedOk)));
      }
    }
  }

  Future<void> _confirmDeleteVaccine(VaccineRecord r) async {
    final babyId = _selectedBabyId;
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
      final cloudId = await AppDatabase.instance.getRowCloudId(table: 'vaccines', id: r.id, babyId: babyId);
      final n = await _runLoading(
        () => AppDatabase.instance.deleteVaccine(id: r.id, babyId: babyId),
        label: loc.commonSaving,
      );
      if (!mounted) return;
      if (n > 0) {
        setState(_reloadVaccines);
        if (cloudId != null) {
          try {
            await FirestoreService.instance.deleteEvent(cloudId);
          } catch (_) {}
        }
        await VaccineReminderScheduler.instance.rescheduleForBaby(babyId);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.deletedOk)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.commonCouldNotSave} $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PortalNightUi.listen((context, night) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PortalNightUi.appBar(s.vaccinesTitle, night: night),
        body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.vaccinesCard,
                      style: PortalNightUi.titleStyle(night, fontSize: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.vaccinesSubtitle,
                      style: PortalNightUi.bodyStyle(night, fontSize: 14).copyWith(
                        height: 1.35,
                        color: night
                            ? PortalTimeOfDay.nightOutlinedTextColor
                                .withAlpha(220)
                            : Colors.black.withAlpha(140),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CardBox(
                      child: Theme(
                        data: PortalNightUi.cardFormTheme(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionTitle(title: s.baby),
                            const SizedBox(height: 10),
                            FutureBuilder<List<Map<String, Object?>>>(
                              future: _babiesFuture,
                              builder: (context, snapshot) {
                                final babies = snapshot.data ?? const [];
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 10),
                                    child: Center(
                                        child: FaceBabySpinner(size: 30)),
                                  );
                                }
                                if (babies.isEmpty) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.vaccNoBabies),
                                      const SizedBox(height: 12),
                                      Text(s.exampleCard,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 10),
                                      _VaccinesTable(
                                          records: _exampleRecords),
                                    ],
                                  );
                                }

                                return _BabySelectorField(
                                  babies: babies,
                                  selectedId: _selectedBabyId,
                                  label: s.selectBaby,
                                  onChanged: _selectBaby,
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _selectedBabyId == null
                                    ? null
                                    : _addVaccine,
                                icon: const Icon(Icons.add),
                                label: Text(s.addVaccine),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  SectionTitle(
                    title: s.recordsTitle,
                    titleColor: night ? PortalTimeOfDay.nightTextColor : null,
                    titleShadows: night
                        ? PortalTimeOfDay.nightTextOutlineShadows
                        : null,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, Object?>>>(
                    future: _vaccinesFuture,
                    builder: (context, snapshot) {
                      if (_selectedBabyId == null) {
                        return const SizedBox.shrink();
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: FaceBabySpinner(size: 30)),
                        );
                      }
                      final rows = snapshot.data ?? const [];
                      if (rows.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CardBox(
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text('${s.noVaccinesYet} ${s.exampleCard}')),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _VaccinesTable(records: _exampleRecords),
                          ],
                        );
                      }

                      final records = rows.map(VaccineRecord.fromRow).toList();
                      _maybeOpenFromNotification(records);
                      return _VaccinesTable(
                        records: records,
                        onEdit: (rec) => _openVaccineSheet(edit: rec),
                        onDelete: _confirmDeleteVaccine,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
    });
  }
}

class _VaccineEditorSheet extends StatefulWidget {
  const _VaccineEditorSheet({
    required this.babyId,
    required this.edit,
    required this.fmtDate,
    required this.runLoading,
  });

  final int babyId;
  final VaccineRecord? edit;
  final String Function(DateTime?) fmtDate;
  final Future<T> Function<T>(Future<T> Function() action, {String? label}) runLoading;

  @override
  State<_VaccineEditorSheet> createState() => _VaccineEditorSheetState();
}

class _VaccineEditorSheetState extends State<_VaccineEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _doseCtrl;
  late final TextEditingController _notesCtrl;
  DateTime? _appliedAt;
  DateTime? _nextDueAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _doseCtrl = TextEditingController(text: e?.dose ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _appliedAt = e?.appliedAt;
    _nextDueAt = e?.nextDueAt;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickApplied() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _appliedAt ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _appliedAt = picked);
  }

  Future<void> _pickNextDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueAt ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() => _nextDueAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final title = widget.edit == null ? loc.vaccAddTitle : loc.edit;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenH * 0.85),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: loc.vaccNameField,
                    prefixIcon: const Icon(Icons.vaccines_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _doseCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: loc.vaccDoseOpt,
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    hintText: loc.vaccDoseHint,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                await _pickApplied();
                              },
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text('${loc.vaccApplied} ${widget.fmtDate(_appliedAt)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                await _pickNextDue();
                              },
                        icon: const Icon(Icons.event_repeat_outlined),
                        label: Text('${loc.vaccNext} ${widget.fmtDate(_nextDueAt)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: loc.vaccNotesOpt,
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final name = _nameCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(loc.vaccNameEmpty)),
                              );
                              return;
                            }
                            setState(() => _saving = true);
                            try {
                              await widget.runLoading(() async {
                                if (widget.edit == null) {
                                  final newId = await AppDatabase.instance.insertVaccine(
                                    babyId: widget.babyId,
                                    name: name,
                                    dose: _doseCtrl.text,
                                    appliedAt: _appliedAt,
                                    nextDueAt: _nextDueAt,
                                    notes: _notesCtrl.text,
                                  );
                                  VaccineCloudSync.pushLocalSoon(localBabyId: widget.babyId, localVaccineId: newId);
                                  await VaccineReminderScheduler.instance.rescheduleForBaby(widget.babyId);
                                } else {
                                  await AppDatabase.instance.updateVaccine(
                                    id: widget.edit!.id,
                                    babyId: widget.babyId,
                                    name: name,
                                    dose: _doseCtrl.text,
                                    appliedAt: _appliedAt,
                                    nextDueAt: _nextDueAt,
                                    notes: _notesCtrl.text,
                                  );
                                  VaccineCloudSync.pushLocalSoon(localBabyId: widget.babyId, localVaccineId: widget.edit!.id);
                                  await VaccineReminderScheduler.instance.rescheduleForBaby(widget.babyId);
                                }
                              }, label: loc.vaccSaving);
                              if (context.mounted) Navigator.of(context).pop(true);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${loc.commonCouldNotSave} $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: FaceBabySpinner(size: 18, strokeWidth: 2.5))
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? loc.commonSaving : loc.commonSave),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Seletor de bebê via bottom sheet (evita menu transparente do dropdown no portal noturno).
class _BabySelectorField extends StatelessWidget {
  const _BabySelectorField({
    required this.babies,
    required this.selectedId,
    required this.label,
    required this.onChanged,
  });

  final List<Map<String, Object?>> babies;
  final int? selectedId;
  final String label;
  final ValueChanged<int?> onChanged;

  static const TextStyle _valueStyle = TextStyle(
    color: AppTheme.textPrimary,
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );

  String? _nameFor(int? id) {
    if (id == null) return null;
    for (final b in babies) {
      if ((b['id'] as num).toInt() == id) {
        return (b['name'] as String?) ?? '—';
      }
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.card,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        final maxH = MediaQuery.sizeOf(sheetCtx).height * 0.55;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: babies.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.black.withAlpha(18),
                    ),
                    itemBuilder: (_, index) {
                      final b = babies[index];
                      final id = (b['id'] as num).toInt();
                      final name = (b['name'] as String?) ?? '—';
                      final selected = selectedId == id;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        leading: const Icon(Icons.child_care,
                            color: AppTheme.textSecondary),
                        title: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w900 : FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle,
                                color: AppTheme.ctaPrimary)
                            : null,
                        onTap: () => Navigator.of(sheetCtx).pop(id),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) onChanged(picked);
  }

  static final InputDecoration _fieldDecoration = InputDecoration(
    filled: true,
    fillColor: AppTheme.card,
    prefixIcon:
        Icon(Icons.child_care, color: AppTheme.textSecondary),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0x47000000)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0x47000000)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: AppTheme.primary, width: 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final selectedName = _nameFor(selectedId);
    final decoration = _fieldDecoration.copyWith(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
    );

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openPicker(context),
          child: InputDecorator(
            decoration: decoration,
            isEmpty: selectedName == null,
            child: Row(
              children: [
                Expanded(
                  child: selectedName == null
                      ? const SizedBox.shrink()
                      : Text(
                          selectedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _valueStyle,
                        ),
                ),
                const Icon(Icons.arrow_drop_down,
                    color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VaccinesTable extends StatelessWidget {
  final List<VaccineRecord> records;
  final void Function(VaccineRecord)? onEdit;
  final void Function(VaccineRecord)? onDelete;

  const _VaccinesTable({
    required this.records,
    this.onEdit,
    this.onDelete,
  });

  bool get _hasActions => onEdit != null && onDelete != null;

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final columns = <DataColumn>[
      DataColumn(label: Text(loc.vaccTableVac, style: const TextStyle(fontWeight: FontWeight.w900))),
      DataColumn(label: Text(loc.vaccTableDose, style: const TextStyle(fontWeight: FontWeight.w900))),
      DataColumn(label: Text(loc.vaccTableDate, style: const TextStyle(fontWeight: FontWeight.w900))),
      DataColumn(label: Text(loc.vaccTableNext, style: const TextStyle(fontWeight: FontWeight.w900))),
      DataColumn(label: Text(loc.vaccTableNotes, style: const TextStyle(fontWeight: FontWeight.w900))),
    ];
    if (_hasActions) {
      columns.add(const DataColumn(label: SizedBox(width: 88)));
    }

    return CardBox(
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          headingRowHeight: 40,
          dataRowMinHeight: 44,
          columns: columns,
          rows: records.map((r) {
            final dose = (r.dose ?? '—').trim();
            final notes = (r.notes ?? '—').trim();
            final cells = <DataCell>[
              DataCell(Text(r.name)),
              DataCell(Text(dose.isEmpty ? '—' : dose)),
              DataCell(Text(_fmtDate(r.appliedAt))),
              DataCell(Text(_fmtDate(r.nextDueAt))),
              DataCell(Text(notes.isEmpty ? '—' : notes)),
            ];
            if (_hasActions) {
              final editable = r.id > 0;
              cells.add(
                DataCell(
                  editable
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: loc.edit,
                              onPressed: () => onEdit!(r),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              tooltip: loc.delete,
                              onPressed: () => onDelete!(r),
                              icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              );
            }
            return DataRow(cells: cells);
          }).toList(),
        ),
      ),
    );
  }
}

