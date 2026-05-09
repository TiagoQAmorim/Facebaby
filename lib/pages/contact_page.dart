import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../theme/app_theme.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  static const _to = 'tiago-famorim@hotmail.com';

  final _formKey = GlobalKey<FormState>();
  final _msgCtrl = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  String? _reqMessage(String? v, S s) => (v == null || v.trim().isEmpty) ? s.contactValidationRequired : null;

  int? _ageYearsFromIso(String? iso) {
    final raw = (iso ?? '').trim();
    if (raw.isEmpty) return null;
    final d = DateTime.tryParse(raw);
    if (d == null) return null;
    final now = DateTime.now();
    var years = now.year - d.year;
    final hasHadBirthday = (now.month > d.month) || (now.month == d.month && now.day >= d.day);
    if (!hasHadBirthday) years--;
    return years.clamp(0, 130);
  }

  Future<void> _send() async {
    final s = S.of(context);
    if (_sending) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _sending = true);
    try {
      final mother = CurrentBabyController.instance.currentMotherRow;
      final rawName = (mother?['name'] as String?)?.trim();
      final rawPhone = (mother?['phone'] as String?)?.trim();
      // O modelo atual não tem campo "email". Como fallback, se o utilizador gravou um email no campo de telefone,
      // usamos aqui; senão mandamos '—' no corpo.
      final rawEmail = (rawPhone != null && rawPhone.contains('@')) ? rawPhone : null;
      final ageYears = _ageYearsFromIso(mother?['birth_date'] as String?);

      final name = (rawName == null || rawName.isEmpty) ? '—' : rawName;
      final email = (rawEmail == null || rawEmail.isEmpty) ? '—' : rawEmail;
      final age = ageYears == null ? '—' : '$ageYears';
      final msg = _msgCtrl.text.trim();

      final subject = s.contactEmailSubject;
      final body = [
        '${s.contactBodyName} $name',
        '${s.contactBodyEmail} $email',
        '${s.contactBodyAge} $age',
        '',
        s.contactBodyMessage,
        msg,
      ].join('\n');

      // Evita que alguns apps de email exibam '+' no lugar de espaços.
      // `Uri(queryParameters: ...)` pode codificar espaços como '+'. Aqui forçamos `%20`.
      final uri = Uri.parse(
        'mailto:$_to?subject=${Uri.encodeQueryComponent(subject)}&body=${Uri.encodeQueryComponent(body)}',
      );

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.contactCouldNotOpenEmail)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.contactCouldNotOpenEmail} $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final mother = CurrentBabyController.instance.currentMotherRow;
    final rawName = (mother?['name'] as String?)?.trim();
    final rawPhone = (mother?['phone'] as String?)?.trim();
    final rawEmail = (rawPhone != null && rawPhone.contains('@')) ? rawPhone : null;
    final ageYears = _ageYearsFromIso(mother?['birth_date'] as String?);

    final name = (rawName == null || rawName.isEmpty) ? '—' : rawName;
    final email = (rawEmail == null || rawEmail.isEmpty) ? '—' : rawEmail;
    final age = ageYears == null ? '—' : '$ageYears';

    return Scaffold(
      appBar: AppBar(title: Text(s.contactTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.contactIntro, style: TextStyle(color: Colors.black.withAlpha(150), fontWeight: FontWeight.w600, height: 1.35)),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: name,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: s.contactFieldName,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: email,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: s.contactFieldEmail,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: age,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: s.contactFieldAge,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _msgCtrl,
                  minLines: 4,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: s.contactFieldMessage,
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => _reqMessage(v, s),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.ctaPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _sending ? null : _send,
                  icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                  label: Text(s.contactSend),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

