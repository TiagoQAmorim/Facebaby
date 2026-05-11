import 'package:flutter/material.dart';

import '../app/face_baby_app.dart';
import '../app/shell_nested_nav.dart';
import '../i18n/app_i18n.dart';
import '../pages/diaper_page.dart';
import '../pages/feeding_hub_page.dart';
import '../pages/growth_dashboard_page.dart';
import '../pages/sleep_page.dart';
import '../pages/consultations_page.dart';
import '../pages/vaccines_page.dart';

/// Payloads gravados ao mostrar notificações; ao tocar, navega para o separador certo no [ShellNestedNav].
abstract final class NotificationNav {
  NotificationNav._();

  static const payloadFeeding = 'nav_feeding';
  static const payloadDiaper = 'nav_diaper';
  static const payloadGrowth = 'nav_growth';
  static const payloadSleep = 'nav_sleep';

  /// Cold start pode montar o [Navigator] tarde — tenta algumas vezes com pequenos atrasos.
  /// Mesmo destino que ao tocar numa notificação push (ex.: lista em Início).
  static void openFromPayload(BuildContext context, String? payload) {
    final p = payload?.trim();
    if (p == null || p.isEmpty) return;
    _openIfKnown(context, p);
  }

  static void scheduleOpen(String? payload) {
    final p = payload?.trim();
    if (p == null || p.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (var i = 0; i < 10; i++) {
        if (i > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
        final ctx = FaceBabyApp.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          _openIfKnown(ctx, p);
          return;
        }
      }
    });
  }

  static void _openIfKnown(BuildContext ctx, String payload) {
    late final S s;
    try {
      s = S.of(ctx);
    } catch (_) {
      return;
    }

    void pushOnTab(int tab, Route<void> route) {
      ShellNestedNav.selectTab?.call(tab);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nested = ShellNestedNav.tabNavigatorKeys[tab].currentState;
        if (nested != null) {
          nested.push(route);
          return;
        }
        FaceBabyApp.navigatorKey.currentState?.push(route);
      });
    }

    switch (payload) {
      case payloadFeeding:
        pushOnTab(0, MaterialPageRoute<void>(builder: (_) => FeedingHubPage(appBarTitle: s.shortcutMilk)));
        return;
      case payloadDiaper:
        pushOnTab(1, MaterialPageRoute<void>(builder: (_) => const DiaperPage()));
        return;
      case payloadGrowth:
        pushOnTab(0, MaterialPageRoute<void>(builder: (_) => GrowthDashboardPage(appBarTitle: s.growth)));
        return;
      case payloadSleep:
        pushOnTab(1, MaterialPageRoute<void>(builder: (_) => const SleepPage()));
        return;
      case 'nav_vaccines':
        pushOnTab(0, MaterialPageRoute<void>(builder: (_) => const VaccinesPage()));
        return;
      default:
        if (payload.startsWith('nav_consultation:')) {
          final rawId = payload.substring('nav_consultation:'.length).trim();
          final cid = int.tryParse(rawId);
          if (cid != null) {
            pushOnTab(
              0,
              MaterialPageRoute<void>(
                builder: (_) => ConsultationsPage(openConsultationId: cid),
              ),
            );
          }
          return;
        }
        if (payload.startsWith('nav_vaccine:')) {
          final rawId = payload.substring('nav_vaccine:'.length).trim();
          final vid = int.tryParse(rawId);
          if (vid != null) {
            pushOnTab(
              0,
              MaterialPageRoute<void>(
                builder: (_) => VaccinesPage(openVaccineId: vid),
              ),
            );
          }
          return;
        }
        return;
    }
  }
}
