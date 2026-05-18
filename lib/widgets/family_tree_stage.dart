import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../models/daily_summary.dart';
import '../services/family_christian_content_service.dart';
import '../services/family_zodiac_content_service.dart';
import '../services/premium/feature_access.dart';
import '../utils/family_zodiac_art.dart';
import '../utils/family_height_estimate.dart';
import '../utils/measurement_format.dart';
import '../utils/memory_share_file.dart';
import '../utils/memory_share_transport.dart';
import '../utils/zodiac_keys.dart';
import 'family_hub_widgets.dart';
import 'photo_avatar.dart';

/// Integrantes da família sobre a ilustração da árvore (separadores + cartão).
class FamilyTreeStage extends StatefulWidget {
  const FamilyTreeStage({
    super.key,
    required this.s,
    required this.zodiacUnlocked,
    required this.zodiacReady,
    this.showChristianMessages = false,
    this.showHoroscopeMessages = true,
    this.christianReady = false,
    required this.mother,
    required this.babies,
    required this.heightCmByBabyId,
    required this.fatherRegistered,
    this.initialTabIndex = 0,

    /// Se true, os separadores ficam numa coluna à esquerda; se false, numa linha horizontal.
    this.verticalMemberTabs = false,
    this.onEditMother,
    this.onEditFather,
    this.onEditBaby,
    this.premiumZodiacLockedMessage,
    this.premiumUnlockCta,
    this.onPremiumTap,
    this.todaySummary,
    this.summaryDay,
    this.summaryDayLabel,
    this.isTodaySummaryDay = true,
    this.onPickSummaryDay,
    this.onTodaySummaryDay,
    this.lastFeedEndedAt,
    this.lastDiaperChangedAt,
    this.lastSleepEndedAt,
  });

  static const treeAsset = 'assets/family/family_tree.png';

  final S s;
  final bool zodiacUnlocked;
  final bool zodiacReady;
  final bool showChristianMessages;
  final bool showHoroscopeMessages;
  final bool christianReady;
  final Map<String, Object?>? mother;
  final List<Map<String, Object?>> babies;
  final Map<int, double> heightCmByBabyId;
  final bool fatherRegistered;

  /// Índice inicial no separador (ex.: bebé actual por defeito).
  final int initialTabIndex;
  final bool verticalMemberTabs;
  final VoidCallback? onEditMother;
  final VoidCallback? onEditFather;
  final void Function(int babyId)? onEditBaby;
  final String? premiumZodiacLockedMessage;
  final String? premiumUnlockCta;
  final VoidCallback? onPremiumTap;
  final DailySummary? todaySummary;
  final DateTime? summaryDay;
  final String? summaryDayLabel;
  final bool isTodaySummaryDay;
  final VoidCallback? onPickSummaryDay;
  final VoidCallback? onTodaySummaryDay;
  final DateTime? lastFeedEndedAt;
  final DateTime? lastDiaperChangedAt;
  final DateTime? lastSleepEndedAt;

  @override
  State<FamilyTreeStage> createState() => _FamilyTreeStageState();
}

class _CarouselMember {
  const _CarouselMember({required this.slot, required this.model});

  final String slot;
  final FamilyMemberFrameModel model;
}

class _FamilyTreeStageState extends State<FamilyTreeStage> {
  bool _shareBusy = false;
  late int _selectedIndex;

  static String _slotKeyMother() => 'mother';
  static String _slotKeyFather() => 'father';
  static String _slotKeyBaby(int babyId) => 'baby_$babyId';

  @override
  void initState() {
    super.initState();
    final members = _buildMembers();
    final maxI = members.isEmpty ? 0 : members.length - 1;
    _selectedIndex = widget.initialTabIndex.clamp(0, maxI);
  }

  @override
  void didUpdateWidget(covariant FamilyTreeStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final members = _buildMembers();
    if (members.isEmpty) return;
    if (_selectedIndex >= members.length) {
      setState(() => _selectedIndex = members.length - 1);
      return;
    }
    if (oldWidget.initialTabIndex != widget.initialTabIndex ||
        oldWidget.fatherRegistered != widget.fatherRegistered) {
      final i = widget.initialTabIndex.clamp(0, members.length - 1);
      if (i != _selectedIndex) setState(() => _selectedIndex = i);
    }
  }

