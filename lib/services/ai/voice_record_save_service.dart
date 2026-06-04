import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../../controllers/breastfeeding_timer_controller.dart';
import '../../controllers/current_baby_controller.dart';
import '../../controllers/sleep_timer_controller.dart';
import '../../models/ai/voice_record_interpretation.dart';
import '../../utils/voice_record_clarification.dart' show parseFeedingDurationMinutes;
import '../../utils/voice_sleep_action.dart' show normalizeVoiceSleepAction, transcriptIndicatesWakeEnd;
import '../app_database.dart';
import '../../utils/growth_baseline.dart';
import '../firebase/profile_cloud_sync.dart';
import '../firebase/diaper_cloud_sync.dart';
import '../firebase/feeding_cloud_sync.dart';
import '../firebase/consultation_cloud_sync.dart';
import '../firebase/growth_cloud_sync.dart';
import '../growth_events.dart';
import '../firebase/sleep_cloud_sync.dart';
import '../firebase/symptom_cloud_sync.dart';
import '../firebase/vaccine_cloud_sync.dart';
import '../scheduled_local_reminders.dart';
import '../vaccine_reminder_scheduler.dart';
import 'feeding_record_verifier.dart';

/// Resultado da gravação local (inclui id quando aplicável).
class VoiceRecordApplyResult {
  const VoiceRecordApplyResult(this.kind, {this.localFeedingId});

  final VoiceRecordSaveKind kind;
  final int? localFeedingId;
}

/// Persiste registro confirmado pelo usuário (local + sync nuvem).
class VoiceRecordSaveService {
  Future<VoiceRecordApplyResult> applyConfirmed({
    required VoiceRecordInterpretation interpretation,
    String transcript = '',
  }) async {
    final babyId = CurrentBabyController.instance.currentBabyId;
    if (babyId == null) {
      throw const VoiceRecordSaveException('Cadastre um bebê primeiro.');
    }

    switch (interpretation.type) {
      case 'feeding':
        final feedingId = await _saveFeeding(babyId, interpretation);
        return VoiceRecordApplyResult(
          VoiceRecordSaveKind.saved,
          localFeedingId: feedingId,
        );
      case 'sleep':
        final sleepKind = await _saveSleep(babyId, interpretation, transcript);
        return VoiceRecordApplyResult(sleepKind);
      case 'diaper':
        await _saveDiaper(babyId, interpretation);
        return const VoiceRecordApplyResult(VoiceRecordSaveKind.saved);
      case 'weight':
        await _saveWeight(babyId, interpretation);
        return const VoiceRecordApplyResult(VoiceRecordSaveKind.saved);
      case 'height':
        await _saveHeight(babyId, interpretation);
        return const VoiceRecordApplyResult(VoiceRecordSaveKind.saved);
      case 'symptom':
        await _saveSymptom(babyId, interpretation);
        return const VoiceRecordApplyResult(VoiceRecordSaveKind.saved);
      case 'consultation':
        await _saveConsultation(babyId, interpretation);
        return const VoiceRecordApplyResult(VoiceRecordSaveKind.saved);
      case 'vaccine':
        await _saveVaccine(babyId, interpretation);
        return const VoiceRecordApplyResult(VoiceRecordSaveKind.saved);
      case 'question':
        throw const VoiceRecordSaveException(
          'Isso é uma pergunta — use "Perguntar à IA Babá" em vez de Confirmar.',
        );
      default:
        throw const VoiceRecordSaveException(
          'Não identifiquei um registro. Ex.: "pesou 3,5 kg", "altura 60 cm" ou "dormiu 40 minutos".',
        );
    }
  }

