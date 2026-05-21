import 'package:flutter/material.dart';

import 'home_recent_memories_section.dart';
import 'weekly_photo_home_section.dart';

const int _kPanelFillAlpha = 142;
const int _kPanelBorderAlpha = 92;

/// Painel único na Home: últimas memórias + foto da semana (fundo semitransparente).
class HomeMemoriesWeeklyPanel extends StatelessWidget {
  const HomeMemoriesWeeklyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(_kPanelFillAlpha),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(_kPanelBorderAlpha)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              HomeRecentMemoriesSection(inSharedPanel: true),
              WeeklyPhotoHomeSection(inSharedPanel: true),
            ],
          ),
        ),
      ),
    );
  }
}
