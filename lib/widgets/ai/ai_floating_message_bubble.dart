import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import '../../utils/floating_message_action.dart';
import '../../utils/portal_layout.dart';

/// Bolinha flutuante estilo balão de chat: arrastar, toque para expandir.
class AiFloatingMessageBubble extends StatefulWidget {
  const AiFloatingMessageBubble({
    super.key,
    this.title,
    required this.message,
    this.collapsedIcon,
    required this.position,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onPositionChanged,
    required this.onDismissDrag,
    required this.onDragEnded,
    this.onDragStarted,
    required this.showDismissZone,
    this.dismissHint,
    this.closeZoneLabel,
    this.attachmentImageUrl,
    this.actionUrl,
    this.actionLinkLabel,
    this.promoLayout = false,
    this.bannerLayout = false,
    this.hasActionButton = false,
    this.showCloseButton = true,
    this.allowDragDismiss = true,
    this.imageAlt,
    this.imageAspectRatio,
    this.onPositionClamp,
    this.messageAlert = false,
    this.onActionTap,
    this.onCloseTap,
    this.messageIndex,
    this.messageCount,
    this.onPreviousMessage,
    this.onNextMessage,
    this.navigationLabel,
  });

  final String? title;
  final String message;
  /// Emoji no modo minimizado (ex.: 🤖 📣 ❤️).
  final String? collapsedIcon;
  /// Imagem anexa (ex.: broadcast do admin) — exibida em destaque, não no avatar.
  final String? attachmentImageUrl;
  /// URL aberta no navegador externo ao tocar no botão.
  final String? actionUrl;
  final String? actionLinkLabel;
  /// Layout estilo propaganda (imagem grande + botão) para mensagens do admin.
  final bool promoLayout;
  /// Layout `promo_banner`: título, banner, texto opcional, CTA, X.
  final bool bannerLayout;
  final bool hasActionButton;
  final bool showCloseButton;
  final bool allowDragDismiss;
  final String? imageAlt;
  final double? imageAspectRatio;
  final Offset position;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Offset> onPositionChanged;
  final VoidCallback onDismissDrag;
  final VoidCallback onDragEnded;
  /// Chamado na primeira movimentação real do arraste (mostra zona FECHAR).
  final VoidCallback? onDragStarted;
  final bool showDismissZone;
  final String? dismissHint;
  final String? closeZoneLabel;
  /// Chamado quando o tamanho do balão muda (expandir) para reajustar posição.
  final void Function(Size bubbleSize, Size viewport)? onPositionClamp;
  /// Pulso visual quando há mensagem nova não lida.
  final bool messageAlert;
  final VoidCallback? onActionTap;
  final VoidCallback? onCloseTap;
  /// Índice da mensagem atual (0-based) para navegação multi-mensagem.
  final int? messageIndex;
  final int? messageCount;
  final VoidCallback? onPreviousMessage;
  final VoidCallback? onNextMessage;
  final String? navigationLabel;

  /// Diâmetro visual do orb minimizado.
  static const double collapsedSize = 56;

  /// Margem externa para badge, pulso e sombra (evita corte no layout).
  static const double collapsedVisualPadding = 10;

  /// Área total ocupada no Stack (clamp, arraste, hit test).
  static double get collapsedLayoutSize =>
      collapsedSize + collapsedVisualPadding * 2;
  static const double dismissZoneHeight = 96;
  static const double expandedMaxWidth = 300;
  static const double expandedMaxHeight = 168;
  static const double promoMinWidth = 300;
  static const double promoImageMinHeight = 180;
  static const double promoImageMaxHeight = 260;
  static const double promoImageHeightFraction = 0.36;
  static const double promoImageWidthFraction = 0.90;
  static const double promoActionButtonHeight = 48;
  static const double attachmentImageHeight = 180;
  static const double actionLinkRowHeight = 36;
  static const double edgePadding = 12;
  /// Margem horizontal mínima do orb minimizado (arraste em toda a largura).
  static const double collapsedHorizontalInset = 8;
  static const double dismissStripHeight = 96;
  static const double dismissStripMaxHeight = 100;
  static const double dismissStripWidthFraction = 0.88;
  static const double dismissStripBottomGap = 16;
  // (removido) _avatarAsset: não usado após redesign do minimizado.

  /// Topo da faixa vermelha (coordenadas do viewport do balão).
  static double dismissStripTop(Size viewport) =>
      viewport.height -
      dismissStripBottomGap -
      dismissStripHeight;

  /// O balão entrou na faixa de soltar para fechar.
  static bool isInDismissStrip({
    required Offset topLeft,
    required Size bubbleSize,
    required Size viewport,
    double overlapPx = 10,
  }) {
    return topLeft.dy + bubbleSize.height >
        dismissStripTop(viewport) + overlapPx;
  }

