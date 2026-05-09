import 'package:flutter/material.dart';
import '../controllers/ai_controller.dart';
import '../theme/app_theme.dart';

class AiButton extends StatelessWidget {
  final AiState state;
  final VoidCallback onTap;

  const AiButton({super.key, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOn = state != AiState.off;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: isOn ? 64 : 58,
        width: isOn ? 64 : 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: isOn ? AppTheme.secondary : AppTheme.primary,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isOn ? AppTheme.secondary : AppTheme.primary).withAlpha(72),
              blurRadius: 20,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Icon(
          Icons.mic,
          size: 30,
          color: isOn ? AppTheme.secondary : AppTheme.primary,
        ),
      ),
    );
  }
}
