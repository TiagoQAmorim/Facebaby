import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';
import '../../utils/portal_layout.dart';
import 'report_page_shell.dart';

/// Ecrã temporário até cada relatório ter UI e dados definidos.
class ReportDetailStubPage extends StatelessWidget {
  const ReportDetailStubPage({
    super.key,
    required this.title,
    required this.anchorDay,
    this.periodHint,
  });

  final String title;
  final DateTime anchorDay;
  /// Ex.: intervalo da semana para contexto.
  final String? periodHint;

  static String formatDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static DateTime mondayOfWeekContaining(DateTime day) {
    final local = DateTime(day.year, day.month, day.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  static String weekRangeLabel(DateTime anyDayInWeek) {
    final start = mondayOfWeekContaining(anyDayInWeek);
    final end = start.add(const Duration(days: 6));
    return '${formatDay(start)} – ${formatDay(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dayStr = formatDay(anchorDay);

    final reportBg = reportScaffoldBackground();

    return Scaffold(
      backgroundColor: reportBg,
      appBar: AppBar(
        backgroundColor: reportBg,
        surfaceTintColor: reportBg,
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppTheme.pageHPadding, 20, AppTheme.pageHPadding, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.reportsHubAnchorLabel}: $dayStr',
                style: TextStyle(
                  fontSize: portalSp(context, 14),
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted,
                ),
              ),
              if (periodHint != null && periodHint!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  periodHint!,
                  style: TextStyle(fontSize: portalSp(context, 13.5), color: AppTheme.textMuted.withAlpha(220)),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                s.reportStubComingSoon,
                style: TextStyle(
                  fontSize: portalSp(context, 15),
                  height: 1.45,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