  /// Posição fixa do ícone minimizado — canto superior-direito do card do bebê.
  /// Fallback: `right: 28`, `top: 330` (nunca sobre saudação/header).
  static const double defaultRightInset = 28;
  static const double defaultTop = 330;

  /// Escurecimento do fundo com banner aberto (60%).
  static const double expandedScrimOpacity = 0.60;

  static Offset defaultCollapsedTopLeft({
    required Size viewport,
    EdgeInsets safePadding = EdgeInsets.zero,
    double rightInset = defaultRightInset,
    double topFallback = defaultTop,
    double bottomReserve = 24,
  }) {
    final layout = collapsedLayoutSize;
    final maxTop = viewport.height -
        layout -
        bottomReserve -
        edgePadding;
    final top = (topFallback + safePadding.top).clamp(
      safePadding.top + edgePadding,
      maxTop,
    );
    final left = viewport.width -
        layout -
        rightInset -
        safePadding.right;
    return Offset(left, top);
  }

  /// Mantém o orb minimizado dentro da área útil (safe horizontal 8px).
  static Offset clampCollapsedTopLeft({
    required Offset topLeft,
    required Size viewport,
    double bottomReserve = 24,
    double horizontalInset = collapsedHorizontalInset,
  }) {
    final layout = collapsedLayoutSize;
    final minX = horizontalInset;
    final maxX = (viewport.width - layout - horizontalInset)
        .clamp(horizontalInset, viewport.width);
    final maxY = viewport.height - layout - bottomReserve - edgePadding;
    return Offset(
      topLeft.dx.clamp(minX, maxX),
      topLeft.dy.clamp(edgePadding, maxY),
    );
  }

  /// O orb entrou na faixa de soltar para fechar (usa a base do círculo).
  static bool isDroppedInDismissZone({
    required Offset topLeft,
    required Size viewport,
    double bubbleSize = collapsedSize,
    double overlapPx = 8,
  }) {
    return isInDismissStrip(
      topLeft: topLeft,
      bubbleSize: Size(bubbleSize, bubbleSize),
      viewport: viewport,
      overlapPx: overlapPx,
    );
  }

  /// Mantém o canto superior-esquerdo do balão dentro da área útil.
  static Offset clampTopLeft({
    required Offset topLeft,
    required Size bubbleSize,
    required Size viewport,
    double padding = edgePadding,
    double bottomReserve = 24,
  }) {
    final maxX = (viewport.width - bubbleSize.width - padding)
        .clamp(padding, viewport.width - padding);
    final maxY = (viewport.height - bubbleSize.height - bottomReserve - padding)
        .clamp(padding, viewport.height - padding);
    return Offset(
      topLeft.dx.clamp(padding, maxX),
      topLeft.dy.clamp(padding, maxY),
    );
  }

  static Size estimatedSize({
    required bool expanded,
    required double viewportWidth,
    double viewportHeight = 640,
    bool hasAttachmentImage = false,
    bool hasActionLink = false,
    bool promoLayout = false,
    bool bannerLayout = false,
    double? imageAspectRatio,
  }) {
    if (!expanded) {
      return Size(collapsedLayoutSize, collapsedLayoutSize);
    }
    if (bannerLayout || promoLayout) {
      final w = (viewportWidth - 16).clamp(200.0, viewportWidth - 16);
      double imgH = 0;
      if (hasAttachmentImage) {
        if (imageAspectRatio != null && imageAspectRatio > 0.2) {
          imgH = (w / imageAspectRatio).clamp(120.0, promoImageMaxHeight);
        } else {
          imgH = (viewportHeight * promoImageHeightFraction)
              .clamp(promoImageMinHeight, promoImageMaxHeight);
        }
      }
      final titleH = bannerLayout ? 44.0 : 0.0;
      const textBlock = 56.0;
      final btnH = hasActionLink ? promoActionButtonHeight + 12 : 0.0;
      final pad = bannerLayout ? 24.0 : 20.0;
      final rawH = titleH + imgH + textBlock + btnH + pad;
      final maxH = viewportHeight * 0.82;
      return Size(w, rawH.clamp(120.0, maxH));
    }
    final w = (viewportWidth - edgePadding * 2).clamp(200.0, expandedMaxWidth);
    var h = expandedMaxHeight;
    if (hasAttachmentImage) h += attachmentImageHeight + 8;
    if (hasActionLink) h += actionLinkRowHeight;
    return Size(w, h);
  }