  List<_CarouselMember> _buildMembers() {
    final list = <_CarouselMember>[];
    if (widget.fatherRegistered) {
      list.add(
        _CarouselMember(slot: _slotKeyFather(), model: _modelForFather()),
      );
    }
    list.add(_CarouselMember(slot: _slotKeyMother(), model: _modelForMother()));
    for (final baby in widget.babies) {
      final id = (baby['id'] as num?)?.toInt();
      if (id == null) continue;
      list.add(
        _CarouselMember(slot: _slotKeyBaby(id), model: _modelForBaby(baby)),
      );
    }
    return list;
  }

  DailySummary get _hubSummary =>
      widget.todaySummary ??
      const DailySummary(
        feedings: 0,
        feedingMinutesTotal: 0,
        sleep: '0m',
        sleepSessions: 0,
        diapers: 0,
        diaperPee: 0,
        diaperPoo: 0,
        weight: '—',
        sleepTotalSeconds: 0,
      );

  Map<String, Object?>? _babyMapFromSlot(String slot) {
    if (!slot.startsWith('baby_')) return null;
    final id = int.tryParse(slot.substring(5));
    if (id == null) return null;
    for (final b in widget.babies) {
      if ((b['id'] as num?)?.toInt() == id) return b;
    }
    return null;
  }

