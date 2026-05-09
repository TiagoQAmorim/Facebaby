import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/app_i18n.dart';
import '../models/consultation_record.dart';
import '../theme/app_theme.dart';

Future<void> showConsultationDetailSheet(BuildContext context, ConsultationRecord r) async {
  final s = S.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      String fmtDt(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} · '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

      Future<void> openTel(String raw) async {
        final digits = raw.replaceAll(RegExp(r'\s'), '');
        final uri = Uri(scheme: 'tel', path: digits);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }

      Future<void> openMaps(String address) async {
        final q = Uri.encodeComponent(address);
        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                r.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.2),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.schedule_rounded, size: 22, color: AppTheme.secondary.withAlpha(230)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.consultationDetailWhen, style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(fmtDt(r.occurredAt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
              if (r.phone != null && r.phone!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.phone_outlined, size: 22, color: AppTheme.secondary.withAlpha(230)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.consultationDetailPhone, style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => openTel(r.phone!),
                            child: Text(
                              r.phone!,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.primary, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (r.address != null && r.address!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_outlined, size: 22, color: AppTheme.secondary.withAlpha(230)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.consultationDetailAddress, style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => openMaps(r.address!),
                            child: Text(
                              r.address!,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.35, color: AppTheme.primary, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(s.consultationDetailNotes, style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Text(r.notes!, style: TextStyle(fontSize: 15, height: 1.4, color: Colors.black.withAlpha(200))),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}
