import '../../i18n/app_i18n.dart';
import '../development_leaps_service.dart';
import '../home_yesterday_baba_service.dart';

/// Texto único do balão: resumo de ontem + curiosidade do salto de desenvolvimento.
abstract final class AiBubbleRoutineInsights {
  AiBubbleRoutineInsights._();

  static const prefsKey = 'yesterday_curiosity_brief';

  static Future<String?> yesterdayAndCuriosity({
    required int? babyId,
    required String babyName,
    required String? babySex,
    required DateTime? birthDate,
    required S strings,
  }) async {
    final buffer = StringBuffer();

    final yesterdayBody = await HomeYesterdayBabaService.bodyForToday(
      babyId: babyId,
      babyName: babyName,
      babySex: babySex,
      birthDate: birthDate,
      strings: strings,
    );
    final yesterdayTrimmed = yesterdayBody.trim();
    if (yesterdayTrimmed.isNotEmpty) {
      buffer.writeln(strings.homeYesterdayBabaTitle);
      buffer.writeln();
      buffer.writeln(yesterdayTrimmed);
    }

    final curiosity = _developmentCuriositySection(
      babyName: babyName,
      birthDate: birthDate,
      strings: strings,
    );
    if (curiosity != null) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write(curiosity);
    }

    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _developmentCuriositySection({
    required String babyName,
    required DateTime? birthDate,
    required S strings,
  }) {
    if (birthDate == null) return null;
    final leap = DevelopmentLeapsService.current(birthDate: birthDate);
    if (leap == null) return null;

    final name = babyName.trim().isEmpty ? strings.baby : babyName.trim();
    final bk = leap.bannerKey;
    final lead = strings
        .developmentLeapBannerLead(bk)
        .replaceAll('{baby_name}', name)
        .trim();
    final emotion = strings.developmentLeapBannerEmotion(bk).trim();
    if (lead.isEmpty && emotion.isEmpty) return null;

    final buffer = StringBuffer(strings.aiBubbleCuriosityTitle);
    buffer.writeln();
    buffer.writeln();
    if (lead.isNotEmpty) buffer.writeln(lead);
    if (emotion.isNotEmpty) {
      if (lead.isNotEmpty) buffer.writeln();
      buffer.write(emotion);
    }
    return buffer.toString().trim();
  }
}
