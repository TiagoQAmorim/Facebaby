import 'package:flutter/material.dart';

/// Tema para navegadores dentro do portal: evita fundo branco do [ThemeData] global
/// durante transições e enquanto o [Scaffold] transparente monta.
ThemeData portalShellTheme(BuildContext context) {
  return Theme.of(context).copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
  );
}

Route<T> portalPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    opaque: true,
    transitionDuration: const Duration(milliseconds: 140),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

Future<T?> pushPortalPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    portalPageRoute<T>(builder: (_) => page),
  );
}
