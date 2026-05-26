import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/face_baby_app.dart';
import '../i18n/app_i18n.dart';
import '../theme/app_theme.dart';
import '../utils/portal_page_route.dart';
import '../utils/portal_time_of_day.dart';
import '../services/firebase/account_deletion_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/premium/premium_service.dart';
import '../widgets/card_box.dart';
import '../widgets/dev_qa_tools_section.dart';
import '../utils/portal_layout.dart';
import '../widgets/loading_scope.dart';
import 'alerts_settings_page.dart';
import 'contact_page.dart';
import 'family_tree_page.dart';
import 'ai/ai_baby_history_page.dart';
import 'mother_profile_page.dart';
import 'units_settings_page.dart';
import 'privacy_policy_page.dart';
import 'reports/reports_hub_page.dart';
import 'terms_of_use_page.dart';
import 'premium/premium_paywall_screen.dart';

/// Confirmação explícita (palavra em inglês, igual para todos os idiomas da app).
const _kAccountDeleteConfirmWord = 'delete';

Future<bool> _promptTypeDeleteToConfirmWord(BuildContext ctx, S s) async {
  final controller = TextEditingController();
  try {
    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final matches = controller.text.trim().toLowerCase() ==
                _kAccountDeleteConfirmWord;
            return AlertDialog(
              title: Text(s.deleteAccountTypeWordTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.deleteAccountTypeWordInstruction),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: s.deleteAccountTypeWordFieldLabel,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setLocalState(() {}),
                      onSubmitted: (_) {
                        final okSubmit = controller.text.trim().toLowerCase() ==
                            _kAccountDeleteConfirmWord;
                        if (okSubmit && dialogCtx.mounted)
                          Navigator.of(dialogCtx).pop(true);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: Text(s.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                  ),
                  onPressed:
                      matches ? () => Navigator.of(dialogCtx).pop(true) : null,
                  child: Text(s.deleteAccountConfirm),
                ),
              ],
            );
          },
        );
      },
    );
    return result == true;
  } finally {
    controller.dispose();
  }
}

String _userVisibleDeleteError(Object e) {
  if (e is FirebaseAuthException) {
    final m = e.message?.trim();
    if (m != null && m.isNotEmpty) return m;
    return e.code;
  }
  if (e is StateError) return e.message;
  return '$e'.replaceFirst(RegExp(r'^Bad state:\s*'), '');
}

TextStyle _deleteReauthSectionStyle(BuildContext context) {
  return TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppTheme.textSecondary.withAlpha(235),
    height: 1.2,
  );
}

Widget _deleteReauthSectionLabel(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: _deleteReauthSectionStyle(context)),
  );
}

Widget _deleteReauthOrDivider(BuildContext context, S s) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            s.deleteAccountReauthOrDivider,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.textMuted.withAlpha(220),
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
    ),
  );
}

Future<bool> _promptReauthenticateForDeletion(BuildContext ctx, S s) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final hasGoogle = user.providerData.any((p) => p.providerId == 'google.com');
  final hasPassword = user.providerData.any((p) => p.providerId == 'password');

  if (!hasGoogle && !hasPassword) {
    if (!ctx.mounted) return false;
    ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(s.deleteAccountReauthCantPassword)));
    return false;
  }

  final passCtrl = TextEditingController();
  final accountEmail = user.email?.trim() ?? '';
  const googleLogoAsset = 'assets/google_g_logo.png';
  const deleteBtnStyle = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(Color(0xFFFF3B30)),
    foregroundColor: WidgetStatePropertyAll(Colors.white),
  );

  Future<void> toastErr(String msg) async {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  try {
    return await showDialog<bool>(
          context: ctx,
          barrierDismissible: false,
          builder: (dialogCtx) {
            return AlertDialog(
              title: Text(s.deleteAccountReauthTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.deleteAccountReauthBody,
                      style: TextStyle(
                        height: 1.4,
                        color: AppTheme.textSecondary.withAlpha(240),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasGoogle) ...[
                      const SizedBox(height: 18),
                      _deleteReauthSectionLabel(
                        dialogCtx,
                        s.deleteAccountReauthGoogleSection,
                      ),
                      if (accountEmail.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            s.deleteAccountReauthGoogleAccountHint(
                                accountEmail),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary.withAlpha(220),
                              height: 1.25,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: deleteBtnStyle,
                          icon: Image.asset(
                            googleLogoAsset,
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                          label: Text(s.deleteAccountReauthGoogle),
                          onPressed: () async {
                            try {
                              await AuthService.instance
                                  .reauthenticateWithGoogle();
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop(true);
                              }
                            } catch (e) {
                              await toastErr(_userVisibleDeleteError(e));
                            }
                          },
                        ),
                      ),
                    ],
                    if (hasGoogle && hasPassword)
                      _deleteReauthOrDivider(dialogCtx, s),
                    if (hasPassword) ...[
                      if (!hasGoogle) const SizedBox(height: 18),
                      _deleteReauthSectionLabel(
                        dialogCtx,
                        s.deleteAccountReauthPasswordSection,
                      ),
                      TextFormField(
                        initialValue: accountEmail,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: s.deleteAccountReauthEmailLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        autofocus: !hasGoogle,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: s.deleteAccountReauthPasswordHint,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) async {
                          final p = passCtrl.text.trim();
                          if (p.isEmpty) {
                            await toastErr(s.deleteAccountReauthPasswordRequired);
                            return;
                          }
                          try {
                            await AuthService.instance
                                .reauthenticateWithPassword(password: p);
                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop(true);
                            }
                          } catch (e) {
                            await toastErr(_userVisibleDeleteError(e));
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: deleteBtnStyle,
                          onPressed: () async {
                            final p = passCtrl.text.trim();
                            if (p.isEmpty) {
                              await toastErr(
                                  s.deleteAccountReauthPasswordRequired);
                              return;
                            }
                            try {
                              await AuthService.instance
                                  .reauthenticateWithPassword(password: p);
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop(true);
                              }
                            } catch (e) {
                              await toastErr(_userVisibleDeleteError(e));
                            }
                          },
                          child: Text(s.deleteAccountReauthContinue),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: Text(s.cancel),
                ),
              ],
            );
          },
        ) ??
        false;
  } finally {
    passCtrl.dispose();
  }
}