  Future<int> _saveFeeding(
    int babyId,
    VoiceRecordInterpretation interpretation,
  ) async {
    FeedingRecordVerifier.logSavePayload(
      babyId: babyId,
      interpretation: interpretation,
    );
    final f = interpretation.feeding;
    final now = DateTime.now();
    var ended = f?.eventTime ?? now;
    var subtype = (f?.subtype ?? '').trim().toLowerCase();
    if (subtype != 'peito' && subtype != 'mamadeira' && subtype != 'solidos') {
      throw const VoiceRecordSaveException(
        'Informe se foi peito ou mamadeira antes de registrar.',
      );
    }
    String? side;
    if (subtype == 'peito') {
      side = (f?.side ?? '').trim().toUpperCase();
      if (side != 'E' && side != 'D') {
        throw const VoiceRecordSaveException(
          'Informe o lado do peito (esquerdo ou direito).',
        );
      }
    }
    var durationMin = 10;
    final noteText = f?.note ?? '';
    var parsedMin = parseFeedingDurationMinutes(noteText.toLowerCase());
    if (parsedMin == null && noteText.trim().isNotEmpty) {
      parsedMin = int.tryParse(noteText.replaceAll(RegExp(r'[^0-9]'), ''));
      if (parsedMin != null && (parsedMin < 1 || parsedMin > 180)) {
        parsedMin = null;
      }
    }
    if (parsedMin != null) durationMin = parsedMin;

    var started = ended.subtract(Duration(minutes: durationMin));
    final breastTimer = BreastfeedingTimerController.instance;
    var usedBreastTimer = false;
    if (subtype == 'peito' &&
        breastTimer.isRunning &&
        breastTimer.babyId == babyId &&
        breastTimer.startedAt != null &&
        breastTimer.side != null) {
      final timerSide = breastTimer.side!.toUpperCase();
      if (side == null || side == timerSide) {
        side ??= timerSide;
        final elapsed = breastTimer.elapsedForSide(breastTimer.side!);
        durationMin = elapsed.inMinutes.clamp(1, 180);
        started = breastTimer.startedAt!;
        ended = DateTime.now();
        usedBreastTimer = true;
      }
    }
    if (usedBreastTimer) {
      breastTimer.clearSession();
    }

    final qty = f?.quantityMl;

    final newId = await AppDatabase.instance.insertFeeding(
      babyId: babyId,
      startedAt: started,
      endedAt: ended,
      durationSec: ended.difference(started).inSeconds.clamp(1, 86400),
      side: side,
      type: subtype,
      quantityMl: qty,
      note: f?.note,
    );
    FeedingCloudSync.pushLocalSoon(localBabyId: babyId, localFeedingId: newId);
    debugPrint(
      'AiNannySave[feeding]: insertFeeding ok id=$newId '
      'collection=${FeedingRecordVerifier.collectionPath}',
    );
    return newId;
  }

  Future<VoiceRecordSaveKind> _saveSleep(
    int babyId,
    VoiceRecordInterpretation interpretation,
    String transcript,
  ) async {
    final s = interpretation.sleep;
    var action = normalizeVoiceSleepAction(
      fromInterpretation: s?.action,
      transcript: transcript,
    );
    if (action == 'complete' && transcriptIndicatesWakeEnd(transcript)) {
      action = 'end';
    }

    if (action == 'start') {
      await _startSleepSession(babyId);
      return VoiceRecordSaveKind.sleepStarted;
    }

    if (action == 'end') {
      return _wakeBaby(babyId, note: s?.note);
    }

    await _logCompletedSleep(babyId, s);
    return VoiceRecordSaveKind.saved;
  }

  /// Encerra sono ativo; se o cronômetro estiver dessincronizado, limpa a UI mesmo assim.
  Future<VoiceRecordSaveKind> _wakeBaby(int babyId, {String? note}) async {
    final timer = SleepTimerController.instance;
    await timer.init();

    if (timer.isTracking &&
        timer.babyId == babyId &&
        timer.startedAt != null) {
      try {
        await _endSleepSession(babyId, note: note);
        return VoiceRecordSaveKind.sleepEnded;
      } on VoiceRecordSaveException {
        timer.clearSession();
        await _syncReminders(babyId);
        return VoiceRecordSaveKind.sleepEnded;
      }
    }

    if (timer.isTracking && timer.babyId == babyId) {
      timer.clearSession();
      await _syncReminders(babyId);
      return VoiceRecordSaveKind.sleepEnded;
    }

    throw const VoiceRecordSaveException(
      'Não há sono em andamento. Diga por exemplo "dormiu 40 minutos" para registrar um período.',
    );
  }

  Future<void> _startSleepSession(int babyId) async {
    final timer = SleepTimerController.instance;
    if (timer.isTracking) {
      if (timer.babyId == babyId) {
        throw const VoiceRecordSaveException('O sono já está em andamento.');
      }
      throw const VoiceRecordSaveException(
        'Há outro sono em andamento. Encerre na tela Sono antes de iniciar outro.',
      );
    }
    await timer.init();
    timer.begin(babyId: babyId);
    await _syncReminders(babyId);
  }

