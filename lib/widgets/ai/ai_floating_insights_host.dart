import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_insight_model.dart';
import '../../controllers/sleep_timer_controller.dart';
import '../../controllers/current_baby_controller.dart';
import '../../services/floating_message_service.dart';
import '../../models/family_message_prefs.dart';
import '../../utils/family_date_keys.dart';
import '../../utils/family_nav.dart';
import '../../services/ai/ai_bubble_alert_engine.dart';
import '../../services/ai/ai_bubble_message_policy.dart';
import '../../repositories/floating_message_repository.dart';
import '../../services/ai/ai_bubble_queue_lifecycle.dart';
import '../../services/growth_curve_alert_ack.dart';
import '../../services/growth_events.dart';
import '../../services/ai/ai_bubble_routine_insights.dart';
import '../../services/ai/ai_insight_local_engine.dart';
import '../../models/floating_message_model.dart';
import '../../services/admin_broadcast_inbox_service.dart';
import '../../services/ai/ai_insights_service.dart';
import '../../services/family_homily_read_prefs.dart';
import '../../services/family_horoscope_read_prefs.dart';
import '../../services/home_prefs.dart';
import '../../services/premium/feature_access.dart';
import '../../utils/family_page_tabs.dart';
import 'ai_floating_message_bubble.dart';

class _BubbleMessage {
  const _BubbleMessage({
    required this.id,
    required this.text,
    required this.prefsKey,
    this.imageUrl,
    this.actionUrl,
    this.actionButtonLabel,
    this.adminCampaignId,
    this.hasActionButton = false,
    this.onActionTap,
    this.collapsedIcon,
  });

  final String id;
  final String text;
  final String prefsKey;
  final String? collapsedIcon;
  final String? imageUrl;
  final String? actionUrl;
  final String? actionButtonLabel;
  /// Quando preenchido, dismiss grava em Firestore (mensagem do admin).
  final String? adminCampaignId;
  final bool hasActionButton;
  final VoidCallback? onActionTap;
}

/// Host flutuante: carrega insights, fila de mensagens, posição e dismiss.
class AiFloatingInsightsHost extends StatefulWidget {
  const AiFloatingInsightsHost({
    super.key,
    required this.babyId,
    required this.babyName,
    required this.babySex,
    required this.birthDate,
  });

  final int? babyId;
  final String babyName;
  final String? babySex;
  final DateTime? birthDate;

  @override
  State<AiFloatingInsightsHost> createState() => _AiFloatingInsightsHostState();
}

class _AiFloatingInsightsHostState extends State<AiFloatingInsightsHost> {
  final _service = AiInsightsService();
  StreamSubscription<AiInsight?>? _dailySub;
  StreamSubscription<List<AdminBroadcastInboxItem>>? _adminInboxSub;
  Timer? _refreshTimer;
  VoidCallback? _horoscopeReadyListener;
  VoidCallback? _homilyReadyListener;
  VoidCallback? _insightsReadyListener;
  List<AdminBroadcastInboxItem> _adminInbox = [];

  final List<_BubbleMessage> _queue = [];
  int _index = 0;
  bool _expanded = false;
  bool _dragging = false;
  Offset _position = const Offset(280, 420);
  /// Posição do orb minimizado — preservada ao expandir/fechar ou trocar mensagem.
  Offset? _anchoredCollapsedTopLeft;
  Size? _lastViewportSize;
  bool _positionLoaded = false;
  String _prefsDay = '';
  bool _isFirstQueueLoad = true;
  /// Pulsa o balão quando chega mensagem nova (ainda não aberta).
  bool _newMessageAlert = false;
  bool _pendingPromoCenter = false;
  bool _rebuildInFlight = false;
  bool _rebuildPending = false;
  final Set<String> _suppressedPrefsKeys = {};

