import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../services/app_database.dart';
import '../services/firebase/profile_cloud_sync.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_user_repository.dart';
import '../services/measurement_units_prefs.dart';
import '../theme/app_theme.dart';
import '../utils/input_formatters.dart';
import '../utils/pick_image_b64.dart';
import '../utils/zodiac.dart';
import '../widgets/card_box.dart';
import '../widgets/loading_scope.dart';
import '../widgets/face_baby_loading.dart';
import '../widgets/growth_ruler_picker.dart';
import '../widgets/photo_avatar.dart';
import '../widgets/section_title.dart';

/// Qual metade do formulário exibir ao editar a mãe a partir de «Meu perfil».
enum MotherProfileMotherFormSection { mother, father }

ThemeData _motherBabyFormTheme(BuildContext context) {
  final base = Theme.of(context);
  final scheme = base.colorScheme;
  const r = 12.0;
  final enabled = OutlineInputBorder(
    borderRadius: BorderRadius.circular(r),
    borderSide: BorderSide(color: scheme.outline.withAlpha(200)),
  );
  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: enabled,
      enabledBorder: enabled,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: const BorderSide(color: AppTheme.ctaPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
  );
}

class MotherBabyRegisterPage extends StatefulWidget {
  final bool mandatory;
  final VoidCallback? onCompleted;
  /// Quando `true`, abre diretamente no passo do bebê (sem cadastrar outra mãe).
  final bool babyOnly;
  /// Mãe já conhecida (ex.: vindo de "Meu Perfil › Bebês › Adicionar outro bebê").
  final int? presetMotherId;
  /// Editar dados da mãe existentes (Meu Perfil).
  final int? editMotherId;
  /// Com [editMotherId]: só campos da mãe ou só do pai (o restante preserva-se na BD).
  final MotherProfileMotherFormSection? profileMotherSection;
  /// Editar dados do bebê existente (Meu Perfil).
  final int? editBabyId;

  const MotherBabyRegisterPage({
    super.key,
    this.mandatory = false,
    this.onCompleted,
    this.babyOnly = false,
    this.presetMotherId,
    this.editMotherId,
    this.profileMotherSection,
    this.editBabyId,
  });

  @override
  State<MotherBabyRegisterPage> createState() => _MotherBabyRegisterPageState();
}

class _MotherBabyRegisterPageState extends State<MotherBabyRegisterPage> {
  final _motherFormKey = GlobalKey<FormState>();
  final _babyFormKey = GlobalKey<FormState>();

  final _motherNameCtrl = TextEditingController();
  final _motherPhoneCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _babyNameCtrl = TextEditingController();

  /// Valores em cm / kg (réguas).
  double _motherHeightCmRuler = 165;
  double _fatherHeightCmRuler = 175;
  double _babyWeightKgRuler = 3.5;
  double _babyHeightCmRuler = 50;

  DateTime? _motherBirthDate;
  DateTime? _fatherBirthDate;
  DateTime? _babyBirthDate;
  String _babySex = 'F';
  String? _motherPhotoB64;
  String? _fatherPhotoB64;
  String? _babyPhotoB64;
  String? _motherPhotoUrl;
  String? _fatherPhotoUrl;
  String? _babyPhotoUrl;
  bool _motherPhotoDirty = false;
  bool _fatherPhotoDirty = false;
  bool _babyPhotoDirty = false;
  bool _saving = false;
  int _step = 0; // 0 = mãe, 1 = bebê
  Future<List<Map<String, Object?>>>? _listFuture;
  Future<List<Map<String, Object?>>>? _mothersFuture;
  int? _selectedMotherId;

  String? get _babyZodiacSign => _babyBirthDate == null ? null : zodiacSignPtBr(_babyBirthDate!);

  bool get _profileEditMother => widget.editMotherId != null;
  bool get _profileEditBaby => widget.editBabyId != null;
  bool get _profileEditMode => _profileEditMother || _profileEditBaby;

  bool get _motherFormSectionVisible =>
      widget.profileMotherSection == null ||
      widget.profileMotherSection == MotherProfileMotherFormSection.mother;

  bool get _fatherFormSectionVisible =>
      widget.profileMotherSection == null ||
      widget.profileMotherSection == MotherProfileMotherFormSection.father;

