import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../services/firebase/weekly_photo_report_service.dart';
import '../theme/app_theme.dart';

/// Link discreto «Denunciar» na Foto da Semana pública.
class WeeklyPhotoReportLink extends StatelessWidget {
  const WeeklyPhotoReportLink({
    super.key,
    required this.publicMemoryId,
    required this.photoUrl,
    this.targetUserId,
  });

  final String publicMemoryId;
  final String photoUrl;
  final String? targetUserId;

  Future<void> _openReportDialog(BuildContext context) async {
    final memId = publicMemoryId.trim();
    if (memId.isEmpty) return;

    if (FirebaseAuth.instance.currentUser == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).weeklyPhotoReportNeedLogin)),
      );
      return;
    }

    final s = S.of(context);
    final ctrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(s.weeklyPhotoReportTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.weeklyPhotoReportHint,
                  style: const TextStyle(
                    height: 1.4,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: WeeklyPhotoReportService.maxMessageLength,
                  decoration: InputDecoration(
                    labelText: s.weeklyPhotoReportMessageLabel,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().length <
                    WeeklyPhotoReportService.minMessageLength) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(s.weeklyPhotoReportMessageTooShort)),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ctaPrimary,
                foregroundColor: Colors.white,
              ),
              child: Text(s.weeklyPhotoReportSubmit),
            ),
          ],
        );
      },
    );

    if (submitted != true || !context.mounted) {
      ctrl.dispose();
      return;
    }

    final message = ctrl.text;
    ctrl.dispose();
    try {
      await WeeklyPhotoReportService.instance.submitReport(
        publicMemoryId: memId,
        message: message,
        photoUrl: photoUrl,
        targetUserId: targetUserId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.weeklyPhotoReportSuccess)),
      );
    } on StateError catch (e) {
      if (!context.mounted) return;
      final msg = switch (e.message) {
        'not_authenticated' => s.weeklyPhotoReportNeedLogin,
        'message_too_short' => s.weeklyPhotoReportMessageTooShort,
        'message_too_long' => s.weeklyPhotoReportMessageTooLong,
        _ => s.weeklyPhotoReportFailed,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.weeklyPhotoReportFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (publicMemoryId.trim().isEmpty) return const SizedBox.shrink();
    final s = S.of(context);
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: () => _openReportDialog(context),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          s.weeklyPhotoReportLink,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
