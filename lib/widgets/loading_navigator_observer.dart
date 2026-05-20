import 'package:flutter/material.dart';

import 'loading_scope.dart';

/// Overlay breve em rotas opacas legadas (MaterialPageRoute no shell).
/// Rotas [portalPageRoute] não disparam máscara — fade rápido + tema transparente.
class LoadingNavigatorObserver extends NavigatorObserver {
  final GlobalKey<NavigatorState> navigatorKey;

  /// Quando `false`, nunca mostra loading (navegadores aninhados do shell).
  final bool maskTransitions;

  LoadingNavigatorObserver(
    this.navigatorKey, {
    this.maskTransitions = true,
  });

  bool _shouldMask(Route<dynamic>? route) {
    if (!maskTransitions) return false;
    if (route == null) return false;
    if (route is PageRoute && !route.opaque) return false;
    return true;
  }

  void _showOnce() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      final loading = LoadingScope.maybeOf(ctx);
      if (loading == null) return;
      loading.show('Carregando…');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        loading.hide();
      });
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (!_shouldMask(route)) return;
    if (previousRoute == null) return;
    _showOnce();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (!_shouldMask(newRoute)) return;
    _showOnce();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (!_shouldMask(previousRoute)) return;
    _showOnce();
  }
}
