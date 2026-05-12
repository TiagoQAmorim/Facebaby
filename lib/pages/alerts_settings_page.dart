import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../services/home_prefs.dart';
import '../services/local_notifications_service.dart';
import '../services/scheduled_local_reminders.dart';
import '../services/app_database.dart';
import '../services/sleep_routine.dart';
import '../services/premium/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/android_exact_alarm_card.dart';
import 'premium/premium_paywall_screen.dart';

/// **Mais › Alertas**: regras explicadas e preferências de lembretes locais.
class AlertsSettingsPage extends StatelessWidget {
  const AlertsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settingsAlerts)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppTheme.pageHPadding, 18, AppTheme.pageHPadding, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.alertsScreenIntro,
                style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: Colors.black.withAlpha(145)),
              ),
              ListenableBuilder(
                listenable: PremiumService.instance,
                builder: (context, _) {
                  if (PremiumService.instance.isPremium) return const SizedBox.shrink();
                  final accent = Color.lerp(AppTheme.primary, AppTheme.primaryPurple, 0.35)!;
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => openPremiumPaywall(context),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [
                                accent.withAlpha(26),
                                AppTheme.mint.withAlpha(40),
                              ],
                            ),
                            border: Border.all(color: accent.withAlpha(55)),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.nights_stay_rounded, color: accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.plusBrandTitle,
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: accent),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      s.settingsPlusCardBodyFree,
                                      style: TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600, color: Colors.black.withAlpha(145)),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: accent.withAlpha(200)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const AndroidExactAlarmCard(),
              const SizedBox(height: 22),
              _AlertsSectionCard(
                title: s.alertsSectionFeeding,
                rule: s.alertsRuleFeeding,
                accent: AppTheme.feedingAlertAccent,
                child: const _FeedingIntervalControls(),
              ),
              _AlertsSectionCard(
                title: s.alertsSectionDiaper,
                rule: s.alertsRuleDiaper,
                accent: AppTheme.green,
                child: ValueListenableBuilder<bool>(
                  valueListenable: HomePrefs.diaperAlertsEnabled,
                  builder: (context, enabled, _) {
                    return SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.diaperToggleAlerts, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(s.diaperToggleAlertsSubtitle, style: TextStyle(fontSize: 12.5, color: Colors.black.withAlpha(130))),
                      ),
                      value: enabled,
                      activeThumbColor: AppTheme.green,
                      activeTrackColor: AppTheme.green.withAlpha(90),
                      onChanged: (v) => HomePrefs.setDiaperAlertsEnabled(v),
                    );
                  },
                ),
              ),
              _AlertsSectionCard(
                title: s.alertsSectionSleep,
                rule: s.alertsRuleSleep,
                accent: AppTheme.primary,
                child: const _SleepAlertControls(),
              ),
              _AlertsSectionCard(
                title: s.alertsSectionGrowth,
                rule: s.alertsRuleGrowth,
                accent: const Color(0xFF00C4CC),
                child: ValueListenableBuilder<bool>(
                  valueListenable: HomePrefs.growthHealthAlertsEnabled,
                  builder: (context, enabled, _) {
                    return SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.healthGrowthToggleAlerts, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(s.healthGrowthToggleAlertsSubtitle, style: TextStyle(fontSize: 12.5, color: Colors.black.withAlpha(130))),
                      ),
                      value: enabled,
                      activeThumbColor: const Color(0xFF00C4CC),
                      activeTrackColor: const Color(0xFF00C4CC).withAlpha(90),
                      onChanged: (v) => HomePrefs.setGrowthHealthAlertsEnabled(v),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              const _AlertsTestCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diagnóstico: dispara uma notificação imediata e agenda outra a 30s para confirmar
/// que tanto o canal `show` como o `zonedSchedule` (OS AlarmManager) estão a funcionar.
class _AlertsTestCard extends StatefulWidget {
  const _AlertsTestCard();

  @override
  State<_AlertsTestCard> createState() => _AlertsTestCardState();
}

class _AlertsTestCardState extends State<_AlertsTestCard> {
  bool _busy = false;
  String? _lastResult;

  Future<void> _runTest() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _lastResult = null;
    });
    final svc = LocalNotificationsService.instance;
    final messenger = ScaffoldMessenger.of(context);

    final errors = <String>[];
    try {
      await svc.requestPermission();
    } catch (e) {
      errors.add('permission: $e');
    }

    try {
      await svc.show(
        id: 99001,
        title: 'FaceBaby — teste imediato',
        body: 'Se vê esta mensagem, o canal imediato está OK.',
      );
    } catch (e) {
      errors.add('show: $e');
    }

    try {
      final scheduled = await svc.scheduleZoned(
        id: 99002,
        title: 'FaceBaby — teste agendado',
        body: 'Esta foi agendada via AlarmManager (~30s).',
        whenLocal: DateTime.now().add(const Duration(seconds: 30)),
      );
      if (!scheduled) errors.add('schedule: AlarmManager recusou todos os modos');
    } catch (e) {
      errors.add('schedule: $e');
    }

    if (!mounted) return;
    final ok = errors.isEmpty;
    setState(() {
      _busy = false;
      _lastResult = ok
          ? 'Enviado. Deve receber agora (imediato) e em ~30s (agendado).'
          : 'Falhou: ${errors.join(' | ')}';
    });
    messenger.showSnackBar(SnackBar(content: Text(_lastResult!)));
  }

  Future<void> _runReminderSync() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _lastResult = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final babyId = CurrentBabyController.instance.currentBabyId;
    final buf = StringBuffer('bebé=$babyId');
    if (babyId != null) {
      try {
        final lastFeed = await AppDatabase.instance.latestBreastOrBottleFeedingEndedAt(babyId: babyId);
        buf.write(' • última mamada=${lastFeed?.toIso8601String() ?? '—'}');
        final lastSleep = await AppDatabase.instance.latestCompletedSleepEnd(babyId: babyId);
        buf.write(' • último sono fim=${lastSleep?.toIso8601String() ?? '—'}');
        final lastDiaper = await AppDatabase.instance.latestDiaperChangedAt(babyId: babyId);
        buf.write(' • última fralda=${lastDiaper?.toIso8601String() ?? '—'}');
      } catch (e) {
        buf.write(' • erro DB: $e');
      }
    }
    try {
      await ScheduledLocalReminders.sync(babyId: babyId);
      buf.write(' • sync OK');
    } catch (e) {
      buf.write(' • sync erro: $e');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResult = buf.toString();
    });
    messenger.showSnackBar(SnackBar(content: Text(_lastResult!), duration: const Duration(seconds: 8)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                'Testar notificações',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Dispara um aviso imediato e agenda outro daqui a 30 segundos. '
            'Útil para confirmar que o sistema está a entregar as notificações da app.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black.withAlpha(150)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _runTest,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bolt_rounded),
            label: const Text('Disparar teste'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _runReminderSync,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Forçar reagendamento (lembretes reais)'),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 10),
            Text(
              _lastResult!,
              style: TextStyle(fontSize: 12, color: Colors.black.withAlpha(170)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mesmo default que [`ScheduledLocalReminders`] quando prefs = 0.
class SleepAlertsDefaults {
  SleepAlertsDefaults._();

  static const int approachBeforeMin = 15;
}

class _AlertsSectionCard extends StatelessWidget {
  final String title;
  final String rule;
  final Color accent;
  final Widget child;

  const _AlertsSectionCard({
    required this.title,
    required this.rule,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(55)),
        boxShadow: [
          BoxShadow(color: accent.withAlpha(18), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accent, letterSpacing: -0.3),
          ),
          const SizedBox(height: 10),
          Text(
            rule,
            style: TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w600, color: Colors.black.withAlpha(148)),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.black.withAlpha(16)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _FeedingIntervalControls extends StatefulWidget {
  const _FeedingIntervalControls();

  @override
  State<_FeedingIntervalControls> createState() => _FeedingIntervalControlsState();
}

class _FeedingIntervalControlsState extends State<_FeedingIntervalControls> {
  late int _intervalDrag;

  @override
  void initState() {
    super.initState();
    _intervalDrag = HomePrefs.feedingAlertIntervalMinutes.value;
    HomePrefs.feedingAlertIntervalMinutes.addListener(_syncIntervalFromPrefs);
  }

  void _syncIntervalFromPrefs() {
    final v = HomePrefs.feedingAlertIntervalMinutes.value;
    if (_intervalDrag != v && mounted) setState(() => _intervalDrag = v);
  }

  @override
  void dispose() {
    HomePrefs.feedingAlertIntervalMinutes.removeListener(_syncIntervalFromPrefs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    const min = HomePrefs.feedingAlertIntervalMinClamp;
    const max = HomePrefs.feedingAlertIntervalMaxClamp;
    const accent = AppTheme.feedingAlertAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: HomePrefs.feedingAlertsEnabled,
          builder: (context, enabled, _) {
            return SwitchTheme(
              data: AppTheme.switchThemeColored(accent),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.feedingAlertsSwitchTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(s.feedingAlertsSwitchSubtitle, style: TextStyle(fontSize: 12.5, height: 1.3, color: Colors.black.withAlpha(140))),
                ),
                value: enabled,
                activeTrackColor: accent.withAlpha(90),
                onChanged: (v) => HomePrefs.setFeedingAlertsEnabled(v),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(left: 0, right: 4, top: 4),
          child: Text(
            s.feedingAlertsIntervalCaption(_intervalDrag),
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(170)),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 3.8, activeTrackColor: accent, thumbColor: accent),
          child: Slider(
            value: _intervalDrag.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: ((max - min) ~/ 10),
            label: '$_intervalDrag min',
            onChanged: (v) {
              var r = v.round();
              if (r < min) r = min;
              if (r > max) r = max;
              setState(() => _intervalDrag = r);
            },
            onChangeEnd: (_) => HomePrefs.setFeedingAlertIntervalMinutes(_intervalDrag),
          ),
        ),
      ],
    );
  }
}

class _SleepAlertControls extends StatefulWidget {
  const _SleepAlertControls();

  @override
  State<_SleepAlertControls> createState() => _SleepAlertControlsState();
}

class _SleepAlertControlsState extends State<_SleepAlertControls> {
  late int _maxDrag;
  late int _beforeDrag;

  @override
  void initState() {
    super.initState();
    _maxDrag = HomePrefs.sleepAwakeMaxOverrideMinutes.value;
    _beforeDrag = HomePrefs.sleepApproachBeforeMinutes.value;
    HomePrefs.sleepAwakeMaxOverrideMinutes.addListener(_sync);
    HomePrefs.sleepApproachBeforeMinutes.addListener(_sync);
    CurrentBabyController.instance.addListener(_sync);
  }

  void _sync() {
    if (!mounted) return;
    setState(() {
      _maxDrag = HomePrefs.sleepAwakeMaxOverrideMinutes.value;
      _beforeDrag = HomePrefs.sleepApproachBeforeMinutes.value;
    });
  }

  @override
  void dispose() {
    HomePrefs.sleepAwakeMaxOverrideMinutes.removeListener(_sync);
    HomePrefs.sleepApproachBeforeMinutes.removeListener(_sync);
    CurrentBabyController.instance.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    const accent = AppTheme.primary;
    final birthRaw = CurrentBabyController.instance.currentBabyRow?['birth_date'] as String?;
    final birth = DateTime.tryParse(birthRaw ?? '');
    final months = SleepRoutine.monthsOld(birth);
    final w = SleepRoutine.windowForMonths(months);
    final tableMax = w.maxAwakeMin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: HomePrefs.sleepAlertsEnabled,
          builder: (context, enabled, _) {
            return SwitchTheme(
              data: AppTheme.switchThemeColored(accent),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.sleepToggleAlerts, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(s.sleepToggleAlertsSubtitle, style: TextStyle(fontSize: 12.5, color: Colors.black.withAlpha(130))),
                ),
                value: enabled,
                activeTrackColor: accent.withAlpha(88),
                onChanged: (v) => HomePrefs.setSleepAlertsEnabled(v),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          birth == null
              ? '${s.sleepAlertsWakeWindowAutomaticNoBirth(tableMax)}\n(${s.sleepAlertsMonthsApprox(months)})'
              : (_maxDrag <= 0
                  ? '${s.sleepAlertsWakeWindowAutomatic(tableMax)}\n(${s.sleepAlertsMonthsApprox(months)})'
                  : s.sleepAlertsWakeWindowCustom(_maxDrag)),
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(170), height: 1.35),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 0, right: 4, top: 6),
          child: Text(
            _maxDrag <= 0
                ? s.sleepAlertsWakeWindowRulerValueAuto(tableMax)
                : s.sleepAlertsWakeWindowRulerValueCustom(_maxDrag),
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(170)),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 3.8, activeTrackColor: accent, thumbColor: accent),
          child: Slider(
            value: (_maxDrag <= 0 ? 0 : _maxDrag).toDouble(),
            min: 0,
            max: HomePrefs.sleepAwakeMaxMaxClamp.toDouble(),
            divisions: (HomePrefs.sleepAwakeMaxMaxClamp ~/ 30),
            label: _maxDrag <= 0
                ? s.sleepAlertsWakeWindowSliderLabelAuto(tableMax)
                : s.sleepAlertsWakeWindowSliderLabelCustom(_maxDrag),
            onChanged: (v) {
              final r = v.round();
              setState(() => _maxDrag = (r < HomePrefs.sleepAwakeMaxMinClamp) ? 0 : r);
            },
            onChangeEnd: (_) => HomePrefs.setSleepAwakeMaxOverrideMinutes(_maxDrag),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          () {
            if (_beforeDrag <= 0) {
              return s.sleepAlertsApproachAuto(SleepAlertsDefaults.approachBeforeMin);
            }
            return s.sleepAlertsApproachCustom(_beforeDrag);
          }(),
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(170)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 0, right: 4, top: 6),
          child: Text(
            _beforeDrag <= 0
                ? s.sleepAlertsApproachRulerValueDefault(SleepAlertsDefaults.approachBeforeMin)
                : s.sleepAlertsApproachRulerValueCustom(_beforeDrag),
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.black.withAlpha(170)),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 3.8, activeTrackColor: accent, thumbColor: accent),
          child: Slider(
            value: (_beforeDrag <= 0 ? 0 : _beforeDrag).toDouble(),
            min: 0,
            max: HomePrefs.sleepApproachBeforeMaxClamp.toDouble(),
            divisions: (HomePrefs.sleepApproachBeforeMaxClamp ~/ 5),
            label: _beforeDrag <= 0
                ? s.sleepAlertsApproachSliderLabelDefault(SleepAlertsDefaults.approachBeforeMin)
                : s.sleepAlertsApproachSliderLabelCustom(_beforeDrag),
            onChanged: (v) {
              final r = v.round();
              setState(() => _beforeDrag = (r < HomePrefs.sleepApproachBeforeMinClamp) ? 0 : r);
            },
            onChangeEnd: (_) => HomePrefs.setSleepApproachBeforeMinutes(_beforeDrag),
          ),
        ),
      ],
    );
  }
}
