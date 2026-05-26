import 'package:flutter/material.dart';

/// One [Navigator] per bottom tab inside [MainShell] so [Navigator.push] keeps
/// the [NavigationBar] visible.
abstract final class ShellNestedNav {
  ShellNestedNav._();

  /// 0 Home, 1 Registros, 2 IA Babá, 3 Memórias, 4 Mais.
  static final List<GlobalKey<NavigatorState>> tabNavigatorKeys =
      List<GlobalKey<NavigatorState>>.generate(
    5,
    (int i) => GlobalKey<NavigatorState>(debugLabel: 'shellTabNav$i'),
  );

  /// Set while [MainShell] is mounted (e.g. notification deep-links).
  static void Function(int index)? selectTab;
}
