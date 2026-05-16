import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/family_message_prefs.dart';
import '../services/app_database.dart';
import '../services/firebase/profile_cloud_sync.dart';
import '../services/firebase/baby_deletion_service.dart';
import '../theme/app_theme.dart';
import '../utils/measurement_format.dart';
import '../widgets/card_box.dart';
import '../widgets/photo_avatar.dart';
import 'mother_baby_register_page.dart';

/// Aba inicial ao abrir [MotherProfilePage] (ex.: vindo da tela Família).
enum MotherProfileInitialTab { mother, father, babies }

class MotherProfilePage extends StatefulWidget {
  final MotherProfileInitialTab initialTab;

  const MotherProfilePage({
    super.key,
    this.initialTab = MotherProfileInitialTab.mother,
  });

  @override
  State<MotherProfilePage> createState() => _MotherProfilePageState();
}

int motherProfileTabIndex({
  required MotherProfileInitialTab tab,
  required bool fatherRegistered,
}) {
  switch (tab) {
    case MotherProfileInitialTab.mother:
      return 0;
    case MotherProfileInitialTab.father:
      return fatherRegistered ? 1 : 0;
    case MotherProfileInitialTab.babies:
      return fatherRegistered ? 2 : 1;
  }
}

bool motherProfileFatherRegistered(Map<String, Object?> mother) {
  final reg = mother['register_father'];
  if (reg is num && reg.toInt() == 1) return true;
  final name = (mother['father_name'] as String?)?.trim();
  if (name != null && name.isNotEmpty) return true;
  final fh = (mother['father_height_cm'] as num?)?.toDouble();
  if (fh != null && fh > 0) return true;
  final fb = mother['father_birth_date'] as String?;
  if (fb != null && fb.trim().isNotEmpty) return true;
  final fpb = (mother['father_photo_b64'] as String?)?.trim();
  if (fpb != null && fpb.isNotEmpty) return true;
  final fpu = (mother['father_photo_url'] as String?)?.trim();
  if (fpu != null && fpu.isNotEmpty) return true;
  return false;
}

class _MotherProfilePageState extends State<MotherProfilePage>
    with SingleTickerProviderStateMixin {
  final _current = CurrentBabyController.instance;
  TabController? _tabs;
  int _tabCount = 2;

  TabController _tabsFor(int count, {required bool fatherRegistered}) {
    if (_tabs != null && _tabCount == count) return _tabs!;
    final prevIndex = _tabs?.index;
    _tabs?.dispose();
    _tabCount = count;
    final initial = prevIndex ??
        motherProfileTabIndex(
          tab: widget.initialTab,
          fatherRegistered: fatherRegistered,
        );
    _tabs = TabController(
      length: count,
      vsync: this,
      initialIndex: initial.clamp(0, count - 1),
    );
    return _tabs!;
  }

  @override
  void initState() {
    super.initState();
    _current.addListener(_onCurrentChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CurrentBabyController.instance.refresh();
    });
  }

  @override
  void dispose() {
    _current.removeListener(_onCurrentChanged);
    _tabs?.dispose();
    super.dispose();
  }

  void _onCurrentChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _editMother(int motherId, MotherProfileMotherFormSection section) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MotherBabyRegisterPage(
          editMotherId: motherId,
          profileMotherSection: section,
        ),
      ),
    );
    await CurrentBabyController.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final mother = _current.currentMotherRow;
    final motherId = (mother?['id'] as num?)?.toInt();
    final fatherRegistered =
        mother != null && motherProfileFatherRegistered(mother);
    final tabCount = fatherRegistered ? 3 : 2;
    final tabs = _tabsFor(tabCount, fatherRegistered: fatherRegistered);

    final tabWidgets = <Widget>[
      Tab(text: s.motherProfileTabMother),
      if (fatherRegistered) Tab(text: s.motherProfileTabFather),
      Tab(text: s.motherProfileTabBabies),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(s.settingsMotherProfile),
        bottom: TabBar(
          controller: tabs,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900),
          tabs: tabWidgets,
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
                controller: tabs,
                children: [
                  _MotherInfoTab(
                    motherRow: mother!,
                    showFatherHeight: !fatherRegistered,
                    onEdit: () => _editMother(motherId, MotherProfileMotherFormSection.mother),
                  ),
                  if (fatherRegistered)
                    _FatherInfoTab(
                      motherRow: mother,
                      onEdit: () => _editMother(motherId, MotherProfileMotherFormSection.father),
                    ),
                  _BabiesTab(motherId: motherId),
                ],
              ),
      ),
    );
  }
}

class _ProfileInfoLine extends StatelessWidget {
  const _ProfileInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black.withAlpha(150),
              ),
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
}

String _profileFmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _MotherInfoTab extends StatefulWidget {
  final Map<String, Object?> motherRow;
  final bool showFatherHeight;
  final Future<void> Function()? onEdit;

  const _MotherInfoTab({
    required this.motherRow,
    this.showFatherHeight = false,
    this.onEdit,
  });

  @override
  State<_MotherInfoTab> createState() => _MotherInfoTabState();
}

class _MotherInfoTabState extends State<_MotherInfoTab> {
  late bool _showChristian;
  late bool _showHoroscope;
  bool _savingPrefs = false;

  @override
  void initState() {
    super.initState();
    _readPrefsFromRow();
  }

