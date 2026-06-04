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
  StreamSubscription<List<FloatingMessage>>? _listSub;
  FloatingMessage? _message;
  List<FloatingMessage> _messages = const [];
  int _index = 0;
  bool _expanded = false;
  bool _dragging = false;
  Offset _position = const Offset(280, 420);
  Offset? _anchoredCollapsedTopLeft;
  Size? _lastViewportSize;
  bool _positionLoaded = false;
  bool _newAlert = false;
  bool _seenMarked = false;

  /// Reserva inferior para o balão minimizado não cobrir o footer.
  static double bottomNavReserve(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 72;

  static String _positionPrefsKey(int? babyId) =>
      'facebaby_floating_msg_bubble_pos_v2_${babyId ?? 0}';

  @override
  void initState() {
    super.initState();
    _anchoredCollapsedTopLeft = _position;
    // Lista ativa é a fonte de verdade — evita sumir ao expandir (watchBestMessage
    // podia emitir null transitório e limpar _message).
    _listSub =
        FloatingMessageService.instance.watchActiveMessageList().listen((list) {
      _applyList(list);
    });
    unawaited(_bootstrapMessages());
  }

  FloatingMessage? get _currentMessage {
    if (_messages.isNotEmpty) {
      final i = _index.clamp(0, _messages.length - 1);
      return _messages[i];
    }
    return _message;
  }

  void _applyList(List<FloatingMessage> list) {
    if (!mounted) return;
    final prevId = _currentMessage?.id;
    setState(() {
      _messages = list;
      if (_messages.isEmpty) {
        _index = 0;
        _message = null;
        _expanded = false;
        _dragging = false;
        _newAlert = false;
        _seenMarked = false;
        return;
      }

      final idx = prevId == null
          ? _index.clamp(0, _messages.length - 1)
          : _messages.indexWhere((m) => m.id == prevId);
      _index = idx >= 0 ? idx : 0;
      _message = _messages[_index];

      final idChanged = prevId != null && prevId != _message!.id;
      if (idChanged) {
        _seenMarked = false;
        _expanded = false;
        _dragging = false;
        _newAlert = true;
        _position = AiFloatingMessageBubble.snapToCollapsedAnchor(
          anchor: _anchoredCollapsedTopLeft,
          fallback: _position,
          viewport: _lastViewportSize,
        );
      } else if (prevId == null && !_expanded) {
        _newAlert = true;
      }
    });
  }

  Future<void> _bootstrapMessages() async {
    final list = await FloatingMessageService.instance.listActiveMessages(
      forceRefresh: true,
    );
    if (!mounted) return;
    _applyList(list);
  }

  @override
  void dispose() {
    _listSub?.cancel();
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

  Future<void> _loadPosition(Size area, EdgeInsets safePadding) async {
    var pos = AiFloatingMessageBubble.defaultCollapsedTopLeft(
      viewport: area,
      safePadding: safePadding,
    );
    final prefs = await SharedPreferences.getInstance();
    final key = _positionPrefsKey(widget.babyId);
    final dx = prefs.getDouble('${key}_dx');
    final dy = prefs.getDouble('${key}_dy');
    if (dx != null && dy != null) {
      pos = AiFloatingMessageBubble.clampCollapsedTopLeft(
        topLeft: Offset(dx, dy),
        viewport: area,
        bottomReserve: 24,
      );
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

  /// Expandido usa `_position`; minimizado usa sempre o anchor guardado.
  Offset _bubblePosition(Size area, {required double bottomReserve}) {
    if (_expanded) return _position;
    return AiFloatingMessageBubble.snapToCollapsedAnchor(
      anchor: _anchoredCollapsedTopLeft,
      fallback: _position,
      viewport: area,
      bottomReserve: bottomReserve,
    );
  }

  Future<void> _persistPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _positionPrefsKey(widget.babyId);
    await prefs.setDouble('${key}_dx', _position.dx);
    await prefs.setDouble('${key}_dy', _position.dy);
  }

  Future<void> _dismiss() async {
    final msg = _currentMessage;
    if (msg == null) return;
    _markSeenOnce(msg);
    if (mounted) {
      setState(() {
        _snapToCollapsedAnchor(
          bottomReserve: _dragging ? 0 : 24,
        );
        _expanded = false;
        _dragging = false;
        _newAlert = false;
      });
    }
    await FloatingMessageService.instance.dismiss(msg);
  }

  Future<void> _dismissAllActive() async {
    if (_messages.isEmpty) return;
    for (final m in _messages) {
      _markSeenOnce(m);
    }
    await FloatingMessageService.instance.dismissAll(_messages);
    if (!mounted) return;
    setState(() {
      _expanded = false;
      _dragging = false;
      _newAlert = false;
      _index = 0;
      _message = null;
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
    _markSeenOnce(msg);
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
    final msg = _currentMessage;
    if (msg == null || !msg.hasRenderableContent) {
      return const SizedBox.shrink();
    }

    final s = S.of(context);
    final title = msg.title.trim().isNotEmpty
        ? msg.title.trim()
        : _defaultTitle(msg.type, s);
    final body = msg.message.trim();

    final allowsDrag = msg.dismissMode.allowsDragDismiss;
    final allowsClose = msg.dismissMode.allowsCloseButton;
    final hasImage = (msg.imageUrl ?? '').trim().isNotEmpty;
    final isBanner = msg.isBannerLayout;
    // Qualquer aviso admin com imagem usa card grande ao expandir.
    final isPromo =
        (msg.isPromoLayout || (hasImage && msg.type.isAdmin)) && !isBanner;
    final hasCta = msg.hasActionButton;
    final ctaLabel = hasCta ? msg.actionLabel!.trim() : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        _lastViewportSize = area;
        final safe = MediaQuery.paddingOf(context);
        if (!_positionLoaded) unawaited(_loadPosition(area, safe));

        // Com arraste ativo, o balão pode entrar na faixa vermelha (fim da área útil).
        final bottomDragReserve = allowsDrag && _dragging ? 0.0 : 24.0;

        final bubble = AiFloatingMessageBubble(
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
          position: _bubblePosition(area, bottomReserve: bottomDragReserve),
          expanded: _expanded,
          messageAlert: _newAlert && !_expanded,
          showDismissZone: allowsDrag && _dragging,
          dismissHint: s.aiBubbleDragToClose,
          closeZoneLabel: _messages.length > 1
              ? s.floatingMessageDropToCloseAll
              : s.floatingMessageDropToClose,
          messageIndex: _messages.isEmpty ? null : _index,
          messageCount: _messages.isEmpty ? null : _messages.length,
          navigationLabel: _messages.isEmpty
              ? null
              : '${_index + 1} de ${_messages.length}',
          onPreviousMessage: _messages.length <= 1
              ? null
              : () {
                  setState(() {
                    _snapToCollapsedAnchor();
                    _index = (_index - 1) < 0 ? _messages.length - 1 : _index - 1;
                    _message = _messages[_index];
                    _newAlert = false;
                  });
                  _markSeenOnce(_message!);
                },
          onNextMessage: _messages.length <= 1
              ? null
              : () {
                  setState(() {
                    _snapToCollapsedAnchor();
                    _index = (_index + 1) % _messages.length;
                    _message = _messages[_index];
                    _newAlert = false;
                  });
                  _markSeenOnce(_message!);
                },
          onToggleExpanded: () {
            final willExpand = !_expanded;
            final bottomReserve =
                allowsDrag && _dragging ? 0.0 : bottomDragReserve;
            if (willExpand) {
              _syncAnchoredCollapsedTopLeft(
                area,
                bottomReserve: bottomReserve,
              );
            }
            setState(() {
              _expanded = willExpand;
              if (willExpand) {
                _newAlert = false;
                _dragging = false;
              } else {
                _snapToCollapsedAnchor(bottomReserve: bottomDragReserve);
              }
            });
            if (willExpand) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _markSeenOnce(msg);
              });
            }
          },
          onDragStarted: () {
            if (allowsDrag && !_dragging) setState(() => _dragging = true);
          },
          onPositionChanged: (next) {
            setState(() {
              if (!_expanded) {
                _position = AiFloatingMessageBubble.clampCollapsedTopLeft(
                  topLeft: next,
                  viewport: area,
                  bottomReserve: bottomDragReserve,
                );
                _anchoredCollapsedTopLeft = _position;
              } else {
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
                _position = AiFloatingMessageBubble.clampTopLeft(
                  topLeft: next,
                  bubbleSize: est,
                  viewport: area,
                  bottomReserve: bottomDragReserve,
                );
              }
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
            if (_messages.length > 1) {
              unawaited(_dismissAllActive());
            } else {
              unawaited(_dismiss());
            }
          },
          onDragEnded: () {
            setState(() => _dragging = false);
            if (!_expanded) {
              _syncAnchoredCollapsedTopLeft(area, bottomReserve: bottomDragReserve);
              unawaited(_persistPosition());
            }
          },
          onCloseTap: allowsClose ? () => unawaited(_dismiss()) : null,
          onActionTap: hasCta ? () => unawaited(_openAction(msg)) : null,
        );

        if (_expanded) {
          return bubble;
        }

        return Padding(
          padding: EdgeInsets.only(bottom: bottomNavReserve(context)),
          child: bubble,
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
