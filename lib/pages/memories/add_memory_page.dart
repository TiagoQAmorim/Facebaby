import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../utils/app_date_picker.dart';
import '../../app/app_locale.dart';
import '../../controllers/memory_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../services/premium/feature_access.dart';
import '../premium/premium_paywall_screen.dart';
import '../../models/baby_memory.dart';
import '../../models/memory_badge.dart';
import '../../theme/app_theme.dart';
import '../../utils/memory_moment_localizations.dart';
import '../../utils/pick_image_b64.dart';
import '../../utils/memory_photo_limits.dart';
import '../../utils/photo_b64.dart';
import '../../utils/portal_time_of_day.dart';
import '../../widgets/card_box.dart';
import '../../widgets/memories/cached_memory_photo.dart';
import '../../widgets/memories/memory_badge_icon.dart';
import '../../widgets/face_baby_loading.dart';
import '../../widgets/weekly_photo_public_confirm_dialog.dart';
import 'memory_badges_catalog.dart';

class AddMemoryPage extends StatefulWidget {
  final int babyId;
  final MemoryBadge? badge;
  final List<MemoryBadge> availableBadges;
  final MemoryController controller;
  final DateTime? babyBirthDate;
  final double? currentWeightKg;
  final double? currentHeightCm;

  /// Quando preenchido, a tela funciona como edição (texto, foto, dados e data).
  final BabyMemory? initialMemory;