  @override
  void didUpdateWidget(covariant _MotherInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motherRow != widget.motherRow) _readPrefsFromRow();
  }

  void _readPrefsFromRow() {
    final prefs = FamilyMessagePrefs.fromMother(widget.motherRow);
    _showChristian = prefs.showChristian;
    _showHoroscope = prefs.showHoroscope;
  }

  Future<void> _setMessagePref({
    bool? showChristian,
    bool? showHoroscope,
  }) async {
    final motherId = (widget.motherRow['id'] as num?)?.toInt();
    if (motherId == null || _savingPrefs) return;

    final nextChristian = showChristian ?? _showChristian;
    var nextHoroscope = showHoroscope ?? _showHoroscope;
    if (!nextChristian && !nextHoroscope) {
      nextHoroscope = true;
    }

    setState(() {
      _savingPrefs = true;
      _showChristian = nextChristian;
      _showHoroscope = nextHoroscope;
    });

    try {
      await AppDatabase.instance.updateMotherFamilyMessagePrefs(
        motherId: motherId,
        showChristian: nextChristian,
        showHoroscope: nextHoroscope,
      );
      await ProfileCloudSync.pushMother(motherId);
      await CurrentBabyController.instance.refresh();
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final motherRow = widget.motherRow;

    final name = (motherRow['name'] as String?)?.trim();
    final phone = (motherRow['phone'] as String?)?.trim();
    final birthRaw = (motherRow['birth_date'] as String?)?.trim();
    final birth =
        birthRaw == null || birthRaw.isEmpty ? null : DateTime.tryParse(birthRaw);
    final height = (motherRow['height_cm'] as num?)?.toDouble();
    final fatherHeight = (motherRow['father_height_cm'] as num?)?.toDouble();
    final photoB64 = (motherRow['photo_b64'] as String?)?.trim();
    final photoUrlRaw = (motherRow['photo_url'] as String?)?.trim();

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
                  photoUrl:
                      (photoUrlRaw == null || photoUrlRaw.isEmpty) ? null : photoUrlRaw,
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
                Text(s.motherProfileSectionInfo,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 12),
                _ProfileInfoLine(
                  label: s.motherProfileFieldPhone,
                  value: (phone == null || phone.isEmpty) ? '—' : phone,
                ),
                _ProfileInfoLine(
                  label: s.motherProfileFieldBirth,
                  value: birth == null ? '—' : _profileFmtDate(birth),
                ),
                _ProfileInfoLine(
                  label: s.motherProfileFieldHeight,
                  value: MeasurementFormat.length(height, decimalsCm: 0),
                ),
                if (widget.showFatherHeight)
                  _ProfileInfoLine(
                    label: s.motherProfileFieldFatherHeight,
                    value: MeasurementFormat.length(fatherHeight, decimalsCm: 0),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.profileFamilyMessagesTitle,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    s.profileShowChristian,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  value: _showChristian,
                  onChanged: _savingPrefs
                      ? null
                      : (v) => _setMessagePref(showChristian: v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    s.profileShowHoroscope,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  value: _showHoroscope,
                  onChanged: _savingPrefs
                      ? null
                      : (v) => _setMessagePref(showHoroscope: v),
                ),
              ],
            ),
          ),
          if (widget.onEdit != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => widget.onEdit!(),
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

class _FatherInfoTab extends StatelessWidget {
  final Map<String, Object?> motherRow;
  final Future<void> Function()? onEdit;

  const _FatherInfoTab({required this.motherRow, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    final name = (motherRow['father_name'] as String?)?.trim();
    final birthRaw = (motherRow['father_birth_date'] as String?)?.trim();
    final birth =
        birthRaw == null || birthRaw.isEmpty ? null : DateTime.tryParse(birthRaw);
    final height = (motherRow['father_height_cm'] as num?)?.toDouble();
    final photoB64 = (motherRow['father_photo_b64'] as String?)?.trim();
    final photoUrlRaw = (motherRow['father_photo_url'] as String?)?.trim();

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
                  photoUrl: (photoUrlRaw == null || photoUrlRaw.isEmpty)
                      ? null
                      : photoUrlRaw,
                  radius: 34,
                  backgroundColor: const Color(0xFFD6EBFF),
                  fallback: const Text('👨', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (name == null || name.isEmpty) ? s.familyRoleFather : name,
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
                Text(s.motherProfileSectionInfo,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 12),
                _ProfileInfoLine(
                  label: s.motherProfileFieldFatherName,
                  value: (name == null || name.isEmpty) ? '—' : name,
                ),
                _ProfileInfoLine(
                  label: s.motherProfileFieldBirth,
                  value: birth == null ? '—' : _profileFmtDate(birth),
                ),
                _ProfileInfoLine(
                  label: s.motherProfileFieldHeight,
                  value: MeasurementFormat.length(height, decimalsCm: 0),
                ),
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
      return all
          .where((b) => (b['mother_id'] as num?)?.toInt() == widget.motherId)
          .toList();
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
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bebê deletado.')));
      setState(() => _reload());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s.commonCouldNotSave} $e')));
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
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ctaPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
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
                  final sex =
                      ((b['sex'] as String?)?.trim().toUpperCase() == 'M') ? 'M' : 'F';
                  final birthRaw = (b['birth_date'] as String?)?.trim();
                  final birth = birthRaw == null || birthRaw.isEmpty
                      ? null
                      : DateTime.tryParse(birthRaw);
                  final photoB64 = (b['photo_b64'] as String?)?.trim();
                  final pu = (b['photo_url'] as String?)?.trim();
                  final photoUrl = (pu == null || pu.isEmpty) ? null : pu;
                  final bg = sex == 'M'
                      ? const Color(0xFFD6EBFF)
                      : const Color(0xFFFFDCE8);
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
                                fallback:
                                    const Text('👶', style: TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (name == null || name.isEmpty) ? '—' : name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900, fontSize: 15),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      birth == null
                                          ? '—'
                                          : s.motherProfileBabyBornAt(_fmtDate(birth)),
                                      style: TextStyle(
                                        color: Colors.black.withAlpha(140),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
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
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Color(0xFFFF3B30)),
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
