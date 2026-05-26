import 'package:flutter/material.dart';

/// Largura mínima para sidebar fixa (desktop). Abaixo disso: drawer + AppBar.
abstract final class AdminLayout {
  static const double wideBreakpoint = 900;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return const EdgeInsets.all(16);
    if (w < wideBreakpoint) return const EdgeInsets.all(20);
    return const EdgeInsets.all(28);
  }

  static TextStyle pageTitleStyle(BuildContext context) => TextStyle(
        fontSize: isWide(context) ? 28 : 22,
        fontWeight: FontWeight.w900,
      );
}

/// Padding responsivo das páginas internas do painel.
class AdminPagePadding extends StatelessWidget {
  const AdminPagePadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AdminLayout.pagePadding(context),
      child: child,
    );
  }
}

/// Título da página + ações; empilha em telas estreitas.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final wide = AdminLayout.isWide(context);

    // Em mobile o título já aparece na AppBar do [AdminShell].
    if (!wide) {
      if (actions.isEmpty) return const SizedBox.shrink();
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(title, style: AdminLayout.pageTitleStyle(context)),
        ),
        ...actions,
      ],
    );
  }
}
