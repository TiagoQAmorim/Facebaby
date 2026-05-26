import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../theme/app_theme.dart';

/// Confirmação ao marcar memória como pública (Foto da Semana).
///
/// Retorna `true` para tornar pública, `false` ou `null` para manter privada.
Future<bool> showWeeklyPhotoPublicConfirmDialog(BuildContext context) async {
  final s = S.of(context);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(s.weeklyPhotoConfirmTitle),
      content: Text(s.weeklyPhotoConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(s.weeklyPhotoConfirmNo),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.ctaPrimary,
            foregroundColor: Colors.white,
          ),
          child: Text(s.weeklyPhotoConfirmYes),
        ),
      ],
    ),
  );
  return result == true;
}
