import 'package:flutter/material.dart';

import 'loading_scope.dart';

/// Shows the global loading overlay briefly during navigation,
/// preventing "white flashes" while the next page builds.
class LoadingNavigatorObserver extends NavigatorObserver {
  final GlobalKey<NavigatorState> navigatorKey;

  LoadingNavigatorObserver(this.navigatorKey);

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
    _showOnce();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _showOnce();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _showOnce();
  }
}

