import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin_models.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_permissions.dart';
import '../services/admin_repository.dart';
import '../widgets/admin_layout.dart';

enum _TargetMode { all, users, babyAge, country }

class MessagingPage extends StatefulWidget {
  const MessagingPage({super.key});

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  final _linkUrl = TextEditingController();
  final _linkButtonLabel = TextEditingController();
  final _actionRoute = TextEditingController();
  final _imageUrl = TextEditingController();
  final _imageAlt = TextEditingController();
  String _messageType = 'admin_ad';
  String _floatingAudience = 'all';
  String _dismissMode = 'both';
  int _priority = 10;
  DateTime? _startsAt;
  DateTime? _endsAt;
  _TargetMode _mode = _TargetMode.all;
  int _ageMin = 0;
  int _ageMax = 12;
  final Set<String> _countries = {'BR'};
  final Set<String> _selectedUids = {};
  List<AdminUserRow> _userRows = [];
  Uint8List? _imageBytes;
  int? _previewCount;
  bool _loadingUsers = false;
  bool _previewing = false;
  bool _sending = false;
  String? _error;

  bool get _canManage =>
      AdminPermissions.canManageUsers(AdminAuthService.instance.admin);

  void _syncCountrySelection() {
    final detected = _detectedCountries;
    if (detected.isEmpty) return;
    final validSet = detected.toSet();
    _countries.removeWhere((c) => !validSet.contains(c));
    if (_countries.isEmpty) _countries.add(detected.first);
  }

  List<String> get _detectedCountries {
    final set = <String>{};
    for (final u in _userRows) {
      final cc = u.countryCode.trim().toUpperCase();
      if (cc.length == 2) set.add(cc);
    }
    final out = set.toList()..sort();
    return out;
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    _linkUrl.dispose();
    _linkButtonLabel.dispose();
    _actionRoute.dispose();
    _imageUrl.dispose();
    _imageAlt.dispose();
    super.dispose();
  }

  bool _isValidHttps(String raw) {
    final u = raw.trim();
    if (u.isEmpty) return true;
    final uri = Uri.tryParse(u.contains('://') ? u : 'https://$u');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  bool _isValidImageUrl(String raw) {
    final u = raw.trim();
    if (u.isEmpty) return true;
    if (!_isValidHttps(u)) return false;
    final lower = u.toLowerCase();
    return RegExp(r'\.(png|jpe?g|webp|gif)(\?|$)').hasMatch(lower) ||
        lower.contains('firebasestorage.googleapis.com');
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _error = null;
    });
    try {
      final rows = await AdminRepository.instance.fetchUsers(limit: 300);
      if (mounted) {
        setState(() {
          _userRows = rows;
          _syncCountrySelection();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Map<String, dynamic> _targetingPayload() {
    return switch (_mode) {
      _TargetMode.all => {'type': 'all'},
      _TargetMode.users => {
          'type': 'users',
          'userIds': _selectedUids.toList(),
        },
      _TargetMode.babyAge => {
          'type': 'baby_age',
          'ageMinMonths': _ageMin,
          'ageMaxMonths': _ageMax,
        },
      _TargetMode.country => {
          'type': 'country',
          'countryCodes': _countries.toList(),
        },
    };
  }

  Future<void> _preview() async {
    setState(() {
      _previewing = true;
      _error = null;
    });
    try {
      final n = await AdminRepository.instance
          .previewBroadcastAudience(_targetingPayload());
      if (mounted) setState(() => _previewCount = n);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;
    if (bytes.length > 900 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagem máx. 900 KB')),
        );
      }
      return;
    }
    setState(() => _imageBytes = bytes);
  }

  Future<void> _send() async {
    final msg = _text.text.trim();
    final extImage = _imageUrl.text.trim();
    final hasUpload = _imageBytes != null;
    final hasImage = hasUpload || extImage.isNotEmpty;

    if (msg.isEmpty && !hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe mensagem e/ou imagem')),
      );
      return;
    }
    if (_messageType == 'promo_banner' && !hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('promo_banner exige imagem (upload ou URL https)'),
        ),
      );
      return;
    }
    if (extImage.isNotEmpty && !_isValidImageUrl(extImage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('imageUrl inválida — use https:// com imagem (.jpg, .png…)'),
        ),
      );
      return;
    }

