import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../models/baby_memory.dart';
import '../../models/memory_badge.dart';
import '../../theme/app_theme.dart';
import '../../utils/memory_moment_localizations.dart';
import '../../utils/measurement_format.dart';
import '../../utils/photo_b64.dart';
import 'memory_badge_icon.dart';

/// Versão para exportar (captura JPG/PDF): largura fixa, altura intrínseca, sem scroll.
class MemoryShareCard extends StatelessWidget {
  final MemoryBadge badge;
  final BabyMemory memory;
  final String tipText;

  static const _purpleCardBg = Color(0xFFF3EEFF);
  static const _purpleTitle = Color(0xFF7B5FB8);
  static const _chipAgeBg = Color(0xFFEDE8FF);
  static const _chipWeightBg = Color(0xFFFFE9F5);
  static const _chipHeightBg = Color(0xFFE5F2FF);
  static const _chipMoodBg = Color(0xFFFFF6E5);

  /// Se preenchido (ex.: foto descarregada de [BabyMemory.photoUrl]), usa estes bytes em vez de [memory.photoB64].
  final Uint8List? photoBytesOverride;

  const MemoryShareCard({
    super.key,
    required this.badge,
    required this.memory,
    required this.tipText,
    this.photoBytesOverride,
  });

  static String weightStr(double? w) => MeasurementFormat.weight(w, decimalsKg: 2);

  static String heightStr(double? h) => MeasurementFormat.length(h, decimalsCm: 1);

  static String moodStr(String? s) =>
      (s == null || s.trim().isEmpty) ? '—' : s.trim();

  static String ageStr(String? s) => (s == null || s.trim().isEmpty) ? '—' : s.trim();

  @override
  Widget build(BuildContext context) {
    const w = 400.0;
    final photoBytes = photoBytesOverride ?? decodePhotoB64(memory.photoB64);
    final desc = (memory.description ?? '').trim();
    const radius = 20.0;
    const side = 172.0;
    final strings = S.of(context);

    Widget photo = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: side,
        height: side,
        child: photoBytes == null
            ? Container(
                color: MemoryBadgeIcon.mutedDiskBackground,
                alignment: Alignment.center,
                child: MemoryBadgeIcon(
                  badge: badge,
                  muted: true,
                  size: 54,
                  shape: MemoryBadgeIconShape.original,
                ),
              )
            : Image.memory(photoBytes, fit: BoxFit.cover),
      ),
    );

    final descStyle = TextStyle(
      color: AppTheme.textPrimary.withAlpha(204),
      height: 1.45,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );

    final descWidget = desc.isEmpty
        ? Text(strings.memoryNoDescription, style: descStyle.copyWith(color: AppTheme.textMuted))
        : null;

    final notes = (memory.motherNotes ?? '').trim();

    return Material(
      color: AppTheme.background,
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MemoryBadgeIcon(
                    badge: badge,
                    muted: photoBytes == null,
                    size: 40,
                    shape: MemoryBadgeIconShape.original,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).memoryBadgeTitle(badge),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                            height: 1.18,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          formatMemoryMomentDateTime(context, memory.memoryDate),
                          style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (descWidget != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    photo,
                    const SizedBox(width: 16),
                    Expanded(child: descWidget),
                  ],
                )
              else
                LayoutBuilder(
                  builder: (context, c) {
                    // Dentro do Padding, `c.maxWidth` já é a largura útil do cartão.
                    final remainingW = (c.maxWidth - side - 16).clamp(90.0, 10000.0);
                    if (remainingW < 120) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(alignment: Alignment.centerLeft, child: photo),
                          const SizedBox(height: 14),
                          Text(desc, style: descStyle),
                        ],
                      );
                    }
                    final tp = TextPainter(
                      text: TextSpan(text: desc, style: descStyle),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout(maxWidth: remainingW);

                    final cutPos = tp.getPositionForOffset(Offset(remainingW, side));
                    final cut = cutPos.offset.clamp(0, desc.length);
                    final lead = desc.substring(0, cut).trimRight();
                    final tail = desc.substring(cut).trimLeft();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            photo,
                            const SizedBox(width: 16),
                            Expanded(child: Text(lead.isEmpty ? desc : lead, style: descStyle)),
                          ],
                        ),
                        if (tail.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(tail, style: descStyle),
                        ],
                      ],
                    );
                  },
                ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(11, 12, 11, 11),
                decoration: BoxDecoration(color: _purpleCardBg, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.memoryMomentInfoTitle,
                      style: TextStyle(color: _purpleTitle, fontWeight: FontWeight.w900, fontSize: 13.5),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: _ShareStatChip(
                            bg: _chipAgeBg,
                            iconBg: const Color(0xFFD9CCFF),
                            icon: Icons.calendar_month_rounded,
                            iconColor: AppTheme.primaryPurple,
                            label: strings.memoryStatAgeLabel,
                            value: ageStr(memory.babyAgeAtMoment),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _ShareStatChip(
                            bg: _chipWeightBg,
                            iconBg: const Color(0xFFFFD0EA),
                            icon: Icons.monitor_weight_rounded,
                            iconColor: AppTheme.primaryPink,
                            label: strings.memoryStatWeightLabel,
                            value: weightStr(memory.weightAtMoment),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _ShareStatChip(
                            bg: _chipHeightBg,
                            iconBg: const Color(0xFFCCE6FF),
                            icon: Icons.straighten_rounded,
                            iconColor: AppTheme.babyBlue,
                            label: strings.memoryStatHeightLabel,
                            value: heightStr(memory.heightAtMoment),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _ShareStatChip(
                            bg: _chipMoodBg,
                            iconBg: const Color(0xFFFFEDC4),
                            icon: Icons.sentiment_satisfied_alt_rounded,
                            iconColor: AppTheme.yellow,
                            label: strings.memoryStatMoodLabel,
                            value: moodStr(memory.moodAtMoment),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note_alt_rounded, color: AppTheme.yellow.withAlpha(220), size: 21),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.memoryMotherNotesLabel,
                            style:
                                TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w900, fontSize: 13.5),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            notes,
                            style:
                                TextStyle(color: AppTheme.textPrimary.withAlpha(210), height: 1.4, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 17),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _purpleCardBg, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: _purpleTitle, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          strings.memoryTipForYouTitle,
                          style: TextStyle(color: _purpleTitle, fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Text(
                      tipText,
                      style: TextStyle(color: AppTheme.textPrimary.withAlpha(200), height: 1.43, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.center,
                child: Text(
                  strings.memoryFooterBranding,
                  style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareStatChip extends StatelessWidget {
  final Color bg;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _ShareStatChip({
    required this.bg,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, height: 1.05),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, height: 1.08),
          ),
        ],
      ),
    );
  }
}
