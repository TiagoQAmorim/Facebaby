import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_insight_model.dart';
import '../../controllers/sleep_timer_controller.dart';
import '../../services/ai/ai_bubble_message_policy.dart';
import '../../services/ai/ai_insight_local_engine.dart';
import '../../services/admin_broadcast_inbox_service.dart';
import '../../services/ai/ai_insights_service.dart';
import '../../services/home_prefs.dart';
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
  });

  final String id;
  final String text;
  final String prefsKey;
  final String? imageUrl;
  final String? actionUrl;
  final String? actionButtonLabel;
  /// Quando preenchido, dismiss grava em Firestore (mensagem do admin).
  final String? adminCampaignId;
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
    super.dispose();
  }

  String _dayStamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _posKey(int babyId) => 'facebaby_ai_bubble_pos_v1_$babyId';
  static String _dismissKey(String prefsKey, int babyId, String day) =>
      '${prefsKey}_${babyId}_$day';

  Future<void> _loadPosition(Size area) async {
    final bid = widget.babyId;
    if (bid == null) {
      _position = Offset(area.width - 72, area.height * 0.62);
      _positionLoaded = true;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final fx = prefs.getDouble('${_posKey(bid)}_fx');
    final fy = prefs.getDouble('${_posKey(bid)}_fy');
    const collapsed = AiFloatingMessageBubble.collapsedSize;
    if (fx != null && fy != null) {
      _position = AiFloatingMessageBubble.clampTopLeft(
        topLeft: Offset(fx * area.width, fy * area.height),
        bubbleSize: const Size(collapsed, collapsed),
        viewport: area,
        bottomReserve: 24,
      );
    } else {
      _position = AiFloatingMessageBubble.clampTopLeft(
        topLeft: Offset(area.width - collapsed - 16, area.height * 0.52),
        bubbleSize: const Size(collapsed, collapsed),
        viewport: area,
        bottomReserve: 24,
      );
    }
    _positionLoaded = true;
    if (mounted) setState(() {});
  }

  Future<void> _savePosition(Size area) async {
    final bid = widget.babyId;
    if (bid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_posKey(bid)}_fx', _position.dx / area.width);
    await prefs.setDouble('${_posKey(bid)}_fy', _position.dy / area.height);
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
            text: text,
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
        items.add(_BubbleMessage(id: 'weekly', text: text, prefsKey: 'weekly'));
      }
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
          unawaited(_loadPosition(area));
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

        return AiFloatingMessageBubble(
          message: msg,
          attachmentImageUrl: current.imageUrl,
          actionUrl: current.actionUrl,
          actionLinkLabel: promoButtonLabel,
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
            final est = _bubbleEstimate(area, current, expanded: _expanded);
            final clamped = AiFloatingMessageBubble.clampTopLeft(
              topLeft: next,
              bubbleSize: est,
              viewport: area,
              bottomReserve: _dragging
                  ? AiFloatingMessageBubble.dismissStripHeight
                  : 24,
            );
            setState(() => _position = clamped);
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
            unawaited(_savePosition(area));
          },
        );
      },
    );
  }

}
