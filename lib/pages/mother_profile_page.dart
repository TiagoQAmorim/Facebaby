import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../services/app_database.dart';
import '../services/firebase/baby_deletion_service.dart';
import '../theme/app_theme.dart';
import '../utils/measurement_format.dart';
import '../widgets/card_box.dart';
import '../widgets/photo_avatar.dart';
import 'mother_baby_register_page.dart';

class MotherProfilePage extends StatefulWidget {
  const MotherProfilePage({super.key});

  @override
  State<MotherProfilePage> createState() => _MotherProfilePageState();
}

class _MotherProfilePageState extends State<MotherProfilePage> with SingleTickerProviderStateMixin {
  final _current = CurrentBabyController.instance;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _current.addListener(_onCurrentChanged);
    // Re-sync com SQLite/Firestore ao abrir (recuperar mãe se o FK ficou órfão).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CurrentBabyController.instance.refresh();
    });
  }

  @override
  void dispose() {
    _current.removeListener(_onCurrentChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onCurrentChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final mother = _current.currentMotherRow;
    final motherId = (mother?['id'] as num?)?.toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.settingsMotherProfile),
        bottom: TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900),
          tabs: [
            Tab(text: s.motherProfileTabMother),
            Tab(text: s.motherProfileTabBabies),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: motherId == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(s.motherProfileNoData, textAlign: TextAlign.center),
                ),
              )
            : TabBarView(
                controller: _tabs,
                children: [
                  _MotherInfoTab(
                    motherRow: mother!,
                    onEdit: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MotherBabyRegisterPage(editMotherId: motherId),
                        ),
                      );
                      await CurrentBabyController.instance.refresh();
                    },
                  ),
                  _BabiesTab(motherId: motherId),
                ],
              ),
      ),
    );
  }
}

class _MotherInfoTab extends StatelessWidget {
  final Map<String, Object?> motherRow;
  final Future<void> Function()? onEdit;

  const _MotherInfoTab({required this.motherRow, this.onEdit});

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    final name = (motherRow['name'] as String?)?.trim();
    final phone = (motherRow['phone'] as String?)?.trim();
    final birthRaw = (motherRow['birth_date'] as String?)?.trim();
    final birth = birthRaw == null || birthRaw.isEmpty ? null : DateTime.tryParse(birthRaw);
    final height = (motherRow['height_cm'] as num?)?.toDouble();
    final fatherHeight = (motherRow['father_height_cm'] as num?)?.toDouble();
    final photoB64 = (motherRow['photo_b64'] as String?)?.trim();
    final photoUrlRaw = (motherRow['photo_url'] as String?)?.trim();

    Widget line(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withAlpha(150)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardBox(
            child: Row(
              children: [
                PhotoAvatar(
                  photoB64: photoB64,
                  photoUrl: (photoUrlRaw == null || photoUrlRaw.isEmpty) ? null : photoUrlRaw,
                  radius: 34,
                  backgroundColor: const Color(0xFFF1F2F6),
                  fallback: const Text('👩', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (name == null || name.isEmpty) ? '—' : name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.motherProfileSectionInfo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 12),
                line(s.motherProfileFieldPhone, (phone == null || phone.isEmpty) ? '—' : phone),
                line(s.motherProfileFieldBirth, birth == null ? '—' : _fmtDate(birth)),
                line(s.motherProfileFieldHeight, MeasurementFormat.length(height, decimalsCm: 0)),
                line(s.motherProfileFieldFatherHeight, MeasurementFormat.length(fatherHeight, decimalsCm: 0)),
              ],
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => onEdit!(),
                icon: const Icon(Icons.edit_outlined),
                label: Text(s.profileEditData),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BabiesTab extends StatefulWidget {
  final int motherId;

  const _BabiesTab({required this.motherId});

  @override
  State<_BabiesTab> createState() => _BabiesTabState();
}

class _BabiesTabState extends State<_BabiesTab> {
  Future<List<Map<String, Object?>>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = AppDatabase.instance.listBabies().then((all) {
      return all.where((b) => (b['mother_id'] as num?)?.toInt() == widget.motherId).toList();
    });
  }

  Future<void> _openEditBaby(Map<String, Object?> b) async {
    final id = (b['id'] as num?)?.toInt();
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MotherBabyRegisterPage(editBabyId: id),
      ),
    );
    await CurrentBabyController.instance.refresh();
    if (!mounted) return;
    setState(() => _reload());
  }

  Future<void> _addAnotherBaby() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MotherBabyRegisterPage(
          babyOnly: true,
          presetMotherId: widget.motherId,
        ),
      ),
    );
    await CurrentBabyController.instance.refresh();
    if (!mounted) return;
    setState(() => _reload());
  }

  Future<void> _deleteBaby(Map<String, Object?> b) async {
    final s = S.of(context);
    final id = (b['id'] as num?)?.toInt();
    if (id == null) return;
    final name = ((b['name'] as String?) ?? '—').trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Deletar bebê'),
          content: Text(
            'Tem certeza que deseja deletar \"$name\"?\n\n'
            'Isso vai apagar também os registros relacionados (sono, alimentação, fraldas, vacinas, etc.).',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF3B30)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Deletar'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    try {
      await BabyDeletionService.instance.deleteBabyEverywhere(localBabyId: id);
      await CurrentBabyController.instance.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bebê deletado.')));
      setState(() => _reload());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.commonCouldNotSave} $e')));
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.ctaPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _addAnotherBaby,
              icon: const Icon(Icons.add),
              label: Text(s.motherProfileAddBaby),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(s.motherProfileNoBabies, textAlign: TextAlign.center),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final b = list[i];
                  final name = (b['name'] as String?)?.trim();
                  final sex = ((b['sex'] as String?)?.trim().toUpperCase() == 'M') ? 'M' : 'F';
                  final birthRaw = (b['birth_date'] as String?)?.trim();
                  final birth = birthRaw == null || birthRaw.isEmpty ? null : DateTime.tryParse(birthRaw);
                  final photoB64 = (b['photo_b64'] as String?)?.trim();
                  final pu = (b['photo_url'] as String?)?.trim();
                  final photoUrl = (pu == null || pu.isEmpty) ? null : pu;
                  final bg = sex == 'M' ? const Color(0xFFD6EBFF) : const Color(0xFFFFDCE8);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CardBox(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openEditBaby(b),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              PhotoAvatar(
                                photoB64: photoB64,
                                photoUrl: photoUrl,
                                radius: 26,
                                backgroundColor: bg,
                                fallback: const Text('👶', style: TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text((name == null || name.isEmpty) ? '—' : name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                    const SizedBox(height: 3),
                                    Text(
                                      birth == null ? '—' : s.motherProfileBabyBornAt(_fmtDate(birth)),
                                      style: TextStyle(color: Colors.black.withAlpha(140), fontWeight: FontWeight.w700, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: s.profileEditData,
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openEditBaby(b),
                              ),
                              IconButton(
                                tooltip: 'Deletar',
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30)),
                                onPressed: () => _deleteBaby(b),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