  Widget _legacyTreeBlock(
    BuildContext context,
    double stackH,
    List<_CarouselMember> members,
    int tabIndex,
  ) {
    return SizedBox(
      height: stackH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFEAF6EA),
                          Color(0xFFD4EDD4),
                          Color(0xFFB8DFB8),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: stackH * 0.62,
                    child: Image.asset(
                      FamilyTreeStage.treeAsset,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      errorBuilder: (_, __, ___) => const Align(
                        alignment: Alignment.bottomCenter,
                        child: Icon(
                          Icons.park_rounded,
                          size: 96,
                          color: Color(0xFF7CB87C),
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withAlpha(100),
                          Colors.transparent,
                          Colors.transparent,
                          const Color(0xFF8BC48B).withAlpha(28),
                        ],
                        stops: const [0.0, 0.22, 0.55, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            bottom: stackH * 0.12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _selectedMemberCard(members[tabIndex]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _babyHubDetailColumn(
    BuildContext context,
    _CarouselMember heroBaby,
    Map<String, Object?> babyMap,
    DateTime? bb,
  ) {
    final s = widget.s;
    final model = heroBaby.model;
    final babyId = (babyMap['id'] as num?)?.toInt();
    final h = babyId == null
        ? (babyMap['height_cm'] as num?)?.toDouble()
        : widget.heightCmByBabyId[babyId] ??
            (babyMap['height_cm'] as num?)?.toDouble();
    final wKg = (babyMap['weight_kg'] as num?)?.toDouble();
    final birthDateStr = bb == null ? '—' : fmtDate(bb);
    final weightStr = wKg == null || wKg <= 0
        ? '—'
        : MeasurementFormat.weight(wKg, decimalsKg: 2);
    final heightStr =
        h == null || h <= 0 ? '—' : MeasurementFormat.length(h, decimalsCm: 0);
    final bzStored = (babyMap['zodiac_sign'] as String?)?.trim();
    final signId = model.signId ?? (bb == null ? null : zodiacIdFromDate(bb));
    final signName = signId != null
        ? s.familyZodiacName(signId)
        : (bzStored != null && bzStored.isNotEmpty ? bzStored : '—');
    final ageLabel = bb == null ? '—' : s.babyAgeLabel(bb, DateTime.now());
    final horoscopeTitle = signId != null
        ? s.familyHoroscopeCardTitle(signId)
        : (bb != null
            ? s.familyHoroscopeCardTitle(zodiacIdFromDate(bb))
            : s.familyHoroscopeCardTitle(ZodiacId.pisces));
    final babySex = (babyMap['sex'] as String?)?.trim().toUpperCase();
    final motherHeightCm = (widget.mother?['height_cm'] as num?)?.toDouble();
    final fatherHeightCm =
        (widget.mother?['father_height_cm'] as num?)?.toDouble();
    final estimatedHeightCm = FamilyHeightEstimate.tryCompute(
      babySex: babySex,
      motherHeightCm: motherHeightCm,
      fatherHeightCm: fatherHeightCm,
    );
    final heightEstimateUnlocked = FeatureAccess.canViewFamilyHeightEstimate;
    final showHeightEstimate = estimatedHeightCm != null && babySex != null;
    final heightEstimateAsset = babySex == 'F'
        ? 'assets/family/regua_menina.png'
        : 'assets/family/regua_menino.png';
    final heightEstimateBody = estimatedHeightCm == null
        ? null
        : heightEstimateUnlocked
            ? s.familyEstimatedResult(
                MeasurementFormat.length(estimatedHeightCm, decimalsCm: 0),
              )
            : s.familyPremiumHeightLocked;
    final heightEstimateDescription = heightEstimateUnlocked
        ? s.familyEstimatedHeightDescription
        : s.familyPremiumUnlockCta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FamilyHubBabyHeroCard(
          s: s,
          babyName: model.name,
          ageLabel: ageLabel,
          birthDateStr: birthDateStr,
          weightStr: weightStr,
          heightStr: heightStr,
          signDisplayName: signName,
          showZodiac: widget.showHoroscopeMessages,
          babyAvatar: model.avatar,
          signId: signId,
          heightEstimateTitle: showHeightEstimate
              ? s.familyEstimatedHeightTitle(model.name)
              : null,
          heightEstimateBody: heightEstimateBody,
          heightEstimateDescription:
              showHeightEstimate ? heightEstimateDescription : null,
          heightEstimateAsset: showHeightEstimate ? heightEstimateAsset : null,
          onTap: model.onEdit,
        ),
        const SizedBox(height: 14),
        FamilyHubContentCards(
          s: s,
          horoscopeTitle: horoscopeTitle,
          horoscopeBody: model.horoscopePremiumBody,
          bibleTitle: s.familyBibleVerseCardTitle,
          bibleBody: model.christianFreeBody,
          bibleReference: _christianReference(model.role, babyId: babyId),
          showHoroscope: widget.showHoroscopeMessages,
          showChristian: widget.showChristianMessages,
          contentUnlocked: widget.zodiacUnlocked,
          signId: signId,
        ),
        const SizedBox(height: 16),
        FamilyHubDailySummaryStrip(
          s: s,
          summary: _hubSummary,
          dayLabel: widget.summaryDayLabel,
          isToday: widget.isTodaySummaryDay,
          onPickDay: widget.onPickSummaryDay,
          onToday: widget.onTodaySummaryDay,
          lastFeed: widget.lastFeedEndedAt,
          lastDiaper: widget.lastDiaperChangedAt,
          lastSleep: widget.lastSleepEndedAt,
        ),
        const SizedBox(height: 16),
        FamilyHubPremiumBanner(s: s, onPremiumTap: widget.onPremiumTap),
      ],
    );
  }

  Widget _adultHubDetailColumn(
    BuildContext context,
    _CarouselMember member,
  ) {
    final s = widget.s;
    final model = member.model;
    final mother = widget.mother;
    final isFather = model.role == FamilyMemberRole.father;
    final birth = _parseDate(
      isFather
          ? (mother?['father_birth_date'] as String?)
          : (mother?['birth_date'] as String?),
    );
    final height = (isFather
            ? (mother?['father_height_cm'] as num?)
            : (mother?['height_cm'] as num?))
        ?.toDouble();
    final signId =
        model.signId ?? (birth == null ? null : zodiacIdFromDate(birth));
    final signName = signId == null ? '—' : s.familyZodiacName(signId);
    final ageLabel = birth == null
        ? '—'
        : s.familyAgeYears(ageInYears(birth, DateTime.now()));
    final birthDateStr = birth == null ? '—' : fmtDate(birth);
    final heightStr = height == null || height <= 0
        ? '—'
        : MeasurementFormat.length(height, decimalsCm: 0);
    final horoscopeTitle = signId == null
        ? model.sectionTitle
        : s.familyHoroscopeCardTitle(signId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FamilyHubAdultHeroCard(
          s: s,
          roleLabel: model.badge,
          name: model.name,
          ageLabel: ageLabel,
          birthDateStr: birthDateStr,
          heightStr: heightStr,
          signDisplayName: signName,
          showZodiac: widget.showHoroscopeMessages,
          avatar: model.avatar,
          accent: model.badgeColor,
          signId: signId,
          onTap: model.onEdit,
        ),
        const SizedBox(height: 14),
        FamilyHubContentCards(
          s: s,
          horoscopeTitle: horoscopeTitle,
          horoscopeBody: model.horoscopePremiumBody,
          bibleTitle: s.familyBibleVerseCardTitle,
          bibleBody: model.christianFreeBody,
          bibleReference: _christianReference(model.role),
          showHoroscope: widget.showHoroscopeMessages,
          showChristian: widget.showChristianMessages,
          contentUnlocked: widget.zodiacUnlocked,
          signId: signId,
        ),
        const SizedBox(height: 16),
        FamilyHubPremiumBanner(s: s, onPremiumTap: widget.onPremiumTap),
      ],
    );
  }

  Widget _buildModernFamilyHub(
    BuildContext context,
    List<_CarouselMember> members,
    int tabIndex,
  ) {
    final motherI = members.indexWhere((m) => m.slot == _slotKeyMother());
    final fatherI = members.indexWhere((m) => m.slot == _slotKeyFather());
    final firstBabyI = members.indexWhere((m) => m.slot.startsWith('baby_'));
    final current = members[tabIndex];
    final heroBaby = current.model.role == FamilyMemberRole.baby
        ? current
        : (firstBabyI >= 0 ? members[firstBabyI] : null);
    final babyMap = heroBaby == null ? null : _babyMapFromSlot(heroBaby.slot);
    final bb =
        babyMap == null ? null : _parseDate(babyMap['birth_date'] as String?);
    final showRibbon = motherI >= 0 && heroBaby != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRibbon)
          FamilyHubAvatarRibbon(
            motherLabel: members[motherI].model.name,
            motherAvatar: members[motherI].model.avatar,
            motherSelected: tabIndex == motherI,
            onMother: () => setState(() => _selectedIndex = motherI),
            babyLabel: heroBaby.model.name,
            babyAvatar: heroBaby.model.avatar,
            babySelected: current.model.role == FamilyMemberRole.baby,
            onBaby: () {
              if (firstBabyI >= 0) setState(() => _selectedIndex = firstBabyI);
            },
            fatherLabel: fatherI >= 0 ? members[fatherI].model.name : null,
            fatherAvatar: fatherI >= 0 ? members[fatherI].model.avatar : null,
            fatherSelected: tabIndex == fatherI,
            onFather: fatherI >= 0
                ? () => setState(() => _selectedIndex = fatherI)
                : null,
          ),
        if (showRibbon) const SizedBox(height: 14),
        if (heroBaby != null &&
            babyMap != null &&
            current.model.role == FamilyMemberRole.baby)
          _babyHubDetailColumn(context, heroBaby, babyMap, bb)
        else if (current.model.role == FamilyMemberRole.mother ||
            current.model.role == FamilyMemberRole.father)
          _adultHubDetailColumn(context, current)
        else
          _selectedMemberCard(current),
      ],
    );
  }

  static String fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  FamilyMemberFrameModel _modelForMother() {
    final s = widget.s;
    final now = DateTime.now();
    final mother = widget.mother;
    const role = FamilyMemberRole.mother;
    final mb = _parseDate(mother?['birth_date'] as String?);
    final mh = (mother?['height_cm'] as num?)?.toDouble();
    final signId = mb == null ? null : zodiacIdFromDate(mb);
    return FamilyMemberFrameModel(
      role: role,
      badge: s.familyRoleMother,
      badgeColor: const Color(0xFFE15A72),
      name: (mother?['name'] as String?)?.trim().isNotEmpty == true
          ? (mother!['name'] as String).trim()
          : '—',
      avatar: PhotoAvatar(
        photoB64: (mother?['photo_b64'] as String?)?.trim(),
        photoUrl: (mother?['photo_url'] as String?)?.trim(),
        radius: 50,
        backgroundColor: const Color(0xFFFFDCE8),
        fallback: const Text('👩', style: TextStyle(fontSize: 40)),
      ),
      infoLines: [
        if (mb != null) s.familyBornOn(fmtDate(mb)),
        if (mb != null) s.familyAgeYears(ageInYears(mb, now)),
        if (widget.showHoroscopeMessages && signId != null)
          '${s.familyZodiacName(signId)} · ${s.familyZodiacSolar}',
        if (mh != null && mh > 0)
          s.familyHeight(MeasurementFormat.length(mh, decimalsCm: 0)),
      ],
      sectionTitle: _sectionTitle(signId, s.familyRoleMother),
      signId: signId,
      horoscopePremiumBody:
          _horoscopePremiumNarrative(FamilyZodiacRole.mother, signId),
      christianFreeBody: _christianCardBody(role),
      onEdit: widget.onEditMother,
    );
  }

  FamilyMemberFrameModel _modelForFather() {
    final s = widget.s;
    final now = DateTime.now();
    final mother = widget.mother;
    const role = FamilyMemberRole.father;
    final fb = _parseDate(mother?['father_birth_date'] as String?);
    final fh = (mother?['father_height_cm'] as num?)?.toDouble();
    final signId = fb == null ? null : zodiacIdFromDate(fb);
    return FamilyMemberFrameModel(
      role: role,
      badge: s.familyRoleFather,
      badgeColor: const Color(0xFF4D99DE),
      name: (mother?['father_name'] as String?)?.trim().isNotEmpty == true
          ? (mother!['father_name'] as String).trim()
          : s.familyRoleFather,
      avatar: PhotoAvatar(
        photoB64: (mother?['father_photo_b64'] as String?)?.trim(),
        photoUrl: (mother?['father_photo_url'] as String?)?.trim(),
        radius: 50,
        backgroundColor: const Color(0xFFD6EBFF),
        fallback: const Text('👨', style: TextStyle(fontSize: 40)),
      ),
      infoLines: [
        if (fb != null) s.familyBornOn(fmtDate(fb)),
        if (fb != null) s.familyAgeYears(ageInYears(fb, now)),
        if (widget.showHoroscopeMessages && signId != null)
          '${s.familyZodiacName(signId)} · ${s.familyZodiacSolar}',
        if (fh != null && fh > 0)
          s.familyHeight(MeasurementFormat.length(fh, decimalsCm: 0)),
      ],
      sectionTitle: _sectionTitle(signId, s.familyRoleFather),
      signId: signId,
      horoscopePremiumBody:
          _horoscopePremiumNarrative(FamilyZodiacRole.father, signId),
      christianFreeBody: _christianCardBody(role),
      onEdit: widget.onEditFather ?? widget.onEditMother,
    );
  }

  FamilyMemberFrameModel _modelForBaby(Map<String, Object?> baby) {
    final s = widget.s;
    final now = DateTime.now();
    const role = FamilyMemberRole.baby;
    final babyId = (baby['id'] as num?)?.toInt();
    final bb = _parseDate(baby['birth_date'] as String?);
    final sex = (baby['sex'] as String?)?.trim().toUpperCase();
    final bzStored = (baby['zodiac_sign'] as String?)?.trim();
    final signId = bb == null ? null : zodiacIdFromDate(bb);
    final h = babyId == null
        ? (baby['height_cm'] as num?)?.toDouble()
        : widget.heightCmByBabyId[babyId] ??
            (baby['height_cm'] as num?)?.toDouble();
    const avatarR = 46.0;
    const emojiSize = 38.0;
    return FamilyMemberFrameModel(
      role: role,
      badge: s.familyRoleBaby,
      badgeColor: const Color(0xFF8D5CF6),
      name: (baby['name'] as String?)?.trim().isNotEmpty == true
          ? (baby['name'] as String).trim()
          : s.baby,
      avatar: PhotoAvatar(
        photoB64: (baby['photo_b64'] as String?)?.trim(),
        photoUrl: (baby['photo_url'] as String?)?.trim(),
        radius: avatarR,
        backgroundColor:
            sex == 'M' ? const Color(0xFFD6EBFF) : const Color(0xFFFFDCE8),
        fallback: const Text('👶', style: TextStyle(fontSize: emojiSize)),
      ),
      infoLines: [
        if (bb != null) s.familyBornOn(fmtDate(bb)),
        if (sex == 'M' || sex == 'F') sex == 'M' ? s.regBabyBoy : s.regBabyGirl,
        if (bb != null) s.babyAgeLabel(bb, now),
        if (widget.showHoroscopeMessages)
          bzStored != null && bzStored.isNotEmpty
              ? '$bzStored · ${s.familyZodiacSolar}'
              : signId == null
                  ? '—'
                  : '${s.familyZodiacName(signId)} · ${s.familyZodiacSolar}',
        if (h != null && h > 0)
          s.familyHeight(MeasurementFormat.length(h, decimalsCm: 0)),
      ],
      sectionTitle: _sectionTitleBaby(signId, bzStored, s.familyRoleBaby),
      signId: signId,
      horoscopePremiumBody:
          _horoscopePremiumNarrative(FamilyZodiacRole.baby, signId),
      christianFreeBody: _christianCardBody(role, babyId: babyId),
      onEdit: babyId == null || widget.onEditBaby == null
          ? null
          : () => widget.onEditBaby!(babyId),
    );
  }

  FamilyChristianRole _christianRole(FamilyMemberRole role) => switch (role) {
        FamilyMemberRole.mother => FamilyChristianRole.mother,
        FamilyMemberRole.father => FamilyChristianRole.father,
        FamilyMemberRole.baby => FamilyChristianRole.baby,
      };

  String? _christianReference(FamilyMemberRole role, {int? babyId}) {
    if (!widget.showChristianMessages || !widget.christianReady) return null;
    return FamilyChristianContentService.instance
        .verseFor(widget.s.lang, _christianRole(role), babyId: babyId)
        ?.reference;
  }

  String _christianCardBody(FamilyMemberRole role, {int? babyId}) {
    if (!widget.showChristianMessages || !widget.christianReady) return '';
    return _christianNarrative(role, babyId: babyId);
  }

  /// Título do cartão: signo + papel (se horóscopo ligado), mesmo sem Premium.
  String _sectionTitle(ZodiacId? signId, String roleLabel) {
    final s = widget.s;
    if (widget.showHoroscopeMessages && signId != null) {
      return '${s.familyZodiacName(signId)} · $roleLabel';
    }
    if (widget.showChristianMessages) return s.familyChristianCardTitle;
    return roleLabel;
  }

  String _sectionTitleBaby(
    ZodiacId? signId,
    String? bzStored,
    String roleLabel,
  ) {
    final s = widget.s;
    if (widget.showHoroscopeMessages) {
      if (signId != null) {
        return '${s.familyZodiacName(signId)} · $roleLabel';
      }
      final bz = bzStored?.trim();
      if (bz != null && bz.isNotEmpty) {
        return '$bz · $roleLabel';
      }
    }
    if (widget.showChristianMessages) return s.familyChristianCardTitle;
    return roleLabel;
  }

  String _zodiacOnlyBody(FamilyZodiacRole contentRole, ZodiacId? signId) {
    if (!widget.showHoroscopeMessages || !widget.zodiacUnlocked) return '';
    if (!widget.zodiacReady || signId == null) {
      return widget.s.familyEntertainmentNote;
    }
    return FamilyZodiacContentService.instance
            .body(widget.s.lang, signId, contentRole) ??
        widget.s.familyEntertainmentNote;
  }

  String _horoscopePremiumNarrative(
    FamilyZodiacRole zodiacRole,
    ZodiacId? signId,
  ) {
    return _zodiacOnlyBody(zodiacRole, signId);
  }

  String _christianNarrative(FamilyMemberRole role, {int? babyId}) {
    if (!widget.showChristianMessages || !widget.christianReady) return '';
    return FamilyChristianContentService.instance
        .body(
          widget.s.lang,
          _christianRole(role),
          babyId: babyId,
        )
        .trim();
  }

  String _tabLabelFor(_CarouselMember m) {
    final s = widget.s;
    if (m.slot == _slotKeyFather()) return s.familyRoleFather;
    if (m.slot == _slotKeyMother()) return s.familyRoleMother;
    if (m.slot.startsWith('baby_')) {
      if (widget.babies.length == 1) return s.familyTabNene;
      final name = m.model.name.trim();
      if (name.isNotEmpty && name != '—') return name;
      return s.familyRoleBaby;
    }
    return m.model.name;
  }

  Widget _memberTabChip(int index, _CarouselMember m) {
    final selected = index == _selectedIndex;
    const accent = Color(0xFF163B68);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: accent.withAlpha(selected ? 255 : 100), width: 1.5),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withAlpha(40),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            _tabLabelFor(m),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: -0.2,
              color: selected ? Colors.white : accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _memberTabsBar(List<_CarouselMember> members) {
    if (members.length <= 1) return const SizedBox.shrink();
    if (widget.verticalMemberTabs) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < members.length; i++) ...[
              _memberTabChip(i, members[i]),
              if (i < members.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < members.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _memberTabChip(i, members[i]),
          ],
        ],
      ),
    );
  }

  Widget _selectedMemberCard(_CarouselMember member) {
    final model = member.model;
    return _FamilyMemberCard(
      model: model,
      s: widget.s,
      zodiacUnlocked: widget.zodiacUnlocked,
      showHoroscopeMessages: widget.showHoroscopeMessages,
      isCenter: true,
      onShare: (key) => _shareCard(
        key,
        model.name.replaceAll(RegExp(r'[^\w]+'), '_').toLowerCase(),
      ),
      premiumZodiacLockedMessage: widget.premiumZodiacLockedMessage,
      onPremiumTap: widget.onPremiumTap,
    );
  }

  Future<void> _shareCard(GlobalKey key, String safeName) async {
    if (_shareBusy || kIsWeb) {
      if (mounted && kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.s.memoryShareWebOnlyMobile)),
        );
      }
      return;
    }
    setState(() => _shareBusy = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final png = await repaintBoundaryToPngBytes(key, pixelRatio: 3);
      final jpg = encodePngBytesToJpg(png, quality: 90);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await shareTempBytes(
        jpg,
        'facebaby_familia_${safeName}_$stamp.jpg',
        'image/jpeg',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.s.memoryShareError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _buildMembers();
    final s = widget.s;

    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    final tabIndex = _selectedIndex.clamp(0, members.length - 1);

    if (widget.verticalMemberTabs && members.length > 1) {
      return LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final screenH = MediaQuery.sizeOf(context).height;
          final stackH = math.max(w * 1.05, screenH * 0.48).clamp(480.0, 640.0);
          final treeBlock =
              _legacyTreeBlock(context, stackH, members, tabIndex);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: (w * 0.28).clamp(108.0, 148.0),
                    child: _memberTabsBar(members),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: treeBlock),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.familyTabsHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF163B68).withAlpha(165),
                ),
              ),
            ],
          );
        },
      );
    }

    return _buildModernFamilyHub(context, members, tabIndex);
  }

  @override
  void dispose() {
    super.dispose();
  }
}

