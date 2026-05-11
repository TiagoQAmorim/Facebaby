import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/app_locale.dart';
import '../../controllers/memory_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../services/premium/feature_access.dart';
import '../../services/premium/premium_constants.dart';
import '../premium/premium_paywall_screen.dart';
import '../../models/baby_memory.dart';
import '../../models/memory_badge.dart';
import '../../theme/app_theme.dart';
import '../../utils/memory_moment_localizations.dart';
import '../../utils/pick_image_b64.dart';
import '../../utils/memory_photo_limits.dart';
import '../../utils/photo_b64.dart';
import '../../widgets/card_box.dart';
import '../../widgets/memories/memory_badge_icon.dart';
import '../../widgets/face_baby_loading.dart';

class AddMemoryPage extends StatefulWidget {
  final int babyId;
  final MemoryBadge badge;
  final MemoryController controller;
  final DateTime? babyBirthDate;
  final double? currentWeightKg;
  final double? currentHeightCm;

  /// Quando preenchido, a tela funciona como edição (texto, foto, dados e data).
  final BabyMemory? initialMemory;

  const AddMemoryPage({
    super.key,
    required this.babyId,
    required this.badge,
    required this.controller,
    this.babyBirthDate,
    this.currentWeightKg,
    this.currentHeightCm,
    this.initialMemory,
  });

  @override
  State<AddMemoryPage> createState() => _AddMemoryPageState();
}

class _AddMemoryPageState extends State<AddMemoryPage> {
  final _descCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _moodCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _memoryDate = DateTime.now();
  String? _photoB64;
  /// Mantém URL da Storage após sync (quando [photoB64] já foi limpo localmente).
  String? _photoUrl;
  bool _saving = false;

  /// Igual ao detalhe da memória: opt-in “Foto da Semana” / mural público.
  bool _isPublic = false;
  bool _showBabyFirstNameWhenPublic = true;

  bool get _isEditing => widget.initialMemory != null;

  /// Há bytes locais OU URL para pré-visualizar (cache / nuvem).
  bool get _hasPhotoForUi => _photoBytesDecoded != null || _hasPhotoUrl;

  Uint8List? get _photoBytesDecoded => decodePhotoB64(_photoB64);

  bool get _hasPhotoUrl {
    final u = _photoUrl?.trim();
    return u != null && u.isNotEmpty;
  }

