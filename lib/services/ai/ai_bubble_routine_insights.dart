import '../../i18n/app_i18n.dart';

import '../development_leaps_service.dart';

import '../home_yesterday_baba_service.dart';



/// Texto único do balão diário: ontem + hoje + curiosidade do salto.

abstract final class AiBubbleRoutineInsights {

  AiBubbleRoutineInsights._();



  /// Legado — substituído por [unifiedPrefsKey].

  static const legacyPrefsKey = 'yesterday_curiosity_brief';



  static const unifiedPrefsKey = 'daily_brief_unified';



  static String? get prefsKey => unifiedPrefsKey;



  static Future<String?> buildUnifiedDailyBrief({

    required int? babyId,

    required String babyName,

    required String? babySex,

    required DateTime? birthDate,

    required S strings,

    required String todayDailyText,

  }) async {

    final buffer = StringBuffer();

    buffer.writeln(strings.aiBubbleDailyBriefTitle);

    buffer.writeln();



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



    final todayTrimmed = todayDailyText.trim();

    if (todayTrimmed.isNotEmpty) {

      if (buffer.length > strings.aiBubbleDailyBriefTitle.length + 2) {

        buffer.writeln();

        buffer.writeln();

      }

      buffer.writeln(strings.homeAiInsightDailyTitle);

      buffer.writeln();

      buffer.writeln(todayTrimmed);

    }



    final curiosity = _developmentCuriositySection(

      babyName: babyName,

      birthDate: birthDate,

      strings: strings,

    );

    if (curiosity != null) {

      buffer.writeln();

      buffer.writeln();

      buffer.write(curiosity);

    }



    if (buffer.length <= strings.aiBubbleDailyBriefTitle.length + 4 &&

        babyId != null) {

      final name = babyName.trim().isEmpty ? strings.baby : babyName.trim();

      buffer

        ..writeln(strings.homeYesterdayBabaTitle)

        ..writeln()

        ..writeln(strings.homeYesterdayBabaFallback(name));

    }



    final text = buffer.toString().trim();

    return text.isEmpty ? null : text;

  }



  @Deprecated('Use buildUnifiedDailyBrief')

  static Future<String?> yesterdayAndCuriosity({

    required int? babyId,

    required String babyName,

    required String? babySex,

    required DateTime? birthDate,

    required S strings,

  }) =>

      buildUnifiedDailyBrief(

        babyId: babyId,

        babyName: babyName,

        babySex: babySex,

        birthDate: birthDate,

        strings: strings,

        todayDailyText: '',

      );



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


