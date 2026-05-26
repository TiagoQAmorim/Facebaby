import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../i18n/app_i18n.dart';
import '../../models/ai/ai_nanny_parsed_message.dart';
import '../../services/app_database.dart';
import '../../controllers/current_baby_controller.dart';
import '../../utils/ai_nanny_locale_codes.dart';
import 'ai_nanny_local_message_parser.dart';
import 'ai_nanny_parse_result_normalizer.dart';
import 'ai_nanny_service.dart';

/// Parser estruturado — Cloud Function `parseAiNannyMessage` + fallback local.
class ParseAiNannyMessageService {
  ParseAiNannyMessageService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: aiNannyFunctionsRegion),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<AiNannyParseResult> parse({
    required String message,
    AppLang locale = AppLang.pt,
    String? babyName,
    String? timezone,
    bool preferCloud = true,
  }) async {
    final text = message.trim();
    if (text.isEmpty) {
      return const AiNannyParseResult(classification: 'chat_only');
    }

    final local = AiNannyParseResultNormalizer.normalize(
      AiNannyLocalMessageParser.parse(text),
      text,
    );
    if (!preferCloud || _auth.currentUser == null) {
      return local;
    }

    try {
      final growth = await _lastGrowthSnapshot();
      final callable = _functions.httpsCallable(
        'parseAiNannyMessage',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
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
    } catch (e, st) {
      debugPrint('ParseAiNannyMessageService: cloud fallback local: $e\n$st');
    }

    return local;
  }

  Future<(double?, double?)> _lastGrowthSnapshot() async {
    final babyId = CurrentBabyController.instance.currentBabyId;
    if (babyId == null) return (null, null);
    double? w;
    double? h;
    final wRows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: 'weight',
      limit: 1,
    );
    if (wRows.isNotEmpty) {
      w = (wRows.first['value'] as num?)?.toDouble();
    }
    w ??= (CurrentBabyController.instance.currentBabyRow?['weight_kg'] as num?)
        ?.toDouble();

    final hRows = await AppDatabase.instance.listGrowthRecords(
      babyId: babyId,
      kind: 'height',
      limit: 1,
    );
    if (hRows.isNotEmpty) {
      h = (hRows.first['value'] as num?)?.toDouble();
    }
    h ??= (CurrentBabyController.instance.currentBabyRow?['height_cm'] as num?)
        ?.toDouble();
    return (w, h);
  }

}
