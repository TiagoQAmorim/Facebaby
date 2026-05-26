import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Banner discreto para Play In-App Update (flexível + reinício).
class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UpdateService.instance,
      builder: (context, _) {
        final phase = UpdateService.instance.phase;
        if (phase == AppUpdateUiPhase.idle) {
          return const SizedBox.shrink();
        }
        final s = S.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            elevation: 6,
            shadowColor: Colors.black26,
            color: Colors.white.withAlpha(248),
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withAlpha(40)),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withAlpha(18),
                    const Color(0xFFFFF8FC),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: _BannerBody(phase: phase, strings: s),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.phase, required this.strings});

  final AppUpdateUiPhase phase;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final svc = UpdateService.instance;

    switch (phase) {
      case AppUpdateUiPhase.readyToInstall:
        return _row(
          icon: Icons.system_update_alt_rounded,
          message: strings.appUpdateReadyToRestart,
          primaryLabel: strings.appUpdateRestart,
          onPrimary: () => svc.completeFlexibleUpdate(),
        );
      case AppUpdateUiPhase.downloading:
        return _row(
          icon: Icons.cloud_download_outlined,
          message: strings.appUpdateDownloading,
          showProgress: true,
        );
      case AppUpdateUiPhase.updateAvailable:
        return _row(
          icon: Icons.favorite_rounded,
          message: strings.appUpdateAvailableMessage,
          primaryLabel: strings.appUpdateActionUpdate,
          secondaryLabel: strings.appUpdateActionLater,
          onPrimary: () => svc.startFlexibleUpdate(),
          onSecondary: () => svc.dismissAvailableBanner(),
        );
      case AppUpdateUiPhase.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _row({
    required IconData icon,
    required String message,
    String? primaryLabel,
    String? secondaryLabel,
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
    bool showProgress = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppTheme.primary, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  height: 1.35,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  minHeight: 3,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  backgroundColor: Color(0xFFE8E4F5),
                  color: AppTheme.primary,
                ),
              ],
            ],
          ),
        ),
        if (primaryLabel != null && onPrimary != null) ...[
          const SizedBox(width: 6),
          TextButton(
            onPressed: onPrimary,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: Text(
              primaryLabel,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
        if (secondaryLabel != null && onSecondary != null)
          TextButton(
            onPressed: onSecondary,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            child: Text(
              secondaryLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