  Future<void> _endSleepSession(int babyId, {String? note}) async {
    final timer = SleepTimerController.instance;
    await timer.init();
    if (!timer.isTracking || timer.babyId != babyId || timer.startedAt == null) {
      throw const VoiceRecordSaveException(
        'Não há sono em andamento. Diga por exemplo "dormiu 40 minutos" para registrar um período.',
      );
    }

    final started = timer.startedAt!;
    final ended = DateTime.now();
    final elapsed = timer.effectiveElapsed;
    final sec = elapsed.inSeconds;
    if (sec < 1) {
      throw const VoiceRecordSaveException('Sono muito curto para registrar.');
    }

    final newId = await AppDatabase.instance.insertSleepRecord(
      babyId: babyId,
      startedAt: started,
      endedAt: ended,
      durationSec: sec,
      quality: _sleepQualityKey(elapsed),
      note: note,
    );
    SleepCloudSync.pushLocalSoon(localBabyId: babyId, localSleepId: newId);
    await _clearSleepTimerIfActive(babyId);
    await _syncReminders(babyId);
  }

  Future<void> _clearSleepTimerIfActive(int babyId) async {
    final timer = SleepTimerController.instance;
    await timer.init();
    if (timer.isTracking && timer.babyId == babyId) {
      timer.clearSession();
    }
  }

  Future<void> _logCompletedSleep(int babyId, VoiceSleepPayload? s) async {
    final now = DateTime.now();
    final ended = s?.endedAt ?? now;
    var started = s?.startedAt;
    if (started == null && s?.durationMinutes != null && s!.durationMinutes! > 0) {
      started = ended.subtract(Duration(minutes: s.durationMinutes!));
    }
    started ??= ended.subtract(const Duration(minutes: 45));
    final sec = ended.difference(started).inSeconds;
    if (sec < 1) {
      throw const VoiceRecordSaveException('Horário de sono inválido.');
    }

    final newId = await AppDatabase.instance.insertSleepRecord(
      babyId: babyId,
      startedAt: started,
      endedAt: ended,
      durationSec: sec,
      quality: _sleepQualityKey(Duration(seconds: sec)),
      note: s?.note,
    );
    SleepCloudSync.pushLocalSoon(localBabyId: babyId, localSleepId: newId);
    await _clearSleepTimerIfActive(babyId);
    await _syncReminders(babyId);
  }

  static String _sleepQualityKey(Duration d) {
    final min = d.inMinutes;
    if (min < 20) return 'bad';
    if (min < 50) return 'ok';
    return 'good';
  }

  Future<void> _syncReminders(int babyId) async {
    try {
      await ScheduledLocalReminders.sync(babyId: babyId);
    } catch (_) {}
  }

  Future<void> _saveDiaper(
    int babyId,
    VoiceRecordInterpretation interpretation,
  ) async {
    final d = interpretation.diaper;
    final kind = (d?.kind ?? '').trim().toLowerCase();
    if (kind != 'pee' && kind != 'poo' && kind != 'both') {
      throw const VoiceRecordSaveException(
        'Informe se a fralda tinha xixi, cocô ou ambos.',
      );
    }
    final changed = d?.changedAt ?? DateTime.now();

    final newId = await AppDatabase.instance.insertDiaperChange(
      babyId: babyId,
      changedAt: changed,
      kind: kind,
    );
    DiaperCloudSync.pushLocalSoon(localBabyId: babyId, localDiaperId: newId);
  }

  Future<void> _saveWeight(
    int babyId,
    VoiceRecordInterpretation interpretation,
  ) async {
    final w = interpretation.weight;
    var kg = w?.weightKg;
    final deltaG = w?.weightDeltaGrams;

    if ((kg == null || kg <= 0) && deltaG != null && deltaG != 0) {
      final base = await GrowthBaseline.latestWeightKg(babyId);
      if (base == null || base <= 0) {
        throw const VoiceRecordSaveException(
          'Para "ganhou X gramas", cadastre antes um peso no perfil ou em Crescimento.',
        );
      }
      kg = base + deltaG / 1000.0;
    }

    if (kg == null || kg <= 0 || kg > 80) {
      throw const VoiceRecordSaveException('Peso não identificado no áudio.');
    }
    if (kg >= 35 && kg <= 43) {
      throw const VoiceRecordSaveException(
        'Parece temperatura (febre), não peso. Diga "febre 38 graus" para registrar em Saúde.',
      );
    }
    final measured = w?.measuredAt ?? DateTime.now();

    final newId = await AppDatabase.instance.insertGrowthRecord(
      babyId: babyId,
      kind: 'weight',
      value: kg,
      measuredAt: measured,
    );
    GrowthCloudSync.pushLocalSoon(
      localBabyId: babyId,
      localGrowthId: newId,
    );
    await GrowthBaseline.syncBabyProfileAfterMeasurement(
      babyId: babyId,
      weightKg: kg,
    );
    unawaited(ProfileCloudSync.pushBaby(babyId));
    GrowthEvents.ping();
  }

