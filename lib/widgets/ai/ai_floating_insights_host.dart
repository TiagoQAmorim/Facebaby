import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_insight_model.dart';
import '../../controllers/sleep_timer_controller.dart';
import '../../controllers/current_baby_controller.dart';
import '../../models/family_message_prefs.dart';
import '../../pages/family_tree_page.dart';
import '../../services/ai/ai_bubble_message_policy.dart';
import '../../services/ai/ai_bubble_routine_insights.dart';
import '../../services/ai/ai_insight_local_engine.dart';
import '../../services/admin_broadcast_inbox_service.dart';
import '../../services/ai/ai_insights_service.dart';
import '../../services/family_homily_read_prefs.dart';
import '../../services/family_horoscope_read_prefs.dart';
import '../../services/home_prefs.dart';
import '../../utils/family_page_tabs.dart';
import '../../utils/portal_page_route.dart';
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
  });

  final String id;
  final String text;
  final String prefsKey;
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
  bool _positionLoaded = false;
  String _prefsDay = '';
  bool _isFirstQueueLoad = true;
  /// Pulsa o balão quando chega mensagem nova (ainda não aberta).
  bool _newMessageAlert = false;
  bool _pendingPromoCenter = false;

  @override
  void initState() {
    super.initState();
    _prefsDay = _dayStamp(DateTime.now());
    _dailySub = _service.watchTodayDaily().listen((_) {
      if (!mounted) return;
      unawaited(_rebuildQueue());
    });
    _adminInboxSub = AdminBroadcastInboxService.instance.watchActive().listen(
      (items) {
        if (!mounted) return;
        setState(() => _adminInbox = items);
        unawaited(_rebuildQueue());
      },
    );
    SleepTimerController.instance.addListener(_onRoutineChanged);
    HomePrefs.feedingAlertsEnabled.addListener(_onRoutineChanged);
    HomePrefs.sleepAlertsEnabled.addListener(_onRoutineChanged);
    HomePrefs.diaperAlertsEnabled.addListener(_onRoutineChanged);
    HomePrefs.growthHealthAlertsEnabled.addListener(_onRoutineChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted) return;
      unawaited(_rebuildQueue());
    });
    _horoscopeReadyListener = () {
      if (!mounted) return;
      unawaited(_rebuildQueue());
    };
    FamilyHoroscopeReadyNotifier.generation
        .addListener(_horoscopeReadyListener!);
    _homilyReadyListener = () {
      if (!mounted) return;
      unawaited(_rebuildQueue());
    };
    FamilyHomilyReadyNotifier.generation.addListener(_homilyReadyListener!);
    _insightsReadyListener = () {
      if (!mounted) return;
      unawaited(_rebuildQueue());
    };
    AiInsightsReadyNotifier.generation.addListener(_insightsReadyListener!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = S.of(context);
      AiInsightsBootstrap.scheduleIfNeeded(s);
      unawaited(_rebuildQueue());
    });
  }

  void _onRoutineChanged() {
    if (!mounted) return;
    unawaited(_rebuildQueue());
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
    super.dispose();
  }

  String _dayStamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _posKey(int babyId) => 'facebaby_ai_bubble_pos_v1_$babyId';
  static String _dismissKey(String prefsKey, int babyId, String day) =>
      '${prefsKey}_${babyId}_$day';

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
    _positionLoaded = true;
    setState(() {});
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
    final bid = widget.babyId;
    final s = S.of(context);
    final stamp = _dayStamp(DateTime.now());
    final prefs = await SharedPreferences.getInstance();

    final items = <_BubbleMessage>[];

    for (final admin in _adminInbox) {
      final adminKey = 'admin_${admin.campaignId}';
      final dismissed = bid == null
          ? false
          : prefs.getBool(_dismissKey(adminKey, bid, stamp)) ?? false;
      if (dismissed) continue;
      items.add(
        _BubbleMessage(
          id: 'admin_${admin.campaignId}',
          text: admin.text,
          prefsKey: 'admin_${admin.campaignId}',
          imageUrl: admin.imageUrl,
          actionUrl: admin.actionUrl,
          actionButtonLabel: admin.actionButtonLabel,
          adminCampaignId: admin.campaignId,
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

    await _service.ensureInsights(strings: s);

    const briefPrefsKey = AiBubbleRoutineInsights.prefsKey;
    final briefDismissed =
        prefs.getBool(_dismissKey(briefPrefsKey, bid, stamp)) ?? false;
    if (!briefDismissed) {
      final brief = await AiBubbleRoutineInsights.yesterdayAndCuriosity(
        babyId: bid,
        babyName: widget.babyName,
        babySex: widget.babySex,
        birthDate: widget.birthDate,
        strings: s,
      );
      if (brief != null && brief.trim().isNotEmpty) {
        items.add(
          _BubbleMessage(
            id: briefPrefsKey,
            text: brief,
            prefsKey: briefPrefsKey,
          ),
        );
      }
    }

    // Alertas de rotina (mamada/sono/fralda/consulta/vacina) ficam só no banner da Home.
    // No balão: campanhas admin + resumos IA; regras extras em [AiBubbleMessagePolicy].
    final extraAi = await AiBubbleMessagePolicy.buildExtraAiAlerts(
      babyId: bid,
      babyName: widget.babyName,
      babySex: widget.babySex,
      birthDate: widget.birthDate,
      strings: s,
    );
    for (final alert in extraAi) {
      final dismissed =
          prefs.getBool(_dismissKey(alert.prefsKey, bid, stamp)) ?? false;
      if (dismissed) continue;
      items.add(
        _BubbleMessage(
          id: alert.id,
          text: alert.text,
          prefsKey: alert.prefsKey,
        ),
      );
    }

    final familyPrefs = FamilyMessagePrefs.fromMother(
      CurrentBabyController.instance.currentMotherRow,
    );
    final homilyTab = FamilyPageTabs.homily(familyPrefs);
    const homilyPrefsKey = 'family_homily_ready';
    final homilyDismissed =
        prefs.getBool(_dismissKey(homilyPrefsKey, bid, stamp)) ?? false;
    final dailyDismissed =
        prefs.getBool(_dismissKey('daily', bid, stamp)) ?? false;
    if (!dailyDismissed) {
      var daily = await _service.loadTodayDaily();
      var text = daily?.text.trim() ?? '';
      if (text.isEmpty) {
        text = await AiInsightLocalEngine.buildDailySummary(
          babyId: bid,
          babyName: widget.babyName,
          babySex: widget.babySex,
          birthDate: widget.birthDate,
          strings: s,
        );
      }
      if (text.isNotEmpty) {
        items.add(
          _BubbleMessage(
            id: 'daily',
            text: '${s.homeAiInsightDailyTitle}\n\n$text',
            prefsKey: 'daily',
          ),
        );
      }
    }

    final weeklyDismissed =
        prefs.getBool(_dismissKey('weekly', bid, stamp)) ?? false;
    if (!weeklyDismissed) {
      final weekly = await _service.loadThisWeek();
      final text = weekly?.text.trim() ?? '';
      if (text.isNotEmpty) {
        items.add(
          _BubbleMessage(
            id: 'weekly',
            text: '${s.homeAiInsightWeeklyTitle}\n\n$text',
            prefsKey: 'weekly',
          ),
        );
      }
    }

    if (homilyTab != null &&
        !homilyDismissed &&
        await FamilyHomilyBubbleAlert.shouldShowInBubble()) {
      items.add(
        _BubbleMessage(
          id: 'family_homily_ready',
          text: s.aiBubbleHomilyReady,
          prefsKey: homilyPrefsKey,
          actionButtonLabel: s.aiBubbleHomilyOpenLink,
          hasActionButton: true,
          onActionTap: () {
            if (!context.mounted) return;
            pushPortalPage<void>(
              context,
              FamilyTreePage(initialTabIndex: homilyTab),
            );
          },
        ),
      );
    }

    final horoscopeTab = FamilyPageTabs.horoscope(familyPrefs);
    const horoscopePrefsKey = 'family_horoscope_ready';
    final horoscopeDismissed =
        prefs.getBool(_dismissKey(horoscopePrefsKey, bid, stamp)) ?? false;
    if (horoscopeTab != null &&
        !horoscopeDismissed &&
        await FamilyHoroscopeBubbleAlert.shouldShowInBubble()) {
      items.add(
        _BubbleMessage(
          id: 'family_horoscope_ready',
          text: s.aiBubbleHoroscopeReady,
          prefsKey: horoscopePrefsKey,
          actionButtonLabel: s.aiBubbleHoroscopeOpenLink,
          hasActionButton: true,
          onActionTap: () {
            if (!context.mounted) return;
            pushPortalPage<void>(
              context,
              FamilyTreePage(initialTabIndex: horoscopeTab),
            );
          },
        ),
      );
    }

    if (!mounted) return;

    final previousIds = _queue.map((e) => e.id).toSet();
    final incomingIds = items.map((e) => e.id).toSet().difference(previousIds);
    var alert = _newMessageAlert;
    if (!_isFirstQueueLoad && incomingIds.isNotEmpty && !_expanded) {
      alert = true;
    }
    _isFirstQueueLoad = false;

    setState(() {
      _queue
        ..clear()
        ..addAll(items);
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
      item.adminCampaignId != null;

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

  Future<void> _dismissCurrent() async {
    if (_queue.isEmpty) return;
    final bid = widget.babyId;
    final item = _queue[_index];
    if (item.adminCampaignId != null) {
      await AdminBroadcastInboxService.instance.dismiss(item.adminCampaignId!);
    }
    if (item.prefsKey == 'family_homily_ready') {
      await FamilyHomilyBubbleAlert.dismissForToday();
    }
    if (item.prefsKey == 'family_horoscope_ready') {
      await FamilyHoroscopeBubbleAlert.dismissForToday();
    }
    if (bid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        _dismissKey(item.prefsKey, bid, _dayStamp(DateTime.now())),
        true,
      );
    }
    if (!mounted) return;
    setState(() {
      _expanded = false;
      _queue.removeAt(_index);
      if (_index >= _queue.length) _index = 0;
    });
  }

  void _syncDay() {
    final day = _dayStamp(DateTime.now());
    if (_prefsDay == day) return;
    _prefsDay = day;
    _index = 0;
    _expanded = false;
    _isFirstQueueLoad = true;
    AiInsightsBootstrap.resetForNewDay();
    unawaited(_rebuildQueue());
  }

  @override
  void didUpdateWidget(covariant AiFloatingInsightsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDay();
    if (oldWidget.babyId != widget.babyId) {
      _positionLoaded = false;
      _isFirstQueueLoad = true;
      _newMessageAlert = false;
      unawaited(_rebuildQueue());
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncDay();
    if (_queue.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
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
                ? (current.prefsKey == 'family_homily_ready'
                    ? S.of(context).aiBubbleHomilyOpenLink
                    : S.of(context).aiBubbleHoroscopeOpenLink)
                : promoButtonLabel);

        return AiFloatingMessageBubble(
          message: msg,
          attachmentImageUrl: current.imageUrl,
          actionUrl: current.actionUrl,
          actionLinkLabel: actionLabel,
          hasActionButton: current.hasActionButton || isPromo,
          onActionTap: horoscopeAction,
          promoLayout: isPromo,
          position: _position,
          expanded: _expanded,
          messageAlert: _newMessageAlert && !_expanded,
          showDismissZone: _dragging,
          dismissHint: S.of(context).aiBubbleDragToClose,
          closeZoneLabel: S.of(context).aiBubbleCloseZone,
          onToggleExpanded: () {
            final willExpand = !_expanded;
            setState(() {
              _expanded = willExpand;
              if (willExpand) {
                _newMessageAlert = false;
                if (isPromo) _pendingPromoCenter = true;
              }
            });
            if (willExpand) {
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
                      bottomReserve: _dragging
                          ? AiFloatingMessageBubble.dismissStripHeight
                          : 24,
                    );
              if (clamped != _position) {
                setState(() => _position = clamped);
              }
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
                  bottomReserve: _dragging
                      ? AiFloatingMessageBubble.dismissStripHeight
                      : 24,
                );
              } else {
                final est = _bubbleEstimate(area, current, expanded: true);
                _position = AiFloatingMessageBubble.clampTopLeft(
                  topLeft: next,
                  bubbleSize: est,
                  viewport: area,
                  bottomReserve: _dragging
                      ? AiFloatingMessageBubble.dismissStripHeight
                      : 24,
                );
              }
            });
          },
          onPositionClamp: (bubbleSize, viewport) {
            final clamped = AiFloatingMessageBubble.clampTopLeft(
              topLeft: _position,
              bubbleSize: bubbleSize,
              viewport: viewport,
              bottomReserve: _dragging
                  ? AiFloatingMessageBubble.dismissStripHeight
                  : 24,
            );
            if (clamped != _position && mounted) {
              setState(() => _position = clamped);
            }
          },
          onDismissDrag: () {
            setState(() => _dragging = false);
            unawaited(_dismissCurrent());
          },
          onDragEnded: () {
            setState(() => _dragging = false);
            if (!_expanded) {
              unawaited(_persistPosition());
            }
          },
        );
      },
    );
  }

}
