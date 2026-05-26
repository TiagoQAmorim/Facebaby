import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Painel admin (web/desktop): barras de rolagem visíveis em horizontal e vertical.
///
/// O [MaterialScrollBehavior] padrão não decora eixos horizontais com [Scrollbar],
/// o que esconde a barra em tabelas largas no browser.
class AdminScrollBehavior extends MaterialScrollBehavior {
  const AdminScrollBehavior();

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

    final horizontal =
        axisDirectionToAxis(details.direction) == Axis.horizontal;

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