  Future<void> _saveHeight(
    int babyId,
    VoiceRecordInterpretation interpretation,
  ) async {
    final h = interpretation.height;
    var cm = h?.heightCm;
    final delta = h?.heightDeltaCm;

    if ((cm == null || cm <= 0) && delta != null && delta > 0) {
      final base = await GrowthBaseline.latestHeightCm(babyId);
      if (base == null || base <= 0) {
        throw const VoiceRecordSaveException(
          'Para "cresceu X cm", cadastre antes uma altura (ex.: "altura 60 cm") no perfil ou em Crescimento.',
        );
      }
      cm = base + delta;
    }

    if (cm == null || cm <= 0 || cm > 250) {
      throw const VoiceRecordSaveException(
        'Altura não identificada. Diga por exemplo "altura 60 cm" ou "cresceu 3 centímetros".',
      );
    }

    final measured = h?.measuredAt ?? DateTime.now();
    final newId = await AppDatabase.instance.insertGrowthRecord(
      babyId: babyId,
      kind: 'height',
      value: cm,
      measuredAt: measured,
    );
    GrowthCloudSync.pushLocalSoon(
      localBabyId: babyId,
      localGrowthId: newId,
    );
    await GrowthBaseline.syncBabyProfileAfterMeasurement(
      babyId: babyId,
      heightCm: cm,
    );
    unawaited(ProfileCloudSync.pushBaby(babyId));
    GrowthEvents.ping();
  }

  Future<void> _saveSymptom(
    int babyId,
    VoiceRecordInterpretation interpretation,
  ) async {
    final s = interpretation.symptom;
    if (s == null) {
      throw const VoiceRecordSaveException('Sintoma não identificado.');
    }
    final any = s.fever ||
        s.crying ||
        s.pain ||
        s.colic ||
        s.reflux ||
        (s.otherNote != null && s.otherNote!.trim().isNotEmpty);
    if (!any) {
      throw const VoiceRecordSaveException(
        'Marque pelo menos um sintoma ou adicione uma observação.',
      );
    }

    final newId = await AppDatabase.instance.insertSymptomReport(
      babyId: babyId,
      occurredAt: s.occurredAt ?? DateTime.now(),
      medicationNote: null,
      fever: s.fever,
      tempCelsius: s.fever ? s.tempCelsius : null,
      crying: s.crying,
      pain: s.pain,
      colic: s.colic,
      reflux: s.reflux,
      otherNote: s.otherNote,
    );
    SymptomCloudSync.pushLocalSoon(
      localBabyId: babyId,
      localSymptomId: newId,
    );
  }

  Future<void> _saveConsultation(
    int babyId,
    VoiceRecordInterpretation interpretation,
  ) async {
    final c = interpretation.consultation;
    final title = c?.title?.trim() ?? '';
    if (title.isEmpty) {
      throw const VoiceRecordSaveException(
        'Informe o título da consulta (ex.: Pediatra).',
      );
    }

    final newId = await AppDatabase.instance.insertConsultation(
      babyId: babyId,
      title: title,
      occurredAt: c?.occurredAt ?? DateTime.now(),
      notes: c?.notes,
      phone: c?.phone,
      address: c?.address,
    );
    ConsultationCloudSync.pushLocalSoon(
      localBabyId: babyId,
      localConsultationId: newId,
    );
  }

  Future<void> _saveVaccine(
    int babyId,
    VoiceRecordInterpretation interpretation,
  ) async {
    final v = interpretation.vaccine;
    final name = v?.name?.trim() ?? '';
    if (name.isEmpty) {
      throw const VoiceRecordSaveException(
        'Informe o nome da vacina antes de confirmar.',
      );
    }

    final newId = await AppDatabase.instance.insertVaccine(
      babyId: babyId,
      name: name,
      dose: v?.dose,
      appliedAt: v?.appliedAt,
      nextDueAt: v?.nextDueAt,
      notes: v?.notes,
    );
    VaccineCloudSync.pushLocalSoon(
      localBabyId: babyId,
      localVaccineId: newId,
    );
    await VaccineReminderScheduler.instance.rescheduleForBaby(babyId);
  }
}

class VoiceRecordSaveException implements Exception {
  const VoiceRecordSaveException(this.message);
  final String message;
}
