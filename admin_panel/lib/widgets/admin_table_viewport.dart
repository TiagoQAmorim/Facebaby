import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'admin_layout.dart';

/// Largura mínima estimada para tabelas largas (scroll horizontal).
const double kAdminTableMinScrollWidth = 1320;

/// Barra horizontal fixa no rodapé — visível sempre que a tabela for mais larga que o ecrã.
class _PinnedHorizontalScrollbar extends StatelessWidget {
  const _PinnedHorizontalScrollbar({
    required this.controller,
    required this.viewportWidth,
    required this.contentWidth,
  });

  final ScrollController controller;
  final double viewportWidth;
  final double contentWidth;

  static const _height = 16.0;

  bool get _scrollable => contentWidth > viewportWidth + 1;

  void _jumpToThumb(BuildContext context, double localX, double trackWidth) {
    if (!controller.hasClients || !_scrollable) return;
    final pos = controller.position;
    final thumbFrac = (viewportWidth / contentWidth).clamp(0.08, 1.0);
    final thumbW = trackWidth * thumbFrac;
    final travel = (trackWidth - thumbW).clamp(1.0, double.infinity);
    final frac = ((localX - thumbW / 2) / travel).clamp(0.0, 1.0);
    controller.jumpTo(frac * pos.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).scrollbarTheme;
    final trackColor =
        theme.trackColor?.resolve(const {}) ?? Colors.black.withValues(alpha: 0.06);
    final thumbColor =
        theme.thumbColor?.resolve(const {}) ?? const Color(0xFF7B1FA2).withValues(alpha: 0.55);

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackW = constraints.maxWidth;
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final offset = controller.hasClients ? controller.offset : 0.0;
              final maxExtent =
                  controller.hasClients ? controller.position.maxScrollExtent : 0.0;
              final thumbFrac = _scrollable
                  ? (viewportWidth / contentWidth).clamp(0.08, 1.0)
                  : 1.0;
              final thumbW = trackW * thumbFrac;
              final travel = (trackW - thumbW).clamp(0.0, double.infinity);
              final left = _scrollable && maxExtent > 0
                  ? (offset / maxExtent) * travel
                  : 0.0;

              return MouseRegion(
                cursor: _scrollable
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _scrollable
                      ? (d) => _jumpToThumb(context, d.localPosition.dx, trackW)
                      : null,
                  onHorizontalDragUpdate: _scrollable
                      ? (d) {
                          if (!controller.hasClients) return;
                          final pos = controller.position;
                          final deltaContent =
                              d.delta.dx * (contentWidth / trackW);
                          controller.jumpTo(
                            (controller.offset + deltaContent)
                                .clamp(0.0, pos.maxScrollExtent),
                          );
                        }
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: trackColor,
                            border: Border(
                              top: BorderSide(
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_scrollable)
                        Positioned(
                          left: left,
                          top: 3,
                          bottom: 3,
                          width: thumbW,
                          child: Material(
                            color: thumbColor,
                            borderRadius: BorderRadius.circular(6),
                            elevation: 0,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Tabela com rolagem vertical no corpo e barra horizontal **sempre** visível no rodapé.
class AdminTableViewport extends StatefulWidget {
  const AdminTableViewport({
    super.key,
    required this.child,
    this.minScrollWidth = kAdminTableMinScrollWidth,
  });

  final Widget child;
  final double minScrollWidth;

  @override
  State<AdminTableViewport> createState() => _AdminTableViewportState();
}

class _AdminTableViewportState extends State<AdminTableViewport> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : widget.minScrollWidth;
        final contentW = widget.minScrollWidth;
        final maxH = constraints.maxHeight;
        final bounded = maxH.isFinite && maxH > 0;

        final tableArea = Scrollbar(
          controller: _vertical,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          child: SingleChildScrollView(
            controller: _vertical,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            child: ScrollConfiguration(
              behavior: const _AdminTableScrollBehavior(),
              child: SingleChildScrollView(
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                primary: false,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: contentW,
                  child: widget.child,
                ),
              ),
            ),
          ),
        );

        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tableArea),
            _PinnedHorizontalScrollbar(
              controller: _horizontal,
              viewportWidth: viewportW,
              contentWidth: contentW,
            ),
          ],
        );

        if (bounded) {
          return SizedBox(height: maxH, child: body);
        }
        return SizedBox(
          height: 420,
          child: body,
        );
      },
    );
  }
}

/// ScrollBehavior local — barras visíveis também no eixo horizontal (Flutter Web).
class _AdminTableScrollBehavior extends MaterialScrollBehavior {
  const _AdminTableScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final controller = details.controller;
    if (controller == null) return child;

    final horizontal = axisDirectionToAxis(details.direction) == Axis.horizontal;

    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      scrollbarOrientation: horizontal
          ? ScrollbarOrientation.bottom
          : ScrollbarOrientation.right,
      child: child,
    );
  }
}

/// Página com tabela: cabeçalho fixo + área da tabela com scroll interno.
class AdminTablePageLayout extends StatelessWidget {
  const AdminTablePageLayout({
    super.key,
    required this.header,
    required this.table,
    this.loading = false,
    this.error,
    this.emptyMessage,
    this.footer,
    this.selectionBar,
    this.tableMinScrollWidth = kAdminTableMinScrollWidth,
  });

  final Widget header;
  final Widget table;
  final bool loading;
  final String? error;
  final String? emptyMessage;
  final Widget? footer;
  final Widget? selectionBar;
  final double tableMinScrollWidth;

  Widget _cardChild(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && error!.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          error!,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
      );
    }
    if (emptyMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            emptyMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return AdminTableViewport(
      minScrollWidth: tableMinScrollWidth,
      child: table,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = AdminLayout.isWide(context);
    final card = Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: _cardChild(context),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (selectionBar != null) ...[
          const SizedBox(height: 12),
          selectionBar!,
        ],
        const SizedBox(height: 16),
        if (footer != null) ...[footer!, const SizedBox(height: 12)],
        Expanded(child: card),
      ],
    );

    if (wide) {
      return column;
    }

    return column;
  }
}

/// Envolve páginas do painel para ocupar a altura disponível (necessário para [Expanded]).
class AdminPageScaffold extends StatelessWidget {
  const AdminPageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AdminPagePadding(child: child),
    );
  }
}