enum FamilyMemberRole { mother, father, baby }

class FamilyMemberFrameModel {
  final FamilyMemberRole role;
  final String badge;
  final Color badgeColor;
  final String name;
  final Widget avatar;
  final List<String> infoLines;
  final String sectionTitle;
  final ZodiacId? signId;

  /// Texto longo do horóscopo (só com Premium); vazio se bloqueado.
  final String horoscopePremiumBody;

  /// Mensagem bíblica / afetiva (grátis); separada do bloco Premium.
  final String christianFreeBody;
  final VoidCallback? onEdit;

  const FamilyMemberFrameModel({
    required this.role,
    required this.badge,
    required this.badgeColor,
    required this.name,
    required this.avatar,
    required this.infoLines,
    required this.sectionTitle,
    required this.signId,
    required this.horoscopePremiumBody,
    required this.christianFreeBody,
    this.onEdit,
  });
}

/// Cartão com todos os detalhes visíveis (sem virar).
class _FamilyMemberCard extends StatefulWidget {
  const _FamilyMemberCard({
    required this.model,
    required this.s,
    required this.zodiacUnlocked,
    required this.showHoroscopeMessages,
    required this.isCenter,
    required this.onShare,
    this.premiumZodiacLockedMessage,
    this.onPremiumTap,
  });