  /// Posição central-superior para cartão de propaganda expandido.
  static Offset centeredPromoTopLeft({
    required Size bubbleSize,
    required Size viewport,
    double padding = edgePadding,
    double verticalBias = 0.22,
  }) {
    final x = (viewport.width - bubbleSize.width) / 2;
    final y = (viewport.height - bubbleSize.height) * verticalBias;
    return clampTopLeft(
      topLeft: Offset(x, y),
      bubbleSize: bubbleSize,
      viewport: viewport,
      padding: padding,
      bottomReserve: 24,
    );
  }

  @override
  State<AiFloatingMessageBubble> createState() =>
      _AiFloatingMessageBubbleState();
}

class _AiFloatingMessageBubbleState extends State<AiFloatingMessageBubble>
    with TickerProviderStateMixin {
  Offset? _dragOrigin;
  Offset? _pointerStart;
  Offset? _lastDragTopLeft;
  bool _moved = false;
  bool _nearDismissZone = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandCurve;
  late final AnimationController _alertCtrl;
  late final Animation<double> _alertPulse;
  late final AnimationController _dismissStripCtrl;
  late final Animation<double> _dismissStripFade;
  late final Animation<Offset> _dismissStripSlide;
  final GlobalKey _bubbleKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: widget.expanded ? 1.0 : 0.0,
    );
    _expandCurve = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _alertCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _alertPulse = CurvedAnimation(parent: _alertCtrl, curve: Curves.easeInOut);
    _dismissStripCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _dismissStripFade = CurvedAnimation(
      parent: _dismissStripCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _dismissStripSlide = Tween<Offset>(
      begin: const Offset(0, 0.42),
      end: Offset.zero,
    ).animate(_dismissStripFade);
    if (widget.showDismissZone) {
      _dismissStripCtrl.value = 1.0;
    }
    _syncAlertAnimation();
  }

  void _syncDismissStripAnimation() {
    final show = widget.allowDragDismiss && widget.showDismissZone;
    if (show) {
      if (_dismissStripCtrl.status != AnimationStatus.forward &&
          _dismissStripCtrl.value < 1.0) {
        unawaited(_dismissStripCtrl.forward());
      }
    } else if (_dismissStripCtrl.value > 0) {
      unawaited(_dismissStripCtrl.reverse());
    }
  }

  void _syncAlertAnimation() {
    final on = widget.messageAlert && !widget.expanded;
    if (on) {
      if (!_alertCtrl.isAnimating) {
        _alertCtrl.repeat(reverse: true);
      }
    } else {
      _alertCtrl.stop();
      _alertCtrl.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant AiFloatingMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      if (widget.expanded) {
        _expandCtrl.forward();
        WidgetsBinding.instance.addPostFrameCallback((_) => _clampAfterLayout());
      } else {
        _expandCtrl.reverse();
      }
    }
    if (oldWidget.messageAlert != widget.messageAlert ||
        oldWidget.expanded != widget.expanded) {
      _syncAlertAnimation();
    }
    if (oldWidget.showDismissZone != widget.showDismissZone) {
      _syncDismissStripAnimation();
    }
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _alertCtrl.dispose();
    _dismissStripCtrl.dispose();
    super.dispose();
  }

  bool get _isDragActive =>
      widget.allowDragDismiss && widget.showDismissZone;

  void _clampAfterLayout() {
    final box = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    final area = _viewportSize();
    if (box == null || !box.hasSize || area == null) return;
    final size = box.size;
    widget.onPositionClamp?.call(size, area);
  }

  Size? _viewportSize() {
    final ctx = context.findRenderObject();
    if (ctx is RenderBox && ctx.hasSize) {
      return ctx.size;
    }
    return null;
  }

  Size _currentBubbleSize(Size viewport) {
    if (_isDragActive) {
      return Size(
        AiFloatingMessageBubble.collapsedLayoutSize,
        AiFloatingMessageBubble.collapsedLayoutSize,
      );
    }
    final box = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) return box.size;
    return AiFloatingMessageBubble.estimatedSize(
      expanded: widget.expanded,
      viewportWidth: viewport.width,
      viewportHeight: viewport.height,
      hasAttachmentImage:
          (widget.attachmentImageUrl?.trim() ?? '').isNotEmpty,
      hasActionLink: widget.hasActionButton,
      promoLayout: widget.promoLayout || widget.bannerLayout,
      bannerLayout: widget.bannerLayout,
      imageAspectRatio: widget.imageAspectRatio,
    );
  }

  bool _hapticDismissFired = false;

  void _onPanStart(DragStartDetails d) {
    if (widget.expanded) return;
    _dragOrigin = widget.position;
    _pointerStart = d.globalPosition;
    _lastDragTopLeft = widget.position;
    _moved = false;
    _hapticDismissFired = false;
    setState(() => _nearDismissZone = false);
  }

  void _onPanUpdate(DragUpdateDetails d, Size area) {
    if (widget.expanded) return;
    final start = _dragOrigin;
    final ptr = _pointerStart;
    if (start == null || ptr == null) return;
    final delta = d.globalPosition - ptr;
    if (delta.distance > 6 && !_moved) {
      _moved = true;
      if (widget.allowDragDismiss) {
        widget.onDragStarted?.call();
      }
    }
    final bubble = _currentBubbleSize(area);
    final raw = Offset(start.dx + delta.dx, start.dy + delta.dy);
    final draggingDismiss =
        widget.allowDragDismiss && widget.showDismissZone;
    final next = (!widget.expanded &&
            bubble.width <= AiFloatingMessageBubble.collapsedLayoutSize + 1)
        ? AiFloatingMessageBubble.clampCollapsedTopLeft(
            topLeft: raw,
            viewport: area,
            bottomReserve: draggingDismiss ? 0 : 24,
          )
        : AiFloatingMessageBubble.clampTopLeft(
            topLeft: raw,
            bubbleSize: bubble,
            viewport: area,
            bottomReserve: draggingDismiss ? 0 : 24,
          );
    final near = widget.allowDragDismiss &&
        AiFloatingMessageBubble.isInDismissStrip(
          topLeft: next,
          bubbleSize: bubble,
          viewport: area,
        );
    if (near != _nearDismissZone) {
      if (near && !_hapticDismissFired) {
        _hapticDismissFired = true;
        HapticFeedback.mediumImpact();
      }
      setState(() => _nearDismissZone = near);
    }
    _lastDragTopLeft = next;
    widget.onPositionChanged(next);
  }

  void _onPanEnd(DragEndDetails d, Size area) {
    if (widget.expanded) return;
    if (!_moved) {
      // Toque curto: [onTap] abre/fecha; não alternar aqui para evitar duplo toggle.
      _dragOrigin = null;
      _pointerStart = null;
      _lastDragTopLeft = null;
      setState(() => _nearDismissZone = false);
      return;
    }
    final releasePos = _lastDragTopLeft ?? widget.position;
    final droppedInDismissZone = widget.allowDragDismiss &&
        AiFloatingMessageBubble.isDroppedInDismissZone(
          topLeft: releasePos,
          viewport: area,
        );
    // Fecha ao soltar na faixa vermelha — não exige showDismissZone no frame final.
    if (droppedInDismissZone) {
      widget.onDismissDrag();
    } else {
      widget.onDragEnded();
    }
    _dragOrigin = null;
    _pointerStart = null;
    _lastDragTopLeft = null;
    _moved = false;
    setState(() => _nearDismissZone = false);
  }

  static List<BoxShadow> _orbShadows({bool dismissHot = false}) => [
        if (dismissHot)
          BoxShadow(
            color: const Color(0xFFE53935).withAlpha(150),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        BoxShadow(
          color: const Color(0xFFE91E8C).withAlpha(90),
          blurRadius: 16,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: const Color(0xFF9C27B0).withAlpha(45),
          blurRadius: 14,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withAlpha(22),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ];

  /// Ícone do balão minimizado — NUNCA usa [attachmentImageUrl] (só no card expandido).
  Widget _minimizedIconOrb({
    double size = AiFloatingMessageBubble.collapsedSize,
    bool includeOuterShadow = true,
    bool dismissHot = false,
  }) {
    final emoji = widget.collapsedIcon?.trim() ?? '';
    final diameter =
        size.clamp(48.0, AiFloatingMessageBubble.collapsedSize).toDouble();
    final fontSize = diameter * 0.52;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFF8FC),
          border: Border.all(color: Colors.white.withAlpha(240), width: 2.5),
          boxShadow:
              includeOuterShadow ? _orbShadows(dismissHot: dismissHot) : null,
        ),
        child: Center(
          child: Text(
            emoji.isNotEmpty ? emoji : '🤖',
            style: TextStyle(fontSize: fontSize),
          ),
        ),
      ),
    );
  }

  /// Chip pequeno no cabeçalho do card expandido (só emoji, sem banner).
  Widget _expandedHeaderIcon() {
    return _minimizedIconOrb(size: 40);
  }

  // (removido) _avatarFace: não usado após redesign do minimizado.

  Widget _networkImage({
    required String url,
    required double height,
    double? width,
    BoxFit fit = BoxFit.cover,
    BorderRadius? radius,
  }) {
    final r = radius ?? BorderRadius.circular(10);
    return ClipRRect(
      borderRadius: r,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 220),
        fadeOutDuration: const Duration(milliseconds: 160),
        placeholder: (_, __) => Container(
          height: height,
          width: width,
          color: const Color(0xFFF3E5F5),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          height: height,
          width: width,
          color: const Color(0xFFF3E5F5),
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.grey.shade500,
            size: 28,
          ),
        ),
      ),
    );
  }

  void _openImagePreview(String url, {String? semanticsLabel}) {
    final raw = url.trim();
    final uri = Uri.tryParse(raw);
    if (raw.isEmpty || uri == null || !uri.hasScheme) return;
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      barrierColor: Colors.black.withAlpha(245),
      builder: (ctx) {
        final pad = MediaQuery.paddingOf(ctx);
        final sz = MediaQuery.sizeOf(ctx);
        final provider = CachedNetworkImageProvider(raw);
        return Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                label: semanticsLabel,
                child: PhotoView(
                  imageProvider: provider,
                  gaplessPlayback: true,
                  minScale: PhotoViewComputedScale.contained * 0.9,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  initialScale: PhotoViewComputedScale.contained,
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  loadingBuilder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                  filterQuality: FilterQuality.medium,
                  customSize: sz,
                ),
              ),
              Positioned(
                top: pad.top + 10,
                right: 12,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withAlpha(150),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openActionLink() async {
    final custom = widget.onActionTap;
    if (custom != null) {
      custom();
      return;
    }
    await FloatingMessageAction.openExternalUrl(widget.actionUrl);
  }

  Widget _promoCtaButton(String linkLabel) {
    return SizedBox(
      height: AiFloatingMessageBubble.promoActionButtonHeight,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _openActionLink,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.open_in_new_rounded, size: 20),
        label: Text(
          linkLabel,
          style: TextStyle(
            fontSize: portalSp(context, 15),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _expandedBannerContent(
    String msg,
    double maxWidth,
    double viewportHeight,
  ) {
    final body = msg.trim();
    final attachment = widget.attachmentImageUrl?.trim() ?? '';
    final linkLabel = (widget.actionLinkLabel ?? 'Saiba mais').trim();
    final aspect = widget.imageAspectRatio;
    var imgH = _promoImageHeight(viewportHeight);
    if (aspect != null && aspect > 0.25 && attachment.isNotEmpty) {
      imgH = (maxWidth / aspect)
          .clamp(
            AiFloatingMessageBubble.promoImageMinHeight,
            AiFloatingMessageBubble.promoImageMaxHeight,
          )
          .toDouble();
    }

    final card = _promoCardShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dragHandle(),
            _navHeader(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _expandedHeaderIcon(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (widget.title?.trim() ?? '').isNotEmpty
                        ? widget.title!.trim()
                        : 'FaceBaby',
                    style: TextStyle(
                      fontSize: portalSp(context, 16),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4A148C),
                      height: 1.15,
                    ),
                  ),
                ),
                if (widget.showCloseButton)
                  _premiumCloseButton(onTap: widget.onCloseTap),
              ],
            ),
            if (attachment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Semantics(
                label: widget.imageAlt?.trim().isNotEmpty == true
                    ? widget.imageAlt!.trim()
                    : null,
                child: GestureDetector(
                  onTap: () => _openImagePreview(
                    attachment,
                    semanticsLabel: widget.imageAlt,
                  ),
                  child: _networkImage(
                    url: attachment,
                    height: imgH,
                    width: maxWidth - 36,
                    fit: aspect != null && aspect > 1.15
                        ? BoxFit.contain
                        : BoxFit.cover,
                    radius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
            if (body.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                body,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: portalSp(context, 14.2),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withAlpha(175),
                ),
              ),
            ],
            if (widget.hasActionButton) ...[
              const SizedBox(height: 14),
              _promoCtaButton(linkLabel),
            ],
          ],
        ),
      ),
    );
    return SizedBox(
      width: maxWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: viewportHeight * 0.78),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: card,
        ),
      ),
    );
  }

  Widget _dismissStrip(Size area) {
    final label = (widget.closeZoneLabel ?? 'Solte aqui para fechar').trim();
    final hot = _nearDismissZone && _isDragActive;
    final stripW = area.width * AiFloatingMessageBubble.dismissStripWidthFraction;
    final left = (area.width - stripW) / 2;
    const stripH = AiFloatingMessageBubble.dismissStripHeight;
    final hotScale = 1.0 + (hot ? 0.045 : 0.0);

    return AnimatedBuilder(
      animation: _dismissStripCtrl,
      builder: (context, child) {
        if (_dismissStripCtrl.value <= 0.01) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: left,
          width: stripW,
          bottom: AiFloatingMessageBubble.dismissStripBottomGap,
          child: IgnorePointer(
            child: SlideTransition(
              position: _dismissStripSlide,
              child: FadeTransition(
                opacity: _dismissStripFade,
                child: Transform.scale(
                  scale: hotScale,
                  alignment: Alignment.bottomCenter,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            const Color(0xFFFFEBEE).withAlpha(185),
                            const Color(0xFFEF9A9A).withAlpha(200),
                            hot ? 0.75 : 0.35,
                          )!,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withAlpha(hot ? 200 : 140),
                            width: 1.25,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE53935)
                                  .withAlpha(hot ? 55 : 35),
                              blurRadius: hot ? 18 : 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          height: stripH.clamp(
                            90.0,
                            AiFloatingMessageBubble.dismissStripMaxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: hot ? 32 : 28,
                                color: hot
                                    ? const Color(0xFFB71C1C)
                                    : const Color(0xFFC62828),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: DefaultTextStyle(
                                  style: const TextStyle(
                                    decoration: TextDecoration.none,
                                    decorationThickness: 0,
                                  ),
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFFB71C1C),
                                      fontSize: portalSp(context, hot ? 16.5 : 16),
                                      fontWeight: hot ? FontWeight.w800 : FontWeight.w700,
                                      letterSpacing: 0.2,
                                      height: 1.25,
                                      decoration: TextDecoration.none,
                                      decorationColor: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _newMessageBadge() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5252), Color(0xFFE91E8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E8C).withAlpha(120),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '!',
        style: TextStyle(
          color: Colors.white,
          fontSize: portalSp(context, 14),
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }

  List<BoxShadow> _collapsedOrbShadows({
    bool dragDismissHot = false,
    double alertT = 0,
  }) {
    return [
      ..._orbShadows(dismissHot: dragDismissHot),
      if (alertT > 0.05)
        BoxShadow(
          color: const Color(0xFFE91E8C).withAlpha((90 * alertT).round()),
          blurRadius: 18 + 8 * alertT,
          spreadRadius: 2 * alertT,
        ),
    ];
  }

  /// Orb minimizado: área externa maior + círculo menor (badge/sombra não cortam).
  Widget _buildCollapsedOrb({
    bool dragDismissHot = false,
    double alertT = 0,
  }) {
    const diameter = AiFloatingMessageBubble.collapsedSize;
    final layout = AiFloatingMessageBubble.collapsedLayoutSize;
    final emoji = widget.collapsedIcon?.trim() ?? '';
    final fontSize = diameter * 0.5;
    final scale = 1.0 + (0.06 * alertT);

    return SizedBox(
      width: layout,
      height: layout,
      child: Center(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: diameter,
                    height: diameter,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFF8FC),
                        border: Border.all(
                          color: Colors.white.withAlpha(240),
                          width: 2,
                        ),
                        boxShadow: _collapsedOrbShadows(
                          dragDismissHot: dragDismissHot,
                          alertT: alertT,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          emoji.isNotEmpty ? emoji : '🤖',
                          style: TextStyle(fontSize: fontSize),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.messageAlert && !widget.expanded)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Transform.scale(
                      scale: 0.92 + (0.1 * alertT),
                      child: _newMessageBadge(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _collapsedContent({
    bool dragDismissHot = false,
    double alertT = 0,
  }) {
    return _buildCollapsedOrb(
      dragDismissHot: dragDismissHot,
      alertT: alertT,
    );
  }

  Widget _promoCardShell({required Widget child}) {
    return Material(
      color: Colors.transparent,
      elevation: 10,
      shadowColor: const Color(0xFF9C27B0).withAlpha(70),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFEDE7F6), width: 1.25),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  Widget _premiumCloseButton({VoidCallback? onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(170),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black.withAlpha(18)),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: Colors.black.withAlpha(160),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(25),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _navHeader() {
    final label = widget.navigationLabel?.trim() ?? '';
    final canNav = (widget.messageCount ?? 0) > 1 &&
        (widget.onPreviousMessage != null || widget.onNextMessage != null);
    if (!canNav && label.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (canNav)
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: widget.onPreviousMessage,
              icon: const Icon(Icons.chevron_left_rounded),
            )
          else
            const SizedBox(width: 34, height: 34),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: portalSp(context, 12),
                  fontWeight: FontWeight.w800,
                  color: Colors.black.withAlpha(110),
                ),
              ),
            ),
          ),
          if (canNav)
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: widget.onNextMessage,
              icon: const Icon(Icons.chevron_right_rounded),
            )
          else
            const SizedBox(width: 34, height: 34),
        ],
      ),
    );
  }

  double _promoImageHeight(double viewportHeight) {
    if ((widget.attachmentImageUrl?.trim() ?? '').isEmpty) return 0;
    return (viewportHeight * AiFloatingMessageBubble.promoImageHeightFraction)
        .clamp(
      AiFloatingMessageBubble.promoImageMinHeight,
      AiFloatingMessageBubble.promoImageMaxHeight,
    );
  }

  Widget _expandedPromoContent(
    String msg,
    double maxWidth,
    double viewportHeight,
  ) {
    final body = msg.replaceFirst(RegExp(r'^🤖\s*'), '').trim();
    final attachment = widget.attachmentImageUrl?.trim() ?? '';
    final linkLabel = (widget.actionLinkLabel ?? 'Saiba mais').trim();
    final imgH = _promoImageHeight(viewportHeight);

    final card = _promoCardShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dragHandle(),
            _navHeader(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _expandedHeaderIcon(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (widget.title?.trim() ?? '').isNotEmpty
                        ? widget.title!.trim()
                        : 'FaceBaby',
                    style: TextStyle(
                      fontSize: portalSp(context, 16),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4A148C),
                      height: 1.15,
                    ),
                  ),
                ),
                if (widget.showCloseButton)
                  _premiumCloseButton(onTap: widget.onCloseTap),
              ],
            ),
            if (attachment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Semantics(
                label: widget.imageAlt?.trim().isNotEmpty == true
                    ? widget.imageAlt!.trim()
                    : null,
                child: GestureDetector(
                  onTap: () => _openImagePreview(
                    attachment,
                    semanticsLabel: widget.imageAlt,
                  ),
                  child: _networkImage(
                    url: attachment,
                    height: imgH,
                    width: maxWidth - 36,
                    fit: BoxFit.cover,
                    radius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
            if (body.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: portalSp(context, 14.2),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withAlpha(175),
                ),
              ),
            ],
            if (widget.hasActionButton) ...[
              const SizedBox(height: 14),
              _promoCtaButton(linkLabel),
            ],
          ],
        ),
      ),
    );
    return SizedBox(
      width: maxWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: viewportHeight * 0.78),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: card,
        ),
      ),
    );
  }

  Widget _expandedContent(
    String msg,
    double maxWidth, {
    double alertT = 0,
  }) {
    final body = msg.replaceFirst(RegExp(r'^🤖\s*'), '').trim().isEmpty
        ? msg
        : msg.replaceFirst(RegExp(r'^🤖\s*'), '').trim();
    final attachment = widget.attachmentImageUrl?.trim() ?? '';
    final linkLabel = (widget.actionLinkLabel ?? 'Abrir link').trim();
    final title = widget.title?.trim() ?? '';

    return _promoCardShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dragHandle(),
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  _navHeader(),
                  if (widget.showCloseButton && widget.onCloseTap != null)
                    Positioned(
                      right: -4,
                      top: 0,
                      child: _premiumCloseButton(onTap: widget.onCloseTap),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(child: _expandedHeaderIcon()),
            if (attachment.isNotEmpty) ...[
              const SizedBox(height: 14),
              Center(
                child: _networkImage(
                  url: attachment,
                  height: AiFloatingMessageBubble.attachmentImageHeight,
                  width: maxWidth - 48,
                  radius: BorderRadius.circular(18),
                ),
              ),
            ],
            if (title.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: portalSp(context, 16),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF4A148C),
                  height: 1.2,
                ),
              ),
            ],
            if (body.isNotEmpty) ...[
              SizedBox(height: title.isNotEmpty ? 8 : 14),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: portalSp(context, 14),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3D2A4F),
                ),
              ),
            ],
            if (widget.hasActionButton) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _openActionLink,
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: Color(0xFF7B1FA2),
                  ),
                  label: Text(
                    linkLabel,
                    style: TextStyle(
                      fontSize: portalSp(context, 13),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF7B1FA2),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bubbleSurfaceContent({
    required String msg,
    required bool banner,
    required bool promo,
    required double maxW,
    required double viewportHeight,
    required double alertT,
  }) {
    if (widget.expanded) {
      return KeyedSubtree(
        key: ValueKey(
          banner
              ? 'ai_bubble_banner'
              : promo
                  ? 'ai_bubble_promo'
                  : 'ai_bubble_expanded',
        ),
        child: banner
            ? _expandedBannerContent(msg, maxW, viewportHeight)
            : promo
                ? _expandedPromoContent(msg, maxW, viewportHeight)
                : _expandedContent(msg, maxW, alertT: 0),
      );
    }
    return KeyedSubtree(
      key: const ValueKey('ai_bubble_collapsed'),
      child: _collapsedContent(alertT: alertT),
    );
  }

  Widget _draggableBubbleChild({
    required String msg,
    required bool banner,
    required bool promo,
    required double maxW,
    required double viewportHeight,
    required double alertT,
  }) {
    if (_isDragActive) {
      return KeyedSubtree(
        key: const ValueKey('ai_bubble_drag_orb'),
        child: _buildCollapsedOrb(
          dragDismissHot: _nearDismissZone,
          alertT: alertT,
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(
          sizeFactor: anim,
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: _bubbleSurfaceContent(
        msg: msg,
        banner: banner,
        promo: promo,
        maxW: maxW,
        viewportHeight: viewportHeight,
        alertT: alertT,
      ),
    );
  }

  Widget _buildBubbleSurface({
    required String msg,
    required bool banner,
    required bool promo,
    required double maxW,
    required double viewportHeight,
    required double alertT,
    required bool collapsed,
    required double expandT,
  }) {
    final surface = KeyedSubtree(
      key: _bubbleKey,
      child: collapsed
          ? _draggableBubbleChild(
              msg: msg,
              banner: banner,
              promo: promo,
              maxW: maxW,
              viewportHeight: viewportHeight,
              alertT: alertT,
            )
          : AnimatedSize(
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutBack,
              reverseDuration: const Duration(milliseconds: 260),
              alignment: Alignment.center,
              clipBehavior: Clip.hardEdge,
              child: _draggableBubbleChild(
                msg: msg,
                banner: banner,
                promo: promo,
                maxW: maxW,
                viewportHeight: viewportHeight,
                alertT: alertT,
              ),
            ),
    );
    if (collapsed) {
      return surface;
    }
    return Transform.scale(
      scale: 0.92 + (0.08 * expandT),
      alignment: Alignment.center,
      child: Opacity(
        opacity: 0.92 + (0.08 * expandT),
        child: surface,
      ),
    );
  }

  Widget _buildExpandedModal({
    required String msg,
    required bool banner,
    required bool promo,
    required double maxW,
    required double viewportHeight,
  }) {
    return Stack(
      key: const Key('floating_message_expanded_layer'),
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ColoredBox(
            key: const Key('floating_message_expanded_scrim'),
            color: Colors.black.withValues(
              alpha: AiFloatingMessageBubble.expandedScrimOpacity,
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedBuilder(
              animation: _expandCurve,
              builder: (context, _) {
                final t = _expandCurve.value;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxW,
                    minWidth: 280,
                  ),
                  child: _buildBubbleSurface(
                    msg: msg,
                    banner: banner,
                    promo: promo,
                    maxW: maxW,
                    viewportHeight: viewportHeight,
                    alertT: 0,
                    collapsed: false,
                    expandT: t,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedLayer({
    required String msg,
    required bool banner,
    required bool promo,
    required double maxW,
    required Size area,
    required double bottomReserve,
  }) {
    final clampedPos = AiFloatingMessageBubble.clampCollapsedTopLeft(
      topLeft: widget.position,
      viewport: area,
      bottomReserve: bottomReserve,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _dismissStrip(area),
        Positioned(
          left: clampedPos.dx,
          top: clampedPos.dy,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onToggleExpanded,
            onPanStart: _onPanStart,
            onPanUpdate: (d) => _onPanUpdate(d, area),
            onPanEnd: (d) => _onPanEnd(d, area),
            child: AnimatedBuilder(
              animation: Listenable.merge([_expandCurve, _alertPulse]),
              builder: (context, child) {
                final alertT = widget.messageAlert ? _alertPulse.value : 0.0;
                return _buildBubbleSurface(
                  msg: msg,
                  banner: banner,
                  promo: promo,
                  maxW: maxW,
                  viewportHeight: area.height,
                  alertT: alertT,
                  collapsed: true,
                  expandT: 0,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message.trim();
    final hasImage = (widget.attachmentImageUrl?.trim() ?? '').isNotEmpty;
    if (msg.isEmpty && !hasImage && !widget.bannerLayout) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        final promo = widget.promoLayout && !widget.bannerLayout;
        final banner = widget.bannerLayout;
        final maxW = (promo || banner
                ? (area.width - 16).clamp(200.0, area.width - 16)
                : (area.width - AiFloatingMessageBubble.edgePadding * 2)
                    .clamp(200.0, AiFloatingMessageBubble.expandedMaxWidth))
            .toDouble();

        if (widget.expanded) {
          return _buildExpandedModal(
            msg: msg,
            banner: banner,
            promo: promo,
            maxW: maxW,
            viewportHeight: area.height,
          );
        }

        final bottomReserve =
            widget.allowDragDismiss && widget.showDismissZone ? 0.0 : 24.0;
        return _buildCollapsedLayer(
          msg: msg,
          banner: banner,
          promo: promo,
          maxW: maxW,
          area: area,
          bottomReserve: bottomReserve,
        );
      },
    );
  }
}
