import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../theme/app_theme.dart';
import 'ai_baby_history_form.dart';
import 'card_box.dart';

/// Aba «Histórico» na Família — formulário da IA Babá (sem página separada).
class FamilyAiBabyHistoryPanel extends StatelessWidget {
  const FamilyAiBabyHistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: AppTheme.primaryPink,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.aiBabyHistoryTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.aiBabyHistoryLinkSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: Colors.black.withAlpha(150),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const CardBox(
          frosted: true,
          child: AiBabyHistoryForm(
            showActions: true,
            showSubtitle: false,
            compact: true,
          ),
        ),
      ],
    );
  }
}