Future<void> _inviteFriendShare(BuildContext context) async {
  final s = S.of(context);
  await Share.share(s.settingsInviteShareText);
}

Future<void> _openStoreRating(BuildContext context) async {
  final s = S.of(context);
  if (kIsWeb) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.settingsRateCouldNotOpen)));
    return;
  }
  final uri = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? Uri.parse('https://apps.apple.com/search?term=FaceBaby')
      : Uri.parse(
          'https://play.google.com/store/apps/details?id=com.facebaby.app');
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.settingsRateCouldNotOpen)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.settingsRateCouldNotOpen)));
    }
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(s.deleteAccountTitle),
          content: Text(s.deleteAccountBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(s.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.deleteAccountConfirm),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final confirmWord = await _promptTypeDeleteToConfirmWord(context, s);
    if (confirmWord != true) return;
    if (!context.mounted) return;

    final verified = await _promptReauthenticateForDeletion(context, s);
    if (verified != true || !context.mounted) return;

    Future<void> onSuccessUx() async {
      FaceBabyApp.navigatorKey.currentState?.popUntil((r) => r.isFirst);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.deleteAccountSuccess)));
    }

    try {
      await LoadingScope.of(context).run(
        () => AccountDeletionService.instance.deleteAllUserDataAndAccount(),
        label: s.deleteAccountDeleting,
      );
      await onSuccessUx();
    } on AccountDeletionRequiresRecentLogin catch (_) {
      if (!context.mounted) return;
      final reVerified = await _promptReauthenticateForDeletion(context, s);
      if (reVerified != true || !context.mounted) return;
      try {
        await LoadingScope.of(context).run(
          () =>
              AccountDeletionService.instance.deleteFirebaseAuthAndLocalOnly(),
          label: s.deleteAccountDeleting,
        );
        await onSuccessUx();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_userVisibleDeleteError(e))),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_userVisibleDeleteError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final accent =
        Color.lerp(AppTheme.primaryPurple, AppTheme.primaryPink, 0.4)!;
    final nightTitleColor = PortalTimeOfDay.isNight(DateTime.now())
        ? PortalTimeOfDay.nightTextColor
        : null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          AppTheme.pageHPadding, 12, AppTheme.pageHPadding, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.settingsTitle,
            style: TextStyle(
              fontSize: portalSp(context, 24),
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: nightTitleColor,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            compact: true,
            icon: Icons.person_outline,
            title: s.settingsMotherProfile,
            onTap: () => pushPortalPage<void>(
              context,
              const MotherProfilePage(
                initialTab: MotherProfileInitialTab.preferences,
              ),
            ),
          ),
          _SettingsTile(
            compact: true,
            icon: Icons.family_restroom_outlined,
            title: s.settingsFamilyTree,
            onTap: () => pushPortalPage<void>(context, const FamilyTreePage()),
          ),
          _SettingsTile(
            compact: true,
            icon: Icons.auto_awesome_outlined,
            title: s.settingsAiBabyHistory,
            onTap: () =>
                pushPortalPage<void>(context, const AiBabyHistoryPage()),
          ),
          _SettingsTile(
            compact: true,
            icon: Icons.insert_chart_outlined,
            title: s.reportsTitle,
            onTap: () => pushPortalPage<void>(context, const ReportsHubPage()),
          ),
          const _SettingsRulerDivider(widthFactor: 0.38),
          _SettingsTile(
            compact: true,
            icon: Icons.ios_share_outlined,
            title: s.settingsTellFriend,
            onTap: () => _inviteFriendShare(context),
          ),
          _SettingsTile(
            compact: true,
            icon: Icons.star_rate_rounded,
            title: s.settingsRateUs,
            onTap: () => _openStoreRating(context),
          ),
          _SettingsTile(
            compact: true,
            icon: Icons.mail_outline,
            title: s.contactTitle,
            onTap: () => pushPortalPage<void>(context, const ContactPage()),
          ),
          const _SettingsRulerDivider(widthFactor: 0.94),
          _SettingsTile(
            compact: true,
            icon: Icons.notifications_none,
            title: s.settingsAlerts,
            onTap: () =>
                pushPortalPage<void>(context, const AlertsSettingsPage()),
          ),
          _SettingsTile(
            compact: true,
            icon: Icons.settings_rounded,
            title: s.unitsTitle,
            onTap: () =>
                pushPortalPage<void>(context, const UnitsSettingsPage()),
          ),
          const _SettingsRulerDivider(widthFactor: 0.94),
          _SettingsTile(
            compact: true,
            icon: Icons.description_outlined,
            title: s.settingsTermsOfUse,
            onTap: () => pushPortalPage<void>(context, const TermsOfUsePage()),
          ),
          _SettingsTile(
            compact: true,
            icon: Icons.privacy_tip_outlined,
            title: s.settingsPrivacyPolicy,
            onTap: () =>
                pushPortalPage<void>(context, const PrivacyPolicyPage()),
          ),
          const _SettingsRulerDivider(widthFactor: 0.94),
          ListenableBuilder(
            listenable: PremiumService.instance,
            builder: (context, _) {
              final plus = PremiumService.instance.isPremium;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => openPremiumPaywall(context),
                  child: CardBox(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            color: accent, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.settingsPlusCardTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: portalSp(context, 15),
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.settingsPremiumBannerHint,
                                style: TextStyle(
                                  fontSize: portalSp(context, 12.5),
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (plus)
                          Padding(
                            padding: const EdgeInsets.only(left: 6, top: 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withAlpha(36),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'PLUS',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    color: accent),
                              ),
                            ),
                          ),
                        Icon(Icons.chevron_right,
                            color: accent.withAlpha(200), size: 22),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const DevQaToolsSection(),
          const _SettingsRulerDivider(widthFactor: 0.42),
          _DangerSettingsTile(
            compact: true,
            icon: Icons.delete_forever_rounded,
            title: s.deleteAccountTitle,
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }
}

/// Divisor horizontal simples entre grupos da página Mais.
class _SettingsRulerDivider extends StatelessWidget {
  const _SettingsRulerDivider({this.widthFactor = 0.9});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final color = Colors.black.withAlpha(42);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool compact;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = compact ? 12.0 : 16.0;
    final vPad = compact ? 10.0 : 16.0;
    final iconSize = compact ? 21.0 : 24.0;
    final fontSize = compact ? 14.0 : 15.0;
    final bottom = compact ? 5.0 : 10.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: CardBox(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            children: [
              Icon(icon,
                  size: iconSize, color: AppTheme.textPrimary.withAlpha(220)),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 4,
                  softWrap: true,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: portalSp(context, fontSize),
                    height: 1.2,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: compact ? 20 : 24, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool compact;
  final VoidCallback? onTap;

  const _DangerSettingsTile(
      {required this.icon,
      required this.title,
      this.compact = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final hPad = compact ? 12.0 : 16.0;
    final vPad = compact ? 10.0 : 16.0;
    final iconSize = compact ? 21.0 : 24.0;
    final fontSize = compact ? 14.0 : 15.0;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 5 : 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: CardBox(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            children: [
              Icon(icon, size: iconSize, color: const Color(0xFFFF3B30)),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 4,
                  softWrap: true,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: portalSp(context, fontSize),
                    height: 1.2,
                    color: const Color(0xFFFF3B30),
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: compact ? 20 : 24, color: const Color(0xFFFF3B30)),
            ],
          ),
        ),
      ),
    );
  }
}
