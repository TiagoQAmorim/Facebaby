import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../services/exact_alarm_android.dart';
import '../theme/app_theme.dart';

/// Android 12+: aviso quando faltam permissões para alarmas na hora certa.
class AndroidExactAlarmCard extends StatefulWidget {
  const AndroidExactAlarmCard({super.key});

  @override
  State<AndroidExactAlarmCard> createState() => _AndroidExactAlarmCardState();
}

class _AndroidExactAlarmCardState extends State<AndroidExactAlarmCard> with WidgetsBindingObserver {
  bool? _show;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final need = await ExactAlarmAndroid.needsExactAlarmFix();
    if (!mounted) return;
    setState(() => _show = need);
  }

  @override
  Widget build(BuildContext context) {
    if (_show != true) return const SizedBox.shrink();
    final s = S.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.yellow.withAlpha(28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.yellow.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded, color: AppTheme.yellow.withAlpha(240)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.alertsExactAlarmAndroidTitle,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.alertsExactAlarmAndroidBody,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.black.withAlpha(155),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await ExactAlarmAndroid.openExactAlarmSettings();
                    await Future<void>.delayed(const Duration(milliseconds: 900));
                    await _refresh();
                    if (mounted) setState(() => _busy = false);
                  },
            child: Text(s.alertsExactAlarmAndroidOpenSettings),
          ),
        ],
      ),
    );
  }
}
