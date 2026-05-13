import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/symptom_report.dart';
import '../services/app_database.dart';
import '../services/firebase/symptom_cloud_sync.dart';
import '../services/measurement_units_prefs.dart';
import '../theme/app_theme.dart';
import '../utils/measurement_format.dart';
import '../utils/portal_layout.dart';
import '../utils/symptom_report_format.dart';
import '../widgets/card_box.dart';

/// Lista e edição de relatos de sintomas (Saúde) — alimenta o relatório pediátrico.
class SymptomReportsPage extends StatefulWidget {
  const SymptomReportsPage({super.key});

  @override
  State<SymptomReportsPage> createState() => _SymptomReportsPageState();
}

class _SymptomReportsPageState extends State<SymptomReportsPage> {
  final _babyCtrl = CurrentBabyController.instance;
  List<SymptomReport> _items = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _babyCtrl.addListener(_onBaby);
    _load();
  }

  @override
  void dispose() {
    _babyCtrl.removeListener(_onBaby);
    super.dispose();
  }

  void _onBaby() => _load();

  Future<void> _load() async {
    final id = _babyCtrl.currentBabyId;
    if (id == null) {
      if (mounted) setState(() => _items = const []);
      return;
    }
    try {
      final rows = await AppDatabase.instance.listSymptomReports(babyId: id);
      if (!mounted) return;
      setState(() {
        _items = rows.map(SymptomReport.fromMap).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _openEditor({SymptomReport? edit}) async {
    final babyId = _babyCtrl.currentBabyId;
    if (babyId == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SymptomReportEditorPage(babyId: babyId, edit: edit),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _confirmDelete(SymptomReport r) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.symptomReportDeleteTitle),
        content: Text(s.symptomReportDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final babyId = _babyCtrl.currentBabyId;
    if (babyId == null) return;
    try {
      await SymptomCloudSync.deleteRemoteIfExists(localBabyId: babyId, localSymptomId: r.id);
      await AppDatabase.instance.deleteSymptomReport(id: r.id, babyId: babyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.deletedOk)));
        await _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final loc = Localizations.localeOf(context).toString();
    final bid = _babyCtrl.currentBabyId;

    return Scaffold(
      appBar: AppBar(title: Text(s.symptomReportTitle)),
      floatingActionButton: bid == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: Text(s.symptomReportNew),
            ),
      body: SafeArea(
        child: bid == null
            ? Center(child: Text(s.feedingNoBabyHint))
            : _error != null
                ? Center(child: SelectableText('$_error'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                            children: [
                              Text(
                                s.symptomReportEmpty,
                                style: TextStyle(
                                  color: Colors.black.withAlpha(140),
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final r = _items[i];
                              final line = SymptomReportFormat.summaryLine(s, r, loc);
                              return CardBox(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: InkWell(
                                  onTap: () => _openEditor(edit: r),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              line,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: portalSp(context, 14),
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: s.delete,
                                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.withAlpha(200)),
                                        onPressed: () => _confirmDelete(r),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}

class SymptomReportEditorPage extends StatefulWidget {
  const SymptomReportEditorPage({super.key, required this.babyId, this.edit});

  final int babyId;
  final SymptomReport? edit;

  @override
  State<SymptomReportEditorPage> createState() => _SymptomReportEditorPageState();
}

class _SymptomReportEditorPageState extends State<SymptomReportEditorPage> {
  late DateTime _occurredAt = widget.edit?.occurredAt ?? DateTime.now();
  late final TextEditingController _medCtrl =
      TextEditingController(text: widget.edit?.medicationNote ?? '');
  late final TextEditingController _tempCtrl = TextEditingController(
    text: widget.edit?.tempCelsius != null
        ? _initialTempDisplay(widget.edit!.tempCelsius!)
        : '',
  );
  late final TextEditingController _otherCtrl =
      TextEditingController(text: widget.edit?.otherNote ?? '');

  late bool _fever = widget.edit?.fever ?? false;
  late bool _crying = widget.edit?.unexplainedCrying ?? false;
  late bool _pain = widget.edit?.pain ?? false;
  late bool _colic = widget.edit?.colic ?? false;
  late bool _reflux = widget.edit?.reflux ?? false;

  bool _saving = false;

  static String _initialTempDisplay(double celsius) {
    switch (MeasurementUnitsPrefs.temperature.value) {
      case TemperatureUnit.c:
        return celsius.toStringAsFixed(1).replaceAll('.', ',');
      case TemperatureUnit.f:
        final f = (celsius * 9.0 / 5.0) + 32.0;
        return f.toStringAsFixed(1).replaceAll('.', ',');
    }
  }

  @override
  void dispose() {
    _medCtrl.dispose();
    _tempCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  bool _validate(S s) {
    final med = _medCtrl.text.trim().isNotEmpty;
    final other = _otherCtrl.text.trim().isNotEmpty;
    final tempOk = !_fever || MeasurementFormat.parseTempToC(_tempCtrl.text) != null;
    final anyFlag = _crying || _pain || _colic || _reflux;
    final any = med || other || anyFlag || (_fever && MeasurementFormat.parseTempToC(_tempCtrl.text) != null);

    if (!any) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.symptomReportValidationNeedOne)));
      return false;
    }
    if (!tempOk) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.symptomReportValidationFeverTemp)));
      return false;
    }
    return true;
  }

  Future<void> _pickDateTime(S s) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (t == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save(S s) async {
    if (!_validate(s) || _saving) return;
    final tempC = _fever ? MeasurementFormat.parseTempToC(_tempCtrl.text) : null;

    setState(() => _saving = true);
    try {
      final edit = widget.edit;
      if (edit == null) {
        final newId = await AppDatabase.instance.insertSymptomReport(
          babyId: widget.babyId,
          occurredAt: _occurredAt,
          medicationNote: _medCtrl.text,
          fever: _fever,
          tempCelsius: tempC,
          crying: _crying,
          pain: _pain,
          colic: _colic,
          reflux: _reflux,
          otherNote: _otherCtrl.text,
        );
        SymptomCloudSync.pushLocalSoon(localBabyId: widget.babyId, localSymptomId: newId);
      } else {
        await AppDatabase.instance.updateSymptomReport(
          id: edit.id,
          babyId: widget.babyId,
          occurredAt: _occurredAt,
          medicationNote: _medCtrl.text,
          fever: _fever,
          tempCelsius: tempC,
          crying: _crying,
          pain: _pain,
          colic: _colic,
          reflux: _reflux,
          otherNote: _otherCtrl.text,
        );
        SymptomCloudSync.pushLocalSoon(localBabyId: widget.babyId, localSymptomId: edit.id);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit == null ? s.symptomReportNew : s.edit),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(s),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : Text(s.symptomReportSave, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded, color: AppTheme.primary),
            title: Text(s.symptomReportOccurredAt),
            subtitle: Text(
              '${MaterialLocalizations.of(context).formatMediumDate(_occurredAt)} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_occurredAt))}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () => _pickDateTime(s),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _medCtrl,
            decoration: InputDecoration(
              labelText: s.symptomReportMedication,
              hintText: s.symptomReportMedicationHint,
              prefixIcon: const Icon(Icons.medication_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(s.symptomReportFever),
            value: _fever,
            activeThumbColor: AppTheme.green,
            onChanged: (v) => setState(() => _fever = v),
          ),
          if (_fever) ...[
            ValueListenableBuilder<TemperatureUnit>(
              valueListenable: MeasurementUnitsPrefs.temperature,
              builder: (context, unit, _) {
                return TextField(
                  controller: _tempCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: s.symptomReportTemp,
                    hintText: s.symptomReportTempHint,
                    suffixText: unit == TemperatureUnit.c ? 'ºC' : 'ºF',
                    prefixIcon: const Icon(Icons.thermostat_outlined),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(s.symptomReportCrying),
            value: _crying,
            activeThumbColor: AppTheme.green,
            onChanged: (v) => setState(() => _crying = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(s.symptomReportPain),
            value: _pain,
            activeThumbColor: AppTheme.green,
            onChanged: (v) => setState(() => _pain = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(s.symptomReportColic),
            value: _colic,
            activeThumbColor: AppTheme.green,
            onChanged: (v) => setState(() => _colic = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(s.symptomReportReflux),
            value: _reflux,
            activeThumbColor: AppTheme.green,
            onChanged: (v) => setState(() => _reflux = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otherCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: s.symptomReportOther,
              hintText: s.symptomReportOtherHint,
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : () => _save(s),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.primary,
            ),
            child: Text(s.symptomReportSave),
          ),
        ],
      ),
    );
  }
}
