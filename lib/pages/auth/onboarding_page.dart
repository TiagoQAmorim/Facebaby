import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../pages/dev/logged_out_screen_mirror.dart';
import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../services/app_database.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_user_repository.dart';
import '../../services/firebase/profile_cloud_sync.dart';
import '../../services/measurement_units_prefs.dart';
import '../../services/onboarding_draft_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/br_date_picker.dart';
import '../../utils/login_platform.dart';
import '../../utils/portal_time_of_day.dart';
import '../../models/family_message_kind.dart';
import '../../models/family_message_prefs.dart';
import '../../utils/zodiac.dart';
import '../../utils/pick_image_b64.dart';
import '../../widgets/auth_screen_background.dart';
import '../../widgets/growth_ruler_picker.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/photo_avatar.dart';
import '../../widgets/ai_baby_history_form.dart';
import '../../repositories/ai/ai_profile_repository.dart';
import 'login_page.dart';

InputDecoration _modernInputDecoration({
  required String hintText,
  IconData? icon,
}) {
  const radius = 20.0;
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: _onboardingDarkBlue.withAlpha(125)),
    prefixIcon: icon == null ? null : Icon(icon, color: _onboardingDarkBlue),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: Colors.black.withAlpha(14)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: AppTheme.ctaPrimary, width: 1.6),
    ),
  );
}

class _OnboardingAssets {
  static const logo = 'assets/onboarding/logo.png';
  static const welcomeLogo = 'assets/onboarding/logo_welcome.png';
  /// Mesmo fundo diurno do portal ([PortalTimeOfDay.backgroundDay]).
  static const registrationBackground = PortalTimeOfDay.backgroundDay;
  static const loginBackground = PortalTimeOfDay.backgroundLogin;
  static const backgroundLoading = 'assets/onboarding/background_loading.png';
  static const cloudIcon = 'assets/onboarding/cloud_icon.png';
  static const dateBirthIcon = 'assets/onboarding/date_birth_icon.png';
  static const genderIcon = 'assets/onboarding/gender_icon.png';
  static const weightIcon = 'assets/onboarding/weight_icon.png';
  static const firstBabyIcon = 'assets/onboarding/first_baby_icon.png';
  static const momBaby = 'assets/onboarding/mom_baby.png';
  static const dadBaby = 'assets/onboarding/dad_baby.png';
}

const _onboardingDarkBlue = Color(0xFF163B68);

/// Azul dos títulos da primeira página (welcome).
const _welcomeHeadlineBlue = Color(0xFF1976D2);

class OnboardingPage extends StatefulWidget {
  final bool requireProfileOnly;
  final VoidCallback? onCompleted;