  @override
  void initState() {
    super.initState();
    if (widget.editMotherId != null) {
      _step = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefillMotherEdit());
    } else if (widget.editBabyId != null) {
      _step = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefillBabyEdit());
    } else if (widget.babyOnly) {
      _step = 1;
      _selectedMotherId = widget.presetMotherId;
    }
    _reload();
  }

  Future<void> _prefillMotherEdit() async {
    final id = widget.editMotherId;
    if (id == null) return;
    final row = await AppDatabase.instance.getMotherById(id);
    if (!mounted || row == null) return;
    final birthRaw = (row['birth_date'] as String?)?.trim();
    final birth = birthRaw == null || birthRaw.isEmpty ? null : DateTime.tryParse(birthRaw);
    final h = row['height_cm'] as num?;
    final fh = row['father_height_cm'] as num?;
    setState(() {
      _motherNameCtrl.text = (row['name'] as String?) ?? '';
      _motherPhoneCtrl.text = (row['phone'] as String?) ?? '';
      _motherHeightCmRuler =
          (h != null && h.toDouble() > 0) ? h.toDouble() : 165.0;
      _fatherNameCtrl.text = (row['father_name'] as String?)?.trim() ?? '';
      _fatherHeightCmRuler =
          (fh != null && fh.toDouble() > 0) ? fh.toDouble() : 175.0;
      final fbRaw = (row['father_birth_date'] as String?)?.trim();
      final fb = fbRaw == null || fbRaw.isEmpty ? null : DateTime.tryParse(fbRaw);
      _fatherBirthDate = fb == null ? null : DateTime(fb.year, fb.month, fb.day);
      _motherBirthDate = birth == null ? null : DateTime(birth.year, birth.month, birth.day);
      _motherPhotoB64 = (row['photo_b64'] as String?)?.trim();
      _fatherPhotoB64 = (row['father_photo_b64'] as String?)?.trim();
      final mu = (row['photo_url'] as String?)?.trim();
      _motherPhotoUrl = (mu == null || mu.isEmpty) ? null : mu;
      final fu = (row['father_photo_url'] as String?)?.trim();
      _fatherPhotoUrl = (fu == null || fu.isEmpty) ? null : fu;
      _motherPhotoDirty = false;
      _fatherPhotoDirty = false;
      _selectedMotherId = id;
    });
  }

  Future<void> _prefillBabyEdit() async {
    final id = widget.editBabyId;
    if (id == null) return;
    final row = await AppDatabase.instance.getBabyById(id);
    if (!mounted || row == null) return;
    final mid = (row['mother_id'] as num?)?.toInt();
    if (mid == null) return;
    final birthRaw = (row['birth_date'] as String?)?.trim();
    final birth = birthRaw == null || birthRaw.isEmpty ? null : DateTime.tryParse(birthRaw);
    final w = row['weight_kg'] as num?;
    final h = row['height_cm'] as num?;
    setState(() {
      _babyNameCtrl.text = (row['name'] as String?) ?? '';
      _babySex = ((row['sex'] as String?)?.trim().toUpperCase() == 'M') ? 'M' : 'F';
      _babyBirthDate = birth == null ? null : DateTime(birth.year, birth.month, birth.day);
      _babyWeightKgRuler = (w != null && w.toDouble() > 0) ? w.toDouble() : 3.5;
      _babyHeightCmRuler = (h != null && h.toDouble() > 0) ? h.toDouble() : 50.0;
      _babyPhotoB64 = (row['photo_b64'] as String?)?.trim();
      final bu = (row['photo_url'] as String?)?.trim();
      _babyPhotoUrl = (bu == null || bu.isEmpty) ? null : bu;
      _babyPhotoDirty = false;
      _selectedMotherId = mid;
      _step = 1;
    });
  }

  @override
  void dispose() {
    _motherNameCtrl.dispose();
    _motherPhoneCtrl.dispose();
    _fatherNameCtrl.dispose();
    _babyNameCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    _listFuture = AppDatabase.instance.listMothersWithBabies();
    _mothersFuture = AppDatabase.instance.listMothers();
  }

  Future<T> _runLoading<T>(
    Future<T> Function() action, {
    String? label,
  }) async {
    final loading = LoadingScope.maybeOf(context);
    if (loading == null) return await action();
    return await loading.run(action, label: label);
  }

  double _lengthDisplayFromCm(double cm) =>
      MeasurementUnitsPrefs.length.value == LengthUnit.inch ? cm / 2.54 : cm;

  double _lengthCmFromDisplay(double v) =>
      MeasurementUnitsPrefs.length.value == LengthUnit.inch ? v * 2.54 : v;

  double _babyWeightDisplayFromKg(double kg) {
    switch (MeasurementUnitsPrefs.weight.value) {
      case WeightUnit.kg:
        return kg;
      case WeightUnit.lb:
        return kg * 2.2046226218;
      case WeightUnit.st:
        return (kg * 2.2046226218) / 14.0;
    }
  }

  double _babyWeightKgFromDisplay(double v) {
    switch (MeasurementUnitsPrefs.weight.value) {
      case WeightUnit.kg:
        return v;
      case WeightUnit.lb:
        return v / 2.2046226218;
      case WeightUnit.st:
        return (v * 14.0) / 2.2046226218;
    }
  }

  String _growthWeightChipLabel() => switch (MeasurementUnitsPrefs.weight.value) {
        WeightUnit.kg => 'Kg',
        WeightUnit.lb => 'Lb',
        WeightUnit.st => 'St',
      };

  DateTime? _rowDateOnly(Map<String, Object?> row, String key) {
    final raw = (row[key] as String?)?.trim();
    if (raw == null || raw.isEmpty) return null;
    final d = DateTime.tryParse(raw);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  Widget _motherHeightRuler(S s) {
    final inch = MeasurementUnitsPrefs.length.value == LengthUnit.inch;
    return GrowthRulerPicker(
      value: _lengthDisplayFromCm(_motherHeightCmRuler),
      min: 0,
      max: inch ? 210 / 2.54 : 210,
      divisions: inch ? 166 : 210,
      unit: inch ? 'pol' : 'cm',
      decimalDigits: 1,
      icon: Icons.accessibility_new_rounded,
      subjectLabel: _motherNameCtrl.text.trim().isEmpty ? null : _motherNameCtrl.text.trim(),
      dragHint: s.onb('DragToAdjust'),
      unitOptions: const ['cm', 'pol'],
      selectedUnit: inch ? 'pol' : 'cm',
      snapStartToZeroWhenAtMax: false,
      onUnitSelected: (u) async {
        await MeasurementUnitsPrefs.setLength(
            u == 'pol' ? LengthUnit.inch : LengthUnit.cm);
        if (mounted) setState(() {});
      },
      onChanged: (v) => setState(() {
        _motherHeightCmRuler = _lengthCmFromDisplay(v);
      }),
    );
  }

  Widget _fatherHeightRuler(S s) {
    final inch = MeasurementUnitsPrefs.length.value == LengthUnit.inch;
    return GrowthRulerPicker(
      value: _lengthDisplayFromCm(_fatherHeightCmRuler),
      min: 0,
      max: inch ? 220 / 2.54 : 220,
      divisions: inch ? 174 : 220,
      unit: inch ? 'pol' : 'cm',
      decimalDigits: 1,
      icon: Icons.straighten_rounded,
      subjectLabel: _fatherNameCtrl.text.trim().isEmpty ? null : _fatherNameCtrl.text.trim(),
      dragHint: s.onb('DragToAdjust'),
      unitOptions: const ['cm', 'pol'],
      selectedUnit: inch ? 'pol' : 'cm',
      snapStartToZeroWhenAtMax: false,
      onUnitSelected: (u) async {
        await MeasurementUnitsPrefs.setLength(
            u == 'pol' ? LengthUnit.inch : LengthUnit.cm);
        if (mounted) setState(() {});
      },
      onChanged: (v) => setState(() {
        _fatherHeightCmRuler = _lengthCmFromDisplay(v);
      }),
    );
  }

  Widget _babyWeightRuler(S s) {
    final wu = MeasurementUnitsPrefs.weight.value;
    final (double max, int divisions, int dec, String unitStr) = switch (wu) {
      WeightUnit.kg => (40.0, 200, 2, 'Kg'),
      WeightUnit.lb => (88.0, 176, 1, 'Lb'),
      WeightUnit.st => (6.3, 126, 2, 'St'),
    };
    return GrowthRulerPicker(
      value: _babyWeightDisplayFromKg(_babyWeightKgRuler),
      min: 0,
      max: max,
      divisions: divisions,
      unit: unitStr,
      decimalDigits: dec,
      icon: Icons.monitor_weight_outlined,
      subjectLabel:
          _babyNameCtrl.text.trim().isEmpty ? null : _babyNameCtrl.text.trim(),
      dragHint: s.onb('DragToAdjust'),
      unitOptions: const ['Kg', 'Lb', 'St'],
      selectedUnit: _growthWeightChipLabel(),
      snapStartToZeroWhenAtMax: false,
      onUnitSelected: (u) async {
        await MeasurementUnitsPrefs.setWeight(
          u == 'Lb'
              ? WeightUnit.lb
              : u == 'St'
                  ? WeightUnit.st
                  : WeightUnit.kg,
        );
        if (mounted) setState(() {});
      },
      onChanged: (v) => setState(() {
        _babyWeightKgRuler = _babyWeightKgFromDisplay(v);
      }),
    );
  }

  Widget _babyHeightRuler(S s) {
    final inch = MeasurementUnitsPrefs.length.value == LengthUnit.inch;
    return GrowthRulerPicker(
      value: _lengthDisplayFromCm(_babyHeightCmRuler),
      min: 0,
      max: inch ? 120 / 2.54 : 120,
      divisions: inch ? 236 : 240,
      unit: inch ? 'pol' : 'cm',
      decimalDigits: 1,
      icon: Icons.straighten_rounded,
      subjectLabel:
          _babyNameCtrl.text.trim().isEmpty ? null : _babyNameCtrl.text.trim(),
      dragHint: s.onb('DragToAdjust'),
      unitOptions: const ['cm', 'pol'],
      selectedUnit: inch ? 'pol' : 'cm',
      snapStartToZeroWhenAtMax: false,
      onUnitSelected: (u) async {
        await MeasurementUnitsPrefs.setLength(
            u == 'pol' ? LengthUnit.inch : LengthUnit.cm);
        if (mounted) setState(() {});
      },
      onChanged: (v) => setState(() {
        _babyHeightCmRuler = _lengthCmFromDisplay(v);
      }),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _babyBirthDate ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _babyBirthDate = picked);
  }

  Future<void> _pickMotherBirthDate() async {
    final now = DateTime.now();
    final initial = _motherBirthDate ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 80),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _motherBirthDate = picked);
  }

  Future<void> _pickFatherBirthDate() async {
    final now = DateTime.now();
    final initial = _fatherBirthDate ?? DateTime(now.year - 30, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 80),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _fatherBirthDate = picked);
  }

  String? get _trimFatherName {
    final t = _fatherNameCtrl.text.trim();
    return t.isEmpty ? null : t;
  }

  bool? get _registerFatherFlag {
    final hasName = (_trimFatherName?.length ?? 0) >= 2;
    final hasBirth = _fatherBirthDate != null;
    final hasHeight = _fatherHeightCmRuler >= 120 && _fatherHeightCmRuler <= 220;
    final hasPhoto = (_fatherPhotoB64?.isNotEmpty == true) ||
        (_fatherPhotoUrl?.isNotEmpty == true);
    if (!hasName && !hasBirth && !hasHeight && !hasPhoto) return false;
    return true;
  }

  Future<void> _saveMother() async {
    if (_saving) return;
    final s = S.of(context);
    final editMid = widget.editMotherId;
    final section = widget.profileMotherSection;

    if (editMid != null && section == MotherProfileMotherFormSection.mother) {
      if (!(_motherFormKey.currentState?.validate() ?? false)) return;
      if (_motherBirthDate == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.regSnackMotherBirth)),
          );
        }
        return;
      }
      if (_motherHeightCmRuler < 120 || _motherHeightCmRuler > 220) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.valHeightMotherRange)),
          );
        }
        return;
      }
      final row = await AppDatabase.instance.getMotherById(editMid);
      if (!mounted || row == null) return;
      setState(() => _saving = true);
      try {
        final fName = (row['father_name'] as String?)?.trim();
        final fH = (row['father_height_cm'] as num?)?.toDouble();
        final keepReg = (row['register_father'] as num?)?.toInt() == 1;
        await _runLoading(() async {
          await AppDatabase.instance.updateMother(
            motherId: editMid,
            name: _motherNameCtrl.text,
            phone: _motherPhoneCtrl.text,
            birthDate: _motherBirthDate,
            heightCm: _motherHeightCmRuler,
            fatherName: fName == null || fName.isEmpty ? null : fName,
            fatherHeightCm: fH,
            fatherBirthDate: _rowDateOnly(row, 'father_birth_date'),
            registerFather: keepReg,
            photoB64: _motherPhotoB64,
            fatherPhotoB64: (row['father_photo_b64'] as String?)?.trim(),
            resetProfilePhotoUrl: _motherPhotoDirty,
            resetFatherPhotoUrl: false,
          );
        }, label: s.commonSaving);
        await ProfileCloudSync.pushMother(editMid);
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null) {
          unawaited(
            FirestoreUserRepository.instance.saveUserProfile(uid, {
              'name': _motherNameCtrl.text.trim(),
              'email': AuthService.instance.currentUser?.email,
              'phone': _motherPhoneCtrl.text.trim().isEmpty ? null : _motherPhoneCtrl.text.trim(),
              'birth_date': _motherBirthDate?.toIso8601String(),
              'height_cm': _motherHeightCmRuler,
              'father_name': fName,
              'father_height_cm': fH,
              'father_birth_date': (row['father_birth_date'] as String?)?.trim(),
              'register_father': keepReg,
            }),
          );
        }
        _motherPhotoDirty = false;
        await CurrentBabyController.instance.refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.profileDataSaved)),
        );
        Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${s.commonCouldNotSave} $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    if (editMid != null && section == MotherProfileMotherFormSection.father) {
      if (!(_motherFormKey.currentState?.validate() ?? false)) return;
      final fname = _fatherNameCtrl.text.trim();
      if (fname.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.valNameShort)),
          );
        }
        return;
      }
      if (_fatherHeightCmRuler < 120 || _fatherHeightCmRuler > 220) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.valHeightMotherRange)),
          );
        }
        return;
      }
      final row = await AppDatabase.instance.getMotherById(editMid);
      if (!mounted || row == null) return;
      setState(() => _saving = true);
      try {
        await _runLoading(() async {
          await AppDatabase.instance.updateMother(
            motherId: editMid,
            name: (row['name'] as String?) ?? '',
            phone: (row['phone'] as String?)?.trim(),
            birthDate: _rowDateOnly(row, 'birth_date'),
            heightCm: (row['height_cm'] as num?)?.toDouble(),
            fatherName: _trimFatherName,
            fatherHeightCm: _fatherHeightCmRuler,
            fatherBirthDate: _fatherBirthDate,
            registerFather: true,
            photoB64: (row['photo_b64'] as String?)?.trim(),
            fatherPhotoB64: _fatherPhotoB64,
            resetProfilePhotoUrl: false,
            resetFatherPhotoUrl: _fatherPhotoDirty,
          );
        }, label: s.commonSaving);
        await ProfileCloudSync.pushMother(editMid);
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null) {
          unawaited(
            FirestoreUserRepository.instance.saveUserProfile(uid, {
              'name': (row['name'] as String?)?.trim(),
              'email': AuthService.instance.currentUser?.email,
              'phone': (row['phone'] as String?)?.trim(),
              'birth_date': (row['birth_date'] as String?)?.trim(),
              'height_cm': (row['height_cm'] as num?)?.toDouble(),
              'father_name': _trimFatherName,
              'father_height_cm': _fatherHeightCmRuler,
              'father_birth_date': _fatherBirthDate?.toIso8601String(),
              'register_father': true,
            }),
          );
        }
        _fatherPhotoDirty = false;
        await CurrentBabyController.instance.refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.profileDataSaved)),
        );
        Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${s.commonCouldNotSave} $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    if (!(_motherFormKey.currentState?.validate() ?? false)) return;
    if (_motherFormSectionVisible && _motherBirthDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.regSnackMotherBirth)),
        );
      }
      return;
    }
    if (_motherFormSectionVisible &&
        (_motherHeightCmRuler < 120 || _motherHeightCmRuler > 220)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.valHeightMotherRange)),
        );
      }
      return;
    }
    if (_fatherFormSectionVisible &&
        (_fatherHeightCmRuler < 120 || _fatherHeightCmRuler > 220)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.valFatherHeightEmpty)),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      if (editMid != null) {
        await _runLoading(() async {
          await AppDatabase.instance.updateMother(
            motherId: editMid,
            name: _motherNameCtrl.text,
            phone: _motherPhoneCtrl.text,
            birthDate: _motherBirthDate,
            heightCm: _motherHeightCmRuler,
            fatherName: _trimFatherName,
            fatherHeightCm: _fatherHeightCmRuler,
            fatherBirthDate: _fatherBirthDate,
            registerFather: _registerFatherFlag,
            photoB64: _motherPhotoB64,
            fatherPhotoB64: _fatherPhotoB64,
            resetProfilePhotoUrl: _motherPhotoDirty,
            resetFatherPhotoUrl: _fatherPhotoDirty,
          );
        }, label: s.commonSaving);
        await ProfileCloudSync.pushMother(editMid);
        final uidFull = AuthService.instance.currentUser?.uid;
        if (uidFull != null) {
          unawaited(
            FirestoreUserRepository.instance.saveUserProfile(uidFull, {
              'name': _motherNameCtrl.text.trim(),
              'email': AuthService.instance.currentUser?.email,
              'phone': _motherPhoneCtrl.text.trim().isEmpty ? null : _motherPhoneCtrl.text.trim(),
              'birth_date': _motherBirthDate?.toIso8601String(),
              'height_cm': _motherHeightCmRuler,
              'father_name': _trimFatherName,
              'father_height_cm': _fatherHeightCmRuler,
              'father_birth_date': _fatherBirthDate?.toIso8601String(),
              'register_father': _registerFatherFlag,
            }),
          );
        }
        _motherPhotoDirty = false;
        _fatherPhotoDirty = false;
        await CurrentBabyController.instance.refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.profileDataSaved)),
        );
        Navigator.of(context).pop();
        return;
      }

      final motherId = await _runLoading(() async {
        return await AppDatabase.instance.insertMother(
          name: _motherNameCtrl.text,
          phone: _motherPhoneCtrl.text,
          birthDate: _motherBirthDate,
          heightCm: _motherHeightCmRuler,
          fatherName: _trimFatherName,
          fatherHeightCm: _fatherHeightCmRuler,
          fatherBirthDate: _fatherBirthDate,
          registerFather: _registerFatherFlag,
          photoB64: _motherPhotoB64,
          fatherPhotoB64: _fatherPhotoB64,
        );
      }, label: s.regSavingMother);
      await ProfileCloudSync.pushMother(motherId);
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        unawaited(
          FirestoreUserRepository.instance.saveUserProfile(uid, {
            'name': _motherNameCtrl.text.trim(),
            'email': AuthService.instance.currentUser?.email,
            'phone': _motherPhoneCtrl.text.trim().isEmpty ? null : _motherPhoneCtrl.text.trim(),
            'birth_date': _motherBirthDate?.toIso8601String(),
            'height_cm': _motherHeightCmRuler,
            'father_name': _trimFatherName,
            'father_height_cm': _fatherHeightCmRuler,
            'father_birth_date': _fatherBirthDate?.toIso8601String(),
            'register_father': _registerFatherFlag,
          }),
        );
      }
      _motherFormKey.currentState?.reset();
      _motherNameCtrl.clear();
      _motherPhoneCtrl.clear();
      _fatherNameCtrl.clear();
      _fatherPhotoB64 = null;
      _fatherPhotoUrl = null;
      _motherBirthDate = null;
      _fatherBirthDate = null;
      setState(() {
        _motherHeightCmRuler = 165;
        _fatherHeightCmRuler = 175;
        _selectedMotherId = motherId;
        _reload();
        _step = 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.regSnackMotherOk)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.commonCouldNotSave} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goToBabyStep() {
    if (_selectedMotherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).regSnackSelectMother)),
      );
      return;
    }
    setState(() => _step = 1);
  }

  void _goToMotherStep() {
    if (widget.babyOnly) return;
    setState(() => _step = 0);
  }

  Future<void> _saveBaby() async {
    if (_saving) return;
    final valid = _babyFormKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (_babyBirthDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).regSnackBabyBirth)),
        );
      }
      return;
    }
    if (_babyWeightKgRuler <= 0 || _babyWeightKgRuler > 40) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).valWeightRange)),
        );
      }
      return;
    }
    if (_babyHeightCmRuler <= 20 || _babyHeightCmRuler > 120) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).valBabyHeightRange)),
        );
      }
      return;
    }
    final motherId = _selectedMotherId;
    if (motherId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).regSnackPickMother)),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final editBid = widget.editBabyId;
      if (editBid != null) {
        await _runLoading(() async {
          await AppDatabase.instance.updateBaby(
            babyId: editBid,
            motherId: motherId,
            name: _babyNameCtrl.text,
            sex: _babySex,
            birthDate: _babyBirthDate,
            zodiacSign: _babyZodiacSign,
            weightKg: _babyWeightKgRuler,
            heightCm: _babyHeightCmRuler,
            photoB64: _babyPhotoB64,
            resetProfilePhotoUrl: _babyPhotoDirty,
          );
        }, label: S.of(context).commonSaving);
        // Login obrigatório: só conclui após persistir na nuvem (FireStore + Storage se houver foto).
        await ProfileCloudSync.pushBaby(editBid);
        // Novo schema: salva/atualiza bebê e marca como selecionado.
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null) {
          unawaited(() async {
            final babyRow = await AppDatabase.instance.getBabyById(editBid);
            final cloudId = (babyRow?['cloud_id'] as String?)?.trim();
            if (cloudId != null && cloudId.isNotEmpty) {
              await FirestoreUserRepository.instance.saveBaby(uid, {
                'id': cloudId,
                'name': _babyNameCtrl.text.trim(),
                'sex': _babySex,
                'birthDate': _babyBirthDate?.toIso8601String(),
                'weightKg': _babyWeightKgRuler,
                'heightCm': _babyHeightCmRuler,
              });
              await FirestoreUserRepository.instance.setSelectedBabyId(uid, cloudId);
            }
          }());
        }
        _babyPhotoDirty = false;
        await CurrentBabyController.instance.refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).profileDataSaved)),
        );
        Navigator.of(context).pop();
        return;
      }

      await _runLoading(() async {
        final id = await AppDatabase.instance.insertBaby(
          motherId: motherId,
          name: _babyNameCtrl.text,
          sex: _babySex,
          birthDate: _babyBirthDate,
          zodiacSign: _babyZodiacSign,
          weightKg: _babyWeightKgRuler,
          heightCm: _babyHeightCmRuler,
          photoB64: _babyPhotoB64,
        );
        await CurrentBabyController.instance.setCurrentBabyId(id);
        // Login obrigatório: só conclui após persistir na nuvem.
        await ProfileCloudSync.pushBaby(id);
        // Novo schema: após push criar cloud_id, replica no schema /users/{uid}/babies e seleciona.
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null) {
          Future<void> syncSelectedToCloud() async {
            // espera um pouco o push preencher cloud_id
            for (var i = 0; i < 6; i++) {
              final row = await AppDatabase.instance.getBabyById(id);
              final cloudId = (row?['cloud_id'] as String?)?.trim();
              if (cloudId != null && cloudId.isNotEmpty) {
                await FirestoreUserRepository.instance.saveUserProfile(uid, {
                  'name': (await AppDatabase.instance.getMotherById(motherId))?['name'],
                  'email': AuthService.instance.currentUser?.email,
                });
                await FirestoreUserRepository.instance.saveBaby(uid, {
                  'id': cloudId,
                  'name': _babyNameCtrl.text.trim(),
                  'sex': _babySex,
                  'birthDate': _babyBirthDate?.toIso8601String(),
                  'weightKg': _babyWeightKgRuler,
                  'heightCm': _babyHeightCmRuler,
                });
                await FirestoreUserRepository.instance.setSelectedBabyId(uid, cloudId);
                break;
              }
              await Future<void>.delayed(Duration(milliseconds: 220 + i * 120));
            }
          }

          // No onboarding obrigatório, precisamos garantir `selectedBabyId` antes de sair,
          // senão o AppGate pede para cadastrar outro bebê.
          if (widget.mandatory) {
            await syncSelectedToCloud();
          } else {
            unawaited(syncSelectedToCloud());
          }
        }
        return id;
      }, label: S.of(context).regSavingBaby);

      _babyFormKey.currentState?.reset();
      _babyNameCtrl.clear();
      _babyBirthDate = null;
      _babySex = 'F';
      _babyPhotoB64 = null;

      setState(() {
        _babyWeightKgRuler = 3.5;
        _babyHeightCmRuler = 50;
        _reload();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).regSnackBabyOk)),
        );
      }

      // If this page is being used as mandatory onboarding, notify completion after first baby is created.
      widget.onCompleted?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.of(context).commonCouldNotSave} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final motherBirthLabel = _motherBirthDate == null
        ? s.commonSelect
        : '${_motherBirthDate!.day.toString().padLeft(2, '0')}/${_motherBirthDate!.month.toString().padLeft(2, '0')}/${_motherBirthDate!.year}';
    final fatherBirthLabel = _fatherBirthDate == null
        ? s.commonSelect
        : '${_fatherBirthDate!.day.toString().padLeft(2, '0')}/${_fatherBirthDate!.month.toString().padLeft(2, '0')}/${_fatherBirthDate!.year}';
    final birthLabel = _babyBirthDate == null
        ? s.commonSelect
        : '${_babyBirthDate!.day.toString().padLeft(2, '0')}/${_babyBirthDate!.month.toString().padLeft(2, '0')}/${_babyBirthDate!.year}';
    final zodiac = _babyZodiacSign;

    return PopScope<Object?>(
      canPop: !widget.mandatory && (_profileEditMode || widget.babyOnly || _step == 0),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.mandatory) return;
        if (widget.babyOnly || _profileEditBaby) return;
        if (_profileEditMother) return;
        if (_step == 1) _goToMotherStep();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: widget.editBabyId != null
              ? Text(s.profileEditBaby, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))
              : widget.editMotherId != null
                  ? Text(
                      widget.profileMotherSection == MotherProfileMotherFormSection.father
                          ? s.profileEditFather
                          : s.profileEditMother,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    )
                  : const SizedBox.shrink(),
          automaticallyImplyLeading: !widget.mandatory,
          toolbarHeight: 44,
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: AppTheme.background,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: AppTheme.background,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  if (!_profileEditMode)
                    Center(
                      child: Column(
                        children: [
                          Image.asset('assets/logo.png', height: 54, fit: BoxFit.contain),
                          const SizedBox(height: 8),
                          Text(s.regLetsStart, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            widget.mandatory ? s.regSubtitleMandatory : s.regSubtitleOptional,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black.withAlpha(140)),
                          ),
                        ],
                      ),
                    ),
                  if (!_profileEditMode) const SizedBox(height: 12),
                  if (!_profileEditMode)
                    Row(
                      children: [
                        Expanded(
                          child: _StepChip(
                            index: 0,
                            current: _step,
                            title: s.regStepMother,
                            onTap: (widget.babyOnly || _profileEditBaby || _saving) ? null : _goToMotherStep,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StepChip(
                            index: 1,
                            current: _step,
                            title: s.regStepBaby,
                            onTap: (widget.editMotherId != null || _saving) ? null : _goToBabyStep,
                          ),
                        ),
                      ],
                    ),
                  if (!_profileEditMode) const SizedBox(height: 12),
                  Theme(
                      data: _motherBabyFormTheme(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        if (_step == 0) ...[
                          Form(
                            key: _motherFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_motherFormSectionVisible) ...[
                                  SectionTitle(title: s.regMotherSection),
                                  const SizedBox(height: 8),
                                TextFormField(
                                  controller: _motherNameCtrl,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: s.commonName,
                                    prefixIcon: const Icon(Icons.person_outline),
                                  ),
                                  validator: (v) {
                                    final t = (v ?? '').trim();
                                    if (t.isEmpty) return s.valNameEmpty;
                                    if (t.length < 2) return s.valNameShort;
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _motherPhoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\(\)\-\s]')),
                                    PhoneBrFormatter(),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: s.commonPhone,
                                    prefixIcon: const Icon(Icons.call_outlined),
                                  ),
                                  validator: (v) {
                                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                    if (digits.isEmpty) return s.valPhoneEmpty;
                                    if (digits.length != 11) return s.valPhoneInvalid;
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _RegTapField(
                                  label: s.regBirthLabel,
                                  value: motherBirthLabel,
                                  icon: Icons.cake_outlined,
                                  dimValue: motherBirthLabel == s.commonSelect,
                                  onTap: _pickMotherBirthDate,
                                ),
                                const SizedBox(height: 12),
                                CardBox(
                                  padding: EdgeInsets.zero,
                                  child: _motherHeightRuler(s),
                                ),
                                const SizedBox(height: 16),
                                ],
                                if (_fatherFormSectionVisible) ...[
                                SectionTitle(title: s.regFatherSection),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _fatherNameCtrl,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: s.regFatherName,
                                    prefixIcon: const Icon(Icons.man_outlined),
                                  ),
                                  validator: (v) {
                                    final t = (v ?? '').trim();
                                    if (t.isEmpty) return null;
                                    if (t.length < 2) return s.valNameShort;
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _RegTapField(
                                  label: s.regFatherBirthLabel,
                                  value: fatherBirthLabel,
                                  icon: Icons.cake_outlined,
                                  dimValue: fatherBirthLabel == s.commonSelect,
                                  onTap: _pickFatherBirthDate,
                                ),
                                const SizedBox(height: 12),
                                CardBox(
                                  padding: EdgeInsets.zero,
                                  child: _fatherHeightRuler(s),
                                ),
                                const SizedBox(height: 12),
                                _RegPhotoTapField(
                                  label: s.fatherPhotoTitle,
                                  caption: ((_fatherPhotoB64 == null) &&
                                          (_fatherPhotoUrl == null ||
                                              _fatherPhotoUrl!.isEmpty))
                                      ? s.regFatherPhotoAdd
                                      : s.regFatherPhotoChange,
                                  photoB64: _fatherPhotoB64,
                                  photoUrl: _fatherPhotoUrl,
                                  avatarBg: const Color(0xFFD6EBFF),
                                  fallback: const Icon(Icons.man_outlined,
                                      color: AppTheme.secondary),
                                  onTap: () async {
                                    // Não usar [_runLoading]: mantém overlay global durante câmara/recorte e bloqueia a UI.
                                    final b64 = await pickImageAsB64(
                                      context: context,
                                      maxBytes: 2 * 1024 * 1024,
                                    );
                                    if (b64 == null) return;
                                    setState(() {
                                      _fatherPhotoB64 = b64;
                                      _fatherPhotoUrl = null;
                                      _fatherPhotoDirty = true;
                                    });
                                  },
                                ),
                                ],
                                if (_motherFormSectionVisible) ...[
                                const SizedBox(height: 12),
                                _RegPhotoTapField(
                                  label: s.motherPhotoTitle,
                                  caption: ((_motherPhotoB64 == null) &&
                                          (_motherPhotoUrl == null || _motherPhotoUrl!.isEmpty))
                                      ? s.regMotherPhotoAdd
                                      : s.regMotherPhotoChange,
                                  photoB64: _motherPhotoB64,
                                  photoUrl: _motherPhotoUrl,
                                  avatarBg: const Color(0xFFFFDCE8),
                                  fallback: const Icon(Icons.person, color: AppTheme.secondary),
                                  onTap: () async {
                                    final b64 = await pickImageAsB64(
                                      context: context,
                                      maxBytes: 2 * 1024 * 1024,
                                    );
                                    if (b64 == null) return;
                                    setState(() {
                                      _motherPhotoB64 = b64;
                                      _motherPhotoUrl = null;
                                      _motherPhotoDirty = true;
                                    });
                                  },
                                ),
                                ],
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _saving ? null : _saveMother,
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: FaceBabySpinner(size: 18, strokeWidth: 2.5),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: Text(_saving ? s.commonSaving : (_profileEditMother ? s.commonSave : s.regSaveMotherAdvance)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FutureBuilder<List<Map<String, Object?>>>(
                                  future: _mothersFuture,
                                  builder: (context, snapshot) {
                                    final mothers = snapshot.data ?? const [];
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Center(child: FaceBabySpinner(size: 28)),
                                      );
                                    }
                                    if (_profileEditMother || widget.mandatory || mothers.isEmpty) return const SizedBox.shrink();

                                    _selectedMotherId ??= (mothers.first['id'] as num).toInt();
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.regSelectMotherPrompt,
                                          style: TextStyle(color: Colors.black.withAlpha(150), fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<int>(
                                          key: ValueKey(_selectedMotherId),
                                          initialValue: _selectedMotherId,
                                          isExpanded: true,
                                          items: mothers.map((m) {
                                            final id = (m['id'] as num).toInt();
                                            final name = (m['name'] as String?) ?? '—';
                                            return DropdownMenuItem(
                                              value: id,
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (v) => setState(() => _selectedMotherId = v),
                                          decoration: InputDecoration(
                                            labelText: s.regMotherLabel,
                                            prefixIcon: const Icon(Icons.person_outline),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                if (!widget.mandatory && !_profileEditMother)
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.tonalIcon(
                                      onPressed: _saving ? null : _goToBabyStep,
                                      icon: const Icon(Icons.arrow_forward),
                                      label: Text(s.commonAdvance),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              if (!widget.babyOnly && !_profileEditBaby)
                                IconButton(
                                  onPressed: _saving ? null : _goToMotherStep,
                                  icon: const Icon(Icons.arrow_back),
                                  tooltip: s.commonBack,
                                ),
                              if (!widget.babyOnly && !_profileEditBaby) const SizedBox(width: 6),
                              Expanded(child: SectionTitle(title: s.regBabySection)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Form(
                            key: _babyFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FutureBuilder<List<Map<String, Object?>>>(
                                  future: _mothersFuture,
                                  builder: (context, snapshot) {
                                    final mothers = snapshot.data ?? const [];
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Center(child: FaceBabySpinner(size: 28)),
                                      );
                                    }
                                    if (mothers.isEmpty) {
                                      return Text(s.regBabyPrompt);
                                    }
                                    _selectedMotherId ??= (mothers.first['id'] as num).toInt();
                                    final mid = _selectedMotherId;
                                    String? mName;
                                    if (mid != null) {
                                      for (final m in mothers) {
                                        final id = (m['id'] as num?)?.toInt();
                                        if (id == mid) {
                                          mName = (m['name'] as String?)?.trim();
                                          break;
                                        }
                                      }
                                    }
                                    final display = s.regMomDisplay(mName);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        s.regPromptBabyNameLine(display),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black.withAlpha(170),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _babyNameCtrl,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: s.commonName,
                                    prefixIcon: const Icon(Icons.child_care),
                                  ),
                                  validator: (v) {
                                    final t = (v ?? '').trim();
                                    if (t.isEmpty) return s.valNameEmpty;
                                    if (t.length < 2) return s.valNameShort;
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                InputDecorator(
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ).applyDefaults(Theme.of(context).inputDecorationTheme),
                                  child: SegmentedButton<String>(
                                    segments: [
                                      ButtonSegment(value: 'F', label: Text(s.regBabyGirl)),
                                      ButtonSegment(value: 'M', label: Text(s.regBabyBoy)),
                                    ],
                                    selected: <String>{_babySex},
                                    onSelectionChanged: (v) => setState(() => _babySex = v.first),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _RegPhotoTapField(
                                  label: s.babyPhotoTitle,
                                  caption:
                                      ((_babyPhotoB64 == null) && (_babyPhotoUrl == null || _babyPhotoUrl!.isEmpty))
                                          ? s.regBabyPhotoAdd
                                          : s.regBabyPhotoChange,
                                  photoB64: _babyPhotoB64,
                                  photoUrl: _babyPhotoUrl,
                                  avatarBg: _babySex == 'M' ? const Color(0xFFD6EBFF) : const Color(0xFFFFDCE8),
                                  fallback: const Icon(Icons.child_care, color: AppTheme.secondary),
                                  onTap: () async {
                                    final b64 = await pickImageAsB64(
                                      context: context,
                                      maxBytes: 2 * 1024 * 1024,
                                    );
                                    if (b64 == null) return;
                                    setState(() {
                                      _babyPhotoB64 = b64;
                                      _babyPhotoUrl = null;
                                      _babyPhotoDirty = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                _RegTapField(
                                  label: s.regBirthLabel,
                                  value: birthLabel,
                                  icon: Icons.cake_outlined,
                                  dimValue: birthLabel == s.commonSelect,
                                  onTap: _pickBirthDate,
                                ),
                                if (zodiac != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, size: 18, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Text(s.regZodiacLine(zodiac), style: const TextStyle(fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                CardBox(
                                  padding: EdgeInsets.zero,
                                  child: _babyWeightRuler(s),
                                ),
                                const SizedBox(height: 12),
                                CardBox(
                                  padding: EdgeInsets.zero,
                                  child: _babyHeightRuler(s),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _saving ? null : _saveBaby,
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: FaceBabySpinner(size: 18, strokeWidth: 2.5),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: Text(_saving ? s.commonSaving : (_profileEditBaby ? s.commonSave : s.regSaveBaby)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!widget.mandatory && !_profileEditMode) ...[
                    const SizedBox(height: 18),
                    SectionTitle(title: s.regRegisteredList),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Map<String, Object?>>>(
                      future: _listFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: FaceBabySpinner(size: 30)),
                          );
                        }
                        final rows = snapshot.data ?? const [];
                        if (rows.isEmpty) {
                          return CardBox(
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline),
                                const SizedBox(width: 10),
                                Expanded(child: Text(s.regNoneYet)),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: rows.map((row) {
                            final motherName = (row['mother_name'] as String?) ?? '';
                            final motherPhone = row['mother_phone'] as String?;
                            final babyName = (row['baby_name'] as String?) ?? '';
                            final babyBirth = row['baby_birth_date'] as String?;
                            final babyZodiac = row['baby_zodiac_sign'] as String?;

                            String? birthText;
                            if (babyBirth != null) {
                              final dt = DateTime.tryParse(babyBirth);
                              if (dt != null) {
                                birthText =
                                    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                              }
                            }

                            final subtitle = <String>[
                              if (babyName.trim().isNotEmpty) s.regListBabyLine(babyName.trim()),
                              if (birthText != null) s.regListBirthLine(birthText),
                              if (babyZodiac != null && babyZodiac.trim().isNotEmpty) s.regListSignLine(babyZodiac.trim()),
                              if (motherPhone != null && motherPhone.trim().isNotEmpty) s.regListPhoneLine(motherPhone.trim()),
                            ].join(' • ');

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: CardBox(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.primary.withAlpha(31),
                                      child: const Icon(Icons.family_restroom, color: AppTheme.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(motherName, style: const TextStyle(fontWeight: FontWeight.w900)),
                                          const SizedBox(height: 6),
                                          Text(subtitle.isEmpty ? '—' : subtitle),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Data (ou valor) tocável com o mesmo contorno dos [TextFormField].
class _RegTapField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool dimValue;

  const _RegTapField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.dimValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.inputDecorationTheme;
    final decoration = InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: scheme.onSurfaceVariant),
      suffixIcon: Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
    ).applyDefaults(base);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: decoration,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 22),
              child: Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: dimValue ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Foto opcional com o mesmo contorno dos outros campos.
class _RegPhotoTapField extends StatelessWidget {
  final String label;
  final String caption;
  final String? photoB64;
  final String? photoUrl;
  final Color avatarBg;
  final Widget fallback;
  final VoidCallback onTap;

  const _RegPhotoTapField({
    required this.label,
    required this.caption,
    required this.photoB64,
    this.photoUrl,
    required this.avatarBg,
    required this.fallback,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.inputDecorationTheme;
    final decoration = InputDecoration(
      labelText: label,
      prefixIcon: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 8),
        child: PhotoAvatar(
          photoB64: photoB64,
          photoUrl: photoUrl,
          radius: 20,
          backgroundColor: avatarBg,
          fallback: fallback,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 48),
      suffixIcon: Icon(Icons.add_a_photo_outlined, color: scheme.onSurfaceVariant),
    ).applyDefaults(base);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: decoration,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final int index;
  final int current;
  final String title;
  final VoidCallback? onTap;

  const _StepChip({
    required this.index,
    required this.current,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == index;
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary.withAlpha(16) : Colors.white;
    final border = selected ? scheme.primary.withAlpha(90) : const Color(0xFFEEE6F6);
    final fg = selected ? scheme.primary : Colors.black.withAlpha(170);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: bg,
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? scheme.primary : Colors.black.withAlpha(8),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: selected ? Colors.white : Colors.black.withAlpha(150),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: fg)),
          ],
        ),
      ),
    );
  }
}

