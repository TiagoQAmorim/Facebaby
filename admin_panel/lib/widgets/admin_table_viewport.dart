import 'package:flutter/material.dart';

import 'admin_layout.dart';

/// Largura mínima estimada para tabelas largas (scroll horizontal).
const double kAdminTableMinScrollWidth = 1280;

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

  Widget _horizontalScrollContent({required Widget child}) {
    return SingleChildScrollView(
      controller: _horizontal,
      scrollDirection: Axis.horizontal,
      primary: false,
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: widget.minScrollWidth),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final bounded = maxH.isFinite && maxH > 0;

        final tableBody = _horizontalScrollContent(child: widget.child);

        final verticalArea = Scrollbar(
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
            child: tableBody,
          ),
        );

        const horizontalBarHeight = 14.0;
        final horizontalBar = SizedBox(
          height: horizontalBarHeight,
          child: Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              primary: false,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: widget.minScrollWidth,
                height: horizontalBarHeight,
              ),
            ),
          ),
        );

        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: verticalArea),
            horizontalBar,
          ],
        );

        if (bounded) {
          return SizedBox(height: maxH, child: body);
        }
        return body;
      },
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
  });

  final Widget header;
  final Widget table;
  final bool loading;
  final String? error;
  final String? emptyMessage;
  final Widget? footer;
  /// Barra de ações em lote (ex.: alterar plano dos selecionados).
  final Widget? selectionBar;

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
    return AdminTableViewport(child: table);
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

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: header),
        if (selectionBar != null) SliverToBoxAdapter(child: selectionBar!),
        if (selectionBar != null) const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (footer != null) SliverToBoxAdapter(child: footer!),
        if (footer != null) const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverFillRemaining(
          hasScrollBody: true,
          child: card,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
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
