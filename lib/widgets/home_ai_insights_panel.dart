import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_i18n.dart';
import '../models/ai/ai_insight_model.dart';
import '../services/ai/ai_insight_local_engine.dart';
import '../services/ai/ai_insights_service.dart';
import '../services/premium/feature_access.dart';
import 'ai/ai_insight_card.dart';

/// Resumos automáticos da IA Babá na Home (cache Firestore, sem OpenAI ao abrir).
class HomeAiInsightsPanel extends StatefulWidget {
  const HomeAiInsightsPanel({
    super.key,
    required this.babyId,
    required this.babyName,
    required this.babySex,
    required this.birthDate,
    this.onDismissedLayoutChanged,
  });

  final int? babyId;
  final String babyName;
  final String? babySex;
  final DateTime? birthDate;
  final ValueChanged<bool>? onDismissedLayoutChanged;

  @override
  State<HomeAiInsightsPanel> createState() => _HomeAiInsightsPanelState();
}

class _HomeAiInsightsPanelState extends State<HomeAiInsightsPanel> {
  final _service = AiInsightsService();
  StreamSubscription<AiInsight?>? _dailySub;
  AiInsight? _weekly;
  bool _dailyDismissed = false;
  bool _weeklyDismissed = false;
  String _prefsDay = '';

  static String _dailyDismissKey(int babyId, String day) =>
      'facebaby_home_ai_insight_daily_dismiss_v1_${babyId}_$day';

  static String _weeklyDismissKey(int babyId, String day) =>
      'facebaby_home_ai_insight_weekly_dismiss_v1_${babyId}_$day';

  bool get _allDismissed => _dailyDismissed && _weeklyDismissed;

  void _notifyLayout() {
    final cb = widget.onDismissedLayoutChanged;
    if (cb == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      cb(_allDismissed);
    });
  }

  @override
  void initState() {
    super.initState();
    _prefsDay = _dayStamp(DateTime.now());
    _dailySub = _service.watchTodayDaily().listen((doc) {
      if (!mounted) return;
      setState(() {});
    });
    unawaited(_reloadDismissPrefs());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = S.of(context);
      AiInsightsBootstrap.scheduleIfNeeded(s);
    });
  }

  @override
  void dispose() {
    _dailySub?.cancel();
    super.dispose();
  }

  String _dayStamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _syncDay() {
    final day = _dayStamp(DateTime.now());
    if (_prefsDay == day) return;
    _prefsDay = day;
    setState(() {
      _dailyDismissed = false;
      _weeklyDismissed = false;
    });
    unawaited(_reloadDismissPrefs());
    unawaited(_loadWeekly());
  }

  Future<void> _reloadDismissPrefs() async {
    final bid = widget.babyId;
    if (bid == null) {
      if (mounted) {
        setState(() {
          _dailyDismissed = false;
          _weeklyDismissed = false;
        });
        _notifyLayout();
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final stamp = _dayStamp(DateTime.now());
    final d = prefs.getBool(_dailyDismissKey(bid, stamp)) ?? false;
    final w = prefs.getBool(_weeklyDismissKey(bid, stamp)) ?? false;
    if (!mounted) return;
    setState(() {
      _dailyDismissed = d;
      _weeklyDismissed = w;
    });
    _notifyLayout();
  }

  Future<void> _loadWeekly() async {
    final w = await _service.loadThisWeek();
    if (!mounted) return;
    setState(() => _weekly = w);
  }

  Future<void> _dismissDaily() async {
    final bid = widget.babyId;
    if (bid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyDismissKey(bid, _dayStamp(DateTime.now())), true);
    if (!mounted) return;
    setState(() => _dailyDismissed = true);
    _notifyLayout();
  }

  Future<void> _dismissWeekly() async {
    final bid = widget.babyId;
    if (bid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weeklyDismissKey(bid, _dayStamp(DateTime.now())), true);
    if (!mounted) return;
    setState(() => _weeklyDismissed = true);
    _notifyLayout();
  }

  @override
  void didUpdateWidget(covariant HomeAiInsightsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDay();
    if (oldWidget.babyId != widget.babyId) {
      unawaited(_reloadDismissPrefs());
      unawaited(_loadWeekly());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureAccess.canUseAnyAi) return const SizedBox.shrink();
    _syncDay();
    final s = S.of(context);
    final bid = widget.babyId;

    return StreamBuilder<AiInsight?>(
      stream: _service.watchTodayDaily(),
      builder: (context, dailySnap) {
        final daily = dailySnap.data;
        if (_weekly == null && bid != null) {
          unawaited(_loadWeekly());
        }

        final children = <Widget>[];

        if (!_dailyDismissed && daily != null && daily.text.isNotEmpty) {
          children.add(
            AiInsightCard(
              title: s.homeAiInsightDailyTitle,
              body: daily.text,
              onDismiss: bid == null ? null : _dismissDaily,
            ),
          );
        } else if (!_dailyDismissed && bid != null && daily == null) {
          children.add(
            FutureBuilder<String>(
              future: AiInsightLocalEngine.buildDailySummary(
                babyId: bid,
                babyName: widget.babyName,
                babySex: widget.babySex,
                birthDate: widget.birthDate,
                strings: s,
              ),
              builder: (context, snap) {
                final text = snap.data?.trim() ?? '';
                if (text.isEmpty) return const SizedBox.shrink();
                return AiInsightCard(
                  title: s.homeAiInsightDailyTitle,
                  body: text,
                  onDismiss: _dismissDaily,
                );
              },
            ),
          );
        }

        if (!_weeklyDismissed &&
            _weekly != null &&
            _weekly!.text.isNotEmpty) {
          if (children.isNotEmpty) children.add(const SizedBox(height: 8));
          children.add(
            AiInsightCard(
              title: s.homeAiInsightWeeklyTitle,
              body: _weekly!.text,
              onDismiss: bid == null ? null : _dismissWeekly,
            ),
          );
        }

        if (children.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}