  /// Novo ficheiro escolhido da galeria (deve anular URL antiga e subir de novo no push).
  bool get _hasLocalPickedB64 => _photoB64 != null && _photoB64!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialMemory;
    if (existing != null) {
      _memoryDate = existing.memoryDate;
      _photoB64 = existing.photoB64;
      final u = existing.photoUrl?.trim();
      _photoUrl = (u == null || u.isEmpty) ? null : u;
      _descCtrl.text = existing.description ?? '';
      _ageCtrl.text = existing.babyAgeAtMoment ?? '';
      final w = existing.weightAtMoment;
      if (w != null) _weightCtrl.text = w.toStringAsFixed(2).replaceAll('.', ',');
      final h = existing.heightAtMoment;
      if (h != null) _heightCtrl.text = h.toStringAsFixed(1).replaceAll('.', ',');
      _moodCtrl.text = existing.moodAtMoment ?? '';
      _notesCtrl.text = existing.motherNotes ?? '';
      _isPublic = existing.isPublic;
      _showBabyFirstNameWhenPublic = existing.showBabyFirstNameWhenPublic;
      return;
    }
    // Nova memória: prefill opcional com dados atuais do bebê.
    final cw = widget.currentWeightKg;
    final ch = widget.currentHeightCm;
    if (cw != null && _weightCtrl.text.isEmpty) {
      _weightCtrl.text = cw.toStringAsFixed(2).replaceAll('.', ',');
    }
    if (ch != null && _heightCtrl.text.isEmpty) {
      _heightCtrl.text = ch.toStringAsFixed(0);
    }
    final birth = widget.babyBirthDate;
    if (birth != null && _ageCtrl.text.isEmpty) {
      _ageCtrl.text = S(kAppLanguage.lang).memorySuggestedAgeBetween(birth: birth, when: _memoryDate);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _moodCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  Future<void> _pickPhoto() async {
    final b64 = await pickImageAsB64(context: context, maxBytes: memoryPhotoPickMaxBytes());
    if (b64 == null) return;
    setState(() {
      _photoB64 = b64;
      _photoUrl = null;
    });
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _memoryDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_memoryDate));
    if (t == null || !mounted) return;
    setState(() => _memoryDate = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  ({DateTime? enabledAt, DateTime? disabledAt}) _publicTimestampsForSave() {
    final prev = widget.initialMemory;
    if (_isPublic) {
      final enabledAt =
          (prev?.isPublic == true) ? (prev!.publicEnabledAt ?? DateTime.now()) : DateTime.now();
      return (enabledAt: enabledAt, disabledAt: null);
    }
    final enabledAt = prev?.publicEnabledAt;
    final disabledAt = (prev?.isPublic == true) ? DateTime.now() : prev?.publicDisabledAt;
    return (enabledAt: enabledAt, disabledAt: disabledAt);
  }

  Future<void> _requestPublicOff() async {
    setState(() => _isPublic = false);
  }

  Future<void> _requestPublicOn() async {
    final bytes = decodePhotoB64(_photoB64);
    final url = (_photoUrl ?? '').trim();
    final hasPhoto = bytes != null || url.isNotEmpty;
    final s = S.of(context);
    if (!hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.weeklyPhotoPublicNeedPhoto)));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final key = 'fb_weekly_photo_confirm_${widget.babyId}_${widget.badge.id}';
    final seen = prefs.getBool(key) ?? false;
    if (!seen) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.weeklyPhotoConfirmTitle),
          content: Text(s.weeklyPhotoConfirmBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.weeklyPhotoConfirmCancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.weeklyPhotoConfirmOk)),
          ],
        ),
      );
      if (ok != true) return;
      await prefs.setBool(key, true);
    }
    if (!mounted) return;
    setState(() => _isPublic = true);
  }

  Future<void> _togglePublicPressed() async {
    if (_isPublic) {
      await _requestPublicOff();
    } else {
      await _requestPublicOn();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final hasPhoto = _hasLocalPickedB64 || _hasPhotoUrl;
    final hasText = _descCtrl.text.trim().isNotEmpty || _notesCtrl.text.trim().isNotEmpty;
    if (!hasPhoto && !hasText) {
      final msg = S.of(context).memorySaveNeedPhotoOrText;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    final s = S.of(context);
    if (!FeatureAccess.canSaveNewMemoryMoment(
      controller: widget.controller,
      badgeId: widget.badge.id,
      isEditing: _isEditing,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.plusMemoryLimitSnack.replaceAll('{max}', '${PremiumConstants.freeMemoryMomentsMax}')),
        ),
      );
      await openPremiumPaywall(context);
      return;
    }
    setState(() => _saving = true);
    try {
      final birth = widget.babyBirthDate;
      final autoAge = (birth == null) ? null : S.of(context).memorySuggestedAgeBetween(birth: birth, when: _memoryDate);
      final autoWeight = widget.currentWeightKg;
      final autoHeight = widget.currentHeightCm;

      final finalAge = _ageCtrl.text.trim().isEmpty ? autoAge : _ageCtrl.text.trim();
      final finalWeight = _weightCtrl.text.trim().isEmpty ? autoWeight : _parseDouble(_weightCtrl.text);
      final finalHeight = _heightCtrl.text.trim().isEmpty ? autoHeight : _parseDouble(_heightCtrl.text);

      final prev = widget.initialMemory;
      final pubTs = _publicTimestampsForSave();
      // Só sobrescrever [photoUrl] / limpar b64 quando há ficheiro novo; senão preserva nuvem/cache local (linha só com URL).
      final m = BabyMemory(
        id: prev?.id,
        babyId: widget.babyId,
        badgeId: widget.badge.id,
        title: S.of(context).memoryBadgeTitle(widget.badge),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        photoB64: _hasLocalPickedB64 ? _photoB64 : prev?.photoB64,
        photoUrl: _hasLocalPickedB64 ? null : prev?.photoUrl,
        createdAt: prev?.createdAt ?? DateTime.now(),
        memoryDate: _memoryDate,
        babyAgeAtMoment: (finalAge == null || finalAge.trim().isEmpty) ? null : finalAge.trim(),
        weightAtMoment: finalWeight,
        heightAtMoment: finalHeight,
        moodAtMoment: _moodCtrl.text.trim().isEmpty ? null : _moodCtrl.text.trim(),
        motherNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        isFavorite: prev?.isFavorite ?? false,
        isPublic: _isPublic,
        publicEnabledAt: pubTs.enabledAt,
        publicDisabledAt: pubTs.disabledAt,
        eligibleForWeeklyPhoto: prev?.eligibleForWeeklyPhoto ?? false,
        weeklyPhotoWinner: prev?.weeklyPhotoWinner ?? false,
        weeklyPhotoWeekId: prev?.weeklyPhotoWeekId,
        showBabyFirstNameWhenPublic: _showBabyFirstNameWhenPublic,
      );
      await widget.controller.upsert(m);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.of(context).memorySaveFail} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bytes = _photoBytesDecoded;
    final photoUrlTrim = _photoUrl?.trim();
    final dt = _memoryDate;
    final dateLabel = formatMemoryMomentDateTime(context, dt);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? s.memoryEditTitle : s.memoryNewTitle),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 22, height: 22, child: FaceBabySpinner(size: 22, strokeWidth: 2.6))
                : const Icon(Icons.check_circle),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MemoryBadgeIcon(badge: widget.badge, muted: !_hasPhotoForUi, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.memoryBadgeTitle(widget.badge),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(dateLabel),
                ),
                const SizedBox(height: 10),
                CardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? s.memoryPhotoEditTitle : s.memoryPhotoAddTitle,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _pickPhoto,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final mw = (c.maxWidth.isFinite && c.maxWidth > 0)
                                    ? c.maxWidth
                                    : math.min(MediaQuery.sizeOf(context).width - 48, 760);
                                // Reserva espaço para o título da badge à direita (com foto há só texto; ícone vai no canto da foto).
                                final badgeRailMin = !_hasPhotoForUi ? 100.0 : 88.0;
                                const gap = 12.0;
                                final photoSide = math.min(
                                  136.0,
                                  math.max(84.0, mw - badgeRailMin - gap),
                                );

                                Widget circleChild;
                                if (!_hasPhotoForUi) {
                                  circleChild = Container(
                                    width: photoSide,
                                    height: photoSide,
                                    color: MemoryBadgeIcon.mutedDiskBackground.withAlpha(230),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_a_photo_rounded, size: 38, color: Colors.black.withAlpha(100)),
                                        const SizedBox(height: 8),
                                        Text(
                                          s.memoryTapToPickPhoto,
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black.withAlpha(120)),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  final mini = (photoSide * 0.26).clamp(22.0, 36.0);
                                  final Widget ovalImage;
                                  if (bytes != null) {
                                    ovalImage = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, alignment: Alignment.center);
                                  } else if (photoUrlTrim != null && photoUrlTrim.isNotEmpty) {
                                    ovalImage = Image.network(
                                      photoUrlTrim,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      gaplessPlayback: true,
                                      loadingBuilder: (ctx, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: FaceBabySpinner(size: photoSide * 0.35, strokeWidth: 2.6),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        color: MemoryBadgeIcon.mutedDiskBackground,
                                        alignment: Alignment.center,
                                        child: Icon(Icons.broken_image_outlined, size: photoSide * 0.35, color: Colors.black45),
                                      ),
                                    );
                                  } else {
                                    ovalImage = const SizedBox.shrink();
                                  }
                                  circleChild = SizedBox(
                                    width: photoSide,
                                    height: photoSide,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        ClipOval(
                                          child: SizedBox(
                                            width: photoSide,
                                            height: photoSide,
                                            child: ovalImage,
                                          ),
                                        ),
                                        Positioned(
                                          right: 2,
                                          bottom: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withAlpha(40),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: MemoryBadgeIcon(badge: widget.badge, muted: false, size: mini),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ClipOval(child: circleChild),
                                    SizedBox(width: gap),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (!_hasPhotoForUi) ...[
                                              MemoryBadgeIcon(badge: widget.badge, muted: true, size: 44),
                                              const SizedBox(height: 6),
                                            ],
                                            Text(
                                              s.memoryBadgeTitle(widget.badge),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary.withAlpha(200)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
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
                      Text(s.memoryTellMomentTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descCtrl,
                        minLines: 4,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: s.memoryTellMomentHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(s.memoryBabyInfoOptionalTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Wrap(
                        runSpacing: 10,
                        spacing: 10,
                        children: [
                          SizedBox(
                            width: 170,
                            child: TextField(
                              controller: _ageCtrl,
                              decoration: InputDecoration(labelText: s.contactFieldAge, hintText: s.memoryAgeHintExample),
                            ),
                          ),
                          SizedBox(
                            width: 170,
                            child: TextField(
                              controller: _weightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration:
                                  InputDecoration(labelText: s.memoryStatWeightLabel, hintText: s.memoryWeightHintExample),
                            ),
                          ),
                          SizedBox(
                            width: 170,
                            child: TextField(
                              controller: _heightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration:
                                  InputDecoration(labelText: s.memoryStatHeightLabel, hintText: s.memoryHeightHintExample),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _moodCtrl,
                              decoration: InputDecoration(labelText: s.memoryBabyMoodLabel, hintText: s.memoryBabyMoodHint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesCtrl,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(labelText: s.memoryMomNotesFieldLabel, border: const OutlineInputBorder()),
                      ),
                      const SizedBox(height: 18),
                      if (!_isPublic)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            s.weeklyPhotoPublicExplainer,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _togglePublicPressed,
                          icon: Icon(
                            _isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            _isPublic ? s.weeklyPhotoPublicOn : s.weeklyPhotoPublicOff,
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppTheme.primaryPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                        ),
                      ),
                      if (_isPublic) ...[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.weeklyPhotoShowBabyFirstName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          value: _showBabyFirstNameWhenPublic,
                          onChanged: _saving
                              ? null
                              : (v) {
                                  setState(() => _showBabyFirstNameWhenPublic = v);
                                },
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        s.weeklyPhotoDisclaimerFooter,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(backgroundColor: AppTheme.ctaPrimary),
                          child: Text(_isEditing ? s.memorySaveChanges : s.memorySaveNew),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

