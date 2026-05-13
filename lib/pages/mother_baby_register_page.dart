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
import '../utils/measurement_format.dart';
import '../utils/zodiac.dart';
import '../widgets/card_box.dart';
import '../widgets/loading_scope.dart';
import '../widgets/face_baby_loading.dart';
import '../widgets/photo_avatar.dart';
import '../widgets/section_title.dart';

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
  /// Editar dados do bebê existente (Meu Perfil).
  final int? editBabyId;

  const MotherBabyRegisterPage({
    super.key,
    this.mandatory = false,
    this.onCompleted,
    this.babyOnly = false,
    this.presetMotherId,
    this.editMotherId,
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
  final _motherHeightCtrl = TextEditingController();
  final _fatherHeightCtrl = TextEditingController();
  final _babyNameCtrl = TextEditingController();
  final _babyWeightCtrl = TextEditingController();
  final _babyHeightCtrl = TextEditingController();

  DateTime? _motherBirthDate;
  DateTime? _babyBirthDate;
  String _babySex = 'F';
  String? _motherPhotoB64;
  String? _babyPhotoB64;
  String? _motherPhotoUrl;
  String? _babyPhotoUrl;
  bool _motherPhotoDirty = false;
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
      _motherHeightCtrl.text = h != null
          ? (switch (MeasurementUnitsPrefs.length.value) {
              LengthUnit.cm => h.toDouble(),
              LengthUnit.inch => h.toDouble() / 2.54,
            })
              .toStringAsFixed(MeasurementUnitsPrefs.length.value == LengthUnit.cm ? 0 : 1)
              .replaceAll('.', ',')
          : '';
      _fatherHeightCtrl.text = fh != null
          ? (switch (MeasurementUnitsPrefs.length.value) {
              LengthUnit.cm => fh.toDouble(),
              LengthUnit.inch => fh.toDouble() / 2.54,
            })
              .toStringAsFixed(MeasurementUnitsPrefs.length.value == LengthUnit.cm ? 0 : 1)
              .replaceAll('.', ',')
          : '';
      _motherBirthDate = birth == null ? null : DateTime(birth.year, birth.month, birth.day);
      _motherPhotoB64 = (row['photo_b64'] as String?)?.trim();
      final mu = (row['photo_url'] as String?)?.trim();
      _motherPhotoUrl = (mu == null || mu.isEmpty) ? null : mu;
      _motherPhotoDirty = false;
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
      if (w != null) {
        _babyWeightCtrl.text = switch (MeasurementUnitsPrefs.weight.value) {
          WeightUnit.kg => (w.toDouble()).toStringAsFixed(2),
          WeightUnit.lb => (w.toDouble() * 2.2046226218).toStringAsFixed(1),
          WeightUnit.st => ((w.toDouble() * 2.2046226218) / 14.0).toStringAsFixed(1),
        }.replaceAll('.', ',');
      } else {
        _babyWeightCtrl.clear();
      }
      _babyHeightCtrl.text = h != null
          ? (switch (MeasurementUnitsPrefs.length.value) {
              LengthUnit.cm => h.toDouble(),
              LengthUnit.inch => h.toDouble() / 2.54,
            })
              .toStringAsFixed(MeasurementUnitsPrefs.length.value == LengthUnit.cm ? 0 : 1)
              .replaceAll('.', ',')
          : '';
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
    _motherHeightCtrl.dispose();
    _fatherHeightCtrl.dispose();
    _babyNameCtrl.dispose();
    _babyWeightCtrl.dispose();
    _babyHeightCtrl.dispose();
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

  double? _parseHeightToCm(String raw) => MeasurementFormat.parseLengthToCm(raw);
  double? _parseWeightToKg(String raw) => MeasurementFormat.parseWeightToKg(raw);

  String _lenUnitLabel(S s) =>
      MeasurementUnitsPrefs.length.value == LengthUnit.cm ? s.unitsOptCm : s.unitsOptInch;

  String _weightUnitLabel(S s) => switch (MeasurementUnitsPrefs.weight.value) {
        WeightUnit.kg => s.unitsOptKg,
        WeightUnit.lb => s.unitsOptLb,
        WeightUnit.st => s.unitsOptSt,
      };

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

  Future<void> _saveMother() async {
    if (_saving) return;
    final valid = _motherFormKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (_motherBirthDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).regSnackMotherBirth)),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final editMid = widget.editMotherId;
      if (editMid != null) {
        await _runLoading(() async {
          await AppDatabase.instance.updateMother(
            motherId: editMid,
            name: _motherNameCtrl.text,
            phone: _motherPhoneCtrl.text,
            birthDate: _motherBirthDate,
            heightCm: _parseHeightToCm(_motherHeightCtrl.text),
            fatherHeightCm: _parseHeightToCm(_fatherHeightCtrl.text),
            photoB64: _motherPhotoB64,
            resetProfilePhotoUrl: _motherPhotoDirty,
          );
        }, label: S.of(context).commonSaving);
        // Login obrigatório: só conclui após persistir na nuvem (users/{uid} + Storage se houver foto).
        await ProfileCloudSync.pushMother(editMid);
        // Novo schema: salva também em users/{uid} (merge) para o gate.
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null) {
          unawaited(
            FirestoreUserRepository.instance.saveUserProfile(uid, {
              'name': _motherNameCtrl.text.trim(),
              'email': AuthService.instance.currentUser?.email,
              'phone': _motherPhoneCtrl.text.trim().isEmpty ? null : _motherPhoneCtrl.text.trim(),
              'birth_date': _motherBirthDate?.toIso8601String(),
              'height_cm': _parseHeightToCm(_motherHeightCtrl.text),
              'father_height_cm': _parseHeightToCm(_fatherHeightCtrl.text),
            }),
          );
        }
        _motherPhotoDirty = false;
        await CurrentBabyController.instance.refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).profileDataSaved)),
        );
        Navigator.of(context).pop();
        return;
      }

      final motherId = await _runLoading(() async {
        return await AppDatabase.instance.insertMother(
          name: _motherNameCtrl.text,
          phone: _motherPhoneCtrl.text,
          birthDate: _motherBirthDate,
          heightCm: _parseHeightToCm(_motherHeightCtrl.text),
          fatherHeightCm: _parseHeightToCm(_fatherHeightCtrl.text),
          photoB64: _motherPhotoB64,
        );
      }, label: S.of(context).regSavingMother);
      // Login obrigatório: só conclui após persistir na nuvem.
      await ProfileCloudSync.pushMother(motherId);
      // Garante persistência de campos básicos do perfil no schema users/{uid}
      // (evita perder telefone/alturas ao reinstalar, mesmo que o push demore).
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        unawaited(
          FirestoreUserRepository.instance.saveUserProfile(uid, {
            'name': _motherNameCtrl.text.trim(),
            'email': AuthService.instance.currentUser?.email,
            'phone': _motherPhoneCtrl.text.trim().isEmpty ? null : _motherPhoneCtrl.text.trim(),
            'birth_date': _motherBirthDate?.toIso8601String(),
            'height_cm': _parseHeightToCm(_motherHeightCtrl.text),
            'father_height_cm': _parseHeightToCm(_fatherHeightCtrl.text),
          }),
        );
      }
      _motherFormKey.currentState?.reset();
      _motherNameCtrl.clear();
      _motherPhoneCtrl.clear();
      _motherHeightCtrl.clear();
      _fatherHeightCtrl.clear();
      _motherBirthDate = null;
      setState(() {
        _selectedMotherId = motherId;
        _reload();
        _step = 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).regSnackMotherOk)),
        );
      }
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
            weightKg: _parseWeightToKg(_babyWeightCtrl.text),
            heightCm: _parseHeightToCm(_babyHeightCtrl.text),
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
                'weightKg': _parseWeightToKg(_babyWeightCtrl.text),
                'heightCm': _parseHeightToCm(_babyHeightCtrl.text),
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
          weightKg: _parseWeightToKg(_babyWeightCtrl.text),
          heightCm: _parseHeightToCm(_babyHeightCtrl.text),
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
                  'weightKg': _parseWeightToKg(_babyWeightCtrl.text),
                  'heightCm': _parseHeightToCm(_babyHeightCtrl.text),
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
      _babyWeightCtrl.clear();
      _babyHeightCtrl.clear();
      _babyBirthDate = null;
      _babySex = 'F';
      _babyPhotoB64 = null;

      setState(() => _reload());
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
          title: widget.editMotherId != null
              ? Text(s.profileEditMother, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))
              : widget.editBabyId != null
                  ? Text(s.profileEditBaby, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
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
                          SectionTitle(title: s.regMotherSection),
                          const SizedBox(height: 8),
                          Form(
                            key: _motherFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _motherHeightCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.next,
                                        inputFormatters: [
                                          MeasurementUnitsPrefs.length.value == LengthUnit.cm
                                              ? const IntOnlyFormatter()
                                              : const DecimalPtBrFormatter(decimalRange: 1),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: '${s.regMotherHeight} (${_lenUnitLabel(s)})',
                                          prefixIcon: const Icon(Icons.height),
                                        ),
                                        validator: (v) {
                                          final t = (v ?? '').trim();
                                          if (t.isEmpty) return s.valHeightEmpty;
                                          final cm = _parseHeightToCm(t);
                                          if (cm == null) return s.valHeightInvalid;
                                          if (cm < 120 || cm > 220) return s.valHeightMotherRange;
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _fatherHeightCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.done,
                                        inputFormatters: [
                                          MeasurementUnitsPrefs.length.value == LengthUnit.cm
                                              ? const IntOnlyFormatter()
                                              : const DecimalPtBrFormatter(decimalRange: 1),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: '${s.regFatherHeight} (${_lenUnitLabel(s)})',
                                          prefixIcon: const Icon(Icons.height_outlined),
                                        ),
                                        validator: (v) {
                                          final t = (v ?? '').trim();
                                          if (t.isEmpty) return s.valFatherHeightEmpty;
                                          final cm = _parseHeightToCm(t);
                                          if (cm == null) return s.valHeightInvalid;
                                          if (cm < 120 || cm > 220) return s.valHeightMotherRange;
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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
                                    final b64 = await _runLoading(
                                      () => pickImageAsB64(context: context, maxBytes: 2 * 1024 * 1024),
                                      label: s.openingGallery,
                                    );
                                    if (b64 == null) return;
                                    setState(() {
                                      _motherPhotoB64 = b64;
                                      _motherPhotoUrl = null;
                                      _motherPhotoDirty = true;
                                    });
                                  },
                                ),
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
                                    final b64 = await _runLoading(
                                      () => pickImageAsB64(context: context, maxBytes: 2 * 1024 * 1024),
                                      label: s.openingGallery,
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _babyWeightCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.next,
                                        inputFormatters: const [DecimalPtBrFormatter(decimalRange: 2)],
                                        decoration: InputDecoration(
                                          labelText: '${s.regBabyWeight} (${_weightUnitLabel(s)})',
                                          prefixIcon: const Icon(Icons.monitor_weight_outlined),
                                        ),
                                        validator: (v) {
                                          final t = (v ?? '').trim();
                                          if (t.isEmpty) return s.valWeightEmpty;
                                          final kg = _parseWeightToKg(t);
                                          if (kg == null) return s.valWeightInvalid;
                                          if (kg <= 0 || kg > 40) return s.valWeightRange;
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _babyHeightCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textInputAction: TextInputAction.done,
                                        inputFormatters: [
                                          MeasurementUnitsPrefs.length.value == LengthUnit.cm
                                              ? const IntOnlyFormatter()
                                              : const DecimalPtBrFormatter(decimalRange: 1),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: '${s.labelHeight} (${_lenUnitLabel(s)})',
                                          prefixIcon: const Icon(Icons.height),
                                        ),
                                        validator: (v) {
                                          final t = (v ?? '').trim();
                                          if (t.isEmpty) return s.valHeightEmpty;
                                          final cm = _parseHeightToCm(t);
                                          if (cm == null) return s.valHeightInvalid;
                                          if (cm <= 20 || cm > 120) return s.valBabyHeightRange;
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
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

