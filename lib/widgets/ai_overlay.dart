import 'package:flutter/material.dart';
import '../controllers/ai_controller.dart';
import '../theme/app_theme.dart';

class AiOverlay extends StatelessWidget {
  final AiState state;
  final VoidCallback onClose;

  const AiOverlay({super.key, required this.state, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final listening = state == AiState.listening;

    return Material(
      color: Colors.white.withAlpha(245),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'FaceBaby IA',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.secondary),
                  ),
                  IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
                ],
              ),
              const Spacer(),
              Text(
                listening ? 'Estou escutando...' : 'Estou respondendo...',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.secondary),
              ),
              const SizedBox(height: 34),
              Container(
                height: 190,
                width: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondary.withAlpha(20),
                ),
                child: Center(
                  child: Container(
                    height: 130,
                    width: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: AppTheme.secondary.withAlpha(77), blurRadius: 34)],
                    ),
                    child: const Icon(Icons.mic, size: 68, color: AppTheme.secondary),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                listening
                    ? 'Fale sobre amamentação, sono, fraldas, saúde ou dúvidas sobre o bebê.'
                    : 'Oi, mamãe! Posso ajudar com um resumo da rotina, alertas ou dúvidas rápidas.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppTheme.text),
              ),
              const Spacer(),
              FilledButton.tonal(onPressed: onClose, child: const Text('Desativar IA')),
            ],
          ),
        ),
      ),
    );
  }
}