  @override
  void initState() {
    super.initState();
    _anchoredCollapsedTopLeft = _position;
    _prefsDay = _dayStamp(DateTime.now());
    _dailySub = _service.watchTodayDaily().listen((_) {
      if (!mounted) return;
      unawaited(_safeRebuildQueue());
    });
    _adminInboxSub = AdminBroadcastInboxService.instance.watchActive().listen(
      (items) {
        if (!mounted) return;
        setState(() => _adminInbox = items);
        unawaited(_safeRebuildQueue());
      },
    );
    SleepTimerController.instance.addListener(_onRoutineChanged);
    HomePrefs.feedingAlertsEnabled.addListener(_onRoutineChanged);
    HomePrefs.sleepAlertsEnabled.addListener(_onRoutineChanged);
    HomePrefs.diaperAlertsEnabled.addListener(_onRoutineChanged);
    HomePrefs.growthHealthAlertsEnabled.addListener(_onRoutineChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted) return;
      unawaited(_safeRebuildQueue());
    });
    _horoscopeReadyListener = () {
      if (!mounted) return;
      unawaited(_safeRebuildQueue());
    };
    FamilyHoroscopeReadyNotifier.generation
        .addListener(_horoscopeReadyListener!);
    _homilyReadyListener = () {
      if (!mounted) return;
      unawaited(_safeRebuildQueue());
    };
    FamilyHomilyReadyNotifier.generation.addListener(_homilyReadyListener!);
    _insightsReadyListener = () {
      if (!mounted) return;
      unawaited(_safeRebuildQueue());
    };
    AiInsightsReadyNotifier.generation.addListener(_insightsReadyListener!);
    CurrentBabyController.instance.addListener(_onBabyOrDataChanged);
    GrowthEvents.revision.addListener(_onRoutineChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = S.of(context);
      AiInsightsBootstrap.scheduleIfNeeded(s);
      unawaited(_safeRebuildQueue());
    });
  }

  void _onBabyOrDataChanged() {
    if (!mounted) return;
    unawaited(_safeRebuildQueue());
  }

  Future<void> _safeRebuildQueue() async {
    if (_rebuildInFlight) {
      _rebuildPending = true;
      return;
    }
    _rebuildInFlight = true;
    try {
      do {
        _rebuildPending = false;
        await _rebuildQueue();
      } while (_rebuildPending && mounted);
    } finally {
      _rebuildInFlight = false;
    }
  }

  void _onRoutineChanged() {
    if (!mounted) return;
    unawaited(_safeRebuildQueue());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _dailySub?.cancel();
    _adminInboxSub?.cancel();
    SleepTimerController.instance.removeListener(_onRoutineChanged);
    HomePrefs.feedingAlertsEnabled.removeListener(_onRoutineChanged);
    HomePrefs.sleepAlertsEnabled.removeListener(_onRoutineChanged);
    HomePrefs.diaperAlertsEnabled.removeListener(_onRoutineChanged);
    HomePrefs.growthHealthAlertsEnabled.removeListener(_onRoutineChanged);
    GrowthEvents.revision.removeListener(_onRoutineChanged);
    final horoscopeListener = _horoscopeReadyListener;
    if (horoscopeListener != null) {
      FamilyHoroscopeReadyNotifier.generation
          .removeListener(horoscopeListener);
    }
    final homilyListener = _homilyReadyListener;
    if (homilyListener != null) {
      FamilyHomilyReadyNotifier.generation.removeListener(homilyListener);
    }
    final insightsListener = _insightsReadyListener;
    if (insightsListener != null) {
      AiInsightsReadyNotifier.generation.removeListener(insightsListener);
    }
    CurrentBabyController.instance.removeListener(_onBabyOrDataChanged);
    super.dispose();
  }

  String _dayStamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// yyyyMMdd — chaves diárias (homilia / horóscopo), fuso SP.
  String _compactDayKey([DateTime? when]) => FamilyDateKeys.todayCompact(when);

  static bool _isFamilyDailyBubbleKey(String prefsKey) =>
      prefsKey.startsWith('family_homily_ready_') ||
      prefsKey.startsWith('family_horoscope_ready_');

  /// Homilia e horóscopo prontos — prioridade no topo da fila.
  Future<void> _appendFamilyDailyBubbleAlerts({
    required List<_BubbleMessage> target,
    required SharedPreferences prefs,
    required int babyId,
    required S strings,
  }) async {
    await FamilyHoroscopeReadPrefs.clearIfNewDay();
    await FamilyHomilyReadPrefs.clearIfNewDay();
    await FamilyHoroscopeUnreadBadge.refresh();
    await FamilyHomilyUnreadBadge.refresh();

    final familyPrefs = FamilyMessagePrefs.fromMother(
      CurrentBabyController.instance.currentMotherRow,
    );
    final dayKey = _compactDayKey();
    final homilyTab = FamilyPageTabs.homily(familyPrefs);
    if (homilyTab != null && await FamilyHomilyBubbleAlert.shouldShowInBubble()) {
      await _addIfEligible(
        items: target,
        prefs: prefs,
        babyId: babyId,
        skipRetroactiveCheck: true,
        message: _BubbleMessage(
          id: 'family_homily_ready_$dayKey',
          text: strings.aiBubbleHomilyReady,
          prefsKey: 'family_homily_ready_$dayKey',
          actionButtonLabel: strings.aiBubbleHomilyOpenLink,
          hasActionButton: true,
          onActionTap: () {
            if (!context.mounted) return;
            FamilyNav.openFamilyTreeTab(context, initialTabIndex: homilyTab);
          },
        ),
      );
    }

    final horoscopeTab = FamilyPageTabs.horoscope(familyPrefs);
    if (horoscopeTab != null &&
        await FamilyHoroscopeBubbleAlert.shouldShowInBubble()) {
      await _addIfEligible(
        items: target,
        prefs: prefs,
        babyId: babyId,
        skipRetroactiveCheck: true,
        message: _BubbleMessage(
          id: 'family_horoscope_ready_$dayKey',
          text: strings.aiBubbleHoroscopeReady,
          prefsKey: 'family_horoscope_ready_$dayKey',
          actionButtonLabel: strings.aiBubbleHoroscopeOpenLink,
          hasActionButton: true,
          onActionTap: () {
            if (!context.mounted) return;
            FamilyNav.openFamilyTreeTab(
              context,
              initialTabIndex: horoscopeTab,
            );
          },
        ),
      );
    }
  }

  static String _posKey(int babyId) => 'facebaby_ai_bubble_pos_v1_$babyId';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _mondayOfWeek(DateTime date) {
    final local = _dateOnly(date);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  void _suppressPrefsKeysFor(_BubbleMessage item) {
    _suppressedPrefsKeys.add(item.prefsKey);
    final campaignId = item.adminCampaignId;
    if (campaignId != null && campaignId.isNotEmpty) {
      _suppressedPrefsKeys.add('fs_$campaignId');
      _suppressedPrefsKeys.add('admin_$campaignId');
    }
  }

  Future<void> _addIfEligible({
    required List<_BubbleMessage> items,
    required SharedPreferences prefs,
    required int babyId,
    required _BubbleMessage message,
    DateTime? contentDay,
    bool skipRetroactiveCheck = false,
    bool persistUntilDismissed = false,
  }) async {
    if (_suppressedPrefsKeys.contains(message.prefsKey)) return;
    final ok = await AiBubbleQueueLifecycle.shouldShow(
      babyId: babyId,
      prefsKey: message.prefsKey,
      prefs: prefs,
      contentDay: contentDay,
      skipRetroactiveCheck: skipRetroactiveCheck,
      persistUntilDismissed: persistUntilDismissed,
    );
    if (!ok) return;
    await AiBubbleQueueLifecycle.noteEnqueued(
      babyId: babyId,
      prefsKey: message.prefsKey,
      prefs: prefs,
    );
    items.add(message);
  }

  Future<void> _loadPosition(Size area, EdgeInsets safePadding) async {
    var pos = AiFloatingMessageBubble.defaultCollapsedTopLeft(
      viewport: area,
      safePadding: safePadding,
    );
    final bid = widget.babyId;
    if (bid != null) {
      final prefs = await SharedPreferences.getInstance();
      final key = _posKey(bid);
      final dx = prefs.getDouble('${key}_dx');
      final dy = prefs.getDouble('${key}_dy');
      if (dx != null && dy != null) {
        pos = AiFloatingMessageBubble.clampCollapsedTopLeft(
          topLeft: Offset(dx, dy),
          viewport: area,
          bottomReserve: 24,
        );
      }
    }
    if (!mounted) return;
    _position = pos;
    _anchoredCollapsedTopLeft = pos;
    _positionLoaded = true;
    setState(() {});
  }

  void _syncAnchoredCollapsedTopLeft(
    Size area, {
    double bottomReserve = 24,
  }) {
    final topLeft = _expanded
        ? (_anchoredCollapsedTopLeft ?? _position)
        : AiFloatingMessageBubble.snapToCollapsedAnchor(
            anchor: _anchoredCollapsedTopLeft,
            fallback: _position,
            viewport: area,
            bottomReserve: bottomReserve,
          );
    _anchoredCollapsedTopLeft = AiFloatingMessageBubble.clampCollapsedTopLeft(
      topLeft: topLeft,
      viewport: area,
      bottomReserve: bottomReserve,
    );
  }

  void _snapToCollapsedAnchor({double bottomReserve = 24}) {
    _position = AiFloatingMessageBubble.snapToCollapsedAnchor(
      anchor: _anchoredCollapsedTopLeft,
      fallback: _position,
      viewport: _lastViewportSize,
      bottomReserve: bottomReserve,
    );
  }

  /// Expandido usa `_position` (centro/clamp do card); minimizado usa sempre o anchor.
  Offset _bubblePosition(Size area, {required double bottomReserve}) {
    if (_expanded) return _position;
    return AiFloatingMessageBubble.snapToCollapsedAnchor(
      anchor: _anchoredCollapsedTopLeft,
      fallback: _position,
      viewport: area,
      bottomReserve: bottomReserve,
    );
  }

  void _goToAdjacentMessage(int delta) {
    if (_queue.length <= 1) return;
    setState(() {
      _snapToCollapsedAnchor();
      _index = (_index + delta) % _queue.length;
      if (_index < 0) _index += _queue.length;
      _newMessageAlert = false;
      final item = _queue[_index];
      _pendingPromoCenter = _expanded && _isPromoMessage(item);
    });
  }

  Future<void> _persistPosition() async {
    final bid = widget.babyId;
    if (bid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _posKey(bid);
    await prefs.setDouble('${key}_dx', _position.dx);
    await prefs.setDouble('${key}_dy', _position.dy);
  }

  Future<void> _rebuildQueue() async {
    if (!mounted) return;
    final bid = widget.babyId;
    final s = S.of(context);
    final prefs = await SharedPreferences.getInstance();

    final bubbleSettings =
        await FloatingMessageRepository().fetchBubbleQueueSettings();
    await AiBubbleQueueLifecycle.runGlobalResetIfNeeded(
      prefs: prefs,
      settings: bubbleSettings,
    );

    final items = <_BubbleMessage>[];
    final priorityItems = <_BubbleMessage>[];
    final firestoreAdminIds = <String>{};

    if (bid != null) {
      await AiBubbleQueueLifecycle.ensureAnchorDay(babyId: bid, prefs: prefs);
      await _appendFamilyDailyBubbleAlerts(
        target: priorityItems,
        prefs: prefs,
        babyId: bid,
        strings: s,
      );
      if (HomePrefs.growthHealthAlertsEnabled.value &&
          widget.birthDate != null) {
        final contextual = await AiBubbleAlertEngine.buildContextualAlerts(
          babyId: bid,
          babyName: widget.babyName,
          babySex: widget.babySex,
          birthDate: widget.birthDate,
          strings: s,
        );
        final growthCurve = contextual
            .where((a) => a.prefsKey.startsWith('alert_growth_curve_'))
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));
        for (final alert in growthCurve) {
          final sig = alert.prefsKey.startsWith('alert_growth_curve_')
              ? alert.prefsKey.substring('alert_growth_curve_'.length)
              : '';
          final before = priorityItems.length;
          await _addIfEligible(
            items: priorityItems,
            prefs: prefs,
            babyId: bid,
            skipRetroactiveCheck: true,
            message: _BubbleMessage(
              id: alert.id,
              text: alert.text,
              prefsKey: alert.prefsKey,
            ),
          );
          if (sig.isNotEmpty && priorityItems.length > before) {
            await GrowthCurveAlertAck.markNotified(
              babyId: bid,
              signature: sig,
            );
          }
        }
      }
      try {
        final firestoreMsgs =
            await FloatingMessageService.instance.listActiveMessages();
        for (final fm in firestoreMsgs) {
          if (!fm.hasRenderableContent) continue;
          final fsKey = 'fs_${fm.id}';
          final text = fm.displayText;
          if (fm.type.isAdmin) firestoreAdminIds.add(fm.id);
          await _addIfEligible(
            items: priorityItems,
            prefs: prefs,
            babyId: bid,
            contentDay: fm.createdAt,
            skipRetroactiveCheck: false,
            persistUntilDismissed: fm.type.isAdmin,
            message: _BubbleMessage(
              id: fm.id,
              text: text,
              prefsKey: fsKey,
              imageUrl: fm.imageUrl,
              actionUrl: fm.effectiveActionUrl,
              actionButtonLabel: fm.hasActionButton ? fm.actionLabel : null,
              hasActionButton: fm.hasActionButton,
              adminCampaignId: fm.type.isAdmin ? fm.id : null,
              collapsedIcon: fm.type.collapsedEmoji,
            ),
          );
        }
      } catch (e) {
        debugPrint('AiFloatingInsightsHost firestore messages: $e');
      }
    }

    for (final admin in _adminInbox) {
      if (!admin.hasRenderableContent) continue;
      if (firestoreAdminIds.contains(admin.campaignId)) continue;
      final adminKey = 'admin_${admin.campaignId}';
      final target = bid == null ? items : priorityItems;
      if (bid == null) {
        target.add(
          _BubbleMessage(
            id: 'admin_${admin.campaignId}',
            text: admin.text,
            prefsKey: adminKey,
            imageUrl: admin.imageUrl,
            actionUrl: admin.actionUrl,
            actionButtonLabel: admin.actionButtonLabel,
            adminCampaignId: admin.campaignId,
            collapsedIcon: FloatingMessageType.adminNotice.collapsedEmoji,
          ),
        );
        continue;
      }
      await _addIfEligible(
        items: target,
        prefs: prefs,
        babyId: bid,
        contentDay: admin.createdAt,
        skipRetroactiveCheck: false,
        persistUntilDismissed: true,
        message: _BubbleMessage(
          id: 'admin_${admin.campaignId}',
          text: admin.text,
          prefsKey: adminKey,
          imageUrl: admin.imageUrl,
          actionUrl: admin.actionUrl,
          actionButtonLabel: admin.actionButtonLabel,
          adminCampaignId: admin.campaignId,
          collapsedIcon: FloatingMessageType.adminNotice.collapsedEmoji,
        ),
      );
    }

    if (bid == null) {
      if (!mounted) return;
      setState(() {
        _queue
          ..clear()
          ..addAll(items);
        if (_index >= _queue.length) _index = 0;
      });
      return;
    }

    try {
      await _service.ensureInsights(strings: s);
    } catch (e, st) {
      debugPrint('AiFloatingInsightsHost ensureInsights: $e\n$st');
    }

    final today = _dateOnly(DateTime.now());
    var daily = await _service.loadTodayDaily();
    var dailyText = daily?.text.trim() ?? '';
    if (dailyText.isEmpty) {
      dailyText = await AiInsightLocalEngine.buildDailySummary(
        babyId: bid,
        babyName: widget.babyName,
        babySex: widget.babySex,
        birthDate: widget.birthDate,
        strings: s,
      );
    }

    final briefPrefsKey = AiBubbleRoutineInsights.unifiedPrefsKey;
    final brief = await AiBubbleRoutineInsights.buildUnifiedDailyBrief(
      babyId: bid,
      babyName: widget.babyName,
      babySex: widget.babySex,
      birthDate: widget.birthDate,
      strings: s,
      todayDailyText: dailyText,
    );
    if (brief != null && brief.trim().isNotEmpty) {
      await _addIfEligible(
        items: items,
        prefs: prefs,
        babyId: bid,
        contentDay: today,
        message: _BubbleMessage(
          id: briefPrefsKey,
          text: brief,
          prefsKey: briefPrefsKey,
        ),
      );
    }

    // Rotina (mamada/sono/fralda/consulta/vacina) fica no banner; curva de crescimento fora
    // da faixa entra em [priorityItems] acima. Aqui: campanhas admin + resumos IA + extras.
    final extraAi = await AiBubbleMessagePolicy.buildExtraAiAlerts(
      babyId: bid,
      babyName: widget.babyName,
      babySex: widget.babySex,
      birthDate: widget.birthDate,
      strings: s,
    );
    for (final alert in extraAi) {
      await _addIfEligible(
        items: items,
        prefs: prefs,
        babyId: bid,
        message: _BubbleMessage(
          id: alert.id,
          text: alert.text,
          prefsKey: alert.prefsKey,
        ),
      );
    }

    final weekMonday = _mondayOfWeek(DateTime.now());
    final weekly = await _service.loadThisWeek();
    final weeklyText = weekly?.text.trim() ?? '';
    if (weeklyText.isNotEmpty) {
      await _addIfEligible(
        items: items,
        prefs: prefs,
        babyId: bid,
        contentDay: weekMonday,
        message: _BubbleMessage(
          id: 'weekly',
          text: '${s.homeAiInsightWeeklyTitle}\n\n$weeklyText',
          prefsKey: 'weekly',
        ),
      );
    }

    if (!mounted) return;

    final merged = [...priorityItems, ...items];
    final previousIds = _queue.map((e) => e.id).toSet();
    final incomingIds = merged.map((e) => e.id).toSet().difference(previousIds);
    var alert = _newMessageAlert;
    if (!_isFirstQueueLoad && incomingIds.isNotEmpty && !_expanded) {
      alert = true;
    }
    _isFirstQueueLoad = false;

    setState(() {
      _queue
        ..clear()
        ..addAll(merged);
      if (_index >= _queue.length) _index = 0;
      if (_queue.isEmpty) {
        _expanded = false;
        _dragging = false;
        alert = false;
        _pendingPromoCenter = false;
      }
      _newMessageAlert = alert;
    });
  }

  bool _isPromoMessage(_BubbleMessage item) =>
      item.adminCampaignId != null &&
      (item.imageUrl?.trim().isNotEmpty ?? false);

  Size _bubbleEstimate(Size area, _BubbleMessage item, {required bool expanded}) {
    return AiFloatingMessageBubble.estimatedSize(
      expanded: expanded,
      viewportWidth: area.width,
      viewportHeight: area.height,
      hasAttachmentImage: (item.imageUrl?.trim() ?? '').isNotEmpty,
      hasActionLink: (item.actionUrl?.trim() ?? '').isNotEmpty,
      promoLayout: _isPromoMessage(item),
    );
  }

  void _applyPromoCenter(Size area, _BubbleMessage item) {
    if (!_pendingPromoCenter || !_expanded || !_isPromoMessage(item)) return;
    final est = _bubbleEstimate(area, item, expanded: true);
    final centered = AiFloatingMessageBubble.centeredPromoTopLeft(
      bubbleSize: est,
      viewport: area,
    );
    if (_position != centered) {
      setState(() {
        _position = centered;
        _pendingPromoCenter = false;
      });
    } else {
      _pendingPromoCenter = false;
    }
  }

  Future<void> _persistDismissForItem(_BubbleMessage item) async {
    final bid = widget.babyId;
    if (item.adminCampaignId != null) {
      final id = item.adminCampaignId!;
      await AdminBroadcastInboxService.instance.dismiss(id);
      final msgs = await FloatingMessageService.instance.listActiveMessages(
        forceRefresh: true,
      );
      FloatingMessage? fm;
      for (final m in msgs) {
        if (m.id == id) {
          fm = m;
          break;
        }
      }
      if (fm != null) {
        await FloatingMessageService.instance.dismiss(fm);
      }
    }
    if (item.prefsKey.startsWith('family_homily_ready')) {
      await FamilyHomilyBubbleAlert.dismissForToday();
    } else if (item.prefsKey.startsWith('family_horoscope_ready')) {
      await FamilyHoroscopeBubbleAlert.dismissForToday();
    } else if (bid != null) {
      if (item.prefsKey.startsWith('alert_growth_curve_')) {
        final sig = item.prefsKey.substring('alert_growth_curve_'.length);
        if (sig.isNotEmpty) {
          await GrowthCurveAlertAck.markNotified(
            babyId: bid,
            signature: sig,
          );
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await AiBubbleQueueLifecycle.markDismissed(
        babyId: bid,
        prefsKey: item.prefsKey,
        prefs: prefs,
      );
    }
  }

  Future<void> _dismissCurrent() async {
    if (_queue.isEmpty) return;
    final item = _queue[_index.clamp(0, _queue.length - 1)];
    _suppressPrefsKeysFor(item);
    if (!mounted) return;
    setState(() {
      _snapToCollapsedAnchor(bottomReserve: _dragging ? 0 : 24);
      _expanded = false;
      _dragging = false;
      _newMessageAlert = false;
      _pendingPromoCenter = false;
      _queue.removeAt(_index.clamp(0, _queue.length - 1));
      if (_index >= _queue.length) _index = 0;
    });
    await _persistDismissForItem(item);
  }

  Future<void> _dismissAll() async {
    if (_queue.isEmpty) return;
    final copy = List<_BubbleMessage>.from(_queue);
    for (final item in copy) {
      _suppressPrefsKeysFor(item);
    }
    if (!mounted) return;
    setState(() {
      _expanded = false;
      _dragging = false;
      _newMessageAlert = false;
      _pendingPromoCenter = false;
      _queue.clear();
      _index = 0;
    });
    for (final item in copy) {
      await _persistDismissForItem(item);
    }
  }

  void _syncDay() {
    final day = _dayStamp(DateTime.now());
    if (_prefsDay == day) return;
    _prefsDay = day;
    _index = 0;
    _expanded = false;
    _isFirstQueueLoad = true;
    AiInsightsBootstrap.resetForNewDay();
    unawaited(_safeRebuildQueue());
  }

  @override
  void didUpdateWidget(covariant AiFloatingInsightsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDay();
    if (oldWidget.babyId != widget.babyId ||
        oldWidget.babyName != widget.babyName ||
        oldWidget.birthDate != widget.birthDate) {
      _positionLoaded = false;
      _isFirstQueueLoad = true;
      _newMessageAlert = false;
      unawaited(_safeRebuildQueue());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureAccess.canUseAnyAi) return const SizedBox.shrink();
    _syncDay();
    if (_queue.isEmpty && widget.babyId != null && !_rebuildInFlight) {
      unawaited(_safeRebuildQueue());
    }
    if (_queue.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        _lastViewportSize = area;
        if (!_positionLoaded) {
          unawaited(_loadPosition(area, MediaQuery.paddingOf(context)));
        }

        final msg = _queue[_index.clamp(0, _queue.length - 1)].text;

        final current = _queue[_index.clamp(0, _queue.length - 1)];
        final isPromo = _isPromoMessage(current);
        final promoButtonLabel = current.actionButtonLabel?.trim().isNotEmpty ==
                true
            ? current.actionButtonLabel!.trim()
            : S.of(context).aiBubblePromoKnowMore;

        if (_pendingPromoCenter && _expanded && isPromo) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applyPromoCenter(area, current);
          });
        }

        final horoscopeAction = current.onActionTap;
        final actionLabel = current.actionButtonLabel?.trim().isNotEmpty == true
            ? current.actionButtonLabel!.trim()
            : (horoscopeAction != null
                ? (_isFamilyDailyBubbleKey(current.prefsKey) &&
                        current.prefsKey.startsWith('family_homily_ready')
                    ? S.of(context).aiBubbleHomilyOpenLink
                    : S.of(context).aiBubbleHoroscopeOpenLink)
                : promoButtonLabel);

        final queueLen = _queue.length;
        final navLabel = queueLen > 1 ? '${_index + 1} de $queueLen' : null;

        return AiFloatingMessageBubble(
          message: msg,
          collapsedIcon: current.collapsedIcon,
          attachmentImageUrl: current.imageUrl,
          actionUrl: current.actionUrl,
          actionLinkLabel: actionLabel,
          hasActionButton: current.hasActionButton || isPromo,
          onActionTap: horoscopeAction,
          promoLayout: isPromo,
          position: _bubblePosition(
            area,
            bottomReserve: _dragging ? 0 : 24,
          ),
          expanded: _expanded,
          messageAlert: _newMessageAlert && !_expanded,
          showDismissZone: _dragging,
          dismissHint: S.of(context).aiBubbleDragToClose,
          closeZoneLabel: S.of(context).aiBubbleCloseZone,
          messageIndex: queueLen > 1 ? _index : null,
          messageCount: queueLen > 1 ? queueLen : null,
          navigationLabel: navLabel,
          onPreviousMessage:
              queueLen > 1 ? () => _goToAdjacentMessage(-1) : null,
          onNextMessage: queueLen > 1 ? () => _goToAdjacentMessage(1) : null,
          onToggleExpanded: () {
            final willExpand = !_expanded;
            final bottomReserve = _dragging ? 0.0 : 24.0;
            if (willExpand) {
              _syncAnchoredCollapsedTopLeft(area, bottomReserve: bottomReserve);
              final bid = widget.babyId;
              if (bid != null) {
                unawaited(() async {
                  final prefs = await SharedPreferences.getInstance();
                  await AiBubbleQueueLifecycle.markSeen(
                    babyId: bid,
                    prefsKey: current.prefsKey,
                    prefs: prefs,
                  );
                }());
              }
              setState(() {
                _expanded = true;
                _newMessageAlert = false;
                if (isPromo) _pendingPromoCenter = true;
              });
              final est = _bubbleEstimate(area, current, expanded: true);
              final clamped = isPromo
                  ? AiFloatingMessageBubble.centeredPromoTopLeft(
                      bubbleSize: est,
                      viewport: area,
                    )
                  : AiFloatingMessageBubble.clampTopLeft(
                      topLeft: _position,
                      bubbleSize: est,
                      viewport: area,
                      bottomReserve: bottomReserve,
                    );
              if (clamped != _position) {
                setState(() => _position = clamped);
              }
            } else {
              setState(() {
                _expanded = false;
                _pendingPromoCenter = false;
                _snapToCollapsedAnchor(bottomReserve: bottomReserve);
              });
            }
          },
          onDragStarted: () {
            if (!_dragging) setState(() => _dragging = true);
          },
          onPositionChanged: (next) {
            setState(() {
              if (!_expanded) {
                _position = AiFloatingMessageBubble.clampCollapsedTopLeft(
                  topLeft: next,
                  viewport: area,
                  bottomReserve: _dragging ? 0 : 24,
                );
                _anchoredCollapsedTopLeft = _position;
              } else {
                final est = _bubbleEstimate(area, current, expanded: true);
                _position = AiFloatingMessageBubble.clampTopLeft(
                  topLeft: next,
                  bubbleSize: est,
                  viewport: area,
                  bottomReserve: _dragging ? 0 : 24,
                );
              }
            });
          },
          onPositionClamp: (bubbleSize, viewport) {
            final clamped = AiFloatingMessageBubble.clampTopLeft(
              topLeft: _position,
              bubbleSize: bubbleSize,
              viewport: viewport,
              bottomReserve: _dragging ? 0 : 24,
            );
            if (clamped != _position && mounted) {
              setState(() => _position = clamped);
            }
          },
          onDismissDrag: () {
            setState(() => _dragging = false);
            if (_queue.length > 1) {
              unawaited(_dismissAll());
            } else {
              unawaited(_dismissCurrent());
            }
          },
          onDragEnded: () {
            setState(() => _dragging = false);
            if (!_expanded) {
              _syncAnchoredCollapsedTopLeft(area);
              unawaited(_persistPosition());
            }
          },
          onCloseTap: () => unawaited(_dismissCurrent()),
        );
      },
    );
  }

}
