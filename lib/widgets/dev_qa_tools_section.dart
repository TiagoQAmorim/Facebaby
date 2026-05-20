import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/dev_qa_account.dart';
import '../services/premium/premium_service.dart';
import '../theme/app_theme.dart';
import 'card_box.dart';

/// Secção «Ferramentas QA» em Mais (apenas debug / FACEBABY_QA_TOOLS).
class DevQaToolsSection extends StatefulWidget {
  const DevQaToolsSection({super.key});

  @override
  State<DevQaToolsSection> createState() => _DevQaToolsSectionState();
}

class _DevQaToolsSectionState extends State<DevQaToolsSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(okMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro QA: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DevQaAccount.available) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: PremiumService.instance,
      builder: (context, _) {
        final premium = PremiumService.instance;
        final forced = premium.isDebugPremiumForced;
        final uid = FirebaseAuth.instance.currentUser?.uid;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                'Ferramentas QA (teste)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            CardBox(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Conta: ${DevQaAccount.email}\nSenha: ${DevQaAccount.password}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withAlpha(170),
                    ),
                  ),
                  if (uid != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'UID: $uid',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black.withAlpha(120),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Premium forçado (dispositivo)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      forced
                          ? 'Tudo liberado neste aparelho.'
                          : 'Usa só premiumLifetime na nuvem.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withAlpha(130),
                      ),
                    ),
                    value: forced,
                    onChanged: _busy
                        ? null
                        : (v) => _run(
                              () => premium.setDebugPremiumForced(v),
                              v ? 'Premium QA ligado.' : 'Premium QA desligado.',
                            ),
                  ),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              DevQaAccount.signInOrCreate,
                              'Conta teste pronta. Complete o cadastro se for a primeira vez.',
                            ),
                    icon: const Icon(Icons.science_outlined, size: 20),
                    label: const Text('Entrar / criar conta teste + Premium'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () async {
                                await Clipboard.setData(
                                  const ClipboardData(
                                    text:
                                        'Email: ${DevQaAccount.email}\nSenha: ${DevQaAccount.password}',
                                  ),
                                );
                              },
                              'Credenciais copiadas.',
                            ),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copiar credenciais'),
                  ),
                  if (FirebaseAuth.instance.currentUser != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                premium.grantLifetimePremiumForCurrentUser,
                                'Premium vitalício gravado na nuvem.',
                              ),
                      child: const Text(
                        'Liberar Premium do utilizador actual',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
