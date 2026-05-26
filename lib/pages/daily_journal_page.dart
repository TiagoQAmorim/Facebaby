import 'package:flutter/material.dart';

import '../utils/app_date_picker.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../services/app_database.dart';
import '../services/firebase/journal_cloud_sync.dart';
import '../theme/app_theme.dart';
import '../utils/portal_layout.dart';
import '../widgets/card_box.dart';
import '../widgets/loading_scope.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class DailyJournalPage extends StatefulWidget {
  const DailyJournalPage({super.key});

  @override
  State<DailyJournalPage> createState() => _DailyJournalPageState();
}

class _DailyJournalPageState extends State<DailyJournalPage> {
  final _controller = TextEditingController();
  DateTime _day = _dateOnly(DateTime.now());
  bool _loading = true;
  bool _saving = false;

  int? get _babyId => CurrentBabyController.instance.currentBabyId;

  @override
  void initState() {
    super.initState();
    _load();
    CurrentBabyController.instance.addListener(_onBabyChanged);
  }

  @override
  void dispose() {
    CurrentBabyController.instance.removeListener(_onBabyChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onBabyChanged() {
    _load();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDay() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted || picked == null) return;
    setState(() => _day = _dateOnly(picked));
    await _load();
  }

  Future<void> _load() async {
    final babyId = _babyId;
    if (babyId == null) {
      if (mounted) {
        setState(() {
          _controller.text = '';
          _loading = false;
        });
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final text = await AppDatabase.instance.getDailyJournalText(babyId: babyId, calendarDay: _day);
      if (!mounted) return;
      setState(() {
        _controller.text = text ?? '';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final s = S.of(context);
    final babyId = _babyId;
    if (babyId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.dailyJournalNoBaby)));
      return;
    }

    setState(() => _saving = true);
    try {
      await LoadingScope.of(context).run(
        () => AppDatabase.instance.upsertDailyJournalText(
          babyId: babyId,
          calendarDay: _day,
          text: _controller.text,
        ),
        label: s.dailyJournalSaving,
      );
      JournalCloudSync.pushLocalSoon(localBabyId: babyId, day: _day);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.dailyJournalSaved)));
    } catch (_) {
      // Reusa mensagens genéricas já existentes (evita expandir i18n agora).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.deleteFail)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final babyId = _babyId;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.dailyJournalTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardBox(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, color: AppTheme.textSecondary.withAlpha(220)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.dailyJournalOnDate(_fmtDate(_day)),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: portalSp(context, 14),
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickDay,
                        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                        label: Text(s.dailyJournalPickDay),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: CardBox(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : TextField(
                            controller: _controller,
                            enabled: !_saving && babyId != null,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: InputDecoration(
                              hintText: babyId == null ? s.dailyJournalNoBaby : s.dailyJournalHint,
                              border: InputBorder.none,
                            ),
                            style: TextStyle(
                              fontSize: portalSp(context, 14),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_saving || _loading) ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(s.dailyJournalSave),
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