  const AddMemoryPage({
    super.key,
    required this.babyId,
    this.badge,
    this.availableBadges = const [],
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
  final _customBadgeNameCtrl = TextEditingController();

  DateTime _memoryDate = DateTime.now();
  MemoryBadge? _selectedBadge;
  String? _photoB64;

  /// Mantém URL da Storage após sync (quando [photoB64] já foi limpo localmente).
  String? _photoUrl;
  bool _saving = false;

  /// Igual ao detalhe da memória: opt-in “Foto da Semana” / mural público.
  bool _isPublic = false;
  bool _showBabyFirstNameWhenPublic = true;

  bool get _isEditing => widget.initialMemory != null;

  bool get _isOtherBadgeSelected =>
      _selectedBadge?.id == MemoryBadgesCatalog.otherBadgeId;

  String get _customBadgeName => _customBadgeNameCtrl.text.trim();

  /// Há bytes locais OU URL para pré-visualizar (cache / nuvem).
  bool get _hasPhotoForUi => _photoBytesDecoded != null || _hasPhotoUrl;

  Uint8List? get _photoBytesDecoded => decodePhotoB64(_photoB64);

  bool get _hasPhotoUrl {
    final u = _photoUrl?.trim();
    return u != null && u.isNotEmpty;
  }

  /// Novo ficheiro escolhido da galeria (deve anular URL antiga e subir de novo no push).
  bool get _hasLocalPickedB64 =>
      _photoB64 != null && _photoB64!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialMemory;
    _selectedBadge = widget.badge;
    if (existing != null) {
      _selectedBadge ??= MemoryBadgesCatalog.findBadgeById(existing.badgeId) ??
          MemoryBadgesCatalog.customFromMemory(
            id: existing.badgeId,
            title: existing.title,
          );
      if (MemoryBadgesCatalog.isCustomBadgeId(existing.badgeId)) {
        _customBadgeNameCtrl.text = existing.title;
      }
      _memoryDate = existing.memoryDate;
      _photoB64 = existing.photoB64;
      final u = existing.photoUrl?.trim();
      _photoUrl = (u == null || u.isEmpty) ? null : u;
      _descCtrl.text = existing.description ?? '';
      _ageCtrl.text = existing.babyAgeAtMoment ?? '';
      final w = existing.weightAtMoment;
      if (w != null) {
        _weightCtrl.text = w.toStringAsFixed(2).replaceAll('.', ',');
      }
      final h = existing.heightAtMoment;
      if (h != null) {
        _heightCtrl.text = h.toStringAsFixed(1).replaceAll('.', ',');
      }
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
      _ageCtrl.text = S(kAppLanguage.lang)
          .memorySuggestedAgeBetween(birth: birth, when: _memoryDate);
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
    _customBadgeNameCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  Future<void> _pickPhoto() async {
    final b64 = await pickImageAsB64(
        context: context, maxBytes: memoryPhotoPickMaxBytes());
    if (b64 == null) return;
    setState(() {
      _photoB64 = b64;
      _photoUrl = null;
    });
  }

  void _openPhotoFullscreen() {
    if (!_hasPhotoForUi) return;
    final b = _photoBytesDecoded;
    final url = _photoUrl?.trim();
    if (b != null) {
      _showPhotoFullscreenDialog(MemoryImage(b));
      return;
    }
    if (url != null && url.isNotEmpty) {
      _showPhotoFullscreenDialog(memoryPhotoNetworkImageProvider(url));
    }
  }

  void _showPhotoFullscreenDialog(ImageProvider<Object> imageProvider) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      barrierColor: Colors.black,
      builder: (ctx) {
        final pad = MediaQuery.paddingOf(ctx);
        final sz = MediaQuery.sizeOf(ctx);
        return Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PhotoView(
                imageProvider: imageProvider,
                gaplessPlayback: true,
                minScale: PhotoViewComputedScale.contained * 0.85,
                maxScale: PhotoViewComputedScale.covered * 4,
                initialScale: PhotoViewComputedScale.contained,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                loadingBuilder: (c, event) => const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
                filterQuality: FilterQuality.medium,
                customSize: sz,
              ),
              Positioned(
                top: pad.top + 8,
                right: 12,
                child: IconButton(
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withAlpha(140)),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showBadgePicker() async {
    if (_isEditing) return;
    final s = S.of(context);
    final options = <MemoryBadge>[
      if (!_isEditing) MemoryBadgesCatalog.otherBadge,
      ...widget.availableBadges,
    ];
    if (options.isEmpty) return;

    final picked = await showModalBottomSheet<MemoryBadge>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        final maxListHeight = MediaQuery.sizeOf(sheetCtx).height * 0.65;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  s.memoryChooseBadgeTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxListHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.black.withAlpha(18),
                    ),
                    itemBuilder: (_, index) {
                      final badge = options[index];
                      final title = s.memoryBadgeTitle(badge);
                      final selected = _selectedBadge?.id == badge.id;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        leading: MemoryBadgeIcon(
                          badge: badge,
                          size: 30,
                          muted: false,
                        ),
                        title: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle,
                                color: AppTheme.ctaPrimary)
                            : null,
                        onTap: () => Navigator.of(sheetCtx).pop(badge),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedBadge = picked);
    }
  }

  Future<void> _pickDateTime() async {
    final d = await showAppDatePicker(
      context: context,
      initialDate: _memoryDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_memoryDate));
    if (t == null || !mounted) return;
    setState(
        () => _memoryDate = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  ({DateTime? enabledAt, DateTime? disabledAt}) _publicTimestampsForSave() {
    final prev = widget.initialMemory;
    if (_isPublic) {
      final enabledAt = (prev?.isPublic == true)
          ? (prev!.publicEnabledAt ?? DateTime.now())
          : DateTime.now();
      return (enabledAt: enabledAt, disabledAt: null);
    }
    final enabledAt = prev?.publicEnabledAt;
    final disabledAt =
        (prev?.isPublic == true) ? DateTime.now() : prev?.publicDisabledAt;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.weeklyPhotoPublicNeedPhoto)));
      return;
    }
    final accepted = await showWeeklyPhotoPublicConfirmDialog(context);
    if (!accepted || !mounted) return;
    setState(() => _isPublic = true);
  }

  Future<void> _save() async {
    if (_saving) return;
    final selectedBadge = _selectedBadge;
    if (selectedBadge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).memoryChooseBadgeTitle)),
      );
      return;
    }
    if (_isOtherBadgeSelected) {
      if (_customBadgeName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).memoryOtherBadgeNameRequired)),
        );
        return;
      }
      if (_customBadgeName.length > 25) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).memoryOtherBadgeNameTooLong)),
        );
        return;
      }
    }
    final hasPhoto = _hasLocalPickedB64 || _hasPhotoUrl;
    final hasText =
        _descCtrl.text.trim().isNotEmpty || _notesCtrl.text.trim().isNotEmpty;
    if (!hasPhoto && !hasText) {
      final msg = S.of(context).memorySaveNeedPhotoOrText;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    if (!FeatureAccess.canSaveNewMemoryMoment(
      controller: widget.controller,
      badgeId: selectedBadge.id,
      isEditing: _isEditing,
    )) {
      await showMemoryPremiumLimitDialog(context);
      return;
    }
    setState(() => _saving = true);
    try {
      final birth = widget.babyBirthDate;
      final autoAge = (birth == null)
          ? null
          : S
              .of(context)
              .memorySuggestedAgeBetween(birth: birth, when: _memoryDate);
      final autoWeight = widget.currentWeightKg;
      final autoHeight = widget.currentHeightCm;

      final finalAge =
          _ageCtrl.text.trim().isEmpty ? autoAge : _ageCtrl.text.trim();
      final finalWeight = _weightCtrl.text.trim().isEmpty
          ? autoWeight
          : _parseDouble(_weightCtrl.text);
      final finalHeight = _heightCtrl.text.trim().isEmpty
          ? autoHeight
          : _parseDouble(_heightCtrl.text);

      final prev = widget.initialMemory;
      final pubTs = _publicTimestampsForSave();
      final badgeId = _isOtherBadgeSelected
          ? '${MemoryBadgesCatalog.customBadgePrefix}${DateTime.now().microsecondsSinceEpoch}'
          : selectedBadge.id;
      final badgeTitle = _isOtherBadgeSelected
          ? _customBadgeName
          : S.of(context).memoryBadgeTitle(selectedBadge);
      // Só sobrescrever [photoUrl] / limpar b64 quando há ficheiro novo; senão preserva nuvem/cache local (linha só com URL).
      final m = BabyMemory(
        id: prev?.id,
        babyId: widget.babyId,
        badgeId: prev?.badgeId ?? badgeId,
        title: _isEditing ? (prev?.title ?? badgeTitle) : badgeTitle,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        photoB64: _hasLocalPickedB64 ? _photoB64 : prev?.photoB64,
        photoUrl: _hasLocalPickedB64 ? null : prev?.photoUrl,
        createdAt: prev?.createdAt ?? DateTime.now(),
        memoryDate: _memoryDate,
        babyAgeAtMoment: (finalAge == null || finalAge.trim().isEmpty)
            ? null
            : finalAge.trim(),
        weightAtMoment: finalWeight,
        heightAtMoment: finalHeight,
        moodAtMoment:
            _moodCtrl.text.trim().isEmpty ? null : _moodCtrl.text.trim(),
        motherNotes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
    final selectedBadge = _selectedBadge;
    final bytes = _photoBytesDecoded;
    final photoUrlTrim = _photoUrl?.trim();
    final dt = _memoryDate;
    final dateLabel = formatMemoryMomentDateTime(context, dt);
    final isNight = PortalTimeOfDay.isNight(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(_isEditing ? s.memoryEditTitle : s.memoryNewTitle),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: FaceBabySpinner(size: 22, strokeWidth: 2.6))
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
                _MemoryNightPanel(
                  enabled: isNight,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (selectedBadge != null)
                            MemoryBadgeIcon(
                                badge: selectedBadge,
                                muted: !_hasPhotoForUi,
                                size: 22)
                          else
                            const Icon(Icons.add_circle_outline_rounded,
                                size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedBadge == null
                                  ? s.memoryAddBadgeCta
                                  : s.memoryBadgeTitle(selectedBadge),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isNight
                                    ? PortalTimeOfDay.nightOutlinedTextColor
                                    : null,
                                shadows: isNight
                                    ? PortalTimeOfDay.nightTextOutlineShadows
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _pickDateTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(dateLabel),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
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
                      Text(
                        s.memoryChooseBadgeTitle,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isEditing ? null : _showBadgePicker,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              isDense: true,
                              enabled: !_isEditing,
                              suffixIcon: _isEditing
                                  ? null
                                  : const Icon(Icons.arrow_drop_down_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (selectedBadge != null) ...[
                                  MemoryBadgeIcon(
                                    badge: selectedBadge,
                                    size: 24,
                                    muted: false,
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    selectedBadge == null
                                        ? s.memoryChooseBadgeTitle
                                        : s.memoryBadgeTitle(selectedBadge),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: selectedBadge == null
                                          ? AppTheme.textMuted
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_isOtherBadgeSelected) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customBadgeNameCtrl,
                          maxLength: 25,
                          decoration: InputDecoration(
                            labelText: s.memoryOtherBadgeNameLabel,
                            hintText: s.memoryOtherBadgeNameHint,
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _MemoryNightPanel(
                  enabled: isNight,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CardBox(
                        color: isNight ? Colors.transparent : null,
                        showShadow: !isNight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _isEditing
                                    ? s.memoryPhotoEditTitle
                                    : s.memoryPhotoAddTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Material(
                              color: Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 4),
                                child: LayoutBuilder(
                                  builder: (context, c) {
                                    final photoSide =
                                        (MediaQuery.sizeOf(context).width *
                                                0.34)
                                            .clamp(104.0, 148.0);

                                    Widget circleChild;
                                    if (!_hasPhotoForUi) {
                                      circleChild = SizedBox(
                                        width: photoSide,
                                        height: photoSide,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withAlpha(210),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppTheme.primaryPurple
                                                  .withAlpha(45),
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.add_a_photo_rounded,
                                            size: 42,
                                            color: AppTheme.primaryPurple
                                                .withAlpha(175),
                                          ),
                                        ),
                                      );
                                    } else {
                                      final Widget ovalImage;
                                      if (bytes != null) {
                                        ovalImage = Image.memory(bytes,
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                            alignment: Alignment.center);
                                      } else if (photoUrlTrim != null &&
                                          photoUrlTrim.isNotEmpty) {
                                        ovalImage = CachedMemoryPhoto(
                                          imageUrl: photoUrlTrim,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                          filterQuality: FilterQuality.medium,
                                          placeholder: (_, __) => Center(
                                            child: FaceBabySpinner(
                                                size: photoSide * 0.35,
                                                strokeWidth: 2.6),
                                          ),
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                            color: MemoryBadgeIcon
                                                .mutedDiskBackground,
                                            alignment: Alignment.center,
                                            child: Icon(
                                                Icons.broken_image_outlined,
                                                size: photoSide * 0.35,
                                                color: Colors.black45),
                                          ),
                                        );
                                      } else {
                                        ovalImage = const SizedBox.shrink();
                                      }
                                      circleChild = SizedBox(
                                        width: photoSide,
                                        height: photoSide,
                                        child: ClipOval(
                                          child: SizedBox(
                                            width: photoSide,
                                            height: photoSide,
                                            child: ovalImage,
                                          ),
                                        ),
                                      );
                                    }

                                    final photoLeading = _hasPhotoForUi
                                        ? Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              customBorder:
                                                  const CircleBorder(),
                                              onTap: _openPhotoFullscreen,
                                              child:
                                                  ClipOval(child: circleChild),
                                            ),
                                          )
                                        : ClipOval(child: circleChild);

                                    final content = Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        photoLeading,
                                        const SizedBox(height: 10),
                                        TextButton.icon(
                                          onPressed: _pickPhoto,
                                          icon: Icon(
                                            _hasPhotoForUi
                                                ? Icons.photo_camera_outlined
                                                : Icons
                                                    .add_photo_alternate_outlined,
                                            size: 18,
                                          ),
                                          label: Text(_hasPhotoForUi
                                              ? s.memoryPhotoEditTitle
                                              : s.memoryTapToPickPhoto),
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            textStyle: const TextStyle(
                                                fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                      ],
                                    );

                                    if (!_hasPhotoForUi) {
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: _pickPhoto,
                                        child: Center(child: content),
                                      );
                                    }
                                    return Center(child: content);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isNight ? 0 : 14),
                      CardBox(
                        color: isNight ? Colors.transparent : null,
                        showShadow: !isNight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.memoryTellMomentTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
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
                            Text(s.memoryBabyInfoOptionalTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _CompactMemoryField(
                                    controller: _ageCtrl,
                                    label: s.contactFieldAge,
                                    hint: s.memoryAgeHintExample,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: _CompactMemoryField(
                                    controller: _weightCtrl,
                                    label: s.memoryStatWeightLabel,
                                    hint: s.memoryWeightHintExample,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: _CompactMemoryField(
                                    controller: _heightCtrl,
                                    label: s.memoryStatHeightLabel,
                                    hint: s.memoryHeightHintExample,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _moodCtrl,
                              decoration: InputDecoration(
                                labelText: s.memoryBabyMoodLabel,
                                hintText: s.memoryBabyMoodHint,
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _notesCtrl,
                              minLines: 2,
                              maxLines: 5,
                              decoration: InputDecoration(
                                  labelText: s.memoryMomNotesFieldLabel,
                                  border: const OutlineInputBorder()),
                            ),
                            const SizedBox(height: 18),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.weeklyPhotoPublicOff,
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontWeight: !_isPublic
                                              ? FontWeight.w900
                                              : FontWeight.w600,
                                          fontSize: 15,
                                          color: !_isPublic
                                              ? AppTheme.textPrimary
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: _isPublic,
                                      onChanged: _saving
                                          ? null
                                          : (v) {
                                              if (v) {
                                                unawaited(_requestPublicOn());
                                              } else {
                                                unawaited(_requestPublicOff());
                                              }
                                            },
                                    ),
                                    Expanded(
                                      child: Text(
                                        s.weeklyPhotoPublicOn,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          fontWeight: _isPublic
                                              ? FontWeight.w900
                                              : FontWeight.w600,
                                          fontSize: 15,
                                          color: _isPublic
                                              ? AppTheme.textPrimary
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  s.weeklyPhotoPublicExplainer,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                            if (_isPublic) ...[
                              const SizedBox(height: 4),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(s.weeklyPhotoShowBabyFirstName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                value: _showBabyFirstNameWhenPublic,
                                onChanged: _saving
                                    ? null
                                    : (v) {
                                        setState(() =>
                                            _showBabyFirstNameWhenPublic = v);
                                      },
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              s.weeklyPhotoDisclaimerFooter,
                              style: const TextStyle(
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
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.ctaPrimary),
                                child: Text(_isEditing
                                    ? s.memorySaveChanges
                                    : s.memorySaveNew),
                              ),
                            ),
                          ],
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

class _CompactMemoryField extends StatelessWidget {
  const _CompactMemoryField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: 1,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      ),
    );
  }
}

class _MemoryNightPanel extends StatelessWidget {
  const _MemoryNightPanel({
    required this.enabled,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final bool enabled;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(178),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withAlpha(140)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
