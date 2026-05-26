import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  static const double collapsedSize = 56;
  static const double dismissZoneHeight = 88;
  static const double expandedMaxWidth = 280;
  static const double expandedMaxHeight = 168;
  static const double promoMinWidth = 300;
  static const double promoImageMinHeight = 220;
  static const double promoImageMaxHeight = 340;
  static const double promoImageHeightFraction = 0.42;
  static const double promoActionButtonHeight = 48;
  static const double attachmentImageHeight = 112;
  static const double actionLinkRowHeight = 36;
  static const double edgePadding = 12;
  static const double dismissStripHeight = 88;
  static const String _avatarAsset = 'assets/ai/ia_baba_button.png';

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
      if (hasAttachmentImage || promoLayout) {
        return const Size(58, 58);
      }
      return const Size(collapsedSize, collapsedSize);
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
      return Size(w, titleH + imgH + textBlock + btnH + pad);
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
  bool _moved = false;
  bool _nearDismissZone = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandCurve;
  late final AnimationController _alertCtrl;
  late final Animation<double> _alertPulse;
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
    _syncAlertAnimation();
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
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _alertCtrl.dispose();
    super.dispose();
  }

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

  void _onPanStart(DragStartDetails d) {
    _dragOrigin = widget.position;
    _pointerStart = d.globalPosition;
    _moved = false;
    setState(() => _nearDismissZone = false);
  }

  void _onPanUpdate(DragUpdateDetails d, Size area) {
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
    final next = AiFloatingMessageBubble.clampTopLeft(
      topLeft: raw,
      bubbleSize: bubble,
      viewport: area,
      bottomReserve: widget.allowDragDismiss &&
              (widget.showDismissZone || _nearDismissZone)
          ? AiFloatingMessageBubble.dismissStripHeight
          : 24,
    );
    final near = widget.allowDragDismiss &&
        next.dy + bubble.height >
            area.height - AiFloatingMessageBubble.dismissStripHeight + 8;
    if (near != _nearDismissZone) {
      setState(() => _nearDismissZone = near);
    }
    widget.onPositionChanged(next);
  }

  void _onPanEnd(DragEndDetails d, Size area) {
    if (!_moved) {
      widget.onToggleExpanded();
      _dragOrigin = null;
      _pointerStart = null;
      setState(() => _nearDismissZone = false);
      return;
    }
    final pos = widget.position;
    final bubble = _currentBubbleSize(area);
    final inDismissZone = widget.allowDragDismiss &&
        (pos.dy + bubble.height >
                area.height - AiFloatingMessageBubble.dismissStripHeight + 4 ||
            _nearDismissZone);
    if (inDismissZone && widget.allowDragDismiss) {
      widget.onDismissDrag();
    } else {
      widget.onDragEnded();
    }
    _dragOrigin = null;
    _pointerStart = null;
    _moved = false;
    setState(() => _nearDismissZone = false);
  }

  Widget _collapsedIconFace() {
    final emoji = widget.collapsedIcon?.trim() ?? '';
    final size = AiFloatingMessageBubble.collapsedSize - 8;
    if (emoji.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
        ),
      );
    }
    return _avatarFace(size: size - 6);
  }

  Widget _avatarFace({required double size}) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFF8FC),
          border: Border.all(color: Colors.white, width: 2),
        ),
        padding: EdgeInsets.all(size * 0.05),
        child: ClipOval(
          child: Image.asset(
            AiFloatingMessageBubble._avatarAsset,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

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

  Future<void> _openActionLink() async {
    final custom = widget.onActionTap;
    if (custom != null) {
      custom();
      return;
    }
    final raw = widget.actionUrl?.trim() ?? '';
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return;
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    return _promoCardShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _collapsedIconFace(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (widget.title?.trim() ?? '').isNotEmpty
                        ? widget.title!.trim()
                        : 'FaceBaby',
                    style: TextStyle(
                      fontSize: portalSp(context, 15),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4A148C),
                    ),
                  ),
                ),
                if (widget.showCloseButton)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: widget.onCloseTap,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
              ],
            ),
            if (attachment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Semantics(
                label: widget.imageAlt?.trim().isNotEmpty == true
                    ? widget.imageAlt!.trim()
                    : null,
                child: _networkImage(
                  url: attachment,
                  height: imgH,
                  width: maxWidth - 24,
                  radius: BorderRadius.circular(14),
                ),
              ),
            ],
            if (body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                body,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: portalSp(context, 14),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3D2A4F),
                ),
              ),
            ],
            if (widget.hasActionButton) ...[
              const SizedBox(height: 12),
              _promoCtaButton(linkLabel),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dismissStrip(Size area) {
    final label = (widget.closeZoneLabel ?? 'Solte aqui para fechar').trim();
    final visible = widget.allowDragDismiss && widget.showDismissZone;
    final height =
        visible ? AiFloatingMessageBubble.dismissStripHeight : 0.0;
    final hot = _nearDismissZone && visible;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: 12,
      right: 12,
      bottom: 8,
      height: height,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFFFEBEE).withAlpha(220),
              const Color(0xFFE53935).withAlpha(235),
              hot ? 1.0 : 0.35,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFFEF9A9A),
                const Color(0xFFC62828),
                hot ? 1.0 : 0.5,
              )!,
              width: hot ? 2 : 1.2,
            ),
            boxShadow: hot
                ? [
                    BoxShadow(
                      color: const Color(0xFFE53935).withAlpha(90),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Opacity(
            opacity: visible ? 1 : 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '🗑️',
                  style: TextStyle(fontSize: portalSp(context, hot ? 22 : 18)),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: hot
                        ? Colors.white
                        : const Color(0xFFB71C1C),
                    fontSize: portalSp(context, 12),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _newMessageBadge() {
    return Container(
      width: 22,
      height: 22,
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

  Widget _chatBubbleShell({
    required Widget child,
    required bool showTail,
    required double tailAlignX,
    double alertT = 0,
  }) {
    const fill = Color(0xFFFAF5FF);
    const border = Color(0xFFE1BEE7);
    const alertFill = Color(0xFFFFEBF3);
    const alertBorder = Color(0xFFE91E8C);

    final bg = Color.lerp(fill, alertFill, alertT)!;
    final bd = Color.lerp(border, alertBorder, alertT)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Material(
          color: Colors.transparent,
          elevation: 6 + (alertT * 6),
          shadowColor: Color.lerp(
            const Color(0xFF9C27B0).withAlpha(80),
            const Color(0xFFE91E8C).withAlpha(160),
            alertT,
          )!,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(6),
              ),
              border: Border.all(
                color: bd.withAlpha((200 + 55 * alertT).round()),
                width: 1.5 + alertT,
              ),
            ),
            child: child,
          ),
        ),
        if (showTail)
          Padding(
            padding: EdgeInsets.only(right: (1 - tailAlignX).clamp(0.0, 1.0) * 24),
            child: CustomPaint(
              size: const Size(16, 10),
              painter: _BubbleTailPainter(color: bg, borderColor: bd),
            ),
          ),
      ],
    );
  }

  Widget _wrapWithAlert(Widget child) {
    return AnimatedBuilder(
      animation: _alertPulse,
      builder: (context, _) {
        final t = widget.messageAlert && !widget.expanded ? _alertPulse.value : 0.0;
        final scale = 1.0 + (0.07 * t);
        return Transform.scale(
          scale: scale,
          alignment: Alignment.bottomRight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (t > 0.05)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE91E8C).withAlpha((90 * t).round()),
                          blurRadius: 18 + 8 * t,
                          spreadRadius: 2 * t,
                        ),
                      ],
                    ),
                  ),
                ),
              child,
              if (widget.messageAlert && !widget.expanded)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Transform.scale(
                    scale: 0.92 + (0.12 * t),
                    child: _newMessageBadge(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _collapsedContent({double alertT = 0}) {
    final attachment = widget.attachmentImageUrl?.trim() ?? '';
    return _chatBubbleShell(
      showTail: true,
      tailAlignX: 0.85,
      alertT: alertT,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
        child: attachment.isNotEmpty
            ? _networkImage(
                url: attachment,
                height: 46,
                width: 46,
                radius: BorderRadius.circular(12),
              )
            : _collapsedIconFace(),
      ),
    );
  }

  Widget _promoCardShell({required Widget child}) {
    return Material(
      color: Colors.transparent,
      elevation: 12,
      shadowColor: const Color(0xFF9C27B0).withAlpha(100),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1BEE7), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
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

    return _promoCardShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showCloseButton)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: widget.onCloseTap,
                  icon: const Icon(Icons.close_rounded, size: 22),
                ),
              ),
            if (attachment.isNotEmpty)
              _networkImage(
                url: attachment,
                height: imgH,
                width: maxWidth - 24,
                radius: BorderRadius.circular(14),
              ),
            if (body.isNotEmpty) ...[
              if (attachment.isNotEmpty) const SizedBox(height: 10),
              Text(
                body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: portalSp(context, 14),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3D2A4F),
                ),
              ),
            ],
            if (widget.hasActionButton) ...[
              const SizedBox(height: 12),
              _promoCtaButton(linkLabel),
            ],
          ],
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
    final maxH = AiFloatingMessageBubble.estimatedSize(
      expanded: true,
      viewportWidth: maxWidth + AiFloatingMessageBubble.edgePadding * 2,
      hasAttachmentImage: attachment.isNotEmpty,
      hasActionLink: widget.hasActionButton,
    ).height;

    return _chatBubbleShell(
      showTail: true,
      tailAlignX: 0.88,
      alertT: alertT,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxH,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showCloseButton && widget.onCloseTap != null)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: widget.onCloseTap,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ),
              if (attachment.isNotEmpty) ...[
                _networkImage(
                  url: attachment,
                  height: AiFloatingMessageBubble.attachmentImageHeight,
                  width: maxWidth - 22,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _collapsedIconFace(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((widget.title?.trim() ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                widget.title!.trim(),
                                style: TextStyle(
                                  fontSize: portalSp(context, 14),
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF4A148C),
                                ),
                              ),
                            ),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: portalSp(context, 13),
                              height: 1.42,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3D2A4F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.hasActionButton) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
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
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
        final bottomReserve = widget.allowDragDismiss && widget.showDismissZone
            ? AiFloatingMessageBubble.dismissStripHeight
            : 24.0;
        final clampedPos = AiFloatingMessageBubble.clampTopLeft(
          topLeft: widget.position,
          bubbleSize: _currentBubbleSize(area),
          viewport: area,
          bottomReserve: bottomReserve,
        );

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            _dismissStrip(area),
            Positioned(
              left: clampedPos.dx,
              top: clampedPos.dy,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: (d) => _onPanUpdate(d, area),
                onPanEnd: (d) => _onPanEnd(d, area),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_expandCurve, _alertPulse]),
                  builder: (context, child) {
                    final t = _expandCurve.value;
                    final alertT = widget.messageAlert && !widget.expanded
                        ? _alertPulse.value
                        : 0.0;
                    return Transform.scale(
                      scale: 0.72 + (0.28 * t),
                      alignment: Alignment.bottomRight,
                      child: Opacity(
                        opacity: 0.88 + (0.12 * t),
                        child: _wrapWithAlert(
                          KeyedSubtree(
                            key: _bubbleKey,
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 340),
                              curve: Curves.easeOutBack,
                              reverseDuration: const Duration(milliseconds: 260),
                              alignment: Alignment.bottomRight,
                              clipBehavior: Clip.hardEdge,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(
                                  opacity: anim,
                                  child: SizeTransition(
                                    sizeFactor: anim,
                                    axisAlignment: -1,
                                    child: child,
                                  ),
                                ),
                                child: widget.expanded
                                    ? KeyedSubtree(
                                        key: ValueKey(
                                          banner
                                              ? 'ai_bubble_banner'
                                              : promo
                                                  ? 'ai_bubble_promo'
                                                  : 'ai_bubble_expanded',
                                        ),
                                        child: banner
                                            ? _expandedBannerContent(
                                                msg,
                                                maxW,
                                                area.height,
                                              )
                                            : promo
                                                ? _expandedPromoContent(
                                                    msg,
                                                    maxW,
                                                    area.height,
                                                  )
                                                : _expandedContent(
                                                    msg,
                                                    maxW,
                                                    alertT: 0,
                                                  ),
                                      )
                                    : KeyedSubtree(
                                        key: const ValueKey(
                                          'ai_bubble_collapsed',
                                        ),
                                        child: _collapsedContent(
                                          alertT: alertT,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Cauda do balão (triângulo) apontando para baixo-direita.
class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color, required this.borderColor});

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.55, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color;
}
