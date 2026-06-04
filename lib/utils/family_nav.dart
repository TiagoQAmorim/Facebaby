import 'package:flutter/material.dart';

import '../app/face_baby_app.dart';
import '../app/shell_nested_nav.dart';
import '../pages/family_tree_page.dart';
import 'portal_page_route.dart';

/// Abre [FamilyTreePage] no navigator aninhado da Home (tab 0) para manter o fundo portal.
abstract final class FamilyNav {
  FamilyNav._();

  static void openFamilyTreeTab(
    BuildContext context, {
    required int initialTabIndex,
  }) {
    ShellNestedNav.selectTab?.call(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nested = ShellNestedNav.tabNavigatorKeys[0].currentState;
      final route = portalPageRoute<void>(
        builder: (_) => FamilyTreePage(initialTabIndex: initialTabIndex),
      );
      if (nested != null) {
        nested.push(route);
        return;
      }
      FaceBabyApp.navigatorKey.currentState?.push(route);
    });
  }
}