  final FamilyMemberFrameModel model;
  final S s;
  final bool zodiacUnlocked;
  final bool showHoroscopeMessages;
  final bool isCenter;
  final void Function(GlobalKey key) onShare;
  final String? premiumZodiacLockedMessage;
  final VoidCallback? onPremiumTap;

  @override
  State<_FamilyMemberCard> createState() => _FamilyMemberCardState();
}

class _FamilyMemberCardState extends State<_FamilyMemberCard> {
  final GlobalKey _shareKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final s = widget.s;
    final center = widget.isCenter;
    final bodyFs = center ? 13.5 : 12.0;
    final titleFs = center ? 18.0 : 15.0;

    IconData iconForLine(String line) {
      final lower = line.toLowerCase();
      if (lower.contains('/') || lower.contains('nasc')) {
        return Icons.cake_outlined;
      }
      if (lower.contains('ano') ||
          lower.contains('semana') ||
          lower.contains('mês')) {
        return Icons.calendar_month_outlined;
      }
      if (lower.contains('solar') ||
          lower.contains('peixes') ||
          lower.contains('áries') ||
          lower.contains('aries') ||
          lower.contains('touro') ||
          lower.contains('gêmeos') ||
          lower.contains('gemeos') ||
          lower.contains('câncer') ||
          lower.contains('cancer') ||
          lower.contains('leão') ||
          lower.contains('leao') ||
          lower.contains('virgem') ||
          lower.contains('libra') ||
          lower.contains('escorpião') ||
          lower.contains('escorpiao') ||
          lower.contains('sagitário') ||
          lower.contains('sagitario') ||
          lower.contains('capricórnio') ||
          lower.contains('capricornio') ||
          lower.contains('aquário') ||
          lower.contains('aquario')) {
        return Icons.auto_awesome_rounded;
      }
      if (lower.contains('cm') || lower.contains('altura')) {
        return Icons.straighten_rounded;
      }
      return Icons.favorite_border_rounded;
    }

