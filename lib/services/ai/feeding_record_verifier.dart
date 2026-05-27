import 'package:flutter/foundation.dart';

import '../../models/ai/voice_record_interpretation.dart';
import '../app_database.dart';

/// Confirma que um registro de mamada existe na tabela local `feedings`.
abstract final class FeedingRecordVerifier {
  static const String collectionPath = 'feedings (sqlite local)';

  static void logSavePayload({
    required int babyId,
    required VoiceRecordInterpretation interpretation,
  }) {
    final f = interpretation.feeding;
    debugPrint(
      'AiNannySave[feeding]: payload babyId=$babyId '
      'subtype=${f?.subtype} side=${f?.side} note=${f?.note} '
      'qtyMl=${f?.quantityMl} eventTime=${f?.eventTime?.toIso8601String()} '
      'collection=$collectionPath',
    );
  }

  static Future<bool> existsInHistory({
    required int babyId,
    required int localFeedingId,
  }) async {
    final rows = await AppDatabase.instance.listFeedings(
      babyId: babyId,
      limit: 30,
    );
    final found = rows.any((r) => (r['id'] as num?)?.toInt() == localFeedingId);
    debugPrint(
      'AiNannySave[feeding]: verify id=$localFeedingId found=$found '
      'collection=$collectionPath',
    );
    return found;
  }
}