    final link = _linkUrl.text.trim();
    final route = _actionRoute.text.trim();
    if (link.isNotEmpty && route.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use apenas URL externa ou rota interna, não ambos'),
        ),
      );
      return;
    }
    if (link.isNotEmpty && !_isValidHttps(link)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('actionUrl deve começar com https:// (http não permitido)'),
        ),
      );
      return;
    }
    if (route.isNotEmpty && !route.startsWith('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('actionRoute deve começar com /')),
      );
      return;
    }

    if (_mode == _TargetMode.users && _selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos um usuário')),
      );
      return;
    }
    if (_mode == _TargetMode.country && _countries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos um país')),
      );
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      String? b64;
      if (_imageBytes != null) {
        b64 = base64Encode(_imageBytes!);
      }
      final res = await AdminRepository.instance.publishBroadcast(
        text: msg,
        title: _title.text.trim(),
        messageType: _messageType,
        priority: _priority,
        targetAudience: _floatingAudience,
        dismissMode: _dismissMode,
        startsAtIso: _startsAt?.toUtc().toIso8601String(),
        endsAtIso: _endsAt?.toUtc().toIso8601String(),
        actionRoute: route,
        targeting: _targetingPayload(),
        imageBase64: b64,
        imageUrl: extImage,
        imageAlt: _imageAlt.text.trim(),
        actionUrl: link,
        actionButtonLabel: _linkButtonLabel.text.trim(),
      );
      if (!mounted) return;
      final count = res['recipientCount'] ?? '?';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enviado para $count usuária(s)')),
      );
      _text.clear();
      _linkUrl.clear();
      _linkButtonLabel.clear();
      setState(() {
        _imageBytes = null;
        _previewCount = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canManage) {
      return const AdminPagePadding(
        child: Center(child: Text('Sem permissão para enviar mensagens.')),
      );
    }

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final narrow = MediaQuery.sizeOf(context).width < 520;

    return AdminPagePadding(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomInset + 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mensageria',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Balão flutuante no portal (FloatingMessageBubble). Grava em floating_messages + inbox legado.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 20),
            Text(
              'Conteúdo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Título (balão expandido)',
                hintText: 'Ex.: Novidade no FaceBaby',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _messageType,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'admin_ad',
                  child: Text('Propaganda (admin_ad) 📣'),
                ),
                DropdownMenuItem(
                  value: 'admin_notice',
                  child: Text('Aviso geral (admin_notice)'),
                ),
                DropdownMenuItem(
                  value: 'premium_offer',
                  child: Text('Oferta Plus (premium_offer) ❤️'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _messageType = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              maxLength: 320,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mensagem',
                hintText: 'Texto do card expandido…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _priority.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: 'Prioridade $_priority',
                    onChanged: (v) => setState(() => _priority = v.round()),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '$_priority',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              value: _floatingAudience,
              decoration: const InputDecoration(
                labelText: 'Público do balão (targetAudience)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todos')),
                DropdownMenuItem(
                  value: 'free_users',
                  child: Text('Usuários gratuitos'),
                ),
                DropdownMenuItem(
                  value: 'plus_users',
                  child: Text('Usuários Plus'),
                ),
                DropdownMenuItem(
                  value: 'no_subscription',
                  child: Text('Sem assinatura'),
                ),
                DropdownMenuItem(
                  value: 'baby_under_6m',
                  child: Text('Bebê até 6 meses'),
                ),
                DropdownMenuItem(
                  value: 'baby_over_6m',
                  child: Text('Bebê acima de 6 meses'),
                ),
                DropdownMenuItem(
                  value: 'ai_active',
                  child: Text('Com IA ativa'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _floatingAudience = v);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startsAt ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) setState(() => _startsAt = d);
                    },
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _startsAt == null
                          ? 'Início (opcional)'
                          : 'Início: ${_startsAt!.toLocal().toString().split(' ').first}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _endsAt ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) setState(() => _endsAt = d);
                    },
                    icon: const Icon(Icons.event_busy_outlined, size: 18),
                    label: Text(
                      _endsAt == null
                          ? 'Fim (opcional)'
                          : 'Fim: ${_endsAt!.toLocal().toString().split(' ').first}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _dismissMode,
              decoration: const InputDecoration(
                labelText: 'Modo de fechamento',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'both',
                  child: Text('Botão X e arrastar para fechar'),
                ),
                DropdownMenuItem(
                  value: 'close_button',
                  child: Text('Somente botão X'),
                ),
                DropdownMenuItem(
                  value: 'drag_to_dismiss',
                  child: Text('Somente arrastar para fechar'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _dismissMode = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _imageUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL do banner (https, opcional)',
                hintText: 'https://…/banner.jpg — ou envie arquivo abaixo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _imageAlt,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Texto alternativo da imagem',
                hintText: 'Acessibilidade — descreva o banner',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                _imageBytes == null
                    ? 'Enviar imagem do banner (upload)'
                    : 'Trocar imagem enviada',
              ),
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _imageBytes!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _imageBytes = null),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Remover imagem'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Botão com link',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _actionRoute,
              decoration: const InputDecoration(
                labelText: 'Rota interna do app (opcional)',
                hintText: 'Ex.: /premium — não use junto com URL externa',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.route_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linkUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL externa do botão (https)',
                hintText: 'https://thefacebaby.com — só https, sem http',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linkButtonLabel,
              maxLength: 48,
              decoration: const InputDecoration(
                labelText: 'Texto do botão (opcional)',
                hintText: 'Ex.: Saiba mais, Ver oferta…',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.smart_button_outlined),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Público',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            _targetModeSelector(narrow),
            const SizedBox(height: 16),
            if (_mode == _TargetMode.babyAge) _babyAgeFields(),
            if (_mode == _TargetMode.country) _countryFields(),
            if (_mode == _TargetMode.users) _userPicker(),
            const SizedBox(height: 16),
            _actionButtons(narrow),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  static String _modeLabel(_TargetMode mode) => switch (mode) {
        _TargetMode.all => 'Todas',
        _TargetMode.users => 'Usuários',
        _TargetMode.babyAge => 'Idade bebê',
        _TargetMode.country => 'País',
      };

  Widget _targetModeSelector(bool narrow) {
    if (!narrow) {
      return SegmentedButton<_TargetMode>(
        segments: [
          for (final mode in _TargetMode.values)
            ButtonSegment(
              value: mode,
              label: Text(
                _modeLabel(mode),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        selected: {_mode},
        onSelectionChanged: (s) {
          setState(() {
            _mode = s.first;
            _previewCount = null;
          });
        },
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mode in _TargetMode.values)
          ChoiceChip(
            label: Text(_modeLabel(mode)),
            selected: _mode == mode,
            onSelected: (_) {
              setState(() {
                _mode = mode;
                _previewCount = null;
              });
            },
          ),
      ],
    );
  }

  Widget _actionButtons(bool narrow) {
    final previewBtn = FilledButton.icon(
      onPressed: _previewing ? null : _preview,
      icon: _previewing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.people_outline),
      label: Text(
        _previewCount != null ? 'Público: $_previewCount' : 'Calcular público',
      ),
    );
    final sendBtn = FilledButton.icon(
      onPressed: _sending ? null : _send,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF7B1FA2),
      ),
      icon: _sending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.send_rounded),
      label: const Text('Enviar balão'),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: double.infinity, child: previewBtn),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: sendBtn),
        ],
      );
    }

    return Row(
      children: [
        previewBtn,
        const SizedBox(width: 12),
        sendBtn,
      ],
    );
  }

  Widget _babyAgeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Idade do bebê (meses): $_ageMin – $_ageMax'),
        RangeSlider(
          values: RangeValues(_ageMin.toDouble(), _ageMax.toDouble()),
          min: 0,
          max: 36,
          divisions: 36,
          labels: RangeLabels('$_ageMin', '$_ageMax'),
          onChanged: (v) {
            setState(() {
              _ageMin = v.start.round();
              _ageMax = v.end.round();
              _previewCount = null;
            });
          },
        ),
      ],
    );
  }

  Widget _countryFields() {
    final detected = _detectedCountries;
    if (_loadingUsers && detected.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Carregando países detectados…'),
      );
    }
    if (detected.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Nenhum país detectado nos usuários ainda. O app salva isso em '
          'login (countryCode/localeCountry). Peça para as usuárias abrirem '
          'o app uma vez para preencher.',
          style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Países detectados (baseado em countryCode/locale do app):',
          style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final code in detected)
              FilterChip(
                label: Text(code),
                selected: _countries.contains(code),
                onSelected: (on) {
                  setState(() {
                    if (on) {
                      _countries.add(code);
                    } else {
                      _countries.remove(code);
                    }
                    _previewCount = null;
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _userPicker() {
    if (_loadingUsers) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _userRows.length,
          itemBuilder: (context, i) {
            final row = _userRows[i];
            final selected = _selectedUids.contains(row.uid);
            return CheckboxListTile(
              value: selected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedUids.add(row.uid);
                  } else {
                    _selectedUids.remove(row.uid);
                  }
                  _previewCount = null;
                });
              },
              title: Text(row.name.isNotEmpty ? row.name : row.email),
              subtitle: Text('${row.email} · ${row.babyName}'),
            );
          },
        ),
      ),
    );
  }
}
