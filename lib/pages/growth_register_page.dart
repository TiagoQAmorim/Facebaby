import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import 'growth_dashboard_page.dart';

/// Atalho "Crescimento": mesma dashboard de métricas (peso / altura / cabeça / resumo).
class GrowthRegisterPage extends StatelessWidget {
  const GrowthRegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return GrowthDashboardPage(appBarTitle: s.growth);
  }
}
