import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_i18n.dart';
import '../models/floating_message_model.dart';
import '../services/floating_message_service.dart';
import '../utils/floating_message_action.dart';
import 'ai/ai_floating_message_bubble.dart';

/// Balão flutuante na Home/portal — uma mensagem por vez (Firestore).
class FloatingMessageHost extends StatefulWidget {
  const FloatingMessageHost({
    super.key,
    required this.babyId,
  });

  final int? babyId;

  @override
  State<FloatingMessageHost> createState() => _FloatingMessageHostState();
}

class _FloatingMessageHostState extends State<FloatingMessageHost> {
  StreamSubscription<FloatingMessage?>? _sub;
  FloatingMessage? _message;
  bool _expanded = false;
  bool _dragging = false;
  Offset _position = const Offset(280, 420);
  bool _positionLoaded = false;
  bool _newAlert = false;
  bool _pendingPromoCenter = false;
  bool _seenMarked = false;

  static String _posKey(int babyId) => 'facebaby_floating_msg_pos_v1_$babyId';

  @override
  void initState() {
    super.initState();
    _sub = FloatingMessageService.instance.watchBestMessage().listen((msg) {
      if (!mounted) return;
      final wasEmpty = _message == null;
      setState(() {
        _message = msg;
        if (msg != null && wasEmpty && !_expanded) _newAlert = true;
        if (msg == null) {
          _expanded = false;
          _dragging = false;
          _newAlert = false;
          _seenMarked = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FloatingMessageHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.babyId != widget.babyId) {
      _positionLoaded = false;
      _seenMarked = false;
      unawaited(FloatingMessageService.instance.pickBestMessage(forceRefresh: true));
    }
  }

  Future<void> _loadPosition(Size area) async {
    final bid = widget.babyId;
    if (bid == null) {
      _position = Offset(area.width - 72, area.height * 0.58);
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
        bottomReserve: 88,
      );
    } else {
      _position = AiFloatingMessageBubble.clampTopLeft(
        topLeft: Offset(area.width - collapsed - 16, area.height * 0.52),
        bubbleSize: const Size(collapsed, collapsed),
        viewport: area,
        bottomReserve: 88,
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

  Future<void> _dismiss() async {
    final msg = _message;
    if (msg == null) return;
    await FloatingMessageService.instance.dismiss(msg);
    if (!mounted) return;
    setState(() {
      _expanded = false;
      _dragging = false;
      _message = null;
      _newAlert = false;
    });
  }

  void _showActionError() {
    if (!mounted) return;
    final s = S.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.floatingMessageLinkOpenFailed)),
    );
  }

  Future<void> _openAction(FloatingMessage msg) async {
    await FloatingMessageService.instance.onActionTapped(msg);

    final url = msg.effectiveActionUrl;
    if (url != null) {
      final ok = await FloatingMessageAction.openExternalUrl(url);
      if (!ok) _showActionError();
      return;
    }

    final route = msg.effectiveActionRoute;
    if (route != null && route.startsWith('/')) {
      if (!mounted) return;
      Navigator.of(context).pushNamed(route);
    }
  }

  void _markSeenOnce(FloatingMessage msg) {
    if (_seenMarked) return;
    _seenMarked = true;
    unawaited(FloatingMessageService.instance.onMessageShown(msg));
  }

  @override
  Widget build(BuildContext context) {
    final msg = _message;
    if (msg == null || !msg.hasRenderableContent) {
      return const SizedBox.shrink();
    }

    final s = S.of(context);
    final title = msg.title.trim().isNotEmpty
        ? msg.title.trim()
        : _defaultTitle(msg.type, s);
    final body = msg.message.trim();

    if (_expanded) _markSeenOnce(msg);

    final allowsDrag = msg.dismissMode.allowsDragDismiss;
    final allowsClose = msg.dismissMode.allowsCloseButton;
    final isBanner = msg.isBannerLayout;
    final isPromo = msg.isPromoLayout && !isBanner;
    final hasCta = msg.hasActionButton;
    final ctaLabel = hasCta ? msg.actionLabel!.trim() : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_positionLoaded) unawaited(_loadPosition(area));

        final bottomDragReserve = allowsDrag && _dragging
            ? AiFloatingMessageBubble.dismissStripHeight
            : 88.0;

        if (_pendingPromoCenter && _expanded && (isPromo || isBanner)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final est = AiFloatingMessageBubble.estimatedSize(
              expanded: true,
              viewportWidth: area.width,
              viewportHeight: area.height,
              hasAttachmentImage: (msg.imageUrl ?? '').isNotEmpty,
              hasActionLink: hasCta,
              promoLayout: isPromo,
              bannerLayout: isBanner,
              imageAspectRatio: msg.imageAspectRatio,
            );
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
          });
        }

        return AiFloatingMessageBubble(
          title: title,
          message: body,
          collapsedIcon: msg.displayIcon,
          attachmentImageUrl: msg.imageUrl,
          imageAlt: msg.imageAlt,
          imageAspectRatio: msg.imageAspectRatio,
          actionUrl: msg.effectiveActionUrl,
          actionLinkLabel: ctaLabel,
          hasActionButton: hasCta,
          promoLayout: isPromo,
          bannerLayout: isBanner,
          showCloseButton: allowsClose,
          allowDragDismiss: allowsDrag,
          position: _position,
          expanded: _expanded,
          messageAlert: _newAlert && !_expanded,
          showDismissZone: allowsDrag && _dragging,
          dismissHint: s.aiBubbleDragToClose,
          closeZoneLabel: s.floatingMessageDropToClose,
          onToggleExpanded: () {
            final willExpand = !_expanded;
            setState(() {
              _expanded = willExpand;
              if (willExpand) {
                _newAlert = false;
                if (isPromo || isBanner) _pendingPromoCenter = true;
              }
            });
            if (willExpand) _markSeenOnce(msg);
          },
          onDragStarted: () {
            if (allowsDrag && !_dragging) setState(() => _dragging = true);
          },
          onPositionChanged: (next) {
            final est = AiFloatingMessageBubble.estimatedSize(
              expanded: _expanded,
              viewportWidth: area.width,
              viewportHeight: area.height,
              hasAttachmentImage: (msg.imageUrl ?? '').isNotEmpty,
              hasActionLink: hasCta,
              promoLayout: isPromo,
              bannerLayout: isBanner,
              imageAspectRatio: msg.imageAspectRatio,
            );
            setState(() {
              _position = AiFloatingMessageBubble.clampTopLeft(
                topLeft: next,
                bubbleSize: est,
                viewport: area,
                bottomReserve: bottomDragReserve,
              );
            });
          },
          onPositionClamp: (bubbleSize, viewport) {
            final clamped = AiFloatingMessageBubble.clampTopLeft(
              topLeft: _position,
              bubbleSize: bubbleSize,
              viewport: viewport,
              bottomReserve: bottomDragReserve,
            );
            if (clamped != _position && mounted) {
              setState(() => _position = clamped);
            }
          },
          onDismissDrag: () {
            setState(() => _dragging = false);
            unawaited(_dismiss());
          },
          onDragEnded: () {
            setState(() => _dragging = false);
            unawaited(_savePosition(area));
          },
          onCloseTap: allowsClose ? () => unawaited(_dismiss()) : null,
          onActionTap: hasCta ? () => unawaited(_openAction(msg)) : null,
        );
      },
    );
  }

  String _defaultTitle(FloatingMessageType type, S s) {
    return switch (type) {
      FloatingMessageType.adminAd => 'FaceBaby',
      FloatingMessageType.adminNotice => 'Novidade',
      FloatingMessageType.promoBanner => 'FaceBaby',
      FloatingMessageType.aiTip => 'Dica da IA',
      FloatingMessageType.aiSummary => 'Resumo da IA',
      FloatingMessageType.aiAlert => 'IA Babá',
      FloatingMessageType.premiumOffer => s.settingsPlusCardTitle,
    };
  }
}
