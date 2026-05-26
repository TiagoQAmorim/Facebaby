import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_baby_history_form.dart';

/// Histórico do bebê para personalizar a IA Babá.
class AiBabyHistoryPage extends StatelessWidget {
  const AiBabyHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withAlpha(235),
        elevation: 0,
        title: Text(
          s.aiBabyHistoryTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF4A148C),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF6A1B9A)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Material(
            color: Colors.white.withAlpha(235),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: const Color(0xFFE1BEE7).withAlpha(100)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AiBabyHistoryForm(
                showActions: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Atalho compacto (Família, configurações, perfil).
class AiBabyHistoryLinkTile extends StatelessWidget {
  const AiBabyHistoryLinkTile({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.auto_awesome_outlined, color: AppTheme.primaryPink),
      title: Text(
        s.aiBabyHistoryTitle,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        s.aiBabyHistoryLinkSubtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.black.withAlpha(140),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AiBabyHistoryPage()),
      ),
    );
  }
}
