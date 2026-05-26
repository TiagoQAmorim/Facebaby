import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/portal_layout.dart';

/// Card visual da IA Babá (borda lilás/rosa, ícone robô).
class AiInsightCard extends StatelessWidget {
  const AiInsightCard({
    super.key,
    required this.title,
    required this.body,
    this.onDismiss,
    this.maxLines = 3,
  });

  final String title;
  final String body;
  final VoidCallback? onDismiss;
  final int maxLines;

  static const _robotEmoji = '🤖';

  @override
  Widget build(BuildContext context) {
    final padR = onDismiss != null ? 36.0 : 12.0;
    final displayBody = body.trim().startsWith(_robotEmoji)
        ? body.trim()
        : '$_robotEmoji ${body.trim()}';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(12, 12, padR, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFCE4EC).withAlpha(245),
                const Color(0xFFF3E5F5).withAlpha(250),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFCE93D8).withAlpha(160),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE91E8C).withAlpha(42),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFF9C27B0).withAlpha(28),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFAB47BC), Color(0xFFE91E8C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9C27B0).withAlpha(80),
                      blurRadius: 10,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _robotEmoji,
                  style: TextStyle(fontSize: portalSp(context, 20)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: portalSp(context, 13),
                        color: const Color(0xFF6A1B9A),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayBody,
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF3D2A4F).withAlpha(215),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        fontSize: portalSp(context, 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onDismiss != null)
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 20),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: AppTheme.textSecondary.withAlpha(230),
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
      ],
    );
  }
}