    Widget infoTile(String line) {
      return Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: m.badgeColor.withAlpha(14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: m.badgeColor.withAlpha(42)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(iconForLine(line), size: 15, color: m.badgeColor),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                line,
                style: TextStyle(
                  fontSize: bodyFs,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF163B68).withAlpha(220),
                  height: 1.22,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget zodiacBadge() {
      final id = m.signId;
      if (id == null) return const SizedBox.shrink();
      return Container(
        width: center ? 64 : 52,
        height: center ? 64 : 52,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(238),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: m.badgeColor.withAlpha(45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Image.asset(
          familyZodiacIconAsset(id),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.auto_awesome_rounded,
            color: m.badgeColor,
          ),
        ),
      );
    }

    return Material(
      elevation: center ? 16 : 6,
      shadowColor: Colors.black.withAlpha(center ? 55 : 30),
      borderRadius: BorderRadius.circular(center ? 24 : 20),
      color: Colors.white,
      child: RepaintBoundary(
        key: _shareKey,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            center ? 18 : 12,
            center ? 16 : 12,
            center ? 18 : 12,
            center ? 14 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(center ? 24 : 20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                m.badgeColor.withAlpha(12),
                Colors.white,
              ],
            ),
            border: Border.all(
              color: m.badgeColor.withAlpha(center ? 120 : 80),
              width: center ? 1.6 : 1.2,
            ),
          ),
          child: SingleChildScrollView(
            physics: center
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: m.badgeColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: m.badgeColor.withAlpha(45),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: m.avatar,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(215),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                m.badge,
                                style: TextStyle(
                                  fontSize: center ? 12 : 10,
                                  fontWeight: FontWeight.w900,
                                  color: m.badgeColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: titleFs,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF163B68),
                                height: 1.1,
                              ),
                            ),
                            if (m.sectionTitle != m.badge) ...[
                              const SizedBox(height: 3),
                              Text(
                                m.sectionTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: center ? 12.5 : 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF163B68).withAlpha(175),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      zodiacBadge(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final line in m.infoLines) infoTile(line),
                if (m.horoscopePremiumBody.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.badgeColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      m.horoscopePremiumBody,
                      style: TextStyle(
                        fontSize: center ? 12.5 : 11,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF163B68).withAlpha(200),
                      ),
                    ),
                  ),
                ],
                if (m.christianFreeBody.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF163B68).withAlpha(10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          familyChristianCrossAsset,
                          width: 34,
                          height: 34,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.menu_book_rounded,
                            size: 26,
                            color: m.badgeColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            m.christianFreeBody,
                            style: TextStyle(
                              fontSize: center ? 12.5 : 11,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF163B68).withAlpha(200),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (center) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (m.onEdit != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: m.onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            label: Text(s.familyEdit),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF163B68),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (m.onEdit != null) const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => widget.onShare(_shareKey),
                          icon: const Icon(Icons.ios_share_rounded, size: 20),
                          label: Text(s.familyShareCard),
                          style: FilledButton.styleFrom(
                            backgroundColor: m.badgeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.familyEntertainmentNote,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF163B68).withAlpha(140),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
