import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../controllers/current_baby_controller.dart';
import '../../utils/growth_baseline.dart';
import '../../utils/ai_nanny_locale_codes.dart';
import 'ai_nanny_local_message_parser.dart';
import 'ai_nanny_parse_result_normalizer.dart';
import 'ai_nanny_processing_phase.dart';
import 'ai_nanny_service.dart';

/// Parser estruturado — local rápido + cloud com timeout (sem bloquear UI).
class ParseAiNannyMessageService {
  ParseAiNannyMessageService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: aiNannyFunctionsRegion),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  static const _cloudTimeout = Duration(seconds: 8);
  static const _slowAfter = Duration(seconds: 2);

  /// Cache de contexto de crescimento (evita query repetida no mesmo turno).
  (double?, double?)? _growthCache;

  Future<AiNannyParseResult> parse({
    required String message,
    AppLang locale = AppLang.pt,
    String? babyName,
    String? timezone,
    bool preferCloud = true,
    AiNannyProgressCallback? onProgress,
  }) async {
    final text = message.trim();
    if (text.isEmpty) {
      return const AiNannyParseResult(classification: 'chat_only');
    }

    void report(AiNannyProcessingPhase p) => onProgress?.call(p);

    report(AiNannyProcessingPhase.understanding);

    final local = await compute(
      _parseLocalIsolate,
      text,
    );

    report(AiNannyProcessingPhase.identifying);

    if (!preferCloud || _auth.currentUser == null) {
      report(AiNannyProcessingPhase.preparing);
      return local;
    }

    report(AiNannyProcessingPhase.preparing);

    final slowTimer = Timer(_slowAfter, () {
      report(AiNannyProcessingPhase.slowWarning);
    });
    final verySlowTimer = Timer(_cloudTimeout, () {
      report(AiNannyProcessingPhase.verySlow);
    });

    try {
      final growth = await _lastGrowthSnapshot();
      final cloudFuture = _callCloud(
        text: text,
        locale: locale,
        babyName: babyName,
        timezone: timezone,
        growth: growth,
      );
      final cloud = await cloudFuture.timeout(_cloudTimeout);
      if (cloud.hasRecords) {
        return cloud;
      }
    } catch (e, st) {
      debugPrint('ParseAiNannyMessageService: cloud fallback local: $e\n$st');
    } finally {
      slowTimer.cancel();
      verySlowTimer.cancel();
    }

    return local;
  }

  static AiNannyParseResult _parseLocalIsolate(String text) {
    return AiNannyParseResultNormalizer.normalize(
      AiNannyLocalMessageParser.parse(text),
      text,
    );
  }

  Future<AiNannyParseResult> _callCloud({
    required String text,
    required AppLang locale,
    String? babyName,
    String? timezone,
    required (double?, double?) growth,
  }) async {
    final callable = _functions.httpsCallable(
      'parseAiNannyMessage',
      options: HttpsCallableOptions(timeout: _cloudTimeout),
    );
    final result = await callable.call({
      'message': text,
      'locale': AiNannyLocaleCodes.fromAppLang(locale),
      if (babyName != null && babyName.isNotEmpty) 'babyName': babyName,
      'timezone': timezone ?? 'America/Sao_Paulo',
      'nowIso': DateTime.now().toIso8601String(),
      if (growth.$1 != null) 'lastWeightKg': growth.$1,
      if (growth.$2 != null) 'lastHeightCm': growth.$2,
    });
    final data = result.data;
    if (data is Map) {
      final parsed = AiNannyParseResult.fromMap(
        Map<String, dynamic>.from(data),
      );
      if (parsed.hasRecords) {
        return AiNannyParseResultNormalizer.normalize(parsed, text);
      }
    }
    return const AiNannyParseResult(classification: 'chat_only');
  }

  Future<(double?, double?)> _lastGrowthSnapshot() async {
    if (_growthCache != null) return _growthCache!;
    final babyId = CurrentBabyController.instance.currentBabyId;
    if (babyId == null) return (null, null);
    final w = await GrowthBaseline.latestWeightKg(babyId);
    final h = await GrowthBaseline.latestHeightCm(babyId);
    _growthCache = (w, h);
    return _growthCache!;
  }
}
