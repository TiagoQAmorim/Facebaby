import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../theme/app_theme.dart';
import '../services/firebase/account_deletion_service.dart';
import '../services/firebase/auth_service.dart';
import '../widgets/card_box.dart';
import '../utils/portal_layout.dart';
import '../widgets/language_picker.dart';
import '../widgets/loading_scope.dart';
import 'alerts_settings_page.dart';
import 'contact_page.dart';
import 'mother_profile_page.dart';
import 'units_settings_page.dart';

String _userVisibleDeleteError(Object e) {
  if (e is FirebaseAuthException) {
    final m = e.message?.trim();
    if (m != null && m.isNotEmpty) return m;
    return e.code;
  }
  if (e is StateError) return e.message;
  return '$e'.replaceFirst(RegExp(r'^Bad state:\s*'), '');
}

Future<bool> _promptReauthenticateForDeletion(BuildContext ctx, S s) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final hasGoogle = user.providerData.any((p) => p.providerId == 'google.com');
  final hasPassword = user.providerData.any((p) => p.providerId == 'password');

  if (!hasGoogle && !hasPassword) {
    if (!ctx.mounted) return false;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(s.deleteAccountReauthCantPassword)));
    return false;
  }

  final passCtrl = TextEditingController();

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
                    Text(s.deleteAccountReauthBody),
                    if (hasPassword) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: s.deleteAccountReauthPasswordHint,
                          border: const OutlineInputBorder(),
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
                if (hasGoogle)
                  SizedBox(
                    width: double.maxFinite,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF3B30), foregroundColor: Colors.white),
                      onPressed: () async {
                        try {
                          await AuthService.instance.reauthenticateWithGoogle();
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
                        } catch (e) {
                          await toastErr(_userVisibleDeleteError(e));
                        }
                      },
                      child: Text(s.deleteAccountReauthGoogle),
                    ),
                  ),
                if (hasPassword)
                  SizedBox(
                    width: double.maxFinite,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF3B30)),
                      onPressed: () async {
                        final p = passCtrl.text.trim();
                        if (p.isEmpty) {
                          await toastErr(s.deleteAccountReauthPasswordHint);
                          return;
                        }
                        try {
                          await AuthService.instance.reauthenticateWithPassword(password: p);
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
                        } catch (e) {
                          await toastErr(_userVisibleDeleteError(e));
                        }
                      },
                      child: Text(s.deleteAccountReauthContinue),
                    ),
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
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF3B30)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.deleteAccountConfirm),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    if (!context.mounted) return;

    Future<void> onSuccessUx() async {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.deleteAccountSuccess)));
      Navigator.of(context).popUntil((r) => r.isFirst);
    }

    try {
      await LoadingScope.of(context).run(
        () => AccountDeletionService.instance.deleteAllUserDataAndAccount(),
        label: s.deleteAccountDeleting,
      );
      await onSuccessUx();
    } on AccountDeletionRequiresRecentLogin catch (_) {
      if (!context.mounted) return;
      final verified = await _promptReauthenticateForDeletion(context, s);
      if (verified != true || !context.mounted) return;
      try {
        await LoadingScope.of(context).run(
          () => AccountDeletionService.instance.deleteFirebaseAuthAndLocalOnly(),
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
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(AppTheme.pageHPadding, 24, AppTheme.pageHPadding, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.settingsTitle, style: TextStyle(fontSize: portalSp(context, 28), fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 18),
          _SettingsTile(
            icon: Icons.settings_rounded,
            title: s.unitsTitle,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UnitsSettingsPage())),
          ),
          _SettingsTile(
            icon: Icons.person_outline,
            title: s.settingsMotherProfile,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MotherProfilePage()),
            ),
          ),
          _SettingsTile(
            icon: Icons.notifications_none,
            title: s.settingsAlerts,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AlertsSettingsPage()),
            ),
          ),
          _SettingsTile(
            icon: Icons.mail_outline,
            title: s.contactTitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ContactPage()),
            ),
          ),
          _SettingsTile(
            icon: Icons.language,
            title: s.language,
            onTap: () => showLanguagePicker(context),
          ),
          const SizedBox(height: 18),
          Text(
            s.settingsSoonTitle,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: portalSp(context, 16), color: Colors.black.withAlpha(160)),
          ),
          const SizedBox(height: 10),
          _SettingsTile(icon: Icons.star_rate_rounded, title: s.settingsRateUs, enabled: false, badge: s.settingsSoonBadge),
          _SettingsTile(icon: Icons.description_outlined, title: s.settingsTermsOfUse, enabled: false, badge: s.settingsSoonBadge),
          _SettingsTile(icon: Icons.privacy_tip_outlined, title: s.settingsPrivacyPolicy, enabled: false, badge: s.settingsSoonBadge),
          _SettingsTile(icon: Icons.favorite_border_rounded, title: s.settingsSpecialThanks, enabled: false, badge: s.settingsSoonBadge),
          _SettingsTile(icon: Icons.share_outlined, title: s.settingsTellFriend, enabled: false, badge: s.settingsSoonBadge),
          const SizedBox(height: 8),
          _DangerSettingsTile(
            icon: Icons.delete_forever_rounded,
            title: s.deleteAccountTitle,
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final bool enabled;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.badge,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: enabled ? onTap : null,
        child: CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: enabled ? null : Colors.black.withAlpha(120)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 4,
                  softWrap: true,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: portalSp(context, 15),
                    height: 1.25,
                    color: enabled ? AppTheme.textPrimary : Colors.black.withAlpha(135),
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: portalSp(context, 11), color: Colors.black.withAlpha(150)),
                  ),
                )
              else
                Icon(Icons.chevron_right, color: enabled ? null : Colors.black.withAlpha(90)),
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
  final VoidCallback? onTap;

  const _DangerSettingsTile({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFFF3B30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 4,
                  softWrap: true,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: portalSp(context, 15),
                    height: 1.25,
                    color: const Color(0xFFFF3B30),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFFF3B30)),
            ],
          ),
        ),
      ),
    );
  }
}