  const OnboardingPage({
    super.key,
    this.requireProfileOnly = false,
    this.onCompleted,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _totalSteps = 20;
  static const _defaultWeightKg = 0.0;
  static const _defaultHeightCm = 0.0;
  static const _defaultMotherHeightCm = 0.0;
  static const _defaultFatherHeightCm = 0.0;

  OnboardingDraft _draft = const OnboardingDraft();
  final _nameCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _aiHistoryCtrl = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _didPrecacheBackgrounds = false;

  final _concerns = const [
    'ConcernSleep',
    'ConcernFeeding',
    'ConcernGrowth',
    'ConcernRoutine',
    'ConcernMemories',
    'ConcernDevelopment',
  ];

  final _goals = const [
    'GoalRoutine',
    'GoalSleepAlerts',
    'GoalMoments',
    'GoalReports',
    'GoalMemoryBook',
  ];

  String _questionIllustrationAsset(int step) => switch (step) {
        0 => _OnboardingAssets.genderIcon,
        1 => _OnboardingAssets.cloudIcon,
        2 => _OnboardingAssets.dateBirthIcon,
        3 => _OnboardingAssets.weightIcon,
        4 => _OnboardingAssets.genderIcon,
        5 => _OnboardingAssets.firstBabyIcon,
        6 => _OnboardingAssets.firstBabyIcon,
        7 || 9 || 10 => _OnboardingAssets.momBaby,
        11 || 12 || 14 => _OnboardingAssets.dadBaby,
        8 || 13 => _OnboardingAssets.dateBirthIcon,
        15 => _OnboardingAssets.cloudIcon,
        _ => _OnboardingAssets.firstBabyIcon,
      };

  double _questionIllustrationHeight(int step) => switch (step) {
        7 ||
        9 ||
        10 ||
        11 ||
        12 ||
        14 =>
          (MediaQuery.sizeOf(context).height * 0.24)
              .clamp(150.0, 230.0)
              .toDouble(),
        _ => (MediaQuery.sizeOf(context).height * 0.15)
            .clamp(92.0, 132.0)
            .toDouble(),
      };

  double _stageIllustrationHeight(double fraction, double maxHeight) =>
      (MediaQuery.sizeOf(context).height * fraction)
          .clamp(170.0, maxHeight)
          .toDouble();

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheBackgrounds) return;
    _didPrecacheBackgrounds = true;
    unawaited(Future.wait<void>([
      PortalTimeOfDay.precacheBackgrounds(context),
      precacheImage(
        const AssetImage(_OnboardingAssets.registrationBackground),
        context,
      ),
    ]));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _motherNameCtrl.dispose();
    _fatherNameCtrl.dispose();
    _aiHistoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    await MeasurementUnitsPrefs.init();
    var draft = await OnboardingDraftStore.load();
    if (widget.requireProfileOnly && draft.stage == 'welcome') {
      draft = draft.copyWith(stage: 'questions');
    }
    if (draft.localBabyId != null &&
        FirebaseAuth.instance.currentUser == null) {
      draft = draft.copyWith(stage: 'auth');
    }
    _nameCtrl.text = draft.babyName;
    _motherNameCtrl.text = draft.motherName;
    _fatherNameCtrl.text = draft.fatherName;
    _aiHistoryCtrl.text = draft.aiHistory;
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _loading = false;
    });
  }

  Future<void> _save(OnboardingDraft draft) async {
    _draft = draft;
    await OnboardingDraftStore.save(draft);
    if (mounted) setState(() {});
  }

  Future<void> _setStage(String stage) => _save(_draft.copyWith(stage: stage));

  Future<void> _setStep(int step) => _save(_draft.copyWith(
      stage: 'questions', step: step.clamp(0, _totalSteps - 1)));

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final s = S.of(context);
    final picked = await showBrDatePicker(
      context,
      title: s.onb('BabyBirthTitle'),
      initialDate: _draft.birthDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 5),
      lastDate: babyBirthDateLastAllowed(now),
      calendarFirst: true,
    );
    if (picked == null) return;
    await _save(_draft.copyWith(birthDate: picked));
  }

  Future<void> _pickMotherBirthDate() async {
    final now = DateTime.now();
    final s = S.of(context);
    final picked = await showBrDatePicker(
      context,
      title: s.onb('MotherBirthTitle'),
      initialDate:
          _draft.motherBirthDate ?? DateTime(now.year - 28, now.month, now.day),
      firstDate: DateTime(now.year - 80),
      lastDate: now,
      calendarFirst: true,
    );
    if (picked == null) return;
    await _save(_draft.copyWith(motherBirthDate: picked));
  }

  Future<void> _pickFatherBirthDate() async {
    final now = DateTime.now();
    final s = S.of(context);
    final picked = await showBrDatePicker(
      context,
      title: s.onb('FatherBirthTitle'),
      initialDate:
          _draft.fatherBirthDate ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 90),
      lastDate: now,
      calendarFirst: true,
    );
    if (picked == null) return;
    await _save(_draft.copyWith(fatherBirthDate: picked));
  }

  String _birthLabel(S s) {
    final d = _draft.birthDate;
    if (d == null) return s.onb('SelectDate');
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _dateLabel(DateTime? date, S s) {
    if (date == null) return s.onb('SelectDate');
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  WeightUnit get _weightUnit =>
      MeasurementUnitsPrefs.weight.value == WeightUnit.lb
          ? WeightUnit.lb
          : WeightUnit.kg;

  LengthUnit get _lengthUnit => MeasurementUnitsPrefs.length.value;

  double _weightForUnit(double kg) =>
      _weightUnit == WeightUnit.lb ? kg * 2.2046226218 : kg;

  double _weightFromUnit(double value) =>
      _weightUnit == WeightUnit.lb ? value / 2.2046226218 : value;

  double _lengthForUnit(double cm) =>
      _lengthUnit == LengthUnit.inch ? cm / 2.54 : cm;

  double _lengthFromUnit(double value) =>
      _lengthUnit == LengthUnit.inch ? value * 2.54 : value;

  String get _weightUnitLabel => _weightUnit == WeightUnit.lb ? 'Lb' : 'Kg';

  String get _lengthUnitLabel => _lengthUnit == LengthUnit.inch ? 'in' : 'cm';

  bool _canContinue() {
    switch (_draft.step) {
      case 0:
        return _draft.sex.isNotEmpty;
      case 1:
        return _nameCtrl.text.trim().length >= 2;
      case 2:
        return _draft.birthDate != null;
      case 3:
        return true;
      case 4:
        return true;
      case 5:
        return true;
      case 6:
        return _draft.firstBaby != null;
      case 7:
        return _motherNameCtrl.text.trim().length >= 2;
      case 8:
        return _draft.motherBirthDate != null;
      case 9:
        return true;
      case 10:
        return true;
      case 11:
        return _draft.registerFather != null;
      case 12:
        return _fatherNameCtrl.text.trim().length >= 2;
      case 13:
        return _draft.fatherBirthDate != null;
      case 14:
        return true;
      case 15:
        return true;
      case 16:
        return _draft.concerns.isNotEmpty;
      case 17:
        return _draft.goals.isNotEmpty;
      case 18:
        return true;
      case 19:
        return true;
      default:
        return false;
    }
  }

  Future<void> _saveStepDefaultIfNeeded() async {
    switch (_draft.step) {
      case 3:
        if (_draft.weightKg == null) {
          await _save(_draft.copyWith(weightKg: _defaultWeightKg));
        }
        return;
      case 4:
        if (_draft.heightCm == null) {
          await _save(_draft.copyWith(heightCm: _defaultHeightCm));
        }
        return;
      case 7:
        await _save(_draft.copyWith(motherName: _motherNameCtrl.text.trim()));
        return;
      case 9:
        if (_draft.motherHeightCm == null) {
          await _save(_draft.copyWith(motherHeightCm: _defaultMotherHeightCm));
        }
        return;
      case 12:
        await _save(_draft.copyWith(fatherName: _fatherNameCtrl.text.trim()));
        return;
      case 14:
        if (_draft.fatherHeightCm == null) {
          await _save(_draft.copyWith(fatherHeightCm: _defaultFatherHeightCm));
        }
        return;
      default:
        return;
    }
  }

  Future<void> _continueStep() async {
    if (!_canContinue()) return;
    if (_draft.step == 1) {
      await _save(_draft.copyWith(babyName: _nameCtrl.text.trim()));
    }
    if (_draft.step == 19) {
      await _save(_draft.copyWith(aiHistory: _aiHistoryCtrl.text.trim()));
    }
    await _saveStepDefaultIfNeeded();
    if (_draft.step == 11 && _draft.registerFather == false) {
      await _save(_draft.copyWith(
        fatherName: '',
        clearFatherBirthDate: true,
        clearFatherHeightCm: true,
        clearFatherPhotoB64: true,
      ));
      await _setStep(16);
      return;
    }
    if (_draft.step < _totalSteps - 1) {
      await _setStep(_draft.step + 1);
      return;
    }
    await _finishQuestions();
  }

  Widget _questionBody(int step) {
    final s = S.of(context);
    switch (step) {
      case 0:
        return _QuestionScaffold(
          title: s.onb('BabySexTitle'),
          child: Column(
            children: [
              _OptionTile(
                  label: s.onb('SexGirl'),
                  selected: _draft.sex == 'F',
                  onTap: () => _save(_draft.copyWith(sex: 'F'))),
              _OptionTile(
                  label: s.onb('SexBoy'),
                  selected: _draft.sex == 'M',
                  onTap: () => _save(_draft.copyWith(sex: 'M'))),
              _OptionTile(
                  label: s.onb('SexUnknown'),
                  selected: _draft.sex == 'N',
                  onTap: () => _save(_draft.copyWith(sex: 'N'))),
            ],
          ),
        );
      case 1:
        return _QuestionScaffold(
          title: s.onb('BabyNameTitle'),
          subtitle: s.onb('BabyNameSubtitle'),
          child: TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: _onboardingDarkBlue),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: _modernInputDecoration(
              hintText: s.onb('BabyNameHint'),
              icon: Icons.child_care_rounded,
            ),
            onChanged: (v) {
              unawaited(_save(_draft.copyWith(babyName: v.trim())));
            },
          ),
        );
      case 2:
        return _QuestionScaffold(
          title: s.onb('BabyBirthTitle'),
          subtitle: s.onb('BabyBirthSubtitle'),
          child: _ChoiceCard(
            selected: _draft.birthDate != null,
            title: _birthLabel(s),
            icon: Icons.cake_outlined,
            onTap: _pickBirthDate,
          ),
        );
      case 3:
        final value = _weightForUnit(_draft.weightKg ?? _defaultWeightKg);
        return _QuestionScaffold(
          title: s.onb('BabyWeightTitle'),
          subtitle: s.onb('BabyWeightSubtitle'),
          child: GrowthRulerPicker(
            value: value,
            min: 0,
            max: _weightUnit == WeightUnit.lb ? 55.1 : 25,
            divisions: _weightUnit == WeightUnit.lb ? 276 : 250,
            unit: _weightUnitLabel,
            decimalDigits: _weightUnit == WeightUnit.lb ? 1 : 2,
            icon: Icons.monitor_weight_outlined,
            subjectLabel: _draft.babyName.trim().isEmpty
                ? s.onb('BabyFallback')
                : _draft.babyName.trim(),
            dragHint: s.onb('DragToAdjust'),
            unitOptions: const ['Kg', 'Lb'],
            selectedUnit: _weightUnitLabel,
            onUnitSelected: (unit) async {
              await MeasurementUnitsPrefs.setWeight(
                  unit == 'Lb' ? WeightUnit.lb : WeightUnit.kg);
              if (mounted) setState(() {});
            },
            onChanged: (v) => _save(_draft.copyWith(
                weightKg: _weightFromUnit(v).clamp(0, 25).toDouble())),
          ),
        );
      case 4:
        final value = _lengthForUnit(_draft.heightCm ?? _defaultHeightCm);
        return _QuestionScaffold(
          title: s.onb('BabyHeightTitle'),
          subtitle: s.onb('BabyHeightSubtitle'),
          child: GrowthRulerPicker(
            value: value,
            min: 0,
            max: _lengthUnit == LengthUnit.inch ? 90 / 2.54 : 90,
            divisions: _lengthUnit == LengthUnit.inch ? 354 : 360,
            unit: _lengthUnitLabel,
            decimalDigits: 1,
            icon: Icons.straighten_rounded,
            subjectLabel: _draft.babyName.trim().isEmpty
                ? s.onb('BabyFallback')
                : _draft.babyName.trim(),
            dragHint: s.onb('DragToAdjust'),
            unitOptions: const ['cm', 'in'],
            selectedUnit: _lengthUnitLabel,
            onUnitSelected: (unit) async {
              await MeasurementUnitsPrefs.setLength(
                  unit == 'in' ? LengthUnit.inch : LengthUnit.cm);
              if (mounted) setState(() {});
            },
            onChanged: (v) => _save(_draft.copyWith(
                heightCm: _lengthFromUnit(v).clamp(0, 90).toDouble())),
          ),
        );
      case 5:
        final hasBabyPhoto = _draft.babyPhotoB64?.isNotEmpty == true;
        return _QuestionScaffold(
          title: s.onb('BabyPhotoTitle'),
          subtitle: s.onb('BabyPhotoSubtitle'),
          child: Column(
            children: [
              Center(
                child: PhotoAvatar(
                  photoB64: _draft.babyPhotoB64,
                  radius: 52,
                  backgroundColor: const Color(0xFFFFF3E6),
                  fallback: const Text('👶', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 20),
              _ChoiceCard(
                selected: hasBabyPhoto,
                title: hasBabyPhoto ? s.regBabyPhotoChange : s.regBabyPhotoAdd,
                icon: Icons.add_a_photo_outlined,
                onTap: () async {
                  final b64 = await pickImageAsB64(
                    context: context,
                    maxBytes: 2 * 1024 * 1024,
                  );
                  if (b64 == null || !mounted) return;
                  await _save(_draft.copyWith(babyPhotoB64: b64));
                },
              ),
            ],
          ),
        );
      case 6:
        return _QuestionScaffold(
          title: s.onb('FirstBabyTitle'),
          child: Column(
            children: [
              _OptionTile(
                  label: s.onb('Yes'),
                  selected: _draft.firstBaby == true,
                  onTap: () => _save(_draft.copyWith(firstBaby: true))),
              _OptionTile(
                  label: s.onb('No'),
                  selected: _draft.firstBaby == false,
                  onTap: () => _save(_draft.copyWith(firstBaby: false))),
            ],
          ),
        );
      case 7:
        return _QuestionScaffold(
          title: s.onb('MotherNameTitle'),
          subtitle: s.onb('MotherNameSubtitle'),
          child: TextField(
            controller: _motherNameCtrl,
            style: const TextStyle(color: _onboardingDarkBlue),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: _modernInputDecoration(
              hintText: s.onb('MotherNameHint'),
              icon: Icons.person_outline_rounded,
            ),
            onChanged: (v) {
              unawaited(_save(_draft.copyWith(motherName: v.trim())));
            },
          ),
        );
      case 8:
        return _QuestionScaffold(
          title: s.onb('MotherBirthTitle'),
          subtitle: s.onb('MotherBirthSubtitle'),
          child: _ChoiceCard(
            selected: _draft.motherBirthDate != null,
            title: _dateLabel(_draft.motherBirthDate, s),
            icon: Icons.event_rounded,
            onTap: _pickMotherBirthDate,
          ),
        );
      case 9:
        final value =
            _lengthForUnit(_draft.motherHeightCm ?? _defaultMotherHeightCm);
        final motherLabel = _draft.motherName.trim().isEmpty
            ? s.onb('MomFallback')
            : _draft.motherName.trim();
        return _QuestionScaffold(
          title: s.onbWithName('MotherHeightTitle', motherLabel),
          subtitle: s.onb('MotherHeightSubtitle'),
          child: GrowthRulerPicker(
            value: value,
            min: 0,
            max: _lengthUnit == LengthUnit.inch ? 83 : 210,
            divisions: _lengthUnit == LengthUnit.inch ? 166 : 210,
            unit: _lengthUnitLabel,
            decimalDigits: 1,
            icon: Icons.accessibility_new_rounded,
            subjectLabel: motherLabel,
            dragHint: s.onb('DragToAdjust'),
            unitOptions: const ['cm', 'in'],
            selectedUnit: _lengthUnitLabel,
            onUnitSelected: (unit) async {
              await MeasurementUnitsPrefs.setLength(
                  unit == 'in' ? LengthUnit.inch : LengthUnit.cm);
              if (mounted) setState(() {});
            },
            onChanged: (v) =>
                _save(_draft.copyWith(motherHeightCm: _lengthFromUnit(v))),
          ),
        );
      case 10:
        final hasMotherPhoto = _draft.motherPhotoB64?.isNotEmpty == true;
        return _QuestionScaffold(
          title: s.onb('MotherPhotoTitle'),
          subtitle: s.onb('MotherPhotoSubtitle'),
          child: Column(
            children: [
              Center(
                child: PhotoAvatar(
                  photoB64: _draft.motherPhotoB64,
                  radius: 52,
                  backgroundColor: const Color(0xFFFFE8F0),
                  fallback: const Text('👩', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 20),
              _ChoiceCard(
                selected: hasMotherPhoto,
                title: hasMotherPhoto
                    ? s.regMotherPhotoChange
                    : s.regMotherPhotoAdd,
                icon: Icons.add_a_photo_outlined,
                onTap: () async {
                  final b64 = await pickImageAsB64(
                    context: context,
                    maxBytes: 2 * 1024 * 1024,
                  );
                  if (b64 == null || !mounted) return;
                  await _save(_draft.copyWith(motherPhotoB64: b64));
                },
              ),
            ],
          ),
        );
      case 11:
        return _QuestionScaffold(
          title: s.onb('RegisterFatherTitle'),
          subtitle: s.onb('RegisterFatherSubtitle'),
          child: Column(
            children: [
              _OptionTile(
                  label: s.onb('Yes'),
                  selected: _draft.registerFather == true,
                  onTap: () => _save(_draft.copyWith(registerFather: true))),
              _OptionTile(
                  label: s.onb('No'),
                  selected: _draft.registerFather == false,
                  onTap: () => _save(_draft.copyWith(registerFather: false))),
            ],
          ),
        );
      case 12:
        return _QuestionScaffold(
          title: s.onb('FatherNameTitle'),
          subtitle: s.onb('FatherNameSubtitle'),
          child: TextField(
            controller: _fatherNameCtrl,
            style: const TextStyle(color: _onboardingDarkBlue),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: _modernInputDecoration(
              hintText: s.onb('FatherNameHint'),
              icon: Icons.person_outline_rounded,
            ),
            onChanged: (v) {
              unawaited(_save(_draft.copyWith(fatherName: v.trim())));
            },
          ),
        );
      case 13:
        return _QuestionScaffold(
          title: s.onb('FatherBirthTitle'),
          subtitle: s.onb('FatherBirthSubtitle'),
          child: _ChoiceCard(
            selected: _draft.fatherBirthDate != null,
            title: _dateLabel(_draft.fatherBirthDate, s),
            icon: Icons.event_available_rounded,
            onTap: _pickFatherBirthDate,
          ),
        );
      case 14:
        final value =
            _lengthForUnit(_draft.fatherHeightCm ?? _defaultFatherHeightCm);
        final fatherLabel = _draft.fatherName.trim().isEmpty
            ? s.onb('DadFallback')
            : _draft.fatherName.trim();
        return _QuestionScaffold(
          title: s.onbWithName('FatherHeightTitle', fatherLabel),
          subtitle: s.onb('FatherHeightSubtitle'),
          child: GrowthRulerPicker(
            value: value,
            min: 0,
            max: _lengthUnit == LengthUnit.inch ? 87 : 220,
            divisions: _lengthUnit == LengthUnit.inch ? 174 : 220,
            unit: _lengthUnitLabel,
            decimalDigits: 1,
            icon: Icons.straighten_rounded,
            subjectLabel: fatherLabel,
            dragHint: s.onb('DragToAdjust'),
            unitOptions: const ['cm', 'in'],
            selectedUnit: _lengthUnitLabel,
            onUnitSelected: (unit) async {
              await MeasurementUnitsPrefs.setLength(
                  unit == 'in' ? LengthUnit.inch : LengthUnit.cm);
              if (mounted) setState(() {});
            },
            onChanged: (v) =>
                _save(_draft.copyWith(fatherHeightCm: _lengthFromUnit(v))),
          ),
        );
      case 15:
        final hasPhoto = _draft.fatherPhotoB64?.isNotEmpty == true;
        return _QuestionScaffold(
          title: s.onb('FatherPhotoTitle'),
          subtitle: s.onb('FatherPhotoSubtitle'),
          child: Column(
            children: [
              Center(
                child: PhotoAvatar(
                  photoB64: _draft.fatherPhotoB64,
                  radius: 52,
                  backgroundColor: const Color(0xFFD6EBFF),
                  fallback: const Text('👨', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 20),
              _ChoiceCard(
                selected: hasPhoto,
                title: hasPhoto ? s.regFatherPhotoChange : s.regFatherPhotoAdd,
                icon: Icons.add_a_photo_outlined,
                onTap: () async {
                  final b64 = await pickImageAsB64(
                    context: context,
                    maxBytes: 2 * 1024 * 1024,
                  );
                  if (b64 == null || !mounted) return;
                  await _save(_draft.copyWith(fatherPhotoB64: b64));
                },
              ),
            ],
          ),
        );
      case 16:
        return _QuestionScaffold(
          title: s.onb('ConcernTitle'),
          subtitle: s.onb('ConcernSubtitle'),
          child: _MultiOptions(
            options: _concerns,
            selected: _draft.concerns,
            labelFor: (id) => s.onb(id),
            onChanged: (v) => _save(_draft.copyWith(concerns: v)),
          ),
        );
      case 17:
        return _QuestionScaffold(
          title: s.onb('GoalsTitle'),
          subtitle: s.onb('GoalsSubtitle'),
          child: _MultiOptions(
            options: _goals,
            selected: _draft.goals,
            labelFor: (id) => s.onb(id),
            onChanged: (v) => _save(_draft.copyWith(goals: v)),
          ),
        );
      case 18:
        return _messagePreferenceStep(s);
      case 19:
        return _QuestionScaffold(
          title: s.onb('AiHistoryTitle'),
          subtitle: s.onb('AiHistorySubtitle'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AiBabyHistoryForm(
                controller: _aiHistoryCtrl,
                embedded: true,
                showActions: false,
                initialText: _draft.aiHistory,
              ),
              const SizedBox(height: 8),
              Text(
                s.onb('AiHistoryOptional'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withAlpha(130),
                ),
              ),
            ],
          ),
        );
      default:
        return _questionBody(18);
    }
  }

  Widget _messagePreferenceStep(S s) {
    final kinds = Set<String>.from(_draft.familyMessageKinds);
    final allOn = FamilyMessageKind.allKinds.every(kinds.contains);

    Future<void> applyKinds(Set<String> next) async {
      await _save(_draft.copyWith(familyMessageKinds: next.toList()));
    }

    void toggleKind(String kind) {
      final next = Set<String>.from(kinds);
      if (next.contains(kind)) {
        next.remove(kind);
      } else {
        next.add(kind);
      }
      unawaited(applyKinds(next));
    }

    void togglePhilosophical() {
      final next = Set<String>.from(kinds);
      final active = next.contains(FamilyMessageKind.spiritist) ||
          next.contains(FamilyMessageKind.jewish);
      if (active) {
        next
          ..remove(FamilyMessageKind.spiritist)
          ..remove(FamilyMessageKind.jewish);
      } else {
        next
          ..add(FamilyMessageKind.spiritist)
          ..add(FamilyMessageKind.jewish);
      }
      unawaited(applyKinds(next));
    }

    final philosophicalOn = kinds.contains(FamilyMessageKind.spiritist) ||
        kinds.contains(FamilyMessageKind.jewish);

    return _QuestionScaffold(
      title: s.onb('MessagePrefTitle'),
      subtitle: s.onb('MessagePrefSubtitle'),
      child: Column(
        children: [
          _OptionTile(
            label: s.onb('MessagePrefAll'),
            selected: allOn,
            onTap: () => unawaited(applyKinds(
              allOn ? <String>{} : FamilyMessageKind.allKinds.toSet(),
            )),
          ),
          _OptionTile(
            label: s.onb('MessagePrefChristian'),
            selected: kinds.contains(FamilyMessageKind.christian),
            onTap: () => toggleKind(FamilyMessageKind.christian),
          ),
          _OptionTile(
            label: s.onb('MessagePrefHoroscope'),
            selected: kinds.contains(FamilyMessageKind.horoscope),
            onTap: () => toggleKind(FamilyMessageKind.horoscope),
          ),
          _OptionTile(
            label: s.onb('MessagePrefPhilosophical'),
            selected: philosophicalOn,
            onTap: togglePhilosophical,
          ),
        ],
      ),
    );
  }

  Future<void> _finishQuestions() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final processingStartedAt = DateTime.now();
      await _save(_draft.copyWith(
          stage: 'processing', babyName: _nameCtrl.text.trim()));
      final ids = await _ensureLocalProfileCreated();
      final next = _draft.copyWith(
        localMotherId: ids.$1,
        localBabyId: ids.$2,
      );
      await _save(next);

      if (FirebaseAuth.instance.currentUser != null) {
        await _syncLocalProfileToCloud(ids.$2);
        await _waitForProcessingMinimum(processingStartedAt);
        await _save(next.copyWith(stage: 'done'));
        return;
      }
      await _waitForProcessingMinimum(processingStartedAt);
      await _save(next.copyWith(stage: 'auth'));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = S.of(context).onb('CouldNotPrepare');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _waitForProcessingMinimum(DateTime startedAt) async {
    final elapsed = DateTime.now().difference(startedAt);
    const minimum = Duration(seconds: 5);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
  }

  Future<(int, int)> _ensureLocalProfileCreated() async {
    final existingMother = _draft.localMotherId;
    final existingBaby = _draft.localBabyId;
    if (existingMother != null && existingBaby != null) {
      return (existingMother, existingBaby);
    }

    final user = FirebaseAuth.instance.currentUser;
    final motherName = _draft.motherName.trim().isNotEmpty
        ? _draft.motherName.trim()
        : (user?.displayName ?? '').trim().isNotEmpty
            ? user!.displayName!.trim()
            : S.of(context).onb('MomFallback');
    final msgPrefs = FamilyMessagePrefs.fromKinds(_draft.familyMessageKinds);
    final motherId = existingMother ??
        await AppDatabase.instance.insertMother(
          name: motherName,
          birthDate: _draft.motherBirthDate,
          heightCm: _draft.motherHeightCm,
          registerFather: _draft.registerFather,
          fatherName: _draft.fatherName.trim().isEmpty
              ? null
              : _draft.fatherName.trim(),
          fatherHeightCm: _draft.fatherHeightCm,
          fatherBirthDate: _draft.fatherBirthDate,
          photoB64: _draft.motherPhotoB64,
          fatherPhotoB64: _draft.fatherPhotoB64,
          showFamilyChristian: msgPrefs.showChristian,
          showFamilyHoroscope: msgPrefs.showHoroscope,
          showFamilySpiritist: msgPrefs.showSpiritist,
          showFamilyJewish: msgPrefs.showJewish,
        );
    final sex = _draft.sex == 'M' || _draft.sex == 'F' ? _draft.sex : 'N';
    final babyId = existingBaby ??
        await AppDatabase.instance.insertBaby(
          motherId: motherId,
          name: _draft.babyName.trim(),
          sex: sex,
          birthDate: _draft.birthDate,
          zodiacSign: _draft.birthDate == null
              ? null
              : zodiacSignPtBr(_draft.birthDate!),
          weightKg: _draft.weightKg,
          heightCm: _draft.heightCm,
          firstBaby: _draft.firstBaby,
          onboardingConcerns: _draft.concerns,
          onboardingGoals: _draft.goals,
          photoB64: _draft.babyPhotoB64,
        );
    await CurrentBabyController.instance.setCurrentBabyId(babyId);
    return (motherId, babyId);
  }

  Future<void> _syncLocalProfileToCloud(int babyId) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await ProfileCloudSync.pushBaby(babyId);
    final baby = await AppDatabase.instance.getBabyById(babyId);
    final cloudId = (baby?['cloud_id'] as String?)?.trim();
    if (cloudId == null || cloudId.isEmpty) return;
    await FirestoreUserRepository.instance.saveUserProfile(uid, {
      'name': AuthService.instance.currentUser?.displayName,
      'email': AuthService.instance.currentUser?.email,
    });
    await FirestoreUserRepository.instance.setSelectedBabyId(uid, cloudId);
    final history = _draft.aiHistory.trim();
    if (history.isNotEmpty) {
      try {
        await AiProfileRepository.instance.save(
          aiHistory: history,
          babyId: cloudId,
        );
      } catch (_) {}
    }
  }

  Future<void> _runAuth(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = S.of(context).userFacingAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _motherNameForAccountCreation() {
    final fromDraft = _draft.motherName.trim();
    if (fromDraft.length >= 2) return fromDraft;
    final fromField = _motherNameCtrl.text.trim();
    if (fromField.length >= 2) return fromField;
    return '';
  }

  Future<void> _showEmailAccountSheet() async {
    final result = await showModalBottomSheet<_EmailAccountData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EmailAccountSheet(
        initialName: _motherNameForAccountCreation(),
      ),
    );
    if (result == null) return;
    await _runAuth(() async {
      await AuthService.instance.registerWithEmail(
        email: result.email,
        password: result.password,
        displayName: result.name,
      );
    });
  }

  /// Novo cadastro a partir do login — primeira pergunta (sexo do bebê), não o welcome.
  Future<void> _restartRegistrationAtFirstQuestion() async {
    await OnboardingDraftStore.clear();
    _nameCtrl.clear();
    _motherNameCtrl.clear();
    _fatherNameCtrl.clear();
    if (!mounted) return;
    setState(() {
      _draft = const OnboardingDraft(stage: 'questions', step: 0);
      _error = null;
    });
    await _save(_draft);
  }

  Future<void> _openExistingLogin() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (!mounted) return;
    if (result == 'restart_registration') {
      await _restartRegistrationAtFirstQuestion();
    }
  }

  Future<void> _completeDone() async {
    await OnboardingDraftStore.clear();
    await CurrentBabyController.instance.refresh();
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final stage = _draft.stage;
    final topInset = MediaQuery.paddingOf(context).top;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: kAuthScreenSkyFallback,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _StageBackground(stage: stage),
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    stage == 'welcome' ? 44 : topInset + 2,
                    22,
                    22 + keyboardBottom,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final incoming = child.key == ValueKey<String>(stage);
                      final offset = incoming
                          ? const Offset(1, 0)
                          : const Offset(-0.28, 0);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: offset,
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<String>(stage),
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(color: _onboardingDarkBlue),
                        child: IconTheme.merge(
                          data: const IconThemeData(color: _onboardingDarkBlue),
                          child: switch (stage) {
                            'questions' => _buildQuestion(),
                            'processing' => _buildProcessing(),
                            'auth' => _buildAuth(),
                            'done' => _buildDone(),
                            _ => _buildWelcome(),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 2,
            right: 8,
            child: const LanguageButton(),
          ),
          if (showLoggedOutScreenMirrors())
            Positioned(
              left: 6,
              bottom: MediaQuery.paddingOf(context).bottom + 6,
              child: SafeArea(
                top: false,
                child: Material(
                  color: Colors.white.withAlpha(230),
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '[Dev] Família',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => pushLoggedOutMirrorFamily(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: _onboardingDarkBlue,
                          ),
                          child: const Text('Família'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final band = (constraints.maxWidth * 0.82).clamp(200.0, 296.0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.center,
                      child: _TransparentAsset(
                        path: _OnboardingAssets.welcomeLogo,
                        height: 176,
                        maxWidth: band,
                        fallbackIcon: Icons.child_care_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: band,
                        child: Text(
                          s.onb('WelcomeTitle'),
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.22,
                            fontWeight: FontWeight.w900,
                            color: _welcomeHeadlineBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: band,
                        child: Text(
                          s.onb('WelcomeSubtitle'),
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.32,
                            fontWeight: FontWeight.w900,
                            color: _welcomeHeadlineBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: band,
                        child: Text(
                          s.onb('PlusEarlyOffer'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                            color: _welcomeHeadlineBlue.withAlpha(200),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _WelcomeFeatureGrid(),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => _setStage('questions'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.ctaPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(s.onb('CreateBabyProfile')),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _openExistingLogin,
          style: TextButton.styleFrom(foregroundColor: _onboardingDarkBlue),
          child: Text(s.onb('ExistingAccountLogin')),
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    final s = S.of(context);
    final step = _draft.step;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressHeader(
          value: (step + 1) / _totalSteps,
          onBack: step == 0 && widget.requireProfileOnly ? null : _back,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final incoming = child.key == ValueKey<int>(step);
                        final slide = Tween<Offset>(
                          begin: incoming
                              ? const Offset(1, 0)
                              : const Offset(-0.28, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(step),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TransparentAsset(
                              path: _questionIllustrationAsset(step),
                              height: _questionIllustrationHeight(step),
                              fallbackIcon: Icons.auto_awesome_rounded,
                            ),
                            const SizedBox(height: 12),
                            _questionBody(step),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_error != null) ...[
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: _canContinue() && !_busy ? _continueStep : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.ctaPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(step == _totalSteps - 1
              ? s.onb('PrepareFaceBaby')
              : s.onb('Continue')),
        ),
      ],
    );
  }

  Future<void> _back() async {
    if (_draft.stage == 'questions') {
      if ((_draft.step == 15 || _draft.step == 16) &&
          _draft.registerFather == false) {
        await _setStep(11);
        return;
      }
      if (_draft.step > 0) {
        await _setStep(_draft.step - 1);
      } else {
        await _setStage('welcome');
      }
      return;
    }
    await _setStage('welcome');
  }

  Widget _buildProcessing() {
    final s = S.of(context);
    return Center(
      child: _OnboardingCard(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: SizedBox(
                  width: 58,
                  height: 58,
                  child: CircularProgressIndicator(strokeWidth: 4)),
            ),
            const SizedBox(height: 24),
            Text(
              s.onb('PreparingTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: _onboardingDarkBlue),
            ),
            const SizedBox(height: 10),
            Text(
              s.onb('PreparingSubtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _onboardingDarkBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuth() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressHeader(value: 1, onBack: () => _setStep(_totalSteps - 1)),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _OnboardingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _PortalLogo(height: 82)),
                  const SizedBox(height: 22),
                  Text(
                    s.onb('AuthTitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        color: _onboardingDarkBlue),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.onb('AuthSubtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: _onboardingDarkBlue),
                  ),
                  const SizedBox(height: 28),
                  if (_error != null) ...[
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _runAuth(
                            () => AuthService.instance.signInWithGoogle()),
                    icon: Image.asset('assets/google_g_logo.png',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) => const Icon(Icons.login)),
                    label: Text(s.onb('SignInGoogle')),
                  ),
                  if (isIOSDevice) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _runAuth(
                              () => AuthService.instance.signInWithApple()),
                      icon: const Icon(Icons.apple),
                      label: Text(s.onb('SignInApple')),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _busy ? null : _showEmailAccountSheet,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.ctaPrimary,
                        foregroundColor: Colors.white),
                    child: Text(_busy ? s.onb('Wait') : s.onb('ContinueEmail')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: _busy ? null : _openExistingLogin,
                      child: Text(s.onb('AlreadyHaveAccount'))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        _OnboardingCard(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            children: [
              _TransparentAsset(
                path: _OnboardingAssets.momBaby,
                height: _stageIllustrationHeight(0.30, 250),
                fallbackIcon: Icons.favorite_rounded,
              ),
              const SizedBox(height: 20),
              Icon(Icons.check_circle_rounded,
                  size: 76, color: AppTheme.ctaPrimary.withAlpha(220)),
              const SizedBox(height: 18),
              Text(
                s.onb('DoneTitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: _onboardingDarkBlue),
              ),
            ],
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _completeDone,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.ctaPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(s.onb('StartTracking')),
        ),
      ],
    );
  }
}

class _QuestionScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _QuestionScaffold(
      {required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return _OnboardingCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: _onboardingDarkBlue),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: _onboardingDarkBlue),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StageBackground extends StatelessWidget {
  final String stage;

  const _StageBackground({required this.stage});

  @override
  Widget build(BuildContext context) {
    const fallback = kAuthScreenSkyFallback;
    final asset = switch (stage) {
      'processing' => _OnboardingAssets.backgroundLoading,
      'auth' => _OnboardingAssets.loginBackground,
      _ => _OnboardingAssets.registrationBackground,
    };
    return AuthScreenBackground(
      asset: asset,
      fallbackColor: fallback,
      alignment: Alignment.bottomCenter,
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _OnboardingCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(238),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TransparentAsset extends StatelessWidget {
  final String path;
  final double height;
  final double? maxWidth;
  final IconData fallbackIcon;

  const _TransparentAsset({
    required this.path,
    required this.height,
    this.maxWidth,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    Widget errorIcon(
            BuildContext context, Object error, StackTrace? stackTrace) =>
        Icon(
          fallbackIcon,
          size: height * 0.72,
          color: AppTheme.primaryPurple.withAlpha(180),
        );

    if (maxWidth != null) {
      return SizedBox(
        width: maxWidth,
        height: height,
        child: Image.asset(
          path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: errorIcon,
        ),
      );
    }
    return Image.asset(
      path,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: errorIcon,
    );
  }
}

class _WelcomeFeatureGrid extends StatelessWidget {
  const _WelcomeFeatureGrid();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final features = [
      _WelcomeFeature(
        icon: Icons.nightlight_round,
        label: s.onb('FeatureSleep'),
        color: const Color(0xFF4D99DE),
      ),
      _WelcomeFeature(
        icon: Icons.local_drink_outlined,
        label: s.onb('FeatureFeeding'),
        color: const Color(0xFF67A99B),
      ),
      _WelcomeFeature(
        icon: Icons.straighten_rounded,
        label: s.onb('FeatureGrowth'),
        color: const Color(0xFFE0AE3F),
      ),
      _WelcomeFeature(
        icon: Icons.image_outlined,
        label: s.onb('FeatureMemories'),
        color: const Color(0xFF5E9FB2),
      ),
      _WelcomeFeature(
        icon: Icons.notifications_none_rounded,
        label: s.onb('FeatureAlerts'),
        color: const Color(0xFFE09A3E),
      ),
      _WelcomeFeature(
        icon: Icons.favorite_border_rounded,
        label: s.onb('FeatureLove'),
        color: const Color(0xFFFF6F9D),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final feature in features.take(3)) feature,
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final feature in features.skip(3)) feature,
          ],
        ),
      ],
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _WelcomeFeature({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 52),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: _welcomeHeadlineBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalLogo extends StatelessWidget {
  final double height;

  const _PortalLogo({required this.height});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _OnboardingAssets.logo,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.child_care_rounded,
        size: height * 0.78,
        color: AppTheme.primaryPurple.withAlpha(180),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final double value;
  final VoidCallback? onBack;

  const _ProgressHeader({required this.value, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
            onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.black.withAlpha(18),
              color: AppTheme.ctaPrimary,
            ),
          ),
        ),
        const SizedBox(width: 52),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ChoiceCard(
      {required this.selected,
      required this.title,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _OptionSurface(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: _onboardingDarkBlue),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: _onboardingDarkBlue))),
          const Icon(Icons.chevron_right_rounded, color: _onboardingDarkBlue),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _OptionSurface(
        selected: selected,
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _onboardingDarkBlue))),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? AppTheme.ctaPrimary
                    : _onboardingDarkBlue.withAlpha(95)),
          ],
        ),
      ),
    );
  }
}

class _MultiOptions extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final String Function(String) labelFor;
  final ValueChanged<List<String>> onChanged;

  const _MultiOptions(
      {required this.options,
      required this.selected,
      required this.labelFor,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in options)
          _OptionTile(
            label: labelFor(option),
            selected: selected.contains(option),
            onTap: () {
              final next = selected.toList();
              if (next.contains(option)) {
                next.remove(option);
              } else {
                next.add(option);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _OptionSurface extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _OptionSurface(
      {required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFF3F8) : Colors.white,
      elevation: selected ? 5 : 2,
      shadowColor: Colors.black.withAlpha(20),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: selected
                    ? AppTheme.ctaPrimary.withAlpha(130)
                    : _onboardingDarkBlue.withAlpha(20)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _EmailAccountData {
  final String name;
  final String email;
  final String password;

  const _EmailAccountData(
      {required this.name, required this.email, required this.password});
}

class _EmailAccountSheet extends StatefulWidget {
  const _EmailAccountSheet({this.initialName});

  /// Nome da mãe já recolhido no onboarding (evita pedir de novo).
  final String? initialName;

  @override
  State<_EmailAccountSheet> createState() => _EmailAccountSheetState();
}

class _EmailAccountSheetState extends State<_EmailAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _checking = false;
  String? _submitError;

  bool get _hasPrefilledName =>
      (widget.initialName ?? '').trim().length >= 2;

  String get _resolvedName =>
      _hasPrefilledName ? widget.initialName!.trim() : _name.text.trim();

  @override
  void initState() {
    super.initState();
    final preset = widget.initialName?.trim() ?? '';
    if (preset.isNotEmpty) {
      _name.text = preset;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final s = S.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(22, 4, 22, bottom + 22),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.onb('EmailSheetTitle'),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _onboardingDarkBlue)),
              const SizedBox(height: 14),
              if (!_hasPrefilledName) ...[
                TextFormField(
                  controller: _name,
                  style: const TextStyle(color: _onboardingDarkBlue),
                  textCapitalization: TextCapitalization.words,
                  decoration: _modernInputDecoration(
                    hintText: s.onb('YourNameHint'),
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (v) =>
                      (v ?? '').trim().length < 2 ? s.onb('ValYourName') : null,
                ),
                const SizedBox(height: 10),
              ],
              TextFormField(
                controller: _email,
                style: const TextStyle(color: _onboardingDarkBlue),
                keyboardType: TextInputType.emailAddress,
                decoration: _modernInputDecoration(
                  hintText: s.onb('EmailHint'),
                  icon: Icons.mail_outline_rounded,
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return s.onb('ValEmailRequired');
                  if (!t.contains('@')) return s.onb('ValEmailInvalid');
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _password,
                style: const TextStyle(color: _onboardingDarkBlue),
                obscureText: true,
                decoration: _modernInputDecoration(
                  hintText: s.onb('PasswordHint'),
                  icon: Icons.lock_outline_rounded,
                ),
                validator: (v) =>
                    (v ?? '').length < 6 ? s.onb('ValPasswordMin') : null,
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _submitError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _checking
                    ? null
                    : () async {
                        if (!_hasPrefilledName &&
                            _resolvedName.length < 2) {
                          setState(() {
                            _submitError = s.onb('ValYourName');
                          });
                          return;
                        }
                        if (!(_formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setState(() {
                          _checking = true;
                          _submitError = null;
                        });
                        try {
                          await AuthService.instance
                              .ensureEmailAvailableForRegistration(
                            _email.text,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop(
                            _EmailAccountData(
                              name: _resolvedName,
                              email: AuthService.normalizeEmail(_email.text),
                              password: _password.text,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          setState(() {
                            _submitError = S.of(context).userFacingAuthError(e);
                          });
                        } finally {
                          if (mounted) setState(() => _checking = false);
                        }
                      },
                child: _checking
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(s.onb('CreateAccount')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
