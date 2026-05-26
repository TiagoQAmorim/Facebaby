import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_insight_model.dart';
import '../../utils/app_tts_locale.dart';
import '../premium/feature_access.dart';
import 'ai_insight_local_engine.dart';
import 'ai_insights_repository.dart';

const String aiInsightsFunctionsRegion = 'southamerica-east1';

/// Carrega insights do cache; gera local 1×; OpenAI só se premium e ainda `local`.
class AiInsightsService {
  AiInsightsService({
    AiInsightsRepository? repository,
    FirebaseFunctions? functions,
  })  : _repo = repository ?? AiInsightsRepository(),
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: aiInsightsFunctionsRegion);

  final AiInsightsRepository _repo;
  final FirebaseFunctions _functions;

  static bool _ensureInFlight = false;

  String get _todayKey => aiInsightDayDocId(DateTime.now());
  String get _weekKey => aiInsightWeekDocId(DateTime.now());

  Future<AiInsight?> loadTodayDaily() => _repo.loadDaily(_todayKey);

  Future<AiInsight?> loadThisWeek() => _repo.loadWeekly(_weekKey);

  Stream<AiInsight?> watchTodayDaily() => _repo.watchDaily(_todayKey);

  /// Garante resumo diário + semanal sem chamar OpenAI ao abrir se já existir cache.
  Future<void> ensureInsights({
    required S strings,
    AppLang? locale,
  }) async {
    if (_ensureInFlight) return;
    _ensureInFlight = true;
    try {
      final babyId = CurrentBabyController.instance.currentBabyId;
      if (babyId == null) return;

      final row = CurrentBabyController.instance.currentBabyRow;
      final babyName = (row?['name'] as String?)?.trim() ?? '';
      final babySex = row?['sex'] as String?;
      final birthRaw = row?['birth_date'] as String?;
      final birthDate = DateTime.tryParse(birthRaw ?? '');

      await _ensureDaily(
        localBabyId: babyId,
        cloudBabyId: CurrentBabyController.instance.currentBabyCloudId,
        babyName: babyName,
        babySex: babySex,
        birthDate: birthDate,
        strings: strings,
        locale: locale ?? strings.lang,
      );
      await _ensureWeekly(
        localBabyId: babyId,
        cloudBabyId: CurrentBabyController.instance.currentBabyCloudId,
        babyName: babyName,
        strings: strings,
        locale: locale ?? strings.lang,
      );
    } finally {
      _ensureInFlight = false;
    }
  }

  Future<void> _ensureDaily({
    required int localBabyId,
    required String? cloudBabyId,
    required String babyName,
    required String? babySex,
    required DateTime? birthDate,
    required S strings,
    required AppLang locale,
  }) async {
    var cached = await _repo.loadDaily(_todayKey);
    if (cached != null && cached.text.isNotEmpty) {
      _maybeUpgradeWithOpenAi(
        kind: AiInsightKind.dailySummary,
        docKey: _todayKey,
        cloudBabyId: cloudBabyId,
        locale: locale,
        source: cached.source,
      );
      return;
    }

    final text = await AiInsightLocalEngine.buildDailySummary(
      babyId: localBabyId,
      babyName: babyName,
      babySex: babySex,
      birthDate: birthDate,
      strings: strings,
    );

    final insight = AiInsight(
      id: _todayKey,
      kind: AiInsightKind.dailySummary,
      text: text,
      babyId: cloudBabyId ?? '$localBabyId',
      source: AiInsightSource.local,
      locale: appLocaleApiCode(locale),
      createdAt: DateTime.now(),
    );
    await _repo.saveLocal(insight);

    _maybeUpgradeWithOpenAi(
      kind: AiInsightKind.dailySummary,
      docKey: _todayKey,
      cloudBabyId: cloudBabyId,
      locale: locale,
      source: AiInsightSource.local,
    );
  }

  Future<void> _ensureWeekly({
    required int localBabyId,
    required String? cloudBabyId,
    required String babyName,
    required S strings,
    required AppLang locale,
  }) async {
    var cached = await _repo.loadWeekly(_weekKey);
    if (cached != null && cached.text.isNotEmpty) {
      _maybeUpgradeWithOpenAi(
        kind: AiInsightKind.weeklySummary,
        docKey: _weekKey,
        cloudBabyId: cloudBabyId,
        locale: locale,
        source: cached.source,
      );
      return;
    }

    final text = await AiInsightLocalEngine.buildWeeklySummary(
      babyId: localBabyId,
      babyName: babyName,
      strings: strings,
    );

    final insight = AiInsight(
      id: _weekKey,
      kind: AiInsightKind.weeklySummary,
      text: text,
      babyId: cloudBabyId ?? '$localBabyId',
      source: AiInsightSource.local,
      locale: appLocaleApiCode(locale),
      createdAt: DateTime.now(),
    );
    await _repo.saveLocal(insight);

    _maybeUpgradeWithOpenAi(
      kind: AiInsightKind.weeklySummary,
      docKey: _weekKey,
      cloudBabyId: cloudBabyId,
      locale: locale,
      source: AiInsightSource.local,
    );
  }

  void _maybeUpgradeWithOpenAi({
    required AiInsightKind kind,
    required String docKey,
    required String? cloudBabyId,
    required AppLang locale,
    required AiInsightSource source,
  }) {
    if (!FeatureAccess.canUseAiNanny) return;
    if (source == AiInsightSource.openai) return;
    unawaited(_callEnsureOpenAi(
      kind: kind,
      docKey: docKey,
      cloudBabyId: cloudBabyId,
      locale: locale,
    ));
  }

  Future<void> _callEnsureOpenAi({
    required AiInsightKind kind,
    required String docKey,
    required String? cloudBabyId,
    required AppLang locale,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'ensureAiInsight',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      await callable.call({
        'kind': kind == AiInsightKind.weeklySummary ? 'weekly' : 'daily',
        'periodKey': docKey,
        if (cloudBabyId != null && cloudBabyId.isNotEmpty) 'babyId': cloudBabyId,
        'locale': appLocaleApiCode(locale),
      });
    } catch (e) {
      debugPrint('AiInsightsService ensureAiInsight: $e');
    }
  }
}

/// Dispara [ensureInsights] uma vez ao abrir a Home (sem bloquear UI).
abstract final class AiInsightsBootstrap {
  AiInsightsBootstrap._();
  static bool _started = false;

  static void scheduleIfNeeded(S strings) {
    if (_started) return;
    _started = true;
    unawaited(AiInsightsService().ensureInsights(strings: strings));
  }

  static void resetForTests() => _started = false;
}
