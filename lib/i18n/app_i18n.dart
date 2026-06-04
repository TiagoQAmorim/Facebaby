import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory_badge.dart';
import '../services/firebase/auth_registration_exception.dart';
import '../services/firebase/email_verification_policy.dart';
import '../utils/zodiac_element.dart';
import '../utils/zodiac_keys.dart';
import 'ai_family_growth_locale_extras.dart';
import 'development_leaps_translated.dart';

// Common languages across Play Store / App Store audiences.
// (PT/EN/ES/FR/DE/IT no seletor; hi/id/ru/tr/ja/ko/zh mantidos no enum por dados legados.)
enum AppLang { pt, en, es, fr, de, it, hi, id, ja, ko, ru, tr, zh }

/// Idiomas não mostrados em Definições › Idioma (strings nas maps mantêm-se).
const Set<AppLang> kAppLangHiddenFromPicker = {
  AppLang.hi,
  AppLang.id,
  AppLang.ru,
  AppLang.tr,
  AppLang.ja,
  AppLang.ko,
  AppLang.zh,
};

class AppLanguageController extends ChangeNotifier {
  static const _prefKey = 'facebaby_app_lang_v1';

  AppLang _lang;

  AppLanguageController([this._lang = AppLang.pt]);

  AppLang get lang => _lang;

  /// Idioma inicial: preferência guardada ou idioma do sistema ([Locale] do dispositivo).
  /// IP/geo não é usado (exigiria servidor e não reflete preferência do utilizador).
  Future<void> loadInitialLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      for (final v in AppLang.values) {
        if (v.name == saved) {
          final use = kAppLangHiddenFromPicker.contains(v) ? AppLang.en : v;
          if (_lang != use) {
            _lang = use;
            notifyListeners();
          }
          if (use != v) {
            unawaited(_persistLang());
          }
          return;
        }
      }
    }
    final loc = WidgetsBinding.instance.platformDispatcher.locale;
    final resolved = appLangFromDeviceLocale(loc);
    if (_lang != resolved) {
      _lang = resolved;
      notifyListeners();
    }
  }

  static AppLang appLangFromDeviceLocale(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    final AppLang resolved = switch (code) {
      'pt' => AppLang.pt,
      'en' => AppLang.en,
      'es' => AppLang.es,
      'fr' => AppLang.fr,
      'de' => AppLang.de,
      'it' => AppLang.it,
      'hi' => AppLang.hi,
      'id' => AppLang.id,
      'ja' => AppLang.ja,
      'ko' => AppLang.ko,
      'ru' => AppLang.ru,
      'tr' => AppLang.tr,
      'zh' || 'cmn' => AppLang.zh,
      _ => AppLang.en,
    };
    return kAppLangHiddenFromPicker.contains(resolved) ? AppLang.en : resolved;
  }

  Locale get locale {
    switch (_lang) {
      case AppLang.pt:
        return const Locale('pt', 'BR');
      case AppLang.en:
        return const Locale('en', 'US');
      case AppLang.es:
        return const Locale('es', 'ES');
      case AppLang.fr:
        return const Locale('fr', 'FR');
      case AppLang.de:
        return const Locale('de', 'DE');
      case AppLang.it:
        return const Locale('it', 'IT');
      case AppLang.hi:
        return const Locale('hi', 'IN');
      case AppLang.id:
        return const Locale('id', 'ID');
      case AppLang.ja:
        return const Locale('ja', 'JP');
      case AppLang.ko:
        return const Locale('ko', 'KR');
      case AppLang.ru:
        return const Locale('ru', 'RU');
      case AppLang.tr:
        return const Locale('tr', 'TR');
      case AppLang.zh:
        return const Locale('zh', 'CN');
    }
  }

  void setLang(AppLang lang) {
    final use = kAppLangHiddenFromPicker.contains(lang) ? AppLang.en : lang;
    if (_lang == use) return;
    _lang = use;
    notifyListeners();
    unawaited(_persistLang());
  }

  Future<void> _persistLang() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _lang.name);
  }
}

class AppI18nScope extends InheritedNotifier<AppLanguageController> {
  const AppI18nScope(
      {super.key, required super.notifier, required super.child});

  static AppLanguageController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppI18nScope>();
    assert(scope != null, 'AppI18nScope not found in widget tree');
    return scope!.notifier!;
  }
}

List<String> _splitLeapLines(String raw) =>
    raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

class S {
  final AppLang lang;

  const S(this.lang);

  static S of(BuildContext context) => S(AppI18nScope.of(context).lang);

  static bool _isMaleBabySex(String? sex) {
    final sx = sex?.trim().toUpperCase();
    return sx == 'M' ||
        sx == 'MALE' ||
        sx == 'BOY' ||
        sx == 'MASCULINO' ||
        sx == 'MENINO';
  }

  String get appName => _t('appName');
  String get home => _t('home');
  String get records => _t('records');
  String get reports => _t('reports');
  String get memories => _t('memories');
  String get more => _t('more');

  String get helloMom => _t('helloMom');
  String get today => _t('today');
  String get shortcuts => _t('shortcuts');
  String get registerNow => _t('registerNow');
  String get edit => _t('edit');
  String get delete => _t('delete');
  String get cancel => _t('cancel');
  String get confirmDelete => _t('confirmDelete');
  String get deletedOk => _t('deletedOk');
  String get deleteFail => _t('deleteFail');
  String get todaySummary => _t('todaySummary');
  String get nextEvents => _t('nextEvents');

  String get quickRecordsTitle => _t('quickRecordsTitle');
  String get quickRecordsSubtitle => _t('quickRecordsSubtitle');
  String get feedingAlertsSwitchTitle => _t('feedingAlertsSwitchTitle');
  String get feedingAlertsSwitchSubtitle => _t('feedingAlertsSwitchSubtitle');
  String feedingAlertsIntervalCaption(int minutes) =>
      _t('feedingAlertsIntervalCaption').replaceAll('{m}', '$minutes');
  String get feedingAlertsShortcutTitle => _t('feedingAlertsShortcutTitle');
  String get scheduledFeedingReminderBody => _t('scheduledFeedingReminderBody');
  String get scheduledDiaperReminderTitle => _t('scheduledDiaperReminderTitle');
  String get scheduledDiaperReminderBody => _t('scheduledDiaperReminderBody');
  String get whatHappenedNow => _t('whatHappenedNow');
  String get momNote => _t('momNote');
  String get saveRecord => _t('saveRecord');

  String get reportsTitle => _t('reportsTitle');
  String get reportsSubtitle => _t('reportsSubtitle');
  String get reportsHubAnchorLabel => _t('reportsHubAnchorLabel');
  String get reportsHubPickDayTooltip => _t('reportsHubPickDayTooltip');
  String get reportsHubSectionTitle => _t('reportsHubSectionTitle');
  String get reportStubComingSoon => _t('reportStubComingSoon');
  String get reportListDaily => _t('reportListDaily');
  String get reportListDailySub => _t('reportListDailySub');
  String get reportListWeekly => _t('reportListWeekly');
  String get reportListWeeklySub => _t('reportListWeeklySub');
  String get reportListMonthly => _t('reportListMonthly');
  String get reportListMonthlySub => _t('reportListMonthlySub');
  String get reportListSleepAdv => _t('reportListSleepAdv');
  String get reportListSleepAdvSub => _t('reportListSleepAdvSub');
  String get reportListPediatric => _t('reportListPediatric');
  String get reportListPediatricSub => _t('reportListPediatricSub');
  String get reportListDevelopment => _t('reportListDevelopment');
  String get reportListDevelopmentSub => _t('reportListDevelopmentSub');

  String get plusBrandTitle => _t('plusBrandTitle');
  String get plusSheetHero => _t('plusSheetHero');
  String get plusSheetPriceLabel => _t('plusSheetPriceLabel');
  String get plusSheetBullets => _t('plusSheetBullets');
  String get plusCtaSubscribe => _t('plusCtaSubscribe');
  String get plusCtaRestore => _t('plusCtaRestore');
  String get plusCtaLater => _t('plusCtaLater');
  String get plusSheetFootnote => _t('plusSheetFootnote');
  String get plusWelcomeSnack => _t('plusWelcomeSnack');
  String get plusPurchaseUnavailableSnack => _t('plusPurchaseUnavailableSnack');
  String plusPurchaseSkuNotFoundSnack(String productId) =>
      _t('plusPurchaseSkuNotFoundSnack').replaceAll('{id}', productId);
  String get plusPurchaseBillingLaunchFailedSnack =>
      _t('plusPurchaseBillingLaunchFailedSnack');
  String get plusPurchaseAlreadyInPlayAccountSnack =>
      _t('plusPurchaseAlreadyInPlayAccountSnack');
  String plusPaywallSkuMissingHint(String productId) =>
      _t('plusPaywallSkuMissingHint').replaceAll('{id}', productId);
  String get plusRestoreOkSnack => _t('plusRestoreOkSnack');
  String get plusRestoreEmptySnack => _t('plusRestoreEmptySnack');
  String get plusSnackLockedFeature => _t('plusSnackLockedFeature');
  String get plusMemoryLimitSnack => _t('plusMemoryLimitSnack');
  String get plusMemoryLimitDialogTitle => _t('plusMemoryLimitDialogTitle');
  String get plusMemoryLimitDialogBody => _t('plusMemoryLimitDialogBody');
  String get plusMemoryLimitDialogSubscribe =>
      _t('plusMemoryLimitDialogSubscribe');
  String get plusReportsLockedHint => _t('plusReportsLockedHint');
  String get plusReportsPremiumTagline => _t('plusReportsPremiumTagline');
  String get plusReportsPremiumCta => _t('plusReportsPremiumCta');
  String get plusExportLockedHint => _t('plusExportLockedHint');
  String get settingsPlusCardTitle => _t('settingsPlusCardTitle');
  String get settingsPlusCardBodyFree => _t('settingsPlusCardBodyFree');
  String get settingsPlusCardBodyActive => _t('settingsPlusCardBodyActive');
  String get settingsPlusUpgradeCta => _t('settingsPlusUpgradeCta');
  String get settingsPlusManageCta => _t('settingsPlusManageCta');
  String plusMemoryCounterFree(int filled, int max) =>
      _t('plusMemoryCounterFree')
          .replaceAll('{n}', '$filled')
          .replaceAll('{max}', '$max');

  String get plusLifetimePaymentBadge => _t('plusLifetimePaymentBadge');
  String get plusNoMonthlyBadge => _t('plusNoMonthlyBadge');
  String get plusPremiumActiveTitle => _t('plusPremiumActiveTitle');
  String get plusPremiumActiveBody => _t('plusPremiumActiveBody');
  String get plusPurchaseErrorSnack => _t('plusPurchaseErrorSnack');
  String get plusDoneClose => _t('plusDoneClose');
  String get plusPaywallHeadline => _t('plusPaywallHeadline');
  String get plusPaywallActiveNote => _t('plusPaywallActiveNote');
  String get plusPaywallSecureNote => _t('plusPaywallRenewalNote');
  String get plusPaywallRenewalNote => _t('plusPaywallRenewalNote');
  String get plusPlanPremiumTitle => _t('plusPlanMonthlyCardTitle');
  String get plusPlanPremiumSubtitle => _t('plusPlanMonthlySubtitle');
  String get plusEarlyAdopterOffer => _t('plusEarlyAdopterOffer');
  String get plusPopularBadge => _t('plusPopularBadge');
  String get plusPlanAnnualTitle => _t('plusPlanAnnualCardTitle');
  String get plusPlanMonthlyTitle => _t('plusPlanMonthlyCardTitle');
  String get plusPlanMonthlyCardTitle => _t('plusPlanMonthlyCardTitle');
  String get plusPlanAnnualCardTitle => _t('plusPlanAnnualCardTitle');
  String get plusPlanMonthlySubtitle => _t('plusPlanMonthlySubtitle');
  String get plusPlanAnnualSubtitle => _t('plusPlanAnnualSubtitle');
  String get plusPlanPremiumBadge => _t('plusPopularBadge');
  String get plusPlanPremiumPriceSubActive =>
      _t('plusPlanPremiumButtonActive');
  String get plusPlanPremiumPriceSubSecure => _t('plusPaywallRenewalNote');
  String get plusPlanPremiumButtonActive => _t('plusPlanPremiumButtonActive');
  String get plusPlanPremiumButton => _t('plusCtaSubscribeMonthly');
  String plusAnnualSavings({int? percent, String? amount}) =>
      plusAnnualSavingsAmountLine(amount ?? '');
  String plusAnnualSavingsAmountLine(String amount) =>
      _t('plusAnnualSavingsAmountLine').replaceAll('{amount}', amount);
  String get plusAnnualPerMonthHint => _t('plusAnnualPerMonthHint');
  String get plusCtaSubscribePlus => _t('plusCtaSubscribeMonthly');
  String get plusCtaSubscribeMonthly => _t('plusCtaSubscribeMonthly');
  String get plusCtaSubscribeAnnual => _t('plusCtaSubscribeAnnual');
  List<String> get plusPlanPremiumFeatures => plusPlanMonthlyFeatures;
  List<String> get plusPlanMonthlyFeatures => [
        _t('plusPlanMonthlyFeature1'),
        _t('plusPlanMonthlyFeature2'),
        _t('plusPlanMonthlyFeature3'),
        _t('plusPlanMonthlyFeature4'),
        _t('plusPlanMonthlyFeature5'),
        _t('plusPlanMonthlyFeature6'),
        _t('plusPlanMonthlyFeature7'),
        _t('plusPlanMonthlyFeature8'),
        _t('plusPlanMonthlyFeature9'),
        _t('plusPlanMonthlyFeature10'),
        _t('plusPlanMonthlyFeature11'),
        _t('plusPlanMonthlyFeature12'),
        _t('plusPlanMonthlyFeature13'),
        _t('plusPlanMonthlyFeature14'),
        _t('plusPlanMonthlyFeature15'),
        _t('plusPlanMonthlyFeature16'),
        _t('plusPlanMonthlyFeature17'),
        _t('plusPlanMonthlyFeature18'),
      ];
  List<String> get plusPlanAnnualFeatures => [
        _t('plusPlanAnnualFeature1'),
        _t('plusPlanAnnualFeature2'),
        _t('plusPlanAnnualFeature3'),
      ];
  String get plusPlanAiTitle => _t('plusPlanAiTitle');
  String get plusPlanAiSubtitle => _t('plusPlanAiSubtitle');
  String get plusPlanAiBadge => _t('plusPlanAiBadge');
  String get plusPlanAiPrice => _t('plusPlanAiPrice');
  String get plusPlanAiPriceSub => _t('plusPlanAiPriceSub');
  String get plusPlanAiButton => _t('plusPlanAiButton');
  List<String> get plusPlanAiFeatures => [
        _t('plusPlanAiFeature1'),
        _t('plusPlanAiFeature2'),
        _t('plusPlanAiFeature3'),
        _t('plusPlanAiFeature4'),
        _t('plusPlanAiFeature5'),
        _t('plusPlanAiFeature6'),
        _t('plusPlanAiFeature7'),
      ];
  String get plusPlanFreeTitle => _t('plusPlanFreeTitle');
  String get plusPlanFreeSubtitle => _t('plusPlanFreeSubtitle');
  String get plusPlanFreePrice => _t('plusPlanFreePrice');
  String get plusPlanCurrent => _t('plusPlanCurrent');
  List<String> get plusPlanFreeFeatures => [
        _t('plusPlanFreeFeature1'),
        _t('plusPlanFreeFeature2'),
        _t('plusPlanFreeFeature3'),
        _t('plusPlanFreeFeature4'),
        _t('plusPlanFreeFeature5'),
        _t('plusPlanFreeFeature6'),
      ];
  List<String> get plusTrustStripItems => [
        _t('plusTrustData'),
        _t('plusTrustFamily'),
        _t('plusTrustContent'),
        _t('plusTrustSupport'),
      ];

  String get reportDailyScreenTitle => _t('reportDailyScreenTitle');
  String get reportDayDetailsTitle => _t('reportDayDetailsTitle');
  String get reportDailyPickDayTooltip => _t('reportDailyPickDayTooltip');
  String get reportDailySubtitleSleepQuality =>
      _t('reportDailySubtitleSleepQuality');
  String get reportDailySubtitleTotalSleep =>
      _t('reportDailySubtitleTotalSleep');
  String get reportDailySubtitleLongestStretch =>
      _t('reportDailySubtitleLongestStretch');
  String get reportDailySubtitleFeedTotal => _t('reportDailySubtitleFeedTotal');
  String get reportDailySubtitleFeedAvg => _t('reportDailySubtitleFeedAvg');
  String get reportDailySubtitleFeedLast => _t('reportDailySubtitleFeedLast');
  String get reportDailySubtitleDiaperTotal =>
      _t('reportDailySubtitleDiaperTotal');
  String get reportDailySubtitleDiaperWet => _t('reportDailySubtitleDiaperWet');
  String get reportDailySubtitleDiaperDirty =>
      _t('reportDailySubtitleDiaperDirty');
  String get reportDailySubtitleMoodMajority =>
      _t('reportDailySubtitleMoodMajority');
  String get reportDailySubtitleMoodIrrit => _t('reportDailySubtitleMoodIrrit');
  String get reportDailySubtitleWeightLast =>
      _t('reportDailySubtitleWeightLast');
  String get reportSleepQualityGood => _t('reportSleepQualityGood');
  String get reportSleepQualityOk => _t('reportSleepQualityOk');
  String get reportSleepQualityBad => _t('reportSleepQualityBad');
  String get reportSleepQualityMixed => _t('reportSleepQualityMixed');
  String get reportVsYesterdayShort => _t('reportVsYesterdayShort');
  String get reportVsYesterdayNA => _t('reportVsYesterdayNA');
  String reportVsYesterdayPct(String pct) =>
      _t('reportVsYesterdayPct').replaceAll('{pct}', pct);
  String get reportLongestStretchHint => _t('reportLongestStretchHint');
  String get reportNapsLabel => _t('reportNapsLabel');
  String get reportTotalSmallLabel => _t('reportTotalSmallLabel');
  String get reportComparedAgeLabel => _t('reportComparedAgeLabel');
  String get reportBenchmarkAbove => _t('reportBenchmarkAbove');
  String get reportBenchmarkNear => _t('reportBenchmarkNear');
  String get reportBenchmarkBelow => _t('reportBenchmarkBelow');
  String get reportIrritLow => _t('reportIrritLow');
  String get reportIrritMedium => _t('reportIrritMedium');
  String get reportIrritHigh => _t('reportIrritHigh');
  String get reportIrritUnknown => _t('reportIrritUnknown');
  String get reportTabSleep => _t('reportTabSleep');
  String get reportTabFeedings => _t('reportTabFeedings');
  String get reportTabDiapers => _t('reportTabDiapers');
  String get reportTabMood => _t('reportTabMood');
  String get reportAiInsightsTitle => _t('reportAiInsightsTitle');
  String get reportTimelineTitle => _t('reportTimelineTitle');
  String get reportShareSoon => _t('reportShareSoon');
  String get reportFeedingChartCaption => _t('reportFeedingChartCaption');
  String get reportSleepChartCaption => _t('reportSleepChartCaption');
  String get reportNoDataHint => _t('reportNoDataHint');
  String get reportInsightSleepAgeGood => _t('reportInsightSleepAgeGood');
  String get reportInsightSleepAgeLow => _t('reportInsightSleepAgeLow');
  String get reportInsightFeedsOften => _t('reportInsightFeedsOften');
  String get reportInsightDiapersFrequent => _t('reportInsightDiapersFrequent');
  String reportInsightMoodLine(String mood) =>
      _t('reportInsightMoodLine').replaceAll('{mood}', mood);

  String get reportWeeklyScreenTitle => _t('reportWeeklyScreenTitle');
  String get reportWeekDetailsTitle => _t('reportWeekDetailsTitle');
  String get reportWeeklyPickWeekTooltip => _t('reportWeeklyPickWeekTooltip');
  String get reportWeeklySummaryTitle => _t('reportWeeklySummaryTitle');
  String get reportWeeklyTrendsTitle => _t('reportWeeklyTrendsTitle');
  String get reportWeeklySeeFullDetails => _t('reportWeeklySeeFullDetails');
  String reportWeeklyPartialWeekHint(String weekday) =>
      _t('reportWeeklyPartialWeekHint').replaceAll('{weekday}', weekday);
  String get reportWeeklyFutureWeekHint => _t('reportWeeklyFutureWeekHint');
  String get reportWeeklyLoadErrorPrefix => _t('reportWeeklyLoadErrorPrefix');
  String get reportWeeklyToneCalm => _t('reportWeeklyToneCalm');
  String get reportWeeklyToneActive => _t('reportWeeklyToneActive');
  String get reportWeeklySleepUnknown => _t('reportWeeklySleepUnknown');
  String get reportWeeklyFirstWeekSleepLine =>
      _t('reportWeeklyFirstWeekSleepLine');
  String get reportWeeklySleepStableShort => _t('reportWeeklySleepStableShort');
  String reportWeeklySleepUp(int pct) =>
      _t('reportWeeklySleepUp').replaceAll('{pct}', '$pct');
  String reportWeeklySleepDown(int pct) =>
      _t('reportWeeklySleepDown').replaceAll('{pct}', '$pct');
  String get reportWeeklyFeedStableLine => _t('reportWeeklyFeedStableLine');
  String reportWeeklyFeedUp(int pct) =>
      _t('reportWeeklyFeedUp').replaceAll('{pct}', '$pct');
  String reportWeeklyFeedDown(int pct) =>
      _t('reportWeeklyFeedDown').replaceAll('{pct}', '$pct');
  String reportWeeklyHeroTemplate(
          String name, String tone, String sleep, String feed) =>
      _t('reportWeeklyHeroTemplate')
          .replaceAll('{name}', name)
          .replaceAll('{tone}', tone)
          .replaceAll('{sleep}', sleep)
          .replaceAll('{feed}', feed);
  String get reportWeeklyTrendLabelImproved =>
      _t('reportWeeklyTrendLabelImproved');
  String get reportWeeklyTrendLabelWorse => _t('reportWeeklyTrendLabelWorse');
  String get reportWeeklyTrendLabelStable => _t('reportWeeklyTrendLabelStable');
  String get reportWeeklyTrendLabelUnknown =>
      _t('reportWeeklyTrendLabelUnknown');
  String get reportWeeklyTrendLabelEvolving =>
      _t('reportWeeklyTrendLabelEvolving');
  String get reportWeeklyTrendLabelIncreased =>
      _t('reportWeeklyTrendLabelIncreased');
  String get reportWeeklyTrendNA => _t('reportWeeklyTrendNA');
  String get reportWeeklyHighlightSleep => _t('reportWeeklyHighlightSleep');
  String get reportWeeklyHighlightFeedingStable =>
      _t('reportWeeklyHighlightFeedingStable');
  String get reportWeeklyHighlightDiaperUp =>
      _t('reportWeeklyHighlightDiaperUp');
  String get reportWeeklyHighlightWeight => _t('reportWeeklyHighlightWeight');
  String get reportWeeklyHighlightGeneric => _t('reportWeeklyHighlightGeneric');
  String reportWeeklyAvgFeedsDay(String avg) =>
      _t('reportWeeklyAvgFeedsDay').replaceAll('{avg}', avg);
  String reportWeeklyAvgDiapersDay(String avg) =>
      _t('reportWeeklyAvgDiapersDay').replaceAll('{avg}', avg);
  String get reportWeeklySleepHoursChartTitle =>
      _t('reportWeeklySleepHoursChartTitle');
  String get reportWeeklyAvgWeekLabel => _t('reportWeeklyAvgWeekLabel');
  String get reportWeeklyVsPrevWeekShort => _t('reportWeeklyVsPrevWeekShort');
  String get reportWeeklyInsightsCardTitle =>
      _t('reportWeeklyInsightsCardTitle');
  String get reportWeeklyPatternsTitle => _t('reportWeeklyPatternsTitle');
  String get reportWeeklySeeAllAnalyses => _t('reportWeeklySeeAllAnalyses');
  String get reportWeeklyHeatmapSoon => _t('reportWeeklyHeatmapSoon');
  String get reportWeeklyFeedChartCaption => _t('reportWeeklyFeedChartCaption');
  String get reportWeeklyDiaperChartCaption =>
      _t('reportWeeklyDiaperChartCaption');
  String get reportWeeklyPatternWeekend => _t('reportWeeklyPatternWeekend');
  String get reportWeeklyPatternFeedingDown =>
      _t('reportWeeklyPatternFeedingDown');
  String get reportWeeklyPatternDefault => _t('reportWeeklyPatternDefault');
  String get reportWeeklyInsightSleepNeutral =>
      _t('reportWeeklyInsightSleepNeutral');
  String get reportWeeklyInsightSleepBetter =>
      _t('reportWeeklyInsightSleepBetter');
  String get reportWeeklyInsightSleepLess => _t('reportWeeklyInsightSleepLess');
  String reportWeeklyInsightTemplate(String name, String sleep) =>
      _t('reportWeeklyInsightTemplate')
          .replaceAll('{name}', name)
          .replaceAll('{sleep}', sleep);

  String get reportMonthlyScreenTitle => _t('reportMonthlyScreenTitle');
  String get reportMonthlyAvgWeight => _t('reportMonthlyAvgWeight');
  String get reportMonthlyAvgHeight => _t('reportMonthlyAvgHeight');
  String get reportMonthlyGrowthChartEmpty =>
      _t('reportMonthlyGrowthChartEmpty');
  String get reportMonthlySleepSection => _t('reportMonthlySleepSection');
  String get reportMonthlySleepAvg => _t('reportMonthlySleepAvg');
  String get reportMonthlyVsPrevMonth => _t('reportMonthlyVsPrevMonth');
  String get reportMonthlyBestWeeks => _t('reportMonthlyBestWeeks');
  String get reportMonthlySleepTrendUp => _t('reportMonthlySleepTrendUp');
  String get reportMonthlySleepTrendDown => _t('reportMonthlySleepTrendDown');
  String get reportMonthlySleepTrendStable =>
      _t('reportMonthlySleepTrendStable');
  String get reportMonthlySleepTrendUnknown =>
      _t('reportMonthlySleepTrendUnknown');
  String get reportMonthlyFeedingSection => _t('reportMonthlyFeedingSection');
  String get reportMonthlyFeedFreq => _t('reportMonthlyFeedFreq');
  String get reportMonthlySleepExplain => _t('reportMonthlySleepExplain');
  String get reportMonthlyFeedingExplain => _t('reportMonthlyFeedingExplain');
  String get reportMonthlyPredominantHours =>
      _t('reportMonthlyPredominantHours');
  String get reportMonthlyMilestonesTitle => _t('reportMonthlyMilestonesTitle');
  String get reportMonthlyMilestonesEmpty => _t('reportMonthlyMilestonesEmpty');
  String get reportMonthlyMilestoneConsultationDefault =>
      _t('reportMonthlyMilestoneConsultationDefault');
  String get reportMonthlyMemoriesTitle => _t('reportMonthlyMemoriesTitle');
  String get homeRecentMemoriesTitle => _t('homeRecentMemoriesTitle');
  String get reportMonthlySeeAllMemories => _t('reportMonthlySeeAllMemories');
  String get reportMonthlyMemoriesEmpty => _t('reportMonthlyMemoriesEmpty');
  String get reportMonthlyVideosHint => _t('reportMonthlyVideosHint');

  String get reportSleepAdvScreenTitle => _t('reportSleepAdvScreenTitle');
  String get reportSleepAdvScoreTitle => _t('reportSleepAdvScoreTitle');
  String get reportSleepAdvMetricsTitle => _t('reportSleepAdvMetricsTitle');
  String get reportSleepAdvEfficiency => _t('reportSleepAdvEfficiency');
  String reportSleepAdvVsPrevPct(int pct) => _t('reportSleepAdvVsPrevPct')
      .replaceAll('{pct}', pct >= 0 ? '+$pct' : '$pct');
  String get reportSleepAdvOnset => _t('reportSleepAdvOnset');
  String get reportSleepAdvAwakenings => _t('reportSleepAdvAwakenings');
  String reportSleepAdvAwakeningsTotal(int n) =>
      _t('reportSleepAdvAwakeningsTotal').replaceAll('{n}', '$n');
  String get reportSleepAdvLongest => _t('reportSleepAdvLongest');
  String get reportSleepAdvAvgDailySleep => _t('reportSleepAdvAvgDailySleep');
  String get reportSleepAdvIdealTitle => _t('reportSleepAdvIdealTitle');
  String get reportSleepAdvIdealFooter => _t('reportSleepAdvIdealFooter');
  String get reportSleepAdvSeeFullAnalysis =>
      _t('reportSleepAdvSeeFullAnalysis');
  String get reportSleepAdvChartsSection => _t('reportSleepAdvChartsSection');
  String get reportSleepAdvChartsSleepTrend =>
      _t('reportSleepAdvChartsSleepTrend');
  String get reportSleepAdvChartsCompare => _t('reportSleepAdvChartsCompare');
  String get reportSleepAdvChartsDistribution =>
      _t('reportSleepAdvChartsDistribution');
  String get reportSleepAdvChartsBars => _t('reportSleepAdvChartsBars');
  String get reportSleepAdvDayPhase => _t('reportSleepAdvDayPhase');
  String get reportSleepAdvNightPhase => _t('reportSleepAdvNightPhase');
  String get reportSleepAdvDistributionEmpty =>
      _t('reportSleepAdvDistributionEmpty');
  String get reportSleepAdvLegendThisWeek => _t('reportSleepAdvLegendThisWeek');
  String get reportSleepAdvLegendPrevWeek => _t('reportSleepAdvLegendPrevWeek');
  String get reportSleepAdvScoreBreakdown => _t('reportSleepAdvScoreBreakdown');
  String reportSleepAdvBreakdownLine(int e, int s, int a, int c) =>
      _t('reportSleepAdvBreakdownLine')
          .replaceAll('{e}', '$e')
          .replaceAll('{s}', '$s')
          .replaceAll('{a}', '$a')
          .replaceAll('{c}', '$c');
  String get reportSleepAdvNotEnoughData => _t('reportSleepAdvNotEnoughData');
  String get reportSleepAdvStatusExcellent =>
      _t('reportSleepAdvStatusExcellent');
  String get reportSleepAdvStatusGood => _t('reportSleepAdvStatusGood');
  String get reportSleepAdvStatusRegular => _t('reportSleepAdvStatusRegular');
  String get reportSleepAdvStatusPoor => _t('reportSleepAdvStatusPoor');
  String get reportSleepAdvBadgeVeryGood => _t('reportSleepAdvBadgeVeryGood');
  String get reportSleepAdvBadgeGood => _t('reportSleepAdvBadgeGood');
  String get reportSleepAdvBadgeOk => _t('reportSleepAdvBadgeOk');
  String get reportSleepAdvBadgeAttention => _t('reportSleepAdvBadgeAttention');
  String get reportSleepAdvBadgeIdeal => _t('reportSleepAdvBadgeIdeal');
  String get reportSleepAdvBadgeUnknown => _t('reportSleepAdvBadgeUnknown');
  String get reportSleepAdvBadgeLow => _t('reportSleepAdvBadgeLow');
  String get reportSleepAdvBadgeModerate => _t('reportSleepAdvBadgeModerate');
  String get reportSleepAdvBadgeHigh => _t('reportSleepAdvBadgeHigh');

  String get reportPediatricScreenTitle => _t('reportPediatricScreenTitle');
  String get reportPediatricPeriodPrefix => _t('reportPediatricPeriodPrefix');
  String get reportPediatricFilterHint => _t('reportPediatricFilterHint');
  String get reportPediatricDateFrom => _t('reportPediatricDateFrom');
  String get reportPediatricDateTo => _t('reportPediatricDateTo');
  String get reportPediatricPickRange => _t('reportPediatricPickRange');
  String get reportPediatricFilterMaxDaysHint =>
      _t('reportPediatricFilterMaxDaysHint');
  String get reportPediatricSectionGeneral =>
      _t('reportPediatricSectionGeneral');
  String get reportPediatricSectionSummary =>
      _t('reportPediatricSectionSummary');
  String get reportPediatricSectionSleep => _t('reportPediatricSectionSleep');
  String get reportPediatricSectionFeeding =>
      _t('reportPediatricSectionFeeding');
  String get reportPediatricSectionSymptoms =>
      _t('reportPediatricSectionSymptoms');
  String get reportPediatricSectionObservations =>
      _t('reportPediatricSectionObservations');
  String get reportPediatricLabelName => _t('reportPediatricLabelName');
  String get reportPediatricLabelAge => _t('reportPediatricLabelAge');
  String get reportPediatricLabelBirth => _t('reportPediatricLabelBirth');
  String get reportPediatricLabelWeightCurrent =>
      _t('reportPediatricLabelWeightCurrent');
  String get reportPediatricLabelHeight => _t('reportPediatricLabelHeight');
  String get reportPediatricWeightStart => _t('reportPediatricWeightStart');
  String get reportPediatricWeightEnd => _t('reportPediatricWeightEnd');
  String get reportPediatricWeightGain => _t('reportPediatricWeightGain');
  String get reportPediatricHeightStart => _t('reportPediatricHeightStart');
  String get reportPediatricHeightEnd => _t('reportPediatricHeightEnd');
  String get reportPediatricHeightGain => _t('reportPediatricHeightGain');
  String get reportPediatricAvgFeeds => _t('reportPediatricAvgFeeds');
  String get reportPediatricAvgSleep => _t('reportPediatricAvgSleep');
  String get reportPediatricAvgDiapers => _t('reportPediatricAvgDiapers');
  String get reportPediatricFeverEpisodes => _t('reportPediatricFeverEpisodes');
  String get reportPediatricFeverNote => _t('reportPediatricFeverNote');
  String get reportPediatricFeverFootnote => _t('reportPediatricFeverFootnote');
  String get reportPediatricVaccines => _t('reportPediatricVaccines');
  String get reportPediatricMedications => _t('reportPediatricMedications');
  String get reportPediatricSleepAvgDaily => _t('reportPediatricSleepAvgDaily');
  String get reportPediatricSleepAwakenings =>
      _t('reportPediatricSleepAwakenings');
  String get reportPediatricSleepPattern => _t('reportPediatricSleepPattern');
  String get reportPediatricSleepPatternStable =>
      _t('reportPediatricSleepPatternStable');
  String get reportPediatricSleepPatternModerate =>
      _t('reportPediatricSleepPatternModerate');
  String get reportPediatricSleepPatternFragmented =>
      _t('reportPediatricSleepPatternFragmented');
  String get reportPediatricSleepLongest => _t('reportPediatricSleepLongest');
  String get reportPediatricFeedingBreast => _t('reportPediatricFeedingBreast');
  String get reportPediatricFeedingFormula =>
      _t('reportPediatricFeedingFormula');
  String get reportPediatricFeedingSolid => _t('reportPediatricFeedingSolid');
  String get reportPediatricFeedingSessions =>
      _t('reportPediatricFeedingSessions');
  String get reportPediatricFeedingAvgDur => _t('reportPediatricFeedingAvgDur');
  String get reportPediatricSymptomReflux => _t('reportPediatricSymptomReflux');
  String get reportPediatricSymptomColic => _t('reportPediatricSymptomColic');
  String get reportPediatricSymptomIrrit => _t('reportPediatricSymptomIrrit');
  String get reportPediatricSymptomCrying => _t('reportPediatricSymptomCrying');
  String get reportPediatricSymptomPain => _t('reportPediatricSymptomPain');
  String get reportPediatricSymptomFromJournal =>
      _t('reportPediatricSymptomFromJournal');
  String get reportPediatricStructuredSymptoms =>
      _t('reportPediatricStructuredSymptoms');
  String get reportPediatricStructuredSymptomsEmpty =>
      _t('reportPediatricStructuredSymptomsEmpty');
  String get reportPediatricIrritHigh => _t('reportPediatricIrritHigh');
  String get reportPediatricIrritMedium => _t('reportPediatricIrritMedium');
  String get reportPediatricIrritLow => _t('reportPediatricIrritLow');
  String get reportPediatricIrritUnknown => _t('reportPediatricIrritUnknown');
  String get reportPediatricYes => _t('reportPediatricYes');
  String get reportPediatricNo => _t('reportPediatricNo');
  String get reportPediatricNa => _t('reportPediatricNa');
  String get reportPediatricJournalNote => _t('reportPediatricJournalNote');
  String get reportPediatricJournalNoteHint =>
      _t('reportPediatricJournalNoteHint');
  String get reportPediatricObsHint => _t('reportPediatricObsHint');
  String get reportPediatricBtnShare => _t('reportPediatricBtnShare');
  String get reportPediatricBtnExportPdf => _t('reportPediatricBtnExportPdf');
  String get reportPediatricBtnPrint => _t('reportPediatricBtnPrint');
  String get reportPediatricBtnEmail => _t('reportPediatricBtnEmail');
  String get reportPediatricBtnWhatsApp => _t('reportPediatricBtnWhatsApp');
  String get reportPediatricScreenFootnote =>
      _t('reportPediatricScreenFootnote');
  String get reportPediatricNone => _t('reportPediatricNone');
  String get reportPediatricPdfTitle => _t('reportPediatricPdfTitle');
  String get reportPediatricPdfPeriod => _t('reportPediatricPdfPeriod');
  String get reportPediatricPdfFooter => _t('reportPediatricPdfFooter');
  String get reportPediatricFeverDisclaimerShort =>
      _t('reportPediatricFeverDisclaimerShort');

  String get reportDevScreenTitle => _t('reportDevScreenTitle');
  String get reportDevSubtitle => _t('reportDevSubtitle');
  String get reportDevScoreTitle => _t('reportDevScoreTitle');
  String get reportDevScoreStatusOnTrack => _t('reportDevScoreStatusOnTrack');
  String get reportDevScoreStatusWatch => _t('reportDevScoreStatusWatch');
  String get reportDevScoreStatusEarly => _t('reportDevScoreStatusEarly');
  String get reportDevSectionMotor => _t('reportDevSectionMotor');
  String get reportDevSectionCognitive => _t('reportDevSectionCognitive');
  String get reportDevSectionSocial => _t('reportDevSectionSocial');
  String get reportDevAchieved => _t('reportDevAchieved');
  String get reportDevGrowing => _t('reportDevGrowing');
  String get reportDevInsightTitle => _t('reportDevInsightTitle');
  String get reportDevSeeAllMarcos => _t('reportDevSeeAllMarcos');
  String get reportDevFootnote => _t('reportDevFootnote');
  String get reportDevNeedBirth => _t('reportDevNeedBirth');
  String devReportMilestoneLabel(String id) {
    final k = 'devReport_$id';
    final v = _t(k);
    return v == k ? id : v;
  }

  String get devReportInsightNewborn => _t('devReportInsightNewborn');
  String get devReportInsightOnTrack => _t('devReportInsightOnTrack');
  String get devReportInsightVariety => _t('devReportInsightVariety');
  String get devReportInsightPatience => _t('devReportInsightPatience');
  String get devReportInsightBalanced => _t('devReportInsightBalanced');

  String get growth => _t('growth');
  String get pediatricReport => _t('pediatricReport');
  String get pediatricReportDesc => _t('pediatricReportDesc');
  String get generatePdf => _t('generatePdf');

  String get memoriesTitle => _t('memoriesTitle');
  String get memoriesSubtitle => _t('memoriesSubtitle');
  String memoriesProgressSaved(int filled, int total) =>
      _t('memoriesProgressSaved')
          .replaceAll('{filled}', '$filled')
          .replaceAll('{total}', '$total');
  String memoriesProgressStandardBadges(int count) =>
      _t('memoriesProgressStandardBadges').replaceAll('{count}', '$count');
  String get memoriesCheerEmpty => _t('memoriesCheerEmpty');
  String get memoriesAlbumPromoTitle => _t('memoriesAlbumPromoTitle');
  String get memoriesAlbumPromoSubtitle => _t('memoriesAlbumPromoSubtitle');
  String get memoriesAlbumDownloadCta => _t('memoriesAlbumDownloadCta');
  String get memoriesAlbumGenerating => _t('memoriesAlbumGenerating');
  String get memoriesAlbumNeedFilled => _t('memoriesAlbumNeedFilled');
  String get memoriesAlbumError => _t('memoriesAlbumError');
  String get memoriesAlbumPdfReadyTitle => _t('memoriesAlbumPdfReadyTitle');
  String get memoriesAlbumShareAction => _t('memoriesAlbumShareAction');
  String get memoriesAlbumSaveAction => _t('memoriesAlbumSaveAction');
  String get memoriesAlbumSavedSnack => _t('memoriesAlbumSavedSnack');
  String get memoriesAlbumSaveFailedSnack => _t('memoriesAlbumSaveFailedSnack');
  String get memoriesAlbumCoverMain => _t('memoriesAlbumCoverMain');
  String memoriesAlbumCoverTagline(String name) =>
      _t('memoriesAlbumCoverTagline').replaceAll('{name}', name);
  String get memoriesAlbumFooter => _t('memoriesAlbumFooter');
  String get memoriesAlbumBackCoverBody => _t('memoriesAlbumBackCoverBody');
  String get memoriesAlbumBackCoverFinale => _t('memoriesAlbumBackCoverFinale');
  String get memoriesAlbumQualityTitle => _t('memoriesAlbumQualityTitle');
  String get memoriesAlbumQualityShareTitle =>
      _t('memoriesAlbumQualityShareTitle');
  String get memoriesAlbumQualityShareDesc =>
      _t('memoriesAlbumQualityShareDesc');
  String get memoriesAlbumQualityPrintTitle =>
      _t('memoriesAlbumQualityPrintTitle');
  String get memoriesAlbumQualityPrintDesc =>
      _t('memoriesAlbumQualityPrintDesc');
  String get memoriesAlbumExportTitle => _t('memoriesAlbumExportTitle');
  String get memoriesAlbumProgressPreparing =>
      _t('memoriesAlbumProgressPreparing');
  String memoriesAlbumProgressImages(int current, int total) =>
      _t('memoriesAlbumProgressImages')
          .replaceAll('{current}', '$current')
          .replaceAll('{total}', '$total');
  String memoriesAlbumProgressBuilding(int current, int total) =>
      _t('memoriesAlbumProgressBuilding')
          .replaceAll('{current}', '$current')
          .replaceAll('{total}', '$total');
  String get memoriesAlbumProgressSaving => _t('memoriesAlbumProgressSaving');
  String get memoriesAlbumCancelBtn => _t('memoriesAlbumCancelBtn');
  String get memoriesAlbumCanceled => _t('memoriesAlbumCanceled');
  String get memoriesAlbumErrorNetwork => _t('memoriesAlbumErrorNetwork');
  String get memoriesAlbumErrorStorage => _t('memoriesAlbumErrorStorage');
  String memoriesAlbumSkippedImages(int count) =>
      _t('memoriesAlbumSkippedImages').replaceAll('{count}', '$count');
  String get addMemory => _t('addMemory');
  String get memoryAddBadgeCta => _t('memoryAddBadgeCta');
  String get memoryChooseBadgeTitle => _t('memoryChooseBadgeTitle');
  String get memoryOtherBadgeTitle => _t('memoryOtherBadgeTitle');
  String get memoryOtherBadgeNameLabel => _t('memoryOtherBadgeNameLabel');
  String get memoryOtherBadgeNameHint => _t('memoryOtherBadgeNameHint');
  String get memoryOtherBadgeNameRequired => _t('memoryOtherBadgeNameRequired');
  String get memoryOtherBadgeNameTooLong => _t('memoryOtherBadgeNameTooLong');

  String get memoryBadgeMonthOne => _t('memoryBadgeMonthOne');
  String memoryBadgeMonthsMany(int n) =>
      _t('memoryBadgeMonthsMany').replaceAll('{n}', '$n');
  String get memoryBadgeYearOne => _t('memoryBadgeYearOne');
  String memoryBadgeYearsMany(int n) =>
      _t('memoryBadgeYearsMany').replaceAll('{n}', '$n');

  /// Rótulo curto sob o número nos selos mensais na grelha (ex.: «mes» / «meses»).
  String get memoryBadgeMonthUnitSingular => _t('memoryBadgeMonthUnitSingular');
  String get memoryBadgeMonthUnitPlural => _t('memoryBadgeMonthUnitPlural');

  /// Título do selo no Livro de memórias para o idioma atual.
  String memoryBadgeTitle(MemoryBadge badge) {
    if (badge.isCustom) return badge.title;
    if (badge.isMonthlyBadge && badge.monthNumber != null) {
      final m = badge.monthNumber!;
      return m == 1 ? memoryBadgeMonthOne : memoryBadgeMonthsMany(m);
    }
    if (badge.category == 'birthday' && badge.yearNumber != null) {
      final y = badge.yearNumber!;
      return y == 1 ? memoryBadgeYearOne : memoryBadgeYearsMany(y);
    }
    return _t('badge_${badge.id}');
  }

  String get settingsTitle => _t('settingsTitle');
  String get dailyJournalTitle => _t('dailyJournalTitle');
  String get dailyJournalPickDay => _t('dailyJournalPickDay');
  String dailyJournalOnDate(String date) =>
      _t('dailyJournalOnDate').replaceAll('{d}', date);
  String get dailyJournalHint => _t('dailyJournalHint');
  String get dailyJournalSave => _t('dailyJournalSave');
  String get dailyJournalSaving => _t('dailyJournalSaving');
  String get dailyJournalSaved => _t('dailyJournalSaved');
  String get dailyJournalNoBaby => _t('dailyJournalNoBaby');
  String get registerMotherBaby => _t('registerMotherBaby');
  String get vaccinesCard => _t('vaccinesCard');
  String get language => _t('language');
  String get settingsSoonTitle => _t('settingsSoonTitle');
  String get settingsSoonBadge => _t('settingsSoonBadge');
  String get settingsRateUs => _t('settingsRateUs');
  String get settingsVersion => _t('settingsVersion');
  String get settingsVersionDialogTitle => _t('settingsVersionDialogTitle');
  String get settingsVersionCopy => _t('settingsVersionCopy');
  String get settingsVersionCopied => _t('settingsVersionCopied');
  String get settingsTermsOfUse => _t('settingsTermsOfUse');
  String get termsLoadError => _t('termsLoadError');
  String get settingsPrivacyPolicy => _t('settingsPrivacyPolicy');
  String get settingsSpecialThanks => _t('settingsSpecialThanks');
  String get settingsTellFriend => _t('settingsTellFriend');
  String get settingsInviteShareText => _t('settingsInviteShareText');
  String get settingsPremiumBenefitsTitle => _t('settingsPremiumBenefitsTitle');
  String get settingsPremiumBannerHint => _t('settingsPremiumBannerHint');
  String get settingsRateCouldNotOpen => _t('settingsRateCouldNotOpen');
  String get unitsTitle => _t('unitsTitle');
  String get unitsIntro => _t('unitsIntro');
  String get unitsLengthTitle => _t('unitsLengthTitle');
  String get unitsLengthSubtitle => _t('unitsLengthSubtitle');
  String get unitsWeightTitle => _t('unitsWeightTitle');
  String get unitsWeightSubtitle => _t('unitsWeightSubtitle');
  String get unitsLiquidTitle => _t('unitsLiquidTitle');
  String get unitsLiquidSubtitle => _t('unitsLiquidSubtitle');
  String get unitsTempTitle => _t('unitsTempTitle');
  String get unitsTempSubtitle => _t('unitsTempSubtitle');
  String get unitsOptCm => _t('unitsOptCm');
  String get unitsOptInch => _t('unitsOptInch');
  String get unitsOptKg => _t('unitsOptKg');
  String get unitsOptLb => _t('unitsOptLb');
  String get unitsOptSt => _t('unitsOptSt');
  String get unitsOptMl => _t('unitsOptMl');
  String get unitsOptUkFloz => _t('unitsOptUkFloz');
  String get unitsOptUsFloz => _t('unitsOptUsFloz');
  String get unitsOptC => _t('unitsOptC');
  String get unitsOptF => _t('unitsOptF');

  // Auth (login / register) — chaves com fallback EN nos idiomas sem tradução própria.
  String get authLoginTitle => _t('authLoginTitle');
  String get authWelcome => _t('authWelcome');
  String get authEmailLabel => _t('authEmailLabel');
  String get authPasswordLabel => _t('authPasswordLabel');
  String get authForgotPassword => _t('authForgotPassword');
  String get authSignIn => _t('authSignIn');
  String get authSigningIn => _t('authSigningIn');
  String get authSignInGoogle => _t('authSignInGoogle');
  String get authSignInApple => _t('authSignInApple');
  String get authSignInEmail => _t('authSignInEmail');
  String get authAppleSignInPlaceholder => _t('authAppleSignInPlaceholder');
  String get authCreateAccount => _t('authCreateAccount');
  String get authForgotDialogTitle => _t('authForgotDialogTitle');
  String get authForgotDialogBody => _t('authForgotDialogBody');
  String get authForgotSend => _t('authForgotSend');
  String get authResetEmailSentSnackbar => _t('authResetEmailSentSnackbar');
  String get authRegisterAppBarTitle => _t('authRegisterAppBarTitle');
  String get authRegisterTitle => _t('authRegisterTitle');
  String get authRegisterNameLabel => _t('authRegisterNameLabel');
  String get authRegisterPasswordLabel => _t('authRegisterPasswordLabel');
  String get authRegisterSubmit => _t('authRegisterSubmit');
  String get authRegisterCreating => _t('authRegisterCreating');
  String get authValEmailRequired => _t('authValEmailRequired');
  String get authValEmailInvalid => _t('authValEmailInvalid');
  String get authValPasswordRequired => _t('authValPasswordRequired');
  String get authValPasswordMin6 => _t('authValPasswordMin6');
  String get authValNameRequired => _t('authValNameRequired');
  String get authValNameShort => _t('authValNameShort');
  String get authErrWeakPassword => _t('authErrWeakPassword');
  String get authErrInvalidEmail => _t('authErrInvalidEmail');
  String get authErrUserDisabled => _t('authErrUserDisabled');
  String get authErrUserNotFound => _t('authErrUserNotFound');
  String get authErrWrongPassword => _t('authErrWrongPassword');
  String get authErrEmailInUse => _t('authErrEmailInUse');
  String get authErrAccountExistsDifferentCredential =>
      _t('authErrAccountExistsDifferentCredential');
  String get authErrInvalidCredential => _t('authErrInvalidCredential');
  String get authErrCredentialsGeneric => _t('authErrCredentialsGeneric');
  String get authErrGoogleConfigAndroid => _t('authErrGoogleConfigAndroid');
  String get authErrAppleFailed => _t('authErrAppleFailed');
  String get authErrAppleUnavailable => _t('authErrAppleUnavailable');
  String get authErrLoginCancelled => _t('authErrLoginCancelled');
  String get authErrUnexpected => _t('authErrUnexpected');

  String get emailVerifyTitle => _t('emailVerifyTitle');
  String get emailVerifyLead => _t('emailVerifyLead');
  String get emailVerifyWhy => _t('emailVerifyWhy');
  String get emailVerifyResendButton => _t('emailVerifyResendButton');
  String get emailVerifyConfirmedButton => _t('emailVerifyConfirmedButton');
  String get emailVerifySignOut => _t('emailVerifySignOut');
  String get emailVerifySent => _t('emailVerifySent');
  String get emailVerifyStillPending => _t('emailVerifyStillPending');
  String get authErrEmailVerifyTooMany => _t('authErrEmailVerifyTooMany');
  String emailVerifyResendWait(int seconds) =>
      _t('emailVerifyResendWait').replaceAll('{seconds}', '$seconds');

  String onb(String key) => _t('onb$key');
  String onbWithName(String key, String name) =>
      _t('onb$key').replaceAll('{name}', name);

  /// Dica quando [fetchSignInMethodsForEmail] indicou métodos já associados ao e-mail.
  String authEmailInUseHintForProviders(List<String> signInMethods) {
    final set = signInMethods
        .map((e) => e.toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final hasPassword = set.contains('password');
    final hasGoogle = set.contains('google.com');
    final hasApple = set.contains('apple.com');
    final hasPhone = set.contains('phone');
    final known = hasPassword || hasGoogle || hasApple || hasPhone;
    if (set.isNotEmpty && !known) {
      return _t('authErrEmailInUseMixed');
    }
    if (hasPhone && set.length == 1) {
      return _t('authErrEmailInUseMixed');
    }
    if (set.length >= 2 || (hasPassword && (hasGoogle || hasApple))) {
      return _t('authErrEmailInUseMixed');
    }
    if (hasGoogle) return _t('authErrEmailInUseGoogle');
    if (hasApple) return _t('authErrEmailInUseApple');
    if (hasPassword) return _t('authErrEmailInUsePassword');
    return _t('authErrEmailInUse');
  }

  /// Mensagens de erro de login/registo alinhadas ao idioma atual.
  String userFacingAuthError(Object error) {
    if (error is EmailVerificationCooldownException) {
      final s = error.remaining.inSeconds;
      return emailVerifyResendWait(s);
    }
    if (error is EmailAlreadyRegisteredException) {
      return authEmailInUseHintForProviders(error.signInMethods);
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'weak-password':
          return authErrWeakPassword;
        case 'invalid-email':
          return authErrInvalidEmail;
        case 'user-disabled':
          return authErrUserDisabled;
        case 'user-not-found':
          return authErrUserNotFound;
        case 'wrong-password':
          return authErrWrongPassword;
        case 'account-exists-with-different-credential':
          return authErrAccountExistsDifferentCredential;
        case 'credential-already-in-use':
          return authErrAccountExistsDifferentCredential;
        case 'email-already-in-use':
          return authErrEmailInUse;
        case 'invalid-credential':
        case 'invalid-verification-code':
        case 'invalid-verification-id':
          return authErrInvalidCredential;
        case 'too-many-requests':
          return authErrEmailVerifyTooMany;
        default:
          return authErrCredentialsGeneric;
      }
    }
    final s = error.toString();
    if (s.contains('ApiException: 10') ||
        s.contains('DEVELOPER_ERROR') ||
        s.contains('sign_in_failed')) {
      return authErrGoogleConfigAndroid;
    }
    if (s.contains('Login cancelado') ||
        s.contains('login canceled') ||
        s.contains('Login canceled') ||
        s.contains('sign_in_canceled') ||
        s.contains('SIGN_IN_CANCELED')) {
      return authErrLoginCancelled;
    }
    if (s.contains('APPLE_UNAVAILABLE_PLATFORM')) {
      return authErrAppleUnavailable;
    }
    if (s.contains('APPLE_MISSING_ID_TOKEN') ||
        s.contains('APPLE_AUTH_FAILED')) {
      return authErrAppleFailed;
    }
    return '$authErrUnexpected\n$s';
  }

  String get vaccinesTitle => _t('vaccinesTitle');
  String get vaccinesSubtitle => _t('vaccinesSubtitle');
  String get baby => _t('baby');
  String get selectBaby => _t('selectBaby');
  String get addVaccine => _t('addVaccine');
  String get recordsTitle => _t('recordsTitle');
  String get noVaccinesYet => _t('noVaccinesYet');
  String get exampleCard => _t('exampleCard');

  // Home / banner / shortcuts
  String get seeAll => _t('seeAll');
  String get changePhoto => _t('changePhoto');
  String get motherPhotoTitle => _t('motherPhotoTitle');
  String get fatherPhotoTitle => _t('fatherPhotoTitle');
  String get regFatherPhotoAdd => _t('regFatherPhotoAdd');
  String get regFatherPhotoChange => _t('regFatherPhotoChange');
  String get babyPhotoTitle => _t('babyPhotoTitle');

  // Família / árvore
  String get familyTitle => _t('familyTitle');
  String get familySubtitle => _t('familySubtitle');
  String get familyEdit => _t('familyEdit');
  String get familyEditData => _t('familyEditData');
  String get familyTabMotherLabel => _t('familyTabMotherLabel');
  String get familyTabFatherLabel => _t('familyTabFatherLabel');

  String get familyRoleMother => _t('familyRoleMother');
  String get familyRoleFather => _t('familyRoleFather');
  String get familyRoleBaby => _t('familyRoleBaby');
  String get familyZodiacSolar => _t('familyZodiacSolar');
  String get familyEntertainmentNote => _t('familyEntertainmentNote');
  String get familyChristianCardTitle => _t('familyChristianCardTitle');
  String get familySpiritistCardTitle => _t('familySpiritistCardTitle');
  String get familyJewishCardTitle => _t('familyJewishCardTitle');
  String familyChristianLine(String reference) =>
      _t('familyChristianLine').replaceAll('{ref}', reference);
  String familyBornOn(String date) =>
      _t('familyBornOn').replaceAll('{date}', date);
  String familyAgeYears(int years) => years == 1
      ? _t('familyAgeOneYear')
      : _t('familyAgeYears').replaceAll('{n}', '$years');
  String familyHeight(String value) =>
      _t('familyHeight').replaceAll('{value}', value);
  String familyMotherBlurb(String sign, String traits) =>
      _t('familyMotherBlurb')
          .replaceAll('{sign}', sign)
          .replaceAll('{traits}', traits);
  String familyFatherBlurb(String sign, String traits) =>
      _t('familyFatherBlurb')
          .replaceAll('{sign}', sign)
          .replaceAll('{traits}', traits);
  String familyBabyBlurb(String sign, String traits) => _t('familyBabyBlurb')
      .replaceAll('{sign}', sign)
      .replaceAll('{traits}', traits);
  String familyZodiacName(ZodiacId id) => _t('familyZodiacName_${id.name}');
  String familyZodiacTrait(ZodiacId id) => _t('familyZodiacTrait_${id.name}');
  String get familyFatherDataComplete => _t('familyFatherDataComplete');
  String get familyFatherDataIncomplete => _t('familyFatherDataIncomplete');
  String get familyAddFatherPrompt => _t('familyAddFatherPrompt');
  String get familyAddFatherButton => _t('familyAddFatherButton');
  String get familyCompleteBabySex => _t('familyCompleteBabySex');
  String get familyEditBabyData => _t('familyEditBabyData');
  String get familyCompleteHeights => _t('familyCompleteHeights');
  String get familyCompleteHeightsButton => _t('familyCompleteHeightsButton');
  String familyEstimatedHeightTitle(String name) =>
      _t('familyEstimatedHeightTitle').replaceAll('{name}', name);
  String get familyMotherHeightLabel => _t('familyMotherHeightLabel');
  String get familyFatherHeightLabel => _t('familyFatherHeightLabel');
  String get familyEstimatedGirl => _t('familyEstimatedGirl');
  String get familyEstimatedBoy => _t('familyEstimatedBoy');
  String familyEstimatedResult(String cm) =>
      _t('familyEstimatedResult').replaceAll('{cm}', cm);
  String get familyHowCalculated => _t('familyHowCalculated');
  String get familyFormulaBoy => _t('familyFormulaBoy');
  String get familyFormulaGirl => _t('familyFormulaGirl');
  String get familyEstimatedHeightDescription =>
      _t('familyEstimatedHeightDescription');
  String familyFormulaExampleGirl(int father, int mother, int result) =>
      _t('familyFormulaExampleGirl')
          .replaceAll('{father}', '$father')
          .replaceAll('{mother}', '$mother')
          .replaceAll('{result}', '$result');
  String familyFormulaExampleBoy(int father, int mother, int result) =>
      _t('familyFormulaExampleBoy')
          .replaceAll('{father}', '$father')
          .replaceAll('{mother}', '$mother')
          .replaceAll('{result}', '$result');
  String get familyHeightDisclaimer => _t('familyHeightDisclaimer');
  String get familyZodiacReadMore => _t('familyZodiacReadMore');
  String get familyPremiumZodiacLocked => _t('familyPremiumZodiacLocked');
  String get familyPremiumHeightLocked => _t('familyPremiumHeightLocked');
  String get familyPremiumUnlockCta => _t('familyPremiumUnlockCta');
  String get familyScreenTitle => _t('familyScreenTitle');
  String get familyPersonalInfoTitle => _t('familyPersonalInfoTitle');
  String familyHoroscopeCardTitle(ZodiacId id) =>
      _t('familyHoroscopeCardTitle').replaceAll('{sign}', familyZodiacName(id));
  String get familyBibleVerseCardTitle => _t('familyBibleVerseCardTitle');
  String get familyDailySummaryTitle => _t('familyDailySummaryTitle');
  String get familySummaryFeeding => _t('familySummaryFeeding');
  String get familySummaryDiapers => _t('familySummaryDiapers');
  String get familySummarySleep => _t('familySummarySleep');
  String get familySummaryWeight => _t('familySummaryWeight');
  String get familyQuickLabelBirth => _t('familyQuickLabelBirth');
  String get familyQuickLabelTime => _t('familyQuickLabelTime');
  String familySummaryFeedingsToday(int n) =>
      _t('familySummaryFeedingsToday').replaceAll('{n}', '$n');
  String familySummaryDiaperChangesCount(int n) =>
      _t('familySummaryDiaperChangesCount').replaceAll('{n}', '$n');
  String familySummaryLastAt(String time) =>
      _t('familySummaryLastAt').replaceAll('{time}', time);
  String familySummaryLastSleepAt(String time) =>
      _t('familySummaryLastSleepAt').replaceAll('{time}', time);
  String get familySummaryWeightDayLine => _t('familySummaryWeightDayLine');
  String get familyFieldBirthDate => _t('familyFieldBirthDate');
  String get familyFieldSign => _t('familyFieldSign');
  String get familyFieldElement => _t('familyFieldElement');
  String get familyFieldAge => _t('familyFieldAge');
  String get familyFieldHeight => _t('familyFieldHeight');
  String get familyFieldWeight => _t('familyFieldWeight');
  String get familyPremiumShortBadge => _t('familyPremiumShortBadge');
  String get familyPremiumFeatureLockedBody =>
      _t('familyPremiumFeatureLockedBody');
  String get familyPremiumBannerTitle => _t('familyPremiumBannerTitle');
  String get familyPremiumBannerBody => _t('familyPremiumBannerBody');
  String get familyPremiumViewPlans => _t('familyPremiumViewPlans');
  String get familyAddFatherCardTitle => _t('familyAddFatherCardTitle');

  String zodiacElementLabel(ZodiacElement element) {
    switch (element) {
      case ZodiacElement.fire:
        return _t('familyElementFire');
      case ZodiacElement.earth:
        return _t('familyElementEarth');
      case ZodiacElement.air:
        return _t('familyElementAir');
      case ZodiacElement.water:
        return _t('familyElementWater');
    }
  }

  String get familyTapToOpen => _t('familyTapToOpen');
  String get familyCarouselSwipe => _t('familyCarouselSwipe');

  /// Rótulo do separador do bebé quando só há um filho (ex.: «Nenê» em PT).
  String get familyTabNene => _t('familyTabNene');
  String get familyTabsHint => _t('familyTabsHint');
  String get familyTapToClose => _t('familyTapToClose');
  String get familyShareCard => _t('familyShareCard');
  String get changeBabyTooltip => _t('changeBabyTooltip');
  String get notificationsInboxTitle => _t('notificationsInboxTitle');
  String get notificationsInboxSubtitle => _t('notificationsInboxSubtitle');
  String get notificationsEmpty => _t('notificationsEmpty');
  String get notificationsKindShown => _t('notificationsKindShown');
  String get notificationsKindScheduled => _t('notificationsKindScheduled');
  String get notificationsOpenTarget => _t('notificationsOpenTarget');
  String get notificationsSelectAll => _t('notificationsSelectAll');
  String get deleteAccountTitle => _t('deleteAccountTitle');
  String get deleteAccountBody => _t('deleteAccountBody');
  String get deleteAccountConfirm => _t('deleteAccountConfirm');
  String get deleteAccountDeleting => _t('deleteAccountDeleting');
  String get deleteAccountSuccess => _t('deleteAccountSuccess');
  String get deleteAccountReauthTitle => _t('deleteAccountReauthTitle');
  String get deleteAccountReauthBody => _t('deleteAccountReauthBody');
  String get deleteAccountReauthGoogleSection =>
      _t('deleteAccountReauthGoogleSection');
  String deleteAccountReauthGoogleAccountHint(String email) =>
      _t('deleteAccountReauthGoogleAccountHint').replaceAll('{email}', email);
  String get deleteAccountReauthPasswordSection =>
      _t('deleteAccountReauthPasswordSection');
  String get deleteAccountReauthOrDivider => _t('deleteAccountReauthOrDivider');
  String get deleteAccountReauthEmailLabel =>
      _t('deleteAccountReauthEmailLabel');
  String get deleteAccountReauthPasswordHint =>
      _t('deleteAccountReauthPasswordHint');
  String get deleteAccountReauthPasswordRequired =>
      _t('deleteAccountReauthPasswordRequired');
  String get deleteAccountReauthGoogle => _t('deleteAccountReauthGoogle');
  String get deleteAccountReauthContinue => _t('deleteAccountReauthContinue');
  String get deleteAccountReauthCantPassword =>
      _t('deleteAccountReauthCantPassword');
  String get deleteAccountTypeWordTitle => _t('deleteAccountTypeWordTitle');
  String get deleteAccountTypeWordInstruction =>
      _t('deleteAccountTypeWordInstruction');
  String get deleteAccountTypeWordFieldLabel =>
      _t('deleteAccountTypeWordFieldLabel');
  String get homeBabyBannerForecastSleep => _t('homeBabyBannerForecastSleep');
  String get homeBabyBannerForecastWake => _t('homeBabyBannerForecastWake');
  String get homeBabyBannerForecastSubtitleSleep =>
      _t('homeBabyBannerForecastSubtitleSleep');
  String get homeBabyBannerForecastSubtitleWake =>
      _t('homeBabyBannerForecastSubtitleWake');
  String homeBabyBannerEtaIn(String d) =>
      _t('homeBabyBannerEtaIn').replaceAll('{d}', d);
  String get homeBabyBannerLastDiaper => _t('homeBabyBannerLastDiaper');
  String get homeBabyBannerNoRecordsYet => _t('homeBabyBannerNoRecordsYet');
  String homeBabyBannerNextBetween(String range) =>
      _t('homeBabyBannerNextBetween').replaceAll('{range}', range);
  String homeBabyBannerDiaperRecommendedUntil(String d) =>
      _t('homeBabyBannerDiaperRecommendedUntil').replaceAll('{d}', d);
  String homeBabyBannerIdealWindow(String range) =>
      _t('homeBabyBannerIdealWindow').replaceAll('{range}', range);
  String get homeConsultationScheduled => _t('homeConsultationScheduled');
  String get homeBannerChipConsultation => _t('homeBannerChipConsultation');
  String get homeBannerChipDiaper => _t('homeBannerChipDiaper');
  String get homeBannerChipFeed => _t('homeBannerChipFeed');
  String get homeBannerChipSleep => _t('homeBannerChipSleep');
  String get homeBannerOverdueSleep => _t('homeBannerOverdueSleep');
  String get homeBannerOverdueWake => _t('homeBannerOverdueWake');
  String get homeBannerHungry => _t('homeBannerHungry');
  String get homeBannerDiaperDirty => _t('homeBannerDiaperDirty');
  String get homeBannerExhausted => _t('homeBannerExhausted');
  String get memoryTellMomentTitle => _t('memoryTellMomentTitle');
  String get memoryTellMomentHint => _t('memoryTellMomentHint');
  String get memoryBabyInfoOptionalTitle => _t('memoryBabyInfoOptionalTitle');
  String get memoryBabyMoodLabel => _t('memoryBabyMoodLabel');
  String get memoryBabyMoodHint => _t('memoryBabyMoodHint');

  // Detalhe / partilha / edição de memória (badge)
  String get memoryMomentInfoTitle => _t('memoryMomentInfoTitle');
  String get memoryStatAgeLabel => _t('memoryStatAgeLabel');
  String get memoryStatWeightLabel => _t('memoryStatWeightLabel');
  String get memoryStatHeightLabel => _t('memoryStatHeightLabel');
  String get memoryStatMoodLabel => _t('memoryStatMoodLabel');
  String get memoryMotherNotesLabel => _t('memoryMotherNotesLabel');
  String get memoryTipForYouTitle => _t('memoryTipForYouTitle');
  String get memoryShareButton => _t('memoryShareButton');
  String get memoryFavoriteButton => _t('memoryFavoriteButton');
  String get memoryFavoritedButton => _t('memoryFavoritedButton');
  String get weeklyPhotoPublicExplainer => _t('weeklyPhotoPublicExplainer');
  String get weeklyPhotoPublicOff => _t('weeklyPhotoPublicOff');
  String get weeklyPhotoPublicOn => _t('weeklyPhotoPublicOn');
  String get weeklyPhotoPublicNeedPhoto => _t('weeklyPhotoPublicNeedPhoto');
  String get weeklyPhotoConfirmTitle => _t('weeklyPhotoConfirmTitle');
  String get weeklyPhotoConfirmBody => _t('weeklyPhotoConfirmBody');
  String get weeklyPhotoConfirmNo => _t('weeklyPhotoConfirmNo');
  String get weeklyPhotoConfirmYes => _t('weeklyPhotoConfirmYes');
  String get weeklyPhotoParticipatingBadge =>
      _t('weeklyPhotoParticipatingBadge');
  String get weeklyPhotoWinnerBadge => _t('weeklyPhotoWinnerBadge');
  String get weeklyPhotoShowBabyFirstName => _t('weeklyPhotoShowBabyFirstName');
  String get weeklyPhotoDisclaimerFooter => _t('weeklyPhotoDisclaimerFooter');
  String get weeklyPhotoReportLink => _t('weeklyPhotoReportLink');
  String get weeklyPhotoReportTitle => _t('weeklyPhotoReportTitle');
  String get weeklyPhotoReportHint => _t('weeklyPhotoReportHint');
  String get weeklyPhotoReportMessageLabel =>
      _t('weeklyPhotoReportMessageLabel');
  String get weeklyPhotoReportSubmit => _t('weeklyPhotoReportSubmit');
  String get weeklyPhotoReportSuccess => _t('weeklyPhotoReportSuccess');
  String get weeklyPhotoReportNeedLogin => _t('weeklyPhotoReportNeedLogin');
  String get weeklyPhotoReportMessageTooShort =>
      _t('weeklyPhotoReportMessageTooShort');
  String get weeklyPhotoReportMessageTooLong =>
      _t('weeklyPhotoReportMessageTooLong');
  String get weeklyPhotoReportFailed => _t('weeklyPhotoReportFailed');
  String get weeklyPhotoSectionTitle => _t('weeklyPhotoSectionTitleFemale');
  String get weeklyPhotoSectionTitleMale => _t('weeklyPhotoSectionTitleMale');
  String get weeklyPhotoSectionTitleFemale =>
      _t('weeklyPhotoSectionTitleFemale');
  String weeklyPhotoSectionTitleForBabySex(String? sex) {
    if (_isMaleBabySex(sex)) return _t('weeklyPhotoSectionTitleMale');
    return _t('weeklyPhotoSectionTitleFemale');
  }

  /// Título em destaque no banner da Home (maiúsculas; PT/EN nas maps, resto via fallback EN).
  String weeklyPhotoHomeHeroTitle(String? sex) {
    if (_isMaleBabySex(sex)) return _t('weeklyPhotoHomeHeroMale');
    return _t('weeklyPhotoHomeHeroFemale');
  }

  String get weeklyPhotoSectionSubtitle => _t('weeklyPhotoSectionSubtitle');
  String get weeklyPhotoViewMemory => _t('weeklyPhotoViewMemory');
  String get weeklyPhotoBabyFallback => _t('weeklyPhotoBabyFallback');
  String get weeklyPhotoDisclaimerShort => _t('weeklyPhotoDisclaimerShort');
  String get weeklyPhotoPublicDetailAppBar =>
      _t('weeklyPhotoPublicDetailAppBar');
  String get weeklyPhotoWinnerCongratsTitle =>
      _t('weeklyPhotoWinnerCongratsTitle');
  String get weeklyPhotoWinnerCongratsBody =>
      weeklyPhotoWinnerCongratsBodyForBabySex(null);
  String weeklyPhotoWinnerCongratsBodyForBabySex(String? sex) {
    return _t(_isMaleBabySex(sex)
        ? 'weeklyPhotoWinnerCongratsBodyMale'
        : 'weeklyPhotoWinnerCongratsBodyFemale');
  }

  String get weeklyPhotoWinnerCongratsOk => _t('weeklyPhotoWinnerCongratsOk');
  String weeklyPhotoLikesCount(int count) =>
      _t('weeklyPhotoLikesCount').replaceAll('{count}', '$count');
  String get weeklyPhotoLikeButton => _t('weeklyPhotoLikeButton');
  String get weeklyPhotoLikedButton => _t('weeklyPhotoLikedButton');
  String get weeklyPhotoLikesWinnerHint => _t('weeklyPhotoLikesWinnerHint');
  String get weeklyPhotoLikeNeedSignIn => _t('weeklyPhotoLikeNeedSignIn');
  String get memoryEditTitle => _t('memoryEditTitle');
  String get memoryNewTitle => _t('memoryNewTitle');
  String get memoryMomNotesFieldLabel => _t('memoryMomNotesFieldLabel');
  String get memorySaveChanges => _t('memorySaveChanges');
  String get memorySaveNew => _t('memorySaveNew');
  String get memoryNoDescription => _t('memoryNoDescription');
  String get memoryPhotoAddTitle => _t('memoryPhotoAddTitle');
  String get memoryPhotoEditTitle => _t('memoryPhotoEditTitle');
  String get memoryTapToPickPhoto => _t('memoryTapToPickPhoto');
  String get memoryAgeHintExample => _t('memoryAgeHintExample');
  String get memoryWeightHintExample => _t('memoryWeightHintExample');
  String get memoryHeightHintExample => _t('memoryHeightHintExample');
  String get memorySaveNeedPhotoOrText => _t('memorySaveNeedPhotoOrText');
  String get memorySaveFail => _t('memorySaveFail');
  String get memoryShareWebOnlyMobile => _t('memoryShareWebOnlyMobile');
  String get memoryShareSheetJpegTitle => _t('memoryShareSheetJpegTitle');
  String get memoryShareSheetJpegSubtitle => _t('memoryShareSheetJpegSubtitle');
  String get memoryShareSheetPdfTitle => _t('memoryShareSheetPdfTitle');
  String get memoryShareSheetPdfSubtitle => _t('memoryShareSheetPdfSubtitle');
  String get memorySharePlatformUnavailable =>
      _t('memorySharePlatformUnavailable');
  String memoryShareError(Object e) =>
      _t('memoryShareError').replaceAll('{error}', '$e');

  /// Rodapé do cartão de partilha.
  String get memoryFooterBranding => _t('memoryFooterBranding');

  String memoryTipForBadgeId(String badgeId) {
    switch (badgeId) {
      case 'first_smile':
        return _t('memoryTipFirstSmile');
      case 'first_laugh':
        return _t('memoryTipFirstLaugh');
      case 'first_feeding':
        return _t('memoryTipFirstFeeding');
      case 'first_steps':
        return _t('memoryTipFirstSteps');
      default:
        return _t('memoryTipDefault');
    }
  }

  /// Idade textual sugerida no formulário novo (automática a partir da data do momento).
  String memorySuggestedAgeBetween(
      {required DateTime birth, required DateTime when}) {
    final days =
        when.difference(DateTime(birth.year, birth.month, birth.day)).inDays;
    if (days < 0) return '—';
    if (days < 60) {
      if (days == 1) return _t('memoryAgeOneDay');
      return _t('memoryAgeManyDays').replaceAll('{n}', '$days');
    }
    final months = (days / 30).floor();
    if (months < 24) {
      return months == 1 ? memoryBadgeMonthOne : memoryBadgeMonthsMany(months);
    }
    final years = (months / 12).floor();
    return years == 1 ? memoryBadgeYearOne : memoryBadgeYearsMany(years);
  }

  String get registerVerb => _t('registerVerb');
  String get viewCalendar => _t('viewCalendar');
  String get shortcutMilk => _t('shortcutMilk');
  String get shortcutSleep => _t('shortcutSleep');
  String get shortcutVaccines => _t('shortcutVaccines');
  String get homeNextNow => _t('homeNextNow');
  String get summaryFeedings => _t('summaryFeedings');
  String get summarySleep => _t('summarySleep');
  String get summaryDiapers => _t('summaryDiapers');
  String get summaryWeight => _t('summaryWeight');
  String summaryFeedingsValue(int n, int minutes) => _t('summaryFeedingsValue')
      .replaceAll('{n}', '$n')
      .replaceAll('{m}', '$minutes');
  String summaryFeedingsCount(int n) =>
      (n == 1 ? _t('summaryFeedingsCountOne') : _t('summaryFeedingsCountMany'))
          .replaceAll('{n}', '$n');
  String summaryFeedingsMinutes(int minutes) =>
      _t('summaryFeedingsMinutes').replaceAll('{m}', '$minutes');
  String summaryDiapersValue(int total, int pee, int poo) =>
      _t('summaryDiapersValue')
          .replaceAll('{total}', '$total')
          .replaceAll('{pee}', '$pee')
          .replaceAll('{poo}', '$poo');
  String summaryDiapersTotal(int total) =>
      _t('summaryDiapersTotal').replaceAll('{total}', '$total');
  String summaryDiapersChanges(int n) => (n == 1
          ? _t('summaryDiapersChangesOne')
          : _t('summaryDiapersChangesMany'))
      .replaceAll('{n}', '$n');
  String summaryDiapersPeePoo(int pee, int poo) => _t('summaryDiapersPeePoo')
      .replaceAll('{pee}', '$pee')
      .replaceAll('{poo}', '$poo');
  String summarySleepValue(int sessions, String totalCompact) =>
      _t('summarySleepValue')
          .replaceAll('{s}', '$sessions')
          .replaceAll('{t}', totalCompact);
  String summarySleepSessions(int sessions) => (sessions == 1
          ? _t('summarySleepSessionsOne')
          : _t('summarySleepSessionsMany'))
      .replaceAll('{s}', '$sessions');
  String get homeSummaryExtraHint => _t('homeSummaryExtraHint');
  String get homeSummaryNoRecords => _t('homeSummaryNoRecords');
  String get homeSummaryTotalDay => _t('homeSummaryTotalDay');
  String get homeTipTitle => _t('homeTipTitle');
  String get homeStatusOk => _t('homeStatusOk');
  String get homeStatusWarn => _t('homeStatusWarn');
  String get homeStatusHungry => _t('homeStatusHungry');
  String get homeTimeToFeed => _t('homeTimeToFeed');
  String get homeStatusDetailFed => _t('homeStatusDetailFed');
  String get homeStatusDetailNear => _t('homeStatusDetailNear');
  String get homeStatusDetailLate => _t('homeStatusDetailLate');
  String get homePickDayLabel => _t('homePickDayLabel');
  String get homeTodayLabel => _t('homeTodayLabel');
  String get homeYesterdayLabel => _t('homeYesterdayLabel');
  String get homePastDayBadge => _t('homePastDayBadge');
  String get homePastDayDetail => _t('homePastDayDetail');
  String get homeBannerAlertCheckDiaper => _t('homeBannerAlertCheckDiaper');
  String get homeBannerAlertTimeToSleep => _t('homeBannerAlertTimeToSleep');
  String get homeBannerAlertSleepingLong => _t('homeBannerAlertSleepingLong');
  String get homeCriticalCareTitle => _t('homeCriticalCareTitle');
  String homeCriticalCareCount(int n) =>
      _t('homeCriticalCareCount').replaceAll('{n}', '$n');
  String get homeCriticalFeedingTitle => _t('homeCriticalFeedingTitle');
  String get homeCriticalSleepTitle => _t('homeCriticalSleepTitle');
  String get homeCriticalDiaperTitle => _t('homeCriticalDiaperTitle');
  String get homeCriticalFeedingSubtitle => _t('homeCriticalFeedingSubtitle');
  String get homeCriticalSleepSubtitle => _t('homeCriticalSleepSubtitle');
  String get homeCriticalWakeTitle => _t('homeCriticalWakeTitle');
  String get homeCriticalWakeSubtitle => _t('homeCriticalWakeSubtitle');
  String get homeCriticalDiaperSubtitle => _t('homeCriticalDiaperSubtitle');
  String get homeSleepBarAwakeTitle => _t('homeSleepBarAwakeTitle');
  String get homeSleepBarSleepTitle => _t('homeSleepBarSleepTitle');
  String get homeFeedingCounterTitle => _t('homeFeedingCounterTitle');
  String get homeFeedingCounterHint => _t('homeFeedingCounterHint');
  String homeSleepBarAwakeHintEarly(int m) =>
      _t('homeSleepBarAwakeHintEarly').replaceAll('{m}', '$m');
  String homeSleepBarAwakeHintIdeal(int m) =>
      _t('homeSleepBarAwakeHintIdeal').replaceAll('{m}', '$m');
  String get homeSleepBarAwakeHintOverdue => _t('homeSleepBarAwakeHintOverdue');
  String homeSleepBarSleepHint(String remaining, int cap) =>
      _t('homeSleepBarSleepHint')
          .replaceAll('{remaining}', remaining)
          .replaceAll('{cap}', '$cap');
  String get homeSleepBarNeedLastSleep => _t('homeSleepBarNeedLastSleep');

  String helloMomNamed(String name) =>
      _t('helloMomNamed').replaceAll('{name}', name.trim());
  String homeFedAgo(String when) => _t('homeFedAgo').replaceAll('{when}', when);
  String homePeeAgo(String when) => _t('homePeeAgo').replaceAll('{when}', when);
  String homePooAgo(String when) => _t('homePooAgo').replaceAll('{when}', when);
  String homeNextIn(int n) => _t('homeNextIn').replaceAll('{n}', '$n');
  String summaryLastFeed(String time) =>
      _t('summaryLastFeed').replaceAll('{time}', time);
  String summaryLastSleep(String time) =>
      _t('summaryLastSleep').replaceAll('{time}', time);
  String homeTipBody(String name) =>
      _t('homeTipBody').replaceAll('{name}', name);
  String get homeYesterdayBabaTitle => _t('homeYesterdayBabaTitle');
  String homeYesterdayBabaFallback(String name) =>
      _t('homeYesterdayBabaFallback').replaceAll('{name}', name);
  String get homeYesterdayBabaRoutineQuiet => _t('homeYesterdayBabaRoutineQuiet');
  String homeYesterdayBabaRoutine({
    required int feeds,
    required String sleep,
    required int diapers,
  }) =>
      _t('homeYesterdayBabaRoutine')
          .replaceAll('{feeds}', '$feeds')
          .replaceAll('{sleep}', sleep)
          .replaceAll('{diapers}', '$diapers');
  String get homeYesterdayBabaGrowthBothWithin =>
      _t('homeYesterdayBabaGrowthBothWithin');
  String get homeYesterdayBabaGrowthNoData => _t('homeYesterdayBabaGrowthNoData');
  String homeYesterdayBabaGrowthCombo({
    required String weight,
    required String height,
  }) =>
      _t('homeYesterdayBabaGrowthCombo')
          .replaceAll('{weight}', weight)
          .replaceAll('{height}', height);
  String get homeYesterdayBabaGrowthBelow => _t('homeYesterdayBabaGrowthBelow');
  String get homeYesterdayBabaGrowthAbove => _t('homeYesterdayBabaGrowthAbove');
  String homeYesterdayBabaRoutineLowSleep({
    required int feeds,
    required String sleep,
    required int diapers,
  }) =>
      _t('homeYesterdayBabaRoutineLowSleep')
          .replaceAll('{feeds}', '$feeds')
          .replaceAll('{sleep}', sleep)
          .replaceAll('{diapers}', '$diapers');
  String get homeYesterdayBabaBandWithin => _t('homeYesterdayBabaBandWithin');
  String get homeYesterdayBabaBandBelow => _t('homeYesterdayBabaBandBelow');
  String get homeYesterdayBabaBandAbove => _t('homeYesterdayBabaBandAbove');
  String get homeYesterdayBabaBandUnknown => _t('homeYesterdayBabaBandUnknown');
  String get homeAiInsightDailyTitle => _t('homeAiInsightDailyTitle');
  String get homeAiInsightWeeklyTitle => _t('homeAiInsightWeeklyTitle');
  String get aiBubbleDragToClose => _t('aiBubbleDragToClose');
  String get aiBubbleCloseZone => _t('aiBubbleCloseZone');
  String get floatingMessageDropToClose => _t('floatingMessageDropToClose');
  String get floatingMessageDropToCloseAll => _t('floatingMessageDropToCloseAll');
  String get floatingMessageLinkOpenFailed =>
      _t('floatingMessageLinkOpenFailed');
  String get aiBubbleOpenLink => _t('aiBubbleOpenLink');
  String get aiBubblePromoKnowMore => _t('aiBubblePromoKnowMore');
  String homeAiInsightDailySleepBetter(String name) =>
      _t('homeAiInsightDailySleepBetter').replaceAll('{name}', name);
  String homeAiInsightDailySleepLess(String name) =>
      _t('homeAiInsightDailySleepLess').replaceAll('{name}', name);
  String homeAiInsightDailyFeedingBetter(String name) =>
      _t('homeAiInsightDailyFeedingBetter').replaceAll('{name}', name);
  String homeAiInsightDailyPeaceful(String name) =>
      _t('homeAiInsightDailyPeaceful').replaceAll('{name}', name);
  String homeAiInsightDailyQuiet(String name) =>
      _t('homeAiInsightDailyQuiet').replaceAll('{name}', name);
  String homeAiInsightDailyDefault(String name) =>
      _t('homeAiInsightDailyDefault').replaceAll('{name}', name);
  String homeAiInsightDailyWithGrowth(String name, String growth) =>
      _t('homeAiInsightDailyWithGrowth')
          .replaceAll('{name}', name)
          .replaceAll('{growth}', growth);
  String homeAiInsightWeeklySleepImproved(String name) =>
      _t('homeAiInsightWeeklySleepImproved').replaceAll('{name}', name);
  String homeAiInsightWeeklyFeedingImproved(String name) =>
      _t('homeAiInsightWeeklyFeedingImproved').replaceAll('{name}', name);
  String homeAiInsightWeeklyStable(String name) =>
      _t('homeAiInsightWeeklyStable').replaceAll('{name}', name);
  String homeAiInsightWeeklyFewData(String name) =>
      _t('homeAiInsightWeeklyFewData').replaceAll('{name}', name);
  String get homeAiInsightGrowthShortHealthy => _t('homeAiInsightGrowthShortHealthy');
  String get homeAiInsightGrowthShortWatch => _t('homeAiInsightGrowthShortWatch');
  String aiBubbleFeverAcute(String name) =>
      _t('aiBubbleFeverAcute').replaceAll('{name}', name);
  String aiBubbleFeverAcuteWithTemp(String name, double temp) =>
      _t('aiBubbleFeverAcuteWithTemp')
          .replaceAll('{name}', name)
          .replaceAll('{temp}', temp.toStringAsFixed(1));
  String aiBubbleFeverAcuteHigh(String name, double temp) =>
      _t('aiBubbleFeverAcuteHigh')
          .replaceAll('{name}', name)
          .replaceAll('{temp}', temp.toStringAsFixed(1));
  String aiBubbleFeverFollowUp(String name) =>
      _t('aiBubbleFeverFollowUp').replaceAll('{name}', name);
  String aiBubbleFeverFollowUpWithTemp(String name, double temp) =>
      _t('aiBubbleFeverFollowUpWithTemp')
          .replaceAll('{name}', name)
          .replaceAll('{temp}', temp.toStringAsFixed(1));
  String aiBubbleFeverRecoveryCheck(String name, int days) =>
      _t('aiBubbleFeverRecoveryCheck')
          .replaceAll('{name}', name)
          .replaceAll('{days}', '$days');
  String aiBubbleConsultToday(String name, String title, String when) =>
      _t('aiBubbleConsultToday')
          .replaceAll('{name}', name)
          .replaceAll('{title}', title)
          .replaceAll('{when}', when);
  String aiBubbleVaccineToday(String name, String vaccine) =>
      _t('aiBubbleVaccineToday')
          .replaceAll('{name}', name)
          .replaceAll('{vaccine}', vaccine);
  String aiBubbleVaccinesToday(String name, int count) =>
      _t('aiBubbleVaccinesToday')
          .replaceAll('{name}', name)
          .replaceAll('{count}', '$count');
  String aiBubbleSleepWakeLong(String name, int hours) =>
      _t('aiBubbleSleepWakeLong')
          .replaceAll('{name}', name)
          .replaceAll('{hours}', '$hours');
  String aiBubbleSleepTracking(String name, int hours) =>
      _t('aiBubbleSleepTracking')
          .replaceAll('{name}', name)
          .replaceAll('{hours}', '$hours');
  String aiBubbleFeedingCritical(String name) =>
      _t('aiBubbleFeedingCritical').replaceAll('{name}', name);
  String aiBubbleSleepCritical(String name) =>
      _t('aiBubbleSleepCritical').replaceAll('{name}', name);
  String aiBubbleSleepApproach(String name) =>
      _t('aiBubbleSleepApproach').replaceAll('{name}', name);
  String aiBubbleDiaperCritical(String name) =>
      _t('aiBubbleDiaperCritical').replaceAll('{name}', name);
  String aiBubbleWeightDown(String name) =>
      _t('aiBubbleWeightDown').replaceAll('{name}', name);
  String aiBubbleGrowthWeightBelow(
    String name,
    String value,
    String min,
    String max,
  ) =>
      _t('aiBubbleGrowthWeightBelow')
          .replaceAll('{name}', name)
          .replaceAll('{value}', value)
          .replaceAll('{min}', min)
          .replaceAll('{max}', max);
  String aiBubbleGrowthWeightAbove(
    String name,
    String value,
    String min,
    String max,
  ) =>
      _t('aiBubbleGrowthWeightAbove')
          .replaceAll('{name}', name)
          .replaceAll('{value}', value)
          .replaceAll('{min}', min)
          .replaceAll('{max}', max);
  String aiBubbleGrowthHeightBelow(
    String name,
    String value,
    String min,
    String max,
  ) =>
      _t('aiBubbleGrowthHeightBelow')
          .replaceAll('{name}', name)
          .replaceAll('{value}', value)
          .replaceAll('{min}', min)
          .replaceAll('{max}', max);
  String aiBubbleGrowthHeightAbove(
    String name,
    String value,
    String min,
    String max,
  ) =>
      _t('aiBubbleGrowthHeightAbove')
          .replaceAll('{name}', name)
          .replaceAll('{value}', value)
          .replaceAll('{min}', min)
          .replaceAll('{max}', max);
  String aiBubbleGrowthStale(String name, int days) =>
      _t('aiBubbleGrowthStale')
          .replaceAll('{name}', name)
          .replaceAll('{days}', '$days');
  String aiBubbleGrowthNone(String name) =>
      _t('aiBubbleGrowthNone').replaceAll('{name}', name);
  String aiBubbleGrowthWatch(String name, String hint) =>
      _t('aiBubbleGrowthWatch')
          .replaceAll('{name}', name)
          .replaceAll('{hint}', hint);
  String aiBubbleTodayEmpty(String name) =>
      _t('aiBubbleTodayEmpty').replaceAll('{name}', name);
  String get homeGreetingSubtitle => _t('homeGreetingSubtitle');
  String get homeMotivationBanner => _t('homeMotivationBanner');
  String get homeMotivationBannerOpenMemories =>
      _t('homeMotivationBannerOpenMemories');
  String get summaryWeightNotYet => _t('summaryWeightNotYet');
  String get summarySleepNotYet => _t('summarySleepNotYet');
  String get shortcutMilkHomeSub => _t('shortcutMilkHomeSub');
  String get shortcutGrowthHomeSub => _t('shortcutGrowthHomeSub');
  String get shortcutSleepHomeSub => _t('shortcutSleepHomeSub');
  String get homeTileDiapers => _t('homeTileDiapers');
  String homeDaysOld(int days) => days == 1
      ? _t('homeOneDayOld')
      : _t('homeDaysOld').replaceAll('{d}', '$days');

  String localizedAgeLabelFromStored(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty || text == '—') return text ?? '';
    final match = RegExp(r'^(\d+)\s*([a-zA-ZÀ-ÿ]+)$', caseSensitive: false)
        .firstMatch(text);
    if (match == null) return text;
    final n = int.tryParse(match.group(1) ?? '');
    if (n == null) return text;
    final unit = (match.group(2) ?? '').toLowerCase();
    if (unit == 'dia' || unit == 'dias' || unit == 'day' || unit == 'days') {
      return homeDaysOld(n);
    }
    if (unit == 'semana' ||
        unit == 'semanas' ||
        unit == 'week' ||
        unit == 'weeks') {
      return n == 1
          ? _t('babyAgeOneWeek')
          : _t('babyAgeWeeks').replaceAll('{n}', '$n');
    }
    if (unit == 'mes' ||
        unit == 'mês' ||
        unit == 'meses' ||
        unit == 'month' ||
        unit == 'months') {
      return n == 1
          ? _t('babyAgeOneMonth')
          : _t('babyAgeMonths').replaceAll('{n}', '$n');
    }
    if (unit == 'ano' || unit == 'anos' || unit == 'year' || unit == 'years') {
      return n == 1
          ? _t('babyAgeOneYear')
          : _t('babyAgeYears').replaceAll('{n}', '$n');
    }
    return text;
  }

  /// Idade do bebê no cartão/banner (dias → semanas → meses → anos), conforme o idioma.
  String babyAgeLabel(DateTime birthDate, DateTime now) {
    final days = now.difference(birthDate).inDays;
    if (days < 0) return '—';
    if (days < 7) return homeDaysOld(days);
    final weeks = (days / 7).floor();
    if (weeks < 8) {
      return weeks == 1
          ? _t('babyAgeOneWeek')
          : _t('babyAgeWeeks').replaceAll('{n}', '$weeks');
    }
    final months = (days / 30).floor();
    if (months < 24) {
      return months == 1
          ? _t('babyAgeOneMonth')
          : _t('babyAgeMonths').replaceAll('{n}', '$months');
    }
    final years = (days / 365).floor();
    return years == 1
        ? _t('babyAgeOneYear')
        : _t('babyAgeYears').replaceAll('{n}', '$years');
  }

  String homeSummaryOnDate(String date) =>
      _t('homeSummaryOnDate').replaceAll('{date}', date);
  String get homeSummaryPickDayTooltip => _t('homeSummaryPickDayTooltip');
  String homeFedAt(String time) => _t('homeFedAt').replaceAll('{time}', time);
  String homePeeAt(String time) => _t('homePeeAt').replaceAll('{time}', time);
  String homePooAt(String time) => _t('homePooAt').replaceAll('{time}', time);
  String homeDiaperChangeAgo(String when) =>
      _t('homeDiaperChangeAgo').replaceAll('{when}', when);
  String homeDiaperChangeAt(String time) =>
      _t('homeDiaperChangeAt').replaceAll('{time}', time);
  String homeSleepEndedAgo(String when) =>
      _t('homeSleepEndedAgo').replaceAll('{when}', when);
  String homeSleepEndedAt(String time) =>
      _t('homeSleepEndedAt').replaceAll('{time}', time);
  String homeSleepInProgress(String elapsed) =>
      _t('homeSleepInProgress').replaceAll('{elapsed}', elapsed);
  String homeSleepPausedBanner(String elapsed) =>
      _t('homeSleepPausedBanner').replaceAll('{elapsed}', elapsed);
  String get sleepBannerEmpty => _t('sleepBannerEmpty');

  String growthHistoryTitle(String label) =>
      _t('growthHistoryTitle').replaceAll('{label}', label);
  String invalidGrowthValue(String label) =>
      _t('invalidGrowthValue').replaceAll('{label}', label);
  String growthSaved(String label) =>
      _t('growthSaved').replaceAll('{label}', label);
  String growthEmpty(String label) =>
      _t('growthEmpty').replaceAll('{label}', label);
  String get notifyGrowthWeightDownTitle => _t('notifyGrowthWeightDownTitle');
  String get notifyGrowthWeightDownBody => _t('notifyGrowthWeightDownBody');
  String get notifyGrowthWeightBelowTitle => _t('notifyGrowthWeightBelowTitle');
  String notifyGrowthWeightBelowBody(String value, String min, String max) =>
      _t('notifyGrowthWeightBelowBody')
          .replaceAll('{value}', value)
          .replaceAll('{min}', min)
          .replaceAll('{max}', max);
  String get notifyGrowthWeightAboveTitle => _t('notifyGrowthWeightAboveTitle');
  String notifyGrowthWeightAboveBody(String value, String min, String max) =>
      _t('notifyGrowthWeightAboveBody')
          .replaceAll('{value}', value)
          .replaceAll('{min}', min)
          .replaceAll('{max}', max);
  String get notifyGrowthHeightBelowTitle => _t('notifyGrowthHeightBelowTitle');
  String notifyGrowthHeightBelowBody(String value, String min, String max) =>
      _t('notifyGrowthHeightBelowBody')
          .replaceAll('{value}', value)
          .replaceAll('{min}', min)
          .replaceAll('{max}', max);
  String get notifyGrowthHeightAboveTitle => _t('notifyGrowthHeightAboveTitle');
  String notifyGrowthHeightAboveBody(String value, String min, String max) =>
      _t('notifyGrowthHeightAboveBody')
          .replaceAll('{value}', value)
          .replaceAll('{min}', min)
          .replaceAll('{max}', max);
  String get notifyGrowthStaleTitle => _t('notifyGrowthStaleTitle');
  String notifyGrowthStaleBody(int days) =>
      _t('notifyGrowthStaleBody').replaceAll('{days}', '$days');
  String get labelHead => _t('labelHead');
  String get growthTabWeight => _t('growthTabWeight');
  String get growthTabHeight => _t('growthTabHeight');
  String get growthTabHead => _t('growthTabHead');
  String get growthTabSummary => _t('growthTabSummary');
  String get growthAtBirth => _t('growthAtBirth');
  String get growthCardCurrent => _t('growthCardCurrent');
  String get growthCardChange => _t('growthCardChange');
  String get growthAddWeight => _t('growthAddWeight');
  String get growthAddHeight => _t('growthAddHeight');
  String get growthAddHead => _t('growthAddHead');
  String get growthSummaryIntro => _t('growthSummaryIntro');
  String growthChartCaption(String name, String metric) =>
      _t('growthChartCaption')
          .replaceAll('{name}', name)
          .replaceAll('{metric}', metric);
  String get growthChartDeltaHint => _t('growthChartDeltaHint');
  String get growthCurveSectionTitle => _t('growthCurveSectionTitle');
  String get growthCurveSectionTitleWeight =>
      _t('growthCurveSectionTitleWeight');
  String get growthCurveDisclaimer => _t('growthCurveDisclaimer');
  String get growthCurveLegendMin => _t('growthCurveLegendMin');
  String get growthCurveLegendAvg => _t('growthCurveLegendAvg');
  String get growthCurveLegendMax => _t('growthCurveLegendMax');
  String get growthCurveLegendBaby => _t('growthCurveLegendBaby');
  String get growthCurveAxisMonths => _t('growthCurveAxisMonths');
  String get growthCurveReferenceGirls => _t('growthCurveReferenceGirls');
  String get growthCurveReferenceBoys => _t('growthCurveReferenceBoys');
  String get growthCurveSexHint => _t('growthCurveSexHint');
  String growthInsightPeriodHeight({
    required String babyName,
    required int days,
    required double deltaCm,
  }) =>
      _t('growthInsightPeriodHeight')
          .replaceAll('{name}', babyName)
          .replaceAll('{days}', '$days')
          .replaceAll('{delta}', deltaCm.toStringAsFixed(1));
  String growthInsightPeriodWeight({
    required String babyName,
    required int days,
    required double deltaGrams,
  }) {
    final absG = deltaGrams.abs();
    final deltaStr = absG >= 1000
        ? '${(absG / 1000).toStringAsFixed(2)} kg'
        : '${absG.round()} g';
    final sign = deltaGrams >= 0 ? '+' : '−';
    return _t('growthInsightPeriodWeight')
        .replaceAll('{name}', babyName)
        .replaceAll('{days}', '$days')
        .replaceAll('{delta}', '$sign$deltaStr');
  }

  String growthInsightWeightBandMessage({
    required String babyName,
    required bool isBoy,
    required int ageMonths,
    required String bandKey,
  }) {
    final tpl = switch (bandKey) {
      'within' => _t('growthInsightWeightBandWithin'),
      'above' => _t('growthInsightWeightBandAbove'),
      'below' => _t('growthInsightWeightBandBelow'),
      _ => _t('growthInsightWeightBandUnknown'),
    };
    final sexWord = isBoy
        ? _t('growthInsightSexWordBoy')
        : _t('growthInsightSexWordGirl');
    return tpl
        .replaceAll('{name}', babyName)
        .replaceAll('{months}', '$ageMonths')
        .replaceAll('{sexWord}', sexWord);
  }

  String get growthInsightCurveConsistent => _t('growthInsightCurveConsistent');
  String growthInsightBandMessage({
    required String babyName,
    required bool isBoy,
    required int ageMonths,
    required String bandKey,
  }) {
    final tpl = switch (bandKey) {
      'within' => _t('growthInsightBandWithin'),
      'above' => _t('growthInsightBandAbove'),
      'below' => _t('growthInsightBandBelow'),
      _ => _t('growthInsightBandUnknown'),
    };
    final sexWord = isBoy
        ? _t('growthInsightSexWordBoy')
        : _t('growthInsightSexWordGirl');
    return tpl
        .replaceAll('{name}', babyName)
        .replaceAll('{months}', '$ageMonths')
        .replaceAll('{sexWord}', sexWord);
  }

  String growthInsightVelocityMessage({required String trendKey}) =>
      _t(switch (trendKey) {
        'healthy' => 'growthInsightVelocityHealthy',
        'slowdown' => 'growthInsightVelocitySlowdown',
        'acceleration' => 'growthInsightVelocityAcceleration',
        'stable' => 'growthInsightVelocityStable',
        'gentle' => 'growthInsightVelocityGentle',
        _ => 'growthInsightVelocityUnknown',
      });
  String get reportPediatricGrowthInsights => _t('reportPediatricGrowthInsights');
  String get reportPediatricSectionGrowthCurve =>
      _t('reportPediatricSectionGrowthCurve');
  String get aiNannyNavLabel => _t('aiNannyNavLabel');
  String get aiNannyPhase1Hint => _t('aiNannyPhase1Hint');
  String get aiNannyTitle => _t('aiNannyTitle');
  String get aiNannySubtitle => _t('aiNannySubtitle');
  String get aiNannyWelcomeMessage => _t('aiNannyWelcomeMessage');
  String get aiNannyGrowthCurveContextHeader =>
      _t('aiNannyGrowthCurveContextHeader');
  String get aiNannyGrowthCurveContextFooter =>
      _t('aiNannyGrowthCurveContextFooter');
  String aiEmotionalMonthiversary(String name, int months, String hint) {
    final unit = months == 1
        ? _t('aiEmotionalMonthSingular')
        : _t('aiEmotionalMonthsPlural');
    return _t('aiEmotionalMonthiversary')
        .replaceAll('{name}', name)
        .replaceAll('{months}', '$months')
        .replaceAll('{unit}', unit)
        .replaceAll('{hint}', hint);
  }
  String aiEmotionalTbtPhoto(String name, String when) =>
      _t('aiEmotionalTbtPhoto').replaceAll('{name}', name).replaceAll('{when}', when);
  String get aiEmotionalTbtWeek => _t('aiEmotionalTbtWeek');
  String get aiEmotionalTbtMonth => _t('aiEmotionalTbtMonth');
  String get aiEmotionalTbtYear => _t('aiEmotionalTbtYear');
  String aiEmotionalAchieveFeedingStreak(String name, int days) =>
      _t('aiEmotionalAchieveFeedingStreak')
          .replaceAll('{name}', name)
          .replaceAll('{days}', '$days');
  String aiEmotionalAchieve100Records(String name, int count) =>
      _t('aiEmotionalAchieve100Records')
          .replaceAll('{name}', name)
          .replaceAll('{count}', '$count');
  String aiEmotionalAchieveFirstMonth(String name) =>
      _t('aiEmotionalAchieveFirstMonth').replaceAll('{name}', name);
  String aiEmotionalAchieveSleepStable(String name) =>
      _t('aiEmotionalAchieveSleepStable').replaceAll('{name}', name);
  String aiEmotionalSpontSleepBetter(String name) =>
      _t('aiEmotionalSpontSleepBetter').replaceAll('{name}', name);
  String aiEmotionalSpontFeedingRegular(String name) =>
      _t('aiEmotionalSpontFeedingRegular').replaceAll('{name}', name);
  String aiEmotionalSpontDevelopment(String name, String hint) =>
      _t('aiEmotionalSpontDevelopment')
          .replaceAll('{name}', name)
          .replaceAll('{hint}', hint);
  String get aiEmotionalSpontSmilePhase => _t('aiEmotionalSpontSmilePhase');
  String aiEmotionalSpontEncouragement(String name) =>
      _t('aiEmotionalSpontEncouragement').replaceAll('{name}', name);
  String aiEmotionalSpontGentleCare(String name) =>
      _t('aiEmotionalSpontGentleCare').replaceAll('{name}', name);
  String get aiEmotionalDev1Month => _t('aiEmotionalDev1Month');
  String get aiEmotionalDev2Months => _t('aiEmotionalDev2Months');
  String get aiEmotionalDev3Months => _t('aiEmotionalDev3Months');
  String get aiEmotionalDev4to5Months => _t('aiEmotionalDev4to5Months');
  String get aiEmotionalDev6to8Months => _t('aiEmotionalDev6to8Months');
  String get aiEmotionalDev9to11Months => _t('aiEmotionalDev9to11Months');
  String get aiEmotionalDev12to23Months => _t('aiEmotionalDev12to23Months');
  String get aiEmotionalDevToddler => _t('aiEmotionalDevToddler');
  String get aiNannyMockReply => _t('aiNannyMockReply');
  String get aiNannyInputHint => _t('aiNannyInputHint');
  String get aiNannyThinking => _t('aiNannyThinking');
  String get aiNannyDisclaimer => _t('aiNannyDisclaimer');
  String get aiNannyPremiumTitle => _t('aiNannyPremiumTitle');
  String get aiNannyPremiumBody => _t('aiNannyPremiumBody');
  String get aiNannyPremiumCta => _t('aiNannyPremiumCta');
  String get aiNannyBenefitSmart => _t('aiNannyBenefitSmart');
  String get aiNannyBenefitPersonal => _t('aiNannyBenefitPersonal');
  String get aiNannyBenefitAlerts => _t('aiNannyBenefitAlerts');
  String get aiNannyBenefitRoutines => _t('aiNannyBenefitRoutines');
  String get aiNannyBenefitContent => _t('aiNannyBenefitContent');
  String get aiNannyBenefitAudioSoon => _t('aiNannyBenefitAudioSoon');
  String get aiNannyAskBelow => _t('aiNannyAskBelow');
  String get aiNannyNoBaby => _t('aiNannyNoBaby');
  String aiNannyRemainingToday(int n) =>
      _t('aiNannyRemainingToday').replaceAll('{n}', '$n');
  String get aiNannyDailyLimitMessage => _t('aiNannyDailyLimitMessage');
  String get aiNannyCallFailed => _t('aiNannyCallFailed');
  String get aiNannyProfileButton => _t('aiNannyProfileButton');
  String get aiNannyClearChat => _t('aiNannyClearChat');
  String get aiNannyClearChatConfirmTitle => _t('aiNannyClearChatConfirmTitle');
  String get aiNannyClearChatConfirmBody => _t('aiNannyClearChatConfirmBody');
  String get aiNannyClearChatDone => _t('aiNannyClearChatDone');
  String get aiNannyDeleteExchange => _t('aiNannyDeleteExchange');
  String get aiNannyDeleteExchangeConfirm => _t('aiNannyDeleteExchangeConfirm');
  String get aiNannySignInRequired => _t('aiNannySignInRequired');
  String aiVoiceRecording(int seconds) =>
      _t('aiVoiceRecording').replaceAll('{s}', '$seconds');
  String get aiVoiceProcessing => _t('aiVoiceProcessing');
  String aiVoiceUnderstood(String text) =>
      _t('aiVoiceUnderstood').replaceAll('{text}', text);
  String get aiVoiceConfirmTitle => _t('aiVoiceConfirmTitle');
  String get aiVoiceConfirm => _t('aiVoiceConfirm');
  String get aiVoiceMicDenied => _t('aiVoiceMicDenied');
  String get aiVoiceMicWebUnavailable => _t('aiVoiceMicWebUnavailable');
  String get aiVoiceSavedOk => _t('aiVoiceSavedOk');
  String get aiVoiceSavedFeedingAndDiaper => _t('aiVoiceSavedFeedingAndDiaper');
  String get aiVoiceSavedSymptom => _t('aiVoiceSavedSymptom');
  String get aiVoiceNeedClarification => _t('aiVoiceNeedClarification');
  String get aiClarifyBreastSide => _t('aiClarifyBreastSide');
  String get aiClarifyFeedingDuration => _t('aiClarifyFeedingDuration');
  String get aiClarifyRegisterNeeded => _t('aiClarifyRegisterNeeded');
  String get aiNannyRecordsFoundTitle => _t('aiNannyRecordsFoundTitle');
  String get aiNannyConfirmCompleteRecords => _t('aiNannyConfirmCompleteRecords');
  String get aiNannyCompleteMissingData => _t('aiNannyCompleteMissingData');
  String get aiNannySaveAllPossible => _t('aiNannySaveAllPossible');
  String get aiNannyCancelRecords => _t('aiNannyCancelRecords');
  String get aiGrowthNeedBaselineWeight => _t('aiGrowthNeedBaselineWeight');
  String get aiGrowthNeedBaselineHeight => _t('aiGrowthNeedBaselineHeight');
  String aiGrowthWeightDeltaPreview(double prevKg, double nextKg) =>
      _t('aiGrowthWeightDeltaPreview')
          .replaceAll('{prev}', prevKg.toStringAsFixed(3))
          .replaceAll('{next}', nextKg.toStringAsFixed(3));
  String aiGrowthHeightDeltaPreview(double prevCm, double nextCm) =>
      _t('aiGrowthHeightDeltaPreview')
          .replaceAll('{prev}', prevCm.toStringAsFixed(1))
          .replaceAll('{next}', nextCm.toStringAsFixed(1));
  String get aiClarifyFeedingType => _t('aiClarifyFeedingType');
  String get aiClarifyDiaperKind => _t('aiClarifyDiaperKind');
  String get aiClarifyDiaperChangeNow => _t('aiClarifyDiaperChangeNow');
  String get aiRecordSaveFailed => _t('aiRecordSaveFailed');
  String get aiRecordLineDiaperPee => _t('aiRecordLineDiaperPee');
  String get aiRecordLineDiaperPoo => _t('aiRecordLineDiaperPoo');
  String get aiRecordLineDiaperBoth => _t('aiRecordLineDiaperBoth');
  String get aiRecordLineDiaperGeneric => _t('aiRecordLineDiaperGeneric');
  String get aiRecordLineFeeding => _t('aiRecordLineFeeding');
  String get aiRecordLineSleepStart => _t('aiRecordLineSleepStart');
  String get aiRecordLineSleepEnd => _t('aiRecordLineSleepEnd');
  String get aiRecordLineSleep => _t('aiRecordLineSleep');
  String get aiRecordLineWeight => _t('aiRecordLineWeight');
  String get aiRecordLineHeight => _t('aiRecordLineHeight');
  String get aiRecordLineSymptom => _t('aiRecordLineSymptom');
  String aiRecordLineConsultation(String title) =>
      _t('aiRecordLineConsultation').replaceAll('{title}', title);
  String get aiRecordLineConsultationGeneric =>
      _t('aiRecordLineConsultationGeneric');
  String aiRecordLineVaccine(String name) =>
      _t('aiRecordLineVaccine').replaceAll('{name}', name);
  String get aiRecordLineVaccineGeneric => _t('aiRecordLineVaccineGeneric');
  String get aiRecordLineGeneric => _t('aiRecordLineGeneric');
  String aiRecordConfirmedPrefix(String name, String line, String time) =>
      _t('aiRecordConfirmedPrefix')
          .replaceAll('{name}', name)
          .replaceAll('{line}', line)
          .replaceAll('{time}', time);
  String aiVaccineScheduledConfirmed(String vaccineName, String dateLabel) =>
      _t('aiVaccineScheduledConfirmed')
          .replaceAll('{name}', vaccineName)
          .replaceAll('{date}', dateLabel);
  String aiBreastfeedingSavedSuccess(String sideLabel, int minutes) =>
      _t('aiBreastfeedingSavedSuccess')
          .replaceAll('{side}', sideLabel)
          .replaceAll('{minutes}', '$minutes');
  String get aiBreastfeedingSaveFailed => _t('aiBreastfeedingSaveFailed');
  String get aiClarifyFeedingPrefix => _t('aiClarifyFeedingPrefix');
  String get aiClarifyDiaperPrefix => _t('aiClarifyDiaperPrefix');
  String get aiClarifyBreastSideOptions => _t('aiClarifyBreastSideOptions');
  String get aiClarifyDiaperKindOptions => _t('aiClarifyDiaperKindOptions');
  String get aiClarifyFeedingTypeOptions => _t('aiClarifyFeedingTypeOptions');
  String get aiClarifyBottleAmount => _t('aiClarifyBottleAmount');
  String get aiClarifySleepStart => _t('aiClarifySleepStart');
  String get aiClarifyVaccineName => _t('aiClarifyVaccineName');
  String get aiClarifyVaccineDate => _t('aiClarifyVaccineDate');
  String get aiClarifyAppointmentReason => _t('aiClarifyAppointmentReason');
  String get aiClarifyAppointmentWhen => _t('aiClarifyAppointmentWhen');
  String get aiClarifyAppointmentAddress => _t('aiClarifyAppointmentAddress');
  String get aiClarifySymptomDetails => _t('aiClarifySymptomDetails');
  String get aiClarifyFeverTemperature => _t('aiClarifyFeverTemperature');
  String aiActionFirstNeedData(int n) =>
      _t('aiActionFirstNeedData').replaceAll('{n}', '$n');
  String aiActionFirstConfirmCard(int n) =>
      _t('aiActionFirstConfirmCard').replaceAll('{n}', '$n');
  String aiActionFirstSummaryHeader(int n) =>
      _t('aiActionFirstSummaryHeader').replaceAll('{n}', '$n');
  String get aiActionFirstFoundIntro => _t('aiActionFirstFoundIntro');
  String get aiActionFirstSummarySingle => _t('aiActionFirstSummarySingle');
  String get aiActionFirstFirstQuestionLead =>
      _t('aiActionFirstFirstQuestionLead');
  String get aiActionFirstNextQuestionLead => _t('aiActionFirstNextQuestionLead');
  String aiOrchestratorFinishSleepAndDiaper(String duration, String diaper) =>
      _t('aiOrchestratorFinishSleepAndDiaper')
          .replaceAll('{duration}', duration)
          .replaceAll('{diaper}', diaper);
  String aiOrchestratorFinishSleepOnly(String duration) =>
      _t('aiOrchestratorFinishSleepOnly').replaceAll('{duration}', duration);
  String aiOrchestratorFinishSleepWithStartedAt(String startedAt, String duration) =>
      _t('aiOrchestratorFinishSleepWithStartedAt')
          .replaceAll('{startedAt}', startedAt)
          .replaceAll('{duration}', duration);
  String aiOrchestratorFinishBreastfeeding(String side, String duration) =>
      _t('aiOrchestratorFinishBreastfeeding')
          .replaceAll('{side}', side)
          .replaceAll('{duration}', duration);
  String get aiOrchestratorDiaperBoth => _t('aiOrchestratorDiaperBoth');
  String get aiOrchestratorDiaperPee => _t('aiOrchestratorDiaperPee');
  String get aiOrchestratorDiaperPoo => _t('aiOrchestratorDiaperPoo');
  String get aiActionFirstNeedDataIntro => _t('aiActionFirstNeedDataIntro');
  String aiActionFirstAllComplete(int n) =>
      _t('aiActionFirstAllComplete').replaceAll('{n}', '$n');
  String get aiPendingAnswerAck => _t('aiPendingAnswerAck');
  String get aiFollowUpSleepStatusQuestion =>
      _t('aiFollowUpSleepStatusQuestion');
  String get aiFollowUpSleepDurationQuestion =>
      _t('aiFollowUpSleepDurationQuestion');
  String get aiSleepOptionFellAsleepNow => _t('aiSleepOptionFellAsleepNow');
  String get aiSleepOptionAlreadyWoke => _t('aiSleepOptionAlreadyWoke');
  String get aiRecordCardFeedingDetected => _t('aiRecordCardFeedingDetected');
  String get aiRecordCardDiaperDetected => _t('aiRecordCardDiaperDetected');
  String get aiRecordCardSleepDetected => _t('aiRecordCardSleepDetected');
  String get aiRecordCardSymptomDetected => _t('aiRecordCardSymptomDetected');
  String get aiRecordCardWeightDetected => _t('aiRecordCardWeightDetected');
  String get aiRecordCardHeightDetected => _t('aiRecordCardHeightDetected');
  String get aiRecordCardVaccineDetected => _t('aiRecordCardVaccineDetected');
  String get aiRecordCardAppointmentDetected =>
      _t('aiRecordCardAppointmentDetected');
  String get aiRecordFieldMethod => _t('aiRecordFieldMethod');
  String get aiRecordFieldSide => _t('aiRecordFieldSide');
  String get aiRecordFieldType => _t('aiRecordFieldType');
  String get aiRecordFieldTime => _t('aiRecordFieldTime');
  String get aiRecordFieldDuration => _t('aiRecordFieldDuration');
  String get aiRecordFieldAmount => _t('aiRecordFieldAmount');
  String get aiRecordFieldMissing => _t('aiRecordFieldMissing');
  String get aiRecordFieldNow => _t('aiRecordFieldNow');
  String get aiRecordFieldAction => _t('aiRecordFieldAction');
  String get aiRecordFieldTemperature => _t('aiRecordFieldTemperature');
  String get aiRecordFieldSymptoms => _t('aiRecordFieldSymptoms');
  String get aiRecordFieldValue => _t('aiRecordFieldValue');
  String get aiRecordFieldName => _t('aiRecordFieldName');
  String get aiRecordFieldStatus => _t('aiRecordFieldStatus');
  String get aiRecordFieldDate => _t('aiRecordFieldDate');
  String get aiRecordFieldReason => _t('aiRecordFieldReason');
  String get aiRecordFeedingBreast => _t('aiRecordFeedingBreast');
  String get aiRecordFeedingBottle => _t('aiRecordFeedingBottle');
  String get aiRecordFeedingFormula => _t('aiRecordFeedingFormula');
  String get aiRecordFeedingExpressed => _t('aiRecordFeedingExpressed');
  String get aiRecordSideLeft => _t('aiRecordSideLeft');
  String get aiRecordSideRight => _t('aiRecordSideRight');
  String get aiRecordSideBoth => _t('aiRecordSideBoth');
  String get aiPhaseTranscribing => _t('aiPhaseTranscribing');
  String get aiPhaseUnderstandingRecords => _t('aiPhaseUnderstandingRecords');
  String get aiPhaseUnderstanding => _t('aiPhaseUnderstanding');
  String get aiVoiceTranscriptionFailed => _t('aiVoiceTranscriptionFailed');
  String get aiPhaseIdentifying => _t('aiPhaseIdentifying');
  String get aiPhasePreparing => _t('aiPhasePreparing');
  String get aiPhaseSlowWarning => _t('aiPhaseSlowWarning');
  String get aiPhaseVerySlow => _t('aiPhaseVerySlow');
  String get aiPhaseShowingResults => _t('aiPhaseShowingResults');
  String get aiExtractionFallbackHint => _t('aiExtractionFallbackHint');
  String get aiConfirmNeedInfoTitle => _t('aiConfirmNeedInfoTitle');
  String get aiConfirmAndSaveRecords => _t('aiConfirmAndSaveRecords');
  String get aiConfirmReadyToSaveVoice => _t('aiConfirmReadyToSaveVoice');
  String get aiCardUnderstood => _t('aiCardUnderstood');
  String get aiCardMissing => _t('aiCardMissing');
  String get aiBadgeComplete => _t('aiBadgeComplete');
  String get aiBadgeMissingInfo => _t('aiBadgeMissingInfo');
  String get aiBadgeIncomplete => _t('aiBadgeIncomplete');
  String get aiRecordLabelBreastfeeding => _t('aiRecordLabelBreastfeeding');
  String get aiRecordLabelBottle => _t('aiRecordLabelBottle');
  String get aiRecordLabelFeeding => _t('aiRecordLabelFeeding');
  String get aiRecordLabelDiaper => _t('aiRecordLabelDiaper');
  String get aiRecordLabelSleep => _t('aiRecordLabelSleep');
  String get aiRecordLabelSymptom => _t('aiRecordLabelSymptom');
  String get aiRecordLabelGrowth => _t('aiRecordLabelGrowth');
  String get aiRecordLabelVaccine => _t('aiRecordLabelVaccine');
  String get aiRecordLabelAppointment => _t('aiRecordLabelAppointment');
  String get aiRecordLabelMemory => _t('aiRecordLabelMemory');
  String get aiConfirmCompleteToSaveHint => _t('aiConfirmCompleteToSaveHint');
  String get aiPendingSessionCancelled => _t('aiPendingSessionCancelled');
  String get aiPendingRepeatQuestionIntro => _t('aiPendingRepeatQuestionIntro');
  String get aiPendingAnswerRecorded => _t('aiPendingAnswerRecorded');
  String get aiPendingFinishInSheet => _t('aiPendingFinishInSheet');
  String get aiPendingMustFinishRecords => _t('aiPendingMustFinishRecords');
  String get aiPendingStateRetry => _t('aiPendingStateRetry');
  String get aiPendingRecordsIntroSingle => _t('aiPendingRecordsIntroSingle');
  String aiPendingRecordsIntroPlural(int n) =>
      _t('aiPendingRecordsIntroPlural').replaceAll('{n}', '$n');
  String aiPendingMissingFieldsLine(String fields) =>
      _t('aiPendingMissingFieldsLine').replaceAll('{fields}', fields);
  String get aiPendingGrowthMissingBaseline =>
      _t('aiPendingGrowthMissingBaseline');
  String aiPendingGrowthStatusDelta(int grams) =>
      _t('aiPendingGrowthStatusDelta').replaceAll('{grams}', '$grams');
  String aiPendingGrowthStatusHeightDelta(int cm) =>
      _t('aiPendingGrowthStatusHeightDelta').replaceAll('{cm}', '$cm');
  String aiPendingVaccineScheduledStatus(String when) =>
      _t('aiPendingVaccineScheduledStatus').replaceAll('{when}', when);
  String aiPendingVaccineNamedStatus(String name, String when) =>
      _t('aiPendingVaccineNamedStatus')
          .replaceAll('{name}', name)
          .replaceAll('{when}', when);
  String aiPendingVaccineAskNameWithWhen(String when) =>
      _t('aiPendingVaccineAskNameWithWhen').replaceAll('{when}', when);
  String aiPendingGrowthNeedLastWeight(int grams) =>
      _t('aiPendingGrowthNeedLastWeight').replaceAll('{grams}', '$grams');
  String aiPendingGrowthWeightDeltaConfirm(
    String prevKg,
    int grams,
    String nextKg,
  ) =>
      _t('aiPendingGrowthWeightDeltaConfirm')
          .replaceAll('{prev}', prevKg)
          .replaceAll('{grams}', '$grams')
          .replaceAll('{next}', nextKg);
  String get aiRecordWhenTomorrow => _t('aiRecordWhenTomorrow');
  String get aiRecordAtConnector => _t('aiRecordAtConnector');
  String get aiPendingRequiredFieldCannotSkip =>
      _t('aiPendingRequiredFieldCannotSkip');
  String get aiFollowUpBreastSideQuestion => _t('aiFollowUpBreastSideQuestion');
  String get aiFollowUpDurationQuestion => _t('aiFollowUpDurationQuestion');
  String get aiFollowUpBreastLeftDuration => _t('aiFollowUpBreastLeftDuration');
  String get aiFollowUpBreastRightDuration => _t('aiFollowUpBreastRightDuration');
  String get aiFollowUpDiaperTypeQuestion => _t('aiFollowUpDiaperTypeQuestion');
  String get aiPartialSaveSummaryHeader => _t('aiPartialSaveSummaryHeader');
  String aiPartialSaveLineSaved(String detail) =>
      _t('aiPartialSaveLineSaved').replaceAll('{detail}', detail);
  String aiPartialSaveLineNeedsInfo(String title) =>
      _t('aiPartialSaveLineNeedsInfo').replaceAll('{title}', title);
  String aiPartialSaveLineBreastNeedsDuration(String title, String side) =>
      _t('aiPartialSaveLineBreastNeedsDuration')
          .replaceAll('{title}', title)
          .replaceAll('{side}', side);
  String aiPartialSaveRecordFailed(String title, String reason) =>
      _t('aiPartialSaveRecordFailed')
          .replaceAll('{title}', title)
          .replaceAll('{reason}', reason);
  String get aiDiaperOptionPee => _t('aiDiaperOptionPee');
  String get aiDiaperOptionPoo => _t('aiDiaperOptionPoo');
  String get aiDiaperOptionBoth => _t('aiDiaperOptionBoth');
  String get aiRoutineRegisterSkipped => _t('aiRoutineRegisterSkipped');
  String get aiVoiceSavedFeeding => _t('aiVoiceSavedFeeding');
  String get aiVoiceSleepStarted => _t('aiVoiceSleepStarted');
  String get aiChatSleepStartedConfirm => _t('aiChatSleepStartedConfirm');
  String get aiChatSleepEndedConfirm => _t('aiChatSleepEndedConfirm');
  String get aiChatRegisterSavedConfirm => _t('aiChatRegisterSavedConfirm');
  String get aiVoiceSleepEnded => _t('aiVoiceSleepEnded');
  String get aiVoiceRecordFailed => _t('aiVoiceRecordFailed');
  String get aiVoiceNotARegisterTitle => _t('aiVoiceNotARegisterTitle');
  String get aiVoiceRegisterHint => _t('aiVoiceRegisterHint');
  String get aiVoiceHoldMicHint => _t('aiVoiceHoldMicHint');
  String get aiVoiceReleaseHint => _t('aiVoiceReleaseHint');
  String get aiVoiceTapMicHint => _t('aiVoiceTapMicHint');
  String get aiVoiceTapStopHint => _t('aiVoiceTapStopHint');
  String get aiVoiceRecordingHint => _t('aiVoiceRecordingHint');
  String get aiVoiceListenReply => _t('aiVoiceListenReply');
  String get aiTtsPreparing => _t('aiTtsPreparing');
  String get aiTtsPause => _t('aiTtsPause');
  String get aiTtsResume => _t('aiTtsResume');
  String get aiTtsRetry => _t('aiTtsRetry');
  String get aiNannyAutoReadLabel => _t('aiNannyAutoReadLabel');
  String get aiNannyDeviceVoiceHint => _t('aiNannyDeviceVoiceHint');
  String get aiNannyTtsFailed => _t('aiNannyTtsFailed');
  String get aiVoiceAskAiInstead => _t('aiVoiceAskAiInstead');
  String get aiVoiceHealthFieldsHint => _t('aiVoiceHealthFieldsHint');
  String get aiVoiceHealthTempLabel => _t('aiVoiceHealthTempLabel');
  String get aiVoiceHealthVaccineNameLabel => _t('aiVoiceHealthVaccineNameLabel');
  String get aiVoiceHealthVaccineDoseLabel => _t('aiVoiceHealthVaccineDoseLabel');
  String get aiVoiceHealthVaccineNameRequired =>
      _t('aiVoiceHealthVaccineNameRequired');
  String get aiBabyHistoryTitle => _t('aiBabyHistoryTitle');
  String get aiBabyHistorySubtitle => _t('aiBabyHistorySubtitle');
  String get aiBabyHistoryFieldLabel => _t('aiBabyHistoryFieldLabel');
  String get aiBabyHistoryPlaceholder => _t('aiBabyHistoryPlaceholder');
  String get aiBabyHistoryDisclaimer => _t('aiBabyHistoryDisclaimer');
  String get aiBabyHistorySave => _t('aiBabyHistorySave');
  String get aiBabyHistoryClear => _t('aiBabyHistoryClear');
  String get aiBabyHistorySaved => _t('aiBabyHistorySaved');
  String get aiBabyHistoryCleared => _t('aiBabyHistoryCleared');
  String get aiBabyHistoryClearConfirmTitle => _t('aiBabyHistoryClearConfirmTitle');
  String get aiBabyHistoryClearConfirmBody => _t('aiBabyHistoryClearConfirmBody');
  String get aiBabyHistoryLinkSubtitle => _t('aiBabyHistoryLinkSubtitle');
  String get settingsAiBabyHistory => _t('settingsAiBabyHistory');
  String aiBabyHistoryCharCount(int current, int max) => _t('aiBabyHistoryCharCount')
      .replaceAll('{current}', '$current')
      .replaceAll('{max}', '$max');
  String get familyTabTree => _t('familyTabTree');
  String get familyTabHoroscope => _t('familyTabHoroscope');
  String get familyTabHomily => _t('familyTabHomily');
  String get familyTabAiHistory => _t('familyTabAiHistory');
  String familyHoroscopeDate(String date) =>
      _t('familyHoroscopeDate').replaceAll('{date}', date);
  String get familyHoroscopeGenerateToday => _t('familyHoroscopeGenerateToday');
  String get familyHoroscopeRefresh => _t('familyHoroscopeRefresh');
  String get familyHoroscopeMother => _t('familyHoroscopeMother');
  String get familyHoroscopeFather => _t('familyHoroscopeFather');
  String get familyHoroscopeBaby => _t('familyHoroscopeBaby');
  String get familyHoroscopeFamilyEnergy => _t('familyHoroscopeFamilyEnergy');
  String get familyHoroscopeDailyAdvice => _t('familyHoroscopeDailyAdvice');
  String get familyHoroscopeDisclaimer => _t('familyHoroscopeDisclaimer');
  String get familyHoroscopeLoading => _t('familyHoroscopeLoading');
  String get familyHoroscopeOpenTabHint => _t('familyHoroscopeOpenTabHint');
  String get aiBubbleHoroscopeReady => _t('aiBubbleHoroscopeReady');
  String get aiBubbleHoroscopeOpenLink => _t('aiBubbleHoroscopeOpenLink');
  String familyHomilyDate(String date) =>
      _t('familyHomilyDate').replaceAll('{date}', date);
  String get familyHomilyLoading => _t('familyHomilyLoading');
  String get familyHomilyOpenTabHint => _t('familyHomilyOpenTabHint');
  String get familyHomilyLiturgicalDay => _t('familyHomilyLiturgicalDay');
  String get familyHomilyFeast => _t('familyHomilyFeast');
  String get familyHomilyGospel => _t('familyHomilyGospel');
  String get familyHomilyTitle => _t('familyHomilyTitle');
  String get familyHomilyFamilyReflection => _t('familyHomilyFamilyReflection');
  String get familyHomilyDisclaimer => _t('familyHomilyDisclaimer');
  String get familyHomilyPremiumTitle => _t('familyHomilyPremiumTitle');
  String get familyHomilyPremiumBody => _t('familyHomilyPremiumBody');
  String get aiBubbleHomilyReady => _t('aiBubbleHomilyReady');
  String get aiBubbleHomilyOpenLink => _t('aiBubbleHomilyOpenLink');
  String get aiBubbleCuriosityTitle => _t('aiBubbleCuriosityTitle');
  String get aiBubbleDailyBriefTitle => _t('aiBubbleDailyBriefTitle');

  String familyHomilyError(String code, {String? serverMessage}) {
    switch (code) {
      case 'not-found':
        return _t('familyHomilyErrorNotFound');
      case 'unauthenticated':
        return _t('familyHomilyErrorUnauthenticated');
      case 'permission-denied':
        return _t('familyHomilyErrorPermission');
      case 'failed-precondition':
        return _t('familyHomilyErrorPrecondition');
      case 'resource-exhausted':
        return _t('familyHomilyErrorExhausted');
      default:
        return _t('familyHomilyErrorGeneric');
    }
  }
  String get familyHoroscopeRegisterFather => _t('familyHoroscopeRegisterFather');
  String get familyHoroscopePremiumTitle => _t('familyHoroscopePremiumTitle');
  String get familyHoroscopePremiumBody => _t('familyHoroscopePremiumBody');

  String familyHoroscopeError(String code, {String? serverMessage}) {
    final sm = serverMessage?.trim();
    switch (code) {
      case 'not-found':
        return _t('familyHoroscopeErrorNotFound');
      case 'unauthenticated':
        return _t('familyHoroscopeErrorUnauthenticated');
      case 'permission-denied':
        return _t('familyHoroscopeErrorPermission');
      case 'failed-precondition':
        if (sm != null && sm.isNotEmpty) return sm;
        return _t('familyHoroscopeErrorPrecondition');
      case 'resource-exhausted':
        return _t('familyHoroscopeErrorExhausted');
      default:
        if (sm != null && sm.isNotEmpty) return sm;
        return _t('familyHoroscopeErrorGeneric');
    }
  }
  String get appUpdateAvailableMessage => _t('appUpdateAvailableMessage');
  String get appUpdateDownloading => _t('appUpdateDownloading');
  String get appUpdateReadyToRestart => _t('appUpdateReadyToRestart');
  String get appUpdateActionUpdate => _t('appUpdateActionUpdate');
  String get appUpdateActionLater => _t('appUpdateActionLater');
  String get appUpdateRestart => _t('appUpdateRestart');
  String feedingAgoMinutes(int m) =>
      _t('feedingAgoMinutes').replaceAll('{m}', '$m');
  String feedingAgoHours(int h, String mPadded) =>
      _t('feedingAgoHours').replaceAll('{h}', '$h').replaceAll('{m}', mPadded);
  String feedingNextInMinutes(int n) =>
      _t('feedingNextIn').replaceAll('{n}', '$n');
  String feedingHistoryLine(int minutes, String side) =>
      _t('feedingHistoryLine')
          .replaceAll('{time}', '$minutes')
          .replaceAll('{side}', side);
  String feedingAvgDurMinutes(int m) =>
      _t('feedingAvgDurFmt').replaceAll('{m}', '$m');
  String feedingAvgIntervalFmt(int h, String mPadded) =>
      _t('feedingAvgIntervalFmt')
          .replaceAll('{h}', '$h')
          .replaceAll('{m}', mPadded);
  String regZodiacLine(String sign) =>
      _t('regZodiacLine').replaceAll('{sign}', sign);
  String regPromptBabyNameLine(String mom) =>
      _t('regPromptBabyName').replaceAll('{mom}', mom);
  String regListBabyLine(String name) =>
      _t('regListBaby').replaceAll('{name}', name);
  String regListBirthLine(String date) =>
      _t('regListBirth').replaceAll('{date}', date);
  String regListSignLine(String sign) =>
      _t('regListSign').replaceAll('{sign}', sign);
  String regListPhoneLine(String phone) =>
      _t('regListPhone').replaceAll('{phone}', phone);
  String regMomDisplay(String? mName) {
    final t = (mName == null || mName.isEmpty)
        ? regMomGeneric
        : regMomWithName(mName);
    return t;
  }

  String regMomWithName(String name) =>
      _t('regMomWithName').replaceAll('{name}', name);

  String get add => _t('add');
  String get labelWeight => _t('labelWeight');
  String get labelHeight => _t('labelHeight');
  String get momNoteHint => _t('momNoteHint');
  String get shortcutDiaper => _t('shortcutDiaper');
  String get diaperPagePlaceholder => _t('diaperPagePlaceholder');
  String get shortcutHealth => _t('shortcutHealth');
  String get shortcutHealthSubtitle => _t('shortcutHealthSubtitle');
  String get shortcutFamily => _t('shortcutFamily');
  String get shortcutFamilyHomeSub => _t('shortcutFamilyHomeSub');
  String get shortcutHealthHomeSub => _t('shortcutHealthHomeSub');
  String get shortcutFeedingSession => _t('shortcutFeedingSession');
  String get shortcutFeedingSessionSub => _t('shortcutFeedingSessionSub');
  String get healthHubTitle => _t('healthHubTitle');
  String get healthHubIntro => _t('healthHubIntro');
  String get healthHubSection => _t('healthHubSection');
  String get healthHubVaccines => _t('healthHubVaccines');
  String get healthHubVaccinesSub => _t('healthHubVaccinesSub');
  String get vaccineReminderNotifTitle => _t('vaccineReminderNotifTitle');
  String vaccineReminderNotifBody(String name) =>
      _t('vaccineReminderNotifBody').replaceAll('{name}', name);
  String get homeBannerChipVaccine => _t('homeBannerChipVaccine');
  String get vaccDueConfirmCheckbox => _t('vaccDueConfirmCheckbox');
  String get vaccDueSavedOk => _t('vaccDueSavedOk');
  String get vaccDuePickTitle => _t('vaccDuePickTitle');
  String get healthHubConsultations => _t('healthHubConsultations');
  String get healthHubConsultationsSub => _t('healthHubConsultationsSub');
  String get healthHubSymptomReports => _t('healthHubSymptomReports');
  String get healthHubSymptomReportsSub => _t('healthHubSymptomReportsSub');
  String get symptomReportTitle => _t('symptomReportTitle');
  String get symptomReportEmpty => _t('symptomReportEmpty');
  String get symptomReportNew => _t('symptomReportNew');
  String get symptomReportSave => _t('symptomReportSave');
  String get symptomReportOccurredAt => _t('symptomReportOccurredAt');
  String get symptomReportPickDateTime => _t('symptomReportPickDateTime');
  String get symptomReportMedication => _t('symptomReportMedication');
  String get symptomReportMedicationHint => _t('symptomReportMedicationHint');
  String get symptomReportFever => _t('symptomReportFever');
  String get symptomReportTemp => _t('symptomReportTemp');
  String get symptomReportTempHint => _t('symptomReportTempHint');
  String get symptomReportCrying => _t('symptomReportCrying');
  String get symptomReportPain => _t('symptomReportPain');
  String get symptomReportColic => _t('symptomReportColic');
  String get symptomReportReflux => _t('symptomReportReflux');
  String get symptomReportOther => _t('symptomReportOther');
  String get symptomReportOtherHint => _t('symptomReportOtherHint');
  String get symptomReportValidationNeedOne =>
      _t('symptomReportValidationNeedOne');
  String get symptomReportValidationFeverTemp =>
      _t('symptomReportValidationFeverTemp');
  String get symptomReportDeleteTitle => _t('symptomReportDeleteTitle');
  String get symptomReportDeleteBody => _t('symptomReportDeleteBody');
  String get consultationsTitle => _t('consultationsTitle');
  String get consultationsIntro => _t('consultationsIntro');
  String get consultationsSoonTitle => _t('consultationsSoonTitle');
  String get consultationsComingBody => _t('consultationsComingBody');
  String get homeSummaryHealthStripTitle => _t('homeSummaryHealthStripTitle');
  String get homeSummaryHealthStripEmpty => _t('homeSummaryHealthStripEmpty');
  String get consultationTitleLabel => _t('consultationTitleLabel');
  String get consultationNotesHint => _t('consultationNotesHint');
  String get consultationWhenLabel => _t('consultationWhenLabel');
  String get consultationTitleEmpty => _t('consultationTitleEmpty');
  String get consultationPhoneLabel => _t('consultationPhoneLabel');
  String get consultationAddressLabel => _t('consultationAddressLabel');
  String get consultationDetailWhen => _t('consultationDetailWhen');
  String get consultationDetailPhone => _t('consultationDetailPhone');
  String get consultationDetailAddress => _t('consultationDetailAddress');
  String get consultationDetailNotes => _t('consultationDetailNotes');
  String get consultationReminderNotifTitle =>
      _t('consultationReminderNotifTitle');
  String consultationReminderNotifBody(String title, String whenFormatted) =>
      _t('consultationReminderNotifBody')
          .replaceAll('{title}', title)
          .replaceAll('{when}', whenFormatted);

  /// Lembrete no **dia** da consulta (push imediato / banner), por oposição a “amanhã”.
  String consultationTodayReminderNotifBody(
          String title, String whenFormatted) =>
      _t('consultationTodayReminderNotifBody')
          .replaceAll('{title}', title)
          .replaceAll('{when}', whenFormatted);
  String homeConsultationBannerChip(String title, String timeHm) =>
      _t('homeConsultationBannerChip')
          .replaceAll('{title}', title)
          .replaceAll('{t}', timeHm);
  String get consultationsEmpty => _t('consultationsEmpty');
  String get consultationsDayEmpty => _t('consultationsDayEmpty');
  String get feedingSessionTitle => _t('feedingSessionTitle');
  String get feedingSessionIntro => _t('feedingSessionIntro');
  String get feedingSessionSoonTitle => _t('feedingSessionSoonTitle');
  String get feedingSessionSoonBody => _t('feedingSessionSoonBody');
  String get settingsFeedingEarlyTitle => _t('settingsFeedingEarlyTitle');
  String get settingsFeedingEarlySub => _t('settingsFeedingEarlySub');
  String get settingsAiMicTitle => _t('settingsAiMicTitle');
  String get settingsAiMicSub => _t('settingsAiMicSub');
  String get reportNoWeight => _t('reportNoWeight');
  String get reportNoHeight => _t('reportNoHeight');
  String get memoriesPhotoError => _t('memoriesPhotoError');
  String get memoriesTodayTitle => _t('memoriesTodayTitle');
  String get memoriesTodayAsk => _t('memoriesTodayAsk');
  String get memoriesNotYet => _t('memoriesNotYet');
  String get memoriesAddPhotoDialog => _t('memoriesAddPhotoDialog');
  String get memoriesAlreadyPostedToday => _t('memoriesAlreadyPostedToday');
  String get memoriesWallEmpty => _t('memoriesWallEmpty');
  String get memoriesHighlights => _t('memoriesHighlights');
  String get memoriesWallSection => _t('memoriesWallSection');
  String get settingsMotherProfile => _t('settingsMotherProfile');
  String get profileEditMother => _t('profileEditMother');
  String get profileEditFather => _t('profileEditFather');
  String get profileAddFather => _t('profileAddFather');
  String get profileFatherNotRegisteredTitle =>
      _t('profileFatherNotRegisteredTitle');
  String get profileFatherNotRegisteredSubtitle =>
      _t('profileFatherNotRegisteredSubtitle');
  String get profileFatherAddCta => _t('profileFatherAddCta');
  String get profileEditBaby => _t('profileEditBaby');
  String get profileDataSaved => _t('profileDataSaved');
  String get profileEditData => _t('profileEditData');
  String get contactTitle => _t('contactTitle');
  String get contactIntro => _t('contactIntro');
  String get contactFieldName => _t('contactFieldName');
  String get contactFieldEmail => _t('contactFieldEmail');
  String get contactFieldAge => _t('contactFieldAge');
  String get contactFieldMessage => _t('contactFieldMessage');
  String get contactSend => _t('contactSend');
  String get contactEmailSubject => _t('contactEmailSubject');
  String get contactBodyName => _t('contactBodyName');
  String get contactBodyEmail => _t('contactBodyEmail');
  String get contactBodyAge => _t('contactBodyAge');
  String get contactBodyMessage => _t('contactBodyMessage');
  String get contactCouldNotOpenEmail => _t('contactCouldNotOpenEmail');
  String get contactValidationRequired => _t('contactValidationRequired');
  String get contactValidationEmail => _t('contactValidationEmail');
  String get contactValidationAge => _t('contactValidationAge');
  String get motherProfileTabPreferences => _t('motherProfileTabPreferences');
  String get motherProfileTabMother => _t('motherProfileTabMother');
  String get motherProfileTabFather => _t('motherProfileTabFather');
  String get motherProfileTabBabies => _t('motherProfileTabBabies');
  String get profileLayoutTitle => _t('profileLayoutTitle');
  String get profileLayoutSubtitle => _t('profileLayoutSubtitle');
  String get profileLayoutAutomatic => _t('profileLayoutAutomatic');
  String get profileLayoutDay => _t('profileLayoutDay');
  String get profileLayoutNight => _t('profileLayoutNight');
  String get profileLayoutUpdating => _t('profileLayoutUpdating');
  String get motherProfileFieldFatherName => _t('motherProfileFieldFatherName');
  String get motherProfileNoData => _t('motherProfileNoData');
  String get motherProfileSectionInfo => _t('motherProfileSectionInfo');
  String get motherProfileFieldPhone => _t('motherProfileFieldPhone');
  String get motherProfileFieldBirth => _t('motherProfileFieldBirth');
  String get motherProfileFieldHeight => _t('motherProfileFieldHeight');
  String get motherProfileFieldFatherHeight =>
      _t('motherProfileFieldFatherHeight');
  String get profileFamilyMessagesTitle => _t('profileFamilyMessagesTitle');
  String get profileShowChristian => _t('profileShowChristian');
  String get profileShowHoroscope => _t('profileShowHoroscope');
  String get profileShowPhilosophical => _t('profileShowPhilosophical');
  String get profileShowSpiritist => _t('profileShowSpiritist');
  String get profileShowJewish => _t('profileShowJewish');
  String get motherProfileAddBaby => _t('motherProfileAddBaby');
  String get motherProfileNoBabies => _t('motherProfileNoBabies');
  String motherProfileBabyBornAt(String date) =>
      _t('motherProfileBabyBornAt').replaceAll('{date}', date);
  String get settingsBabyData => _t('settingsBabyData');
  String get settingsAlerts => _t('settingsAlerts');
  String get alertsScreenIntro => _t('alertsScreenIntro');
  String get alertsExactAlarmAndroidTitle => _t('alertsExactAlarmAndroidTitle');
  String get alertsExactAlarmAndroidBody => _t('alertsExactAlarmAndroidBody');
  String get alertsExactAlarmAndroidOpenSettings =>
      _t('alertsExactAlarmAndroidOpenSettings');
  String get alertsSectionFeeding => _t('alertsSectionFeeding');
  String get alertsRuleFeeding => _t('alertsRuleFeeding');
  String get alertsSectionDiaper => _t('alertsSectionDiaper');
  String get alertsRuleDiaper => _t('alertsRuleDiaper');
  String get alertsSectionSleep => _t('alertsSectionSleep');
  String get alertsRuleSleep => _t('alertsRuleSleep');
  String get alertsSectionGrowth => _t('alertsSectionGrowth');
  String get alertsRuleGrowth => _t('alertsRuleGrowth');
  String get alertsTestTitle => _t('alertsTestTitle');
  String get alertsTestBody => _t('alertsTestBody');
  String get alertsTestRun => _t('alertsTestRun');
  String get alertsTestResync => _t('alertsTestResync');
  String get alertsTestImmediateTitle => _t('alertsTestImmediateTitle');
  String get alertsTestImmediateBody => _t('alertsTestImmediateBody');
  String get alertsTestScheduledTitle => _t('alertsTestScheduledTitle');
  String get alertsTestScheduledBody => _t('alertsTestScheduledBody');
  String get alertsTestAllScheduleModesFailed =>
      _t('alertsTestAllScheduleModesFailed');
  String get alertsTestSentOk => _t('alertsTestSentOk');
  String alertsTestFailed(String errors) =>
      _t('alertsTestFailed').replaceAll('{errors}', errors);
  String get settingsPrivacy => _t('settingsPrivacy');
  String get settingsSaaS => _t('settingsSaaS');
  String get loadingMotherPhoto => _t('loadingMotherPhoto');
  String get loadingBabyPhoto => _t('loadingBabyPhoto');
  String get loadingBabies => _t('loadingBabies');
  String get gateLoadProfilesError => _t('gateLoadProfilesError');
  String get gateRetry => _t('gateRetry');
  String get pickBabyTitle => _t('pickBabyTitle');
  String get switchingBaby => _t('switchingBaby');
  String get sleepAppBar => _t('sleepAppBar');
  String get sleepTitle => _t('sleepTitle');
  String get sleepIntro => _t('sleepIntro');
  String get sleepComingTitle => _t('sleepComingTitle');
  String get sleepComingBody => _t('sleepComingBody');
  String get sleepSessionTitle => _t('sleepSessionTitle');
  String sleepSessionStartedAt(String time) =>
      _t('sleepSessionStartedAt').replaceAll('{time}', time);
  String get sleepStatusSleeping => _t('sleepStatusSleeping');
  String get sleepStatusPaused => _t('sleepStatusPaused');
  String get sleepWakeButton => _t('sleepWakeButton');
  String get sleepThisCardTitle => _t('sleepThisCardTitle');
  String get sleepLabelStart => _t('sleepLabelStart');
  String get sleepLabelEnd => _t('sleepLabelEnd');
  String get sleepLabelDuration => _t('sleepLabelDuration');
  String get sleepLabelQuality => _t('sleepLabelQuality');
  String get sleepObservationsTitle => _t('sleepObservationsTitle');
  String get sleepObservationHint => _t('sleepObservationHint');
  String get sleepPause => _t('sleepPause');
  String get sleepResume => _t('sleepResume');
  String get sleepCancelSession => _t('sleepCancelSession');
  String get sleepStartButton => _t('sleepStartButton');
  String get sleepSavedOk => _t('sleepSavedOk');
  String get sleepResultDialogTitle => _t('sleepResultDialogTitle');
  String get sleepResultShortTitle => _t('sleepResultShortTitle');
  String get sleepResultExpectedTitle => _t('sleepResultExpectedTitle');
  String get sleepResultLongTitle => _t('sleepResultLongTitle');
  String sleepResultDurationLine(String duration) =>
      _t('sleepResultDurationLine').replaceAll('{duration}', duration);
  String sleepResultExpectedLine(int min, int max) =>
      _t('sleepResultExpectedLine')
          .replaceAll('{min}', '$min')
          .replaceAll('{max}', '$max');
  String get sleepResultShortBody => _t('sleepResultShortBody');
  String get sleepResultExpectedBody => _t('sleepResultExpectedBody');
  String get sleepResultLongBody => _t('sleepResultLongBody');
  String get sleepConfirmBackTitle => _t('sleepConfirmBackTitle');
  String get sleepConfirmBackBody => _t('sleepConfirmBackBody');
  String get sleepConfirmCancelSessionTitle =>
      _t('sleepConfirmCancelSessionTitle');
  String get sleepConfirmCancelSessionBody =>
      _t('sleepConfirmCancelSessionBody');
  String get sleepDiscard => _t('sleepDiscard');
  String get sleepHistoryTitle => _t('sleepHistoryTitle');
  String get sleepHistoryEmpty => _t('sleepHistoryEmpty');
  String get historyShowButton => _t('historyShowButton');
  String get historyHideButton => _t('historyHideButton');
  String get historyViewMoreButton => _t('historyViewMoreButton');
  String get sleepUpdatedOk => _t('sleepUpdatedOk');
  String sleepBannerNextNap(int min) =>
      _t('sleepBannerNextNap').replaceAll('{min}', '$min');
  String get sleepWindowTitle => _t('sleepWindowTitle');
  String get sleepWindowEarly => _t('sleepWindowEarly');
  String get sleepWindowIdeal => _t('sleepWindowIdeal');
  String get sleepWindowLate => _t('sleepWindowLate');
  String sleepRoutineLastLabel(String ago) =>
      _t('sleepRoutineLastLabel').replaceAll('{ago}', ago);
  String get sleepRoutineLastNever => _t('sleepRoutineLastNever');
  String get sleepRoutineNextPrefix => _t('sleepRoutineNextPrefix');
  String sleepNextApproxMin(int min) =>
      _t('sleepNextApproxMin').replaceAll('{min}', '$min');
  String get sleepRoutineNextNow => _t('sleepRoutineNextNow');
  String get sleepStatusEarly => _t('sleepStatusEarly');
  String get sleepStatusIdeal => _t('sleepStatusIdeal');
  String get sleepStatusOverdue => _t('sleepStatusOverdue');
  String get sleepHeroAwakeBadge => _t('sleepHeroAwakeBadge');
  String get sleepHeroAwakeCaption => _t('sleepHeroAwakeCaption');
  String get sleepHeroSleepingBadge => _t('sleepHeroSleepingBadge');
  String get sleepHeroSleepingCaption => _t('sleepHeroSleepingCaption');
  String get sleepRoutineCardTitle => _t('sleepRoutineCardTitle');
  String sleepRoutineStatusLine(String status) =>
      _t('sleepRoutineStatusLine').replaceAll('{status}', status);

  /// Limites de vigília vêm da tabela fixa do app (ver `SleepRoutine`) — não há registo nas Definições.
  String sleepRoutineVigilHighlight(int min, int max) =>
      _t('sleepRoutineVigilHighlight')
          .replaceAll('{min}', '$min')
          .replaceAll('{max}', '$max');
  String get sleepIdealForAge => _t('sleepIdealForAge');
  String sleepAgeMonthsLabel(int n) =>
      _t('sleepAgeMonthsLabel').replaceAll('{n}', '$n');
  String sleepWindowMinMax(int min, int max) => _t('sleepWindowMinMax')
      .replaceAll('{min}', '$min')
      .replaceAll('{max}', '$max');
  String get sleepLegendG => _t('sleepLegendG');
  String get sleepLegendY => _t('sleepLegendY');
  String get sleepLegendR => _t('sleepLegendR');
  String get sleepWakeWindowExplainer => _t('sleepWakeWindowExplainer');
  String get sleepFinalizeButton => _t('sleepFinalizeButton');
  String sleepSleepingFor(String when) =>
      _t('sleepSleepingFor').replaceAll('{when}', when);
  String get sleepInsightTitle => _t('sleepInsightTitle');
  String sleepInsightNaps(int n) =>
      _t('sleepInsightNaps').replaceAll('{n}', '$n');
  String sleepInsightAvg(int min) =>
      _t('sleepInsightAvg').replaceAll('{min}', '$min');
  String get sleepInsightTrendDown => _t('sleepInsightTrendDown');
  String get sleepInsightTrendOk => _t('sleepInsightTrendOk');
  String get sleepHistoryToday => _t('sleepHistoryToday');
  String get sleepToggleAlerts => _t('sleepToggleAlerts');
  String get sleepToggleAlertsSubtitle => _t('sleepToggleAlertsSubtitle');
  String sleepAlertsWakeWindowRulerValueAuto(int m) =>
      _t('sleepAlertsWakeWindowRulerValueAuto').replaceAll('{m}', '$m');
  String sleepAlertsWakeWindowRulerValueCustom(int m) =>
      _t('sleepAlertsWakeWindowRulerValueCustom').replaceAll('{m}', '$m');
  String sleepAlertsWakeWindowSliderLabelAuto(int m) =>
      _t('sleepAlertsWakeWindowSliderLabelAuto').replaceAll('{m}', '$m');
  String sleepAlertsWakeWindowSliderLabelCustom(int m) =>
      _t('sleepAlertsWakeWindowSliderLabelCustom').replaceAll('{m}', '$m');
  String sleepAlertsApproachRulerValueDefault(int m) =>
      _t('sleepAlertsApproachRulerValueDefault').replaceAll('{m}', '$m');
  String sleepAlertsApproachRulerValueCustom(int m) =>
      _t('sleepAlertsApproachRulerValueCustom').replaceAll('{m}', '$m');
  String sleepAlertsApproachSliderLabelDefault(int m) =>
      _t('sleepAlertsApproachSliderLabelDefault').replaceAll('{m}', '$m');
  String sleepAlertsApproachSliderLabelCustom(int m) =>
      _t('sleepAlertsApproachSliderLabelCustom').replaceAll('{m}', '$m');
  String sleepAlertsWakeWindowAutomatic(int m) =>
      _t('sleepAlertsWakeWindowAutomatic').replaceAll('{m}', '$m');
  String sleepAlertsWakeWindowAutomaticNoBirth(int m) =>
      _t('sleepAlertsWakeWindowAutomaticNoBirth').replaceAll('{m}', '$m');
  String sleepAlertsMonthsApprox(int n) =>
      _t('sleepAlertsMonthsApprox').replaceAll('{n}', '$n');
  String sleepAlertsWakeWindowCustom(int m) =>
      _t('sleepAlertsWakeWindowCustom').replaceAll('{m}', '$m');
  String sleepAlertsApproachAuto(int m) =>
      _t('sleepAlertsApproachAuto').replaceAll('{m}', '$m');
  String sleepAlertsApproachCustom(int m) =>
      _t('sleepAlertsApproachCustom').replaceAll('{m}', '$m');
  String get diaperToggleAlerts => _t('diaperToggleAlerts');
  String get diaperToggleAlertsSubtitle => _t('diaperToggleAlertsSubtitle');
  String get healthGrowthToggleAlerts => _t('healthGrowthToggleAlerts');
  String get healthGrowthToggleAlertsSubtitle =>
      _t('healthGrowthToggleAlertsSubtitle');
  String get feedingScreenAlertsHint => _t('feedingScreenAlertsHint');
  String get sleepNotifTitle => _t('sleepNotifTitle');
  String get sleepNotifBeforeBody => _t('sleepNotifBeforeBody');
  String get sleepNotifOverdueBody => _t('sleepNotifOverdueBody');
  String sleepNotifWakeOverdueBodyForBabySex(
      {required String? sex, required int hours}) {
    final key = _isMaleBabySex(sex)
        ? 'sleepNotifWakeOverdueBodyMale'
        : 'sleepNotifWakeOverdueBodyFemale';
    return _t(key).replaceAll('{hours}', '$hours');
  }

  /// Nomes/descrições dos canais Android (definições do sistema).
  String get notifChannelRemindersName => _t('notifChannelRemindersName');
  String get notifChannelRemindersDesc => _t('notifChannelRemindersDesc');
  String get notifChannelGrowthName => _t('notifChannelGrowthName');
  String get notifChannelGrowthDesc => _t('notifChannelGrowthDesc');

  String get diaperIntro => _t('diaperIntro');
  String get diaperSavedOk => _t('diaperSavedOk');
  String get diaperUpdatedOk => _t('diaperUpdatedOk');
  String get diaperHistoryTitle => _t('diaperHistoryTitle');
  String get diaperHistoryEmpty => _t('diaperHistoryEmpty');
  String get diaperKindPee => _t('diaperKindPee');
  String get diaperKindPoo => _t('diaperKindPoo');
  String get diaperKindBoth => _t('diaperKindBoth');
  String get diaperKindLabel => _t('diaperKindLabel');
  String get diaperDashTitle => _t('diaperDashTitle');
  String get diaperDashLastPee => _t('diaperDashLastPee');
  String get diaperDashLastPoo => _t('diaperDashLastPoo');
  String get diaperDashNoRecordYet => _t('diaperDashNoRecordYet');
  String get diaperDashJustNow => _t('diaperDashJustNow');

  /// Ex.: `{ago}` = `15\u00A0min` ou `2h\u00A005`.
  String diaperDashAgoLine(String compactAgo) =>
      _t('diaperDashAgoLine').replaceAll('{ago}', compactAgo);
  String get diaperChangedAtLabel => _t('diaperChangedAtLabel');
  String get diaperNoteOptional => _t('diaperNoteOptional');
  String get feedingTitle => _t('feedingTitle');
  String get feedingSelectBabyFirst => _t('feedingSelectBabyFirst');
  String get feedingNoRunning => _t('feedingNoRunning');
  String get feedingSavedOk => _t('feedingSavedOk');
  String get feedingSaveFail => _t('feedingSaveFail');
  String get feedingSaving => _t('feedingSaving');
  String get feedingQuickSummary => _t('feedingQuickSummary');
  String get feedingNoBabyHint => _t('feedingNoBabyHint');
  String get feedingPickBabyLabel => _t('feedingPickBabyLabel');
  String get feedingEmptyDataHint => _t('feedingEmptyDataHint');
  String get feedingLast => _t('feedingLast');
  String get feedingNextEst => _t('feedingNextEst');
  String get feedingStatusOk => _t('feedingStatusOk');
  String get feedingStatusLate => _t('feedingStatusLate');
  String get feedingStatusWarn => _t('feedingStatusWarn');
  String get feedingFinish => _t('feedingFinish');
  String get feedingStart => _t('feedingStart');
  String get feedingAfterFinish => _t('feedingAfterFinish');
  String get feedingTypeBreast => _t('feedingTypeBreast');
  String get feedingTypeBottle => _t('feedingTypeBottle');
  String get feedingTypeLabel => _t('feedingTypeLabel');
  String get feedingSideLeft => _t('feedingSideLeft');
  String get feedingSideRight => _t('feedingSideRight');
  String get feedingSideBoth => _t('feedingSideBoth');
  String get feedingSideLabel => _t('feedingSideLabel');
  String get feedingQty => _t('feedingQty');
  String get feedingQtyMl => _t('feedingQtyMl');
  String get feedingNote => _t('feedingNote');
  String get feedingHintRunning => _t('feedingHintRunning');
  String get feedingHintIdle => _t('feedingHintIdle');
  String get feedingHistory => _t('feedingHistory');
  String get feedingNoRecords => _t('feedingNoRecords');
  String get feedingInsights => _t('feedingInsights');
  String get feedingInsightsNeed => _t('feedingInsightsNeed');
  String get feedingAlertSection => _t('feedingAlertSection');
  String get feedingAlertTitle => _t('feedingAlertTitle');
  String get feedingModeAvg => _t('feedingModeAvg');
  String get feedingModeManual => _t('feedingModeManual');
  String get feedingNotifyNote => _t('feedingNotifyNote');
  String get feedingDurationShort => _t('feedingDurationShort');
  String get feedingDurationSeconds => _t('feedingDurationSeconds');
  String get feedingTabBreastfeeding => _t('feedingTabBreastfeeding');
  String get feedingTabBottle => _t('feedingTabBottle');
  String get feedingTabSolids => _t('feedingTabSolids');
  String get feedingTypeSolid => _t('feedingTypeSolid');
  String get feedingHubTapSidesHint => _t('feedingHubTapSidesHint');
  String get feedingHubLetterLeft => _t('feedingHubLetterLeft');
  String get feedingHubLetterRight => _t('feedingHubLetterRight');
  String get feedingHubAddManualEntry => _t('feedingHubAddManualEntry');
  String get feedingHubOverviewTitle => _t('feedingHubOverviewTitle');
  String get feedingHubManualTitle => _t('feedingHubManualTitle');
  String get feedingHubManualMinutes => _t('feedingHubManualMinutes');
  String get feedingHubManualInvalid => _t('feedingHubManualInvalid');
  String get feedingHubSaveBottle => _t('feedingHubSaveBottle');
  String get feedingHubSaveSolid => _t('feedingHubSaveSolid');
  String get feedingHubSolidDescribe => _t('feedingHubSolidDescribe');
  String get feedingHubSolidRequired => _t('feedingHubSolidRequired');
  String get feedingHubOverviewEmpty => _t('feedingHubOverviewEmpty');
  String get feedingHubMlRequired => _t('feedingHubMlRequired');
  String get memoryDeleteBadgeTitle => _t('memoryDeleteBadgeTitle');
  String get memoryDeleteBadgeBody => _t('memoryDeleteBadgeBody');
  String get feedingHubTimerTooShort => _t('feedingHubTimerTooShort');
  String get feedingHubBreastPieTitle => _t('feedingHubBreastPieTitle');
  String get feedingHubBreastPieEmpty => _t('feedingHubBreastPieEmpty');
  String get feedingHubFeedingUpdatedOk => _t('feedingHubFeedingUpdatedOk');
  String get vaccAddTitle => _t('vaccAddTitle');
  String get vaccNameField => _t('vaccNameField');
  String get vaccDoseOpt => _t('vaccDoseOpt');
  String get vaccDoseHint => _t('vaccDoseHint');
  String get vaccApplied => _t('vaccApplied');
  String get vaccNext => _t('vaccNext');
  String get vaccNotesOpt => _t('vaccNotesOpt');
  String get vaccNameEmpty => _t('vaccNameEmpty');
  String get vaccSaving => _t('vaccSaving');
  String get vaccUpdatedOk => _t('vaccUpdatedOk');
  String get vaccNoBabies => _t('vaccNoBabies');
  String get vaccTableVac => _t('vaccTableVac');
  String get vaccTableDose => _t('vaccTableDose');
  String get vaccTableDate => _t('vaccTableDate');
  String get vaccTableNext => _t('vaccTableNext');
  String get vaccTableNotes => _t('vaccTableNotes');
  String get commonCouldNotSave => _t('commonCouldNotSave');
  String get commonSaving => _t('commonSaving');
  String get commonSave => _t('commonSave');
  String get commonSelect => _t('commonSelect');
  String get commonBack => _t('commonBack');
  String get commonAdvance => _t('commonAdvance');
  String get commonClose => _t('commonClose');
  String get commonName => _t('commonName');
  String get commonPhone => _t('commonPhone');
  String get openingGallery => _t('openingGallery');
  String get devLeapsTitle => _t('devLeapsTitle');
  String devLeapsIntro(String babyName) =>
      _t('devLeapsIntro').replaceAll('{name}', babyName);
  String get devLeapsNeedBirth => _t('devLeapsNeedBirth');
  String get devLeapsAllTitle => _t('devLeapsAllTitle');
  String get devLeapsCurrentPill => _t('devLeapsCurrentPill');
  String get devLeapsSeeDetails => _t('devLeapsSeeDetails');
  String get devLeapsWhatsHappening => _t('devLeapsWhatsHappening');
  String get devLeapsKeywords => _t('devLeapsKeywords');
  String get devLeapsMayHappen => _t('devLeapsMayHappen');
  String get devLeapsHowToHelp => _t('devLeapsHowToHelp');
  String get devLeapsSkills => _t('devLeapsSkills');
  String get devLeapsEmotionalLook => _t('devLeapsEmotionalLook');

  /// Textos traduzidos do banner/lista sobre saltos (chave por fase, ex.: [dv01]…[dv20]).
  String developmentLeapBannerRange(String bannerKey) =>
      _t('devLeap_${bannerKey}_range');
  String developmentLeapBannerTitle(String bannerKey) =>
      _t('devLeap_${bannerKey}_title');
  String developmentLeapBannerLead(String bannerKey) =>
      _t('devLeap_${bannerKey}_lead');
  String developmentLeapBannerEmotion(String bannerKey) =>
      _t('devLeap_${bannerKey}_emotion');

  /// Corpo da fase no card/página de detalhe (lista: uma linha por item).
  List<String> developmentLeapHomeBullets(String bannerKey) =>
      _splitLeapLines(_t('devLeap_${bannerKey}_homeBullets'));

  String developmentLeapDetailWhats(String bannerKey) =>
      _t('devLeap_${bannerKey}_detailWhats');

  List<String> developmentLeapDetailKeywords(String bannerKey) =>
      _splitLeapLines(_t('devLeap_${bannerKey}_keywords'));

  List<String> developmentLeapDetailMayHappen(String bannerKey) =>
      _splitLeapLines(_t('devLeap_${bannerKey}_detailMay'));

  List<String> developmentLeapDetailHowToHelp(String bannerKey) =>
      _splitLeapLines(_t('devLeap_${bannerKey}_detailHelp'));

  List<String> developmentLeapDetailSkills(String bannerKey) =>
      _splitLeapLines(_t('devLeap_${bannerKey}_detailSkills'));

  String developmentLeapDetailEmotionalLook(String bannerKey) =>
      _t('devLeap_${bannerKey}_detailEmotional');

  String get regAppBarTitle => _t('regAppBarTitle');
  String get regLetsStart => _t('regLetsStart');
  String get regSubtitleMandatory => _t('regSubtitleMandatory');
  String get regSubtitleOptional => _t('regSubtitleOptional');
  String get regStepMother => _t('regStepMother');
  String get regStepBaby => _t('regStepBaby');
  String get regMotherSection => _t('regMotherSection');
  String get regBabySection => _t('regBabySection');
  String get regBirthLabel => _t('regBirthLabel');
  String get regMotherHeight => _t('regMotherHeight');
  String get regFatherSection => _t('regFatherSection');
  String get regFatherName => _t('regFatherName');
  String get regFatherBirthLabel => _t('regFatherBirthLabel');
  String get regFatherHeight => _t('regFatherHeight');
  String get settingsFamilyTree => _t('settingsFamilyTree');
  String get regMotherPhotoAdd => _t('regMotherPhotoAdd');
  String get regMotherPhotoChange => _t('regMotherPhotoChange');
  String get regBabyPhotoAdd => _t('regBabyPhotoAdd');
  String get regBabyPhotoChange => _t('regBabyPhotoChange');
  String get regSaveMotherAdvance => _t('regSaveMotherAdvance');
  String get regSaveBaby => _t('regSaveBaby');
  String get regSelectMotherPrompt => _t('regSelectMotherPrompt');
  String get regMotherLabel => _t('regMotherLabel');
  String get regBabyGirl => _t('regBabyGirl');
  String get regBabyBoy => _t('regBabyBoy');
  String get regBabyWeight => _t('regBabyWeight');
  String get regRegisteredList => _t('regRegisteredList');
  String get regNoneYet => _t('regNoneYet');
  String get regBabyPrompt => _t('regBabyPrompt');
  String get regSavingMother => _t('regSavingMother');
  String get regSavingBaby => _t('regSavingBaby');
  String get regSnackMotherBirth => _t('regSnackMotherBirth');
  String get regSnackMotherOk => _t('regSnackMotherOk');
  String get regSnackSelectMother => _t('regSnackSelectMother');
  String get regSnackBabyBirth => _t('regSnackBabyBirth');
  String get regSnackPickMother => _t('regSnackPickMother');
  String get regSnackBabyOk => _t('regSnackBabyOk');
  String get regMomGeneric => _t('regMomGeneric');
  String get valNameEmpty => _t('valNameEmpty');
  String get valNameShort => _t('valNameShort');
  String get valPhoneEmpty => _t('valPhoneEmpty');
  String get valPhoneInvalid => _t('valPhoneInvalid');
  String get valHeightEmpty => _t('valHeightEmpty');
  String get valHeightInvalid => _t('valHeightInvalid');
  String get valHeightMotherRange => _t('valHeightMotherRange');
  String get valFatherHeightEmpty => _t('valFatherHeightEmpty');
  String get valWeightEmpty => _t('valWeightEmpty');
  String get valWeightInvalid => _t('valWeightInvalid');
  String get valWeightRange => _t('valWeightRange');
  String get valBabyHeightRange => _t('valBabyHeightRange');
  String get placeholderBabyName => _t('placeholderBabyName');
  String get valBirthDateInvalid => _t('valBirthDateInvalid');
  String get brDateHint => _t('brDateHint');
  String get brDateOpenCalendar => _t('brDateOpenCalendar');

  String _t(String key) {
    final map = _strings[lang] ?? _strings[AppLang.pt]!;
    final en = _strings[AppLang.en]!;
    final pt = _strings[AppLang.pt]!;
    final primary = map[key];
    if (primary != null) return primary;

    final extra = aiFamilyGrowthLocaleExtra(lang.name, key);
    if (extra != null) return extra;

    if (key.startsWith('devLeap_') || key.startsWith('devLeaps')) {
      final leap = kDevelopmentLeapsTranslated[lang.name]?[key];
      if (leap != null) return leap;
    }

    return en[key] ?? pt[key] ?? key;
  }
}

const Map<AppLang, Map<String, String>> _strings = {
  AppLang.pt: {
    'appName': 'FaceBaby',
    'home': 'Início',
    'records': 'Registros',
    'reports': 'Relatórios',
    'memories': 'Memórias',
    'more': 'Mais',
    'helloMom': 'Olá, Mamãe!',
    'today': 'Hoje',
    'shortcuts': 'Atalhos',
    'registerNow': 'Registrar agora',
    'edit': 'Editar',
    'delete': 'Excluir',
    'cancel': 'Cancelar',
    'confirmDelete': 'Tem certeza que deseja excluir este registro?',
    'deletedOk': 'Excluído com sucesso.',
    'deleteFail': 'Não foi possível excluir:',
    'todaySummary': 'Resumo de hoje',
    'nextEvents': 'Próximos eventos',
    'quickRecordsTitle': 'Registros rápidos',
    'quickRecordsSubtitle':
        'Adicione eventos da rotina da bebê em poucos toques.',
    'feedingAlertsSwitchTitle': 'Alerta de Amamentação',
    'feedingAlertsSwitchSubtitle':
        'Aviso quando passar o tempo desde a última amamentação ao seio ou mamadeira (push).',
    'feedingAlertsIntervalCaption':
        'Tempo para avisar após a última amamentação: {m} min (20–360)',
    'feedingAlertsShortcutTitle': 'Alerta de alimentação',
    'scheduledFeedingReminderBody':
        'Momento do lembrete de amamentação. Toque para registar.',
    'scheduledDiaperReminderTitle': 'Troca de fralda',
    'scheduledDiaperReminderBody':
        'Já passou o tempo sugerido desde a última troca. Toque para registar.',
    'whatHappenedNow': 'O que aconteceu agora?',
    'momNote': 'Observação da mamãe',
    'saveRecord': 'Salvar registro',
    'reportsTitle': 'Relatórios',
    'reportsSubtitle': 'Resumo para a mamãe e para o pediatra.',
    'reportsHubAnchorLabel': 'Referência',
    'reportsHubPickDayTooltip': 'Escolher dia de referência para os relatórios',
    'reportsHubSectionTitle': 'Relatórios disponíveis',
    'reportStubComingSoon':
        'Este relatório será atualizado automaticamente com os dados da app para o período indicado. Detalhes de layout e métricas serão definidos a seguir.',
    'reportListDaily': 'Relatório diário',
    'reportListDailySub': 'Resumo e detalhes do dia selecionado',
    'reportListWeekly': 'Relatório semanal',
    'reportListWeeklySub':
        'Resumo e detalhes da semana que contém o dia selecionado',
    'reportListMonthly': 'Relatório mensal',
    'reportListMonthlySub': 'Agregados do mês do dia selecionado',
    'reportListSleepAdv': 'Relatório avançado de sono',
    'reportListSleepAdvSub': 'Padrões e métricas de sono',
    'reportListPediatric': 'Relatório Pediátrico',
    'reportListPediatricSub': 'PDF e dados para consulta médica',
    'reportListDevelopment': 'Relatório de desenvolvimento',
    'reportListDevelopmentSub': 'Marcos e saltos do desenvolvimento',
    'plusBrandTitle': 'FaceBaby Plus',
    'plusEarlyAdopterOffer': 'Preço especial para os primeiros usuários.',
    'plusPopularBadge': 'Mais Popular ❤️',
    'plusPlanAnnualCardTitle': 'FaceBaby Plus Anual',
    'plusPlanMonthlyCardTitle': 'FaceBaby Plus Mensal',
    'plusPlanAnnualSubtitle': 'Economize assinando o plano anual.',
    'plusPlanMonthlySubtitle':
        'Tudo que você precisa para acompanhar seu bebê com carinho e inteligência.',
    'plusAnnualSavingsAmountLine': 'Economize R\$ {amount} por ano',
    'plusAnnualPerMonthHint': 'Equivale a cerca de R\$ 12,49/mês',
    'plusCtaSubscribeMonthly': 'Assinar plano mensal',
    'plusCtaSubscribeAnnual': 'Assinar plano anual',
    'plusCtaSubscribePlus': 'Assinar FaceBaby Plus',
    'plusPaywallRenewalNote':
        'A assinatura é renovada automaticamente pela Google Play. Você pode cancelar quando quiser nas configurações da Play Store.',
    'plusSheetHero':
        'FaceBaby Plus: IA Babá 24h, fotos à vontade, backup completo, relatórios premium, livro do bebê e muito mais — a partir de R\$ 14,90/mês.',
    'plusSheetPriceLabel': 'Planos mensal e anual',
    'plusSheetBullets':
        '• IA Babá 24h\n• Upload de fotos à vontade\n• Backup completo na nuvem\n• Relatórios premium e livro do bebê\n• Crescimento avançado e horóscopo familiar IA\n• Conteúdos gerados por IA\n• Em breve: respostas por voz',
    'plusCtaSubscribe': 'Assinar FaceBaby Plus',
    'plusCtaRestore': 'Restaurar compras',
    'plusCtaLater': 'Agora não',
    'plusSheetFootnote':
        'Assinatura processada pela Google Play ou App Store. Cancele quando quiser nas definições da loja.',
    'plusWelcomeSnack':
        'Obrigada por assinar o FaceBaby Plus — as memórias do bebê ficam ainda mais seguras.',
    'plusPurchaseUnavailableSnack':
        'Não foi possível iniciar a compra. Confirme o produto nas lojas ou tente mais tarde.',
    'plusPurchaseSkuNotFoundSnack':
        'A Google Play não devolveu a assinatura "{id}". No Play Console crie uma assinatura mensal activa com este ID (Monetizar → Assinaturas), ou use --dart-define=FACEBABY_PREMIUM_SKU=… no build.',
    'plusPurchaseBillingLaunchFailedSnack':
        'Não foi possível abrir o pagamento na Google Play. Confirme ligação à Internet, que a app veio da Play e que está com uma conta Google válida. Em testes internos/fechados, use conta licenciada. Se a mensagem da Play disser que o produto já foi comprado, use «Restaurar compras» abaixo.',
    'plusPurchaseAlreadyInPlayAccountSnack':
        'Se a Play disser que o produto já é seu, toque em «Restaurar compras» abaixo para ligar o Premium a esta conta FaceBaby. Se não funcionar, confira se está na mesma conta Google da compra.',
    'plusPaywallSkuMissingHint':
        'Ainda sem preço da loja para a assinatura "{id}". Confirme o plano mensal activo na Play Console ou aguarde sincronização.',
    'plusRestoreOkSnack': 'Compras restauradas com sucesso.',
    'plusRestoreEmptySnack': 'Não encontrámos uma compra anterior nesta conta.',
    'plusSnackLockedFeature': 'Incluído no FaceBaby Plus.',
    'plusMemoryLimitSnack':
        'No plano gratuito pode guardar até {max} fotos em selos. O Premium libera fotos à vontade.',
    'plusMemoryLimitDialogTitle': 'Liberte mais memórias',
    'plusMemoryLimitDialogBody':
        'No plano gratuito você pode guardar até {max} fotos nos selos.\n\nAssine o FaceBaby Plus para fotos à vontade, IA Babá, backup completo e todas as funções premium.',
    'plusMemoryLimitDialogSubscribe': 'Assinar Premium',
    'plusReportsLockedHint': 'Relatório FaceBaby Premium',
    'plusReportsPremiumTagline':
        'Relatórios premium, IA Babá e backup — FaceBaby Plus a partir de R\$ 14,90/mês.',
    'plusReportsPremiumCta': 'Ver FaceBaby Premium',
    'plusExportLockedHint': 'Exportação FaceBaby Premium',
    'plusLifetimePaymentBadge': 'Plano mensal',
    'plusNoMonthlyBadge': 'Melhor custo-benefício',
    'plusPremiumActiveTitle': 'Obrigada pelo Premium',
    'plusPremiumActiveBody':
        'Suas funções premium estão ativas. Gerencie ou cancele a assinatura na Google Play ou App Store.',
    'plusPurchaseErrorSnack':
        'Algo correu mal. Tenta de novo ou usa Restaurar compras.',
    'plusDoneClose': 'Fechar',
    'plusPaywallHeadline':
        'Escolha o plano ideal para\nacompanhar seu bebê com o FaceBaby Plus.',
    'plusPaywallActiveNote':
        'Seu FaceBaby Plus está ativo. Gerencie a assinatura na Play Store.',
    'plusPlanPremiumButtonActive': 'Plano atual',
    'plusPlanMonthlyFeature1': 'Tudo do plano Gratuito',
    'plusPlanMonthlyFeature2': 'IA Babá 24h com você',
    'plusPlanMonthlyFeature3': 'Respostas inteligentes',
    'plusPlanMonthlyFeature4': 'Orientações personalizadas',
    'plusPlanMonthlyFeature5': 'Alertas preditivos',
    'plusPlanMonthlyFeature6': 'Rotinas personalizadas',
    'plusPlanMonthlyFeature7': 'Conteúdos gerados por IA',
    'plusPlanMonthlyFeature8': 'Upload de fotos',
    'plusPlanMonthlyFeature9': 'Backup completo',
    'plusPlanMonthlyFeature10': 'Relatórios premium',
    'plusPlanMonthlyFeature11': 'Relatório para o pediatra',
    'plusPlanMonthlyFeature12': 'Livro do bebê em PDF',
    'plusPlanMonthlyFeature13': 'Crescimento avançado',
    'plusPlanMonthlyFeature14': 'Horóscopo familiar com IA',
    'plusPlanMonthlyFeature15': 'Mensagens bíblicas diárias',
    'plusPlanMonthlyFeature16': 'Descrição dos signos',
    'plusPlanMonthlyFeature17': 'Suporte prioritário',
    'plusPlanMonthlyFeature18': 'Em breve: respostas por voz',
    'plusPlanAnnualFeature1': 'Tudo do Plus Mensal',
    'plusPlanAnnualFeature2': 'Economia em relação ao mensal',
    'plusPlanAnnualFeature3': 'Melhor custo-benefício',
    'plusPlanAiTitle': 'IA Babá',
    'plusPlanAiSubtitle': 'Assistente inteligente\npara o dia a dia',
    'plusPlanAiBadge': 'Em breve',
    'plusPlanAiFeature1': 'Tudo do plano Premium',
    'plusPlanAiFeature2': 'IA Babá 24h com você',
    'plusPlanAiFeature3': 'Respostas inteligentes',
    'plusPlanAiFeature4': 'Orientações personalizadas',
    'plusPlanAiFeature5': 'Alertas preditivos',
    'plusPlanAiFeature6': 'Rotinas personalizadas',
    'plusPlanAiFeature7': 'Conteúdos gerados pela IA',
    'plusPlanAiPrice': 'Em breve',
    'plusPlanAiPriceSub': 'Fique ligada!',
    'plusPlanAiButton': 'Quero ser avisado',
    'plusPlanFreeTitle': 'Gratuito',
    'plusPlanFreeSubtitle': 'Comece sua jornada com o essencial.',
    'plusPlanFreePrice': 'R\$ 0,00',
    'plusPlanCurrent': 'Plano atual',
    'plusPlanFreeFeature1': 'Cadastros básicos',
    'plusPlanFreeFeature2': 'Registro diário',
    'plusPlanFreeFeature3': 'Agendas e lembretes',
    'plusPlanFreeFeature4': 'Peso e altura',
    'plusPlanFreeFeature5': 'Algumas memórias',
    'plusPlanFreeFeature6': 'Recursos limitados',
    'plusTrustData': 'Seus dados\nsempre seguros',
    'plusTrustFamily': 'Feito com amor\npara famílias',
    'plusTrustContent': 'Conteúdos confiáveis\ne atualizados',
    'plusTrustSupport': 'Apoio em cada\nmomento',
    'settingsPlusCardTitle': 'FaceBaby Plus',
    'settingsPlusCardBodyFree':
        'IA Babá, fotos ilimitadas, backup completo, relatórios premium e livro do bebê — mensal R\$ 14,90 ou anual R\$ 149,90.',
    'settingsPlusCardBodyActive':
        'Seu FaceBaby Plus está ativo — obrigada por apoiar o projeto.',
    'settingsPlusUpgradeCta': 'Conhecer FaceBaby Plus',
    'settingsPlusManageCta': 'Gerenciar Plus',
    'plusMemoryCounterFree': '{n} de {max} fotos no plano gratuito',
    'reportDailyScreenTitle': 'Relatório Diário',
    'reportDayDetailsTitle': 'Detalhes do Dia',
    'reportDailyPickDayTooltip': 'Escolher dia',
    'reportDailySubtitleSleepQuality': 'Qualidade do sono',
    'reportDailySubtitleTotalSleep': 'Total dormido',
    'reportDailySubtitleLongestStretch': 'Maior período contínuo',
    'reportDailySubtitleFeedTotal': 'Total de mamadas',
    'reportDailySubtitleFeedAvg': 'Duração média',
    'reportDailySubtitleFeedLast': 'Última mamada',
    'reportDailySubtitleDiaperTotal': 'Total de trocas',
    'reportDailySubtitleDiaperWet': 'Fraldas molhadas',
    'reportDailySubtitleDiaperDirty': 'Fraldas sujas',
    'reportDailySubtitleMoodMajority': 'Maioria do dia',
    'reportDailySubtitleMoodIrrit': 'Irritabilidade',
    'reportDailySubtitleWeightLast': 'Última medição',
    'reportSleepQualityGood': 'Boa',
    'reportSleepQualityOk': 'Ok',
    'reportSleepQualityBad': 'Frágil',
    'reportSleepQualityMixed': 'Variável',
    'reportVsYesterdayShort': 'vs ontem',
    'reportVsYesterdayNA': '—',
    'reportVsYesterdayPct': '{pct}%',
    'reportLongestStretchHint': '{start} – {end}',
    'reportNapsLabel': 'Sonecas',
    'reportTotalSmallLabel': 'Total',
    'reportComparedAgeLabel': 'Comparado à média da idade',
    'reportBenchmarkAbove': 'Acima da média',
    'reportBenchmarkNear': 'Próximo da média',
    'reportBenchmarkBelow': 'Abaixo da média',
    'reportIrritLow': 'Baixa',
    'reportIrritMedium': 'Moderada',
    'reportIrritHigh': 'Alta',
    'reportIrritUnknown': 'Sem dados',
    'reportTabSleep': 'Sono',
    'reportTabFeedings': 'Mamadas',
    'reportTabDiapers': 'Fraldas',
    'reportTabMood': 'Humor',
    'reportAiInsightsTitle': 'Insights',
    'reportTimelineTitle': 'Timeline do dia',
    'reportShareSoon': 'Partilhar (em breve)',
    'reportFeedingChartCaption': 'Mamadas por hora',
    'reportSleepChartCaption': 'Sono por hora',
    'reportNoDataHint': 'Sem registos suficientes para esta métrica.',
    'reportInsightSleepAgeGood':
        'O sono total está próximo do esperado para a idade — bom sinal de descanso recuperador.',
    'reportInsightSleepAgeLow':
        'O sono ficou abaixo do típico para a idade; observe sinais de cansaço e rotina à noite.',
    'reportInsightFeedsOften':
        'Muitas mamadas ao longo do dia — comum em fases de salto ou hidratação; registe duração para ver médias.',
    'reportInsightDiapersFrequent':
        'Várias trocas de fralda — pode indicar hidratação ok ou irritação de pele; vale observar o tipo (xixi/cocô).',
    'reportInsightMoodLine':
        'Humor predominante registrado nas memórias: {mood}.',
    'reportWeeklyScreenTitle': 'Relatório Semanal',
    'reportWeekDetailsTitle': 'Detalhes da Semana',
    'reportWeeklyPickWeekTooltip': 'Escolher semana (qualquer dia)',
    'reportWeeklySummaryTitle': 'Resumo da Semana',
    'reportWeeklyTrendsTitle': 'Tendências',
    'reportWeeklySeeFullDetails': 'Ver relatório completo',
    'reportWeeklyPartialWeekHint':
        'Médias e tendências: segunda a {weekday} (semana até agora).',
    'reportWeeklyFutureWeekHint':
        'Esta semana ainda não começou no calendário — escolhe outra semana ou volta quando houver dias registados.',
    'reportWeeklyLoadErrorPrefix': 'Não foi possível carregar o relatório:',
    'reportWeeklyToneCalm': 'tranquila',
    'reportWeeklyToneActive': 'movimentada',
    'reportWeeklySleepUnknown':
        'Sem dados suficientes para comparar o sono entre semanas.',
    'reportWeeklyFirstWeekSleepLine':
        'Esta é a primeira semana com registos: continue a anotar para vermos tendências em breve.',
    'reportWeeklySleepStableShort':
        'O sono manteve-se estável face à semana anterior.',
    'reportWeeklySleepUp':
        'O sono melhorou cerca de {pct}% face à semana anterior.',
    'reportWeeklySleepDown':
        'O sono reduziu cerca de {pct}% face à semana anterior.',
    'reportWeeklyFeedStableLine': 'As mamadas mantiveram-se regulares.',
    'reportWeeklyFeedUp':
        'As mamadas aumentaram cerca de {pct}% na média diária.',
    'reportWeeklyFeedDown':
        'As mamadas diminuíram cerca de {pct}% na média diária.',
    'reportWeeklyHeroTemplate': '{name} teve uma semana {tone}! {sleep} {feed}',
    'reportWeeklyTrendLabelImproved': 'Melhorou',
    'reportWeeklyTrendLabelWorse': 'Piorou',
    'reportWeeklyTrendLabelStable': 'Estável',
    'reportWeeklyTrendLabelUnknown': '—',
    'reportWeeklyTrendLabelEvolving': 'Evoluindo',
    'reportWeeklyTrendLabelIncreased': 'Aumentou',
    'reportWeeklyTrendNA': '—',
    'reportWeeklyHighlightSleep':
        'Destaque positivo: sono mais recuperador esta semana.',
    'reportWeeklyHighlightFeedingStable':
        'Destaque positivo: ritmo de alimentação consistente.',
    'reportWeeklyHighlightDiaperUp':
        'Destaque: mais trocas — hidratação ou digestão mais ativa.',
    'reportWeeklyHighlightWeight': 'Destaque positivo: ganho de peso.',
    'reportWeeklyHighlightGeneric':
        'Continue a registar para tendências mais claras.',
    'reportWeeklyAvgFeedsDay': 'Média diária: {avg} mamadas.',
    'reportWeeklyAvgDiapersDay': 'Média diária: {avg} trocas.',
    'reportWeeklySleepHoursChartTitle': 'Horas de sono por dia',
    'reportWeeklyAvgWeekLabel': 'Média da semana',
    'reportWeeklyVsPrevWeekShort': 'vs semana anterior',
    'reportWeeklyInsightsCardTitle': 'Insights da IA',
    'reportWeeklyPatternsTitle': 'Padrões detectados',
    'reportWeeklySeeAllAnalyses': 'Ver todas as análises',
    'reportWeeklyHeatmapSoon':
        'Mapa de calor horário (opcional) disponível em breve.',
    'reportWeeklyFeedChartCaption': 'Mamadas por dia',
    'reportWeeklyDiaperChartCaption': 'Trocas por dia',
    'reportWeeklyPatternWeekend':
        'Ao fim de semana o sono tende a alongar um pouco.',
    'reportWeeklyPatternFeedingDown':
        'Menos mamadas na média — comum quando os intervalos aumentam.',
    'reportWeeklyPatternDefault':
        'Padrão semanal dentro do esperado — ajuste conforme o ritmo do bebê.',
    'reportWeeklyInsightSleepNeutral':
        'O sono foi semelhante ao da semana anterior.',
    'reportWeeklyInsightSleepBetter':
        'Há mais horas de sono do que na semana passada — bom sinal.',
    'reportWeeklyInsightSleepLess':
        'O sono total ficou abaixo da semana anterior — vale observar o descanso à noite.',
    'reportWeeklyInsightTemplate': '{name}: {sleep}',
    'reportMonthlyScreenTitle': 'Relatório Mensal',
    'reportMonthlyAvgWeight': 'Peso médio',
    'reportMonthlyAvgHeight': 'Altura média',
    'reportMonthlyGrowthChartEmpty':
        'Adicione pelo menos dois registos de peso no mês para ver o gráfico.',
    'reportMonthlySleepSection': 'Sono',
    'reportMonthlySleepAvg': 'Média mensal (por dia)',
    'reportMonthlyVsPrevMonth': 'vs mês anterior',
    'reportMonthlyBestWeeks': 'Semanas com mais sono',
    'reportMonthlySleepTrendUp':
        'Tendência geral: mais sono recuperador este mês.',
    'reportMonthlySleepTrendDown':
        'Tendência geral: menos sono total que no mês anterior — vale acompanhar.',
    'reportMonthlySleepTrendStable':
        'Tendência geral: sono estável ao longo do mês.',
    'reportMonthlySleepTrendUnknown':
        'Sem dados suficientes para comparar com o mês anterior.',
    'reportMonthlySleepExplain':
        'A média de sono por dia soma todo o tempo registado em cada dia civil do mês e divide pelo número de dias desse mês (sessões contadas pelo horário de fim). A percentagem compara essa média com a do mês anterior. «Semanas com mais sono» mostra até duas semanas (segunda a domingo) em que o total de sono foi maior.',
    'reportMonthlyFeedingSection': 'Alimentação',
    'reportMonthlyFeedFreq': 'Frequência média (mamadas/dia)',
    'reportMonthlyFeedingExplain':
        'A frequência média é o total de mamadas ao peito ou à mamadeira registadas no mês dividido pelos dias do calendário desse mês (inclui dias sem registo). Alimentação sólida não entra nesta contagem. Os horários são até três faixas horárias em que mais mamadas terminaram neste mês.',
    'reportMonthlyPredominantHours': 'Horários predominantes (fim da mamada)',
    'reportMonthlyMilestonesTitle': 'Marcos do mês',
    'reportMonthlyMilestonesEmpty':
        'Sem vacinas, consultas ou memórias com selo neste mês.',
    'reportMonthlyMilestoneConsultationDefault': 'Consulta',
    'reportMonthlyMemoriesTitle': 'Memórias do mês',
    'homeRecentMemoriesTitle': 'Últimas Memórias',
    'reportMonthlySeeAllMemories': 'Ver todas',
    'reportMonthlyMemoriesEmpty':
        'Sem fotos registadas nas memórias deste mês.',
    'reportMonthlyVideosHint':
        'Vídeos aparecem quando existirem nos momentos guardados.',
    'reportSleepAdvScreenTitle': 'Relatório de Sono',
    'reportSleepAdvScoreTitle': 'Score de Sono',
    'reportSleepAdvMetricsTitle': 'Métricas da semana',
    'reportSleepAdvEfficiency': 'Eficiência do sono',
    'reportSleepAdvVsPrevPct':
        'Variação da eficiência: {pct}% (vs semana anterior)',
    'reportSleepAdvOnset': 'Tempo até o primeiro sono da noite',
    'reportSleepAdvAwakenings': 'Despertares por noite (média)',
    'reportSleepAdvAwakeningsTotal': 'Soma de despertares na semana: {n}',
    'reportSleepAdvLongest': 'Maior período contínuo',
    'reportSleepAdvAvgDailySleep': 'Média de sono por dia',
    'reportSleepAdvIdealTitle': 'Melhor horário para adormecer',
    'reportSleepAdvIdealFooter':
        'Janela estimada a partir dos teus registos (não é aconselhamento médico).',
    'reportSleepAdvSeeFullAnalysis': 'Ver análise completa',
    'reportSleepAdvChartsSection': 'Sessão sono',
    'reportSleepAdvChartsSleepTrend': 'Ritmo do sono (esta semana)',
    'reportSleepAdvChartsCompare': 'Comparação com a semana anterior',
    'reportSleepAdvChartsDistribution': 'Dia e noite (soma da semana)',
    'reportSleepAdvChartsBars': 'Volume de sono: esta semana vs anterior',
    'reportSleepAdvDayPhase': 'Sono diurno (6h–18h)',
    'reportSleepAdvNightPhase': 'Sono noturno (18h–6h)',
    'reportSleepAdvDistributionEmpty': 'Sem dados para repartir.',
    'reportSleepAdvLegendThisWeek': 'Esta semana',
    'reportSleepAdvLegendPrevWeek': 'Semana anterior',
    'reportSleepAdvScoreBreakdown': 'O que o score reflete',
    'reportSleepAdvBreakdownLine':
        'Eficiência: {e} pts • Tramos longos: {s} pts • Despertares: {a} pts • Regularidade: {c} pts (indicativos).',
    'reportSleepAdvNotEnoughData':
        'Ainda há poucos registos esta semana — os valores são orientativos.',
    'reportSleepAdvStatusExcellent': 'Excelente',
    'reportSleepAdvStatusGood': 'Bom',
    'reportSleepAdvStatusRegular': 'Regular',
    'reportSleepAdvStatusPoor': 'Frágil',
    'reportSleepAdvBadgeVeryGood': 'Muito bom',
    'reportSleepAdvBadgeGood': 'Boa',
    'reportSleepAdvBadgeOk': 'Moderado',
    'reportSleepAdvBadgeAttention': 'Acompanhar',
    'reportSleepAdvBadgeIdeal': 'Ideal',
    'reportSleepAdvBadgeUnknown': 'Sem dados',
    'reportSleepAdvBadgeLow': 'Baixo',
    'reportSleepAdvBadgeModerate': 'Moderado',
    'reportSleepAdvBadgeHigh': 'Elevado',
    'reportPediatricScreenTitle': 'Relatório Pediátrico',
    'reportPediatricPeriodPrefix': 'Período:',
    'reportPediatricFilterHint': 'Período do relatório',
    'reportPediatricDateFrom': 'De',
    'reportPediatricDateTo': 'Até',
    'reportPediatricPickRange': 'Escolher datas',
    'reportPediatricFilterMaxDaysHint':
        'Toque para alterar. Intervalos muito longos são limitados a 366 dias.',
    'reportPediatricSectionGeneral': 'Informações gerais',
    'reportPediatricSectionSummary': 'Resumo do período',
    'reportPediatricSectionSleep': 'Sono',
    'reportPediatricSectionFeeding': 'Alimentação',
    'reportPediatricSectionSymptoms': 'Sintomas e registos',
    'reportPediatricSectionObservations': 'Observações dos pais',
    'reportPediatricLabelName': 'Nome',
    'reportPediatricLabelAge': 'Idade',
    'reportPediatricLabelBirth': 'Data de nascimento',
    'reportPediatricLabelWeightCurrent': 'Peso (último no período)',
    'reportPediatricLabelHeight': 'Altura',
    'reportPediatricWeightStart': 'Peso inicial (período)',
    'reportPediatricWeightEnd': 'Peso final (período)',
    'reportPediatricWeightGain': 'Variação de peso',
    'reportPediatricHeightStart': 'Altura inicial (período)',
    'reportPediatricHeightEnd': 'Altura final (período)',
    'reportPediatricHeightGain': 'Crescimento de altura',
    'reportPediatricAvgFeeds': 'Mamadas/refeições por dia (média)',
    'reportPediatricAvgSleep': 'Sono por dia (média)',
    'reportPediatricAvgDiapers': 'Trocas de fralda por dia (média)',
    'reportPediatricFeverEpisodes': 'Episódios de febre (registo estruturado)',
    'reportPediatricFeverNote': 'Nota',
    'reportPediatricFeverFootnote':
        'Contagem a partir dos relatos estruturados em Saúde › Relatar sintoma (com temperatura quando aplicável).',
    'reportPediatricVaccines': 'Vacinas aplicadas no período',
    'reportPediatricMedications':
        'Medicamentos (relatos e palavras-chave nas notas)',
    'reportPediatricSleepAvgDaily': 'Média diária de sono',
    'reportPediatricSleepAwakenings': 'Despertares noturnos (média)',
    'reportPediatricSleepPattern': 'Padrão geral do sono',
    'reportPediatricSleepPatternStable': 'Predominantemente contínuo',
    'reportPediatricSleepPatternModerate': 'Intermédio',
    'reportPediatricSleepPatternFragmented': 'Mais fragmentado',
    'reportPediatricSleepLongest': 'Maior período contínuo',
    'reportPediatricFeedingBreast': 'Aleitamento',
    'reportPediatricFeedingFormula': 'Fórmula',
    'reportPediatricFeedingSolid': 'Alimentação sólida',
    'reportPediatricFeedingSessions': 'sessões',
    'reportPediatricFeedingAvgDur': 'duração média',
    'reportPediatricSymptomReflux': 'Refluxo (diários ou relatos)',
    'reportPediatricSymptomColic': 'Cólicas (diários ou relatos)',
    'reportPediatricSymptomIrrit': 'Irritabilidade (humores)',
    'reportPediatricIrritHigh': 'Mais perceptível',
    'reportPediatricIrritMedium': 'Moderada',
    'reportPediatricIrritLow': 'Pouco perceptível',
    'reportPediatricIrritUnknown': 'Sem dados',
    'reportPediatricYes': 'Sim',
    'reportPediatricNo': 'Não',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'Diários do dia',
    'reportPediatricJournalNoteHint': 'Deteção por palavras nos textos livres.',
    'reportPediatricObsHint':
        'Observações para a consulta: sintomas, medicamentos, comportamentos diferentes…',
    'reportPediatricBtnShare': 'Compartilhar',
    'reportPediatricBtnExportPdf': 'Exportar PDF',
    'reportPediatricBtnPrint': 'Imprimir',
    'reportPediatricBtnEmail': 'E-mail',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote':
        'Documento informativo a partir dos registos locais. Não substitui avaliação clínica.',
    'reportPediatricNone': 'Nenhum',
    'reportPediatricPdfTitle': 'Relatório pediátrico — FaceBaby',
    'reportPediatricPdfPeriod': 'Período:',
    'reportPediatricPdfFooter':
        'Gerado na app FaceBaby. Conteúdo limitado ao registado neste dispositivo (modo offline disponível).',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': 'Choro sem causa aparente (relatos)',
    'reportPediatricSymptomPain': 'Dor (relatos)',
    'reportPediatricSymptomFromJournal': 'mencionado no diário (sem hora)',
    'reportPediatricStructuredSymptoms': 'Relatos de sintomas (data e hora)',
    'reportPediatricStructuredSymptomsEmpty':
        'Nenhum relato estruturado neste período.',
    'reportDevScreenTitle': 'Desenvolvimento',
    'reportDevSubtitle': 'Marcos orientativos para acompanhar com calma.',
    'reportDevScoreTitle': 'Score de desenvolvimento',
    'reportDevScoreStatusOnTrack': 'Dentro do esperado',
    'reportDevScoreStatusWatch': 'Há espaço para novas descobertas',
    'reportDevScoreStatusEarly': 'No seu ritmo — com tempo para florescer',
    'reportDevSectionMotor': 'Desenvolvimento motor',
    'reportDevSectionCognitive': 'Desenvolvimento cognitivo',
    'reportDevSectionSocial': 'Desenvolvimento social',
    'reportDevAchieved': 'Alcançado',
    'reportDevGrowing': 'A desenvolver',
    'reportDevInsightTitle': 'Insights',
    'reportDevSeeAllMarcos': 'Ver todos os marcos',
    'reportDevFootnote':
        'Marcos são orientações gerais; cada bebê tem o seu tempo. Em dúvida, converse com o pediatra.',
    'reportDevNeedBirth':
        'Adiciona a data de nascimento do bebê para ver este relatório.',
    'devReport_motor_head': 'Sustenta a cabeça',
    'devReport_motor_roll': 'Rola (ex.: de bruços para costas)',
    'devReport_motor_sit': 'Senta (com ou sem apoio)',
    'devReport_motor_crawl': 'Engatinha ou desloca-se em quatro apoios',
    'devReport_motor_walk': 'Dá passos / anda com apoio',
    'devReport_cog_faces': 'Reconhece rostos familiares',
    'devReport_cog_sounds': 'Responde a sons e vozes',
    'devReport_cog_track': 'Acompanha objetos com o olhar',
    'devReport_cog_babble': 'Balbucia ou vocaliza',
    'devReport_cog_visual': 'Contacto visual na brincadeira',
    'devReport_soc_smile': 'Sorriso social',
    'devReport_soc_emotion_resp': 'Resposta emocional aos cuidadores',
    'devReport_soc_family': 'Interação com familiares próximos',
    'devReport_soc_emotion_react': 'Reações emocionais às situações',
    'devReportInsightNewborn':
        'Nos primeiros dias o mais importante é vínculo e segurança — cada pequeno sinal conta.',
    'devReportInsightOnTrack':
        'O desenvolvimento registado está compatível com padrões esperados para a faixa etária.',
    'devReportInsightVariety':
        'É natural haver variação entre marcos — alguns aparecem um pouco antes ou depois.',
    'devReportInsightPatience':
        'Ainda há marcos por explorar: tummy time calmo, conversas e brincadeiras sem pressa ajudam muito.',
    'devReportInsightBalanced':
        'Celebra as pequenas conquistas; o carinho e a rotina gentil são o melhor estímulo.',
    'growth': 'Crescimento',
    'pediatricReport': 'Relatório Pediátrico',
    'pediatricReportDesc':
        'Gere um PDF com peso, sono, alimentação, fraldas, vacinas, sintomas relatados em Saúde, consultas e observações.',
    'generatePdf': 'Gerar PDF',
    'memoriesTitle': 'Livro de memórias',
    'memoriesSubtitle': 'Momentos importantes para transformar em recordações.',
    'memoriesProgressSaved': '{filled} de {total} momentos guardados',
    'memoriesProgressStandardBadges': '({count} badges padrão)',
    'memoriesCheerEmpty':
        'Toque num selo com + para registrar fotos e histórias.',
    'memoriesAlbumPromoTitle': 'O seu livro de recordação completo',
    'memoriesAlbumPromoSubtitle':
        'Baixe um PDF elegante com capa FaceBaby, moldura decorativa e todas as badges que já preencheu — ideal para guardar ou partilhar.',
    'memoriesAlbumDownloadCta': 'Baixar PDF do álbum',
    'memoriesAlbumGenerating': 'Gerando o Álbum',
    'memoriesAlbumNeedFilled':
        'Preencha pelo menos um momento no álbum para gerar o PDF.',
    'memoriesAlbumError': 'Não foi possível gerar o PDF.',
    'memoriesAlbumPdfReadyTitle': 'PDF do álbum pronto',
    'memoriesAlbumShareAction': 'Compartilhar',
    'memoriesAlbumSaveAction': 'Salvar / Download',
    'memoriesAlbumSavedSnack': 'PDF guardado no telemóvel.',
    'memoriesAlbumSaveFailedSnack': 'Não foi possível guardar o PDF.',
    'memoriesAlbumCoverMain': 'Livro de recordação',
    'memoriesAlbumCoverTagline': 'Momentos especiais com {name}',
    'memoriesAlbumFooter': 'Gerado com FaceBaby',
    'memoriesAlbumBackCoverBody':
        'FaceBaby nasceu para transformar momentos simples em lembranças eternas. Cada sorriso, descoberta, abraço e conquista do seu bebê merece ser guardado com carinho, amor e significado.\n\nEste livro foi criado para acompanhar os primeiros passos dessa jornada tão especial, registrando memórias únicas que poderão ser revividas por toda a vida.\n\nMais do que fotos e anotações, estas páginas carregam sentimentos, histórias e emoções que o tempo jamais apagará.\n\nObrigado por permitir que a FaceBaby faça parte da história da sua família. 💛',
    'memoriesAlbumBackCoverFinale':
        'Porque crescer passa rápido…\nmas as memórias podem durar para sempre.',
    'memoriesAlbumQualityTitle': 'Qualidade do PDF',
    'memoriesAlbumQualityShareTitle': 'Leve — para partilhar',
    'memoriesAlbumQualityShareDesc':
        'Imagens comprimidas, ficheiro menor. Ideal para WhatsApp e e-mail.',
    'memoriesAlbumQualityPrintTitle': 'Alta qualidade — para imprimir',
    'memoriesAlbumQualityPrintDesc':
        'Maior resolução das fotos. Ficheiro maior; melhor para impressão.',
    'memoriesAlbumExportTitle': 'A gerar o livro…',
    'memoriesAlbumProgressPreparing': 'A preparar páginas…',
    'memoriesAlbumProgressImages': 'A processar fotos ({current}/{total})…',
    'memoriesAlbumProgressBuilding': 'A montar o PDF ({current}/{total})…',
    'memoriesAlbumProgressSaving': 'A guardar o ficheiro…',
    'memoriesAlbumCancelBtn': 'Cancelar',
    'memoriesAlbumCanceled': 'Geração cancelada.',
    'memoriesAlbumErrorNetwork':
        'Sem ligação à internet. Verifique a rede e tente novamente.',
    'memoriesAlbumErrorStorage':
        'Espaço insuficiente no dispositivo para guardar o PDF.',
    'memoriesAlbumSkippedImages':
        '{count} foto(s) não puderam ser incluídas (rede ou ficheiro inválido).',
    'addMemory': 'Adicionar memória',
    'memoryAddBadgeCta': 'Adicionar badge',
    'memoryChooseBadgeTitle': 'Qual badge deseja criar?',
    'memoryOtherBadgeTitle': 'Outra',
    'memoryOtherBadgeNameLabel': 'Nome da badge',
    'memoryOtherBadgeNameHint': 'Ex: Primeira fantasia',
    'memoryOtherBadgeNameRequired': 'Informe o nome da badge.',
    'memoryOtherBadgeNameTooLong': 'Use no máximo 25 caracteres.',
    'memoryBadgeMonthOne': '1 mês',
    'memoryBadgeMonthsMany': '{n} meses',
    'memoryBadgeYearOne': '1 ano',
    'memoryBadgeYearsMany': '{n} anos',
    'memoryBadgeMonthUnitSingular': 'mês',
    'memoryBadgeMonthUnitPlural': 'meses',
    'badge_arrived_home': 'Cheguei em casa',
    'badge_first_smile': 'Primeiro sorriso',
    'badge_first_feeding': 'Primeira Amamentação',
    'badge_sleeping': 'Dormindo',
    'badge_bath_time': 'Hora do banho',
    'badge_going_out': 'Indo passear',
    'badge_first_laugh': 'Primeira risada',
    'badge_found_hands': 'Achei minhas mãos',
    'badge_lifted_head': 'Levantei a cabeça',
    'badge_at_park': 'No parque',
    'badge_first_hug': 'Primeiro abraço',
    'badge_first_foods': 'Primeiros alimentos',
    'badge_first_bath': 'Primeiro banho',
    'badge_crib_sleep': 'Primeiro soninho no berço',
    'badge_first_diaper_change': 'Primeira troca de fralda',
    'badge_first_burp': 'Primeiro arroto',
    'badge_first_mom_cuddle': 'Primeiro colo da mamãe',
    'badge_first_dad_cuddle': 'Primeiro colo do papai',
    'badge_first_pediatrician': 'Primeira visita ao pediatra',
    'badge_first_vaccine': 'Primeira vacina',
    'badge_first_car_ride': 'Primeiro passeio de carro',
    'badge_first_stroller_ride': 'Primeiro passeio de carrinho',
    'badge_favorite_toy': 'Primeiro brinquedo favorito',
    'badge_first_night_home': 'Primeira noite em casa',
    'badge_first_giggle': 'Primeira gargalhada',
    'badge_sun_bath': 'Primeiro banho de sol',
    'badge_first_christmas': 'Primeiro Natal',
    'badge_first_new_year': 'Primeiro Ano Novo',
    'badge_first_mothers_day': 'Primeiro Dia das Mães',
    'badge_first_fathers_day': 'Primeiro Dia dos Pais',
    'badge_first_tooth': 'Primeiro dente',
    'badge_first_puree': 'Primeira papinha',
    'badge_sat_alone': 'Sentou sem apoio',
    'badge_crawled': 'Engatinhou',
    'badge_stood_up': 'Ficou em pé',
    'badge_first_steps': 'Primeiros passos',
    'badge_first_word': 'Primeira palavra',
    'badge_favorite_song': 'Primeira música favorita',
    'badge_first_trip': 'Primeira viagem',
    'badge_family_birthday': 'Primeiro aniversário em família',
    'badge_first_beach': 'Primeira praia',
    'badge_first_pool': 'Primeira piscina',
    'badge_first_haircut': 'Primeiro corte de cabelo',
    'badge_first_shoes': 'Primeiro sapatinho',
    'badge_special_outfit': 'Roupinha especial',
    'badge_first_friend': 'Primeiro amigo',
    'badge_first_party': 'Primeira festa',
    'badge_first_cartoon': 'Primeiro desenho',
    'badge_first_book': 'Primeiro livro',
    'badge_special_free': 'Momento especial livre',
    'settingsTitle': 'Mais',
    'dailyJournalTitle': 'Resumo do dia',
    'dailyJournalPickDay': 'Escolher dia',
    'dailyJournalOnDate': 'Resumo em {d}',
    'dailyJournalHint':
        'Escreva aqui o resumo de hoje (ou do dia selecionado)…',
    'dailyJournalSave': 'Salvar resumo',
    'dailyJournalSaving': 'Salvando resumo…',
    'dailyJournalSaved': 'Resumo salvo.',
    'dailyJournalNoBaby':
        'Cadastre/seleciona um bebê para usar o resumo do dia.',
    'registerMotherBaby': 'Cadastro (mãe e bebê)',
    'vaccinesCard': 'Vacinas (carteirinha)',
    'language': 'Idioma',
    'settingsSoonTitle': 'Em breve',
    'settingsSoonBadge': 'Em breve',
    'settingsRateUs': 'Avalie-nos',
    'settingsVersion': 'Versão',
    'settingsVersionDialogTitle': 'Versão do app',
    'settingsVersionCopy': 'Copiar',
    'settingsVersionCopied': 'Informações da versão copiadas',
    'settingsTermsOfUse': 'Termos de uso',
    'termsLoadError': 'Não foi possível carregar os termos.',
    'settingsPrivacyPolicy': 'Política de privacidade',
    'settingsSpecialThanks': 'Agradecimentos especiais',
    'settingsTellFriend': 'Indique para um Amigo',
    'settingsInviteShareText':
        'Experimente o FaceBaby — o diário da rotina e memórias do bebê.\nhttps://play.google.com/store/apps/details?id=com.facebaby.app',
    'settingsPremiumBenefitsTitle': 'Benefícios FaceBaby Plus',
    'settingsPremiumBannerHint':
        'Toque para ver planos Plus, preços e o que está incluído.',
    'settingsRateCouldNotOpen':
        'Não foi possível abrir a loja. Tente mais tarde.',
    'unitsTitle': 'Unidades de medida',
    'unitsIntro':
        'Escolha como prefere ver as medidas. Começamos com um padrão automático baseado na região do seu celular.',
    'unitsLengthTitle': 'Unidade de comprimento',
    'unitsLengthSubtitle': 'Altura, perímetro e medidas em geral.',
    'unitsWeightTitle': 'Unidade de peso',
    'unitsWeightSubtitle': 'Peso do bebê e registros relacionados.',
    'unitsLiquidTitle': 'Unidade de líquidos',
    'unitsLiquidSubtitle': 'Volume (ex.: mamadeira e outros).',
    'unitsTempTitle': 'Unidade de temperatura',
    'unitsTempSubtitle': 'Temperatura corporal e ambiente.',
    'unitsOptCm': 'cm',
    'unitsOptInch': 'pol (in)',
    'unitsOptKg': 'kg',
    'unitsOptLb': 'lb',
    'unitsOptSt': 'st',
    'unitsOptMl': 'ml',
    'unitsOptUkFloz': 'uk fl oz',
    'unitsOptUsFloz': 'us fl oz',
    'unitsOptC': 'ºC',
    'unitsOptF': 'ºF',
    'authLoginTitle': 'Entrar',
    'authWelcome': 'Bem-vindo',
    'authEmailLabel': 'E-mail',
    'authPasswordLabel': 'Senha',
    'authForgotPassword': 'Esqueci minha senha',
    'authSignIn': 'Entrar',
    'authSigningIn': 'Entrando...',
    'authSignInGoogle': 'Entrar com Google',
    'authSignInApple': 'Entrar com Apple',
    'authSignInEmail': 'Entrar com e-mail',
    'authAppleSignInPlaceholder': 'Apple Sign-In ainda será configurado.',
    'authCreateAccount': 'Criar conta',
    'authForgotDialogTitle': 'Esqueci minha senha',
    'authForgotDialogBody': 'Vamos enviar um link para redefinir sua senha.',
    'authForgotSend': 'Enviar',
    'authResetEmailSentSnackbar':
        'E-mail enviado. Verifique sua caixa de entrada.',
    'authRegisterAppBarTitle': 'Criar conta',
    'authRegisterTitle': 'Cadastro',
    'authRegisterNameLabel': 'Nome (como quer ser chamada)',
    'authRegisterPasswordLabel': 'Senha',
    'authRegisterSubmit': 'Criar conta',
    'authRegisterCreating': 'Criando...',
    'authValEmailRequired': 'Informe seu e-mail',
    'authValEmailInvalid': 'E-mail inválido',
    'authValPasswordRequired': 'Informe sua senha',
    'authValPasswordMin6': 'Mínimo 6 caracteres',
    'authValNameRequired': 'Informe seu nome',
    'authValNameShort': 'Nome muito curto',
    'authErrWeakPassword': 'Senha fraca. Use pelo menos 6 caracteres.',
    'authErrInvalidEmail': 'E-mail inválido.',
    'authErrUserDisabled': 'Esta conta foi desativada.',
    'authErrUserNotFound': 'Não há conta com esse e-mail.',
    'authErrWrongPassword': 'Senha incorreta.',
    'authErrEmailInUse':
        'Já existe conta com esse e-mail. Use «Já tenho conta» para entrar.',
    'authErrAccountExistsDifferentCredential':
        'Este e-mail já tem conta FaceBaby com outro método (por exemplo Google). Volte, toque em «Já tenho conta» e use o mesmo método de antes; se quiser criar com e-mail e senha, use outro e-mail.',
    'authErrEmailInUseGoogle':
        'Este e-mail já está registado com o Google. Volte e entre com o botão Google em «Já tenho conta».',
    'authErrEmailInUsePassword':
        'Este e-mail já tem senha FaceBaby. Use «Já tenho conta» com e-mail e senha; se esqueceu, «Esqueci a senha» no login.',
    'authErrEmailInUseApple':
        'Este e-mail já está ligado à Apple. Entre com o botão Apple em «Já tenho conta».',
    'authErrEmailInUseMixed':
        'Este e-mail já está registado com outro método de acesso. Use «Já tenho conta» e o mesmo Google, Apple ou e-mail/senha de sempre.',
    'authErrInvalidCredential': 'Credenciais inválidas. Tente novamente.',
    'authErrCredentialsGeneric': 'Não foi possível entrar. Tente novamente.',
    'authErrGoogleConfigAndroid':
        'Login com Google falhou por configuração do app (erro 10).\n\n'
            '1) No Firebase: Configurações do projeto → app Android → cadastre a impressão SHA-1 do keystore de debug.\n'
            '2) Na pasta android, rode: gradlew signingReport e copie o SHA-1 de "debug".\n'
            '3) Em Autenticação → Google → ative.\n'
            '4) Baixe de novo o google-services.json em android/app/.',
    'authErrLoginCancelled': 'Login cancelado.',
    'authErrAppleFailed':
        'Não foi possível entrar com a Apple. Tente novamente ou use outro método.',
    'authErrAppleUnavailable':
        'Entrar com a Apple só está disponível no iPhone ou iPad.',
    'authErrUnexpected': 'Ocorreu um erro inesperado.',
    'emailVerifyTitle': 'Confirme seu e-mail',
    'emailVerifyLead':
        'Verifique seu endereço de e-mail antes de continuar. Enviamos um link para a sua caixa de entrada.',
    'emailVerifyWhy':
        'A confirmação protege os dados do bebê, permite recuperar a conta e reduz cadastros falsos.',
    'emailVerifyResendButton': 'Reenviar e-mail de verificação',
    'emailVerifyResendWait': 'Aguarde {seconds}s para reenviar',
    'emailVerifyConfirmedButton': 'Já verifiquei meu e-mail',
    'emailVerifySignOut': 'Sair da conta',
    'emailVerifySent': 'E-mail enviado! Verifique também a pasta de spam.',
    'emailVerifyStillPending':
        'Ainda não confirmamos seu e-mail. Abra o link que enviamos e tente de novo.',
    'authErrEmailVerifyTooMany':
        'Muitas tentativas. Aguarde alguns minutos antes de pedir outro e-mail.',
    'onbSelectDate': 'Selecionar data',
    'onbBabyFallback': 'bebê',
    'onbMomFallback': 'mamãe',
    'onbDadFallback': 'papai',
    'onbWelcomeTitle': 'Acompanhando e monitorando',
    'onbWelcomeSubtitle': 'o desenvolvimento com Amor.',
    'onbPlusEarlyOffer':
        'FaceBaby Plus: preço especial para os primeiros usuários — IA Babá, backup e relatórios premium.',
    'onbFeatureSleep': 'Sono',
    'onbFeatureFeeding': 'Alimentação',
    'onbFeatureGrowth': 'Crescimento',
    'onbFeatureMemories': 'Memórias',
    'onbFeatureAlerts': 'Alertas',
    'onbFeatureLove': 'Muito Amor',
    'onbCreateBabyProfile': 'Criar perfil do bebê',
    'onbExistingAccountLogin': 'Já tenho uma conta / Fazer login',
    'onbContinue': 'Continuar',
    'onbPrepareFaceBaby': 'Preparar FaceBaby',
    'onbPreparingTitle': 'Preparando o FaceBaby para você...',
    'onbPreparingSubtitle':
        'Personalizando alertas, memórias e rotina do bebê.',
    'onbAuthTitle': 'Seu perfil básico está pronto',
    'onbAuthSubtitle':
        'Agora crie sua conta para guardar tudo com segurança e sincronizar depois.',
    'onbSignInGoogle': 'Entrar com Google',
    'onbSignInApple': 'Entrar com Apple',
    'onbContinueEmail': 'Continuar com e-mail',
    'onbAlreadyHaveAccount': 'Já tenho conta',
    'onbWait': 'Aguarde...',
    'onbDoneTitle': 'Pronto! O perfil do bebê foi criado.',
    'onbStartTracking': 'Começar a acompanhar',
    'onbCouldNotPrepare':
        'Não foi possível preparar o perfil agora. Tente novamente.',
    'onbBabyNameTitle': 'Qual é o nome do bebê?',
    'onbBabyNameSubtitle':
        'Vamos deixar o FaceBaby com a carinha da sua família.',
    'onbBabyNameHint': 'Nome do bebê',
    'onbBabyBirthTitle': 'Qual é a data de nascimento?',
    'onbBabyBirthSubtitle':
        'Usamos a idade para personalizar sono, rotina e crescimento.',
    'onbBabyWeightTitle': 'Qual é o peso do bebê?',
    'onbBabyWeightSubtitle':
        'Arraste a régua para escolher. Você pode alternar entre Kg e Lb.',
    'onbBabyHeightTitle': 'Qual é a altura do bebê?',
    'onbBabyHeightSubtitle':
        'Use a régua para informar o tamanho aproximado na unidade que preferir.',
    'onbMotherNameTitle': 'Qual é o nome da mamãe?',
    'onbMotherNameSubtitle': 'Vamos usar o nome dela nas próximas perguntas.',
    'onbMotherNameHint': 'Nome da mamãe',
    'onbMotherBirthTitle': 'Qual é a data de nascimento da mamãe?',
    'onbMotherBirthSubtitle': 'Depois disso vamos perguntar a altura dela.',
    'onbMotherHeightTitle': 'Qual é a altura da {name}?',
    'onbMotherHeightSubtitle':
        'Essa informação ajuda nos relatórios de crescimento.',
    'onbRegisterFatherTitle': 'Deseja cadastrar o pai também?',
    'onbRegisterFatherSubtitle':
        'Se quiser, o FaceBaby também personaliza os dados do papai.',
    'onbFatherNameTitle': 'Qual é o nome do papai?',
    'onbFatherNameSubtitle': 'Assim a régua dele também fica personalizada.',
    'onbFatherNameHint': 'Nome do papai',
    'onbFatherBirthTitle': 'Qual é a data de nascimento do papai?',
    'onbFatherBirthSubtitle': 'Depois disso vamos perguntar a altura dele.',
    'onbFatherHeightTitle': 'Qual é a altura do {name}?',
    'onbFatherHeightSubtitle':
        'Pode ser aproximada, você ajusta depois se quiser.',
    'onbFatherPhotoTitle': 'Quer adicionar uma foto do papai?',
    'onbFatherPhotoSubtitle':
        'Opcional — você pode incluir depois em Família ou no cadastro.',
    'onbBabyPhotoTitle': 'Quer adicionar uma foto do bebê?',
    'onbBabyPhotoSubtitle':
        'Opcional — você pode incluir depois no cadastro ou em Memórias.',
    'onbMotherPhotoTitle': 'Quer adicionar uma foto da mamãe?',
    'onbMotherPhotoSubtitle':
        'Opcional — você pode incluir depois em Família ou no cadastro.',
    'onbBabySexTitle': 'Qual é o sexo do bebê?',
    'onbSexGirl': 'Menina',
    'onbSexBoy': 'Menino',
    'onbSexUnknown': 'Prefiro não informar',
    'onbFirstBabyTitle': 'É seu primeiro bebê?',
    'onbYes': 'Sim',
    'onbNo': 'Não',
    'onbConcernTitle': 'Qual é sua maior preocupação agora?',
    'onbConcernSubtitle': 'Pode escolher mais de uma.',
    'onbConcernSleep': 'Sono do bebê',
    'onbConcernFeeding': 'Amamentação/alimentação',
    'onbConcernGrowth': 'Peso e crescimento',
    'onbConcernRoutine': 'Rotina do dia',
    'onbConcernMemories': 'Memórias e fotos',
    'onbConcernDevelopment': 'Desenvolvimento',
    'onbGoalsTitle': 'Quais são seus objetivos?',
    'onbGoalsSubtitle': 'Vamos usar isso para personalizar sua experiência.',
    'onbGoalRoutine': 'Acompanhar melhor a rotina',
    'onbGoalSleepAlerts': 'Receber alertas de sono',
    'onbGoalMoments': 'Registrar momentos especiais',
    'onbGoalReports': 'Gerar relatórios',
    'onbGoalMemoryBook': 'Criar livro de memórias',
    'onbMessagePrefTitle': 'Mamãe espiritualizada, bebê feliz.',
    'onbMessagePrefSubtitle': 'Deseja receber mensagens diárias?',
    'onbMessagePrefChristian': 'Cristã',
    'onbMessagePrefHoroscope': 'Astrológica',
    'onbMessagePrefPhilosophical': 'Filosófica / Ecumênica',
    'onbMessagePrefSpiritist': 'Espíritas',
    'onbMessagePrefJewish': 'Judias',
    'onbMessagePrefAll': 'Todas',
    'onbMessagePrefBoth': 'Ambas',
    'onbMessagePrefNone': 'Nenhuma das opções',
    'onbAiHistoryTitle': 'Histórico do Bebê para a IA Babá',
    'onbAiHistorySubtitle':
        'Opcional — conte sobre rotina, saúde e preferências da família. Você pode editar depois em Família ou na IA Babá.',
    'onbAiHistoryOptional': 'Pode pular e preencher depois',
    'onbDragToAdjust': 'Arraste para ajustar',
    'onbEmailSheetTitle': 'Criar conta com e-mail',
    'onbYourNameHint': 'Seu nome',
    'onbEmailHint': 'E-mail',
    'onbPasswordHint': 'Senha',
    'onbCreateAccount': 'Criar conta',
    'onbValYourName': 'Informe seu nome.',
    'onbValEmailRequired': 'Informe seu e-mail.',
    'onbValEmailInvalid': 'E-mail inválido.',
    'onbValPasswordMin': 'Use pelo menos 6 caracteres.',
    'vaccinesTitle': 'Vacinas',
    'vaccinesSubtitle': 'Adicione vacinas, datas e próximas doses.',
    'baby': 'Bebê',
    'selectBaby': 'Selecionar bebê',
    'addVaccine': 'Adicionar vacina',
    'recordsTitle': 'Registros',
    'noVaccinesYet': 'Nenhuma vacina registrada ainda.',
    'seeAll': 'Ver todos',
    'changePhoto': 'Alterar foto',
    'motherPhotoTitle': 'Foto da mãe',
    'babyPhotoTitle': 'Foto da bebê',
    'familyTabMotherLabel': 'Mamãe',
    'familyTabFatherLabel': 'Papai',
    'familyTitle': 'Família',
    'familySubtitle': 'Aqui nasce o amor que cresce junto 💖',
    'familyEdit': 'Editar',
    'familyEditData': 'Editar dados >',
    'familyRoleMother': 'Mãe',
    'familyRoleFather': 'Pai',
    'familyRoleBaby': 'Bebê',
    'familyZodiacSolar': 'Signo solar',
    'familyEntertainmentNote':
        'Conteúdo leve e afetivo, para entretenimento — não substitui orientação profissional.',
    'familyChristianCardTitle': 'Mensagem para a família',
    'familySpiritistCardTitle': 'Mensagem espírita',
    'familyJewishCardTitle': 'Mensagem judaica',
    'familyChristianLine': '📖 {ref}',
    'familyBornOn': 'Nascimento: {date}',
    'familyAgeOneYear': '1 ano',
    'familyAgeYears': '{n} anos',
    'familyHeight': 'Altura: {value}',
    'familyMotherBlurb':
        'Como mãe de {sign}, você tende a demonstrar amor de forma {traits}.',
    'familyFatherBlurb':
        'Como pai de {sign}, você tende a proteger, ensinar e se conectar com seu bebê de forma {traits}.',
    'familyBabyBlurb':
        'Como bebê de {sign}, pode demonstrar traços como {traits}.',
    'familyZodiacName_capricorn': 'Capricórnio',
    'familyZodiacName_aquarius': 'Aquário',
    'familyZodiacName_pisces': 'Peixes',
    'familyZodiacName_aries': 'Áries',
    'familyZodiacName_taurus': 'Touro',
    'familyZodiacName_gemini': 'Gêmeos',
    'familyZodiacName_cancer': 'Câncer',
    'familyZodiacName_leo': 'Leão',
    'familyZodiacName_virgo': 'Virgem',
    'familyZodiacName_libra': 'Libra',
    'familyZodiacName_scorpio': 'Escorpião',
    'familyZodiacName_sagittarius': 'Sagitário',
    'familyZodiacTrait_capricorn': 'calma, responsável e acolhedora',
    'familyZodiacTrait_aquarius': 'criativa, gentil e cheia de carinho',
    'familyZodiacTrait_pisces': 'sensível, doce e muito empática',
    'familyZodiacTrait_aries': 'energética, protetora e carinhosa',
    'familyZodiacTrait_taurus': 'paciente, estável e muito presente',
    'familyZodiacTrait_gemini': 'alegre, comunicativa e curiosa',
    'familyZodiacTrait_cancer': 'afetuosa, intuitiva e protetora',
    'familyZodiacTrait_leo': 'calorosa, orgulhosa e generosa',
    'familyZodiacTrait_virgo': 'cuidadosa, atenta e dedicada',
    'familyZodiacTrait_libra': 'harmoniosa, carinhosa e equilibrada',
    'familyZodiacTrait_scorpio': 'intensa no amor, leal e protetora',
    'familyZodiacTrait_sagittarius': 'otimista, divertida e cheia de esperança',
    'familyFatherDataComplete': 'Dados do pai — completos e atualizados',
    'familyFatherDataIncomplete': 'Dados do pai — ainda incompletos',
    'familyAddFatherPrompt':
        'Quer adicionar os dados do pai? Complete para ver a altura estimada do seu bebê.',
    'familyAddFatherButton': 'Adicionar dados do pai',
    'familyCompleteBabySex':
        'Informe o sexo do bebê no cadastro para calcular a altura estimada.',
    'familyEditBabyData': 'Editar dados do bebê',
    'familyCompleteHeights':
        'Para a estimativa, precisamos da altura da mãe e do pai.',
    'familyCompleteHeightsButton': 'Completar alturas',
    'familyEstimatedHeightTitle': 'Altura estimada da {name}',
    'familyMotherHeightLabel': 'Altura da mãe',
    'familyFatherHeightLabel': 'Altura do pai',
    'familyEstimatedGirl': 'Altura estimada para menina',
    'familyEstimatedBoy': 'Altura estimada para menino',
    'familyEstimatedResult': 'aproximadamente {cm}',
    'familyHowCalculated': 'Como é feito o cálculo?',
    'familyFormulaBoy': 'Menino: (altura do pai + altura da mãe + 13) ÷ 2',
    'familyFormulaGirl': 'Menina: (altura do pai + altura da mãe − 13) ÷ 2',
    'familyEstimatedHeightDescription':
        'Estimativa baseada na altura da mãe e do pai, ajustada pelo sexo do bebê. Desconsidera fatores ambientais, nutricionais, de saúde e outros. Serve apenas como referência orientativa.',
    'familyFormulaExampleGirl': '({father} + {mother} − 13) ÷ 2 = {result} cm',
    'familyFormulaExampleBoy': '({father} + {mother} + 13) ÷ 2 = {result} cm',
    'familyHeightDisclaimer':
        'Esta é uma estimativa simples usada como referência em pediatria. A altura final pode variar por genética, alimentação, sono, saúde, puberdade e outros fatores. O acompanhamento com pediatra continua sendo o mais importante.',
    'familyZodiacReadMore': 'Ler texto completo',
    'familyPremiumZodiacLocked':
        'Signos solares e textos personalizados são exclusivos do FaceBaby Premium.',
    'familyPremiumHeightLocked':
        'A altura estimada na vida adulta é exclusiva do FaceBaby Premium.',
    'familyPremiumUnlockCta': 'Desbloquear Premium',
    'familyScreenTitle': 'Família 💜',
    'familyPersonalInfoTitle': 'Informações pessoais',
    'familyHoroscopeCardTitle': 'Astrologia de {sign}',
    'familyBibleVerseCardTitle': 'Versículo Bíblico de hoje.',
    'familyDailySummaryTitle': 'Resumo do dia',
    'familySummaryFeeding': 'Amamentação',
    'familySummaryDiapers': 'Fraldas',
    'familySummarySleep': 'Sono',
    'familySummaryWeight': 'Peso',
    'familyQuickLabelBirth': 'Nascimento',
    'familyQuickLabelTime': 'Hora',
    'familySummaryFeedingsToday': '{n}× hoje',
    'familySummaryDiaperChangesCount': '{n} trocas',
    'familySummaryLastAt': 'Última às {time}',
    'familySummaryLastSleepAt': 'Último às {time}',
    'familySummaryWeightDayLine': 'Total do dia',
    'familyFieldBirthDate': 'Data de nascimento',
    'familyFieldSign': 'Signo',
    'familyFieldElement': 'Elemento',
    'familyFieldAge': 'Idade',
    'familyFieldHeight': 'Altura',
    'familyFieldWeight': 'Peso',
    'familyPremiumShortBadge': 'Premium',
    'familyPremiumFeatureLockedBody':
        'Este conteúdo faz parte do FaceBaby Premium. Toque para ver planos.',
    'familyPremiumBannerTitle': 'Desbloqueie com FaceBaby Plus',
    'familyPremiumBannerBody':
        'Horóscopo familiar com IA, crescimento avançado e conteúdos exclusivos no FaceBaby Plus.',
    'familyPremiumViewPlans': 'Ver planos',
    'familyAddFatherCardTitle': 'Adicionar dados do papai',
    'familyElementFire': 'Fogo',
    'familyElementEarth': 'Terra',
    'familyElementAir': 'Ar',
    'familyElementWater': 'Água',
    'familyTapToOpen': 'Toque para ver detalhes',
    'familyCarouselSwipe': 'Deslize para ver cada integrante',
    'familyTabNene': 'Nenê',
    'familyTabsHint': 'Toque num nome para ver os detalhes',
    'familyTapToClose': 'Fechar',
    'familyShareCard': 'Compartilhar',
    'changeBabyTooltip': 'Trocar bebê',
    'notificationsInboxTitle': 'Notificações',
    'notificationsInboxSubtitle':
        'Últimos 3 dias (enviadas e agendadas registadas na app)',
    'notificationsEmpty': 'Ainda não há notificações registadas neste período.',
    'notificationsKindShown': 'Enviada',
    'notificationsKindScheduled': 'Agendada',
    'notificationsOpenTarget': 'Toque para abrir',
    'notificationsSelectAll': 'Selecionar todos',
    'deleteAccountTitle': 'Deletar conta',
    'deleteAccountBody':
        'Isso vai apagar sua conta e TODOS os seus dados (mãe, bebê e registros) da nuvem.\n\nEssa ação não pode ser desfeita.',
    'deleteAccountConfirm': 'Apagar tudo',
    'deleteAccountDeleting': 'Apagando sua conta...',
    'deleteAccountSuccess': 'Conta apagada com sucesso.',
    'deleteAccountReauthTitle': 'Confirmar senha ou Google',
    'deleteAccountReauthBody':
        'Último passo antes de apagar: confirme o mesmo método com que entra no app (senha do e-mail ou conta Google/Gmail).',
    'deleteAccountReauthGoogleSection': 'Entrou com Google / Gmail',
    'deleteAccountReauthGoogleAccountHint': 'Conta Google: {email}',
    'deleteAccountReauthPasswordSection': 'Entrou com e-mail e senha',
    'deleteAccountReauthOrDivider': 'ou',
    'deleteAccountReauthEmailLabel': 'E-mail da conta',
    'deleteAccountReauthPasswordHint': 'Senha atual',
    'deleteAccountReauthPasswordRequired': 'Digite a senha atual da conta.',
    'deleteAccountReauthGoogle': 'Confirmar com Google (Gmail)',
    'deleteAccountReauthContinue': 'Confirmar com senha',
    'deleteAccountReauthCantPassword':
        'Use o botão do mesmo método de login (Google/Gmail ou e-mail e senha) que usou ao criar a conta.',
    'deleteAccountTypeWordTitle': 'Confirmação final',
    'deleteAccountTypeWordInstruction':
        'Para apagar a conta de forma permanente, digite a palavra delete no campo abaixo. Na sequência, pediremos confirmação com senha ou com Google (Gmail).',
    'deleteAccountTypeWordFieldLabel': 'delete',
    'homeBabyBannerForecastSleep': 'Previsão de dormir',
    'homeBabyBannerForecastWake': 'Previsão de acordar',
    'homeBabyBannerForecastSubtitleSleep':
        'Sinais de sono detectados\ncom base no horário atual',
    'homeBabyBannerForecastSubtitleWake':
        'Baseado no horário atual e padrão para a idade',
    'homeBabyBannerEtaIn': 'em {d}',
    'homeBabyBannerLastDiaper': 'Última fralda',
    'homeBabyBannerNoRecordsYet': 'Sem registros ainda',
    'homeBabyBannerNextBetween': 'Próxima entre {range}',
    'homeBabyBannerDiaperRecommendedUntil': 'Troca recomendada até {d}',
    'homeBabyBannerIdealWindow': 'Janela ideal: {range}',
    'homeConsultationScheduled': 'Consulta marcada',
    'homeBannerChipConsultation': 'Consulta',
    'homeBannerChipDiaper': 'Fralda',
    'homeBannerChipFeed': 'Mamar',
    'homeBannerChipSleep': 'Sono',
    'homeBannerOverdueSleep': 'Passou da hora de dormir',
    'homeBannerOverdueWake': 'Passou da hora de acordar',
    'homeBannerHungry': 'Faminto',
    'homeBannerDiaperDirty': 'Deve estar suja',
    'homeBannerExhausted': 'ESGOTADO',
    'memoryTellMomentTitle': 'Conte sobre esse momento',
    'memoryTellMomentHint':
        'Como foi esse momento? Conte detalhes que você quer guardar…',
    'memoryBabyInfoOptionalTitle': 'Informações do bebê (opcional)',
    'memoryBabyMoodLabel': 'Humor/estado',
    'memoryBabyMoodHint': 'Ex: Feliz',
    'memoryMomentInfoTitle': 'Informações do momento',
    'memoryStatAgeLabel': 'Idade',
    'memoryStatWeightLabel': 'Peso',
    'memoryStatHeightLabel': 'Altura',
    'memoryStatMoodLabel': 'Como estava',
    'memoryMotherNotesLabel': 'Notas da mamãe',
    'memoryTipForYouTitle': 'Dica para você',
    'memoryShareButton': 'Compartilhar',
    'memoryFavoriteButton': 'Favoritar',
    'memoryFavoritedButton': 'Favoritado',
    'weeklyPhotoPublicExplainer':
        'Ao marcar como público, esta foto poderá participar da Foto da Semana e poderá ser vista por outras mães dentro do FaceBaby.',
    'weeklyPhotoPublicOff': 'Privado',
    'weeklyPhotoPublicOn': 'Público',
    'weeklyPhotoPublicNeedPhoto':
        'Adicione uma foto para marcar esta memória como pública.',
    'weeklyPhotoConfirmTitle': 'Tornar esta foto pública?',
    'weeklyPhotoConfirmBody':
        'Você concorda em exibir essa foto para outros usuários caso você seja a sorteada da semana?',
    'weeklyPhotoConfirmNo': 'Não',
    'weeklyPhotoConfirmYes': 'Sim',
    'weeklyPhotoParticipatingBadge': 'Participando da Foto da Semana',
    'weeklyPhotoWinnerBadge':
        'Esta memória foi escolhida como Foto da Semana 💜',
    'weeklyPhotoShowBabyFirstName':
        'Mostrar primeiro nome do bebê no mural público',
    'weeklyPhotoDisclaimerFooter':
        'Somente fotos marcadas como públicas participam. Você pode remover a opção a qualquer momento.',
    'weeklyPhotoReportLink': 'Denunciar',
    'weeklyPhotoReportTitle': 'Denunciar foto',
    'weeklyPhotoReportHint':
        'Descreva o motivo da denúncia. A equipe FaceBaby irá analisar.',
    'weeklyPhotoReportMessageLabel': 'Motivo da denúncia',
    'weeklyPhotoReportSubmit': 'Enviar denúncia',
    'weeklyPhotoReportSuccess':
        'Denúncia enviada. Obrigada por ajudar a manter a comunidade segura.',
    'weeklyPhotoReportNeedLogin':
        'Entre na sua conta para enviar uma denúncia.',
    'weeklyPhotoReportMessageTooShort':
        'Escreva pelo menos 5 caracteres no motivo da denúncia.',
    'weeklyPhotoReportMessageTooLong': 'O texto da denúncia é muito longo.',
    'weeklyPhotoReportFailed':
        'Não foi possível enviar a denúncia. Tente novamente.',
    'weeklyPhotoSectionTitleMale': 'Príncipe da Semana',
    'weeklyPhotoSectionTitleFemale': 'Princesa da Semana',
    'weeklyPhotoHomeHeroMale': 'PRÍNCIPE DA SEMANA',
    'weeklyPhotoHomeHeroFemale': 'PRINCESA DA SEMANA',
    'weeklyPhotoSectionSubtitle':
        'Uma memória especial compartilhada por uma mãe do FaceBaby.',
    'weeklyPhotoViewMemory': 'Ver memória',
    'weeklyPhotoBabyFallback': 'Um bebê FaceBaby',
    'weeklyPhotoDisclaimerShort':
        'Somente fotos marcadas como públicas participam. Você pode remover a opção a qualquer momento.',
    'weeklyPhotoPublicDetailAppBar': 'Memória da semana',
    'weeklyPhotoWinnerCongratsTitle': 'Parabéns Mamãe!',
    'weeklyPhotoWinnerCongratsBody':
        'A foto da sua Princesa foi a escolhida da semana! Vamos todos prestigiá-la.\n\nA família FaceBaby agradece por partilhar este lindo momento conosco! 💜',
    'weeklyPhotoWinnerCongratsBodyMale':
        'A foto do seu Príncipe foi a escolhida da semana! Vamos todos prestigiá-lo.\n\nA família FaceBaby agradece por partilhar este lindo momento conosco! 💜',
    'weeklyPhotoWinnerCongratsBodyFemale':
        'A foto da sua Princesa foi a escolhida da semana! Vamos todos prestigiá-la.\n\nA família FaceBaby agradece por partilhar este lindo momento conosco! 💜',
    'weeklyPhotoWinnerCongratsOk': 'Confirmar',
    'weeklyPhotoLikesCount': '{count} curtidas',
    'weeklyPhotoLikeButton': 'Curtir',
    'weeklyPhotoLikedButton': 'Curtido',
    'weeklyPhotoLikesWinnerHint': 'Pessoas que curtiram a foto do seu bebê',
    'weeklyPhotoLikeNeedSignIn':
        'Inicie sessão com a mesma conta para curtir a Foto da Semana.',
    'memoryEditTitle': 'Editar memória',
    'memoryNewTitle': 'Nova memória',
    'memoryMomNotesFieldLabel': 'Observações da mamãe',
    'memorySaveChanges': 'Guardar alterações',
    'memorySaveNew': 'Salvar memória',
    'memoryNoDescription': 'Sem descrição para este momento.',
    'memoryPhotoAddTitle': 'Adicione uma foto',
    'memoryPhotoEditTitle': 'Altere a foto',
    'memoryTapToPickPhoto': 'Toque',
    'memoryAgeHintExample': 'Ex: 10 dias',
    'memoryWeightHintExample': 'Ex: 3,28',
    'memoryHeightHintExample': 'Ex: 49',
    'memorySaveNeedPhotoOrText':
        'Adicione uma foto ou escreva uma descrição para salvar.',
    'memorySaveFail': 'Não foi possível salvar:',
    'memoryShareWebOnlyMobile':
        'Partilhar imagem ou PDF está disponível na app instalada (Android/iOS).',
    'memoryShareSheetJpegTitle': 'Imagem (JPG)',
    'memoryShareSheetJpegSubtitle':
        'Escolha WhatsApp, Gmail, Bluetooth… na folha do sistema',
    'memoryShareSheetPdfTitle': 'PDF (uma página)',
    'memoryShareSheetPdfSubtitle': 'Bom para email ou arquivo',
    'memorySharePlatformUnavailable': 'Indisponível nesta plataforma.',
    'memoryShareError': 'Não foi possível partilhar: {error}',
    'memoryFooterBranding': 'FaceBaby • Livro de memórias',
    'memoryTipFirstSmile':
        'Sorrir é uma das primeiras formas do bebê se comunicar e criar vínculo. Continue conversando e sorrindo para ele ou ela!',
    'memoryTipFirstLaugh':
        'A risada fortalece o vínculo e mostra que o bebê está confortável. Repita brincadeiras que façam ele ou ela se divertir.',
    'memoryTipFirstFeeding':
        'Os primeiros dias de amamentação são de adaptação. Se tiver dúvidas, peça apoio do pediatra ou consultora.',
    'memoryTipFirstSteps':
        'Cada bebê tem seu ritmo. Ofereça um ambiente seguro e incentive sem pressão — os primeiros passos chegam no tempo certo.',
    'memoryTipDefault':
        'Momentos como este ficam na memória da família para sempre. Continue registrando o que for importante para vocês.',
    'memoryAgeOneDay': '1 dia',
    'memoryAgeManyDays': '{n} dias',
    'helloMomNamed': 'Olá, Mamãe {name}!',
    'registerVerb': 'Registrar',
    'viewCalendar': 'Ver calendário',
    'shortcutMilk': 'Amamentação',
    'shortcutSleep': 'Sono',
    'shortcutVaccines': 'Vacinas',
    'homeFedAgo': 'Amamentou há\u00A0{when}',
    'homePeeAgo': 'Xixi há\u00A0{when}',
    'homePooAgo': 'Cocô há\u00A0{when}',
    'homeNextNow': 'Próxima agora.',
    'homeNextIn': 'Próxima em {n} min.',
    'homeStatusOk': 'Tudo ok agora',
    'homeStatusWarn': 'Atenção leve',
    'homeStatusHungry': 'Pode estar com fome',
    'homeTimeToFeed': 'Hora de amamentar!',
    'homeStatusDetailFed': 'Amamentação recente',
    'homeStatusDetailNear': 'Próximo de amamentar',
    'homeStatusDetailLate': 'Já faz um tempo',
    'homePickDayLabel': 'Dia do resumo',
    'homeTodayLabel': 'Hoje',
    'homeYesterdayLabel': 'Ontem',
    'homeSummaryOnDate': 'Resumo — {date}',
    'homeSummaryPickDayTooltip':
        'Escolher dia do resumo (histórico guardado após o dia terminar)',
    'homeFedAt': 'Amamentação às {time}',
    'homePeeAt': 'Xixi às {time}',
    'homePooAt': 'Cocô às {time}',
    'homeDiaperChangeAgo': 'Troca de Fralda há\u00A0{when}',
    'homeDiaperChangeAt': 'Troca de Fralda às {time}',
    'homeSleepEndedAgo': 'Último sono há\u00A0{when}',
    'homeSleepEndedAt': 'Último sono às {time}',
    'homeSleepInProgress': 'A dormir · {elapsed}',
    'homeSleepPausedBanner': 'Sono pausado · {elapsed}',
    'sleepBannerEmpty': 'Sem sono registado.',
    'homePastDayBadge': 'Dia anterior',
    'homePastDayDetail': 'Horários registrados neste dia',
    'homeBannerAlertCheckDiaper': 'Verificar fralda',
    'homeBannerAlertTimeToSleep': 'Hora de dormir',
    'homeBannerAlertSleepingLong': 'Dormindo há muito tempo',
    'homeCriticalCareTitle': 'Cuidados que precisam de atenção',
    'homeCriticalCareCount': '{n} cuidados precisam de atenção',
    'homeCriticalFeedingTitle': 'Pode ser hora de mamar',
    'homeCriticalSleepTitle': 'Pode ser hora de dormir',
    'homeCriticalDiaperTitle': 'Pode ser hora de trocar a fralda',
    'homeCriticalFeedingSubtitle':
        'Passou do horário esperado desde a última mamada.',
    'homeCriticalSleepSubtitle': 'A janela de sono pode ter sido ultrapassada.',
    'homeCriticalWakeTitle': 'Passou da hora de acordar',
    'homeCriticalWakeSubtitle':
        'A sessão de sono pode ter ultrapassado o tempo recomendado.',
    'homeCriticalDiaperSubtitle': 'Já faz um tempo desde a última troca.',
    'homeSleepBarAwakeTitle': 'Acordado · janela até dormir',
    'homeSleepBarSleepTitle': 'A dormir · tempo da sessão',
    'homeFeedingCounterTitle': 'Alimentação · tempo até ao próximo intervalo',
    'homeFeedingCounterHint':
        'Contagem decrescente (intervalo em Registos rápidos)',
    'homeSleepBarAwakeHintEarly': '≈ {m} min até a janela ideal',
    'homeSleepBarAwakeHintIdeal': '≈ {m} min até o fim da janela',
    'homeSleepBarAwakeHintOverdue':
        'Janela ultrapassada · pode ser hora de dormir',
    'homeSleepBarSleepHint':
        '{remaining} restantes · limite da sessão ~{cap} min',
    'homeSleepBarNeedLastSleep': 'Registe o último sono para ver a linha',
    'homeTipTitle': 'Dica do dia',
    'homeTipBody':
        'Rotinas consistentes ajudam seu bebê a se sentir seguro e tranquilo.',
    'homeYesterdayBabaTitle': 'IA Babá · ontem',
    'homeYesterdayBabaFallback':
        'Registre a rotina de {name} para leitura pediátrica.',
    'homeYesterdayBabaRoutineQuiet':
        'Poucos registros — rotina previsível ajuda a regulação emocional.',
    'homeYesterdayBabaRoutine':
        '{feeds} mamadas · sono {sleep} · {diapers} trocas.',
    'homeYesterdayBabaRoutineLowSleep':
        '{feeds} mamadas · sono {sleep} (reduzido) · {diapers} trocas.',
    'homeYesterdayBabaGrowthBothWithin':
        'Peso e estatura na curva de referência.',
    'homeYesterdayBabaGrowthNoData': 'Atualize peso/altura na curva.',
    'homeYesterdayBabaGrowthBelow':
        'Antropometria abaixo da faixa — alinhe com o pediatra.',
    'homeYesterdayBabaGrowthAbove':
        'Antropometria acima da faixa — acompanhe na consulta.',
    'homeYesterdayBabaGrowthCombo': 'Curva: peso {weight}, estatura {height}.',
    'homeYesterdayBabaBandWithin': 'adequado',
    'homeYesterdayBabaBandBelow': 'abaixo',
    'homeYesterdayBabaBandAbove': 'acima',
    'homeYesterdayBabaBandUnknown': '—',
    'homeAiInsightDailyTitle': 'IA Babá · hoje',
    'homeAiInsightWeeklyTitle': 'IA Babá · semana',
    'aiBubbleDragToClose': 'Arraste até a área vermelha para fechar',
    'aiBubbleCloseZone': 'Solte aqui para fechar',
    'floatingMessageDropToClose': 'Solte aqui para fechar',
    'floatingMessageDropToCloseAll': 'Solte aqui para fechar todos os avisos',
    'floatingMessageLinkOpenFailed':
        'Não foi possível abrir o link. Verifique a URL (https).',
    'aiBubbleOpenLink': 'Abrir link',
    'aiBubblePromoKnowMore': 'Saiba mais',
    'homeAiInsightDailySleepBetter':
        'Hoje {name} dormiu melhor que no dia anterior.',
    'homeAiInsightDailySleepLess':
        'O sono de {name} ficou um pouco mais curto ontem — observe com carinho.',
    'homeAiInsightDailyFeedingBetter':
        'Houve melhora no padrão de alimentação de {name}.',
    'homeAiInsightDailyPeaceful':
        'Hoje {name} teve uma rotina mais tranquila.',
    'homeAiInsightDailyQuiet':
        'Registre a rotina de {name} para insights mais precisos.',
    'homeAiInsightDailyDefault':
        'Estou acompanhando a rotina de {name} com carinho.',
    'homeAiInsightDailyWithGrowth':
        'Rotina de {name} estável · {growth}',
    'homeAiInsightWeeklySleepImproved':
        'Esta semana o sono de {name} melhorou em relação à anterior.',
    'homeAiInsightWeeklyFeedingImproved':
        'Esta semana houve melhora no padrão de alimentação de {name}.',
    'homeAiInsightWeeklyStable':
        'A rotina de {name} seguiu estável nesta semana.',
    'homeAiInsightWeeklyFewData':
        'Registre mais dias da rotina de {name} para o resumo semanal.',
    'homeAiInsightGrowthShortHealthy': 'crescimento na curva esperada',
    'homeAiInsightGrowthShortWatch': 'acompanhe peso/altura na curva',
    'aiBubbleFeverAcute':
        '{name} com sinais de febre agora — hidrate, ambiente fresco e observe a temperatura de hora em hora.',
    'aiBubbleFeverAcuteWithTemp':
        '{name} com {temp}°C — mantenha hidratação e observe de perto nas próximas horas.',
    'aiBubbleFeverAcuteHigh':
        '{name} com {temp}°C (alta). Acompanhe de perto; se não baixar ou piorar, fale com o pediatra.',
    'aiBubbleFeverFollowUp':
        'Como está {name} hoje? Se a febre continuar, vale medir de novo e registrar em Saúde.',
    'aiBubbleFeverFollowUpWithTemp':
        'Lembra da febre de {name} ({temp}°C). Como está a temperatura agora?',
    'aiBubbleFeverRecoveryCheck':
        'Faz {days} dia(s) que anotamos febre em {name}. Ela já melhorou?',
    'aiBubbleConsultToday':
        'Consulta hoje para {name}: {title} às {when}.',
    'aiBubbleVaccineToday': 'Vacina hoje para {name}: {vaccine}.',
    'aiBubbleVaccinesToday':
        '{count} vacinas previstas hoje para {name}.',
    'aiBubbleSleepWakeLong':
        '{name} está dormindo há {hours}h — pode ser hora de acordar com calma.',
    'aiBubbleSleepTracking':
        'Sono de {name} em andamento há {hours}h. Toque para ver o cronômetro.',
    'aiBubbleFeedingCritical':
        'Pode ser hora de mamar: intervalo de alimentação de {name} já passou.',
    'aiBubbleSleepCritical':
        'Pode ser hora de dormir: a vigília de {name} passou da janela sugerida.',
    'aiBubbleSleepApproach':
        'Em breve pode ser hora do próximo sono de {name}.',
    'aiBubbleDiaperCritical':
        'Pode ser hora de trocar a fralda de {name}.',
    'aiBubbleWeightDown':
        'Último peso de {name} ficou abaixo do registro anterior — vale acompanhar.',
    'aiBubbleGrowthWeightBelow':
        'Urgente: o peso de {name} ({value} kg) está abaixo da curva de referência para a idade ({min}–{max} kg). Confira o registro. Neste tipo de alerta, procure um médico ou pediatra para avaliar.',
    'aiBubbleGrowthWeightAbove':
        'Urgente: o peso de {name} ({value} kg) está acima da curva de referência para a idade ({min}–{max} kg). Confira o registro. Neste tipo de alerta, procure um médico ou pediatra para avaliar.',
    'aiBubbleGrowthHeightBelow':
        'Urgente: a altura de {name} ({value} cm) está abaixo da curva de referência para a idade ({min}–{max} cm). Confira o registro. Neste tipo de alerta, procure um médico ou pediatra para avaliar.',
    'aiBubbleGrowthHeightAbove':
        'Urgente: a altura de {name} ({value} cm) está acima da curva de referência para a idade ({min}–{max} cm). Confira o registro. Neste tipo de alerta, procure um médico ou pediatra para avaliar.',
    'aiBubbleGrowthStale':
        'Há {days} dias sem medir peso ou altura de {name}.',
    'aiBubbleGrowthNone':
        'Ainda não há medições de crescimento de {name} — registre peso ou altura.',
    'aiBubbleGrowthWatch':
        'Curva de {name}: {hint}.',
    'aiBubbleTodayEmpty':
        'Poucos registros hoje para {name} — um minuto na rotina já ajuda muito.',
    'homeGreetingSubtitle': 'Que bom te ver aqui hoje!',
    'homeMotivationBanner':
        'Você está fazendo um ótimo trabalho! Pequenos registros, grandes lembranças.',
    'homeMotivationBannerOpenMemories': 'Abrir livro de memórias',
    'summaryWeightNotYet': 'Ainda não registrado',
    'summarySleepNotYet': 'Sem registro hoje',
    'shortcutMilkHomeSub': 'Registrar amamentação',
    'shortcutGrowthHomeSub': 'Registrar peso e altura',
    'shortcutSleepHomeSub': 'Registrar sono',
    'homeTileDiapers': 'Trocas',
    'homeOneDayOld': '1 dia',
    'homeDaysOld': '{d} dias',
    'babyAgeOneWeek': '1 semana',
    'babyAgeWeeks': '{n} semanas',
    'babyAgeOneMonth': '1 mês',
    'babyAgeMonths': '{n} meses',
    'babyAgeOneYear': '1 ano',
    'babyAgeYears': '{n} anos',
    'summaryFeedings': 'AMAMENTAÇÃO',
    'summarySleep': 'SONO',
    'summaryLastFeed': 'Última às {time}',
    'summaryLastSleep': 'Último às {time}',
    'summaryDiapers': 'FRALDAS',
    'summaryFeedingsValue': '{n} · {m} min',
    'summaryFeedingsCountOne': '1 amamentação',
    'summaryFeedingsCountMany': '{n} amamentações',
    'summaryFeedingsMinutes': '{m} min',
    'summaryDiapersValue': 'Total {total} · Xixi {pee} · Cocô {poo}',
    'summaryDiapersTotal': 'Total {total} trocas',
    'summaryDiapersChangesOne': '1 troca',
    'summaryDiapersChangesMany': '{n} trocas',
    'summaryDiapersPeePoo': '{pee} - Xixi    {poo} - Cocô',
    'summarySleepValue': '{s} · {t}',
    'summarySleepSessionsOne': '1 soneca',
    'summarySleepSessionsMany': '{s} sonecas',
    'summaryWeight': 'PESO',
    'homeSummaryExtraHint': 'Totais do dia selecionado',
    'homeSummaryNoRecords': 'Sem Registros',
    'homeSummaryTotalDay': 'Total no dia',
    'add': 'Adicionar',
    'labelWeight': 'Peso',
    'labelHeight': 'Altura',
    'labelHead': 'Perímetro da cabeça',
    'growthTabWeight': 'Peso',
    'growthTabHeight': 'Altura',
    'growthTabHead': 'Cabeça',
    'growthTabSummary': 'Resumo',
    'growthAtBirth': 'Ao nascer',
    'growthCardCurrent': 'Atual',
    'growthCardChange': 'Mudar',
    'growthAddWeight': 'Adicionar peso',
    'growthAddHeight': 'Adicionar altura',
    'growthAddHead': 'Adicionar cabeça',
    'growthSummaryIntro': 'Visão geral de peso e altura.',
    'growthChartCaption': '{name} — {metric}',
    'growthChartDeltaHint':
        'Eixo vertical: variação em relação ao valor ao nascer (0 = ao nascer).',
    'growthCurveSectionTitle': 'Curva de crescimento (altura)',
    'growthCurveSectionTitleWeight': 'Curva de crescimento (peso)',
    'growthCurveDisclaimer':
        'Os dados possuem caráter informativo e não substituem avaliação médica.',
    'growthCurveLegendMin': 'Mínimo saudável',
    'growthCurveLegendAvg': 'Média saudável',
    'growthCurveLegendMax': 'Máximo saudável',
    'growthCurveLegendBaby': 'Evolução do bebê',
    'growthCurveAxisMonths': 'meses',
    'growthCurveReferenceGirls': 'Referência — meninas (0–4 anos)',
    'growthCurveReferenceBoys': 'Referência — meninos (0–4 anos)',
    'growthCurveSexHint':
        'Informe o sexo do bebê no cadastro para usar a curva de referência correta. Exibindo referência para meninas.',
    'growthInsightBandWithin':
        '{name} está na faixa de altura saudável para {sexWord} de {months} meses.',
    'growthInsightBandAbove':
        'A evolução está acima da média saudável para {sexWord} de {months} meses — acompanhamento informativo.',
    'growthInsightBandBelow':
        'A altura está abaixo da faixa mínima saudável para a idade — vale conversar com o pediatra no próximo encontro, sem alarme.',
    'growthInsightBandUnknown':
        'Registre mais medições de altura para acompanhar a curva com calma.',
    'growthInsightSexWordGirl': 'meninas',
    'growthInsightSexWordBoy': 'meninos',
    'growthInsightPeriodHeight':
        'Nos últimos {days} dias, {name} cresceu {delta} cm.',
    'growthInsightPeriodWeight':
        'Nos últimos {days} dias, {name} variou {delta} de peso.',
    'growthInsightWeightBandWithin':
        '{name} está na faixa de peso saudável para {sexWord} de {months} meses.',
    'growthInsightWeightBandAbove':
        'O peso está acima da média saudável para {sexWord} de {months} meses — acompanhamento informativo.',
    'growthInsightWeightBandBelow':
        'O peso está abaixo da faixa mínima saudável para a idade — vale conversar com o pediatra no próximo encontro, sem alarme.',
    'growthInsightWeightBandUnknown':
        'Registre mais medições de peso para acompanhar a curva com calma.',
    'growthInsightCurveConsistent': 'A curva permanece consistente com as medições recentes.',
    'growthInsightVelocityHealthy':
        'A velocidade de crescimento está saudável para a idade.',
    'growthInsightVelocitySlowdown':
        'O crescimento desacelerou levemente, mas ainda pode estar dentro de um ritmo saudável.',
    'growthInsightVelocityAcceleration':
        'Houve uma fase de crescimento um pouco mais acelerada — comum em alguns períodos.',
    'growthInsightVelocityStable':
        'O ritmo de crescimento está estável entre as últimas medições.',
    'growthInsightVelocityGentle':
        'O ritmo entre medições ficou mais lento — acompanhe nas próximas semanas com tranquilidade.',
    'growthInsightVelocityUnknown':
        'Adicione pelo menos duas medições para estimar a velocidade de crescimento.',
    'reportPediatricGrowthInsights': 'Tendências de crescimento (informativo)',
    'reportPediatricSectionGrowthCurve': 'Curva de crescimento (referência)',
    'aiNannyNavLabel': 'IA Babá',
    'aiNannyPhase1Hint': 'O chat chega na próxima fase. Por agora, o atalho já está no menu.',
    'aiNannyTitle': 'IA Babá 24h com você',
    'aiNannySubtitle':
        'Conselheira acolhedora para mãe, pai e família — rotina do bebê e apoio emocional.',
    'aiNannyWelcomeMessage':
        '🤖 Olá! Eu sou a IA Babá 💜\n\n'
        'Sou sua companheira e conselheira: posso ajudar a registrar a rotina (mamadas, sono, vacinas…), '
        'tirar dúvidas sobre o bebê ou a gestação, e ouvir mãe, pai e família quando precisarem desabafar. '
        'Estou aqui com você ✨',
    'aiNannyGrowthCurveContextHeader':
        'ALERTA DE CRESCIMENTO (obrigatório): o bebê está com medição fora da curva de referência para a idade. Se a família perguntar como ele(a) está, sobre peso, altura, saúde ou crescimento, mencione este alerta com carinho — não ignore só para dar uma resposta positiva.',
    'aiNannyGrowthCurveContextFooter':
        'Oriente a conferir se o registro está correto e a procurar o pediatra para avaliar.',
    'aiEmotionalMonthiversary':
        '🤖 Hoje {name} completa {months} {unit} ❤️\n{hint}',
    'aiEmotionalMonthSingular': 'mês',
    'aiEmotionalMonthsPlural': 'meses',
    'aiEmotionalTbtPhoto':
        '🤖 {when}, essa era uma das primeiras fotos da {name} 🥹',
    'aiEmotionalTbtWeek': 'Há 1 semana',
    'aiEmotionalTbtMonth': 'Há 1 mês',
    'aiEmotionalTbtYear': 'Há 1 ano',
    'aiEmotionalAchieveFeedingStreak':
        '🤖 {days} dias seguidos registrando alimentação de {name} 🎉',
    'aiEmotionalAchieve100Records':
        '🤖 {count} registros concluídos com {name} ✨',
    'aiEmotionalAchieveFirstMonth':
        '🤖 Primeiro mês acompanhando {name} no FaceBaby ❤️',
    'aiEmotionalAchieveSleepStable':
        '🤖 A rotina de sono de {name} pareceu mais estável esta semana 🌙',
    'aiEmotionalSpontSleepBetter':
        '🤖 {name} dormiu melhor que ontem 🌙',
    'aiEmotionalSpontFeedingRegular':
        '🤖 O padrão de alimentação de {name} parece mais regular ❤️',
    'aiEmotionalSpontDevelopment':
        '🤖 {name} pode começar a {hint} 👶✨',
    'aiEmotionalSpontSmilePhase': 'sorrir mais nesta fase',
    'aiEmotionalSpontEncouragement': '🤖 Vocês estão indo muito bem com {name} 💕',
    'aiEmotionalSpontGentleCare':
        '🤖 Cuidar de {name} com calma faz diferença — estou aqui com vocês 💜',
    'aiEmotionalDev1Month':
        'Ela está começando a reconhecer vozes familiares ✨',
    'aiEmotionalDev2Months':
        'Ela está descobrindo mais o mundo ao redor ✨',
    'aiEmotionalDev3Months':
        'Os sorrisos e sons novos podem aparecer com mais frequência ✨',
    'aiEmotionalDev4to5Months':
        'Ela explora mais o ambiente e responde ao seu carinho ✨',
    'aiEmotionalDev6to8Months':
        'Ela pode demonstrar mais curiosidade e interação ✨',
    'aiEmotionalDev9to11Months':
        'Ela pode estar mais ativa e comunicativa nesta fase ✨',
    'aiEmotionalDev12to23Months':
        'Cada conquista pequena conta muito nesta fase ✨',
    'aiEmotionalDevToddler':
        'A personalidade dela brilha cada vez mais ✨',
    'aiNannyMockReply':
        'Entendi ❤️ Na próxima fase eu vou responder com base nos registros reais do bebê.',
    'aiNannyInputHint': 'Digite sua pergunta…',
    'aiNannyThinking': 'IA Babá está pensando com carinho…',
    'aiNannyDisclaimer':
        'Conteúdo informativo. Não substitui avaliação médica nem pediatra.',
    'aiNannyPremiumTitle': 'IA Babá 24h com você',
    'aiNannyPremiumBody':
        'IA Babá 24h no FaceBaby Plus: orientações carinhosas com contexto do bebê.',
    'aiNannyPremiumCta': 'Assinar FaceBaby Plus',
    'aiNannyBenefitSmart': 'Respostas inteligentes',
    'aiNannyBenefitPersonal': 'Orientações personalizadas',
    'aiNannyBenefitAlerts': 'Alertas preditivos (em evolução)',
    'aiNannyBenefitRoutines': 'Rotinas personalizadas',
    'aiNannyBenefitContent': 'Conteúdos gerados por IA',
    'aiNannyBenefitAudioSoon': 'Em breve: respostas por áudio',
    'aiNannyAskBelow': 'Faça sua primeira pergunta no campo abaixo.',
    'aiNannyNoBaby': 'Cadastre um bebê para personalizar as respostas.',
    'aiNannyRemainingToday': 'Mensagens restantes hoje: {n}',
    'aiNannyDailyLimitMessage':
        'Você atingiu o limite diário da IA Babá. Volte amanhã.',
    'aiNannyCallFailed':
        'Não consegui responder agora. Tente novamente em alguns instantes.',
    'aiNannyProfileButton': 'Perfil da IA',
    'aiNannyClearChat': 'Apagar conversa',
    'aiNannyClearChatConfirmTitle': 'Apagar toda a conversa?',
    'aiNannyClearChatConfirmBody':
        'Todas as mensagens com a IA Babá serão removidas deste aparelho e da nuvem. Esta ação não pode ser desfeita.',
    'aiNannyClearChatDone': 'Conversa apagada.',
    'aiNannyDeleteExchange': 'Apagar esta troca',
    'aiNannyDeleteExchangeConfirm':
        'Remover esta pergunta e a resposta da IA Babá?',
    'aiNannySignInRequired': 'Faça login para usar a IA Babá.',
    'aiVoiceRecording': 'Gravando… {s}s (máx. 20)',
    'aiVoiceProcessing': 'Transcrevendo e interpretando…',
    'aiVoiceUnderstood': 'Entendi: {text}',
    'aiVoiceConfirmTitle': 'Quer registrar isso?',
    'aiVoiceConfirm': 'Confirmar',
    'aiVoiceMicDenied':
        'Precisamos do microfone para o registro por voz. Ative nas configurações do aparelho.',
    'aiVoiceMicWebUnavailable':
        'Registro por voz está disponível no app Android e iOS.',
    'aiVoiceSavedOk': 'Registro salvo com sucesso.',
    'aiVoiceSavedFeedingAndDiaper': 'Mamada e troca de fralda registradas.',
    'aiVoiceSavedSymptom': 'Sintomas registrados em Saúde.',
    'aiVoiceNeedClarification': '',
    'aiClarifyFeedingPrefix': 'Sobre a mamada:',
    'aiClarifyDiaperPrefix': 'Sobre a fralda:',
    'aiClarifyBreastSide': 'foi peito esquerdo ou direito?',
    'aiClarifyFeedingDuration': 'quantos minutos durou?',
    'aiClarifyRegisterNeeded':
        'Para registrar no app, preciso que você me diga:',
    'aiNannyRecordsFoundTitle': '🤖 Encontrei estes registros',
    'aiNannyConfirmCompleteRecords': 'Confirmar registros completos',
    'aiNannyCompleteMissingData': 'Completar dados faltantes',
    'aiNannySaveAllPossible': 'Salvar tudo possível',
    'aiNannyCancelRecords': 'Cancelar',
    'aiGrowthNeedBaselineWeight':
        'Peso: falta um peso anterior para calcular o ganho.',
    'aiGrowthNeedBaselineHeight':
        'Altura: falta uma medição anterior para calcular o crescimento.',
    'aiGrowthWeightDeltaPreview':
        'Peso: último {prev} kg → novo {next} kg (confirmar)',
    'aiGrowthHeightDeltaPreview':
        'Altura: último {prev} cm → novo {next} cm (confirmar)',
    'aiClarifyFeedingType': 'foi peito ou mamadeira?',
    'aiClarifyDiaperKind': 'tinha xixi, cocô ou os dois?',
    'aiClarifyBreastSideOptions':
        'Qual lado foi usado mais?\n• Esquerdo\n• Direito\n• Ambos',
    'aiClarifyDiaperKindOptions':
        'Que tipo de troca foi?\n• Xixi\n• Cocô\n• Ambos',
    'aiClarifyFeedingTypeOptions':
        'Como foi a alimentação?\n• Peito\n• Mamadeira\n• Fórmula',
    'aiClarifyBottleAmount': 'Quantos ml tomou?',
    'aiClarifySleepStart': 'Quando o sono começou?',
    'aiClarifyVaccineName': 'Qual é o nome da vacina?',
    'aiClarifyVaccineDate': 'Qual a data da vacina?',
    'aiClarifyAppointmentReason': 'Qual especialidade ou motivo?',
    'aiClarifyAppointmentWhen': 'Quando é a consulta (data e hora)?',
    'aiClarifySymptomDetails':
        'Quais sintomas ou temperatura devo registrar?',
    'aiClarifyFeverTemperature':
        'Qual a temperatura agora, em graus? (ex.: 38,5)',
    'aiActionFirstNeedData':
        'Entendi {n} registro(s), mas ainda faltam dados.',
    'aiActionFirstFoundIntro': 'Entendi 😊',
    'aiActionFirstSummarySingle': 'Encontrei:',
    'aiActionFirstSummaryHeader': 'Encontrei:',
    'aiActionFirstFirstQuestionLead': 'Primeiro:',
    'aiActionFirstNextQuestionLead': 'Agora:',
    'aiOrchestratorFinishSleepAndDiaper':
        '🤖 Posso finalizar o sono ativo ({duration}), registrar {diaper}. Deseja salvar?',
    'aiOrchestratorFinishSleepOnly':
        '🤖 Posso finalizar o sono ativo ({duration}) e registrar que ela acordou agora. Deseja salvar?',
    'aiOrchestratorFinishSleepWithStartedAt':
        '🤖 Encontrei um sono ativo iniciado às {startedAt}. Posso finalizar com duração total de {duration}?',
    'aiOrchestratorFinishBreastfeeding':
        '🤖 Posso finalizar a mamada do peito {side} ({duration}). Deseja salvar?',
    'aiOrchestratorDiaperBoth': 'xixi e cocô',
    'aiOrchestratorDiaperPee': 'xixi',
    'aiOrchestratorDiaperPoo': 'cocô',
    'aiActionFirstNeedDataIntro':
        'Agora preciso completar algumas informações.',
    'aiActionFirstAllComplete':
        'Pronto 😊\nOs registros estão completos.',
    'aiActionFirstConfirmCard':
        'Organizei {n} registro(s). Confira o card e toque em confirmar para salvar.',
    'aiRecordCardFeedingDetected': 'Mamada detectada',
    'aiRecordCardDiaperDetected': 'Fralda detectada',
    'aiRecordCardSleepDetected': 'Sono detectado',
    'aiRecordCardSymptomDetected': 'Sintoma detectado',
    'aiRecordCardWeightDetected': 'Peso detectado',
    'aiRecordCardHeightDetected': 'Altura detectada',
    'aiRecordCardVaccineDetected': 'Vacina detectada',
    'aiRecordCardAppointmentDetected': 'Consulta detectada',
    'aiRecordFieldMethod': 'Método',
    'aiRecordFieldSide': 'Lado',
    'aiRecordFieldType': 'Tipo',
    'aiRecordFieldTime': 'Horário',
    'aiRecordFieldDuration': 'Duração',
    'aiRecordFieldAmount': 'Quantidade',
    'aiRecordFieldMissing': 'faltando',
    'aiRecordFieldNow': 'agora (pode editar)',
    'aiRecordFieldAction': 'Ação',
    'aiRecordFieldTemperature': 'Temperatura',
    'aiRecordFieldSymptoms': 'Sintomas',
    'aiRecordFieldValue': 'Valor',
    'aiRecordFieldName': 'Nome',
    'aiRecordFieldStatus': 'Status',
    'aiRecordFieldDate': 'Data',
    'aiRecordFieldReason': 'Motivo',
    'aiRecordFeedingBreast': 'amamentação',
    'aiRecordFeedingBottle': 'mamadeira',
    'aiRecordFeedingFormula': 'fórmula',
    'aiRecordFeedingExpressed': 'leite ordenhado',
    'aiRecordSideLeft': 'esquerdo',
    'aiRecordSideRight': 'direito',
    'aiRecordSideBoth': 'ambos',
    'aiPhaseTranscribing': 'Transcrevendo áudio...',
    'aiPhaseUnderstandingRecords': 'Entendendo registros...',
    'aiPhaseUnderstanding': 'Entendendo sua mensagem...',
    'aiVoiceTranscriptionFailed':
        'Não consegui transcrever o áudio. Tente gravar de novo.',
    'aiPhaseIdentifying': 'Identificando registros...',
    'aiPhasePreparing': 'Preparando confirmação...',
    'aiPhaseSlowWarning': 'Ainda processando...',
    'aiPhaseVerySlow':
        'Estou demorando mais que o normal, mas continuo processando...',
    'aiPhaseShowingResults': 'Quase pronto...',
    'aiExtractionFallbackHint':
        'Não consegui entender tudo. Pode revisar os dados abaixo?',
    'aiConfirmNeedInfoTitle': 'Preciso de algumas informações antes de salvar',
    'aiConfirmAndSaveRecords': 'Confirmar e salvar registros',
    'aiConfirmReadyToSaveVoice':
        'Pronto, agora posso salvar os registros. Deseja confirmar?',
    'aiCardUnderstood': 'Entendi:',
    'aiCardMissing': 'Falta:',
    'aiBadgeComplete': 'Completo',
    'aiBadgeMissingInfo': 'Falta informação',
    'aiBadgeIncomplete': 'Incompleto',
    'aiRecordLabelBreastfeeding': 'Amamentação',
    'aiRecordLabelBottle': 'Mamadeira',
    'aiRecordLabelFeeding': 'Alimentação',
    'aiRecordLabelDiaper': 'Fralda',
    'aiRecordLabelSleep': 'Sono',
    'aiRecordLabelSymptom': 'Sintoma',
    'aiRecordLabelGrowth': 'Crescimento',
    'aiRecordLabelVaccine': 'Vacina',
    'aiRecordLabelAppointment': 'Consulta',
    'aiRecordLabelMemory': 'Memória',
    'aiConfirmCompleteToSaveHint': 'Complete as informações para salvar',
    'aiPendingSessionCancelled': 'Certo, cancelei os registros pendentes.',
    'aiPendingRepeatQuestionIntro': 'Ainda preciso saber:',
    'aiPendingAnswerRecorded': 'Anotado.',
    'aiPendingAnswerAck': 'Perfeito 😊',
    'aiPendingFinishInSheet': 'Abra o card de registros para continuar.',
    'aiPendingMustFinishRecords':
        'Antes de continuar, preciso finalizar estes registros.',
    'aiPendingStateRetry':
        'Pode me dizer de novo o que deseja registrar?',
    'aiPendingRecordsIntroSingle': '🤖 Ainda tenho 1 registro pendente:',
    'aiPendingRecordsIntroPlural': '🤖 Ainda tenho {n} registros pendentes:',
    'aiPendingMissingFieldsLine': 'Falta informar: {fields}.',
    'aiPendingGrowthMissingBaseline':
        'Preciso do último peso registrado para calcular o novo valor.',
    'aiPendingGrowthStatusDelta': 'Crescimento: ganho de {grams}g.',
    'aiPendingGrowthStatusHeightDelta': 'Crescimento: +{cm} cm.',
    'aiPendingVaccineScheduledStatus': 'Vacina agendada para {when}.',
    'aiPendingVaccineNamedStatus': 'Vacina {name} ({when}).',
    'aiPendingVaccineAskNameWithWhen':
        '🤖 Entendi. Quer agendar uma vacina para {when}. Qual é o nome da vacina?',
    'aiPendingGrowthNeedLastWeight':
        '🤖 Entendi que ela ganhou {grams}g. Qual era o último peso registrado?',
    'aiPendingGrowthWeightDeltaConfirm':
        '🤖 Último peso: {prev} kg. Com +{grams}g, o novo peso será {next} kg. Deseja salvar?',
    'aiRecordWhenTomorrow': 'amanhã',
    'aiRecordAtConnector': 'às',
    'aiPendingRequiredFieldCannotSkip':
        'Este campo é obrigatório. Pode responder com uma das opções.',
    'aiFollowUpBreastSideQuestion': 'Sobre a amamentação: qual lado foi usado?',
    'aiFollowUpDurationQuestion': 'Quanto tempo ela mamou?',
    'aiFollowUpBreastLeftDuration': 'Quantos minutos no peito esquerdo?',
    'aiFollowUpBreastRightDuration': 'Quantos minutos no peito direito?',
    'aiPartialSaveSummaryHeader': '🤖 Encontrei estes registros:',
    'aiPartialSaveLineSaved': '{detail}',
    'aiPartialSaveLineNeedsInfo': '{title}: preciso de mais um detalhe',
    'aiPartialSaveLineBreastNeedsDuration':
        '{title}: preciso dos minutos do peito {side}',
    'aiPartialSaveRecordFailed':
        'Não consegui salvar {title}: {reason}',
    'aiFollowUpDiaperTypeQuestion': 'Sobre a fralda: foi xixi, cocô ou ambos?',
    'aiFollowUpSleepStatusQuestion':
        'Agora sobre o sono:\nEla dormiu agora ou já acordou?',
    'aiFollowUpSleepDurationQuestion': 'Quanto tempo ela dormiu?',
    'aiSleepOptionFellAsleepNow': 'Dormiu agora',
    'aiSleepOptionAlreadyWoke': 'Já acordou',
    'aiDiaperOptionPee': 'Xixi',
    'aiDiaperOptionPoo': 'Cocô',
    'aiDiaperOptionBoth': 'Ambos',
    'aiClarifyDiaperChangeNow': 'foi na fralda — você trocou agora?',
    'aiRecordSaveFailed':
        '🤖 Não consegui salvar o registro agora. Tente novamente ou registre manualmente.',
    'aiRecordConfirmedPrefix':
        'Pronto, registrei {line} para {name} às {time}.',
    'aiVaccineScheduledConfirmed':
        'Agendei a vacina {name} para {date} (coluna Próxima na carteirinha).',
    'aiBreastfeedingSavedSuccess':
        '✅ Registrei a mamada no peito {side} por {minutes} minutos.',
    'aiBreastfeedingSaveFailed':
        'Não consegui salvar a mamada. Tente novamente.',
    'aiRecordLineDiaperPee': 'fralda com xixi',
    'aiRecordLineDiaperPoo': 'fralda com cocô',
    'aiRecordLineDiaperBoth': 'fralda com xixi e cocô',
    'aiRecordLineDiaperGeneric': 'troca de fralda',
    'aiRecordLineFeeding': 'mamada',
    'aiRecordLineSleepStart': 'início de sono',
    'aiRecordLineSleepEnd': 'fim de sono',
    'aiRecordLineSleep': 'sono',
    'aiRecordLineWeight': 'peso',
    'aiRecordLineHeight': 'altura',
    'aiRecordLineSymptom': 'sintoma em Saúde',
    'aiRecordLineConsultation': 'a consulta ({title})',
    'aiRecordLineConsultationGeneric': 'a consulta médica',
    'aiRecordLineVaccine': 'a vacina {name}',
    'aiRecordLineVaccineGeneric': 'a vacina',
    'aiRecordLineGeneric': 'registro',
    'aiClarifyAppointmentAddress':
        'Qual o endereço do consultório? Se souber, me envie aqui para eu anotar no registro.',
    'aiRoutineRegisterSkipped': 'Ok, não vou registrar esse evento.',
    'aiVoiceSavedFeeding': 'Mamada registrada.',
    'aiVoiceSleepStarted': 'Sono iniciado — use a tela Sono ou diga "acordou" quando acordar.',
    'aiChatSleepStartedConfirm':
        'Prontinho! Registrei que o bebê foi dormir agora. Na Home e em Sono você verá o sono em andamento.',
    'aiChatSleepEndedConfirm':
        'Sono encerrado e salvo no diário. Obrigada por avisar!',
    'aiChatRegisterSavedConfirm':
        'Registro salvo no app. Confira na Home ou em Registros.',
    'aiVoiceSleepEnded': 'Sono registrado com sucesso.',
    'aiVoiceRecordFailed': 'Não consegui processar o áudio. Tente novamente.',
    'aiVoiceNotARegisterTitle': 'Isso parece uma pergunta, não um registro.',
    'aiVoiceRegisterHint':
        'Para registrar por voz, diga por exemplo: "coloquei pra dormir", "dormiu 1 hora", "pesou 3,5 kg", "altura 60 cm" ou "mamou 120 ml". Para dúvidas, fale normalmente — a IA Babá responde no chat.',
    'aiVoiceHoldMicHint': 'Segure o microfone para falar com a IA Babá.',
    'aiVoiceReleaseHint': 'Solte para enviar…',
    'aiVoiceTapMicHint': 'Toque no microfone para gravar',
    'aiVoiceTapStopHint': 'Toque de novo para enviar o áudio',
    'aiVoiceRecordingHint': 'Gravando… toque no ■ para enviar',
    'aiVoiceListenReply': 'Ouvir resposta',
    'aiTtsPreparing': 'Preparando áudio...',
    'aiTtsPause': 'Pausar',
    'aiTtsResume': 'Continuar',
    'aiTtsRetry': 'Tentar novamente',
    'aiNannyAutoReadLabel': 'Ler respostas em voz alta',
    'aiNannyDeviceVoiceHint':
        'Voz natural indisponível — usando voz do telefone. Verifique internet e atualize o app.',
    'aiNannyTtsFailed':
        'Não consegui reproduzir a voz natural. Verifique volume, internet e login; tente «Ouvir resposta» de novo.',
    'aiVoiceAskAiInstead': 'Perguntar à IA Babá',
    'aiVoiceHealthFieldsHint':
        'Complete os campos abaixo e toque em Confirmar para salvar em Saúde.',
    'aiVoiceHealthTempLabel': 'Temperatura (°C)',
    'aiVoiceHealthVaccineNameLabel': 'Nome da vacina',
    'aiVoiceHealthVaccineDoseLabel': 'Dose (opcional)',
    'aiVoiceHealthVaccineNameRequired': 'Informe o nome da vacina.',
    'aiBabyHistoryTitle': 'Histórico do Bebê',
    'aiBabyHistorySubtitle':
        'Conte características importantes do bebê e da rotina para ajudar a IA Babá a responder de forma mais personalizada.',
    'aiBabyHistoryFieldLabel': 'Histórico importante para a IA',
    'aiBabyHistoryPlaceholder':
        'Exemplo: meu bebê nasceu prematuro, tem refluxo, mama no peito, acorda muito à noite, usa fórmula, possui alergias ou segue alguma orientação do pediatra.',
    'aiBabyHistoryDisclaimer':
        'Essas informações ajudam a IA a responder melhor, mas não substituem orientação médica.',
    'aiBabyHistorySave': 'Salvar histórico',
    'aiBabyHistoryClear': 'Limpar histórico',
    'aiBabyHistorySaved': 'Histórico salvo com sucesso',
    'aiBabyHistoryCleared': 'Histórico removido',
    'aiBabyHistoryClearConfirmTitle': 'Limpar histórico?',
    'aiBabyHistoryClearConfirmBody':
        'A IA Babá deixará de usar essas informações até você preencher de novo.',
    'aiBabyHistoryLinkSubtitle': 'Personalize as respostas da IA Babá',
    'aiBabyHistoryCharCount': '{current} / {max} caracteres',
    'settingsAiBabyHistory': 'Histórico do Bebê para a IA Babá',
    'familyTabTree': 'Família',
    'familyTabHoroscope': 'Horóscopo',
    'familyTabHomily': 'Homilia',
    'familyTabAiHistory': 'Histórico',
    'familyHoroscopeDate': 'Horóscopo de {date}',
    'familyHoroscopeGenerateToday': 'Gerar horóscopo de hoje',
    'familyHoroscopeRefresh': 'Atualizar horóscopo',
    'familyHoroscopeMother': 'Horóscopo da Mamãe',
    'familyHoroscopeFather': 'Horóscopo do Papai',
    'familyHoroscopeBaby': 'Horóscopo do Bebê',
    'familyHoroscopeFamilyEnergy': 'Energia da Família Hoje',
    'familyHoroscopeDailyAdvice': 'Conselho do Dia para a Família',
    'familyHoroscopeDisclaimer':
        'Conteúdo gerado por IA para entretenimento e reflexão familiar. Não substitui orientação profissional.',
    'familyHoroscopeLoading': 'Gerando o horóscopo familiar de hoje…',
    'familyHoroscopeOpenTabHint':
        'Abra esta guia para ver o horóscopo do dia.',
    'aiBubbleHoroscopeReady':
        '✨ O horóscopo familiar de hoje está pronto! Toque abaixo para ler na Família.',
    'aiBubbleHoroscopeOpenLink': 'Ver horóscopo',
    'familyHomilyDate': 'Homilia de {date}',
    'familyHomilyLoading': 'Preparando a homilia do dia no calendário litúrgico…',
    'familyHomilyOpenTabHint':
        'Abra esta guia para ler a homilia cristã do dia.',
    'familyHomilyLiturgicalDay': 'Tempo litúrgico',
    'familyHomilyFeast': 'Festa ou memória',
    'familyHomilyGospel': 'Evangelho do dia',
    'familyHomilyTitle': 'Homilia do dia',
    'familyHomilyFamilyReflection': 'Para refletir em família',
    'familyHomilyDisclaimer':
        'Conteúdo gerado por IA com base no calendário litúrgico católico, para reflexão e fé no lar. Não substitui orientação pastoral.',
    'familyHomilyPremiumTitle': 'Homilia diária com IA',
    'familyHomilyPremiumBody':
        'Receba cada dia uma homilia acolhedora alinhada ao calendário cristão, pensada para a sua família.',
    'aiBubbleHomilyReady':
        '✝️ A homilia de hoje está pronta! Toque abaixo para ler na Família.',
    'aiBubbleHomilyOpenLink': 'Ver homilia',
    'aiBubbleCuriosityTitle': 'Curiosidade do dia ✨',
    'aiBubbleDailyBriefTitle': 'IA Babá · seu dia',
    'familyHomilyErrorGeneric':
        'Não foi possível gerar a homilia agora. Tente novamente.',
    'familyHomilyErrorNotFound':
        'Homilia não encontrada. Tente gerar novamente.',
    'familyHomilyErrorUnauthenticated': 'Faça login para gerar a homilia.',
    'familyHomilyErrorPermission':
        'Homilia diária disponível no plano Premium.',
    'familyHomilyErrorPrecondition':
        'Complete seu cadastro na Família para gerar a homilia.',
    'familyHomilyErrorExhausted':
        'Muitas tentativas agora. Aguarde alguns minutos e tente de novo.',
    'familyHoroscopeRegisterFather':
        'Cadastre o papai para incluir o horóscopo dele na leitura familiar.',
    'familyHoroscopePremiumTitle': 'Horóscopo familiar com IA',
    'familyHoroscopePremiumBody':
        'Desbloqueie leituras diárias afetivas para mamãe, papai e bebê com base nos signos.',
    'familyHoroscopeErrorGeneric':
        'Não foi possível gerar o horóscopo agora. Tente novamente.',
    'familyHoroscopeErrorNotFound':
        'Serviço de horóscopo indisponível. Atualize o app e tente novamente.',
    'familyHoroscopeErrorUnauthenticated': 'Faça login para gerar o horóscopo.',
    'familyHoroscopeErrorPermission':
        'Horóscopo familiar completo disponível no plano Premium.',
    'familyHoroscopeErrorPrecondition':
        'Cadastre as datas de nascimento na Família para gerar o horóscopo.',
    'familyHoroscopeErrorExhausted':
        'Limite temporário atingido. Tente novamente mais tarde.',
    'appUpdateAvailableMessage':
        'Uma nova versão do FaceBaby está disponível ❤️',
    'appUpdateDownloading': 'A atualização está a ser descarregada…',
    'appUpdateReadyToRestart': 'Reinicie para concluir a atualização.',
    'appUpdateActionUpdate': 'Atualizar',
    'appUpdateActionLater': 'Depois',
    'appUpdateRestart': 'Reiniciar',
    'growthHistoryTitle': '{label} (histórico)',
    'invalidGrowthValue': 'Informe um valor válido de {label}.',
    'growthSaved': '{label} registrado com sucesso.',
    'growthEmpty': 'Nenhum registro de {label} ainda.',
    'notifyGrowthWeightDownTitle': 'Peso menor que antes',
    'notifyGrowthWeightDownBody':
        'O último registro de peso está abaixo do anterior. Em caso de dúvida, fale com o pediatra.',
    'notifyGrowthWeightBelowTitle': 'Peso abaixo da curva',
    'notifyGrowthWeightBelowBody':
        'Último peso: {value} kg (curva saudável: {min}–{max} kg). Confira o registro. Neste tipo de alerta, procure um médico ou pediatra.',
    'notifyGrowthWeightAboveTitle': 'Peso acima da curva',
    'notifyGrowthWeightAboveBody':
        'Último peso: {value} kg (curva saudável: {min}–{max} kg). Confira o registro. Neste tipo de alerta, procure um médico ou pediatra.',
    'notifyGrowthHeightBelowTitle': 'Altura abaixo da curva',
    'notifyGrowthHeightBelowBody':
        'Última altura: {value} cm (curva saudável: {min}–{max} cm). Confira o registro. Neste tipo de alerta, procure um médico ou pediatra.',
    'notifyGrowthHeightAboveTitle': 'Altura acima da curva',
    'notifyGrowthHeightAboveBody':
        'Última altura: {value} cm (curva saudável: {min}–{max} cm). Confira o registro. Neste tipo de alerta, procure um médico ou pediatra.',
    'notifyGrowthStaleTitle': 'Há tempo sem registar o crescimento',
    'notifyGrowthStaleBody':
        'Passaram mais de 30 dias desde a última medição (peso, altura ou cabeça). Já são {days} dias — atualize nos registros.',
    'momNoteHint': 'Ex: dormiu melhor depois do banho...',
    'shortcutDiaper': 'Fralda',
    'diaperPagePlaceholder':
        'Em breve você poderá registrar trocas (xixi e cocô). Estamos preparando esta área.',
    'shortcutHealth': 'Saúde',
    'shortcutHealthSubtitle': 'Vacinas e consultas',
    'shortcutFamily': 'Família',
    'shortcutFamilyHomeSub': 'Árvore e perfil familiar',
    'shortcutHealthHomeSub': 'Vacinas, consultas e sintomas',
    'shortcutFeedingSession': 'Alimentação',
    'shortcutFeedingSessionSub': 'Sessão / introdução',
    'healthHubTitle': 'Saúde',
    'healthHubIntro': 'Vacinas, consultas e outros cuidados em um só lugar.',
    'healthHubSection': 'Acesso rápido',
    'healthHubVaccines': 'Carteira de vacinação',
    'healthHubVaccinesSub': 'Registrar e consultar vacinas do bebê',
    'vaccineReminderNotifTitle': 'Vacina',
    'vaccineReminderNotifBody': 'Hoje é dia da vacina: {name}.',
    'homeBannerChipVaccine': 'Vacina hoje',
    'vaccDueConfirmCheckbox': 'Confirmo que esta dose já foi aplicada.',
    'vaccDueSavedOk': 'Vacina registada como aplicada.',
    'vaccDuePickTitle': 'Vacinas previstas hoje',
    'healthHubConsultations': 'Consultas',
    'healthHubConsultationsSub': 'Pediatra e retornos',
    'healthHubSymptomReports': 'Relatar sintoma',
    'healthHubSymptomReportsSub':
        'Febre, cólicas, medicamentos e outros — integrados no relatório pediátrico',
    'symptomReportTitle': 'Relatar sintoma',
    'symptomReportEmpty': 'Ainda não há relatos. Toque em + para registar.',
    'symptomReportNew': 'Novo relato',
    'symptomReportSave': 'Guardar',
    'symptomReportOccurredAt': 'Data e hora',
    'symptomReportPickDateTime': 'Alterar data e hora',
    'symptomReportMedication': 'Medicamentos tomados',
    'symptomReportMedicationHint': 'Nome ou nota breve',
    'symptomReportFever': 'Febre',
    'symptomReportTemp': 'Temperatura',
    'symptomReportTempHint': 'Conforme as unidades definidas nas preferências',
    'symptomReportCrying': 'Choro sem causa aparente',
    'symptomReportPain': 'Dor',
    'symptomReportColic': 'Cólicas',
    'symptomReportReflux': 'Refluxo',
    'symptomReportOther': 'Outro',
    'symptomReportOtherHint': 'Breve descrição',
    'symptomReportValidationNeedOne':
        'Seleccione pelo menos um sintoma ou preencha um campo.',
    'symptomReportValidationFeverTemp':
        'Indique a temperatura quando marcar febre.',
    'symptomReportDeleteTitle': 'Eliminar relato?',
    'symptomReportDeleteBody': 'Esta acção não pode ser desfeita.',
    'consultationsTitle': 'Consultas',
    'consultationsIntro':
        'Registe consultas com data e hora; aparecem no resumo do dia na Home.',
    'consultationsSoonTitle': 'Em breve',
    'consultationsComingBody':
        'Em breve você poderá registrar consultas, anexar notas e lembretes de retorno.',
    'homeSummaryHealthStripTitle': 'Vacinas e consultas neste dia',
    'homeSummaryHealthStripEmpty':
        'Nenhuma Vacina ou Consulta registrada neste dia.',
    'consultationTitleLabel': 'Motivo ou especialidade',
    'consultationNotesHint': 'Notas (opcional)',
    'consultationWhenLabel': 'Data e hora',
    'consultationTitleEmpty': 'Indique o motivo ou especialidade da consulta.',
    'consultationPhoneLabel': 'Telefone do consultório',
    'consultationAddressLabel': 'Endereço',
    'consultationDetailWhen': 'Horário',
    'consultationDetailPhone': 'Telefone',
    'consultationDetailAddress': 'Endereço',
    'consultationDetailNotes': 'Notas',
    'consultationReminderNotifTitle': 'Consulta agendada',
    'consultationReminderNotifBody': 'Amanhã · {title} · {when}',
    'consultationTodayReminderNotifBody': 'Hoje · {title} · {when}',
    'homeConsultationBannerChip': 'Consulta · {title} · {t}',
    'consultationsEmpty': 'Nenhuma consulta registada ainda.',
    'consultationsDayEmpty': 'Nenhuma consulta neste dia.',
    'feedingSessionTitle': 'Sessão de alimentação',
    'feedingSessionIntro':
        'O atalho na Home aparece a partir dos 7 meses ou se você ativar a opção em Mais.',
    'feedingSessionSoonTitle': 'Próximos passos',
    'feedingSessionSoonBody':
        'Aqui entram cardápio, fotos das refeições e resumo do dia. Por enquanto use Registros e siga o pediatra.',
    'settingsFeedingEarlyTitle': 'Alimentação antes dos 7 meses',
    'settingsFeedingEarlySub':
        'Mostra o atalho "Alimentação" na Home mesmo com bebê menor de 7 meses.',
    'settingsAiMicTitle': 'Assistente por voz (microfone)',
    'settingsAiMicSub':
        'Mostra o botão do microfone na tela inicial (em desenvolvimento).',
    'reportNoWeight': 'Sem dados de peso ainda.',
    'reportNoHeight': 'Sem dados de altura ainda.',
    'memoriesPhotoError': 'Não foi possível selecionar a foto.',
    'memoriesTodayTitle': 'Memórias de hoje',
    'memoriesTodayAsk': 'Você já adicionou sua foto de hoje?',
    'memoriesNotYet': 'Ainda não',
    'memoriesAddPhotoDialog': 'Adicionar foto',
    'memoriesAlreadyPostedToday': 'Você já adicionou a foto de hoje.',
    'memoriesWallEmpty':
        'Seu mural ainda está vazio. Adicione a primeira foto do dia!',
    'memoriesHighlights': 'Destaques',
    'memoriesWallSection': 'Mural',
    'settingsMotherProfile': 'Meu Perfil',
    'profileEditMother': 'Editar dados da mãe',
    'profileEditFather': 'Editar dados do pai',
    'profileAddFather': 'Cadastrar pai',
    'profileFatherNotRegisteredTitle': 'Pai ainda não cadastrado',
    'profileFatherNotRegisteredSubtitle':
        'Se você não incluiu o pai no primeiro cadastro, pode adicionar os dados dele aqui a qualquer momento.',
    'profileFatherAddCta': 'Cadastrar pai agora',
    'profileEditBaby': 'Editar dados do bebê',
    'profileDataSaved': 'Dados atualizados.',
    'profileEditData': 'Editar dados',
    'contactTitle': 'Contato',
    'contactIntro':
        'Envie uma mensagem por e-mail. Vamos abrir seu app de e-mail com os dados preenchidos.',
    'contactFieldName': 'Nome',
    'contactFieldEmail': 'Email',
    'contactFieldAge': 'Idade',
    'contactFieldMessage': 'Mensagem',
    'contactSend': 'Enviar',
    'contactEmailSubject': 'Contato pelo app',
    'contactBodyName': 'Nome:',
    'contactBodyEmail': 'Email:',
    'contactBodyAge': 'Idade:',
    'contactBodyMessage': 'Mensagem:',
    'contactCouldNotOpenEmail': 'Não foi possível abrir o app de e-mail.',
    'contactValidationRequired': 'Campo obrigatório.',
    'contactValidationEmail': 'Informe um email válido.',
    'contactValidationAge': 'Informe uma idade válida.',
    'motherProfileTabPreferences': 'Preferências',
    'motherProfileTabMother': 'Mãe',
    'motherProfileTabFather': 'Pai',
    'motherProfileTabBabies': 'Bebês',
    'profileLayoutTitle': 'Layout do app',
    'profileLayoutSubtitle':
        'Modo diurno, noturno ou automático conforme o horário.',
    'profileLayoutAutomatic': 'Auto',
    'profileLayoutDay': 'Diurno',
    'profileLayoutNight': 'Noturno',
    'profileLayoutUpdating': 'Atualizando layout…',
    'motherProfileFieldFatherName': 'Nome',
    'motherProfileNoData':
        'Nenhum perfil encontrado. Tente novamente em instantes.',
    'motherProfileSectionInfo': 'Informações',
    'motherProfileFieldPhone': 'Telefone',
    'motherProfileFieldBirth': 'Nascimento',
    'motherProfileFieldHeight': 'Altura',
    'motherProfileFieldFatherHeight': 'Altura do pai',
    'profileFamilyMessagesTitle': 'Mensagens na tela Família',
    'profileShowChristian': 'Cristã',
    'profileShowHoroscope': 'Astrológica',
    'profileShowPhilosophical': 'Filosófica / Ecumênica',
    'profileShowSpiritist': 'Mensagens espíritas',
    'profileShowJewish': 'Mensagens judaicas',
    'motherProfileAddBaby': 'Adicionar outro bebê',
    'motherProfileNoBabies': 'Nenhum bebê encontrado para este perfil.',
    'motherProfileBabyBornAt': 'Nascimento: {date}',
    'settingsBabyData': 'Dados da bebê',
    'settingsAlerts': 'Alertas',
    'alertsScreenIntro':
        'Resumo das regras dos lembretes. Pode mudar estes interruptores aqui ou nos ecrãs de alimentação, fralda, sono e crescimento/saúde.',
    'alertsExactAlarmAndroidTitle': 'Alarmas na hora (Android)',
    'alertsExactAlarmAndroidBody':
        'Para receber o lembrete de amamentação à hora certa, permita alarmas exactos / «Alarmes e lembretes» para o FaceBaby nas definições do sistema. Sem isto o telemóvel pode atrasar ou não mostrar a notificação.',
    'alertsExactAlarmAndroidOpenSettings': 'Abrir definições',
    'alertsSectionFeeding': 'Alimentação',
    'alertsRuleFeeding':
        'Com o alerta ligado, a app agenda uma notificação local quando passarem os minutos que escolher abaixo desde o fim do último registo ao peito ou mamadeira (o mais recente na base de dados). Sempre que regista novo alimento, o prazo volta a calcular a partir dessa hora.',
    'alertsSectionDiaper': 'Fralda',
    'alertsRuleDiaper':
        'Sugestão fixa na app de cerca de 3 horas e 30 minutos após a última troca registada. Ao guardar uma nova troca, o lembrete é cancelado e reagendado. Respeita a permissão do sistema para notificações.',
    'alertsSectionSleep': 'Sono',
    'alertsRuleSleep':
        'Usando a última hora em que terminou um sono registado e a idade do bebê em meses (data de nascimento no perfil), a app marca até dois tipos de aviso quando o alerta está ligado: um pouco antes de atingir a janela de vigília habitual e outro quando essa janela já pode ter sido ultrapassada. Ao gravar um novo período de sono, os horários são atualizados.',
    'alertsSectionGrowth': 'Crescimento e medições',
    'alertsRuleGrowth':
        'Notificação quando o peso mais recente fica abaixo do registo de peso anterior (por data de medição). Outro aviso quando passam mais de 30 dias sem qualquer medição de peso, altura ou perímetro craniano guardada na app.',
    'alertsTestTitle': 'Testar notificações',
    'alertsTestBody':
        'Dispara um aviso imediato e agenda outro daqui a 30 segundos. Útil para confirmar que o sistema está a entregar as notificações da app.',
    'alertsTestRun': 'Disparar teste',
    'alertsTestResync': 'Forçar reagendamento (lembretes reais)',
    'alertsTestImmediateTitle': 'FaceBaby — teste imediato',
    'alertsTestImmediateBody': 'Se vê esta mensagem, o canal imediato está OK.',
    'alertsTestScheduledTitle': 'FaceBaby — teste agendado',
    'alertsTestScheduledBody': 'Esta foi agendada via AlarmManager (~30s).',
    'alertsTestAllScheduleModesFailed': 'AlarmManager recusou todos os modos',
    'alertsTestSentOk':
        'Enviado. Deve receber agora (imediato) e em ~30s (agendado).',
    'alertsTestFailed': 'Falhou: {errors}',
    'sleepToggleAlertsSubtitle':
        'Lembretes com base no último sono terminado e na idade.',
    'sleepAlertsWakeWindowRulerValueAuto':
        'Tempo efetivo nesta régua: {m} min (automático pela idade).',
    'sleepAlertsWakeWindowRulerValueCustom':
        'Tempo nesta régua: {m} min (valor personalizado).',
    'sleepAlertsWakeWindowSliderLabelAuto': '{m} min · auto',
    'sleepAlertsWakeWindowSliderLabelCustom': '{m} min',
    'sleepAlertsApproachRulerValueDefault':
        'Antecedência efetiva nesta régua: {m} min (padrão).',
    'sleepAlertsApproachRulerValueCustom': 'Antecedência nesta régua: {m} min.',
    'sleepAlertsApproachSliderLabelDefault': '{m} min · padrão',
    'sleepAlertsApproachSliderLabelCustom': '{m} min',
    'sleepAlertsWakeWindowAutomatic':
        'Limite de vigília usado no alerta: {m} min (automático pela tabela por idade).',
    'sleepAlertsWakeWindowAutomaticNoBirth':
        'Adicione a data de nascimento do bebê no perfil para o padrão certo; até lá usamos referência de {m} min.',
    'sleepAlertsMonthsApprox': 'Tabela de referência: ~{n} meses',
    'sleepAlertsWakeWindowCustom': 'Limite de vigília personalizado: {m} min.',
    'sleepAlertsApproachAuto':
        'Aviso antes do limite: {m} min antecedência (valor padrão).',
    'sleepAlertsApproachCustom':
        'Aviso antes do limite: {m} min antecedência (personalizado).',
    'settingsPrivacy': 'Privacidade',
    'settingsSaaS': 'Plano SaaS futuro',
    'loadingMotherPhoto': 'Atualizando foto da mãe…',
    'loadingBabyPhoto': 'Atualizando foto do bebê…',
    'loadingBabies': 'Carregando bebês…',
    'gateLoadProfilesError':
        'Não foi possível ler os dados guardados. É possível que ainda estejam no aparelho; não refaça o cadastro antes de tentar de novo.',
    'gateRetry': 'Tentar novamente',
    'pickBabyTitle': 'Selecionar bebê',
    'switchingBaby': 'Trocando bebê…',
    'sleepAppBar': 'Sono',
    'sleepTitle': 'Sono',
    'sleepIntro': 'Registre e acompanhe as sonecas e o sono noturno.',
    'sleepComingTitle': 'Em breve',
    'sleepComingBody':
        'Essa tela já está pronta para receber o registro de sono.\nNo próximo passo, a gente liga no banco e mostra "último sono", total do dia e histórico.',
    'sleepSessionTitle': 'Sono em andamento',
    'sleepSessionStartedAt': 'Iniciado às {time}',
    'sleepStatusSleeping': 'Dormindo',
    'sleepStatusPaused': 'Pausado',
    'sleepWakeButton': 'ACORDOU?',
    'sleepThisCardTitle': 'Este sono',
    'sleepLabelStart': 'Início',
    'sleepLabelEnd': 'Fim',
    'sleepLabelDuration': 'Duração',
    'sleepLabelQuality': 'Qualidade',
    'sleepObservationsTitle': 'Observações',
    'sleepObservationHint': 'Adicionar observação…',
    'sleepPause': 'Pausar',
    'sleepResume': 'Retomar',
    'sleepCancelSession': 'Cancelar sono',
    'sleepStartButton': 'INICIAR SONO',
    'sleepSavedOk': 'Sono registrado.',
    'sleepResultDialogTitle': 'Status do sono',
    'sleepResultShortTitle': 'Dormiu menos que o esperado',
    'sleepResultExpectedTitle': 'Sono dentro do esperado',
    'sleepResultLongTitle': 'Dormiu mais que o esperado',
    'sleepResultDurationLine': 'Duração registrada: {duration}.',
    'sleepResultExpectedLine':
        'Referência para a idade: cerca de {min}–{max} min.',
    'sleepResultShortBody':
        'Foi um sono curto. Observe sinais de cansaço e tente manter um ambiente calmo para o próximo descanso.',
    'sleepResultExpectedBody':
        'Boa janela de descanso. O sono ficou próximo do esperado para a idade.',
    'sleepResultLongBody':
        'Foi um sono mais longo. Pode ser recuperação de cansaço; acompanhe se isso se repetir com frequência.',
    'sleepConfirmBackTitle': 'Sair do sono?',
    'sleepConfirmBackBody':
        'O registro ainda não foi salvo. Deseja descartar esta sessão?',
    'sleepConfirmCancelSessionTitle': 'Cancelar sono?',
    'sleepConfirmCancelSessionBody': 'O tempo desta sessão será descartado.',
    'sleepDiscard': 'Descartar',
    'sleepHistoryTitle': 'Histórico de sonos',
    'sleepHistoryEmpty': 'Ainda não há sonos registados.',
    'historyShowButton': 'Ver histórico',
    'historyHideButton': 'Ocultar histórico',
    'historyViewMoreButton': 'Ver mais',
    'sleepUpdatedOk': 'Sono atualizado.',
    'sleepBannerNextNap': 'Próximo cochilo em ~{min} min',
    'sleepWindowTitle': 'Janela de sono atual',
    'sleepWindowEarly': 'Antes da janela ideal',
    'sleepWindowIdeal': 'Ideal',
    'sleepWindowLate': 'Passou do ponto',
    'sleepRoutineLastLabel': 'Último sono: há {ago}',
    'sleepRoutineLastNever': 'Último sono: ainda sem registo',
    'sleepRoutineNextPrefix': 'Próximo cochilo:',
    'sleepNextApproxMin': 'em ~{min} min',
    'sleepRoutineNextNow': 'agora — boa hora para tentar',
    'sleepStatusEarly': '🟡 Antes da janela ideal',
    'sleepStatusIdeal': '🟢 Janela ideal',
    'sleepStatusOverdue': '🔴 Pode estar cansada demais',
    'sleepHeroAwakeBadge': 'Acordada',
    'sleepHeroAwakeCaption':
        'A faixa verde → amarela → vermelha mostra há quanto tempo está acordada e quando costuma ser hora de dormir de novo. Quando for deitar, toque em INICIAR SONO.',
    'sleepHeroSleepingBadge': 'A dormir',
    'sleepHeroSleepingCaption':
        'Quando acordar, toque em Terminar sono para gravar este período.',
    'sleepRoutineCardTitle': 'Próximo sono',
    'sleepRoutineVigilHighlight':
        'Vigília ideal neste app: {min}–{max} min acordado entre sonos (fixo por idade em meses — não é configurável).',
    'sleepRoutineStatusLine': 'Estado: {status}',
    'sleepIdealForAge': 'Mesma tabela (por idade)',
    'sleepAgeMonthsLabel': '{n} meses',
    'sleepWindowMinMax': '{min}–{max} min',
    'sleepLegendG': '🟢 janela ideal',
    'sleepLegendY': '🟡 antes da janela ideal',
    'sleepLegendR': '🔴 passou do ponto',
    'sleepWakeWindowExplainer':
        'Mostra há quanto tempo o bebê está acordado desde o fim do último sono (não quanto dormiu). Amarelo: ainda não chegou à faixa típica para o próximo cochilo — não quer dizer que acordou “cedo demais”.',
    'sleepFinalizeButton': 'FINALIZAR',
    'sleepSleepingFor': 'Dormindo há {when}',
    'sleepInsightTitle': 'Resumo do dia',
    'sleepInsightNaps': 'Hoje teve {n} cochilos',
    'sleepInsightAvg': 'Média: {min} min',
    'sleepInsightTrendDown': '💡 Dormiu menos que o padrão hoje',
    'sleepInsightTrendOk': '💡 Padrão de sono estável hoje',
    'sleepHistoryToday': 'Hoje',
    'sleepToggleAlerts': 'Ativar alertas de sono',
    'diaperToggleAlerts': 'Notificações sobre fralda',
    'diaperToggleAlertsSubtitle': 'Lembrete quando sugerimos uma nova troca.',
    'healthGrowthToggleAlerts': 'Alertas de crescimento',
    'healthGrowthToggleAlertsSubtitle':
        'Avisos de peso e ausência prolongada de medições.',
    'feedingScreenAlertsHint': 'Para mudar os minutos, use Mais › Alertas.',
    'sleepNotifTitle': 'Sono',
    'sleepNotifBeforeBody':
        'Pode ser um bom momento para colocar o bebê para dormir.',
    'sleepNotifOverdueBody':
        'Seu bebê pode estar cansado — tente iniciar o sono com calma.',
    'sleepNotifWakeOverdueBodyMale':
        'Já faz mais de {hours} h que está dormindo, dê uma olhada nele, mamãe.',
    'sleepNotifWakeOverdueBodyFemale':
        'Já faz mais de {hours} h que está dormindo, dê uma olhada nela, mamãe.',
    'notifChannelRemindersName': 'Lembretes',
    'notifChannelRemindersDesc': 'Alertas de alimentação, fraldas e sono.',
    'notifChannelGrowthName': 'Crescimento',
    'notifChannelGrowthDesc':
        'Alertas de peso e ausência prolongada de medições.',
    'diaperIntro':
        'Registre uma troca para manter o lembrete funcionando. No histórico, pode editar ou excluir qualquer registo.',
    'diaperSavedOk': 'Troca registrada.',
    'diaperUpdatedOk': 'Troca atualizada.',
    'diaperHistoryTitle': 'Histórico',
    'diaperHistoryEmpty': 'Ainda não há trocas registadas.',
    'diaperKindPee': 'Xixi',
    'diaperKindPoo': 'Cocô',
    'diaperKindBoth': 'Xixi e Cocô',
    'diaperKindLabel': 'Tipo',
    'diaperDashTitle': 'Últimos registos',
    'diaperDashLastPee': 'Último xixi',
    'diaperDashLastPoo': 'Último cocô',
    'diaperDashNoRecordYet': 'Sem registo ainda',
    'diaperDashJustNow': 'Agora há pouco',
    'diaperDashAgoLine': 'há\u00A0{ago}',
    'diaperChangedAtLabel': 'Data e hora',
    'diaperNoteOptional': 'Nota (opcional)',
    'feedingTitle': 'Amamentação',
    'feedingSelectBabyFirst': 'Selecione um bebê antes de iniciar.',
    'feedingNoRunning':
        'Não foi possível finalizar: nenhuma amamentação em andamento.',
    'feedingSavedOk': 'Amamentação registrada.',
    'feedingSaveFail': 'Não foi possível salvar:',
    'feedingSaving': 'Salvando amamentação…',
    'feedingQuickSummary': 'Resumo rápido',
    'feedingNoBabyHint':
        'Cadastre um bebê primeiro em "Mais > Cadastro (mãe e bebês)".',
    'feedingPickBabyLabel': 'Selecionar bebê',
    'feedingEmptyDataHint':
        'Sem dados ainda. Use "Iniciar amamentação" para registrar com 1 toque.',
    'feedingLast': 'Última amamentação',
    'feedingNextEst': 'Próxima estimada',
    'feedingNextIn': 'em ~{n} min',
    'feedingStatusOk': 'OK',
    'feedingStatusLate': 'Atrasado',
    'feedingStatusWarn': 'Atenção',
    'feedingFinish': 'Finalizar amamentação',
    'feedingStart': 'Iniciar amamentação',
    'feedingAfterFinish': 'Registro (após finalizar)',
    'feedingTypeBreast': 'Peito',
    'feedingTypeBottle': 'Mamadeira',
    'feedingTypeSolid': 'Sólidos',
    'feedingTypeLabel': 'Tipo',
    'feedingTabBreastfeeding': 'Amamentação',
    'feedingTabBottle': 'Mamadeira',
    'feedingTabSolids': 'Sólidos',
    'feedingHubTapSidesHint':
        'Toque em E ou D para iniciar o cronômetro. Toque novamente para salvar.',
    'feedingHubLetterLeft': 'E',
    'feedingHubLetterRight': 'D',
    'feedingHubAddManualEntry': 'Adicionar entrada manual',
    'feedingHubOverviewTitle': 'Visão geral dos registros',
    'feedingHubManualTitle': 'Entrada manual (peito)',
    'feedingHubManualMinutes': 'Duração (minutos)',
    'feedingHubManualInvalid': 'Informe uma duração maior que zero.',
    'feedingHubSaveBottle': 'Registrar mamadeira',
    'feedingHubSaveSolid': 'Registrar refeição',
    'feedingHubSolidDescribe': 'O que foi oferecido?',
    'feedingHubSolidRequired': 'Descreva o que foi oferecido antes de salvar.',
    'feedingHubOverviewEmpty': 'Nenhum registro nesta faixa.',
    'feedingHubMlRequired': 'Informe a quantidade em ml.',
    'memoryDeleteBadgeTitle': 'Excluir memória',
    'memoryDeleteBadgeBody':
        'Esta badge voltará a ficar disponível para um novo registro. Deseja excluir?',
    'feedingHubTimerTooShort':
        'Espere pelo menos alguns segundos antes de salvar esta amamentação.',
    'feedingHubBreastPieTitle': 'Qual lado está sendo mais usado?',
    'feedingHubBreastPieEmpty':
        'Registre algumas amamentações (E/D) para ver o gráfico.',
    'feedingHubFeedingUpdatedOk': 'Registro atualizado.',
    'feedingSideLeft': 'Esquerdo',
    'feedingSideRight': 'Direito',
    'feedingSideBoth': 'Ambos',
    'feedingSideLabel': 'Lado',
    'feedingQty': 'Quantidade',
    'feedingQtyMl': 'Quantidade (ml) (opcional)',
    'feedingNote': 'Observação (opcional)',
    'feedingHintRunning': 'Finalize para salvar.',
    'feedingHintIdle':
        'Pronto para registrar a próxima amamentação com 1 toque.',
    'feedingHistory': 'Histórico',
    'feedingNoRecords': 'Ainda sem registros.',
    'feedingHistoryLine': '{time} min • {side}',
    'feedingInsights': 'Insights',
    'feedingInsightsNeed':
        'Registre pelo menos 2 amamentações para ver padrões.',
    'feedingAvgDurFmt': 'Média de tempo: {m} min',
    'feedingAvgIntervalFmt': 'Intervalo médio: {h}h{m}',
    'feedingAlertSection': 'Alerta (opcional)',
    'feedingAlertTitle': 'Ativar alerta de próxima amamentação',
    'feedingModeAvg': 'Média automática',
    'feedingModeManual': 'Intervalo manual',
    'feedingNotifyNote':
        'Obs: por enquanto é só configuração visual. Depois a gente liga notificação.',
    'feedingAgoMinutes': 'há {m} min',
    'feedingAgoHours': 'há {h}h{m}',
    'feedingDurationShort': '{m}m {s}s',
    'feedingDurationSeconds': '{s}s',
    'vaccAddTitle': 'Adicionar vacina',
    'vaccNameField': 'Vacina',
    'vaccDoseOpt': 'Dose (opcional)',
    'vaccDoseHint': 'Ex: 1ª dose / reforço',
    'vaccApplied': 'Aplicada:',
    'vaccNext': 'Próxima:',
    'vaccNotesOpt': 'Observações (opcional)',
    'vaccNameEmpty': 'Informe o nome da vacina.',
    'vaccSaving': 'Salvando vacina…',
    'vaccUpdatedOk': 'Vacina atualizada.',
    'vaccNoBabies':
        'Nenhum bebê cadastrado ainda. Vá em "Mais > Cadastro (mãe e bebê)".',
    'vaccTableVac': 'Vacina',
    'vaccTableDose': 'Dose',
    'vaccTableDate': 'Data',
    'vaccTableNext': 'Próxima',
    'vaccTableNotes': 'Obs.',
    'commonCouldNotSave': 'Não foi possível salvar:',
    'commonSaving': 'Salvando...',
    'commonSave': 'Salvar',
    'commonSelect': 'Selecionar',
    'commonBack': 'Voltar',
    'commonAdvance': 'Avançar',
    'commonClose': 'Fechar',
    'commonName': 'Nome',
    'commonPhone': 'Telefone',
    'openingGallery': 'Abrindo galeria…',
    'devLeapsTitle': 'Saltos de desenvolvimento',
    'devLeapsIntro':
        'Fases comuns do desenvolvimento de {name}. Os textos são acolhedores e sem alarmismo.',
    'devLeapsNeedBirth':
        'Para mostrar as fases por idade, preencha a data de nascimento do bebê no perfil.',
    'devLeapsAllTitle': 'Todas as fases',
    'devLeapsCurrentPill': 'Agora',
    'devLeapsSeeDetails': 'Ver detalhes da fase',
    'devLeapsWhatsHappening': 'O que está acontecendo',
    'devLeapsKeywords': 'Palavras-chave',
    'devLeapsMayHappen': 'O que pode acontecer',
    'devLeapsHowToHelp': 'Como ajudar',
    'devLeapsSkills': 'Habilidades possíveis',
    'devLeapsEmotionalLook': 'Olhar emocional',
    // Banner / cartões de saltos por fase (fallback de idioma: mapa en abaixo).
    'devLeap_dv01_range': 'Semana 1',
    'devLeap_dv01_title': 'Primeira adaptação',
    'devLeap_dv01_lead':
        '{baby_name} pode estar vivendo uma adaptação intensa ao novo ambiente.',
    'devLeap_dv01_emotion': 'Tudo ainda é muito novo.',
    'devLeap_dv02_range': 'Semana 2',
    'devLeap_dv02_title': 'Mais atento',
    'devLeap_dv02_lead':
        '{baby_name} pode estar começando a perceber melhor vozes e rostos.',
    'devLeap_dv02_emotion': 'O vínculo emocional continua crescendo.',
    'devLeap_dv03_range': 'Semana 3',
    'devLeap_dv03_title': 'Mais sensível',
    'devLeap_dv03_lead': '{baby_name} pode estar mais sensível ao ambiente.',
    'devLeap_dv03_emotion': 'O cérebro continua amadurecendo rapidamente.',
    'devLeap_dv04_range': 'Semana 4',
    'devLeap_dv04_title': 'Pequenas interações',
    'devLeap_dv04_lead': '{baby_name} pode estar começando a interagir mais.',
    'devLeap_dv04_emotion': 'O bebê começa a criar conexões sociais.',
    'devLeap_dv05_range': 'Semana 5',
    'devLeap_dv05_title': 'Novas descobertas',
    'devLeap_dv05_lead':
        '{baby_name} pode estar percebendo mais os próprios movimentos.',
    'devLeap_dv05_emotion': 'O corpo começa a ganhar significado.',
    'devLeap_dv06_range': 'Semana 6',
    'devLeap_dv06_title': 'Mais conectado',
    'devLeap_dv06_lead':
        '{baby_name} pode estar mais atento às emoções das pessoas.',
    'devLeap_dv06_emotion': 'O vínculo emocional continua se fortalecendo.',
    'devLeap_dv07_range': 'Semana 7–8',
    'devLeap_dv07_title': 'Sono diferente',
    'devLeap_dv07_lead':
        '{baby_name} pode estar passando por mudanças importantes no sono.',
    'devLeap_dv07_emotion': 'O cérebro está amadurecendo rapidamente.',
    'devLeap_dv08_range': '2–3 meses',
    'devLeap_dv08_title': 'Mais consciente',
    'devLeap_dv08_lead':
        '{baby_name} pode estar percebendo mais o próprio corpo e o ambiente.',
    'devLeap_dv08_emotion': 'Pequenas descobertas acontecem todos os dias.',
    'devLeap_dv09_range': '3–4 meses',
    'devLeap_dv09_title': 'Muito mais interação',
    'devLeap_dv09_lead': '{baby_name} pode estar muito mais sociável.',
    'devLeap_dv09_emotion': 'O vínculo social cresce rapidamente.',
    'devLeap_dv10_range': '4–5 meses',
    'devLeap_dv10_title': 'Explorando mais',
    'devLeap_dv10_lead': '{baby_name} pode estar muito mais curioso.',
    'devLeap_dv10_emotion': 'O aprendizado acontece através da experiência.',
    'devLeap_dv11_range': '5–6 meses',
    'devLeap_dv11_title': 'Mais comunicação',
    'devLeap_dv11_lead':
        '{baby_name} pode estar tentando interagir cada vez mais.',
    'devLeap_dv11_emotion': 'A comunicação começa a ganhar força.',
    'devLeap_dv12_range': '6–7 meses',
    'devLeap_dv12_title': 'Mundo maior',
    'devLeap_dv12_lead':
        '{baby_name} pode estar percebendo melhor o espaço e o ambiente.',
    'devLeap_dv12_emotion': 'O mundo parece cada vez maior.',
    'devLeap_dv13_range': '7–8 meses',
    'devLeap_dv13_title': 'Mais apego',
    'devLeap_dv13_lead':
        '{baby_name} pode estar vivendo uma fase de maior necessidade emocional.',
    'devLeap_dv13_emotion': 'O vínculo emocional se fortalece.',
    'devLeap_dv14_range': '8–9 meses',
    'devLeap_dv14_title': 'Muitas conexões',
    'devLeap_dv14_lead':
        '{baby_name} pode estar criando novas conexões rapidamente.',
    'devLeap_dv14_emotion': 'O cérebro está extremamente ativo.',
    'devLeap_dv15_range': '9–10 meses',
    'devLeap_dv15_title': 'Não para quieto',
    'devLeap_dv15_lead':
        '{baby_name} pode estar em uma fase de muita movimentação.',
    'devLeap_dv15_emotion': 'O corpo e o cérebro trabalham juntos nessa fase.',
    'devLeap_dv16_range': '10–11 meses',
    'devLeap_dv16_title': 'Tentando se comunicar',
    'devLeap_dv16_lead':
        '{baby_name} pode estar observando e imitando muito mais.',
    'devLeap_dv16_emotion': 'A comunicação ganha força.',
    'devLeap_dv17_range': '11–12 meses',
    'devLeap_dv17_title': 'Mais autonomia',
    'devLeap_dv17_lead':
        '{baby_name} pode estar tentando fazer mais coisas sozinho.',
    'devLeap_dv17_emotion': 'A independência começa a aparecer.',
    'devLeap_dv18_range': '12–18 meses',
    'devLeap_dv18_title': 'Muitas emoções',
    'devLeap_dv18_lead':
        '{baby_name} pode estar vivendo emoções mais intensas.',
    'devLeap_dv18_emotion': 'O mundo emocional está crescendo rapidamente.',
    'devLeap_dv19_range': '18–24 meses',
    'devLeap_dv19_title': 'Faz de conta',
    'devLeap_dv19_lead':
        '{baby_name} pode estar entrando em uma fase de imaginação intensa.',
    'devLeap_dv19_emotion': 'A imaginação começa a florescer.',
    'devLeap_dv20_range': '2–3 anos',
    'devLeap_dv20_title': 'Grande personalidade',
    'devLeap_dv20_lead':
        '{baby_name} pode estar vivendo uma fase de muita independência e imaginação.',
    'devLeap_dv20_emotion': 'A identidade da criança cresce rapidamente.',

    // Development leap detail + card bullets (PT: uma lista por texto com \\n entre itens)
    'devLeap_dv01_homeBullets':
        'quer muito colo\nacorda frequentemente\nestranha sons e luzes\nprecisa de contato constante',
    'devLeap_dv01_detailWhats':
        'Seu bebê passou muitos meses em um ambiente silencioso, protegido e quentinho. Agora tudo mudou — e o cérebro ainda está tentando entender luz, frio, fome, sono, toque e sons.',
    'devLeap_dv01_keywords':
        'adaptação\nvínculo\nsegurança\nsensibilidade\nacolhimento',
    'devLeap_dv01_detailMay':
        'choros frequentes\ndespertares frequentes\nnecessidade constante de colo\nsono irregular\nmaior sensibilidade',
    'devLeap_dv01_detailHelp':
        'pele com pele\nvoz calma\npouca luz\nreduzir estímulos\nacolhimento constante',
    'devLeap_dv01_detailSkills':
        'reconhecer cheiro da mãe\nreagir a sons\nreflexos primitivos',
    'devLeap_dv01_detailEmotional':
        'Seu bebê ainda não entende rotina. Ele entende presença, calor e segurança.',
    'devLeap_dv02_homeBullets':
        'observa mais\nreconhece vozes\nfica atento ao colo\ncomeça pequenas interações',
    'devLeap_dv02_detailWhats':
        'O bebê começa lentamente a perceber rostos, vozes, cheiros e presença emocional. A voz da mãe costuma trazer conforto e previsibilidade.',
    'devLeap_dv02_keywords':
        'reconhecimento\nconexão\nconforto\npresença\nobservação',
    'devLeap_dv02_detailMay':
        'mais observação\nperíodos acordado maior\nreação à voz\nmais calma no colo',
    'devLeap_dv02_detailHelp':
        'conversar olhando nos olhos\ncantar músicas suaves\ncontato visual\nacolhimento',
    'devLeap_dv02_detailSkills':
        'acompanhar rostos\nreconhecer vozes\nobservar movimentos',
    'devLeap_dv02_detailEmotional':
        'Mesmo pequeno, o bebê já começa a construir memórias emocionais.',
    'devLeap_dv03_homeBullets':
        'chora mais no fim do dia\nquer mais colo\nse irrita facilmente\ntem dificuldade para relaxar',
    'devLeap_dv03_detailWhats':
        'O sistema nervoso do bebê ainda está muito imaturo. Tudo pode parecer intenso: sons, luzes, fome, cansaço e estímulos.',
    'devLeap_dv03_keywords':
        'sensibilidade\nirritação\nacolhimento\nsobrecarga\nnecessidade emocional',
    'devLeap_dv03_detailMay':
        'choros no fim do dia\nagitação\ndificuldade para dormir\nnecessidade maior de colo',
    'devLeap_dv03_detailHelp':
        'ambiente silencioso\npouca luz\ncolo\nembalo suave\nreduzir estímulos',
    'devLeap_dv03_detailSkills':
        'mais expressões faciais\nmaior atenção ao ambiente',
    'devLeap_dv03_detailEmotional':
        'Seu bebê não está “difícil”. Ele ainda está aprendendo a lidar com o mundo.',
    'devLeap_dv04_homeBullets':
        'observa rostos\nacompanha movimentos\ndemonstra atenção\nreage mais às pessoas',
    'devLeap_dv04_detailWhats':
        'O bebê começa a prestar mais atenção, acompanhar pessoas, perceber expressões e reagir ao ambiente.',
    'devLeap_dv04_keywords':
        'interação\natenção\nobservação\nexpressões\nconexão',
    'devLeap_dv04_detailMay':
        'mais atenção visual\nsons diferentes\nmais períodos acordado\nreação social maior',
    'devLeap_dv04_detailHelp':
        'conversar bastante\nfazer expressões faciais\nmostrar objetos simples\nrespeitar sinais de sono',
    'devLeap_dv04_detailSkills':
        'acompanhar objetos\ndemonstrar interesse social\nreagir a expressões',
    'devLeap_dv04_detailEmotional':
        'O bebê aprende sobre o mundo através das relações.',
    'devLeap_dv05_homeBullets':
        'observa as mãos\nmovimenta mais os braços\nfaz novos sons\nfica mais curioso',
    'devLeap_dv05_detailWhats':
        'O bebê começa a perceber mãos, braços, movimentos e sensações corporais.',
    'devLeap_dv05_keywords':
        'corpo\ndescoberta\ncoordenação\ncuriosidade\nmovimento',
    'devLeap_dv05_detailMay':
        'observar as mãos\nmovimentos repetitivos\nnovos sons\nmais expressões',
    'devLeap_dv05_detailHelp':
        'tummy time\nbrinquedos leves\ncontato visual\nconversa constante',
    'devLeap_dv05_detailSkills':
        'levantar cabeça\nobservar mãos\nreagir ao próprio movimento',
    'devLeap_dv05_detailEmotional':
        'Cada descoberta ajuda o bebê a construir confiança.',
    'devLeap_dv06_homeBullets':
        'observa expressões\nreage ao tom de voz\nquer mais interação\nfica mais sociável',
    'devLeap_dv06_detailWhats':
        'O bebê começa a perceber emoções, tom de voz, expressões faciais e presença emocional.',
    'devLeap_dv06_keywords': 'emoções\nvínculo\ninteração\nsegurança\npresença',
    'devLeap_dv06_detailMay':
        'mais sorrisos\nsons diferentes\nbusca por interação\nmais atenção social',
    'devLeap_dv06_detailHelp':
        'sorrir para o bebê\nconversar frequentemente\nusar voz tranquila\ninteragir com calma',
    'devLeap_dv06_detailSkills':
        'sorriso social\nreação emocional\ninteração maior',
    'devLeap_dv06_detailEmotional':
        'Seu bebê aprende segurança através das interações diárias.',
    'devLeap_dv07_homeBullets':
        'acorda mais\ndorme leve\nfica mais irritado\nprecisa mais de acolhimento',
    'devLeap_dv07_detailWhats':
        'O cérebro começa a criar ciclos de sono mais complexos. O sono deixa de ser totalmente profundo e passa a ter transições, despertares e ciclos mais leves.',
    'devLeap_dv07_keywords':
        'sono\ndespertares\nsensibilidade\nmaturação cerebral\nirritação',
    'devLeap_dv07_detailMay':
        'cochilos curtos\nmais despertares\nirritação\ndificuldade para relaxar',
    'devLeap_dv07_detailHelp':
        'rotina leve\nambiente escuro\nmenos estímulos\nrespeitar sinais de sono',
    'devLeap_dv07_detailSkills':
        'mais interação\ncuriosidade maior\nnovas expressões',
    'devLeap_dv07_detailEmotional':
        'Mudanças no sono não significam regressão. O cérebro está evoluindo.',
    'devLeap_dv08_homeBullets':
        'observa as mãos\nfaz novos sons\ndemonstra mais curiosidade\nreage mais às pessoas',
    'devLeap_dv08_detailWhats':
        'O bebê começa a perceber que consegue interagir com o ambiente. Ele aprende movimento, resposta emocional, coordenação e percepção visual.',
    'devLeap_dv08_keywords':
        'consciência corporal\ncoordenação\ncuriosidade\ndescoberta\npercepção',
    'devLeap_dv08_detailMay':
        'movimentos repetitivos\nobservação intensa\nmais interação\nnovos sons',
    'devLeap_dv08_detailHelp':
        'tummy time\nbrinquedos simples\ninteração visual\nconversas suaves',
    'devLeap_dv08_detailSkills':
        'levantar mais a cabeça\nobservar objetos\nreagir ao ambiente',
    'devLeap_dv08_detailEmotional':
        'Cada nova descoberta fortalece a confiança do bebê.',
    'devLeap_dv09_homeBullets':
        'ri mais\nresponde às pessoas\nfaz sons\nquer brincar',
    'devLeap_dv09_detailWhats':
        'O bebê começa a perceber melhor emoções, vozes, expressões e interação social.',
    'devLeap_dv09_keywords':
        'socialização\ngargalhadas\ncomunicação\nexpressões\nvínculo',
    'devLeap_dv09_detailMay':
        'mais risadas\nsons repetitivos\nmaior interação\nbusca por brincadeiras',
    'devLeap_dv09_detailHelp':
        'brincar bastante\nfazer expressões\nresponder aos sons\nconversar frequentemente',
    'devLeap_dv09_detailSkills':
        'gargalhadas\nreação emocional intensa\ninteresse social',
    'devLeap_dv09_detailEmotional':
        'Seu bebê aprende amor e segurança através das interações.',
    'devLeap_dv10_homeBullets':
        'tenta pegar objetos\nleva coisas à boca\nobserva detalhes\nquer explorar',
    'devLeap_dv10_detailWhats':
        'O bebê desenvolve coordenação, curiosidade intensa, exploração sensorial e percepção espacial.',
    'devLeap_dv10_keywords':
        'exploração\ncoordenação\ncuriosidade\nsensações\ndescoberta',
    'devLeap_dv10_detailMay':
        'pegar objetos\nlevar itens à boca\nmais energia\nmais atenção visual',
    'devLeap_dv10_detailHelp':
        'brinquedos seguros\nestímulos variados\nsupervisão constante\npermitir exploração',
    'devLeap_dv10_detailSkills':
        'rolar\nalcançar objetos\nmanipular brinquedos',
    'devLeap_dv10_detailEmotional':
        'Explorar é a principal forma de aprendizado nessa fase.',
    'devLeap_dv11_homeBullets':
        'faz novos sons\nresponde às pessoas\nquer brincar\ndemonstra emoções',
    'devLeap_dv11_detailWhats':
        'O bebê aprende interação social, troca emocional, comunicação inicial e resposta ao ambiente.',
    'devLeap_dv11_keywords':
        'linguagem\ncomunicação\ninteração\nsocialização\nvínculo',
    'devLeap_dv11_detailMay':
        'balbucios\nmais risadas\ninteração constante\nbusca por atenção',
    'devLeap_dv11_detailHelp':
        'responder aos sons\nconversar muito\nbrincar frequentemente\ncantar músicas',
    'devLeap_dv11_detailSkills':
        'balbuciar\nresponder ao nome\nmais expressão emocional',
    'devLeap_dv11_detailEmotional':
        'O bebê aprende conexão antes mesmo das palavras.',
    'devLeap_dv12_homeBullets':
        'quer explorar\nobserva mais\ntenta alcançar coisas\ndemonstra curiosidade intensa',
    'devLeap_dv12_detailWhats':
        'O bebê começa a compreender distância, espaço, movimento, exploração.',
    'devLeap_dv12_keywords':
        'percepção espacial\nexploração\ncuriosidade\nmovimento\ndescoberta',
    'devLeap_dv12_detailMay':
        'querer se movimentar\nexplorar objetos\nmais atenção ao ambiente\nmais energia',
    'devLeap_dv12_detailHelp':
        'permitir exploração segura\nbrinquedos variados\nespaço livre supervisionado',
    'devLeap_dv12_detailSkills':
        'arrastar\nalcançar objetos distantes\nsentar melhor',
    'devLeap_dv12_detailEmotional':
        'Explorar o ambiente ajuda o bebê a construir confiança.',
    'devLeap_dv13_homeBullets':
        'quer mais colo\nestranha pessoas\nchora quando você sai\nfica mais sensível',
    'devLeap_dv13_detailWhats':
        'O bebê começa a compreender ausência, distância, separação e retorno.',
    'devLeap_dv13_keywords':
        'apego\nvínculo\nansiedade de separação\nsegurança emocional\nsensibilidade',
    'devLeap_dv13_detailMay':
        'mais choros\ndificuldade para dormir sozinho\nnecessidade de colo\nestranhar desconhecidos',
    'devLeap_dv13_detailHelp':
        'despedidas leves\nacolhimento\nprevisibilidade\npresença emocional',
    'devLeap_dv13_detailSkills':
        'reconhecer ausência\nprocurar a mãe\nresponder emocionalmente',
    'devLeap_dv13_detailEmotional':
        'Seu bebê não está “manhoso”. Ele está aprendendo sobre segurança emocional.',
    'devLeap_dv14_homeBullets':
        'observa muito\nreage mais\naprende rápido\nexplora constantemente',
    'devLeap_dv14_detailWhats':
        'O bebê começa a desenvolver lógica básica, causa e efeito, permanência de objetos e reconhecimento de padrões.',
    'devLeap_dv14_keywords':
        'lógica\nconexões\nobservação\naprendizado\npadrões',
    'devLeap_dv14_detailMay':
        'brincar escondendo objetos\nrepetir ações\ncuriosidade intensa\nexplorar reações',
    'devLeap_dv14_detailHelp':
        'brincadeiras simples\nesconder brinquedos\nmúsicas repetitivas\ninteração constante',
    'devLeap_dv14_detailSkills': 'bater palmas\nengatinhar\nprocurar objetos',
    'devLeap_dv14_detailEmotional':
        'O bebê aprende muito através da repetição.',
    'devLeap_dv15_homeBullets':
        'quer explorar tudo\ntenta se mover constantemente\nmexe em objetos\ndemonstra muita energia',
    'devLeap_dv15_detailWhats':
        'O bebê percebe que consegue agir no ambiente: empurra, abre, alcança, joga e explora.',
    'devLeap_dv15_keywords':
        'movimento\ncoordenação\nexploração\ncuriosidade\nautonomia',
    'devLeap_dv15_detailMay':
        'agitação\nexploração intensa\nmais tombos\ndificuldade para ficar parado',
    'devLeap_dv15_detailHelp':
        'ambiente seguro\npermitir exploração\nsupervisão constante\nbrinquedos sensoriais',
    'devLeap_dv15_detailSkills': 'levantar\napoiar em móveis\nexplorar a casa',
    'devLeap_dv15_detailEmotional':
        'Explorar é a forma do bebê entender o mundo.',
    'devLeap_dv16_homeBullets':
        'repete sons\nobserva expressões\ntenta interagir\nresponde mais às pessoas',
    'devLeap_dv16_detailWhats':
        'O bebê descobre que sons têm significado, gestos geram respostas e comunicação aproxima pessoas.',
    'devLeap_dv16_keywords':
        'linguagem\nimitação\ncomunicação\nexpressão\ninteração',
    'devLeap_dv16_detailMay':
        'sons repetitivos\ntentativa de chamar atenção\nmais expressões\nobservação intensa',
    'devLeap_dv16_detailHelp':
        'conversar bastante\nnomear objetos\nresponder aos sons\nler livros simples',
    'devLeap_dv16_detailSkills':
        'apontar\nrepetir sons\nentender palavras simples',
    'devLeap_dv16_detailEmotional':
        'Antes das palavras, o bebê aprende conexão através da comunicação.',
    'devLeap_dv17_homeBullets':
        'tenta andar\nexplora tudo\ndemonstra preferências\ntesta limites',
    'devLeap_dv17_detailWhats':
        'O bebê percebe que pode agir sozinho no ambiente. Isso traz entusiasmo, curiosidade, insegurança e frustração.',
    'devLeap_dv17_keywords':
        'autonomia\nindependência\nexploração\nconfiança\nmovimento',
    'devLeap_dv17_detailMay':
        'tentativas de andar\nresistência a ajuda\nexploração intensa\nfrustrações rápidas',
    'devLeap_dv17_detailHelp':
        'incentivar tentativas\nambiente seguro\nacolher frustrações\ncelebrar conquistas',
    'devLeap_dv17_detailSkills':
        'primeiros passos\nprimeiras palavras\nmais autonomia',
    'devLeap_dv17_detailEmotional': 'Cada tentativa constrói confiança.',
    'devLeap_dv18_homeBullets':
        'quer independência\nse frustra facilmente\nmuda rápido de humor\ndemonstra personalidade',
    'devLeap_dv18_detailWhats':
        'A criança começa a perceber vontades próprias, limites, desejos e frustrações — mas ainda não consegue regular emoções sozinha.',
    'devLeap_dv18_keywords':
        'emoções\nautonomia\nfrustração\npersonalidade\nsensibilidade',
    'devLeap_dv18_detailMay':
        'choros intensos\nirritação\nresistência\nbusca por independência',
    'devLeap_dv18_detailHelp':
        'acolher emoções\nnomear sentimentos\nmanter calma\nreforçar segurança emocional',
    'devLeap_dv18_detailSkills':
        'comer sozinho\nandar melhor\nimitar adultos\nfalar mais palavras',
    'devLeap_dv18_detailEmotional':
        'A criança ainda está aprendendo a lidar com emoções grandes demais para a idade.',
    'devLeap_dv19_homeBullets':
        'brinca diferente\ncria histórias\nconversa mais\ndemonstra criatividade',
    'devLeap_dv19_detailWhats':
        'A criança começa a desenvolver pensamento simbólico, criatividade, imaginação e linguagem mais complexa.',
    'devLeap_dv19_keywords':
        'imaginação\ncriatividade\nlinguagem\nbrincadeira\nexpressão',
    'devLeap_dv19_detailMay':
        'brincadeiras de faz de conta\nmais perguntas\nhistórias inventadas\nfala acelerada',
    'devLeap_dv19_detailHelp':
        'brincadeiras livres\nleitura\nmúsicas\ndesenhos\nconversas frequentes',
    'devLeap_dv19_detailSkills':
        'frases maiores\nbrincadeiras simbólicas\nmaior interação social',
    'devLeap_dv19_detailEmotional':
        'Imaginar é uma forma importante de construir inteligência emocional.',
    'devLeap_dv20_homeBullets':
        'faz muitas perguntas\nquer decidir tudo\ndemonstra emoções fortes\ncria histórias',
    'devLeap_dv20_detailWhats':
        'A criança desenvolve identidade própria, imaginação intensa, linguagem avançada e emoções mais complexas.',
    'devLeap_dv20_keywords':
        'personalidade\nindependência\nimaginação\nemoções\ncriatividade',
    'devLeap_dv20_detailMay':
        'muitas perguntas\nmudanças rápidas de humor\nnecessidade de independência\nbrincadeiras imaginativas',
    'devLeap_dv20_detailHelp':
        'incentivar criatividade\nconversar bastante\najudar a nomear emoções\ndar pequenas responsabilidades',
    'devLeap_dv20_detailSkills':
        'contar histórias\ncriar personagens\nconversar claramente\nresolver pequenas situações',
    'devLeap_dv20_detailEmotional':
        'Cada criança possui seu próprio ritmo. Comparações podem gerar ansiedade desnecessária.',
    'regAppBarTitle': 'Cadastro: mãe e bebês',
    'regLetsStart': 'Vamos começar',
    'regSubtitleMandatory': 'Cadastre a mamãe e o bebê para liberar o app.',
    'regSubtitleOptional': 'Cadastre a mamãe e adicione um ou mais bebês.',
    'regStepMother': 'Mãe',
    'regStepBaby': 'Bebê',
    'regMotherSection': '1) Cadastro da mãe',
    'regBabySection': '2) Cadastro do bebê',
    'regBirthLabel': 'Nascimento:',
    'regMotherHeight': 'Altura (cm)',
    'regFatherSection': 'Dados do papai (opcional)',
    'regFatherName': 'Nome do papai',
    'regFatherBirthLabel': 'Nascimento do papai',
    'regFatherHeight': 'Altura do papai (cm)',
    'settingsFamilyTree': 'Família',
    'fatherPhotoTitle': 'Foto do papai',
    'regFatherPhotoAdd': 'Adicionar foto do papai',
    'regFatherPhotoChange': 'Trocar foto do papai',
    'regMotherPhotoAdd': 'Foto da mãe (opcional)',
    'regMotherPhotoChange': 'Trocar foto da mãe',
    'regBabyPhotoAdd': 'Foto do bebê (opcional)',
    'regBabyPhotoChange': 'Trocar foto do bebê',
    'regSaveMotherAdvance': 'Salvar e avançar',
    'regSaveBaby': 'Salvar bebê',
    'regSelectMotherPrompt': 'Ou selecione uma mãe já cadastrada:',
    'regMotherLabel': 'Mãe',
    'regBabyGirl': 'Menina',
    'regBabyBoy': 'Menino',
    'regZodiacLine': 'Signo: {sign}',
    'regBabyWeight': 'Peso (kg)',
    'regRegisteredList': 'Cadastradas',
    'regNoneYet': 'Nenhum cadastro ainda.',
    'regBabyPrompt': 'Cadastre uma mãe primeiro para adicionar bebês.',
    'regPromptBabyName': 'Muito bem, {mom}. Agora diga o nome do(a) bebê:',
    'regMomGeneric': 'mamãe',
    'regMomWithName': 'mamãe {name}',
    'regListBaby': 'Bebê: {name}',
    'regListBirth': 'Nascimento: {date}',
    'regListSign': 'Signo: {sign}',
    'regListPhone': 'Telefone: {phone}',
    'regSavingMother': 'Salvando mãe…',
    'regSavingBaby': 'Salvando bebê…',
    'regSnackMotherBirth': 'Informe a data de nascimento da mãe.',
    'regSnackMotherOk': 'Mãe cadastrada com sucesso.',
    'regSnackSelectMother': 'Selecione ou cadastre uma mãe antes de avançar.',
    'regSnackBabyBirth': 'Informe a data de nascimento do bebê.',
    'regSnackPickMother': 'Selecione uma mãe para cadastrar o bebê.',
    'regSnackBabyOk': 'Bebê cadastrado com sucesso.',
    'valNameEmpty': 'Informe o nome.',
    'valNameShort': 'Nome muito curto.',
    'valPhoneEmpty': 'Informe o telefone.',
    'valPhoneInvalid': 'Telefone inválido. Use (xx) 9XXXX-XXXX.',
    'valHeightEmpty': 'Informe a altura.',
    'valHeightInvalid': 'Altura inválida.',
    'valHeightMotherRange': 'Altura fora do esperado.',
    'valFatherHeightEmpty': 'Informe a altura do papai.',
    'valWeightEmpty': 'Informe o peso.',
    'valWeightInvalid': 'Peso inválido.',
    'valWeightRange': 'Peso fora do esperado.',
    'valBabyHeightRange': 'Altura fora do esperado.',
    'placeholderBabyName': 'Bebê',
    'valBirthDateInvalid': 'Data inválida. Use dd/mm/aaaa.',
    'brDateHint': 'Data de nascimento',
    'brDateOpenCalendar': 'Abrir calendário',
    'exampleCard': 'Exemplo de carteirinha:',
  },
  AppLang.en: {
    'appName': 'FaceBaby',
    'home': 'Home',
    'records': 'Logs',
    'reports': 'Reports',
    'memories': 'Memories',
    'more': 'More',
    'helloMom': 'Hi, Mom!',
    'today': 'Today',
    'shortcuts': 'Shortcuts',
    'registerNow': 'Log now',
    'edit': 'Edit',
    'delete': 'Delete',
    'cancel': 'Cancel',
    'confirmDelete': 'Are you sure you want to delete this record?',
    'deletedOk': 'Deleted successfully.',
    'deleteFail': 'Could not delete:',
    'todaySummary': "Today's summary",
    'nextEvents': 'Upcoming events',
    'quickRecordsTitle': 'Quick logs',
    'quickRecordsSubtitle': "Add your baby's routine in a few taps.",
    'feedingAlertsSwitchTitle': 'Nursing alert',
    'feedingAlertsSwitchSubtitle':
        'Notify when the set interval has passed since the last breast or bottle feed.',
    'feedingAlertsIntervalCaption': 'Remind after last feed: {m} min (20–360)',
    'feedingAlertsShortcutTitle': 'Feeding alert',
    'scheduledFeedingReminderBody':
        'Time for your feeding reminder. Tap to log.',
    'scheduledDiaperReminderTitle': 'Diaper change',
    'scheduledDiaperReminderBody':
        'It may be time for a diaper change. Tap to log.',
    'whatHappenedNow': 'What happened now?',
    'momNote': "Mom's note",
    'saveRecord': 'Save log',
    'reportsTitle': 'Reports',
    'reportsSubtitle': 'A summary for Mom and the pediatrician.',
    'reportsHubAnchorLabel': 'Reference',
    'reportsHubPickDayTooltip': 'Choose reference day for reports',
    'reportsHubSectionTitle': 'Available reports',
    'reportStubComingSoon':
        'This report will update automatically from your app data for the selected period. Layout and metrics will be specified next.',
    'reportListDaily': 'Daily report',
    'reportListDailySub': 'Summary and details for the selected day',
    'reportListWeekly': 'Weekly report',
    'reportListWeeklySub':
        'Summary and details for the week containing the selected day',
    'reportListMonthly': 'Monthly report',
    'reportListMonthlySub':
        'Monthly aggregates for the month of the selected day',
    'reportListSleepAdv': 'Advanced sleep report',
    'reportListSleepAdvSub': 'Sleep patterns and metrics',
    'reportListPediatric': 'Pediatric report',
    'reportListPediatricSub': 'PDF and data for medical visits',
    'reportListDevelopment': 'Development report',
    'reportListDevelopmentSub': 'Milestones and leaps',
    'plusBrandTitle': 'FaceBaby Plus',
    'plusEarlyAdopterOffer': 'Special pricing for early users.',
    'plusPopularBadge': 'Most Popular ❤️',
    'plusPlanAnnualCardTitle': 'FaceBaby Plus Annual',
    'plusPlanMonthlyCardTitle': 'FaceBaby Plus Monthly',
    'plusPlanAnnualSubtitle': 'Save with the annual plan.',
    'plusPlanMonthlySubtitle':
        'Everything you need to care for your baby with love and intelligence.',
    'plusAnnualSavingsAmountLine': 'Save \${amount} per year',
    'plusAnnualPerMonthHint': 'About \$12.49/month',
    'plusCtaSubscribeMonthly': 'Subscribe monthly',
    'plusCtaSubscribeAnnual': 'Subscribe annual',
    'plusCtaSubscribePlus': 'Subscribe to FaceBaby Plus',
    'plusPaywallRenewalNote':
        'Subscription renews automatically through Google Play. You can cancel anytime in Play Store settings.',
    'plusSheetHero':
        'FaceBaby Plus: 24h AI Nanny, unlimited photos, full backup, premium reports, baby book, and more — from \$19.90/month.',
    'plusSheetPriceLabel': 'Monthly and annual plans',
    'plusSheetBullets':
        '• PDF reports (sleep, routine, growth)\n• Keepsake book PDF\n• Export badges (PNG / PDF)\n• Cloud backup across devices\n• More memories & photos\n• Smart insights in reports\n• Pediatrician report\n• Advanced statistics\n• Premium book themes',
    'plusCtaSubscribe': 'Subscribe to FaceBaby Plus',
    'plusCtaRestore': 'Restore purchases',
    'plusCtaLater': 'Not now',
    'plusSheetFootnote':
        'Subscription processed by Google Play or the App Store. Cancel anytime in store settings.',
    'plusWelcomeSnack':
        'Welcome to FaceBaby Premium — thank you for cherishing these memories together.',
    'plusPurchaseUnavailableSnack':
        'Could not start purchase. Check the store listing or try again later.',
    'plusPurchaseSkuNotFoundSnack':
        'Google Play did not return product "{id}". Create an active managed in-app product with this exact Product ID (Monetize → In-app products), or build with --dart-define=FACEBABY_PREMIUM_SKU=… to match your store ID.',
    'plusPurchaseBillingLaunchFailedSnack':
        'Could not open Google Play billing. Check your internet connection, that you installed the app from Play, and that you use a valid Google account. For internal/closed testing, use a licensed tester. If the store says you already own the product, tap “Restore purchases” below.',
    'plusPurchaseAlreadyInPlayAccountSnack':
        'If the store says you already own this, tap “Restore purchases” below to link Premium to this FaceBaby account. If it still fails, use the same Google account you bought with.',
    'plusPaywallSkuMissingHint':
        'Store price not loaded yet for "{id}". Confirm the product is active in Play Console or wait for sync (can take a few hours).',
    'plusRestoreOkSnack': 'Purchases restored.',
    'plusRestoreEmptySnack': 'No previous purchase found for this account.',
    'plusSnackLockedFeature': 'Included in FaceBaby Plus.',
    'plusMemoryLimitSnack':
        'On the free plan you can save up to {max} badge photos. Premium unlocks unlimited photos.',
    'plusMemoryLimitDialogTitle': 'Unlock more memories',
    'plusMemoryLimitDialogBody':
        'On the free plan you can save up to {max} photos on badges.\n\nGet FaceBaby Premium for about \$9/month for unlimited photos, reports, exports, and more portal features.',
    'plusMemoryLimitDialogSubscribe': 'Get Premium',
    'plusReportsLockedHint': 'FaceBaby Premium report',
    'plusReportsPremiumTagline':
        'Monthly subscription from about \$9. Premium reports and more.',
    'plusReportsPremiumCta': 'See FaceBaby Premium',
    'plusExportLockedHint': 'FaceBaby Premium export',
    'plusLifetimePaymentBadge': 'Monthly subscription',
    'plusNoMonthlyBadge': 'Cancel in store',
    'plusPremiumActiveTitle': 'Thank you for Premium',
    'plusPremiumActiveBody':
        'Your premium features are active. Manage or cancel your subscription in Google Play or the App Store.',
    'plusPurchaseErrorSnack':
        'Something went wrong. Try again or tap Restore purchases.',
    'plusDoneClose': 'Close',
    'plusPaywallHeadline':
        'Choose the right plan to\nsupport your baby with FaceBaby Plus.',
    'plusPaywallActiveNote':
        'Your FaceBaby Plus is active. Manage your subscription in the Play Store.',
    'plusPlanPremiumButtonActive': 'Current plan',
    'plusPlanMonthlyFeature1': 'Everything in the Free plan',
    'plusPlanMonthlyFeature2': '24h AI Nanny with you',
    'plusPlanMonthlyFeature3': 'Smart answers',
    'plusPlanMonthlyFeature4': 'Personalized guidance',
    'plusPlanMonthlyFeature5': 'Predictive alerts',
    'plusPlanMonthlyFeature6': 'Personalized routines',
    'plusPlanMonthlyFeature7': 'AI-generated content',
    'plusPlanMonthlyFeature8': 'Photo uploads',
    'plusPlanMonthlyFeature9': 'Full backup',
    'plusPlanMonthlyFeature10': 'Premium reports',
    'plusPlanMonthlyFeature11': 'Pediatrician report',
    'plusPlanMonthlyFeature12': 'Baby book PDF',
    'plusPlanMonthlyFeature13': 'Advanced growth',
    'plusPlanMonthlyFeature14': 'AI family horoscope',
    'plusPlanMonthlyFeature15': 'Daily Bible messages',
    'plusPlanMonthlyFeature16': 'Zodiac descriptions',
    'plusPlanMonthlyFeature17': 'Priority support',
    'plusPlanMonthlyFeature18': 'Coming soon: voice replies',
    'plusPlanAnnualFeature1': 'Everything in Monthly Plus',
    'plusPlanAnnualFeature2': 'Savings vs monthly billing',
    'plusPlanAnnualFeature3': 'Best value',
    'plusPlanAiTitle': 'AI Nanny',
    'plusPlanAiSubtitle': 'Smart assistant\nfor everyday life',
    'plusPlanAiBadge': 'Coming soon',
    'plusPlanAiFeature1': 'Everything in Premium',
    'plusPlanAiFeature2': '24h AI Nanny with you',
    'plusPlanAiFeature3': 'Smart answers',
    'plusPlanAiFeature4': 'Personalized guidance',
    'plusPlanAiFeature5': 'Predictive alerts',
    'plusPlanAiFeature6': 'Personalized routines',
    'plusPlanAiFeature7': 'AI-generated content',
    'plusPlanAiPrice': 'Coming soon',
    'plusPlanAiPriceSub': 'Stay tuned!',
    'plusPlanAiButton': 'Notify me',
    'plusPlanFreeTitle': 'Free',
    'plusPlanFreeSubtitle': 'Start your journey with the essentials.',
    'plusPlanFreePrice': '\$0.00',
    'plusPlanCurrent': 'Current plan',
    'plusPlanFreeFeature1': 'Basic profiles',
    'plusPlanFreeFeature2': 'Daily logging',
    'plusPlanFreeFeature3': 'Schedules and reminders',
    'plusPlanFreeFeature4': 'Weight and height',
    'plusPlanFreeFeature5': 'Some memories',
    'plusPlanFreeFeature6': 'Limited features',
    'plusTrustData': 'Your data\nalways secure',
    'plusTrustFamily': 'Made with love\nfor families',
    'plusTrustContent': 'Reliable, updated\ncontent',
    'plusTrustSupport': 'Support at every\nmoment',
    'settingsPlusCardTitle': 'FaceBaby Plus',
    'settingsPlusCardBodyFree':
        'AI Nanny, unlimited photos, full backup, premium reports & baby book — \$19.90/mo or \$149.90/yr.',
    'settingsPlusCardBodyActive':
        'Your FaceBaby Plus is active — thank you for your support.',
    'settingsPlusUpgradeCta': 'Explore FaceBaby Plus',
    'settingsPlusManageCta': 'Manage Plus',
    'plusMemoryCounterFree': '{n} of {max} photos on the free plan',
    'reportDailyScreenTitle': 'Daily report',
    'reportDayDetailsTitle': 'Day details',
    'reportDailyPickDayTooltip': 'Choose day',
    'reportDailySubtitleSleepQuality': 'Sleep quality',
    'reportDailySubtitleTotalSleep': 'Total sleep',
    'reportDailySubtitleLongestStretch': 'Longest stretch',
    'reportDailySubtitleFeedTotal': 'Total feeds',
    'reportDailySubtitleFeedAvg': 'Average duration',
    'reportDailySubtitleFeedLast': 'Last feed',
    'reportDailySubtitleDiaperTotal': 'Total changes',
    'reportDailySubtitleDiaperWet': 'Wet diapers',
    'reportDailySubtitleDiaperDirty': 'Dirty diapers',
    'reportDailySubtitleMoodMajority': 'Most of the day',
    'reportDailySubtitleMoodIrrit': 'Irritability',
    'reportDailySubtitleWeightLast': 'Latest measurement',
    'reportSleepQualityGood': 'Good',
    'reportSleepQualityOk': 'OK',
    'reportSleepQualityBad': 'Poor',
    'reportSleepQualityMixed': 'Mixed',
    'reportVsYesterdayShort': 'vs yesterday',
    'reportVsYesterdayNA': '—',
    'reportVsYesterdayPct': '{pct}%',
    'reportLongestStretchHint': '{start} – {end}',
    'reportNapsLabel': 'Naps',
    'reportTotalSmallLabel': 'Total',
    'reportComparedAgeLabel': 'Compared to age average',
    'reportBenchmarkAbove': 'Above average',
    'reportBenchmarkNear': 'Near average',
    'reportBenchmarkBelow': 'Below average',
    'reportIrritLow': 'Low',
    'reportIrritMedium': 'Moderate',
    'reportIrritHigh': 'High',
    'reportIrritUnknown': 'No data',
    'reportTabSleep': 'Sleep',
    'reportTabFeedings': 'Feeds',
    'reportTabDiapers': 'Diapers',
    'reportTabMood': 'Mood',
    'reportAiInsightsTitle': 'Insights',
    'reportTimelineTitle': 'Day timeline',
    'reportShareSoon': 'Share (soon)',
    'reportFeedingChartCaption': 'Feeds by hour',
    'reportSleepChartCaption': 'Sleep by hour',
    'reportNoDataHint': 'Not enough logged data for this metric.',
    'reportInsightSleepAgeGood':
        'Total sleep is close to what is typical for this age — a good sign of restorative rest.',
    'reportInsightSleepAgeLow':
        'Sleep came in below the usual range for this age; watch for tired cues and bedtime rhythm.',
    'reportInsightFeedsOften':
        'Many feeds across the day — common during growth spurts; logging duration helps spot averages.',
    'reportInsightDiapersFrequent':
        'Frequent diaper changes — hydration may be fine or skin may need care; note wet vs dirty patterns.',
    'reportInsightMoodLine': 'Predominant mood saved in memories: {mood}.',
    'reportWeeklyScreenTitle': 'Weekly report',
    'reportWeekDetailsTitle': 'Week details',
    'reportWeeklyPickWeekTooltip': 'Pick a week (any day in that week)',
    'reportWeeklySummaryTitle': 'Week summary',
    'reportWeeklyTrendsTitle': 'Trends',
    'reportWeeklySeeFullDetails': 'View full report',
    'reportWeeklyPartialWeekHint':
        'Averages and trends: Monday through {weekday} (week to date).',
    'reportWeeklyFutureWeekHint':
        "This week hasn't started on the calendar yet — pick another week, or come back when there are logged days.",
    'reportWeeklyLoadErrorPrefix': 'Could not load the report:',
    'reportWeeklyToneCalm': 'calm',
    'reportWeeklyToneActive': 'busy',
    'reportWeeklySleepUnknown': 'Not enough sleep data to compare weeks.',
    'reportWeeklyFirstWeekSleepLine':
        'This is the first week with entries — keep logging so trends can show up next week.',
    'reportWeeklySleepStableShort': 'Sleep stayed stable vs last week.',
    'reportWeeklySleepUp': 'Sleep improved by about {pct}% vs last week.',
    'reportWeeklySleepDown': 'Sleep dropped by about {pct}% vs last week.',
    'reportWeeklyFeedStableLine': 'Feeds stayed steady.',
    'reportWeeklyFeedUp': 'Daily feeds increased by about {pct}% on average.',
    'reportWeeklyFeedDown': 'Daily feeds decreased by about {pct}% on average.',
    'reportWeeklyHeroTemplate': '{name} had a {tone} week! {sleep} {feed}',
    'reportWeeklyTrendLabelImproved': 'Improved',
    'reportWeeklyTrendLabelWorse': 'Worse',
    'reportWeeklyTrendLabelStable': 'Stable',
    'reportWeeklyTrendLabelUnknown': '—',
    'reportWeeklyTrendLabelEvolving': 'Growing',
    'reportWeeklyTrendLabelIncreased': 'Increased',
    'reportWeeklyTrendNA': '—',
    'reportWeeklyHighlightSleep': 'Positive: more restorative sleep this week.',
    'reportWeeklyHighlightFeedingStable': 'Positive: steady feeding rhythm.',
    'reportWeeklyHighlightDiaperUp':
        'Note: more changes — hydration or digestion may be more active.',
    'reportWeeklyHighlightWeight': 'Positive: healthy weight gain.',
    'reportWeeklyHighlightGeneric': 'Keep logging for clearer trends.',
    'reportWeeklyAvgFeedsDay': 'Daily average: {avg} feeds.',
    'reportWeeklyAvgDiapersDay': 'Daily average: {avg} changes.',
    'reportWeeklySleepHoursChartTitle': 'Sleep hours per day',
    'reportWeeklyAvgWeekLabel': 'Weekly average',
    'reportWeeklyVsPrevWeekShort': 'vs previous week',
    'reportWeeklyInsightsCardTitle': 'AI insights',
    'reportWeeklyPatternsTitle': 'Patterns spotted',
    'reportWeeklySeeAllAnalyses': 'See all analyses',
    'reportWeeklyHeatmapSoon': 'Optional hourly heatmap coming soon.',
    'reportWeeklyFeedChartCaption': 'Feeds per day',
    'reportWeeklyDiaperChartCaption': 'Changes per day',
    'reportWeeklyPatternWeekend': 'Sleep tends to stretch a bit on weekends.',
    'reportWeeklyPatternFeedingDown':
        'Fewer feeds on average — common when intervals widen.',
    'reportWeeklyPatternDefault':
        'Weekly pattern looks steady — adjust routines as needed.',
    'reportWeeklyInsightSleepNeutral': 'Sleep was similar to last week.',
    'reportWeeklyInsightSleepBetter':
        'More sleep than last week — a good sign.',
    'reportWeeklyInsightSleepLess':
        'Total sleep dipped vs last week — worth watching nights.',
    'reportWeeklyInsightTemplate': '{name}: {sleep}',
    'reportMonthlyScreenTitle': 'Monthly report',
    'reportMonthlyAvgWeight': 'Average weight',
    'reportMonthlyAvgHeight': 'Average height',
    'reportMonthlyGrowthChartEmpty':
        'Add at least two weight logs this month to see the chart.',
    'reportMonthlySleepSection': 'Sleep',
    'reportMonthlySleepAvg': 'Monthly average (per day)',
    'reportMonthlyVsPrevMonth': 'vs previous month',
    'reportMonthlyBestWeeks': 'Weeks with the most sleep',
    'reportMonthlySleepTrendUp':
        'Overall trend: more restorative sleep this month.',
    'reportMonthlySleepTrendDown':
        'Overall trend: less total sleep than last month — worth watching.',
    'reportMonthlySleepTrendStable':
        'Overall trend: steady sleep through the month.',
    'reportMonthlySleepTrendUnknown':
        'Not enough data to compare with last month.',
    'reportMonthlySleepExplain':
        'Average sleep per day adds up every logged sleep session by calendar day this month and divides by the number of days in the month (sessions counted by end time). The percentage compares that average with the previous month. “Weeks with the most sleep” highlights up to two Monday–Sunday weeks with the highest total sleep.',
    'reportMonthlyFeedingSection': 'Feeding',
    'reportMonthlyFeedFreq': 'Average frequency (feeds/day)',
    'reportMonthlyFeedingExplain':
        'Average frequency is total breast or bottle feeds logged this month divided by the number of calendar days in that month (days with no logs still count). Solid feeds are not included. The times are up to three clock hours when the most feeds ended this month.',
    'reportMonthlyPredominantHours': 'Most common times (feed ended)',
    'reportMonthlyMilestonesTitle': 'Milestones this month',
    'reportMonthlyMilestonesEmpty':
        'No vaccines, visits or badge memories this month.',
    'reportMonthlyMilestoneConsultationDefault': 'Visit',
    'reportMonthlyMemoriesTitle': 'Memories this month',
    'homeRecentMemoriesTitle': 'Latest Memories',
    'reportMonthlySeeAllMemories': 'See all',
    'reportMonthlyMemoriesEmpty': 'No photos in memories for this month.',
    'reportMonthlyVideosHint': 'Videos will appear when saved in your moments.',
    'reportSleepAdvScreenTitle': 'Sleep report',
    'reportSleepAdvScoreTitle': 'Sleep score',
    'reportSleepAdvMetricsTitle': 'Weekly metrics',
    'reportSleepAdvEfficiency': 'Sleep efficiency',
    'reportSleepAdvVsPrevPct': 'Efficiency change: {pct}% (vs previous week)',
    'reportSleepAdvOnset': 'Time until first night sleep',
    'reportSleepAdvAwakenings': 'Awakenings per night (avg.)',
    'reportSleepAdvAwakeningsTotal': 'Awakenings this week: {n}',
    'reportSleepAdvLongest': 'Longest continuous sleep',
    'reportSleepAdvAvgDailySleep': 'Average sleep per day',
    'reportSleepAdvIdealTitle': 'Best time to fall asleep',
    'reportSleepAdvIdealFooter':
        'Window estimated from your logs (not medical advice).',
    'reportSleepAdvSeeFullAnalysis': 'See full analysis',
    'reportSleepAdvChartsSection': 'Sleep session',
    'reportSleepAdvChartsSleepTrend': 'Sleep rhythm (this week)',
    'reportSleepAdvChartsCompare': 'Compared with last week',
    'reportSleepAdvChartsDistribution': 'Day vs night (week total)',
    'reportSleepAdvChartsBars': 'Sleep volume: this week vs last',
    'reportSleepAdvDayPhase': 'Day sleep (6am–6pm)',
    'reportSleepAdvNightPhase': 'Night sleep (6pm–6am)',
    'reportSleepAdvDistributionEmpty': 'Not enough data to split.',
    'reportSleepAdvLegendThisWeek': 'This week',
    'reportSleepAdvLegendPrevWeek': 'Last week',
    'reportSleepAdvScoreBreakdown': 'What the score reflects',
    'reportSleepAdvBreakdownLine':
        'Efficiency: {e} pts • Long stretches: {s} pts • Wake-ups: {a} pts • Steadiness: {c} pts (indicative).',
    'reportSleepAdvNotEnoughData':
        'Still few entries this week — numbers are indicative.',
    'reportSleepAdvStatusExcellent': 'Excellent',
    'reportSleepAdvStatusGood': 'Good',
    'reportSleepAdvStatusRegular': 'Fair',
    'reportSleepAdvStatusPoor': 'Low',
    'reportSleepAdvBadgeVeryGood': 'Very good',
    'reportSleepAdvBadgeGood': 'Good',
    'reportSleepAdvBadgeOk': 'Moderate',
    'reportSleepAdvBadgeAttention': 'Watch',
    'reportSleepAdvBadgeIdeal': 'Ideal',
    'reportSleepAdvBadgeUnknown': 'No data',
    'reportSleepAdvBadgeLow': 'Low',
    'reportSleepAdvBadgeModerate': 'Moderate',
    'reportSleepAdvBadgeHigh': 'High',
    'reportPediatricScreenTitle': 'Pediatric clinical report',
    'reportPediatricPeriodPrefix': 'Period:',
    'reportPediatricFilterHint': 'Report period',
    'reportPediatricDateFrom': 'From',
    'reportPediatricDateTo': 'To',
    'reportPediatricPickRange': 'Choose dates',
    'reportPediatricFilterMaxDaysHint':
        'Tap to change. Very long ranges are limited to 366 days.',
    'reportPediatricSectionGeneral': 'General information',
    'reportPediatricSectionSummary': 'Period summary',
    'reportPediatricSectionSleep': 'Sleep',
    'reportPediatricSectionFeeding': 'Feeding',
    'reportPediatricSectionSymptoms': 'Symptoms & logs',
    'reportPediatricSectionObservations': 'Parent observations',
    'reportPediatricLabelName': 'Name',
    'reportPediatricLabelAge': 'Age',
    'reportPediatricLabelBirth': 'Date of birth',
    'reportPediatricLabelWeightCurrent': 'Weight (latest in period)',
    'reportPediatricLabelHeight': 'Height',
    'reportPediatricWeightStart': 'Starting weight (period)',
    'reportPediatricWeightEnd': 'Ending weight (period)',
    'reportPediatricWeightGain': 'Weight change',
    'reportPediatricHeightStart': 'Starting height (period)',
    'reportPediatricHeightEnd': 'Ending height (period)',
    'reportPediatricHeightGain': 'Height growth',
    'reportPediatricAvgFeeds': 'Feeds/meals per day (avg.)',
    'reportPediatricAvgSleep': 'Sleep per day (avg.)',
    'reportPediatricAvgDiapers': 'Diaper changes per day (avg.)',
    'reportPediatricFeverEpisodes': 'Fever episodes (structured)',
    'reportPediatricFeverNote': 'Note',
    'reportPediatricFeverFootnote':
        'Counted from structured symptom logs (Health › Report symptom), with temperature when provided.',
    'reportPediatricVaccines': 'Vaccines given in period',
    'reportPediatricMedications':
        'Medications (structured logs & keywords in notes)',
    'reportPediatricSleepAvgDaily': 'Average daily sleep',
    'reportPediatricSleepAwakenings': 'Night awakenings (avg.)',
    'reportPediatricSleepPattern': 'Overall sleep pattern',
    'reportPediatricSleepPatternStable': 'Mostly continuous',
    'reportPediatricSleepPatternModerate': 'Moderate',
    'reportPediatricSleepPatternFragmented': 'More fragmented',
    'reportPediatricSleepLongest': 'Longest continuous sleep',
    'reportPediatricFeedingBreast': 'Breastfeeding',
    'reportPediatricFeedingFormula': 'Formula',
    'reportPediatricFeedingSolid': 'Solid foods',
    'reportPediatricFeedingSessions': 'sessions',
    'reportPediatricFeedingAvgDur': 'avg. duration',
    'reportPediatricSymptomReflux': 'Reflux (journals or structured logs)',
    'reportPediatricSymptomColic': 'Colic (journals or structured logs)',
    'reportPediatricSymptomIrrit': 'Irritability (moods)',
    'reportPediatricIrritHigh': 'More noticeable',
    'reportPediatricIrritMedium': 'Moderate',
    'reportPediatricIrritLow': 'Mild',
    'reportPediatricIrritUnknown': 'No data',
    'reportPediatricYes': 'Yes',
    'reportPediatricNo': 'No',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'Daily journals',
    'reportPediatricJournalNoteHint': 'Keyword detection in free text.',
    'reportPediatricObsHint':
        'Notes for the visit: symptoms, meds, behaviour changes…',
    'reportPediatricBtnShare': 'Share',
    'reportPediatricBtnExportPdf': 'Export PDF',
    'reportPediatricBtnPrint': 'Print',
    'reportPediatricBtnEmail': 'Email',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote':
        'Informational summary from local logs. Not a substitute for clinical assessment.',
    'reportPediatricNone': 'None',
    'reportPediatricPdfTitle': 'Pediatric clinical report — FaceBaby',
    'reportPediatricPdfPeriod': 'Period:',
    'reportPediatricPdfFooter':
        'Generated in FaceBaby. Content limited to data stored on this device (offline-friendly).',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': 'Unexplained crying (structured logs)',
    'reportPediatricSymptomPain': 'Pain (structured logs)',
    'reportPediatricSymptomFromJournal': 'mentioned in journal (no time)',
    'reportPediatricStructuredSymptoms':
        'Structured symptom logs (date & time)',
    'reportPediatricStructuredSymptomsEmpty':
        'No structured symptom logs this period.',
    'reportDevScreenTitle': 'Development',
    'reportDevSubtitle': 'Gentle milestones to follow at your own pace.',
    'reportDevScoreTitle': 'Development score',
    'reportDevScoreStatusOnTrack': 'Within the expected range',
    'reportDevScoreStatusWatch': 'Room for new skills to bloom',
    'reportDevScoreStatusEarly': 'Growing at their own lovely pace',
    'reportDevSectionMotor': 'Motor development',
    'reportDevSectionCognitive': 'Cognitive development',
    'reportDevSectionSocial': 'Social & emotional',
    'reportDevAchieved': 'On track',
    'reportDevGrowing': 'Emerging',
    'reportDevInsightTitle': 'Gentle insight',
    'reportDevSeeAllMarcos': 'See all milestones',
    'reportDevFootnote':
        'Milestones are general guides; every baby is different. When unsure, ask your pediatrician.',
    'reportDevNeedBirth': 'Add your baby’s birth date to see this report.',
    'devReport_motor_head': 'Holds head up',
    'devReport_motor_roll': 'Rolls (e.g. tummy to back)',
    'devReport_motor_sit': 'Sits (with or without support)',
    'devReport_motor_crawl': 'Crawls or moves on hands and knees',
    'devReport_motor_walk': 'Takes steps / walks with support',
    'devReport_cog_faces': 'Recognises familiar faces',
    'devReport_cog_sounds': 'Responds to sounds and voices',
    'devReport_cog_track': 'Follows objects with eyes',
    'devReport_cog_babble': 'Babbles or vocalises',
    'devReport_cog_visual': 'Keeps eye contact in play',
    'devReport_soc_smile': 'Social smile',
    'devReport_soc_emotion_resp': 'Emotional responses to caregivers',
    'devReport_soc_family': 'Interaction with close family',
    'devReport_soc_emotion_react': 'Emotional reactions to situations',
    'devReportInsightNewborn':
        'In the first days, bonding and safety matter most — every tiny cue counts.',
    'devReportInsightOnTrack':
        'What we see here fits common patterns for babies around this age.',
    'devReportInsightVariety':
        'It’s normal for skills to arrive a little earlier or later.',
    'devReportInsightPatience':
        'Some milestones are still unfolding — calm tummy time, chat and gentle play all help.',
    'devReportInsightBalanced':
        'Celebrate small wins; warmth and gentle routines are powerful stimulation.',
    'growth': 'Growth',
    'pediatricReport': 'Pediatric clinical report',
    'pediatricReportDesc':
        'Generate a PDF with weight, sleep, feeding, diapers, vaccines, symptom logs from Health, appointments and notes.',
    'generatePdf': 'Generate PDF',
    'memoriesTitle': 'Memory book',
    'memoriesSubtitle': 'Important moments to keep forever.',
    'memoriesProgressSaved': '{filled} of {total} moments saved',
    'memoriesProgressStandardBadges': '({count} standard badges)',
    'memoriesCheerEmpty': 'Tap a badge with + to add photos and stories.',
    'memoriesAlbumPromoTitle': 'Your complete keepsake book',
    'memoriesAlbumPromoSubtitle':
        'Download an elegant PDF with a FaceBaby cover, decorative frame, and every badge you have filled in — perfect to keep or share.',
    'memoriesAlbumDownloadCta': 'Download album PDF',
    'memoriesAlbumGenerating': 'Creating your album…',
    'memoriesAlbumNeedFilled':
        'Fill in at least one moment in the album to generate the PDF.',
    'memoriesAlbumError': 'Could not generate the PDF.',
    'memoriesAlbumPdfReadyTitle': 'Album PDF ready',
    'memoriesAlbumShareAction': 'Share…',
    'memoriesAlbumSaveAction': 'Save / download',
    'memoriesAlbumSavedSnack': 'PDF saved on your device.',
    'memoriesAlbumSaveFailedSnack': 'Could not save the PDF.',
    'memoriesAlbumCoverMain': 'Keepsake memory book',
    'memoriesAlbumCoverTagline': 'Special moments with {name}',
    'memoriesAlbumFooter': 'Made with FaceBaby',
    'memoriesAlbumBackCoverBody':
        'FaceBaby was created to turn simple moments into everlasting memories. Every smile, discovery, hug, and milestone your baby experiences deserves to be preserved with love, care, and meaning.\n\nThis book was designed to follow the first steps of this beautiful journey, capturing precious memories that can be treasured forever.\n\nMore than photos and notes, these pages hold emotions, stories, and feelings that time will never erase.\n\nThank you for allowing FaceBaby to be part of your family\u2019s story. 💛',
    'memoriesAlbumBackCoverFinale':
        'Because childhood goes by quickly…\nbut memories can last forever.',
    'memoriesAlbumQualityTitle': 'PDF quality',
    'memoriesAlbumQualityShareTitle': 'Light — for sharing',
    'memoriesAlbumQualityShareDesc':
        'Compressed images, smaller file. Best for WhatsApp and email.',
    'memoriesAlbumQualityPrintTitle': 'High quality — for printing',
    'memoriesAlbumQualityPrintDesc':
        'Higher photo resolution. Larger file; best for printing.',
    'memoriesAlbumExportTitle': 'Creating your book…',
    'memoriesAlbumProgressPreparing': 'Preparing pages…',
    'memoriesAlbumProgressImages': 'Processing photos ({current}/{total})…',
    'memoriesAlbumProgressBuilding': 'Building PDF ({current}/{total})…',
    'memoriesAlbumProgressSaving': 'Saving file…',
    'memoriesAlbumCancelBtn': 'Cancel',
    'memoriesAlbumCanceled': 'Generation canceled.',
    'memoriesAlbumErrorNetwork':
        'No internet connection. Check your network and try again.',
    'memoriesAlbumErrorStorage':
        'Not enough storage on device to save the PDF.',
    'memoriesAlbumSkippedImages':
        '{count} photo(s) could not be included (network or invalid file).',
    'addMemory': 'Add memory',
    'memoryAddBadgeCta': 'Add badge',
    'memoryChooseBadgeTitle': 'Which badge do you want to create?',
    'memoryOtherBadgeTitle': 'Other',
    'memoryOtherBadgeNameLabel': 'Badge name',
    'memoryOtherBadgeNameHint': 'Ex: First costume',
    'memoryOtherBadgeNameRequired': 'Enter the badge name.',
    'memoryOtherBadgeNameTooLong': 'Use up to 25 characters.',
    'memoryBadgeMonthOne': '1 month',
    'memoryBadgeMonthsMany': '{n} months',
    'memoryBadgeYearOne': '1 year',
    'memoryBadgeYearsMany': '{n} years',
    'memoryBadgeMonthUnitSingular': 'month',
    'memoryBadgeMonthUnitPlural': 'months',
    'badge_arrived_home': 'Home at last',
    'badge_first_smile': 'First smile',
    'badge_first_feeding': 'First feeding',
    'badge_sleeping': 'Sleeping',
    'badge_bath_time': 'Bath time',
    'badge_going_out': 'Out for a walk',
    'badge_first_laugh': 'First laugh',
    'badge_found_hands': 'Found my hands',
    'badge_lifted_head': 'Lifted head',
    'badge_at_park': 'At the park',
    'badge_first_hug': 'First hug',
    'badge_first_foods': 'First foods',
    'badge_first_bath': 'First bath',
    'badge_crib_sleep': 'First crib nap',
    'badge_first_diaper_change': 'First diaper change',
    'badge_first_burp': 'First burp',
    'badge_first_mom_cuddle': 'First cuddle with Mom',
    'badge_first_dad_cuddle': 'First cuddle with Dad',
    'badge_first_pediatrician': 'First pediatric visit',
    'badge_first_vaccine': 'First vaccine',
    'badge_first_car_ride': 'First car ride',
    'badge_first_stroller_ride': 'First stroller ride',
    'badge_favorite_toy': 'Favorite toy',
    'badge_first_night_home': 'First night home',
    'badge_first_giggle': 'First giggle',
    'badge_sun_bath': 'First sun bath',
    'badge_first_christmas': 'First Christmas',
    'badge_first_new_year': 'First New Year',
    'badge_first_mothers_day': "First Mother's Day",
    'badge_first_fathers_day': "First Father's Day",
    'badge_first_tooth': 'First tooth',
    'badge_first_puree': 'First puree',
    'badge_sat_alone': 'Sat without support',
    'badge_crawled': 'Crawling',
    'badge_stood_up': 'Stood up',
    'badge_first_steps': 'First steps',
    'badge_first_word': 'First word',
    'badge_favorite_song': 'Favorite song',
    'badge_first_trip': 'First trip',
    'badge_family_birthday': 'First family birthday',
    'badge_first_beach': 'First beach day',
    'badge_first_pool': 'First pool',
    'badge_first_haircut': 'First haircut',
    'badge_first_shoes': 'First shoes',
    'badge_special_outfit': 'Special outfit',
    'badge_first_friend': 'First friend',
    'badge_first_party': 'First party',
    'badge_first_cartoon': 'First cartoon',
    'badge_first_book': 'First book',
    'badge_special_free': 'Special moment',
    'settingsTitle': 'More',
    'dailyJournalTitle': 'Daily summary',
    'dailyJournalPickDay': 'Pick day',
    'dailyJournalOnDate': 'Summary on {d}',
    'dailyJournalHint': 'Write the day summary here…',
    'dailyJournalSave': 'Save summary',
    'dailyJournalSaving': 'Saving summary…',
    'dailyJournalSaved': 'Summary saved.',
    'dailyJournalNoBaby': 'Create/select a baby to use the daily summary.',
    'registerMotherBaby': 'Register (mom & baby)',
    'vaccinesCard': 'Vaccines (card)',
    'language': 'Language',
    'settingsSoonTitle': 'Coming soon',
    'settingsSoonBadge': 'Soon',
    'settingsRateUs': 'Rate us',
    'settingsVersion': 'Version',
    'settingsVersionDialogTitle': 'App version',
    'settingsVersionCopy': 'Copy',
    'settingsVersionCopied': 'Version info copied',
    'settingsTermsOfUse': 'Terms of use',
    'termsLoadError': 'Could not load the terms.',
    'settingsPrivacyPolicy': 'Privacy policy',
    'settingsSpecialThanks': 'Special thanks',
    'settingsTellFriend': 'Refer a friend',
    'settingsInviteShareText':
        'Try FaceBaby — baby routines & memories in one place.\nhttps://play.google.com/store/apps/details?id=com.facebaby.app',
    'settingsPremiumBenefitsTitle': 'FaceBaby Premium benefits',
    'settingsPremiumBannerHint': 'Tap to see what is included in your plan.',
    'settingsRateCouldNotOpen': 'Could not open the store. Try again later.',
    'unitsTitle': 'Measurement units',
    'unitsIntro':
        'Choose how you want measurements to be shown. We start with an automatic default based on your device region.',
    'unitsLengthTitle': 'Length unit',
    'unitsLengthSubtitle': 'Height, circumference and general measurements.',
    'unitsWeightTitle': 'Weight unit',
    'unitsWeightSubtitle': 'Baby weight and related logs.',
    'unitsLiquidTitle': 'Liquid unit',
    'unitsLiquidSubtitle': 'Volume (e.g. bottle and others).',
    'unitsTempTitle': 'Temperature unit',
    'unitsTempSubtitle': 'Body and ambient temperature.',
    'unitsOptCm': 'cm',
    'unitsOptInch': 'in',
    'unitsOptKg': 'kg',
    'unitsOptLb': 'lb',
    'unitsOptSt': 'st',
    'unitsOptMl': 'ml',
    'unitsOptUkFloz': 'uk fl oz',
    'unitsOptUsFloz': 'us fl oz',
    'unitsOptC': '°C',
    'unitsOptF': '°F',
    'authLoginTitle': 'Sign in',
    'authWelcome': 'Welcome',
    'authEmailLabel': 'Email',
    'authPasswordLabel': 'Password',
    'authForgotPassword': 'Forgot password',
    'authSignIn': 'Sign in',
    'authSigningIn': 'Signing in...',
    'authSignInGoogle': 'Sign in with Google',
    'authSignInApple': 'Sign in with Apple',
    'authSignInEmail': 'Sign in with email',
    'authAppleSignInPlaceholder': 'Apple Sign-In will be configured later.',
    'authCreateAccount': 'Create account',
    'authForgotDialogTitle': 'Forgot password',
    'authForgotDialogBody': "We'll email you a link to reset your password.",
    'authForgotSend': 'Send',
    'authResetEmailSentSnackbar': 'Email sent. Check your inbox.',
    'authRegisterAppBarTitle': 'Create account',
    'authRegisterTitle': 'Sign up',
    'authRegisterNameLabel': 'Name (how you want to be called)',
    'authRegisterPasswordLabel': 'Password',
    'authRegisterSubmit': 'Create account',
    'authRegisterCreating': 'Creating...',
    'authValEmailRequired': 'Enter your email',
    'authValEmailInvalid': 'Invalid email',
    'authValPasswordRequired': 'Enter your password',
    'authValPasswordMin6': 'At least 6 characters',
    'authValNameRequired': 'Enter your name',
    'authValNameShort': 'Name is too short',
    'authErrWeakPassword': 'Weak password. Use at least 6 characters.',
    'authErrInvalidEmail': 'Invalid email.',
    'authErrUserDisabled': 'This account has been disabled.',
    'authErrUserNotFound': 'No account found for this email.',
    'authErrWrongPassword': 'Incorrect password.',
    'authErrEmailInUse':
        'An account already exists with this email. Use “Already have an account” to sign in.',
    'authErrAccountExistsDifferentCredential':
        'This email already has a FaceBaby account with a different sign-in method (for example Google). Go back, tap “Already have an account,” and use the same method as before; to use email/password, try another email.',
    'authErrEmailInUseGoogle':
        'This email is already registered with Google. Go back and sign in with the Google button under “Already have an account.”',
    'authErrEmailInUsePassword':
        'This email already has a FaceBaby password. Use “Already have an account” with email and password; if you forgot, use “Forgot password” on the login screen.',
    'authErrEmailInUseApple':
        'This email is already linked to Apple. Sign in with the Apple button under “Already have an account.”',
    'authErrEmailInUseMixed':
        'This email is already registered with another sign-in method. Use “Already have an account” with the same Google, Apple, or email/password you used before.',
    'authErrInvalidCredential': 'Invalid credentials. Try again.',
    'authErrCredentialsGeneric': 'Could not sign in. Try again.',
    'authErrGoogleConfigAndroid':
        'Google sign-in failed due to app configuration (error 10).\n\n'
            '1) Firebase: Project settings → your Android app → add your debug keystore SHA-1.\n'
            '2) In the android folder run: gradlew signingReport and copy the "debug" SHA-1.\n'
            '3) Authentication → enable Google provider.\n'
            '4) Download google-services.json again into android/app/.',
    'authErrLoginCancelled': 'Sign-in cancelled.',
    'authErrAppleFailed':
        'Could not sign in with Apple. Try again or use another method.',
    'authErrAppleUnavailable':
        'Sign in with Apple is only available on iPhone or iPad.',
    'authErrUnexpected': 'Something went wrong.',
    'emailVerifyTitle': 'Verify your email',
    'emailVerifyLead':
        'Please verify your email address before continuing. We sent a link to your inbox.',
    'emailVerifyWhy':
        'Verification helps protect baby data, recover your account, and prevent fake sign-ups.',
    'emailVerifyResendButton': 'Resend verification email',
    'emailVerifyResendWait': 'Wait {seconds}s to resend',
    'emailVerifyConfirmedButton': "I've verified my email",
    'emailVerifySignOut': 'Sign out',
    'emailVerifySent': 'Email sent! Check your spam folder too.',
    'emailVerifyStillPending':
        'Your email is not verified yet. Open the link we sent and try again.',
    'authErrEmailVerifyTooMany':
        'Too many attempts. Wait a few minutes before requesting another email.',
    'onbSelectDate': 'Select date',
    'onbBabyFallback': 'baby',
    'onbMomFallback': 'mom',
    'onbDadFallback': 'dad',
    'onbWelcomeTitle': 'Accompanying and monitoring',
    'onbWelcomeSubtitle': 'development with Love.',
    'onbPlusEarlyOffer':
        'FaceBaby Plus: special pricing for early users — AI Nanny, backup, and premium reports.',
    'onbFeatureSleep': 'Sleep',
    'onbFeatureFeeding': 'Feeding',
    'onbFeatureGrowth': 'Growth',
    'onbFeatureMemories': 'Memories',
    'onbFeatureAlerts': 'Alerts',
    'onbFeatureLove': 'Lots of Love',
    'onbCreateBabyProfile': "Create baby's profile",
    'onbExistingAccountLogin': 'I already have an account / Sign in',
    'onbContinue': 'Continue',
    'onbPrepareFaceBaby': 'Prepare FaceBaby',
    'onbPreparingTitle': 'Preparing FaceBaby for you...',
    'onbPreparingSubtitle':
        "Personalizing your baby's alerts, memories and routine.",
    'onbAuthTitle': 'Your basic profile is ready',
    'onbAuthSubtitle':
        'Now create your account to keep everything safe and sync later.',
    'onbSignInGoogle': 'Sign in with Google',
    'onbSignInApple': 'Sign in with Apple',
    'onbContinueEmail': 'Continue with email',
    'onbAlreadyHaveAccount': 'I already have an account',
    'onbWait': 'Please wait...',
    'onbDoneTitle': "Done! Your baby's profile was created.",
    'onbStartTracking': 'Start tracking',
    'onbCouldNotPrepare':
        'Could not prepare the profile right now. Please try again.',
    'onbBabyNameTitle': "What is your baby's name?",
    'onbBabyNameSubtitle': 'Let’s make FaceBaby feel like your family.',
    'onbBabyNameHint': "Baby's name",
    'onbBabyBirthTitle': 'What is the date of birth?',
    'onbBabyBirthSubtitle':
        'We use age to personalize sleep, routine and growth.',
    'onbBabyWeightTitle': "What is your baby's weight?",
    'onbBabyWeightSubtitle':
        'Drag the ruler to choose. You can switch between Kg and Lb.',
    'onbBabyHeightTitle': "What is your baby's height?",
    'onbBabyHeightSubtitle':
        'Use the ruler to enter the approximate size in your preferred unit.',
    'onbMotherNameTitle': "What is mom's name?",
    'onbMotherNameSubtitle': 'We will use her name in the next questions.',
    'onbMotherNameHint': "Mom's name",
    'onbMotherBirthTitle': "What is mom's date of birth?",
    'onbMotherBirthSubtitle': 'After this, we will ask her height.',
    'onbMotherHeightTitle': 'What is {name}’s height?',
    'onbMotherHeightSubtitle': 'This helps with growth reports.',
    'onbRegisterFatherTitle': 'Do you also want to add dad?',
    'onbRegisterFatherSubtitle':
        'If you want, FaceBaby can personalize dad’s information too.',
    'onbFatherNameTitle': "What is dad's name?",
    'onbFatherNameSubtitle': 'This makes his ruler personalized too.',
    'onbFatherNameHint': "Dad's name",
    'onbFatherBirthTitle': "What is dad's date of birth?",
    'onbFatherBirthSubtitle': 'After this, we will ask his height.',
    'onbFatherHeightTitle': 'What is {name}’s height?',
    'onbFatherHeightSubtitle':
        'An approximate value is fine. You can adjust it later.',
    'onbFatherPhotoTitle': "Would you like to add a photo of dad?",
    'onbFatherPhotoSubtitle':
        'Optional — you can add it later in Family or registration.',
    'onbBabyPhotoTitle': "Would you like to add a photo of your baby?",
    'onbBabyPhotoSubtitle':
        'Optional — you can add it later during registration or in Memories.',
    'onbMotherPhotoTitle': "Would you like to add a photo of mom?",
    'onbMotherPhotoSubtitle':
        'Optional — you can add it later in Family or registration.',
    'onbBabySexTitle': "What is your baby's sex?",
    'onbSexGirl': 'Girl',
    'onbSexBoy': 'Boy',
    'onbSexUnknown': 'Prefer not to say',
    'onbFirstBabyTitle': 'Is this your first baby?',
    'onbYes': 'Yes',
    'onbNo': 'No',
    'onbConcernTitle': 'What is your biggest concern right now?',
    'onbConcernSubtitle': 'You can choose more than one.',
    'onbConcernSleep': "Baby's sleep",
    'onbConcernFeeding': 'Breastfeeding/feeding',
    'onbConcernGrowth': 'Weight and growth',
    'onbConcernRoutine': 'Daily routine',
    'onbConcernMemories': 'Memories and photos',
    'onbConcernDevelopment': 'Development',
    'onbGoalsTitle': 'What are your goals?',
    'onbGoalsSubtitle': 'We will use this to personalize your experience.',
    'onbGoalRoutine': 'Track the routine better',
    'onbGoalSleepAlerts': 'Receive sleep alerts',
    'onbGoalMoments': 'Log special moments',
    'onbGoalReports': 'Generate reports',
    'onbGoalMemoryBook': 'Create a memory book',
    'onbMessagePrefTitle': 'Spiritual mom, happy baby.',
    'onbMessagePrefSubtitle': 'Would you like to receive daily messages?',
    'onbMessagePrefChristian': 'Christian',
    'onbMessagePrefHoroscope': 'Astrological',
    'onbMessagePrefPhilosophical': 'Philosophical / Ecumenical',
    'onbMessagePrefSpiritist': 'Spiritist',
    'onbMessagePrefJewish': 'Jewish',
    'onbMessagePrefAll': 'All',
    'onbMessagePrefBoth': 'Both',
    'onbMessagePrefNone': 'Neither',
    'onbAiHistoryTitle': 'Baby history for AI Nanny',
    'onbAiHistorySubtitle':
        'Optional — share routine, health and family preferences. You can edit later in Family or AI Nanny.',
    'onbAiHistoryOptional': 'You can skip and fill in later',
    'onbDragToAdjust': 'Drag to adjust',
    'onbEmailSheetTitle': 'Create account with email',
    'onbYourNameHint': 'Your name',
    'onbEmailHint': 'Email',
    'onbPasswordHint': 'Password',
    'onbCreateAccount': 'Create account',
    'onbValYourName': 'Enter your name.',
    'onbValEmailRequired': 'Enter your email.',
    'onbValEmailInvalid': 'Invalid email.',
    'onbValPasswordMin': 'Use at least 6 characters.',
    'vaccinesTitle': 'Vaccines',
    'vaccinesSubtitle': 'Add vaccines, dates and next doses.',
    'baby': 'Baby',
    'selectBaby': 'Select baby',
    'addVaccine': 'Add vaccine',
    'recordsTitle': 'Records',
    'noVaccinesYet': 'No vaccines yet.',
    'seeAll': 'See all',
    'changePhoto': 'Change photo',
    'motherPhotoTitle': "Mom's photo",
    'babyPhotoTitle': "Baby's photo",
    'familyTabMotherLabel': 'Mom',
    'familyTabFatherLabel': 'Dad',
    'familyTitle': 'Family',
    'familySubtitle': 'Where love grows together 💖',
    'familyEdit': 'Edit',
    'familyEditData': 'Edit data >',
    'familyRoleMother': 'Mom',
    'familyRoleFather': 'Dad',
    'familyRoleBaby': 'Baby',
    'familyZodiacSolar': 'Sun sign',
    'familyEntertainmentNote':
        'Light, affectionate content for entertainment — not professional advice.',
    'familyChristianCardTitle': 'Message for the family',
    'familySpiritistCardTitle': 'Spiritist message',
    'familyJewishCardTitle': 'Jewish message',
    'familyChristianLine': '📖 {ref}',
    'familyBornOn': 'Born: {date}',
    'familyAgeOneYear': '1 year',
    'familyAgeYears': '{n} years',
    'familyHeight': 'Height: {value}',
    'familyMotherBlurb':
        'As a {sign} mom, you tend to show love in a {traits} way.',
    'familyFatherBlurb':
        'As a {sign} dad, you tend to protect, teach and bond with your baby in a {traits} way.',
    'familyBabyBlurb': 'As a {sign} baby, they may show traits like {traits}.',
    'familyZodiacName_capricorn': 'Capricorn',
    'familyZodiacName_aquarius': 'Aquarius',
    'familyZodiacName_pisces': 'Pisces',
    'familyZodiacName_aries': 'Aries',
    'familyZodiacName_taurus': 'Taurus',
    'familyZodiacName_gemini': 'Gemini',
    'familyZodiacName_cancer': 'Cancer',
    'familyZodiacName_leo': 'Leo',
    'familyZodiacName_virgo': 'Virgo',
    'familyZodiacName_libra': 'Libra',
    'familyZodiacName_scorpio': 'Scorpio',
    'familyZodiacName_sagittarius': 'Sagittarius',
    'familyZodiacTrait_capricorn': 'calm, responsible and nurturing',
    'familyZodiacTrait_aquarius': 'creative, gentle and affectionate',
    'familyZodiacTrait_pisces': 'sensitive, sweet and empathetic',
    'familyZodiacTrait_aries': 'energetic, protective and loving',
    'familyZodiacTrait_taurus': 'patient, steady and present',
    'familyZodiacTrait_gemini': 'cheerful, communicative and curious',
    'familyZodiacTrait_cancer': 'affectionate, intuitive and protective',
    'familyZodiacTrait_leo': 'warm, proud and generous',
    'familyZodiacTrait_virgo': 'caring, attentive and dedicated',
    'familyZodiacTrait_libra': 'harmonious, loving and balanced',
    'familyZodiacTrait_scorpio': 'deeply loving, loyal and protective',
    'familyZodiacTrait_sagittarius': 'optimistic, playful and hopeful',
    'familyFatherDataComplete': "Dad's data — complete and up to date",
    'familyFatherDataIncomplete': "Dad's data — still incomplete",
    'familyAddFatherPrompt':
        "Add dad's details to see your baby's estimated adult height.",
    'familyAddFatherButton': "Add dad's details",
    'familyCompleteBabySex':
        "Add your baby's sex in their profile to calculate estimated height.",
    'familyEditBabyData': "Edit baby's profile",
    'familyCompleteHeights': 'We need both parents\' heights for the estimate.',
    'familyCompleteHeightsButton': 'Complete heights',
    'familyEstimatedHeightTitle': 'Estimated height for {name}',
    'familyMotherHeightLabel': "Mom's height",
    'familyFatherHeightLabel': "Dad's height",
    'familyEstimatedGirl': 'Estimated height for a girl',
    'familyEstimatedBoy': 'Estimated height for a boy',
    'familyEstimatedResult': 'approximately {cm}',
    'familyHowCalculated': 'How is it calculated?',
    'familyFormulaBoy': 'Boy: (father + mother + 13) ÷ 2',
    'familyFormulaGirl': 'Girl: (father + mother − 13) ÷ 2',
    'familyEstimatedHeightDescription':
        "Estimate based on the parents' heights and the baby's sex. It does not account for environmental, nutritional, health or other factors. For guidance only.",
    'familyFormulaExampleGirl': '({father} + {mother} − 13) ÷ 2 = {result} cm',
    'familyFormulaExampleBoy': '({father} + {mother} + 13) ÷ 2 = {result} cm',
    'familyHeightDisclaimer':
        'This is a simple estimate used as a pediatric reference. Final height can vary with genetics, nutrition, sleep, health, puberty and other factors. Follow-up with your pediatrician remains essential.',
    'familyZodiacReadMore': 'Read full text',
    'familyPremiumZodiacLocked':
        'Solar signs and personalized texts are included in FaceBaby Premium.',
    'familyPremiumHeightLocked':
        'Estimated adult height is included in FaceBaby Premium.',
    'familyPremiumUnlockCta': 'Unlock Premium',
    'familyScreenTitle': 'Family 💜',
    'familyPersonalInfoTitle': 'Personal information',
    'familyHoroscopeCardTitle': 'Horoscope for {sign}',
    'familyBibleVerseCardTitle': 'Bible verse of the day',
    'familyDailySummaryTitle': 'Today summary',
    'familySummaryFeeding': 'Feedings',
    'familySummaryDiapers': 'Diapers',
    'familySummarySleep': 'Sleep',
    'familySummaryWeight': 'Weight',
    'familyQuickLabelBirth': 'Birth',
    'familyQuickLabelTime': 'Time',
    'familySummaryFeedingsToday': '{n}× today',
    'familySummaryDiaperChangesCount': '{n} changes',
    'familySummaryLastAt': 'Last at {time}',
    'familySummaryLastSleepAt': 'Last at {time}',
    'familySummaryWeightDayLine': 'Day total',
    'familyFieldBirthDate': 'Date of birth',
    'familyFieldSign': 'Sign',
    'familyFieldElement': 'Element',
    'familyFieldAge': 'Age',
    'familyFieldHeight': 'Height',
    'familyFieldWeight': 'Weight',
    'familyPremiumShortBadge': 'Premium',
    'familyPremiumFeatureLockedBody':
        'This content is part of FaceBaby Premium. Tap to see plans.',
    'familyPremiumBannerTitle': 'Unlock Premium content',
    'familyPremiumBannerBody':
        'Full horoscopes, exclusive Bible verses and tailored suggestions.',
    'familyPremiumViewPlans': 'See plans',
    'familyAddFatherCardTitle': 'Add dad’s details',
    'familyElementFire': 'Fire',
    'familyElementEarth': 'Earth',
    'familyElementAir': 'Air',
    'familyElementWater': 'Water',
    'familyTapToOpen': 'Tap for details',
    'familyCarouselSwipe': 'Swipe to browse each member',
    'familyTabNene': 'Baby',
    'familyTabsHint': 'Tap a name to see details',
    'familyTapToClose': 'Close',
    'familyShareCard': 'Share',
    'changeBabyTooltip': 'Switch baby',
    'notificationsInboxTitle': 'Notifications',
    'notificationsInboxSubtitle':
        'Last 3 days (delivered and scheduled, logged in the app)',
    'notificationsEmpty': 'No notifications logged in this period yet.',
    'notificationsKindShown': 'Delivered',
    'notificationsKindScheduled': 'Scheduled',
    'notificationsOpenTarget': 'Tap to open',
    'notificationsSelectAll': 'Select all',
    'deleteAccountTitle': 'Delete account',
    'deleteAccountBody':
        'This will delete your account and ALL your data (mom, baby and records) from the cloud.\n\nThis action cannot be undone.',
    'deleteAccountConfirm': 'Delete everything',
    'deleteAccountDeleting': 'Deleting your account...',
    'deleteAccountSuccess': 'Account deleted successfully.',
    'deleteAccountReauthTitle': 'Confirm password or Google',
    'deleteAccountReauthBody':
        'Last step before deletion: confirm how you sign in (email password or Google/Gmail account).',
    'deleteAccountReauthGoogleSection': 'Signed in with Google / Gmail',
    'deleteAccountReauthGoogleAccountHint': 'Google account: {email}',
    'deleteAccountReauthPasswordSection': 'Signed in with email and password',
    'deleteAccountReauthOrDivider': 'or',
    'deleteAccountReauthEmailLabel': 'Account email',
    'deleteAccountReauthPasswordHint': 'Current password',
    'deleteAccountReauthPasswordRequired':
        'Enter your account’s current password.',
    'deleteAccountReauthGoogle': 'Confirm with Google (Gmail)',
    'deleteAccountReauthContinue': 'Confirm with password',
    'deleteAccountReauthCantPassword':
        'Use the button for the same sign-in method (Google/Gmail or email and password) you used when creating the account.',
    'deleteAccountTypeWordTitle': 'Final confirmation',
    'deleteAccountTypeWordInstruction':
        'To permanently delete your account, type delete in the field below. Next we will ask for password or Google (Gmail) confirmation.',
    'deleteAccountTypeWordFieldLabel': 'delete',
    'homeBabyBannerForecastSleep': 'Sleep forecast',
    'homeBabyBannerForecastWake': 'Wake-up forecast',
    'homeBabyBannerForecastSubtitleSleep':
        'Sleep cues detected\nbased on the current time',
    'homeBabyBannerForecastSubtitleWake':
        'Based on current time and age pattern',
    'homeBabyBannerEtaIn': 'in {d}',
    'homeBabyBannerLastDiaper': 'Last diaper',
    'homeBabyBannerNoRecordsYet': 'No records yet',
    'homeBabyBannerNextBetween': 'Next between {range}',
    'homeBabyBannerDiaperRecommendedUntil': 'Change recommended until {d}',
    'homeBabyBannerIdealWindow': 'Ideal window: {range}',
    'homeConsultationScheduled': 'Consultation scheduled',
    'homeBannerChipConsultation': 'Consultation',
    'homeBannerChipDiaper': 'Diaper',
    'homeBannerChipFeed': 'Feed',
    'homeBannerChipSleep': 'Sleep',
    'homeBannerOverdueSleep': "It's past sleep time",
    'homeBannerOverdueWake': "It's past wake-up time",
    'homeBannerHungry': 'Hungry',
    'homeBannerDiaperDirty': 'May be dirty',
    'homeBannerExhausted': 'EXHAUSTED',
    'memoryTellMomentTitle': 'Tell about this moment',
    'memoryTellMomentHint': 'How was it? Share details you want to remember…',
    'memoryBabyInfoOptionalTitle': 'Baby info (optional)',
    'memoryBabyMoodLabel': 'Mood/state',
    'memoryBabyMoodHint': 'e.g. Happy',
    'memoryMomentInfoTitle': 'About this moment',
    'memoryStatAgeLabel': 'Age',
    'memoryStatWeightLabel': 'Weight',
    'memoryStatHeightLabel': 'Height',
    'memoryStatMoodLabel': 'How they were',
    'memoryMotherNotesLabel': "Mom's notes",
    'memoryTipForYouTitle': 'A tip for you',
    'memoryShareButton': 'Share',
    'memoryFavoriteButton': 'Favorite',
    'memoryFavoritedButton': 'Favorited',
    'weeklyPhotoPublicExplainer':
        'When you mark this as public, the photo may enter Photo of the Week and be seen by other moms in FaceBaby.',
    'weeklyPhotoPublicOff': 'Private',
    'weeklyPhotoPublicOn': 'Public',
    'weeklyPhotoPublicNeedPhoto':
        'Add a photo before marking this memory public.',
    'weeklyPhotoConfirmTitle': 'Make this photo public?',
    'weeklyPhotoConfirmBody':
        'Do you agree to show this photo to other users if you are selected as the weekly winner?',
    'weeklyPhotoConfirmNo': 'No',
    'weeklyPhotoConfirmYes': 'Yes',
    'weeklyPhotoParticipatingBadge': 'Entered for Photo of the Week',
    'weeklyPhotoWinnerBadge': 'This memory was chosen as Photo of the Week 💜',
    'weeklyPhotoShowBabyFirstName':
        "Show baby's first name on the public gallery",
    'weeklyPhotoDisclaimerFooter':
        'Only photos marked public participate. You can remove this anytime.',
    'weeklyPhotoReportLink': 'Report',
    'weeklyPhotoReportTitle': 'Report photo',
    'weeklyPhotoReportHint':
        'Describe the reason for your report. The FaceBaby team will review it.',
    'weeklyPhotoReportMessageLabel': 'Reason for report',
    'weeklyPhotoReportSubmit': 'Send report',
    'weeklyPhotoReportSuccess':
        'Report sent. Thank you for helping keep the community safe.',
    'weeklyPhotoReportNeedLogin': 'Sign in to your account to send a report.',
    'weeklyPhotoReportMessageTooShort':
        'Write at least 5 characters in the report reason.',
    'weeklyPhotoReportMessageTooLong': 'The report text is too long.',
    'weeklyPhotoReportFailed': 'Could not send the report. Please try again.',
    'weeklyPhotoSectionTitleMale': 'Prince of the Week',
    'weeklyPhotoSectionTitleFemale': 'Princess of the Week',
    'weeklyPhotoHomeHeroMale': 'PRINCE OF THE WEEK',
    'weeklyPhotoHomeHeroFemale': 'PRINCESS OF THE WEEK',
    'weeklyPhotoSectionSubtitle': 'A special memory shared by a FaceBaby mom.',
    'weeklyPhotoViewMemory': 'View memory',
    'weeklyPhotoBabyFallback': 'A FaceBaby baby',
    'weeklyPhotoDisclaimerShort':
        'Only photos marked public participate. You can remove this anytime.',
    'weeklyPhotoPublicDetailAppBar': 'Weekly memory',
    'weeklyPhotoWinnerCongratsTitle': 'Congratulations, Mom!',
    'weeklyPhotoWinnerCongratsBody':
        "Your Princess's photo was chosen as Photo of the Week! Let's all celebrate her.\n\nThe FaceBaby family thanks you for sharing this beautiful moment with us! 💜",
    'weeklyPhotoWinnerCongratsBodyMale':
        "Your Prince's photo was chosen as Photo of the Week! Let's all celebrate him.\n\nThe FaceBaby family thanks you for sharing this beautiful moment with us! 💜",
    'weeklyPhotoWinnerCongratsBodyFemale':
        "Your Princess's photo was chosen as Photo of the Week! Let's all celebrate her.\n\nThe FaceBaby family thanks you for sharing this beautiful moment with us! 💜",
    'weeklyPhotoWinnerCongratsOk': 'Confirm',
    'weeklyPhotoLikesCount': '{count} likes',
    'weeklyPhotoLikeButton': 'Like',
    'weeklyPhotoLikedButton': 'Liked',
    'weeklyPhotoLikesWinnerHint': 'People who liked your baby’s photo',
    'weeklyPhotoLikeNeedSignIn':
        'Sign in with the same account to like the Weekly Photo.',
    'memoryEditTitle': 'Edit memory',
    'memoryNewTitle': 'New memory',
    'memoryMomNotesFieldLabel': "Mom's notes",
    'memorySaveChanges': 'Save changes',
    'memorySaveNew': 'Save memory',
    'memoryNoDescription': 'No description for this moment yet.',
    'memoryPhotoAddTitle': 'Add a photo',
    'memoryPhotoEditTitle': 'Change the photo',
    'memoryTapToPickPhoto': 'Tap',
    'memoryAgeHintExample': 'e.g. 10 days',
    'memoryWeightHintExample': 'e.g. 3.28',
    'memoryHeightHintExample': 'e.g. 49',
    'memorySaveNeedPhotoOrText': 'Add a photo or write a description to save.',
    'memorySaveFail': 'Could not save:',
    'memoryShareWebOnlyMobile':
        'Sharing image or PDF is available in the installed app (Android/iOS).',
    'memoryShareSheetJpegTitle': 'Image (JPG)',
    'memoryShareSheetJpegSubtitle':
        'Choose WhatsApp, email, Bluetooth… in the system sheet',
    'memoryShareSheetPdfTitle': 'PDF (one page)',
    'memoryShareSheetPdfSubtitle': 'Handy for email or archives',
    'memorySharePlatformUnavailable': 'Not available on this platform.',
    'memoryShareError': 'Could not share: {error}',
    'memoryFooterBranding': 'FaceBaby • Memory book',
    'memoryTipFirstSmile':
        'Smiling is one of the first ways babies connect and bond. Keep talking and smiling at them!',
    'memoryTipFirstLaugh':
        'Laughter strengthens the bond and shows your baby is comfortable. Repeat games that make them giggle.',
    'memoryTipFirstFeeding':
        'The first breastfeeding days are about adapting. If unsure, ask your pediatrician or lactation support.',
    'memoryTipFirstSteps':
        'Every baby has their own pace. Offer a safe space and encourage without pressure—the first steps come in time.',
    'memoryTipDefault':
        'Moments like this stay in the family memory forever. Keep recording what matters to you.',
    'memoryAgeOneDay': '1 day',
    'memoryAgeManyDays': '{n} days',
    'helloMomNamed': 'Hi, Mom {name}!',
    'registerVerb': 'Log',
    'viewCalendar': 'View calendar',
    'shortcutMilk': 'Feeding',
    'shortcutSleep': 'Sleep',
    'shortcutVaccines': 'Vaccines',
    'homeFedAgo': 'Fed\u00A0{when} ago',
    'homePeeAgo': 'Pee\u00A0{when} ago',
    'homePooAgo': 'Poop\u00A0{when} ago',
    'homeNextNow': 'Next: now.',
    'homeNextIn': 'Next in {n} min.',
    'homeStatusOk': 'All good now',
    'homeStatusWarn': 'Light alert',
    'homeStatusHungry': 'May be hungry',
    'homeTimeToFeed': 'Time to feed!',
    'homeStatusDetailFed': 'Recent feeding',
    'homeStatusDetailNear': 'Close to feeding time',
    'homeStatusDetailLate': 'Been a while',
    'homePickDayLabel': 'Summary day',
    'homeTodayLabel': 'Today',
    'homeYesterdayLabel': 'Yesterday',
    'homeSummaryOnDate': 'Summary — {date}',
    'homeSummaryPickDayTooltip':
        'Pick summary day (history saved after each day ends)',
    'homeFedAt': 'Feeding at {time}',
    'homePeeAt': 'Pee at {time}',
    'homePooAt': 'Poop at {time}',
    'homeDiaperChangeAgo': 'Diaper change\u00A0{when} ago',
    'homeDiaperChangeAt': 'Diaper change at {time}',
    'homeSleepEndedAgo': 'Last sleep\u00A0{when} ago',
    'homeSleepEndedAt': 'Last sleep at {time}',
    'homeSleepInProgress': 'Sleeping · {elapsed}',
    'homeSleepPausedBanner': 'Sleep paused · {elapsed}',
    'sleepBannerEmpty': 'No sleep logs yet.',
    'homePastDayBadge': 'Past day',
    'homePastDayDetail': 'Times recorded on this day',
    'homeBannerAlertCheckDiaper': 'Check diaper',
    'homeBannerAlertTimeToSleep': 'Time to sleep',
    'homeBannerAlertSleepingLong': 'Sleeping a long time',
    'homeCriticalCareTitle': 'Care that needs attention',
    'homeCriticalCareCount': '{n} care items need attention',
    'homeCriticalFeedingTitle': 'It may be time to feed',
    'homeCriticalSleepTitle': 'It may be time to sleep',
    'homeCriticalDiaperTitle': 'It may be time to change the diaper',
    'homeCriticalFeedingSubtitle':
        'It may have passed the expected time since the last feeding.',
    'homeCriticalSleepSubtitle': 'The awake window may have been exceeded.',
    'homeCriticalWakeTitle': 'Past wake-up time',
    'homeCriticalWakeSubtitle':
        'The sleep session may have exceeded the recommended duration.',
    'homeCriticalDiaperSubtitle':
        'It may have been a while since the last change.',
    'homeSleepBarAwakeTitle': 'Awake · window until sleep',
    'homeSleepBarSleepTitle': 'Sleeping · session time',
    'homeFeedingCounterTitle': 'Feeding · time until next interval',
    'homeFeedingCounterHint': 'Countdown (interval in Quick logs)',
    'homeSleepBarAwakeHintEarly': '≈ {m} min until the ideal window',
    'homeSleepBarAwakeHintIdeal': '≈ {m} min until the window ends',
    'homeSleepBarAwakeHintOverdue': 'Past the window · time to consider sleep',
    'homeSleepBarSleepHint': '{remaining} left · session cap ~{cap} min',
    'homeSleepBarNeedLastSleep': 'Log the last sleep session to see the bar',
    'homeTipTitle': 'Tip of the day',
    'homeTipBody': 'Consistent routines help your baby feel safe and calm.',
    'homeYesterdayBabaTitle': 'AI Nanny · yesterday',
    'homeYesterdayBabaFallback':
        'Log {name}\'s routine for a pediatric readout.',
    'homeYesterdayBabaRoutineQuiet':
        'Few logs — predictable routines support emotional regulation.',
    'homeYesterdayBabaRoutine':
        '{feeds} feeds · {sleep} sleep · {diapers} diaper changes.',
    'homeYesterdayBabaRoutineLowSleep':
        '{feeds} feeds · {sleep} sleep (low) · {diapers} diaper changes.',
    'homeYesterdayBabaGrowthBothWithin':
        'Weight and length on the reference curve.',
    'homeYesterdayBabaGrowthNoData': 'Update weight/length on the curve.',
    'homeYesterdayBabaGrowthBelow':
        'Growth below reference — discuss with your pediatrician.',
    'homeYesterdayBabaGrowthAbove':
        'Growth above reference — review at the next visit.',
    'homeYesterdayBabaGrowthCombo': 'Curve: weight {weight}, length {height}.',
    'homeYesterdayBabaBandWithin': 'adequate',
    'homeYesterdayBabaBandBelow': 'below',
    'homeYesterdayBabaBandAbove': 'above',
    'homeYesterdayBabaBandUnknown': '—',
    'homeAiInsightDailyTitle': 'AI Nanny · today',
    'homeAiInsightWeeklyTitle': 'AI Nanny · week',
    'aiBubbleDragToClose': 'Drag to the red zone to close',
    'aiBubbleCloseZone': 'Drop here to close',
    'floatingMessageDropToClose': 'Drop here to close',
    'floatingMessageDropToCloseAll': 'Drop here to close all notices',
    'floatingMessageLinkOpenFailed':
        'Could not open the link. Check the URL (https).',
    'aiBubbleOpenLink': 'Open link',
    'aiBubblePromoKnowMore': 'Learn more',
    'homeAiInsightDailySleepBetter':
        'Today {name} slept better than the day before.',
    'homeAiInsightDailySleepLess':
        '{name}\'s sleep was a bit shorter yesterday — observe with care.',
    'homeAiInsightDailyFeedingBetter':
        '{name}\'s feeding pattern improved.',
    'homeAiInsightDailyPeaceful':
        'Today {name} had a calmer routine.',
    'homeAiInsightDailyQuiet':
        'Log {name}\'s routine for sharper insights.',
    'homeAiInsightDailyDefault':
        'I\'m following {name}\'s routine with care.',
    'homeAiInsightDailyWithGrowth':
        '{name}\'s routine is steady · {growth}',
    'homeAiInsightWeeklySleepImproved':
        'This week {name}\'s sleep improved vs last week.',
    'homeAiInsightWeeklyFeedingImproved':
        'This week {name}\'s feeding pattern improved.',
    'homeAiInsightWeeklyStable':
        '{name}\'s routine stayed steady this week.',
    'homeAiInsightWeeklyFewData':
        'Log more days for {name}\'s weekly summary.',
    'homeAiInsightGrowthShortHealthy': 'growth on expected curve',
    'homeAiInsightGrowthShortWatch': 'watch weight/height on the curve',
    'aiBubbleFeverAcute':
        '{name} may have a fever now — keep fluids up, a cool room, and check temperature hourly.',
    'aiBubbleFeverAcuteWithTemp':
        '{name} is at {temp}°C — stay hydrated and watch closely over the next few hours.',
    'aiBubbleFeverAcuteHigh':
        '{name} is at {temp}°C (high). Watch closely; call your pediatrician if it stays high or worsens.',
    'aiBubbleFeverFollowUp':
        'How is {name} today? If fever continues, measure again and log it under Health.',
    'aiBubbleFeverFollowUpWithTemp':
        'Remember {name}\'s fever ({temp}°C). How is temperature now?',
    'aiBubbleFeverRecoveryCheck':
        'It\'s been {days} day(s) since we noted fever for {name}. Is she feeling better?',
    'aiBubbleConsultToday':
        'Appointment today for {name}: {title} at {when}.',
    'aiBubbleVaccineToday': 'Vaccine today for {name}: {vaccine}.',
    'aiBubbleVaccinesToday': '{count} vaccines due today for {name}.',
    'aiBubbleSleepWakeLong':
        '{name} has been asleep for {hours}h — a gentle wake-up may help.',
    'aiBubbleSleepTracking':
        '{name}\'s sleep timer has been running for {hours}h.',
    'aiBubbleFeedingCritical':
        'Feeding time? {name}\'s feeding interval may have passed.',
    'aiBubbleSleepCritical':
        'Nap time? {name}\'s awake window may be overdue.',
    'aiBubbleSleepApproach':
        '{name}\'s next nap window may be coming up soon.',
    'aiBubbleDiaperCritical':
        'Diaper change? It\'s been a while since {name}\'s last change.',
    'aiBubbleWeightDown':
        '{name}\'s latest weight is below the previous entry — worth watching.',
    'aiBubbleGrowthWeightBelow':
        'Urgent: {name}\'s weight ({value} kg) is below the reference curve for this age ({min}–{max} kg). Verify the entry. For this type of alert, see a doctor or pediatrician.',
    'aiBubbleGrowthWeightAbove':
        'Urgent: {name}\'s weight ({value} kg) is above the reference curve for this age ({min}–{max} kg). Verify the entry. For this type of alert, see a doctor or pediatrician.',
    'aiBubbleGrowthHeightBelow':
        'Urgent: {name}\'s height ({value} cm) is below the reference curve for this age ({min}–{max} cm). Verify the entry. For this type of alert, see a doctor or pediatrician.',
    'aiBubbleGrowthHeightAbove':
        'Urgent: {name}\'s height ({value} cm) is above the reference curve for this age ({min}–{max} cm). Verify the entry. For this type of alert, see a doctor or pediatrician.',
    'aiBubbleGrowthStale':
        'No weight or height logged for {name} in {days} days.',
    'aiBubbleGrowthNone':
        'No growth measurements yet for {name} — log weight or height.',
    'aiBubbleGrowthWatch':
        '{name}\'s growth curve: {hint}.',
    'aiBubbleTodayEmpty':
        'Few logs today for {name} — a quick routine entry helps a lot.',
    'homeGreetingSubtitle': 'Good to see you here today!',
    'homeMotivationBanner':
        "You're doing a great job! Small logs, big memories.",
    'homeMotivationBannerOpenMemories': 'Open memory book',
    'summaryWeightNotYet': 'Not logged yet',
    'summarySleepNotYet': 'No sleep logged today',
    'shortcutMilkHomeSub': 'Log a feeding',
    'shortcutGrowthHomeSub': 'Log weight and height',
    'shortcutSleepHomeSub': 'Log sleep',
    'homeTileDiapers': 'Diaper changes',
    'homeOneDayOld': '1 day',
    'homeDaysOld': '{d} days',
    'babyAgeOneWeek': '1 week',
    'babyAgeWeeks': '{n} weeks',
    'babyAgeOneMonth': '1 month',
    'babyAgeMonths': '{n} months',
    'babyAgeOneYear': '1 year',
    'babyAgeYears': '{n} years',
    'summaryFeedings': 'FEEDINGS',
    'summarySleep': 'SLEEP',
    'summaryLastFeed': 'Last at {time}',
    'summaryLastSleep': 'Last at {time}',
    'summaryDiapers': 'DIAPERS',
    'summaryFeedingsValue': '{n} · {m} min',
    'summaryFeedingsCountOne': '1 feeding',
    'summaryFeedingsCountMany': '{n} feedings',
    'summaryFeedingsMinutes': '{m} min',
    'summaryDiapersValue': 'Total {total} · Pee {pee} · Poop {poo}',
    'summaryDiapersTotal': 'Total {total} changes',
    'summaryDiapersChangesOne': '1 change',
    'summaryDiapersChangesMany': '{n} changes',
    'summaryDiapersPeePoo': '{pee} - Pee    {poo} - Poop',
    'summarySleepValue': '{s} · {t}',
    'summarySleepSessionsOne': '1 nap',
    'summarySleepSessionsMany': '{s} naps',
    'summaryWeight': 'WEIGHT',
    'homeSummaryExtraHint': 'Totals for the selected day',
    'homeSummaryNoRecords': 'No records',
    'homeSummaryTotalDay': 'Total for the day',
    'add': 'Add',
    'labelWeight': 'Weight',
    'labelHeight': 'Height',
    'labelHead': 'Head circumference',
    'growthTabWeight': 'Weight',
    'growthTabHeight': 'Height',
    'growthTabHead': 'Head',
    'growthTabSummary': 'Summary',
    'growthAtBirth': 'At birth',
    'growthCardCurrent': 'Current',
    'growthCardChange': 'Change',
    'growthAddWeight': 'Add weight',
    'growthAddHeight': 'Add height',
    'growthAddHead': 'Add head',
    'growthSummaryIntro': 'Overview of weight and height.',
    'growthChartCaption': '{name} — {metric}',
    'growthChartDeltaHint':
        'Vertical axis: change from the at-birth value (0 = at birth).',
    'growthCurveSectionTitle': 'Growth curve (height)',
    'growthCurveSectionTitleWeight': 'Growth curve (weight)',
    'growthCurveDisclaimer':
        'This information is for guidance only and does not replace a medical evaluation.',
    'growthCurveLegendMin': 'Healthy minimum',
    'growthCurveLegendAvg': 'Healthy average',
    'growthCurveLegendMax': 'Healthy maximum',
    'growthCurveLegendBaby': "Baby's progress",
    'growthCurveAxisMonths': 'months',
    'growthCurveReferenceGirls': 'Reference — girls (0–4 years)',
    'growthCurveReferenceBoys': 'Reference — boys (0–4 years)',
    'growthCurveSexHint':
        "Add your baby's sex in their profile for the correct reference curve. Showing girls' reference.",
    'growthInsightBandWithin':
        '{name} is within the healthy height range for {sexWord} at {months} months.',
    'growthInsightBandAbove':
        'Growth is above the healthy average for {sexWord} at {months} months — for information only.',
    'growthInsightBandBelow':
        'Height is below the healthy minimum for age — consider mentioning it at your next pediatric visit, without worry.',
    'growthInsightBandUnknown':
        'Log more height measurements to follow the curve calmly.',
    'growthInsightSexWordGirl': 'girls',
    'growthInsightSexWordBoy': 'boys',
    'growthInsightPeriodHeight':
        'In the last {days} days, {name} grew {delta} cm.',
    'growthInsightPeriodWeight':
        'In the last {days} days, {name} changed weight by {delta}.',
    'growthInsightWeightBandWithin':
        '{name} is in the healthy weight range for {sexWord} at {months} months.',
    'growthInsightWeightBandAbove':
        'Weight is above the healthy average for {sexWord} at {months} months — for information only.',
    'growthInsightWeightBandBelow':
        'Weight is below the healthy minimum for this age — worth mentioning to your pediatrician at the next visit, without alarm.',
    'growthInsightWeightBandUnknown':
        'Log more weight measurements to follow the curve calmly.',
    'growthInsightCurveConsistent':
        'The curve stays consistent with recent measurements.',
    'growthInsightVelocityHealthy':
        'Growth velocity looks healthy for this age.',
    'growthInsightVelocitySlowdown':
        'Growth slowed slightly but may still be within a healthy pace.',
    'growthInsightVelocityAcceleration':
        'There was a slightly faster growth phase — common at some ages.',
    'growthInsightVelocityStable':
        'Growth pace is stable between recent measurements.',
    'growthInsightVelocityGentle':
        'Pace between measurements was slower — keep tracking calmly over the next weeks.',
    'growthInsightVelocityUnknown':
        'Add at least two measurements to estimate growth velocity.',
    'reportPediatricGrowthInsights': 'Growth trends (informational)',
    'reportPediatricSectionGrowthCurve': 'Growth curve (reference)',
    'aiNannyNavLabel': 'AI Nanny',
    'aiNannyPhase1Hint': 'Chat arrives in the next phase. The shortcut is already in the menu.',
    'aiNannyTitle': 'AI Nanny 24/7 with you',
    'aiNannySubtitle':
        'A caring counselor for mom, dad and family — baby routine and emotional support.',
    'aiNannyWelcomeMessage':
        '🤖 Hi! I\'m AI Nanny 💜\n\n'
        'I\'m your companion and counselor: I can help log routine (feeds, sleep, vaccines…), '
        'answer questions about your baby or pregnancy, and listen when mom, dad or family need to vent. '
        'I\'m here for you ✨',
    'aiNannyGrowthCurveContextHeader':
        'GROWTH ALERT (required): the baby has a measurement outside the healthy reference curve for their age. If the family asks how the baby is doing, about weight, height, health, or growth, mention this alert gently — do not skip it just to sound positive.',
    'aiNannyGrowthCurveContextFooter':
        'Suggest verifying the log entry and seeing a pediatrician for evaluation.',
    'aiEmotionalMonthiversary':
        '🤖 Today {name} turns {months} {unit} ❤️\n{hint}',
    'aiEmotionalMonthSingular': 'month',
    'aiEmotionalMonthsPlural': 'months',
    'aiEmotionalTbtPhoto':
        '🤖 {when}, this was one of {name}\'s first photos 🥹',
    'aiEmotionalTbtWeek': 'One week ago',
    'aiEmotionalTbtMonth': 'One month ago',
    'aiEmotionalTbtYear': 'One year ago',
    'aiEmotionalAchieveFeedingStreak':
        '🤖 {days} days in a row logging feeds for {name} 🎉',
    'aiEmotionalAchieve100Records':
        '🤖 {count} records logged with {name} ✨',
    'aiEmotionalAchieveFirstMonth':
        '🤖 First month tracking {name} on FaceBaby ❤️',
    'aiEmotionalAchieveSleepStable':
        '🤖 {name}\'s sleep routine looked steadier this week 🌙',
    'aiEmotionalSpontSleepBetter':
        '🤖 {name} slept better than yesterday 🌙',
    'aiEmotionalSpontFeedingRegular':
        '🤖 {name}\'s feeding pattern looks more regular ❤️',
    'aiEmotionalSpontDevelopment':
        '🤖 {name} may start to {hint} 👶✨',
    'aiEmotionalSpontSmilePhase': 'smile more at this stage',
    'aiEmotionalSpontEncouragement':
        '🤖 You\'re doing great with {name} 💕',
    'aiEmotionalSpontGentleCare':
        '🤖 Gentle care for {name} matters — I\'m here with you 💜',
    'aiEmotionalDev1Month':
        'They\'re starting to recognize familiar voices ✨',
    'aiEmotionalDev2Months':
        'They\'re discovering more of the world around them ✨',
    'aiEmotionalDev3Months':
        'Smiles and new sounds may show up more often ✨',
    'aiEmotionalDev4to5Months':
        'They explore more and respond to your warmth ✨',
    'aiEmotionalDev6to8Months':
        'They may show more curiosity and interaction ✨',
    'aiEmotionalDev9to11Months':
        'They may be more active and communicative now ✨',
    'aiEmotionalDev12to23Months':
        'Every small milestone counts at this stage ✨',
    'aiEmotionalDevToddler':
        'Their personality shines brighter every day ✨',
    'aiNannyMockReply':
        'Got it ❤️ In the next phase I\'ll answer using your baby\'s real records.',
    'aiNannyInputHint': 'Type your question…',
    'aiNannyThinking': 'AI Nanny is thinking…',
    'aiNannyDisclaimer':
        'Informational content only. Not a substitute for medical care.',
    'aiNannyPremiumTitle': 'AI Nanny 24/7 with you',
    'aiNannyPremiumBody':
        'Premium feature: smart chat with baby context, up to 50 messages per day.',
    'aiNannyPremiumCta': 'Unlock Premium',
    'aiNannyBenefitSmart': 'Smart answers',
    'aiNannyBenefitPersonal': 'Personalized guidance',
    'aiNannyBenefitAlerts': 'Predictive alerts (coming soon)',
    'aiNannyBenefitRoutines': 'Personalized routines',
    'aiNannyBenefitContent': 'AI-generated content',
    'aiNannyBenefitAudioSoon': 'Coming soon: voice replies',
    'aiNannyAskBelow': 'Ask your first question below.',
    'aiNannyNoBaby': 'Add a baby profile to personalize answers.',
    'aiNannyRemainingToday': 'Messages left today: {n}',
    'aiNannyDailyLimitMessage':
        'You reached the daily AI Nanny limit. Come back tomorrow.',
    'aiNannyCallFailed':
        'I could not answer right now. Please try again in a few moments.',
    'aiNannyProfileButton': 'AI profile',
    'aiNannyClearChat': 'Delete conversation',
    'aiNannyClearChatConfirmTitle': 'Delete entire conversation?',
    'aiNannyClearChatConfirmBody':
        'All AI Nanny messages will be removed from this device and the cloud. This cannot be undone.',
    'aiNannyClearChatDone': 'Conversation deleted.',
    'aiNannyDeleteExchange': 'Delete this exchange',
    'aiNannyDeleteExchangeConfirm':
        'Remove this question and the AI Nanny reply?',
    'aiNannySignInRequired': 'Sign in to use AI Nanny.',
    'aiVoiceRecording': 'Recording… {s}s (max 20)',
    'aiVoiceProcessing': 'Transcribing and interpreting…',
    'aiVoiceUnderstood': 'Got it: {text}',
    'aiVoiceConfirmTitle': 'Register this?',
    'aiVoiceConfirm': 'Confirm',
    'aiVoiceMicDenied':
        'Microphone access is needed for voice logging. Enable it in device settings.',
    'aiVoiceMicWebUnavailable': 'Voice logging is available on Android and iOS apps.',
    'aiVoiceSavedOk': 'Record saved successfully.',
    'aiVoiceSavedFeedingAndDiaper': 'Feeding and diaper change saved.',
    'aiVoiceSavedSymptom': 'Symptoms saved in Health.',
    'aiVoiceNeedClarification': '',
    'aiClarifyFeedingPrefix': 'About feeding:',
    'aiClarifyDiaperPrefix': 'About the diaper:',
    'aiClarifyBreastSide': 'left or right breast?',
    'aiClarifyFeedingDuration': 'how many minutes did it last?',
    'aiClarifyRegisterNeeded': 'To save this in the app, I need to know:',
    'aiNannyRecordsFoundTitle': '🤖 I found these records',
    'aiNannyConfirmCompleteRecords': 'Confirm complete records',
    'aiNannyCompleteMissingData': 'Complete missing data',
    'aiNannySaveAllPossible': 'Save all possible',
    'aiNannyCancelRecords': 'Cancel',
    'aiGrowthNeedBaselineWeight':
        'Weight: need a previous weight to calculate the gain.',
    'aiGrowthNeedBaselineHeight':
        'Height: need a previous measurement to calculate growth.',
    'aiGrowthWeightDeltaPreview':
        'Weight: last {prev} kg → new {next} kg (confirm)',
    'aiGrowthHeightDeltaPreview':
        'Height: last {prev} cm → new {next} cm (confirm)',
    'aiClarifyFeedingType': 'breast or bottle?',
    'aiClarifyDiaperKind': 'pee, poop, or both?',
    'aiClarifyBreastSideOptions':
        'Which side was used more?\n• Left\n• Right\n• Both',
    'aiClarifyDiaperKindOptions':
        'What kind of diaper change was it?\n• Pee\n• Poop\n• Both',
    'aiClarifyFeedingTypeOptions':
        'How was the feeding?\n• Breast\n• Bottle\n• Formula',
    'aiClarifyBottleAmount': 'How many ml?',
    'aiClarifySleepStart': 'When did sleep start?',
    'aiClarifyVaccineName': 'What is the vaccine name?',
    'aiClarifyVaccineDate': 'What is the vaccine date?',
    'aiClarifyAppointmentReason': 'Which specialty or reason?',
    'aiClarifyAppointmentWhen': 'When is the appointment (date and time)?',
    'aiClarifyAppointmentAddress':
        'What is the clinic address? Send it here and I will add it to the record.',
    'aiClarifySymptomDetails': 'Which symptoms or temperature should I log?',
    'aiClarifyFeverTemperature':
        'What is the temperature now, in degrees? (e.g. 38.5)',
    'aiActionFirstNeedData':
        'I found {n} record(s) but still need details.',
    'aiActionFirstFoundIntro': 'Got it 😊',
    'aiActionFirstSummarySingle': 'I found:',
    'aiActionFirstSummaryHeader': 'I found:',
    'aiActionFirstFirstQuestionLead': 'First:',
    'aiActionFirstNextQuestionLead': 'Now:',
    'aiOrchestratorFinishSleepAndDiaper':
        '🤖 I can end the active sleep ({duration}) and log {diaper}. Save now?',
    'aiOrchestratorFinishSleepOnly':
        '🤖 I can end the active sleep ({duration}) and log that they woke up. Save now?',
    'aiOrchestratorFinishSleepWithStartedAt':
        '🤖 There is an active sleep since {startedAt}. End it with total duration {duration}?',
    'aiOrchestratorFinishBreastfeeding':
        '🤖 I can finish the {side} breast feeding ({duration}). Save now?',
    'aiOrchestratorDiaperBoth': 'pee and poop',
    'aiOrchestratorDiaperPee': 'pee',
    'aiOrchestratorDiaperPoo': 'poop',
    'aiActionFirstNeedDataIntro': 'I need to complete a few details now.',
    'aiActionFirstAllComplete': 'All set 😊\nThe records are complete.',
    'aiActionFirstConfirmCard':
        'I organized {n} record(s). Review the card and tap confirm to save.',
    'aiRecordCardFeedingDetected': 'Breastfeeding detected',
    'aiRecordCardDiaperDetected': 'Diaper detected',
    'aiRecordCardSleepDetected': 'Sleep detected',
    'aiRecordCardSymptomDetected': 'Symptom detected',
    'aiRecordCardWeightDetected': 'Weight detected',
    'aiRecordCardHeightDetected': 'Height detected',
    'aiRecordCardVaccineDetected': 'Vaccine detected',
    'aiRecordCardAppointmentDetected': 'Appointment detected',
    'aiRecordFieldMethod': 'Method',
    'aiRecordFieldSide': 'Side',
    'aiRecordFieldType': 'Type',
    'aiRecordFieldTime': 'Time',
    'aiRecordFieldDuration': 'Duration',
    'aiRecordFieldAmount': 'Amount',
    'aiRecordFieldMissing': 'missing',
    'aiRecordFieldNow': 'now (editable)',
    'aiRecordFieldAction': 'Action',
    'aiRecordFieldTemperature': 'Temperature',
    'aiRecordFieldSymptoms': 'Symptoms',
    'aiRecordFieldValue': 'Value',
    'aiRecordFieldName': 'Name',
    'aiRecordFieldStatus': 'Status',
    'aiRecordFieldDate': 'Date',
    'aiRecordFieldReason': 'Reason',
    'aiRecordFeedingBreast': 'breastfeeding',
    'aiRecordFeedingBottle': 'bottle',
    'aiRecordFeedingFormula': 'formula',
    'aiRecordFeedingExpressed': 'expressed milk',
    'aiRecordSideLeft': 'left',
    'aiRecordSideRight': 'right',
    'aiRecordSideBoth': 'both',
    'aiPhaseTranscribing': 'Transcribing audio...',
    'aiPhaseUnderstandingRecords': 'Understanding records...',
    'aiPhaseUnderstanding': 'Understanding your message...',
    'aiVoiceTranscriptionFailed':
        'Could not transcribe the audio. Please try recording again.',
    'aiPhaseIdentifying': 'Identifying records...',
    'aiPhasePreparing': 'Preparing confirmation...',
    'aiPhaseSlowWarning': 'Still processing...',
    'aiPhaseVerySlow':
        'This is taking longer than usual, but I am still processing...',
    'aiPhaseShowingResults': 'Almost ready...',
    'aiExtractionFallbackHint':
        'I could not understand everything. Please review the data below.',
    'aiConfirmNeedInfoTitle': 'I need a few details before saving',
    'aiConfirmAndSaveRecords': 'Confirm and save records',
    'aiConfirmReadyToSaveVoice':
        'All set, I can save the records now. Would you like to confirm?',
    'aiCardUnderstood': 'Understood:',
    'aiCardMissing': 'Missing:',
    'aiBadgeComplete': 'Complete',
    'aiBadgeMissingInfo': 'Missing information',
    'aiBadgeIncomplete': 'Incomplete',
    'aiRecordLabelBreastfeeding': 'Breastfeeding',
    'aiRecordLabelBottle': 'Bottle feeding',
    'aiRecordLabelFeeding': 'Feeding',
    'aiRecordLabelDiaper': 'Diaper',
    'aiRecordLabelSleep': 'Sleep',
    'aiRecordLabelSymptom': 'Symptom',
    'aiRecordLabelGrowth': 'Growth',
    'aiRecordLabelVaccine': 'Vaccine',
    'aiRecordLabelAppointment': 'Appointment',
    'aiRecordLabelMemory': 'Memory',
    'aiConfirmCompleteToSaveHint': 'Complete the details to save',
    'aiPendingSessionCancelled': 'Okay, I cancelled the pending records.',
    'aiPendingRepeatQuestionIntro': 'I still need to know:',
    'aiPendingAnswerRecorded': 'Got it.',
    'aiPendingAnswerAck': 'Perfect.',
    'aiPendingFinishInSheet': 'Open the records card to continue.',
    'aiPendingMustFinishRecords':
        'Before we continue, I need to finish these records.',
    'aiPendingStateRetry': 'Can you tell me again what you want to log?',
    'aiPendingRecordsIntroSingle': '🤖 I still have 1 pending record:',
    'aiPendingRecordsIntroPlural': '🤖 I still have {n} pending records:',
    'aiPendingMissingFieldsLine': 'Still need: {fields}.',
    'aiPendingGrowthMissingBaseline':
        'I need the last recorded weight to calculate the new value.',
    'aiPendingGrowthStatusDelta': 'Growth: gained {grams}g.',
    'aiPendingGrowthStatusHeightDelta': 'Growth: +{cm} cm.',
    'aiPendingVaccineScheduledStatus': 'Vaccine scheduled for {when}.',
    'aiPendingVaccineNamedStatus': 'Vaccine {name} ({when}).',
    'aiPendingVaccineAskNameWithWhen':
        '🤖 Got it. Vaccine for {when}. What is the vaccine name?',
    'aiPendingGrowthNeedLastWeight':
        '🤖 Got it — gained {grams}g. What was the last recorded weight?',
    'aiPendingGrowthWeightDeltaConfirm':
        '🤖 Last weight: {prev} kg. With +{grams}g, the new weight will be {next} kg. Save it?',
    'aiRecordWhenTomorrow': 'tomorrow',
    'aiRecordAtConnector': 'at',
    'aiPendingRequiredFieldCannotSkip':
        'This field is required. Please pick one of the options.',
    'aiFollowUpBreastSideQuestion': 'About feeding: which side was used?',
    'aiFollowUpDurationQuestion': 'How long did they feed?',
    'aiFollowUpBreastLeftDuration': 'How many minutes on the left breast?',
    'aiFollowUpBreastRightDuration': 'How many minutes on the right breast?',
    'aiPartialSaveSummaryHeader': '🤖 Here is what I found:',
    'aiPartialSaveLineSaved': '{detail}',
    'aiPartialSaveLineNeedsInfo': '{title}: I still need one detail',
    'aiPartialSaveLineBreastNeedsDuration':
        '{title}: I need minutes for the {side} breast',
    'aiPartialSaveRecordFailed': 'Could not save {title}: {reason}',
    'aiFollowUpDiaperTypeQuestion': 'About the diaper: pee, poop, or both?',
    'aiFollowUpSleepStatusQuestion':
        'About sleep:\nDid they fall asleep now or already wake up?',
    'aiFollowUpSleepDurationQuestion': 'How long did they sleep?',
    'aiSleepOptionFellAsleepNow': 'Fell asleep now',
    'aiSleepOptionAlreadyWoke': 'Already woke up',
    'aiDiaperOptionPee': 'Pee',
    'aiDiaperOptionPoo': 'Poop',
    'aiDiaperOptionBoth': 'Both',
    'aiClarifyDiaperChangeNow': 'was it a diaper change just now?',
    'aiRecordSaveFailed':
        '🤖 I could not save the record now. Please try again or log it manually.',
    'aiRecordConfirmedPrefix': 'Done — logged {line} for {name} at {time}.',
    'aiVaccineScheduledConfirmed':
        'Scheduled the {name} vaccine for {date} (see Next column).',
    'aiBreastfeedingSavedSuccess':
        '✅ Logged breastfeeding on the {side} breast for {minutes} minutes.',
    'aiBreastfeedingSaveFailed':
        "Couldn't save the feeding. Please try again.",
    'aiRecordLineDiaperPee': 'diaper (pee)',
    'aiRecordLineDiaperPoo': 'diaper (poop)',
    'aiRecordLineDiaperBoth': 'diaper (pee and poop)',
    'aiRecordLineDiaperGeneric': 'diaper change',
    'aiRecordLineFeeding': 'feeding',
    'aiRecordLineSleepStart': 'sleep start',
    'aiRecordLineSleepEnd': 'sleep end',
    'aiRecordLineSleep': 'sleep',
    'aiRecordLineWeight': 'weight',
    'aiRecordLineHeight': 'height',
    'aiRecordLineSymptom': 'symptom in Health',
    'aiRecordLineConsultation': 'the appointment ({title})',
    'aiRecordLineConsultationGeneric': 'the medical appointment',
    'aiRecordLineVaccine': 'the {name} vaccine',
    'aiRecordLineVaccineGeneric': 'the vaccine',
    'aiRecordLineGeneric': 'entry',
    'aiRoutineRegisterSkipped': 'OK, I will not log that event.',
    'aiVoiceSavedFeeding': 'Feeding logged.',
    'aiVoiceSleepStarted': 'Sleep started — check the Sleep screen or say "woke up" when done.',
    'aiChatSleepStartedConfirm':
        'Done! I logged that your baby is going to sleep now. Check Home or Sleep for the active session.',
    'aiChatSleepEndedConfirm':
        'Sleep ended and saved to the diary. Thanks for letting me know!',
    'aiChatRegisterSavedConfirm':
        'Saved to the app. Check Home or Records.',
    'aiVoiceSleepEnded': 'Sleep logged successfully.',
    'aiVoiceRecordFailed': 'Could not process the audio. Try again.',
    'aiVoiceNotARegisterTitle': 'This sounds like a question, not a log entry.',
    'aiVoiceRegisterHint':
        'To log by voice, say e.g. "Baby had 120 ml now" or "diaper change with pee". For questions, just speak — AI Nanny answers in chat.',
    'aiVoiceHoldMicHint': 'Hold the microphone to talk to AI Nanny.',
    'aiVoiceReleaseHint': 'Release to send…',
    'aiVoiceTapMicHint': 'Tap the microphone to record',
    'aiVoiceTapStopHint': 'Tap again to send audio',
    'aiVoiceRecordingHint': 'Recording… tap ■ to send',
    'aiVoiceListenReply': 'Listen',
    'aiTtsPreparing': 'Preparing audio...',
    'aiTtsPause': 'Pause',
    'aiTtsResume': 'Resume',
    'aiTtsRetry': 'Try again',
    'aiNannyAutoReadLabel': 'Read answers aloud',
    'aiNannyDeviceVoiceHint':
        'Natural voice unavailable — using phone voice. Check internet and update the app.',
    'aiNannyTtsFailed':
        'Could not play natural voice. Check volume, internet, and sign-in; tap «Listen» to try again.',
    'aiVoiceAskAiInstead': 'Ask AI Nanny',
    'aiVoiceHealthFieldsHint':
        'Fill in the fields below and tap Confirm to save under Health.',
    'aiVoiceHealthTempLabel': 'Temperature (°C)',
    'aiVoiceHealthVaccineNameLabel': 'Vaccine name',
    'aiVoiceHealthVaccineDoseLabel': 'Dose (optional)',
    'aiVoiceHealthVaccineNameRequired': 'Enter the vaccine name.',
    'aiBabyHistoryTitle': 'Baby history',
    'aiBabyHistorySubtitle':
        'Share important traits about your baby and routine so AI Nanny can personalize answers.',
    'aiBabyHistoryFieldLabel': 'Important history for AI',
    'aiBabyHistoryPlaceholder':
        'Example: premature birth, reflux, breastfeeding, wakes often at night, formula, allergies, or pediatric guidance.',
    'aiBabyHistoryDisclaimer':
        'This helps the AI respond better but does not replace medical advice.',
    'aiBabyHistorySave': 'Save history',
    'aiBabyHistoryClear': 'Clear history',
    'aiBabyHistorySaved': 'History saved successfully',
    'aiBabyHistoryCleared': 'History cleared',
    'aiBabyHistoryClearConfirmTitle': 'Clear history?',
    'aiBabyHistoryClearConfirmBody':
        'AI Nanny will stop using this information until you fill it in again.',
    'aiBabyHistoryLinkSubtitle': 'Personalize AI Nanny answers',
    'aiBabyHistoryCharCount': '{current} / {max} characters',
    'settingsAiBabyHistory': 'Baby history for AI Nanny',
    'familyTabTree': 'Family',
    'familyTabHoroscope': 'Horoscope',
    'familyTabHomily': 'Homily',
    'familyTabAiHistory': 'History',
    'familyHoroscopeDate': 'Horoscope for {date}',
    'familyHoroscopeGenerateToday': 'Generate today\'s horoscope',
    'familyHoroscopeRefresh': 'Refresh horoscope',
    'familyHoroscopeMother': 'Mom\'s horoscope',
    'familyHoroscopeFather': 'Dad\'s horoscope',
    'familyHoroscopeBaby': 'Baby\'s horoscope',
    'familyHoroscopeFamilyEnergy': 'Family energy today',
    'familyHoroscopeDailyAdvice': 'Family advice for today',
    'familyHoroscopeDisclaimer':
        'AI-generated content for family reflection and entertainment. Not professional advice.',
    'familyHoroscopeLoading': 'Generating today\'s family horoscope…',
    'familyHoroscopeOpenTabHint': 'Open this tab to see today\'s horoscope.',
    'aiBubbleHoroscopeReady':
        '✨ Today\'s family horoscope is ready! Tap below to read it in Family.',
    'aiBubbleHoroscopeOpenLink': 'View horoscope',
    'familyHomilyDate': 'Homily for {date}',
    'familyHomilyLoading': 'Preparing today\'s homily from the liturgical calendar…',
    'familyHomilyOpenTabHint': 'Open this tab to read today\'s Christian homily.',
    'familyHomilyLiturgicalDay': 'Liturgical season',
    'familyHomilyFeast': 'Feast or memorial',
    'familyHomilyGospel': 'Gospel of the day',
    'familyHomilyTitle': 'Homily of the day',
    'familyHomilyFamilyReflection': 'Family reflection',
    'familyHomilyDisclaimer':
        'AI-generated content based on the Catholic liturgical calendar for family reflection. Not a substitute for pastoral guidance.',
    'familyHomilyPremiumTitle': 'Daily AI homily',
    'familyHomilyPremiumBody':
        'Each day, receive a warm homily aligned with the Christian calendar for your family.',
    'aiBubbleHomilyReady':
        '✝️ Today\'s homily is ready! Tap below to read it in Family.',
    'aiBubbleHomilyOpenLink': 'View homily',
    'aiBubbleCuriosityTitle': 'Daily curiosity ✨',
    'aiBubbleDailyBriefTitle': 'AI Nanny · your day',
    'familyHomilyErrorGeneric':
        'Could not generate the homily right now. Please try again.',
    'familyHomilyErrorNotFound': 'Homily not found. Try generating again.',
    'familyHomilyErrorUnauthenticated': 'Sign in to generate the homily.',
    'familyHomilyErrorPermission': 'Daily homily is available on Premium.',
    'familyHomilyErrorPrecondition':
        'Complete your Family profile to generate the homily.',
    'familyHomilyErrorExhausted':
        'Too many attempts. Wait a few minutes and try again.',
    'familyHoroscopeRegisterFather':
        'Add dad\'s profile to include his horoscope in the family reading.',
    'familyHoroscopePremiumTitle': 'AI family horoscope',
    'familyHoroscopePremiumBody':
        'Unlock daily affectionate readings for mom, dad and baby based on zodiac signs.',
    'familyHoroscopeErrorGeneric':
        'Could not generate the horoscope now. Please try again.',
    'familyHoroscopeErrorNotFound':
        'Horoscope service unavailable. Update the app and try again.',
    'familyHoroscopeErrorUnauthenticated': 'Sign in to generate the horoscope.',
    'familyHoroscopeErrorPermission':
        'Full family horoscope is available on the Premium plan.',
    'familyHoroscopeErrorPrecondition':
        'Add birth dates in Family to generate the horoscope.',
    'familyHoroscopeErrorExhausted':
        'Temporary limit reached. Try again later.',
    'appUpdateAvailableMessage': 'A new FaceBaby version is available ❤️',
    'appUpdateDownloading': 'Downloading the update…',
    'appUpdateReadyToRestart': 'Restart to finish updating.',
    'appUpdateActionUpdate': 'Update',
    'appUpdateActionLater': 'Later',
    'appUpdateRestart': 'Restart',
    'growthHistoryTitle': '{label} (history)',
    'invalidGrowthValue': 'Enter a valid {label} value.',
    'growthSaved': '{label} saved successfully.',
    'growthEmpty': 'No {label} records yet.',
    'notifyGrowthWeightDownTitle': 'Weight lower than before',
    'notifyGrowthWeightDownBody':
        'The latest weight entry is below the previous one. When in doubt, contact your pediatrician.',
    'notifyGrowthWeightBelowTitle': 'Weight below the curve',
    'notifyGrowthWeightBelowBody':
        'Latest weight: {value} kg (healthy range: {min}–{max} kg). Verify the entry. For this type of alert, see a doctor or pediatrician.',
    'notifyGrowthWeightAboveTitle': 'Weight above the curve',
    'notifyGrowthWeightAboveBody':
        'Latest weight: {value} kg (healthy range: {min}–{max} kg). Verify the entry. For this type of alert, see a doctor or pediatrician.',
    'notifyGrowthHeightBelowTitle': 'Height below the curve',
    'notifyGrowthHeightBelowBody':
        'Latest height: {value} cm (healthy range: {min}–{max} cm). Verify the entry. For this type of alert, see a doctor or pediatrician.',
    'notifyGrowthHeightAboveTitle': 'Height above the curve',
    'notifyGrowthHeightAboveBody':
        'Latest height: {value} cm (healthy range: {min}–{max} cm). Verify the entry. For this type of alert, see a doctor or pediatrician.',
    'notifyGrowthStaleTitle': 'No growth log in a while',
    'notifyGrowthStaleBody':
        'It has been over 30 days since the last growth measurement (weight, height, or head). It has been {days} days — add a new entry.',
    'momNoteHint': 'E.g. slept better after bath...',
    'shortcutDiaper': 'Diaper',
    'diaperPagePlaceholder':
        'Soon you will be able to log diaper changes. This section is coming.',
    'shortcutHealth': 'Health',
    'shortcutHealthSubtitle': 'Vaccines & visits',
    'shortcutFamily': 'Family',
    'shortcutFamilyHomeSub': 'Family tree and profiles',
    'shortcutHealthHomeSub': 'Vaccines, visits and symptoms',
    'shortcutFeedingSession': 'Feeding',
    'shortcutFeedingSessionSub': 'Session timing & meals',
    'healthHubTitle': 'Health',
    'healthHubIntro': 'Vaccines, checkups and baby care in one place.',
    'healthHubSection': 'Quick access',
    'healthHubVaccines': 'Vaccine record',
    'healthHubVaccinesSub': 'Log and review your baby’s vaccines',
    'vaccineReminderNotifTitle': 'Vaccine',
    'vaccineReminderNotifBody': 'Vaccine due today: {name}.',
    'homeBannerChipVaccine': 'Vaccine today',
    'vaccDueConfirmCheckbox': 'I confirm this dose has been given.',
    'vaccDueSavedOk': 'Vaccine marked as administered.',
    'vaccDuePickTitle': 'Vaccines due today',
    'healthHubConsultations': 'Checkups',
    'healthHubConsultationsSub': 'Pediatrician and follow-ups',
    'healthHubSymptomReports': 'Report symptom',
    'healthHubSymptomReportsSub':
        'Fever, colic, medications and more — included in the pediatric report',
    'symptomReportTitle': 'Report symptom',
    'symptomReportEmpty': 'No entries yet. Tap + to add one.',
    'symptomReportNew': 'New entry',
    'symptomReportSave': 'Save',
    'symptomReportOccurredAt': 'Date & time',
    'symptomReportPickDateTime': 'Change date & time',
    'symptomReportMedication': 'Medications taken',
    'symptomReportMedicationHint': 'Name or short note',
    'symptomReportFever': 'Fever',
    'symptomReportTemp': 'Temperature',
    'symptomReportTempHint': 'Uses your preferred units from Settings',
    'symptomReportCrying': 'Unexplained crying',
    'symptomReportPain': 'Pain',
    'symptomReportColic': 'Colic',
    'symptomReportReflux': 'Reflux',
    'symptomReportOther': 'Other',
    'symptomReportOtherHint': 'Short description',
    'symptomReportValidationNeedOne':
        'Select at least one symptom or fill a field.',
    'symptomReportValidationFeverTemp':
        'Enter temperature when fever is checked.',
    'symptomReportDeleteTitle': 'Delete entry?',
    'symptomReportDeleteBody': 'This cannot be undone.',
    'consultationsTitle': 'Checkups',
    'consultationsIntro':
        'Log visits with date and time; they show in the Home day summary.',
    'consultationsSoonTitle': 'Coming soon',
    'consultationsComingBody':
        'Soon you will be able to log visits, attach notes and return reminders.',
    'homeSummaryHealthStripTitle': 'Vaccines and checkups this day',
    'homeSummaryHealthStripEmpty':
        'No vaccines or checkups logged for this day.',
    'consultationTitleLabel': 'Reason or specialty',
    'consultationNotesHint': 'Notes (optional)',
    'consultationWhenLabel': 'Date and time',
    'consultationTitleEmpty': 'Enter the reason or specialty for this visit.',
    'consultationPhoneLabel': 'Clinic phone',
    'consultationAddressLabel': 'Address',
    'consultationDetailWhen': 'When',
    'consultationDetailPhone': 'Phone',
    'consultationDetailAddress': 'Address',
    'consultationDetailNotes': 'Notes',
    'consultationReminderNotifTitle': 'Upcoming checkup',
    'consultationReminderNotifBody': 'Tomorrow · {title} · {when}',
    'consultationTodayReminderNotifBody': 'Today · {title} · {when}',
    'homeConsultationBannerChip': 'Checkup · {title} · {t}',
    'consultationsEmpty': 'No checkups logged yet.',
    'consultationsDayEmpty': 'No checkups on this day.',
    'feedingSessionTitle': 'Feeding session',
    'feedingSessionIntro':
        'The Home shortcut appears from 7 months or if you enable it in More.',
    'feedingSessionSoonTitle': 'Next steps',
    'feedingSessionSoonBody':
        'Meal ideas, photos and daily summaries will live here. For now use Records and your pediatrician’s plan.',
    'settingsFeedingEarlyTitle': 'Solids shortcut before 7 months',
    'settingsFeedingEarlySub':
        'Shows the “Solids” shortcut on Home even if your baby is under 7 months.',
    'settingsAiMicTitle': 'Voice assistant (microphone)',
    'settingsAiMicSub':
        'Shows the microphone button on Home (work in progress).',
    'reportNoWeight': 'No weight data yet.',
    'reportNoHeight': 'No height data yet.',
    'memoriesPhotoError': 'Could not select the photo.',
    'memoriesTodayTitle': "Today's memories",
    'memoriesTodayAsk': 'Have you added your photo for today?',
    'memoriesNotYet': 'Not yet',
    'memoriesAddPhotoDialog': 'Add photo',
    'memoriesAlreadyPostedToday': "You've already added today's photo.",
    'memoriesWallEmpty':
        'Your wall is still empty. Add the first photo of the day!',
    'memoriesHighlights': 'Highlights',
    'memoriesWallSection': 'Wall',
    'settingsMotherProfile': 'My profile',
    'profileEditMother': 'Edit mother\'s details',
    'profileEditFather': 'Edit father\'s details',
    'profileAddFather': 'Register dad',
    'profileFatherNotRegisteredTitle': 'Dad not registered yet',
    'profileFatherNotRegisteredSubtitle':
        'If you skipped dad during signup, you can add his details here anytime.',
    'profileFatherAddCta': 'Register dad now',
    'profileEditBaby': 'Edit baby\'s details',
    'profileDataSaved': 'Saved.',
    'profileEditData': 'Edit details',
    'contactTitle': 'Contact',
    'contactIntro':
        'Send a message by email. We will open your email app with the fields filled in.',
    'contactFieldName': 'Name',
    'contactFieldEmail': 'Email',
    'contactFieldAge': 'Age',
    'contactFieldMessage': 'Message',
    'contactSend': 'Send',
    'contactEmailSubject': 'App contact',
    'contactBodyName': 'Name:',
    'contactBodyEmail': 'Email:',
    'contactBodyAge': 'Age:',
    'contactBodyMessage': 'Message:',
    'contactCouldNotOpenEmail': 'Could not open the email app.',
    'contactValidationRequired': 'Required field.',
    'contactValidationEmail': 'Enter a valid email.',
    'contactValidationAge': 'Enter a valid age.',
    'motherProfileTabPreferences': 'Preferences',
    'motherProfileTabMother': 'Mom',
    'motherProfileTabFather': 'Dad',
    'motherProfileTabBabies': 'Babies',
    'profileLayoutTitle': 'App layout',
    'profileLayoutSubtitle':
        'Day, night, or automatic based on the time of day.',
    'profileLayoutAutomatic': 'Automatic',
    'profileLayoutDay': 'Day',
    'profileLayoutNight': 'Night',
    'profileLayoutUpdating': 'Updating layout…',
    'motherProfileFieldFatherName': 'Name',
    'motherProfileNoData': 'No profile found. Please try again in a moment.',
    'motherProfileSectionInfo': 'Info',
    'motherProfileFieldPhone': 'Phone',
    'motherProfileFieldBirth': 'Birth date',
    'motherProfileFieldHeight': 'Height',
    'motherProfileFieldFatherHeight': "Father's height",
    'profileFamilyMessagesTitle': 'Messages on Family screen',
    'profileShowChristian': 'Christian',
    'profileShowHoroscope': 'Astrological',
    'profileShowPhilosophical': 'Philosophical / Ecumenical',
    'profileShowSpiritist': 'Spiritist messages',
    'profileShowJewish': 'Jewish messages',
    'motherProfileAddBaby': 'Add another baby',
    'motherProfileNoBabies': 'No babies found for this profile.',
    'motherProfileBabyBornAt': 'Born: {date}',
    'settingsBabyData': "Baby's data",
    'settingsAlerts': 'Alerts',
    'alertsScreenIntro':
        'How each reminder works. You can change these switches here or on the feeding, diaper, sleep, and growth/health screens.',
    'alertsExactAlarmAndroidTitle': 'On-time alerts (Android)',
    'alertsExactAlarmAndroidBody':
        'To get feeding reminders at the scheduled time, allow FaceBaby to use exact alarms / “Alarms & reminders” in system settings. Without this, Android may delay or skip the notification.',
    'alertsExactAlarmAndroidOpenSettings': 'Open settings',
    'alertsSectionFeeding': 'Feeding',
    'alertsRuleFeeding':
        'When enabled, the app schedules a local notification after the minutes you set below, counting from the end of the latest breast or bottle log in the database. Logging a new feed restarts the timer from that time.',
    'alertsSectionDiaper': 'Diaper',
    'alertsRuleDiaper':
        'The app suggests a reminder about 3 hours 30 minutes after the last logged change. Saving a new change cancels and reschedules. System notification permission still applies.',
    'alertsSectionSleep': 'Sleep',
    'alertsRuleSleep':
        'Using the last logged sleep end time and your baby’s age in months (birth date on the profile), the app can schedule up to two reminders when alerts are on: one shortly before the typical awake window ends, and one when that window may already be passed. Logging a new sleep updates the schedule.',
    'alertsSectionGrowth': 'Growth & measurements',
    'alertsRuleGrowth':
        'Notifies when the newest weight is below the previous weight entry (by measurement date). Also warns when more than 30 days pass without any weight, height, or head circumference saved in the app.',
    'alertsTestTitle': 'Test notifications',
    'alertsTestBody':
        'Sends one notification now and schedules another for 30 seconds from now. Useful to confirm the system is delivering app notifications.',
    'alertsTestRun': 'Run test',
    'alertsTestResync': 'Force reschedule (real reminders)',
    'alertsTestImmediateTitle': 'FaceBaby — immediate test',
    'alertsTestImmediateBody':
        'If you see this message, the immediate channel is OK.',
    'alertsTestScheduledTitle': 'FaceBaby — scheduled test',
    'alertsTestScheduledBody': 'This was scheduled with AlarmManager (~30s).',
    'alertsTestAllScheduleModesFailed': 'AlarmManager rejected every mode',
    'alertsTestSentOk': 'Sent. You should receive one now and another in ~30s.',
    'alertsTestFailed': 'Failed: {errors}',
    'sleepToggleAlertsSubtitle':
        'Reminders based on last sleep ended and baby’s age.',
    'sleepAlertsWakeWindowRulerValueAuto':
        'Effective value on this ruler: {m} min (automatic by age).',
    'sleepAlertsWakeWindowRulerValueCustom':
        'Value on this ruler: {m} min (custom).',
    'sleepAlertsWakeWindowSliderLabelAuto': '{m} min · auto',
    'sleepAlertsWakeWindowSliderLabelCustom': '{m} min',
    'sleepAlertsApproachRulerValueDefault':
        'Lead time on this ruler: {m} min (default).',
    'sleepAlertsApproachRulerValueCustom': 'Lead time on this ruler: {m} min.',
    'sleepAlertsApproachSliderLabelDefault': '{m} min · default',
    'sleepAlertsApproachSliderLabelCustom': '{m} min',
    'sleepAlertsWakeWindowAutomatic':
        'Awake-window limit for the alert: {m} min (automatic from age table).',
    'sleepAlertsWakeWindowAutomaticNoBirth':
        'Add your baby’s birth date in Profile for accurate timing; for now using a fallback of {m} min.',
    'sleepAlertsMonthsApprox': 'Age table bracket: ~{n} mo',
    'sleepAlertsWakeWindowCustom': 'Custom awake-window limit: {m} min.',
    'sleepAlertsApproachAuto':
        'Reminder before limit: default {m} min lead time.',
    'sleepAlertsApproachCustom':
        'Reminder before limit: custom {m} min lead time.',
    'settingsPrivacy': 'Privacy',
    'settingsSaaS': 'Future SaaS plan',
    'loadingMotherPhoto': "Updating mom's photo…",
    'loadingBabyPhoto': "Updating baby's photo…",
    'loadingBabies': 'Loading babies…',
    'gateLoadProfilesError':
        'Could not read saved data. It may still be on this device — try again before re-registering.',
    'gateRetry': 'Try again',
    'pickBabyTitle': 'Select baby',
    'switchingBaby': 'Switching baby…',
    'sleepAppBar': 'Sleep',
    'sleepTitle': 'Sleep',
    'sleepIntro': 'Log and track naps and night sleep.',
    'sleepComingTitle': 'Coming soon',
    'sleepComingBody':
        'This screen is ready for sleep logging.\nNext we will connect the database and show last sleep, daily total and history.',
    'sleepSessionTitle': 'Sleep in progress',
    'sleepSessionStartedAt': 'Started at {time}',
    'sleepStatusSleeping': 'Sleeping',
    'sleepStatusPaused': 'Paused',
    'sleepWakeButton': 'WOKE UP?',
    'sleepThisCardTitle': 'This sleep',
    'sleepLabelStart': 'Start',
    'sleepLabelEnd': 'End',
    'sleepLabelDuration': 'Duration',
    'sleepLabelQuality': 'Quality',
    'sleepObservationsTitle': 'Notes',
    'sleepObservationHint': 'Add a note…',
    'sleepPause': 'Pause',
    'sleepResume': 'Resume',
    'sleepCancelSession': 'Cancel sleep',
    'sleepStartButton': 'START SLEEP',
    'sleepSavedOk': 'Sleep saved.',
    'sleepResultDialogTitle': 'Sleep status',
    'sleepResultShortTitle': 'Slept less than expected',
    'sleepResultExpectedTitle': 'Sleep within expected range',
    'sleepResultLongTitle': 'Slept more than expected',
    'sleepResultDurationLine': 'Logged duration: {duration}.',
    'sleepResultExpectedLine': 'Age reference: about {min}–{max} min.',
    'sleepResultShortBody':
        'This was a short sleep. Watch for tired cues and try a calm setup for the next rest.',
    'sleepResultExpectedBody':
        'Good rest window. This sleep was close to what is expected for this age.',
    'sleepResultLongBody':
        'This was a longer sleep. It may be catching up from tiredness; keep an eye on it if it happens often.',
    'sleepConfirmBackTitle': 'Leave sleep tracking?',
    'sleepConfirmBackBody': 'This session is not saved yet. Discard it?',
    'sleepConfirmCancelSessionTitle': 'Cancel sleep?',
    'sleepConfirmCancelSessionBody':
        'Time recorded in this session will be lost.',
    'sleepDiscard': 'Discard',
    'sleepHistoryTitle': 'Sleep history',
    'sleepHistoryEmpty': 'No sleep sessions yet.',
    'historyShowButton': 'View history',
    'historyHideButton': 'Hide history',
    'historyViewMoreButton': 'View more',
    'sleepUpdatedOk': 'Sleep updated.',
    'sleepBannerNextNap': 'Next nap in ~{min} min',
    'sleepWindowTitle': 'Current sleep window',
    'sleepWindowEarly': 'Before ideal window',
    'sleepWindowIdeal': 'Ideal',
    'sleepWindowLate': 'Overdue',
    'sleepRoutineLastLabel': 'Last sleep: {ago}',
    'sleepRoutineLastNever': 'Last sleep: no logs yet',
    'sleepRoutineNextPrefix': 'Next nap:',
    'sleepNextApproxMin': 'in ~{min} min',
    'sleepRoutineNextNow': 'now — good time to try',
    'sleepStatusEarly': '🟡 Before ideal window',
    'sleepStatusIdeal': '🟢 Ideal window',
    'sleepStatusOverdue': '🔴 Likely overtired',
    'sleepHeroAwakeBadge': 'Awake',
    'sleepHeroAwakeCaption':
        'The green → yellow → red bar shows how long she has been awake and when a nap is usually due. When she lies down to sleep, tap START SLEEP.',
    'sleepHeroSleepingBadge': 'Sleeping',
    'sleepHeroSleepingCaption':
        'When she wakes up, tap End sleep to save this session.',
    'sleepRoutineCardTitle': 'Next sleep',
    'sleepRoutineVigilHighlight':
        'App awake-time window: {min}–{max} min between sleeps (fixed by age in months — not configurable).',
    'sleepRoutineStatusLine': 'Status: {status}',
    'sleepIdealForAge': 'Same table (by age)',
    'sleepAgeMonthsLabel': '{n} months old',
    'sleepWindowMinMax': '{min}–{max} min',
    'sleepLegendG': '🟢 ideal window',
    'sleepLegendY': '🟡 before ideal window',
    'sleepLegendR': '🔴 past the mark',
    'sleepWakeWindowExplainer':
        'Shows how long your baby has been awake since the last sleep ended (not how long they slept). Yellow: not yet in the typical window for the next nap — it does not mean they woke “too early”.',
    'sleepFinalizeButton': 'END',
    'sleepSleepingFor': 'Sleeping for {when}',
    'sleepInsightTitle': 'Today’s summary',
    'sleepInsightNaps': 'Today: {n} naps',
    'sleepInsightAvg': 'Average: {min} min',
    'sleepInsightTrendDown': '💡 Less sleep than usual today',
    'sleepInsightTrendOk': '💡 Sleep pattern steady today',
    'sleepHistoryToday': 'Today',
    'sleepToggleAlerts': 'Enable sleep reminders',
    'diaperToggleAlerts': 'Diaper reminders',
    'diaperToggleAlertsSubtitle':
        'Get notified around the suggested next change.',
    'healthGrowthToggleAlerts': 'Growth alerts',
    'healthGrowthToggleAlertsSubtitle':
        'Weight-loss vs. last log and overdue measurements.',
    'feedingScreenAlertsHint': 'To change timing, open More › Alerts.',
    'sleepNotifTitle': 'Sleep',
    'sleepNotifBeforeBody':
        'It may be a good time to help baby settle to sleep.',
    'sleepNotifOverdueBody':
        'Your baby may be tired — try starting sleep gently.',
    'sleepNotifWakeOverdueBodyMale':
        'It has been more than {hours} h since he fell asleep. Check on him, Mom.',
    'sleepNotifWakeOverdueBodyFemale':
        'It has been more than {hours} h since she fell asleep. Check on her, Mom.',
    'notifChannelRemindersName': 'Reminders',
    'notifChannelRemindersDesc':
        'Alerts for feeding, diapers, sleep, visits, and vaccines.',
    'notifChannelGrowthName': 'Growth',
    'notifChannelGrowthDesc':
        'Weight alerts and long gaps between measurements.',
    'diaperIntro':
        'Log a change to keep reminders working. In the list below you can edit or delete any entry.',
    'diaperSavedOk': 'Change saved.',
    'diaperUpdatedOk': 'Change updated.',
    'diaperHistoryTitle': 'History',
    'diaperHistoryEmpty': 'No diaper logs yet.',
    'diaperKindPee': 'Pee',
    'diaperKindPoo': 'Poop',
    'diaperKindBoth': 'Pee & poop',
    'diaperKindLabel': 'Type',
    'diaperDashTitle': 'Latest logs',
    'diaperDashLastPee': 'Last pee',
    'diaperDashLastPoo': 'Last poop',
    'diaperDashNoRecordYet': 'None yet',
    'diaperDashJustNow': 'Just now',
    'diaperDashAgoLine': '{ago}\u00A0ago',
    'diaperChangedAtLabel': 'Date & time',
    'diaperNoteOptional': 'Note (optional)',
    'feedingTitle': 'Feeding',
    'feedingSelectBabyFirst': 'Select a baby before starting.',
    'feedingNoRunning': 'Could not finish: no feeding in progress.',
    'feedingSavedOk': 'Feeding saved.',
    'feedingSaveFail': 'Could not save:',
    'feedingSaving': 'Saving feeding…',
    'feedingQuickSummary': 'Quick summary',
    'feedingNoBabyHint':
        'Register a baby first in "More > Register (mom & babies)".',
    'feedingPickBabyLabel': 'Select baby',
    'feedingEmptyDataHint':
        'No data yet. Use "Start feeding" to log with one tap.',
    'feedingLast': 'Last feeding',
    'feedingNextEst': 'Next estimate',
    'feedingNextIn': 'in ~{n} min',
    'feedingStatusOk': 'OK',
    'feedingStatusLate': 'Overdue',
    'feedingStatusWarn': 'Attention',
    'feedingFinish': 'Finish feeding',
    'feedingStart': 'Start feeding',
    'feedingAfterFinish': 'Log (after finishing)',
    'feedingTypeBreast': 'Breast',
    'feedingTypeBottle': 'Bottle',
    'feedingTypeSolid': 'Solids',
    'feedingTypeLabel': 'Type',
    'feedingTabBreastfeeding': 'Breastfeeding',
    'feedingTabBottle': 'Bottle',
    'feedingTabSolids': 'Solids',
    'feedingHubTapSidesHint':
        'Tap L or R to start the timer. Tap again on the same side to save.',
    'feedingHubLetterLeft': 'L',
    'feedingHubLetterRight': 'R',
    'feedingHubAddManualEntry': 'Add manual entry',
    'feedingHubOverviewTitle': 'Records overview',
    'feedingHubManualTitle': 'Manual entry (breast)',
    'feedingHubManualMinutes': 'Duration (minutes)',
    'feedingHubManualInvalid': 'Enter a duration greater than zero.',
    'feedingHubSaveBottle': 'Log bottle',
    'feedingHubSaveSolid': 'Log meal',
    'feedingHubSolidDescribe': 'What was offered?',
    'feedingHubSolidRequired': 'Describe what was offered before saving.',
    'feedingHubOverviewEmpty': 'No entries in this list yet.',
    'feedingHubMlRequired': 'Enter amount in ml.',
    'memoryDeleteBadgeTitle': 'Delete memory',
    'memoryDeleteBadgeBody':
        'This badge will be available again for a new entry. Delete?',
    'feedingHubTimerTooShort':
        'Keep the timer running a few seconds before saving this feeding.',
    'feedingHubBreastPieTitle': 'Which side is used more?',
    'feedingHubBreastPieEmpty': 'Log a few (L/R) feedings to see the chart.',
    'feedingHubFeedingUpdatedOk': 'Entry updated.',
    'feedingSideLeft': 'Left',
    'feedingSideRight': 'Right',
    'feedingSideBoth': 'Both',
    'feedingSideLabel': 'Side',
    'feedingQty': 'Amount',
    'feedingQtyMl': 'Amount (ml) (optional)',
    'feedingNote': 'Note (optional)',
    'feedingHintRunning': 'Finish to save.',
    'feedingHintIdle': 'Ready to log the next feeding with one tap.',
    'feedingHistory': 'History',
    'feedingNoRecords': 'No records yet.',
    'feedingHistoryLine': '{time} min • {side}',
    'feedingInsights': 'Insights',
    'feedingInsightsNeed': 'Log at least 2 feedings to see patterns.',
    'feedingAvgDurFmt': 'Average duration: {m} min',
    'feedingAvgIntervalFmt': 'Average interval: {h}h{m}',
    'feedingAlertSection': 'Alert (optional)',
    'feedingAlertTitle': 'Enable next-feeding alert',
    'feedingModeAvg': 'Auto average',
    'feedingModeManual': 'Manual interval',
    'feedingNotifyNote':
        'Note: for now this is visual only. Notifications will come later.',
    'feedingAgoMinutes': '{m} min ago',
    'feedingAgoHours': '{h}h{m} ago',
    'feedingDurationShort': '{m}m {s}s',
    'feedingDurationSeconds': '{s}s',
    'vaccAddTitle': 'Add vaccine',
    'vaccNameField': 'Vaccine',
    'vaccDoseOpt': 'Dose (optional)',
    'vaccDoseHint': 'E.g. 1st dose / booster',
    'vaccApplied': 'Applied:',
    'vaccNext': 'Next:',
    'vaccNotesOpt': 'Notes (optional)',
    'vaccNameEmpty': 'Enter the vaccine name.',
    'vaccSaving': 'Saving vaccine…',
    'vaccUpdatedOk': 'Vaccine updated.',
    'vaccNoBabies':
        'No baby registered yet. Go to "More > Register (mom & baby)".',
    'vaccTableVac': 'Vaccine',
    'vaccTableDose': 'Dose',
    'vaccTableDate': 'Date',
    'vaccTableNext': 'Next',
    'vaccTableNotes': 'Notes',
    'commonCouldNotSave': 'Could not save:',
    'commonSaving': 'Saving...',
    'commonSave': 'Save',
    'commonSelect': 'Select',
    'commonBack': 'Back',
    'commonAdvance': 'Continue',
    'commonClose': 'Close',
    'commonName': 'Name',
    'commonPhone': 'Phone',
    'openingGallery': 'Opening gallery…',
    'devLeapsTitle': 'Development leaps',
    'devLeapsIntro':
        'Common development phases for {name}. The text is supportive and not alarmist.',
    'devLeapsNeedBirth':
        'To show phases by age, add the baby’s birth date in the profile.',
    'devLeapsAllTitle': 'All phases',
    'devLeapsCurrentPill': 'Now',
    'devLeapsSeeDetails': 'See phase details',
    'devLeapsWhatsHappening': 'What is happening',
    'devLeapsKeywords': 'Keywords',
    'devLeapsMayHappen': 'What may happen',
    'devLeapsHowToHelp': 'How to help',
    'devLeapsSkills': 'Possible skills',
    'devLeapsEmotionalLook': 'Emotional view',
    // Development leap banner (EN = fallback for langs without own map entry)
    'devLeap_dv01_range': 'Week 1',
    'devLeap_dv01_title': 'Early adjustment',
    'devLeap_dv01_lead':
        '{baby_name} may be having an intense adjustment to the new surroundings.',
    'devLeap_dv01_emotion': 'Everything is still very new.',
    'devLeap_dv02_range': 'Week 2',
    'devLeap_dv02_title': 'More alert',
    'devLeap_dv02_lead':
        '{baby_name} may be starting to notice voices and faces a little better.',
    'devLeap_dv02_emotion': 'The emotional bond keeps growing.',
    'devLeap_dv03_range': 'Week 3',
    'devLeap_dv03_title': 'More sensitive',
    'devLeap_dv03_lead':
        '{baby_name} may be more sensitive to the environment around them.',
    'devLeap_dv03_emotion': 'The brain is maturing quickly.',
    'devLeap_dv04_range': 'Week 4',
    'devLeap_dv04_title': 'Small interactions',
    'devLeap_dv04_lead': '{baby_name} may be beginning to interact a bit more.',
    'devLeap_dv04_emotion': 'Your baby starts building social connections.',
    'devLeap_dv05_range': 'Week 5',
    'devLeap_dv05_title': 'New discoveries',
    'devLeap_dv05_lead':
        '{baby_name} may be noticing more of their own movements.',
    'devLeap_dv05_emotion': 'Their body starts to gain meaning.',
    'devLeap_dv06_range': 'Week 6',
    'devLeap_dv06_title': 'More connected',
    'devLeap_dv06_lead':
        '{baby_name} may be more tuned in to people\'s emotions.',
    'devLeap_dv06_emotion': 'The emotional bond keeps strengthening.',
    'devLeap_dv07_range': 'Weeks 7–8',
    'devLeap_dv07_title': 'Changing sleep',
    'devLeap_dv07_lead':
        '{baby_name} may be going through important sleep shifts.',
    'devLeap_dv07_emotion': 'The brain is maturing quickly.',
    'devLeap_dv08_range': '2–3 months',
    'devLeap_dv08_title': 'More awareness',
    'devLeap_dv08_lead':
        '{baby_name} may be noticing more of their body and the world around them.',
    'devLeap_dv08_emotion': 'Small discoveries happen every day.',
    'devLeap_dv09_range': '3–4 months',
    'devLeap_dv09_title': 'Much more social',
    'devLeap_dv09_lead': '{baby_name} may be much more social.',
    'devLeap_dv09_emotion': 'Social bonding grows fast.',
    'devLeap_dv10_range': '4–5 months',
    'devLeap_dv10_title': 'Exploring more',
    'devLeap_dv10_lead': '{baby_name} may be much more curious.',
    'devLeap_dv10_emotion': 'Learning happens through experience.',
    'devLeap_dv11_range': '5–6 months',
    'devLeap_dv11_title': 'More communication',
    'devLeap_dv11_lead': '{baby_name} may be trying to interact more and more.',
    'devLeap_dv11_emotion': 'Communication is starting to take off.',
    'devLeap_dv12_range': '6–7 months',
    'devLeap_dv12_title': 'A bigger world',
    'devLeap_dv12_lead':
        '{baby_name} may be understanding space and the environment better.',
    'devLeap_dv12_emotion': 'The world feels bigger each day.',
    'devLeap_dv13_range': '7–8 months',
    'devLeap_dv13_title': 'More attachment',
    'devLeap_dv13_lead':
        '{baby_name} may be in a phase of greater emotional need.',
    'devLeap_dv13_emotion': 'The emotional bond strengthens.',
    'devLeap_dv14_range': '8–9 months',
    'devLeap_dv14_title': 'Many connections',
    'devLeap_dv14_lead': '{baby_name} may be wiring new connections quickly.',
    'devLeap_dv14_emotion': 'The brain is very active.',
    'devLeap_dv15_range': '9–10 months',
    'devLeap_dv15_title': 'On the move',
    'devLeap_dv15_lead': '{baby_name} may be in a very active moving phase.',
    'devLeap_dv15_emotion': 'Body and brain work together here.',
    'devLeap_dv16_range': '10–11 months',
    'devLeap_dv16_title': 'Trying to communicate',
    'devLeap_dv16_lead': '{baby_name} may be watching and imitating much more.',
    'devLeap_dv16_emotion': 'Communication is growing stronger.',
    'devLeap_dv17_range': '11–12 months',
    'devLeap_dv17_title': 'More independence',
    'devLeap_dv17_lead': '{baby_name} may be trying to do more things alone.',
    'devLeap_dv17_emotion': 'Independence is starting to show.',
    'devLeap_dv18_range': '12–18 months',
    'devLeap_dv18_title': 'Big feelings',
    'devLeap_dv18_lead': '{baby_name} may be feeling emotions more intensely.',
    'devLeap_dv18_emotion': 'The emotional world grows fast.',
    'devLeap_dv19_range': '18–24 months',
    'devLeap_dv19_title': 'Pretend play',
    'devLeap_dv19_lead':
        '{baby_name} may be entering a phase of vivid imagination.',
    'devLeap_dv19_emotion': 'Imagination starts to bloom.',
    'devLeap_dv20_range': '2–3 years',
    'devLeap_dv20_title': 'A big personality',
    'devLeap_dv20_lead':
        '{baby_name} may be in a phase of strong independence and imagination.',
    'devLeap_dv20_emotion': 'Their sense of self grows quickly.',

    'devLeap_dv01_homeBullets':
        'wants lots of cuddling\nwakes frequently\nunsettled by sounds and lights\nneeds constant contact',
    'devLeap_dv01_detailWhats':
        'Your baby spent many months in a quiet, protected, cosy space. Now everything has changed — and the brain is still learning light, cold, hunger, sleep, touch, and sounds.',
    'devLeap_dv01_keywords':
        'adjustment\nbond\nsecurity\nsensitivity\nwelcoming calm',
    'devLeap_dv01_detailMay':
        'frequent crying\nfrequent wake-ups\nconstant need for cuddling\nirregular sleep\ngreater sensitivity',
    'devLeap_dv01_detailHelp':
        'skin-to-skin\ncalm voice\ndim light\nfewer stimuli\nsteady soothing',
    'devLeap_dv01_detailSkills':
        'notice caregiver scent\nreact to sounds\nprimitive reflexes',
    'devLeap_dv01_detailEmotional':
        'Your baby does not grasp routines yet. They understand presence, warmth, and safety.',
    'devLeap_dv02_homeBullets':
        'watches more\nrecognises voices\nattentive when held\nbegins tiny interactions',
    'devLeap_dv02_detailWhats':
        'Little by little babies notice faces, voices, scents, and emotional presence. Mom’s voice usually brings comfort and predictability.',
    'devLeap_dv02_keywords':
        'recognition\nconnection\ncomfort\npresence\nobservation',
    'devLeap_dv02_detailMay':
        'more watching\nlonger awake periods\nreaction to voice\ncalm in arms',
    'devLeap_dv02_detailHelp':
        'talk eye-to-eye\nsing softly\neye contact\nsoothing',
    'devLeap_dv02_detailSkills':
        'track faces\nrecognise voices\nwatch movements',
    'devLeap_dv02_detailEmotional':
        'Even tiny, your baby begins building emotional memories.',
    'devLeap_dv03_homeBullets':
        'more crying in the evening\nwants more cuddling\nirritates easily\nhard to unwind',
    'devLeap_dv03_detailWhats':
        'Your baby’s nervous system is still immature. Everything may feel loud: sights, hunger, fatigue, stimulation.',
    'devLeap_dv03_keywords':
        'sensitivity\noverwhelm\ncomfort\noverload\nemotional needs',
    'devLeap_dv03_detailMay':
        'evening fussiness\nrestlessness\nharder sleep\nextra need for cuddles',
    'devLeap_dv03_detailHelp':
        'quiet room\ngentle light\nhold and sway gently\nfewer stimuli',
    'devLeap_dv03_detailSkills':
        'more facial expressions\nmore attention to surroundings',
    'devLeap_dv03_detailEmotional':
        'Your baby is not “difficult”; they’re still learning the world.',
    'devLeap_dv04_homeBullets':
        'watches faces\nfollows movements\nshows attention\nresponds more to people',
    'devLeap_dv04_detailWhats':
        'They pay closer attention follow people spot expressions and react to what is around.',
    'devLeap_dv04_keywords':
        'interaction\nattention\nobservation\nexpressions\nbond',
    'devLeap_dv04_detailMay':
        'more eye contact\nnew sounds\nlonger awake stretches\nsocial responses',
    'devLeap_dv04_detailHelp':
        'talk plenty\nmirror faces\nsimple toys\nrespect sleepy cues',
    'devLeap_dv04_detailSkills':
        'track objects\nsocial curiosity reacts to facial cues',
    'devLeap_dv04_detailEmotional': 'Relationships teach them about the world.',
    'devLeap_dv05_homeBullets':
        'watches hands\nmore arm waving\nnew sounds more curious',
    'devLeap_dv05_detailWhats':
        'They begin noticing hands arms movement and bodily sensations.',
    'devLeap_dv05_keywords':
        'body\ndiscovery\ncoordination\ncuriosity\nmovement',
    'devLeap_dv05_detailMay':
        'studying hands\nrepetitive motion\nnew sounds\nricher expressions',
    'devLeap_dv05_detailHelp':
        'tummy time\nlight toys\nsteady eye gaze\nchat often',
    'devLeap_dv05_detailSkills': 'lift head\nwatch hands\nreact to own motion',
    'devLeap_dv05_detailEmotional': 'Each discovery builds confidence.',
    'devLeap_dv06_homeBullets':
        'reads facial cues\nresponds to tone\nwants more contact\nmore social',
    'devLeap_dv06_detailWhats':
        'They’re tuning in to emotions, tone of voice, faces, and your steady presence.',
    'devLeap_dv06_keywords': 'emotion\nbond\ninteraction\nsafety\npresence',
    'devLeap_dv06_detailMay':
        'extra smiles\new sounds seeking chats\nmore social curiosity',
    'devLeap_dv06_detailHelp':
        'smile back\ntalk often\ncalm voice\nplayful back-and-forth',
    'devLeap_dv06_detailSkills':
        'social smile\nstronger reactions\nricher interaction',
    'devLeap_dv06_detailEmotional': 'Safety grows through everyday connection.',
    'devLeap_dv07_homeBullets':
        'wakes more lighter sleep grouchier extra soothing',
    'devLeap_dv07_detailWhats':
        'The brain spins up more complex sleep cycles—lighter transitions more wake-ups between cycles.',
    'devLeap_dv07_keywords':
        'sleep\nnight waking\nsensitivity\nbrain change\ngrumpiness',
    'devLeap_dv07_detailMay':
        'short naps\nmore wake-ups\nirritability\ntrickier settling',
    'devLeap_dv07_detailHelp':
        'gentle rhythm\ndark room\nless stimulation\nfollow sleepy cues',
    'devLeap_dv07_detailSkills':
        'stronger interplay curiosity richer expressions',
    'devLeap_dv07_detailEmotional':
        'Sleep shifts are not regressions—they’re growth.',
    'devLeap_dv08_homeBullets':
        'watches hands\nnew sounds\nricher curiosity\nstronger reactions to people',
    'devLeap_dv08_detailWhats':
        'They sense they can act on the world—movement emotion coordination vision knit together.',
    'devLeap_dv08_keywords':
        'body awareness\ncoordination\ncuriosity\nsensing\nplay',
    'devLeap_dv08_detailMay':
        'repeated motions\ndeep observing\nchatty bursts\nsound play',
    'devLeap_dv08_detailHelp': 'floor time basic toys gaze games soft chatter',
    'devLeap_dv08_detailSkills':
        'steady head lifts\nobject watching\nresponds to scenery',
    'devLeap_dv08_detailEmotional': 'Tiny wins deepen trust.',
    'devLeap_dv09_homeBullets':
        'laughs more answers people makes sounds seeks play',
    'devLeap_dv09_detailWhats':
        'They read emotions voices faces and joyful back-and-forth better.',
    'devLeap_dv09_keywords':
        'social life laughter communication expressions attachment',
    'devLeap_dv09_detailMay':
        'big giggles\nlooping sounds\nspirited play\nseeks playful games',
    'devLeap_dv09_detailHelp':
        'play often mirror moods echo coos chatter daily',
    'devLeap_dv09_detailSkills':
        'belly laughs deeper feelings social curiosity',
    'devLeap_dv09_detailEmotional': 'Love and safety rehearse during play.',
    'devLeap_dv10_homeBullets':
        'grasps items mouthing observes details itching to roam',
    'devLeap_dv10_detailWhats':
        'Motor skills spike—curiosity touch space all wire together.',
    'devLeap_dv10_keywords':
        'exploration\nmotor skills\ncuriosity\nsensations\ndiscovery',
    'devLeap_dv10_detailMay':
        'hands-on play\nmouthing\nenergy bursts sharper focus',
    'devLeap_dv10_detailHelp':
        'safe toys\ninteresting textures\nwatch closely\nencourage roaming',
    'devLeap_dv10_detailSkills': 'rolls\nreaches toys\nhands-on manipulation',
    'devLeap_dv10_detailEmotional': 'Exploring is central learning here.',
    'devLeap_dv11_homeBullets':
        'new sounds\nresponds to people\nwants play\nshows feelings',
    'devLeap_dv11_detailWhats':
        'They practice emotional turn-taking early signals and reacting to caregivers.',
    'devLeap_dv11_keywords':
        'language\ncommunication\ninteraction\nsocial play\nbonding',
    'devLeap_dv11_detailMay':
        'babbling\nmore giggles\nsteady chatter\nasking for attention',
    'devLeap_dv11_detailHelp':
        'mirror sounds\nlots of play\nsing simple songs\nanswer often',
    'devLeap_dv11_detailSkills':
        'babbling\nresponds to name\nricher expression',
    'devLeap_dv11_detailEmotional': 'Connection blossoms before fluent words.',
    'devLeap_dv12_homeBullets':
        'wants to roam\nstudies surroundings\nreaches farther intense curiosity',
    'devLeap_dv12_detailWhats':
        'Distance space movement and roaming make more sense now.',
    'devLeap_dv12_keywords':
        'spatial awareness\nexploration\ncuriosity\nmovement\ndiscovery',
    'devLeap_dv12_detailMay':
        'pushing toward toys\nscanning the room\nbursts of energy',
    'devLeap_dv12_detailHelp':
        'safe roaming varied toys supervised open floor time',
    'devLeap_dv12_detailSkills':
        'scooting toward toys\nreaching far\nsteady sitting',
    'devLeap_dv12_detailEmotional':
        'Exploring the space around them builds confidence.',
    'devLeap_dv13_homeBullets':
        'needs more cuddling\nwary of strangers\ncries when you leave\nextra sensitive',
    'devLeap_dv13_detailWhats':
        'They clock absences separations and reunions with new feelings.',
    'devLeap_dv13_keywords':
        'attachment\nbonding\nseparation distress\nemotional safety\nsensitivity',
    'devLeap_dv13_detailMay':
        'more crying\nharder sleeping alone\nwary of strangers\nclings to caregivers',
    'devLeap_dv13_detailHelp':
        'brief goodbyes\noffer comfort\nsteady routines\nemotional presence',
    'devLeap_dv13_detailSkills':
        'notices absence\nseeks caregiver\nmirrors feelings',
    'devLeap_dv13_detailEmotional':
        'Neediness here is nervous-system learning—not manipulation.',
    'devLeap_dv14_homeBullets':
        'studies everything\nreacts fast\nlearns quickly\nexplores nonstop',
    'devLeap_dv14_detailWhats':
        'Cause-effect hides-and-seeks object permanence and pattern hunts ramp up.',
    'devLeap_dv14_keywords':
        'logic\nconnections\nobservation\nlearning\npatterns',
    'devLeap_dv14_detailMay':
        'peek-a-boo\nhides objects\nrepeats actions\ntests reactions',
    'devLeap_dv14_detailHelp':
        'simple cause games\nhide toys\nrepeatable songs\nconsistent play',
    'devLeap_dv14_detailSkills': 'clapping\ncrawling\nfinds hidden objects',
    'devLeap_dv14_detailEmotional': 'Repetition anchors big learning leaps.',
    'devLeap_dv15_homeBullets':
        'into everything\nbusy hands\nalways moving\nhigh energy',
    'devLeap_dv15_detailWhats':
        'Pushing tossing reaching yanking—all ways to steer their space.',
    'devLeap_dv15_keywords':
        'movement\ncoordination\nexploration\ncuriosity\nindependence',
    'devLeap_dv15_detailMay':
        'lots of energy\nroaming\ntumbles\ntrouble staying still',
    'devLeap_dv15_detailHelp':
        'baby-proof space\nsupervise\nsensory play\nencourage movement',
    'devLeap_dv15_detailSkills': 'pulls up\ncruises furniture\nmaps the room',
    'devLeap_dv15_detailEmotional':
        'Motion is how they decode the wider world.',
    'devLeap_dv16_homeBullets':
        'copies sounds\nwatches faces\nreaches out\nresponds more to people',
    'devLeap_dv16_detailWhats':
        'Sounds carry meaning gestures rebound they practice mini dialogues.',
    'devLeap_dv16_keywords':
        'language\nimitation\ncommunication\nexpression\ninteraction',
    'devLeap_dv16_detailMay':
        'repeating sounds\nbids for attention\nstudies faces\nfocuses on speech',
    'devLeap_dv16_detailHelp':
        'narrate days\nname objects\nanswer babble\nsimple board books',
    'devLeap_dv16_detailSkills': 'points\nrepeats sounds\nnotices simple words',
    'devLeap_dv16_detailEmotional':
        'Bonding drills through chatter before fluent speech.',
    'devLeap_dv17_homeBullets':
        'tries walking\nexplores everything\nshows preferences\ntests limits',
    'devLeap_dv17_detailWhats':
        'Doing it myself sparks thrill fear big feelings all mixed.',
    'devLeap_dv17_keywords':
        'autonomy\nindependence\nexploration\nconfidence\nmovement',
    'devLeap_dv17_detailMay':
        'walking tries\nresists help\nintense roaming quick frustration',
    'devLeap_dv17_detailHelp':
        'cheer attempts\nsafe spaces\nname frustration\ncelebrate wins',
    'devLeap_dv17_detailSkills': 'first steps first words\nmore independence',
    'devLeap_dv17_detailEmotional': 'Each brave try strengthens self-trust.',
    'devLeap_dv18_homeBullets':
        'wants independence\nfrustrates fast\nmood swings\nbig personality',
    'devLeap_dv18_detailWhats':
        'Wants collide with limits long before regulation skills arrive.',
    'devLeap_dv18_keywords':
        'emotions\nautonomy\nfrustration\ntemperament\nsensitivity',
    'devLeap_dv18_detailMay':
        'big meltdowns\npushback\nmood shifts\nwants to do it alone',
    'devLeap_dv18_detailHelp':
        'name feelings stay calm model regulation anchor safety',
    'devLeap_dv18_detailSkills':
        'self-feeding steadier walking\nimitates adults word growth',
    'devLeap_dv18_detailEmotional':
        'Big feelings outsized brains still wiring emotional brakes.',
    'devLeap_dv19_homeBullets':
        'play changes\nstorytelling\nchattier\ncreative streaks',
    'devLeap_dv19_detailWhats':
        'Symbolic thought imagination language layers expand together.',
    'devLeap_dv19_keywords':
        'imagination\ncreativity\nlanguage\npretend play\nstorytelling',
    'devLeap_dv19_detailMay':
        'pretend play\nmany questions\nmade-up stories\ntalk explosion',
    'devLeap_dv19_detailHelp':
        'open play\nread aloud\nmusic\ndrawing\nchat often',
    'devLeap_dv19_detailSkills':
        'longer sentences symbolic play\nfriendlier with peers',
    'devLeap_dv19_detailEmotional':
        'Pretend builds emotional IQ alongside words.',
    'devLeap_dv20_homeBullets':
        'many questions\nwants to choose everything\nstrong feelings\ninvents stories',
    'devLeap_dv20_detailWhats':
        'Personality imaginative talk and layered emotions braid together.',
    'devLeap_dv20_keywords':
        'personality\nindependence\nimagination\nemotions\ncreativity',
    'devLeap_dv20_detailMay':
        'fast mood swings\nwants control\nimaginative play\nnonstop talking',
    'devLeap_dv20_detailHelp':
        'support imagination\nkeep talking\ncoach feelings\nsmall responsibilities',
    'devLeap_dv20_detailSkills':
        'tells stories invents characters clear speech\nsolves little problems',
    'devLeap_dv20_detailEmotional':
        'Every timeline differs—comparison fuels anxiety.',
    'regAppBarTitle': 'Register: mom & babies',
    'regLetsStart': "Let's start",
    'regSubtitleMandatory': 'Register mom and baby to unlock the app.',
    'regSubtitleOptional': 'Register mom and add one or more babies.',
    'regStepMother': 'Mom',
    'regStepBaby': 'Baby',
    'regMotherSection': '1) Mom registration',
    'regBabySection': '2) Baby registration',
    'regBirthLabel': 'Birth:',
    'regMotherHeight': 'Height (cm)',
    'regFatherSection': "Dad's details (optional)",
    'regFatherName': "Dad's name",
    'regFatherBirthLabel': "Dad's date of birth",
    'regFatherHeight': "Dad's height (cm)",
    'settingsFamilyTree': 'Family',
    'fatherPhotoTitle': "Dad's photo",
    'regFatherPhotoAdd': "Add dad's photo",
    'regFatherPhotoChange': "Change dad's photo",
    'regMotherPhotoAdd': "Mom's photo (optional)",
    'regMotherPhotoChange': "Change mom's photo",
    'regBabyPhotoAdd': "Baby's photo (optional)",
    'regBabyPhotoChange': "Change baby's photo",
    'regSaveMotherAdvance': 'Save and continue',
    'regSaveBaby': 'Save baby',
    'regSelectMotherPrompt': 'Or select an already registered mom:',
    'regMotherLabel': 'Mom',
    'regBabyGirl': 'Girl',
    'regBabyBoy': 'Boy',
    'regZodiacLine': 'Sign: {sign}',
    'regBabyWeight': 'Weight (kg)',
    'regRegisteredList': 'Registered',
    'regNoneYet': 'No registrations yet.',
    'regBabyPrompt': 'Register a mom first to add babies.',
    'regPromptBabyName': 'Great, {mom}. Now enter the baby\'s name:',
    'regMomGeneric': 'mom',
    'regMomWithName': 'mom {name}',
    'regListBaby': 'Baby: {name}',
    'regListBirth': 'Birth: {date}',
    'regListSign': 'Sign: {sign}',
    'regListPhone': 'Phone: {phone}',
    'regSavingMother': 'Saving mom…',
    'regSavingBaby': 'Saving baby…',
    'regSnackMotherBirth': "Enter the mom's date of birth.",
    'regSnackMotherOk': 'Mom registered successfully.',
    'regSnackSelectMother': 'Select or register a mom before continuing.',
    'regSnackBabyBirth': "Enter the baby's date of birth.",
    'regSnackPickMother': 'Select a mom to register the baby.',
    'regSnackBabyOk': 'Baby registered successfully.',
    'valNameEmpty': 'Enter the name.',
    'valNameShort': 'Name is too short.',
    'valPhoneEmpty': 'Enter the phone.',
    'valPhoneInvalid': 'Invalid phone. Use (xx) 9XXXX-XXXX.',
    'valHeightEmpty': 'Enter the height.',
    'valHeightInvalid': 'Invalid height.',
    'valHeightMotherRange': 'Height out of expected range.',
    'valFatherHeightEmpty': "Enter dad's height.",
    'valWeightEmpty': 'Enter the weight.',
    'valWeightInvalid': 'Invalid weight.',
    'valWeightRange': 'Weight out of expected range.',
    'valBabyHeightRange': 'Height out of expected range.',
    'placeholderBabyName': 'Baby',
    'valBirthDateInvalid': 'Invalid date. Use dd/mm/yyyy.',
    'brDateHint': 'Date of birth',
    'brDateOpenCalendar': 'Open calendar',
    'exampleCard': 'Example card:',
  },
  AppLang.es: {
    'appName': 'FaceBaby',
    'home': 'Inicio',
    'records': 'Registros',
    'reports': 'Informes',
    'memories': 'Recuerdos',
    'more': 'Más',
    'helloMom': '¡Hola, Mamá!',
    'today': 'Hoy',
    'shortcuts': 'Atajos',
    'registerNow': 'Registrar ahora',
    'edit': 'Editar',
    'todaySummary': 'Resumen de hoy',
    'nextEvents': 'Próximos eventos',
    'quickRecordsTitle': 'Registros rápidos',
    'quickRecordsSubtitle': 'Agrega la rutina del bebé en pocos toques.',
    'feedingAlertsSwitchTitle': 'Alerta de alimentación',
    'feedingAlertsSwitchSubtitle':
        'Notifica cuando pasa el intervalo definido desde la última toma al pecho o biberón.',
    'feedingAlertsIntervalCaption':
        'Recordar después de la última toma: {m} min (20–360)',
    'feedingAlertsShortcutTitle': 'Alerta de alimentación',
    'scheduledFeedingReminderBody':
        'Momento del recordatorio de alimentación. Toca para registrar.',
    'scheduledDiaperReminderTitle': 'Cambio de pañal',
    'scheduledDiaperReminderBody':
        'Puede ser hora de cambiar el pañal desde la última vez. Toca para registrar.',
    'homeTimeToFeed': '¡Hora de alimentar!',
    'sleepBannerEmpty': 'Aún no hay sueños registrados.',
    'sleepToggleAlertsSubtitle':
        'Recordatorios según el último sueño terminado y la edad.',
    'sleepAlertsWakeWindowRulerValueAuto':
        'Tiempo efectivo en esta escala: {m} min (automático según la edad).',
    'sleepAlertsWakeWindowRulerValueCustom':
        'Tiempo en esta escala: {m} min (valor personalizado).',
    'sleepAlertsWakeWindowSliderLabelAuto': '{m} min · auto',
    'sleepAlertsWakeWindowSliderLabelCustom': '{m} min',
    'sleepAlertsApproachRulerValueDefault':
        'Antelación efectiva en esta escala: {m} min (predeterminado).',
    'sleepAlertsApproachRulerValueCustom':
        'Antelación en esta escala: {m} min.',
    'sleepAlertsApproachSliderLabelDefault': '{m} min · predeterminado',
    'sleepAlertsApproachSliderLabelCustom': '{m} min',
    'sleepAlertsWakeWindowAutomatic':
        'Límite de vigilia usado en la alerta: {m} min (automático según la tabla por edad).',
    'sleepAlertsWakeWindowAutomaticNoBirth':
        'Añade la fecha de nacimiento del bebé en el perfil para el valor correcto; hasta entonces usamos {m} min de referencia.',
    'sleepAlertsMonthsApprox': 'Tabla de referencia: ~{n} meses',
    'sleepAlertsWakeWindowCustom': 'Límite de vigilia personalizado: {m} min.',
    'sleepAlertsApproachAuto':
        'Aviso antes del límite: {m} min de antelación (valor predeterminado).',
    'sleepAlertsApproachCustom':
        'Aviso antes del límite: {m} min de antelación (personalizado).',
    'sleepAppBar': 'Sueño',
    'sleepTitle': 'Sueño',
    'sleepIntro': 'Registra y sigue las siestas y el sueño nocturno.',
    'sleepComingTitle': 'Próximamente',
    'sleepComingBody':
        'Esta pantalla está lista para registrar el sueño.\nPronto conectaremos la base de datos y mostraremos último sueño, total del día e historial.',
    'sleepSessionTitle': 'Sueño en curso',
    'sleepSessionStartedAt': 'Iniciado a las {time}',
    'sleepStatusSleeping': 'Durmiendo',
    'sleepStatusPaused': 'En pausa',
    'sleepWakeButton': '¿DESPERTÓ?',
    'sleepThisCardTitle': 'Este sueño',
    'sleepLabelStart': 'Inicio',
    'sleepLabelEnd': 'Fin',
    'sleepLabelDuration': 'Duración',
    'sleepLabelQuality': 'Calidad',
    'sleepObservationsTitle': 'Observaciones',
    'sleepObservationHint': 'Añadir observación…',
    'sleepPause': 'Pausar',
    'sleepResume': 'Reanudar',
    'sleepCancelSession': 'Cancelar sueño',
    'sleepStartButton': 'INICIAR SUEÑO',
    'sleepSavedOk': 'Sueño registrado.',
    'sleepResultDialogTitle': 'Estado del sueño',
    'sleepResultShortTitle': 'Durmió menos de lo esperado',
    'sleepResultExpectedTitle': 'Sueño dentro de lo esperado',
    'sleepResultLongTitle': 'Durmió más de lo esperado',
    'sleepResultDurationLine': 'Duración registrada: {duration}.',
    'sleepResultExpectedLine': 'Referencia para la edad: unos {min}–{max} min.',
    'sleepResultShortBody':
        'Fue un sueño corto. Observa señales de cansancio y prepara un ambiente tranquilo para el próximo descanso.',
    'sleepResultExpectedBody':
        'Buena ventana de descanso. El sueño estuvo cerca de lo esperado para la edad.',
    'sleepResultLongBody':
        'Fue un sueño más largo. Puede ser recuperación de cansancio; vigílalo si se repite con frecuencia.',
    'sleepConfirmBackTitle': '¿Salir del sueño?',
    'sleepConfirmBackBody':
        'El registro aún no se ha guardado. ¿Descartar esta sesión?',
    'sleepConfirmCancelSessionTitle': '¿Cancelar sueño?',
    'sleepConfirmCancelSessionBody': 'Se descartará el tiempo de esta sesión.',
    'sleepDiscard': 'Descartar',
    'sleepHistoryTitle': 'Historial de sueños',
    'sleepHistoryEmpty': 'Aún no hay sueños registrados.',
    'historyShowButton': 'Ver historial',
    'historyHideButton': 'Ocultar historial',
    'historyViewMoreButton': 'Ver más',
    'sleepUpdatedOk': 'Sueño actualizado.',
    'sleepBannerNextNap': 'Próxima siesta en ~{min} min',
    'sleepWindowTitle': 'Ventana de sueño actual',
    'sleepWindowEarly': 'Antes de la ventana ideal',
    'sleepWindowIdeal': 'Ideal',
    'sleepWindowLate': 'Pasó el momento',
    'sleepRoutineLastLabel': 'Último sueño: hace {ago}',
    'sleepRoutineLastNever': 'Último sueño: sin registros aún',
    'sleepRoutineNextPrefix': 'Próxima siesta:',
    'sleepNextApproxMin': 'en ~{min} min',
    'sleepRoutineNextNow': 'ahora — buen momento para intentar',
    'sleepStatusEarly': '🟡 Antes de la ventana ideal',
    'sleepStatusIdeal': '🟢 Ventana ideal',
    'sleepStatusOverdue': '🔴 Puede estar muy cansado',
    'sleepHeroAwakeBadge': 'Despierto',
    'sleepHeroAwakeCaption':
        'La barra verde → amarilla → roja muestra cuánto lleva despierto y cuándo suele tocar la próxima siesta. Al dormir, toca INICIAR SUEÑO.',
    'sleepHeroSleepingBadge': 'Durmiendo',
    'sleepHeroSleepingCaption':
        'Cuando despierte, toca Finalizar sueño para guardar esta sesión.',
    'sleepRoutineCardTitle': 'Próximo sueño',
    'sleepRoutineVigilHighlight':
        'Ventana de vigilia en la app: {min}–{max} min despierto entre sueños (fija por edad en meses — no configurable).',
    'sleepRoutineStatusLine': 'Estado: {status}',
    'sleepIdealForAge': 'Misma tabla (por edad)',
    'sleepAgeMonthsLabel': '{n} meses',
    'sleepWindowMinMax': '{min}–{max} min',
    'sleepLegendG': '🟢 ventana ideal',
    'sleepLegendY': '🟡 antes de la ventana ideal',
    'sleepLegendR': '🔴 pasó el momento',
    'sleepWakeWindowExplainer':
        'Muestra cuánto lleva despierto desde el fin del último sueño (no cuánto durmió). Amarillo: aún no está en la ventana típica de la próxima siesta.',
    'sleepFinalizeButton': 'FINALIZAR',
    'sleepSleepingFor': 'Durmiendo hace {when}',
    'sleepInsightTitle': 'Resumen del día',
    'sleepInsightNaps': 'Hoy: {n} siestas',
    'sleepInsightAvg': 'Media: {min} min',
    'sleepInsightTrendDown': '💡 Durmió menos de lo habitual hoy',
    'sleepInsightTrendOk': '💡 Patrón de sueño estable hoy',
    'sleepHistoryToday': 'Hoy',
    'sleepToggleAlerts': 'Activar alertas de sueño',
    'sleepNotifTitle': 'Sueño',
    'sleepNotifBeforeBody':
        'Puede ser un buen momento para ayudar al bebé a dormir.',
    'sleepNotifOverdueBody':
        'Tu bebé puede estar cansado — intenta iniciar el sueño con calma.',
    'sleepNotifWakeOverdueBodyMale':
        'Ya hace más de {hours} h que está durmiendo, míralo, mamá.',
    'sleepNotifWakeOverdueBodyFemale':
        'Ya hace más de {hours} h que está durmiendo, mírala, mamá.',
    'notifyGrowthWeightDownTitle': 'Peso menor que antes',
    'notifyGrowthWeightDownBody':
        'El último peso está por debajo del anterior. Consulta al pediatra si tienes dudas.',
    'notifyGrowthStaleTitle': 'Hace tiempo que no registras el crecimiento',
    'notifyGrowthStaleBody':
        'Han pasado más de 30 días desde la última medición (peso, altura o perímetro). Ya van {days} días — actualiza en los registros.',
    'vaccineReminderNotifTitle': 'Vacuna',
    'vaccineReminderNotifBody': 'Vacuna prevista hoy: {name}.',
    'consultationReminderNotifTitle': 'Cita programada',
    'consultationReminderNotifBody': 'Mañana · {title} · {when}',
    'consultationTodayReminderNotifBody': 'Hoy · {title} · {when}',
    'notifChannelRemindersName': 'Recordatorios',
    'notifChannelRemindersDesc': 'Alertas de alimentación, pañales y sueño.',
    'notifChannelGrowthName': 'Crecimiento',
    'notifChannelGrowthDesc':
        'Alertas de peso y ausencia prolongada de mediciones.',
    'whatHappenedNow': '¿Qué pasó ahora?',
    'momNote': 'Nota de mamá',
    'saveRecord': 'Guardar registro',
    'reportsTitle': 'Informes',
    'reportsSubtitle': 'Resumen para mamá y el pediatra.',
    'reportsHubAnchorLabel': 'Referencia',
    'reportsHubPickDayTooltip': 'Elegir día de referencia para los informes',
    'reportsHubSectionTitle': 'Informes disponibles',
    'reportStubComingSoon':
        'Este informe se actualizará automáticamente con los datos de la app para el periodo seleccionado. El diseño y las métricas se definirán a continuación.',
    'reportListDaily': 'Informe diario',
    'reportListDailySub': 'Resumen y detalles del día seleccionado',
    'reportListWeekly': 'Informe semanal',
    'reportListWeeklySub':
        'Resumen y detalles de la semana que contiene el día seleccionado',
    'reportListMonthly': 'Informe mensual',
    'reportListMonthlySub': 'Agregados mensuales del mes del día seleccionado',
    'reportListSleepAdv': 'Informe avanzado de sueño',
    'reportListSleepAdvSub': 'Patrones y métricas de sueño',
    'reportListDevelopment': 'Informe de desarrollo',
    'reportListDevelopmentSub': 'Hitos y saltos del desarrollo',
    'growth': 'Crecimiento',
    'pediatricReport': 'Informe pediátrico',
    'pediatricReportDesc':
        'Genera un PDF con peso, sueño, alimentación, pañales, vacunas, síntomas registrados en Salud, citas y notas.',
    'reportListPediatric': 'Informe para el pediatra',
    'reportListPediatricSub': 'PDF y datos para la consulta médica',
    'healthHubSymptomReports': 'Registrar síntoma',
    'healthHubSymptomReportsSub':
        'Fiebre, cólicas, medicamentos y más — incluidos en el informe pediátrico',
    'symptomReportTitle': 'Registrar síntoma',
    'symptomReportEmpty': 'Aún no hay registros. Pulsa + para añadir.',
    'symptomReportNew': 'Nuevo registro',
    'symptomReportSave': 'Guardar',
    'symptomReportOccurredAt': 'Fecha y hora',
    'symptomReportPickDateTime': 'Cambiar fecha y hora',
    'symptomReportMedication': 'Medicamentos tomados',
    'symptomReportMedicationHint': 'Nombre o nota breve',
    'symptomReportFever': 'Fiebre',
    'symptomReportTemp': 'Temperatura',
    'symptomReportTempHint': 'Según las unidades de Ajustes',
    'symptomReportCrying': 'Llanto sin causa aparente',
    'symptomReportPain': 'Dolor',
    'symptomReportColic': 'Cólicas',
    'symptomReportReflux': 'Reflujo',
    'symptomReportOther': 'Otro',
    'symptomReportOtherHint': 'Breve descripción',
    'symptomReportValidationNeedOne':
        'Selecciona al menos un síntoma o rellena un campo.',
    'symptomReportValidationFeverTemp':
        'Indica la temperatura si marcas fiebre.',
    'symptomReportDeleteTitle': '¿Eliminar registro?',
    'symptomReportDeleteBody': 'Esta acción no se puede deshacer.',
    'reportPediatricScreenTitle': 'Informe pediátrico',
    'reportPediatricPeriodPrefix': 'Periodo:',
    'reportPediatricFilterHint': 'Periodo del informe',
    'reportPediatricDateFrom': 'Desde',
    'reportPediatricDateTo': 'Hasta',
    'reportPediatricPickRange': 'Elegir fechas',
    'reportPediatricFilterMaxDaysHint':
        'Toca para cambiar. Los intervalos muy largos están limitados a 366 días.',
    'reportPediatricSectionGeneral': 'Información general',
    'reportPediatricSectionSummary': 'Resumen del periodo',
    'reportPediatricSectionSleep': 'Sueño',
    'reportPediatricSectionFeeding': 'Alimentación',
    'reportPediatricSectionSymptoms': 'Síntomas y registros',
    'reportPediatricSectionObservations': 'Observaciones de los padres',
    'reportPediatricLabelName': 'Nombre',
    'reportPediatricLabelAge': 'Edad',
    'reportPediatricLabelBirth': 'Fecha de nacimiento',
    'reportPediatricLabelWeightCurrent': 'Peso (último del periodo)',
    'reportPediatricLabelHeight': 'Altura',
    'reportPediatricWeightStart': 'Peso inicial (periodo)',
    'reportPediatricWeightEnd': 'Peso final (periodo)',
    'reportPediatricWeightGain': 'Cambio de peso',
    'reportPediatricHeightStart': 'Altura inicial (periodo)',
    'reportPediatricHeightEnd': 'Altura final (periodo)',
    'reportPediatricHeightGain': 'Crecimiento de altura',
    'reportPediatricAvgFeeds': 'Tomas/comidas por día (media)',
    'reportPediatricAvgSleep': 'Sueño por día (media)',
    'reportPediatricAvgDiapers': 'Cambios de pañal por día (media)',
    'reportPediatricFeverEpisodes':
        'Episodios de fiebre (registro estructurado)',
    'reportPediatricFeverNote': 'Nota',
    'reportPediatricFeverFootnote':
        'Recuento desde registros estructurados en Salud › Registrar síntoma (con temperatura si aplica).',
    'reportPediatricVaccines': 'Vacunas administradas en el periodo',
    'reportPediatricMedications':
        'Medicamentos (registros y palabras clave en notas)',
    'reportPediatricSleepAvgDaily': 'Promedio diario de sueño',
    'reportPediatricSleepAwakenings': 'Despertares nocturnos (media)',
    'reportPediatricSleepPattern': 'Patrón general del sueño',
    'reportPediatricSleepPatternStable': 'Sobre todo continuo',
    'reportPediatricSleepPatternModerate': 'Intermedio',
    'reportPediatricSleepPatternFragmented': 'Más fragmentado',
    'reportPediatricSleepLongest': 'Mayor período continuo de sueño',
    'reportPediatricFeedingBreast': 'Lactancia',
    'reportPediatricFeedingFormula': 'Fórmula',
    'reportPediatricFeedingSolid': 'Sólidos',
    'reportPediatricFeedingSessions': 'sesiones',
    'reportPediatricFeedingAvgDur': 'duración media',
    'reportPediatricSymptomReflux': 'Reflujo (diarios o registros)',
    'reportPediatricSymptomColic': 'Cólicas (diarios o registros)',
    'reportPediatricSymptomIrrit': 'Irritabilidad (estados de ánimo)',
    'reportPediatricIrritHigh': 'Más perceptible',
    'reportPediatricIrritMedium': 'Moderada',
    'reportPediatricIrritLow': 'Leve',
    'reportPediatricIrritUnknown': 'Sin datos',
    'reportPediatricYes': 'Sí',
    'reportPediatricNo': 'No',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'Diarios del día',
    'reportPediatricJournalNoteHint': 'Detección por palabras en texto libre.',
    'reportPediatricObsHint':
        'Notas para la consulta: síntomas, medicamentos, cambios de comportamiento…',
    'reportPediatricBtnShare': 'Compartir',
    'reportPediatricBtnExportPdf': 'Exportar PDF',
    'reportPediatricBtnPrint': 'Imprimir',
    'reportPediatricBtnEmail': 'Correo',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote':
        'Resumen informativo a partir de registros locales. No sustituye la valoración clínica.',
    'reportPediatricNone': 'Ninguno',
    'reportPediatricPdfTitle': 'Informe pediátrico — FaceBaby',
    'reportPediatricPdfPeriod': 'Periodo:',
    'reportPediatricPdfFooter':
        'Generado en FaceBaby. Contenido limitado a los datos en este dispositivo (modo sin conexión).',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': 'Llanto sin causa aparente (registros)',
    'reportPediatricSymptomPain': 'Dolor (registros)',
    'reportPediatricStructuredSymptoms': 'Registros de síntomas (fecha y hora)',
    'reportPediatricStructuredSymptomsEmpty':
        'No hay registros estructurados en este periodo.',
    'generatePdf': 'Generar PDF',
    'memoriesTitle': 'Libro de recuerdos',
    'memoriesSubtitle': 'Momentos importantes para guardar para siempre.',
    'memoriesProgressSaved': '{filled} de {total} momentos guardados',
    'memoriesProgressStandardBadges': '({count} insignias estándar)',
    'memoriesCheerEmpty':
        'Toca una insignia con + para añadir fotos e historias.',
    'memoriesAlbumPromoTitle': 'Tu libro de recuerdos completo',
    'memoriesAlbumPromoSubtitle':
        'Descarga un PDF elegante con portada FaceBaby, marco decorativo y todas las insignias que ya completaste.',
    'memoriesAlbumDownloadCta': 'Descargar PDF del álbum',
    'memoriesAlbumGenerating': 'Generando su álbum…',
    'memoriesAlbumNeedFilled':
        'Complete al menos un momento en el álbum para generar el PDF.',
    'memoriesAlbumError': 'No se pudo generar el PDF.',
    'memoriesAlbumPdfReadyTitle': 'PDF del álbum listo',
    'memoriesAlbumShareAction': 'Compartir…',
    'memoriesAlbumSaveAction': 'Guardar / descargar',
    'memoriesAlbumSavedSnack': 'PDF guardado en el dispositivo.',
    'memoriesAlbumSaveFailedSnack': 'No se pudo guardar el PDF.',
    'memoriesAlbumCoverMain': 'Libro de recuerdos',
    'memoriesAlbumCoverTagline': 'Momentos especiales con {name}',
    'memoriesAlbumFooter': 'Creado con FaceBaby',
    'memoriesAlbumBackCoverBody':
        'FaceBaby nació para transformar momentos simples en recuerdos eternos. Cada sonrisa, descubrimiento, abrazo y logro de tu bebé merece ser guardado con amor, cariño y significado.\n\nEste libro fue creado para acompañar los primeros pasos de esta hermosa etapa, registrando recuerdos únicos que podrán revivirse para siempre.\n\nMás que fotos y anotaciones, estas páginas guardan emociones, historias y sentimientos que el tiempo jamás borrará.\n\nGracias por permitir que FaceBaby forme parte de la historia de tu familia. 💛',
    'memoriesAlbumBackCoverFinale':
        'Porque crecer pasa rápido…\npero los recuerdos pueden durar para siempre.',
    'memoriesAlbumQualityTitle': 'Calidad del PDF',
    'memoriesAlbumQualityShareTitle': 'Ligero — para compartir',
    'memoriesAlbumQualityShareDesc':
        'Imágenes comprimidas, archivo más pequeño. Ideal para WhatsApp y correo.',
    'memoriesAlbumQualityPrintTitle': 'Alta calidad — para imprimir',
    'memoriesAlbumQualityPrintDesc':
        'Mayor resolución de fotos. Archivo más grande; mejor para impresión.',
    'memoriesAlbumExportTitle': 'Generando su libro…',
    'memoriesAlbumProgressPreparing': 'Preparando páginas…',
    'memoriesAlbumProgressImages': 'Procesando fotos ({current}/{total})…',
    'memoriesAlbumProgressBuilding': 'Montando PDF ({current}/{total})…',
    'memoriesAlbumProgressSaving': 'Guardando archivo…',
    'memoriesAlbumCancelBtn': 'Cancelar',
    'memoriesAlbumCanceled': 'Generación cancelada.',
    'memoriesAlbumErrorNetwork':
        'Sin conexión a internet. Compruebe la red e intente de nuevo.',
    'memoriesAlbumErrorStorage':
        'Espacio insuficiente en el dispositivo para guardar el PDF.',
    'memoriesAlbumSkippedImages':
        '{count} foto(s) no se pudieron incluir (red o archivo inválido).',
    'addMemory': 'Añadir recuerdo',
    'memoryAddBadgeCta': 'Añadir insignia',
    'memoryChooseBadgeTitle': '¿Qué insignia quieres crear?',
    'memoryOtherBadgeTitle': 'Otra',
    'memoryOtherBadgeNameLabel': 'Nombre de la insignia',
    'memoryOtherBadgeNameHint': 'Ej: Primer disfraz',
    'memoryOtherBadgeNameRequired': 'Indica el nombre de la insignia.',
    'memoryOtherBadgeNameTooLong': 'Usa hasta 25 caracteres.',
    'memoryBadgeMonthOne': '1 mes',
    'memoryBadgeMonthsMany': '{n} meses',
    'memoryBadgeYearOne': '1 año',
    'memoryBadgeYearsMany': '{n} años',
    'memoryBadgeMonthUnitSingular': 'mes',
    'memoryBadgeMonthUnitPlural': 'meses',
    'badge_arrived_home': 'Llegué a casa',
    'badge_first_smile': 'Primera sonrisa',
    'badge_first_feeding': 'Primera alimentación',
    'badge_sleeping': 'Durmiendo',
    'badge_bath_time': 'Hora del baño',
    'badge_going_out': 'De paseo',
    'badge_first_laugh': 'Primera risa',
    'badge_found_hands': 'Descubrió sus manos',
    'badge_lifted_head': 'Levantó la cabeza',
    'badge_at_park': 'En el parque',
    'badge_first_hug': 'Primer abrazo',
    'badge_first_foods': 'Primeros alimentos',
    'badge_first_bath': 'Primer baño',
    'badge_crib_sleep': 'Primera siesta en la cuna',
    'badge_first_diaper_change': 'Primer cambio de pañal',
    'badge_first_burp': 'Primer eructo',
    'badge_first_mom_cuddle': 'Primer regazo de mamá',
    'badge_first_dad_cuddle': 'Primer regazo de papá',
    'badge_first_pediatrician': 'Primera visita al pediatra',
    'badge_first_vaccine': 'Primera vacuna',
    'badge_first_car_ride': 'Primer paseo en coche',
    'badge_first_stroller_ride': 'Primer paseo en carrito',
    'badge_favorite_toy': 'Primer juguete favorito',
    'badge_first_night_home': 'Primera noche en casa',
    'badge_first_giggle': 'Primera risita',
    'badge_sun_bath': 'Primer baño de sol',
    'badge_first_christmas': 'Primera Navidad',
    'badge_first_new_year': 'Primera Nochevieja',
    'badge_first_mothers_day': 'Primer Día de la Madre',
    'badge_first_fathers_day': 'Primer Día del Padre',
    'badge_first_tooth': 'Primer diente',
    'badge_first_puree': 'Primer puré',
    'badge_sat_alone': 'Se sentó sin apoyo',
    'badge_crawled': 'Gateó',
    'badge_stood_up': 'Se puso de pie',
    'badge_first_steps': 'Primeros pasos',
    'badge_first_word': 'Primera palabra',
    'badge_favorite_song': 'Primera canción favorita',
    'badge_first_trip': 'Primer viaje',
    'badge_family_birthday': 'Primer cumpleaños en familia',
    'badge_first_beach': 'Primera playa',
    'badge_first_pool': 'Primera piscina',
    'badge_first_haircut': 'Primer corte de pelo',
    'badge_first_shoes': 'Primeros zapatitos',
    'badge_special_outfit': 'Outfit especial',
    'badge_first_friend': 'Primer amigo',
    'badge_first_party': 'Primera fiesta',
    'badge_first_cartoon': 'Primer dibujo animado',
    'badge_first_book': 'Primer libro',
    'badge_special_free': 'Momento especial libre',
    'settingsTitle': 'Más',
    'registerMotherBaby': 'Registro (mamá y bebé)',
    'vaccinesCard': 'Vacunas (cartilla)',
    'language': 'Idioma',
    'unitsTitle': 'Unidades de medida',
    'unitsIntro':
        'Elige cómo quieres ver las medidas. Empezamos con un valor por defecto según la región de tu dispositivo.',
    'unitsLengthTitle': 'Unidad de longitud',
    'unitsLengthSubtitle': 'Altura, perímetro y medidas en general.',
    'unitsWeightTitle': 'Unidad de peso',
    'unitsWeightSubtitle': 'Peso del bebé y registros relacionados.',
    'unitsLiquidTitle': 'Unidad de líquidos',
    'unitsLiquidSubtitle': 'Volumen (p. ej., biberón y otros).',
    'unitsTempTitle': 'Unidad de temperatura',
    'unitsTempSubtitle': 'Temperatura corporal y ambiente.',
    'unitsOptCm': 'cm',
    'unitsOptInch': 'in',
    'unitsOptKg': 'kg',
    'unitsOptLb': 'lb',
    'unitsOptSt': 'st',
    'unitsOptMl': 'ml',
    'unitsOptUkFloz': 'uk fl oz',
    'unitsOptUsFloz': 'us fl oz',
    'unitsOptC': '°C',
    'unitsOptF': '°F',
    'settingsSoonTitle': 'Próximamente',
    'settingsSoonBadge': 'Pronto',
    'settingsRateUs': 'Califícanos',
    'settingsVersion': 'Versión',
    'settingsVersionDialogTitle': 'Versión de la app',
    'settingsVersionCopy': 'Copiar',
    'settingsVersionCopied': 'Información de versión copiada',
    'settingsTermsOfUse': 'Términos de uso',
    'settingsPrivacyPolicy': 'Política de privacidad',
    'settingsSpecialThanks': 'Agradecimientos especiales',
    'settingsTellFriend': 'Cuéntale a un amigo',
    'settingsMotherProfile': 'Mi perfil',
    'profileEditMother': 'Editar datos de la mamá',
    'profileEditFather': 'Editar datos del papá',
    'profileAddFather': 'Registrar papá',
    'profileFatherNotRegisteredTitle': 'Papá aún no registrado',
    'profileFatherNotRegisteredSubtitle':
        'Si no incluiste al papá en el primer registro, puedes añadir sus datos aquí cuando quieras.',
    'profileFatherAddCta': 'Registrar papá ahora',
    'profileEditBaby': 'Editar datos del bebé',
    'profileDataSaved': 'Datos guardados.',
    'profileEditData': 'Editar datos',
    'motherProfileTabPreferences': 'Preferencias',
    'motherProfileTabMother': 'Mamá',
    'motherProfileTabFather': 'Papá',
    'motherProfileTabBabies': 'Bebés',
    'profileLayoutTitle': 'Diseño de la app',
    'profileLayoutSubtitle':
        'Modo diurno, nocturno o automático según la hora.',
    'profileLayoutAutomatic': 'Automático',
    'profileLayoutDay': 'Diurno',
    'profileLayoutNight': 'Nocturno',
    'profileLayoutUpdating': 'Actualizando diseño…',
    'motherProfileFieldFatherName': 'Nombre',
    'motherProfileNoData':
        'No se encontró ningún perfil. Inténtalo de nuevo en unos instantes.',
    'motherProfileSectionInfo': 'Información',
    'motherProfileFieldPhone': 'Teléfono',
    'motherProfileFieldBirth': 'Nacimiento',
    'motherProfileFieldHeight': 'Altura',
    'motherProfileFieldFatherHeight': 'Altura del papá',
    'profileFamilyMessagesTitle': 'Mensajes en la pantalla Familia',
    'profileShowChristian': 'Cristiana',
    'profileShowHoroscope': 'Astrológica',
    'profileShowPhilosophical': 'Filosófica / Ecuménica',
    'profileShowSpiritist': 'Mensajes espíritas',
    'profileShowJewish': 'Mensajes judías',
    'motherProfileAddBaby': 'Agregar otro bebé',
    'motherProfileNoBabies': 'No se encontró ningún bebé para este perfil.',
    'motherProfileBabyBornAt': 'Nacimiento: {date}',
    'plusBrandTitle': 'Premium de FaceBaby',
    'plusSheetHero':
        'Desbloquea informes, libro de recuerdos en PDF, más fotos y copia en la nube con un pago único.',
    'plusSheetPriceLabel': 'Pago único',
    'plusSheetBullets':
        '• Informes en PDF (sueño, rutina, crecimiento)\n• Libro de recuerdos en PDF\n• Exportar insignias (PNG / PDF)\n• Copia de seguridad en la nube entre dispositivos\n• Más recuerdos y fotos\n• Insights inteligentes en los informes\n• Informe para el pediatra\n• Estadísticas avanzadas\n• Temas premium del libro',
    'plusCtaSubscribe': 'Desbloquear ahora',
    'plusCtaRestore': 'Restaurar compra',
    'plusCtaLater': 'Ahora no',
    'plusSheetFootnote':
        'Pago único. Sin mensualidad. La compra se puede restaurar con la misma cuenta de la tienda.',
    'plusWelcomeSnack': 'Premium activado. Gracias por apoyar FaceBaby.',
    'plusPurchaseUnavailableSnack':
        'La compra no está disponible en este dispositivo.',
    'plusPurchaseSkuNotFoundSnack': 'Producto no encontrado en la tienda: {id}',
    'plusPurchaseBillingLaunchFailedSnack':
        'No se pudo abrir el pago. Inténtalo de nuevo.',
    'plusPaywallSkuMissingHint': 'Configura el producto en la tienda: {id}',
    'plusRestoreOkSnack': 'Compra restaurada.',
    'plusRestoreEmptySnack': 'No encontramos una compra para restaurar.',
    'plusSnackLockedFeature': 'Esta función forma parte de FaceBaby Premium.',
    'plusMemoryLimitSnack':
        'En el plan gratuito puedes guardar hasta {max} fotos en insignias.',
    'plusMemoryLimitDialogTitle': 'Desbloquea más recuerdos',
    'plusMemoryLimitDialogBody':
        'En el plan gratuito puedes guardar hasta {max} fotos en insignias.\n\nContrata FaceBaby Premium con pago único — sin mensualidad — para fotos ilimitadas, informes, exportaciones y más funciones del portal.',
    'plusMemoryLimitDialogSubscribe': 'Contratar Premium',
    'plusReportsLockedHint':
        'Los informes en PDF forman parte de FaceBaby Premium.',
    'plusExportLockedHint':
        'Exportar insignias forma parte de FaceBaby Premium.',
    'plusLifetimePaymentBadge': 'Pago único',
    'plusNoMonthlyBadge': 'Sin mensualidad',
    'plusPremiumActiveTitle': 'Gracias por Premium',
    'plusPremiumActiveBody':
        'Tienes todas las funciones premium activas para siempre en este dispositivo. Restaura compras cuando cambies de teléfono.',
    'plusPurchaseErrorSnack':
        'No se pudo completar la compra. Inténtalo de nuevo.',
    'plusDoneClose': 'Cerrar',
    'plusPaywallHeadline':
        'Cada plan fue pensado para\nacompañarte en cada etapa.',
    'plusPaywallActiveNote':
        'Tu Premium está activo. Puedes revisar los planes en cualquier momento.',
    'plusPaywallSecureNote':
        'Compra 100% segura. Puedes cancelar cuando quieras.',
    'plusPlanPremiumTitle': 'Premium',
    'plusPlanPremiumSubtitle':
        'Todo para cuidar y\nacompañar de la mejor manera',
    'plusPlanPremiumBadge': 'Más elegido',
    'plusPlanPremiumPriceSubActive': 'activo ahora',
    'plusPlanPremiumPriceSubSecure': 'compra segura',
    'plusPlanPremiumButtonActive': 'Plan actual',
    'plusPlanPremiumButton': 'Quiero Premium',
    'plusPlanPremiumFeature1': 'Todo lo del plan Gratuito',
    'plusPlanPremiumFeature2': 'Informes completos del bebé',
    'plusPlanPremiumFeature3':
        'Informe para el pediatra (útil para compartir con tu pediatra)',
    'plusPlanPremiumFeature4': 'Descripción de los signos',
    'plusPlanPremiumFeature5': 'Mensajes bíblicos diarios',
    'plusPlanPremiumFeature6': 'Análisis e insights del desarrollo',
    'plusPlanPremiumFeature7': 'Contenidos y consejos exclusivos',
    'plusPlanPremiumFeature8': 'Soporte prioritario',
    'plusPlanAiTitle': 'IA Niñera',
    'plusPlanAiSubtitle': 'Asistente inteligente\npara el día a día',
    'plusPlanAiBadge': 'Próximamente',
    'plusPlanAiFeature1': 'Todo lo del plan Premium',
    'plusPlanAiFeature2': 'IA Niñera 24h contigo',
    'plusPlanAiFeature3': 'Respuestas inteligentes',
    'plusPlanAiFeature4': 'Orientaciones personalizadas',
    'plusPlanAiFeature5': 'Alertas predictivas',
    'plusPlanAiFeature6': 'Rutinas personalizadas',
    'plusPlanAiFeature7': 'Contenidos generados por IA',
    'plusPlanAiPrice': 'Próximamente',
    'plusPlanAiPriceSub': '¡Mantente atenta!',
    'plusPlanAiButton': 'Quiero que me avisen',
    'plusPlanFreeTitle': 'Gratuito',
    'plusPlanFreeSubtitle': 'Comienza tu camino con lo esencial',
    'plusPlanFreePrice': '0,00 €',
    'plusPlanCurrent': 'Plan actual',
    'plusPlanFreeFeature1': 'Registros básicos',
    'plusPlanFreeFeature2': 'Registro diario',
    'plusPlanFreeFeature3': 'Agendas y recordatorios',
    'plusPlanFreeFeature4': 'Peso y altura',
    'plusTrustData': 'Tus datos\nsiempre seguros',
    'plusTrustFamily': 'Hecho con amor\npara familias',
    'plusTrustContent': 'Contenidos confiables\ny actualizados',
    'plusTrustSupport': 'Apoyo en cada\nmomento',
    'settingsPlusCardTitle': 'Premium de FaceBaby',
    'settingsPlusCardBodyFree':
        'PDFs, libro de recuerdos, más fotos, copia en la nube, informe al pediatra y estadísticas avanzadas — un único pago.',
    'settingsPlusCardBodyActive':
        'Tienes FaceBaby Premium activo — gracias por apoyar el proyecto.',
    'settingsPlusUpgradeCta': 'Desbloquear Premium',
    'settingsPlusManageCta': 'Ver Premium',
    'settingsPremiumBenefitsTitle': 'Beneficios de FaceBaby Premium',
    'settingsPremiumBannerHint': 'Toca para ver lo que incluye tu plan.',
    'authLoginTitle': 'Entrar',
    'authWelcome': 'Bienvenida',
    'authEmailLabel': 'Correo electrónico',
    'authPasswordLabel': 'Contraseña',
    'authForgotPassword': 'Olvidé mi contraseña',
    'authSignIn': 'Entrar',
    'authSigningIn': 'Entrando...',
    'authSignInGoogle': 'Entrar con Google',
    'authCreateAccount': 'Crear cuenta',
    'authForgotDialogTitle': 'Olvidé mi contraseña',
    'authForgotDialogBody':
        'Te enviaremos un enlace para restablecer tu contraseña.',
    'authForgotSend': 'Enviar',
    'authResetEmailSentSnackbar':
        'Correo enviado. Revisa tu bandeja de entrada.',
    'authRegisterAppBarTitle': 'Crear cuenta',
    'authRegisterTitle': 'Registro',
    'authRegisterNameLabel': 'Nombre (cómo quieres que te llamen)',
    'authRegisterPasswordLabel': 'Contraseña',
    'authRegisterSubmit': 'Crear cuenta',
    'authRegisterCreating': 'Creando...',
    'authValEmailRequired': 'Introduce tu correo',
    'authValEmailInvalid': 'Correo no válido',
    'authValPasswordRequired': 'Introduce tu contraseña',
    'authValPasswordMin6': 'Mínimo 6 caracteres',
    'authValNameRequired': 'Introduce tu nombre',
    'authValNameShort': 'Nombre demasiado corto',
    'authErrWeakPassword': 'Contraseña débil. Usa al menos 6 caracteres.',
    'authErrInvalidEmail': 'Correo no válido.',
    'authErrUserDisabled': 'Esta cuenta fue desactivada.',
    'authErrUserNotFound': 'No hay cuenta con ese correo.',
    'authErrWrongPassword': 'Contraseña incorrecta.',
    'authErrEmailInUse': 'Ya existe una cuenta con ese correo.',
    'authErrInvalidCredential': 'Credenciales no válidas. Inténtalo de nuevo.',
    'authErrCredentialsGeneric':
        'No se pudo iniciar sesión. Inténtalo de nuevo.',
    'authErrGoogleConfigAndroid':
        'El inicio con Google falló por configuración de la app (error 10).\n\n'
            '1) Firebase: Ajustes del proyecto → app Android → añade el SHA-1 del keystore de depuración.\n'
            '2) En la carpeta android ejecuta: gradlew signingReport y copia el SHA-1 "debug".\n'
            '3) Autenticación → activa Google.\n'
            '4) Vuelve a descargar google-services.json en android/app/.',
    'authErrLoginCancelled': 'Inicio de sesión cancelado.',
    'authErrAppleFailed':
        'No se pudo iniciar sesión con Apple. Inténtalo de nuevo u otro método.',
    'authErrAppleUnavailable':
        'Iniciar sesión con Apple solo está disponible en iPhone o iPad.',
    'authErrUnexpected': 'Ocurrió un error inesperado.',
    'onbSelectDate': 'Seleccionar fecha',
    'onbBabyFallback': 'bebé',
    'onbMomFallback': 'mamá',
    'onbDadFallback': 'papá',
    'onbWelcomeTitle': 'Acompañando y monitoreando',
    'onbWelcomeSubtitle': 'el desarrollo con Amor.',
    'onbFeatureSleep': 'Sueño',
    'onbFeatureFeeding': 'Alimentación',
    'onbFeatureGrowth': 'Crecimiento',
    'onbFeatureMemories': 'Recuerdos',
    'onbFeatureAlerts': 'Alertas',
    'onbFeatureLove': 'Mucho Amor',
    'onbCreateBabyProfile': 'Crear perfil del bebé',
    'onbExistingAccountLogin': 'Ya tengo una cuenta / Iniciar sesión',
    'onbContinue': 'Continuar',
    'onbPrepareFaceBaby': 'Preparar FaceBaby',
    'onbPreparingTitle': 'Preparando FaceBaby para ti...',
    'onbPreparingSubtitle':
        'Personalizando alertas, recuerdos y rutina del bebé.',
    'onbAuthTitle': 'Tu perfil básico está listo',
    'onbAuthSubtitle':
        'Ahora crea tu cuenta para guardar todo con seguridad y sincronizar después.',
    'onbSignInGoogle': 'Entrar con Google',
    'onbSignInApple': 'Entrar con Apple',
    'onbContinueEmail': 'Continuar con correo',
    'onbAlreadyHaveAccount': 'Ya tengo cuenta',
    'onbWait': 'Espera...',
    'onbDoneTitle': '¡Listo! El perfil del bebé fue creado.',
    'onbStartTracking': 'Empezar a acompañar',
    'onbCouldNotPrepare':
        'No se pudo preparar el perfil ahora. Inténtalo de nuevo.',
    'onbBabyNameTitle': '¿Cuál es el nombre del bebé?',
    'onbBabyNameSubtitle':
        'Vamos a hacer que FaceBaby tenga la carita de tu familia.',
    'onbBabyNameHint': 'Nombre del bebé',
    'onbBabyBirthTitle': '¿Cuál es la fecha de nacimiento?',
    'onbBabyBirthSubtitle':
        'Usamos la edad para personalizar sueño, rutina y crecimiento.',
    'onbBabyWeightTitle': '¿Cuál es el peso del bebé?',
    'onbBabyWeightSubtitle':
        'Arrastra la regla para elegir. Puedes alternar entre Kg y Lb.',
    'onbBabyHeightTitle': '¿Cuál es la altura del bebé?',
    'onbBabyHeightSubtitle':
        'Usa la regla para indicar el tamaño aproximado en la unidad que prefieras.',
    'onbMotherNameTitle': '¿Cuál es el nombre de mamá?',
    'onbMotherNameSubtitle': 'Usaremos su nombre en las próximas preguntas.',
    'onbMotherNameHint': 'Nombre de mamá',
    'onbMotherBirthTitle': '¿Cuál es la fecha de nacimiento de mamá?',
    'onbMotherBirthSubtitle': 'Después preguntaremos su altura.',
    'onbMotherHeightTitle': '¿Cuál es la altura de {name}?',
    'onbMotherHeightSubtitle':
        'Esta información ayuda en los informes de crecimiento.',
    'onbRegisterFatherTitle': '¿Deseas registrar también al papá?',
    'onbRegisterFatherSubtitle':
        'Si quieres, FaceBaby también personaliza los datos de papá.',
    'onbFatherNameTitle': '¿Cuál es el nombre de papá?',
    'onbFatherNameSubtitle': 'Así su regla también queda personalizada.',
    'onbFatherNameHint': 'Nombre de papá',
    'onbFatherBirthTitle': '¿Cuál es la fecha de nacimiento de papá?',
    'onbFatherBirthSubtitle': 'Después preguntaremos su altura.',
    'onbFatherHeightTitle': '¿Cuál es la altura de {name}?',
    'onbFatherHeightSubtitle':
        'Puede ser aproximada; puedes ajustarla después.',
    'onbBabySexTitle': '¿Cuál es el sexo del bebé?',
    'onbSexGirl': 'Niña',
    'onbSexBoy': 'Niño',
    'onbSexUnknown': 'Prefiero no informar',
    'onbFirstBabyTitle': '¿Es tu primer bebé?',
    'onbYes': 'Sí',
    'onbNo': 'No',
    'onbConcernTitle': '¿Cuál es tu mayor preocupación ahora?',
    'onbConcernSubtitle': 'Puedes elegir más de una.',
    'onbConcernSleep': 'Sueño del bebé',
    'onbConcernFeeding': 'Lactancia/alimentación',
    'onbConcernGrowth': 'Peso y crecimiento',
    'onbConcernRoutine': 'Rutina del día',
    'onbConcernMemories': 'Recuerdos y fotos',
    'onbConcernDevelopment': 'Desarrollo',
    'onbGoalsTitle': '¿Cuáles son tus objetivos?',
    'onbGoalsSubtitle': 'Usaremos esto para personalizar tu experiencia.',
    'onbGoalRoutine': 'Acompañar mejor la rutina',
    'onbGoalSleepAlerts': 'Recibir alertas de sueño',
    'onbGoalMoments': 'Registrar momentos especiales',
    'onbGoalReports': 'Generar informes',
    'onbGoalMemoryBook': 'Crear libro de recuerdos',
    'onbMessagePrefTitle': 'Mamá espiritualizada, bebé feliz.',
    'onbMessagePrefSubtitle': '¿Deseas recibir mensajes diarios?',
    'onbMessagePrefChristian': 'Cristiana',
    'onbMessagePrefHoroscope': 'Astrológica',
    'onbMessagePrefPhilosophical': 'Filosófica / Ecuménica',
    'onbMessagePrefSpiritist': 'Espíritas',
    'onbMessagePrefJewish': 'Judías',
    'onbMessagePrefAll': 'Todas',
    'onbDragToAdjust': 'Arrastra para ajustar',
    'onbEmailSheetTitle': 'Crear cuenta con correo',
    'onbYourNameHint': 'Tu nombre',
    'onbEmailHint': 'Correo electrónico',
    'onbPasswordHint': 'Contraseña',
    'onbCreateAccount': 'Crear cuenta',
    'onbValYourName': 'Informa tu nombre.',
    'onbValEmailRequired': 'Informa tu correo.',
    'onbValEmailInvalid': 'Correo inválido.',
    'onbValPasswordMin': 'Usa al menos 6 caracteres.',
    'vaccinesTitle': 'Vacunas',
    'vaccinesSubtitle': 'Agrega vacunas, fechas y próximas dosis.',
    'baby': 'Bebé',
    'selectBaby': 'Seleccionar bebé',
    'addVaccine': 'Agregar vacuna',
    'recordsTitle': 'Registros',
    'noVaccinesYet': 'Aún no hay vacunas.',
    'seeAll': 'Ver todo',
    'changePhoto': 'Cambiar foto',
    'motherPhotoTitle': 'Foto de mamá',
    'babyPhotoTitle': 'Foto del bebé',
    'familyTitle': 'Familia',
    'familySubtitle': 'Árbol familiar, signos y mensajes del día.',
    'familyEdit': 'Editar',
    'familyEditData': 'Editar datos >',
    'familyTabMotherLabel': 'Mamá',
    'familyTabFatherLabel': 'Papá',
    'familyRoleMother': 'Mamá',
    'familyRoleFather': 'Papá',
    'familyRoleBaby': 'Bebé',
    'familyZodiacSolar': 'Signo solar',
    'familyEntertainmentNote':
        'Completa los datos de nacimiento para personalizar este contenido.',
    'familyChristianCardTitle': 'Mensaje bíblico',
    'familySpiritistCardTitle': 'Mensaje espírita',
    'familyJewishCardTitle': 'Mensaje judío',
    'familyChristianLine': 'Versículo del día · {ref}',
    'familyBornOn': 'Nac. {date}',
    'familyAgeOneYear': '1 año',
    'familyAgeYears': '{n} años',
    'familyHeight': '{value}',
    'familyMotherBlurb':
        'Como mamá de {sign}, puede mostrar rasgos como {traits}.',
    'familyFatherBlurb':
        'Como papá de {sign}, puede mostrar rasgos como {traits}.',
    'familyBabyBlurb':
        'Como bebé de {sign}, puede mostrar rasgos como {traits}.',
    'familyZodiacName_capricorn': 'Capricornio',
    'familyZodiacName_aquarius': 'Acuario',
    'familyZodiacName_pisces': 'Piscis',
    'familyZodiacName_aries': 'Aries',
    'familyZodiacName_taurus': 'Tauro',
    'familyZodiacName_gemini': 'Géminis',
    'familyZodiacName_cancer': 'Cáncer',
    'familyZodiacName_leo': 'Leo',
    'familyZodiacName_virgo': 'Virgo',
    'familyZodiacName_libra': 'Libra',
    'familyZodiacName_scorpio': 'Escorpio',
    'familyZodiacName_sagittarius': 'Sagitario',
    'familyZodiacTrait_capricorn': 'disciplinado y responsable',
    'familyZodiacTrait_aquarius': 'curioso e independiente',
    'familyZodiacTrait_pisces': 'sensible e imaginativo',
    'familyZodiacTrait_aries': 'valiente y lleno de energía',
    'familyZodiacTrait_taurus': 'tranquilo y afectuoso',
    'familyZodiacTrait_gemini': 'comunicativo y curioso',
    'familyZodiacTrait_cancer': 'cariñoso y protector',
    'familyZodiacTrait_leo': 'alegre y expresivo',
    'familyZodiacTrait_virgo': 'observador y cuidadoso',
    'familyZodiacTrait_libra': 'dulce y sociable',
    'familyZodiacTrait_scorpio': 'intenso y afectuoso',
    'familyZodiacTrait_sagittarius': 'alegre y explorador',
    'familyFatherDataComplete': 'Datos del papá completos y actualizados',
    'familyFatherDataIncomplete': 'Datos del papá aún incompletos',
    'familyAddFatherPrompt':
        '¿Quieres añadir los datos del papá? Complétalos para ver la altura estimada de tu bebé.',
    'familyAddFatherButton': 'Añadir datos del papá',
    'familyCompleteBabySex':
        'Informa el sexo del bebé en el registro para calcular la altura estimada.',
    'familyEditBabyData': 'Editar datos del bebé',
    'familyCompleteHeights':
        'Para la estimación necesitamos la altura de mamá y papá.',
    'familyCompleteHeightsButton': 'Completar alturas',
    'familyEstimatedHeightTitle': 'Altura estimada de {name}',
    'familyMotherHeightLabel': 'Altura de mamá',
    'familyFatherHeightLabel': 'Altura de papá',
    'familyEstimatedGirl': 'Altura estimada para niña',
    'familyEstimatedBoy': 'Altura estimada para niño',
    'familyEstimatedResult': 'aproximadamente {cm}',
    'familyHowCalculated': '¿Cómo se calcula?',
    'familyFormulaBoy':
        'Niño: (altura del padre + altura de la madre + 13) ÷ 2',
    'familyFormulaGirl':
        'Niña: (altura del padre + altura de la madre − 13) ÷ 2',
    'familyEstimatedHeightDescription':
        'Estimación basada en la altura de la madre y del padre, ajustada por el sexo del bebé. No considera factores ambientales, nutricionales, de salud ni otros. Solo como referencia orientativa.',
    'familyFormulaExampleGirl': '({father} + {mother} − 13) ÷ 2 = {result} cm',
    'familyFormulaExampleBoy': '({father} + {mother} + 13) ÷ 2 = {result} cm',
    'familyHeightDisclaimer':
        'Esta es una estimación simple usada como referencia en pediatría. La altura final puede variar por genética, alimentación, sueño, salud, pubertad y otros factores.',
    'familyZodiacReadMore': 'Leer texto completo',
    'familyPremiumZodiacLocked':
        'Los signos solares y textos personalizados son exclusivos de FaceBaby Premium.',
    'familyPremiumHeightLocked':
        'La altura adulta estimada es exclusiva de FaceBaby Premium.',
    'familyPremiumUnlockCta': 'Desbloquear Premium',
    'familyScreenTitle': 'Familia 💜',
    'familyPersonalInfoTitle': 'Información personal',
    'familyHoroscopeCardTitle': 'Astrologia de {sign}',
    'familyBibleVerseCardTitle': 'Versículo Bíblico de hoy.',
    'familyDailySummaryTitle': 'Resumen del día',
    'familySummaryFeeding': 'Lactancia',
    'familySummaryDiapers': 'Pañales',
    'familySummarySleep': 'Sueño',
    'familySummaryWeight': 'Peso',
    'familyQuickLabelBirth': 'Nac.',
    'familyQuickLabelTime': 'Hora',
    'familySummaryFeedingsToday': '{n} tomas',
    'familySummaryDiaperChangesCount': '{n} cambios',
    'familySummaryLastAt': 'Última a las {time}',
    'familySummaryLastSleepAt': 'Último a las {time}',
    'familySummaryWeightDayLine': 'Día seleccionado',
    'familyFieldBirthDate': 'Nacimiento',
    'familyFieldSign': 'Signo',
    'familyFieldElement': 'Elemento',
    'familyFieldAge': 'Edad',
    'familyFieldHeight': 'Altura',
    'familyFieldWeight': 'Peso',
    'familyPremiumShortBadge': 'Premium',
    'familyPremiumFeatureLockedBody':
        'Contenido exclusivo para familias Premium.',
    'familyPremiumBannerTitle': 'Desbloquea contenidos Premium',
    'familyPremiumBannerBody':
        'Accede a descripciones de signos, altura estimada y contenidos personalizados.',
    'familyPremiumViewPlans': 'Ver planes',
    'familyAddFatherCardTitle': 'Añadir papá',
    'familyElementFire': 'Fuego',
    'familyElementEarth': 'Tierra',
    'familyElementAir': 'Aire',
    'familyElementWater': 'Agua',
    'familyTapToOpen': 'Toca para ver detalles',
    'familyCarouselSwipe': 'Desliza para cambiar de familiar',
    'familyTabNene': 'Bebé',
    'familyTabsHint': 'Toca una foto para cambiar de familiar',
    'familyTapToClose': 'Toca para cerrar',
    'familyShareCard': 'Compartir tarjeta',
    'changeBabyTooltip': 'Cambiar bebé',
    'notificationsInboxTitle': 'Notificaciones',
    'notificationsInboxSubtitle':
        'Últimos 3 días (entregadas y programadas, registradas en la app)',
    'notificationsEmpty':
        'Aún no hay notificaciones registradas en este período.',
    'notificationsKindShown': 'Entregada',
    'notificationsKindScheduled': 'Programada',
    'notificationsOpenTarget': 'Toca para abrir',
    'notificationsSelectAll': 'Seleccionar todo',
    'deleteAccountTitle': 'Eliminar cuenta',
    'deleteAccountBody':
        'Esto eliminará tu cuenta y TODOS tus datos (mamá, bebé y registros) de la nube.\n\nEsta acción no se puede deshacer.',
    'deleteAccountConfirm': 'Eliminar todo',
    'deleteAccountDeleting': 'Eliminando tu cuenta...',
    'deleteAccountSuccess': 'Cuenta eliminada con éxito.',
    'deleteAccountReauthTitle': 'Confirmar contraseña o Google',
    'deleteAccountReauthBody':
        'Último paso antes de eliminar: confirma el mismo método con el que entras (contraseña del correo o cuenta Google/Gmail).',
    'deleteAccountReauthGoogleSection': 'Entraste con Google / Gmail',
    'deleteAccountReauthGoogleAccountHint': 'Cuenta Google: {email}',
    'deleteAccountReauthPasswordSection': 'Entraste con correo y contraseña',
    'deleteAccountReauthOrDivider': 'o',
    'deleteAccountReauthEmailLabel': 'Correo de la cuenta',
    'deleteAccountReauthPasswordHint': 'Contraseña actual',
    'deleteAccountReauthPasswordRequired':
        'Escribe la contraseña actual de la cuenta.',
    'deleteAccountReauthGoogle': 'Confirmar con Google (Gmail)',
    'deleteAccountReauthContinue': 'Confirmar con contraseña',
    'deleteAccountReauthCantPassword':
        'Usa el botón del mismo método de acceso (Google/Gmail o correo y contraseña) con el que creaste la cuenta.',
    'deleteAccountTypeWordTitle': 'Confirmación final',
    'deleteAccountTypeWordInstruction':
        'Para eliminar la cuenta de forma permanente, escribe delete en el campo. Después pediremos confirmación con contraseña o Google (Gmail).',
    'deleteAccountTypeWordFieldLabel': 'delete',
    'homeBabyBannerForecastSleep': 'Previsión de sueño',
    'homeBabyBannerForecastWake': 'Previsión de despertar',
    'homeBabyBannerForecastSubtitleSleep':
        'Señales de sueño detectadas\nsegún la hora actual',
    'homeBabyBannerForecastSubtitleWake':
        'Según la hora actual y el patrón por edad',
    'homeBabyBannerEtaIn': 'en {d}',
    'homeBabyBannerLastDiaper': 'Último pañal',
    'homeBabyBannerNoRecordsYet': 'Sin registros todavía',
    'homeBabyBannerNextBetween': 'Próxima entre {range}',
    'homeBabyBannerDiaperRecommendedUntil': 'Cambio recomendado hasta {d}',
    'homeBabyBannerIdealWindow': 'Ventana ideal: {range}',
    'homeConsultationScheduled': 'Cita programada',
    'homeBannerChipConsultation': 'Cita',
    'homeBannerChipDiaper': 'Pañal',
    'homeBannerChipFeed': 'Tomar',
    'homeBannerChipSleep': 'Sueño',
    'homeBannerOverdueSleep': 'Ya pasó la hora de dormir',
    'homeBannerOverdueWake': 'Ya pasó la hora de despertar',
    'homeBannerHungry': 'Hambriento',
    'homeBannerDiaperDirty': 'Puede estar sucio',
    'homeBannerExhausted': 'AGOTADO',
    'homeBannerChipVaccine': 'Vacuna hoy',
    'homeMotivationBanner':
        '¡Lo estás haciendo muy bien! Pequeños registros, grandes recuerdos.',
    'homeMotivationBannerOpenMemories': 'Abrir libro de recuerdos',
    'healthHubTitle': 'Salud',
    'healthHubIntro':
        'Vacunas, consultas y cuidados del bebé en un solo lugar.',
    'healthHubSection': 'Acceso rápido',
    'healthHubVaccines': 'Cartilla de vacunación',
    'healthHubVaccinesSub': 'Registra y revisa las vacunas del bebé',
    'vaccDueConfirmCheckbox': 'Confirmo que esta dosis ya fue aplicada.',
    'vaccDueSavedOk': 'Vacuna registrada como aplicada.',
    'vaccDuePickTitle': 'Vacunas previstas para hoy',
    'homeSummaryHealthStripTitle': 'Vacunas y consultas en este día',
    'homeSummaryHealthStripEmpty':
        'No hay vacunas ni consultas registradas en este día.',
    'memoryTellMomentTitle': 'Cuenta sobre este momento',
    'memoryTellMomentHint': '¿Cómo fue? Comparte detalles que quieres guardar…',
    'memoryBabyInfoOptionalTitle': 'Información del bebé (opcional)',
    'memoryBabyMoodLabel': 'Ánimo/estado',
    'memoryBabyMoodHint': 'Ej: Feliz',
    'memoryMomentInfoTitle': 'Información del momento',
    'memoryStatAgeLabel': 'Edad',
    'memoryStatWeightLabel': 'Peso',
    'memoryStatHeightLabel': 'Altura',
    'memoryStatMoodLabel': 'Cómo estaba',
    'memoryMotherNotesLabel': 'Notas de mamá',
    'memoryTipForYouTitle': 'Un consejo para ti',
    'memoryShareButton': 'Compartir',
    'memoryFavoriteButton': 'Favorito',
    'memoryFavoritedButton': 'En favoritos',
    'weeklyPhotoPublicExplainer':
        'Al marcarla como pública, esta foto podrá participar en la Foto de la Semana y podrá ser vista por otras mamás dentro de FaceBaby.',
    'weeklyPhotoPublicOff': 'Privada',
    'weeklyPhotoPublicOn': 'Pública',
    'weeklyPhotoPublicNeedPhoto':
        'Añade una foto para marcar este recuerdo como público.',
    'weeklyPhotoConfirmTitle': '¿Hacer pública esta foto?',
    'weeklyPhotoConfirmBody':
        '¿Aceptas mostrar esta foto a otros usuarios si resultas sorteada de la semana?',
    'weeklyPhotoConfirmNo': 'No',
    'weeklyPhotoConfirmYes': 'Sí',
    'weeklyPhotoParticipatingBadge': 'Participando en la Foto de la Semana',
    'weeklyPhotoWinnerBadge':
        'Este recuerdo fue elegido como Foto de la Semana 💜',
    'weeklyPhotoShowBabyFirstName':
        'Mostrar el primer nombre del bebé en el mural público',
    'weeklyPhotoDisclaimerFooter':
        'Solo participan las fotos marcadas como públicas. Puedes quitar esta opción en cualquier momento.',
    'weeklyPhotoReportLink': 'Denunciar',
    'weeklyPhotoReportTitle': 'Denunciar foto',
    'weeklyPhotoReportHint':
        'Describe el motivo de la denuncia. El equipo FaceBaby lo revisará.',
    'weeklyPhotoReportMessageLabel': 'Motivo de la denuncia',
    'weeklyPhotoReportSubmit': 'Enviar denuncia',
    'weeklyPhotoReportSuccess':
        'Denuncia enviada. Gracias por ayudar a mantener la comunidad segura.',
    'weeklyPhotoReportNeedLogin':
        'Inicia sesión en tu cuenta para enviar una denuncia.',
    'weeklyPhotoReportMessageTooShort':
        'Escribe al menos 5 caracteres en el motivo de la denuncia.',
    'weeklyPhotoReportMessageTooLong':
        'El texto de la denuncia es demasiado largo.',
    'weeklyPhotoReportFailed':
        'No se pudo enviar la denuncia. Inténtalo de nuevo.',
    'weeklyPhotoSectionTitleMale': 'Príncipe de la Semana',
    'weeklyPhotoSectionTitleFemale': 'Princesa de la Semana',
    'weeklyPhotoHomeHeroMale': 'PRÍNCIPE DE LA SEMANA',
    'weeklyPhotoHomeHeroFemale': 'PRINCESA DE LA SEMANA',
    'weeklyPhotoSectionSubtitle':
        'Un recuerdo especial compartido por una mamá de FaceBaby.',
    'weeklyPhotoViewMemory': 'Ver recuerdo',
    'weeklyPhotoBabyFallback': 'Un bebé FaceBaby',
    'weeklyPhotoDisclaimerShort':
        'Solo participan las fotos marcadas como públicas. Puedes quitar esta opción en cualquier momento.',
    'weeklyPhotoPublicDetailAppBar': 'Recuerdo de la semana',
    'weeklyPhotoWinnerCongratsTitle': '¡Felicidades, Mamá!',
    'weeklyPhotoWinnerCongratsBody':
        'La foto de tu Princesa fue la elegida de la semana. Vamos todos a celebrarla.\n\n¡La familia FaceBaby agradece que compartas este hermoso momento con nosotros! 💜',
    'weeklyPhotoWinnerCongratsBodyMale':
        'La foto de tu Príncipe fue la elegida de la semana. Vamos todos a celebrarlo.\n\n¡La familia FaceBaby agradece que compartas este hermoso momento con nosotros! 💜',
    'weeklyPhotoWinnerCongratsBodyFemale':
        'La foto de tu Princesa fue la elegida de la semana. Vamos todos a celebrarla.\n\n¡La familia FaceBaby agradece que compartas este hermoso momento con nosotros! 💜',
    'weeklyPhotoWinnerCongratsOk': 'Confirmar',
    'memoryEditTitle': 'Editar recuerdo',
    'memoryNewTitle': 'Nuevo recuerdo',
    'memoryMomNotesFieldLabel': 'Observaciones de mamá',
    'memorySaveChanges': 'Guardar cambios',
    'memorySaveNew': 'Guardar recuerdo',
    'memoryNoDescription': 'Sin descripción para este momento.',
    'memoryPhotoAddTitle': 'Añade una foto',
    'memoryPhotoEditTitle': 'Cambiar la foto',
    'memoryTapToPickPhoto': 'Toca',
    'memoryAgeHintExample': 'Ej.: 10 días',
    'memoryWeightHintExample': 'Ej.: 3,28',
    'memoryHeightHintExample': 'Ej.: 49',
    'memorySaveNeedPhotoOrText':
        'Añade una foto o una descripción para guardar.',
    'memorySaveFail': 'No se pudo guardar:',
    'memoryShareWebOnlyMobile':
        'Compartir imagen o PDF está disponible en la app instalada (Android/iOS).',
    'memoryShareSheetJpegTitle': 'Imagen (JPG)',
    'memoryShareSheetJpegSubtitle':
        'Elige WhatsApp, correo, Bluetooth… en la hoja del sistema',
    'memoryShareSheetPdfTitle': 'PDF (una página)',
    'memoryShareSheetPdfSubtitle': 'Útil para correo o archivo',
    'memorySharePlatformUnavailable': 'No disponible en esta plataforma.',
    'memoryShareError': 'No se pudo compartir: {error}',
    'memoryFooterBranding': 'FaceBaby • Libro de recuerdos',
    'memoryTipFirstSmile':
        'Sonreír es una de las primeras formas de vínculo. ¡Sigue hablando y sonriendo!',
    'memoryTipFirstLaugh':
        'La risa refuerza el vínculo. Repite juegos que le hagan reír.',
    'memoryTipFirstFeeding':
        'Los primeros días de lactancia son de adaptación. Si dudas, pide ayuda pediátrica o de lactancia.',
    'memoryTipFirstSteps':
        'Cada bebé tiene su ritmo. Ofrece un espacio seguro sin presión.',
    'memoryTipDefault':
        'Momentos así quedan en la familia para siempre. Sigue registrando lo importante.',
    'memoryAgeOneDay': '1 día',
    'memoryAgeManyDays': '{n} días',
    'helloMomNamed': '¡Hola, Mamá {name}!',
    'registerVerb': 'Registrar',
    'viewCalendar': 'Ver calendario',
    'shortcutMilk': 'Lactancia',
    'shortcutSleep': 'Sueño',
    'shortcutVaccines': 'Vacunas',
    'shortcutFamily': 'Familia',
    'shortcutFamilyHomeSub': 'Árbol y perfil familiar',
    'shortcutHealthHomeSub': 'Vacunas, consultas y síntomas',
    'shortcutFeedingSession': 'Alimentación',
    'homeFedAgo': 'Comió hace {when}',
    'homePeeAgo': 'Pipi hace {when}',
    'homePooAgo': 'Popó hace {when}',
    'homeNextNow': 'Próxima: ahora.',
    'homeNextIn': 'Próxima en {n} min.',
    'homeStatusOk': 'Todo bien ahora',
    'homeStatusWarn': 'Alerta leve',
    'homeStatusHungry': 'Puede tener hambre',
    'homeTipTitle': 'Consejo de hoy',
    'homeTipBody':
        'Rutinas suaves ayudan a {name} a dormir mejor por la noche.',
    'homeYesterdayBabaTitle': 'IA Niñera · ayer',
    'homeYesterdayBabaFallback':
        'Registra la rutina de {name} para lectura pediátrica.',
    'homeYesterdayBabaRoutineQuiet':
        'Pocos registros — la rutina predecible favorece la regulación emocional.',
    'homeYesterdayBabaRoutine':
        '{feeds} tomas · sueño {sleep} · {diapers} pañales.',
    'homeYesterdayBabaRoutineLowSleep':
        '{feeds} tomas · sueño {sleep} (bajo) · {diapers} pañales.',
    'homeYesterdayBabaGrowthBothWithin':
        'Peso y talla en la curva de referencia.',
    'homeYesterdayBabaGrowthNoData': 'Actualiza peso/talla en la curva.',
    'homeYesterdayBabaGrowthBelow':
        'Antropometría bajo la curva — coméntalo con el pediatra.',
    'homeYesterdayBabaGrowthAbove':
        'Antropometría sobre la curva — revisa en la consulta.',
    'homeYesterdayBabaGrowthCombo': 'Curva: peso {weight}, talla {height}.',
    'homeYesterdayBabaBandWithin': 'adecuado',
    'homeYesterdayBabaBandBelow': 'bajo',
    'homeYesterdayBabaBandAbove': 'alto',
    'homeYesterdayBabaBandUnknown': '—',
    'homeGreetingSubtitle': '¡Qué bueno verte por aquí hoy!',
    'summaryWeightNotYet': 'Aún no registrado',
    'summarySleepNotYet': 'Sin sueño registrado hoy',
    'shortcutMilkHomeSub': 'Registrar lactancia',
    'shortcutGrowthHomeSub': 'Registrar peso y altura',
    'shortcutSleepHomeSub': 'Registrar sueño',
    'homeTileDiapers': 'Cambios de pañal',
    'homeOneDayOld': '1 día',
    'homeDaysOld': '{d} días',
    'babyAgeOneWeek': '1 semana',
    'babyAgeWeeks': '{n} semanas',
    'babyAgeOneMonth': '1 mes',
    'babyAgeMonths': '{n} meses',
    'babyAgeOneYear': '1 año',
    'babyAgeYears': '{n} años',
    'summaryFeedings': 'TOMAS',
    'summarySleep': 'SUEÑO TOTAL',
    'summaryLastFeed': 'Última a las {time}',
    'summaryLastSleep': 'Último a las {time}',
    'summaryDiapers': 'PAÑALES',
    'summaryFeedingsValue': '{n} · {m} min',
    'summaryFeedingsCountOne': '1 toma',
    'summaryFeedingsCountMany': '{n} tomas',
    'summaryFeedingsMinutes': '{m} min',
    'summaryDiapersValue': 'Total {total} · Pipí {pee} · Popó {poo}',
    'summaryDiapersTotal': 'Total {total} cambios',
    'summaryDiapersChangesOne': '1 cambio',
    'summaryDiapersChangesMany': '{n} cambios',
    'summaryDiapersPeePoo': '{pee} - Pipí    {poo} - Popó',
    'summarySleepValue': '{s} · {t}',
    'summarySleepSessionsOne': '1 siesta',
    'summarySleepSessionsMany': '{s} siestas',
    'summaryWeight': 'PESO',
    'homeSummaryExtraHint': 'Totales del día seleccionado',
    'add': 'Agregar',
    'labelWeight': 'Peso',
    'labelHeight': 'Altura',
    'labelHead': 'Perímetro de la cabeza',
    'growthTabWeight': 'Peso',
    'growthTabHeight': 'Altura',
    'growthTabHead': 'Cabeza',
    'growthTabSummary': 'Resumen',
    'growthAtBirth': 'Al nacer',
    'growthCardCurrent': 'Actual',
    'growthCardChange': 'Cambio',
    'growthAddWeight': 'Agregar peso',
    'growthAddHeight': 'Agregar altura',
    'growthAddHead': 'Agregar cabeza',
    'growthSummaryIntro': 'Visión general de peso y altura.',
    'growthChartCaption': '{name} — {metric}',
    'growthChartDeltaHint':
        'Eje vertical: variación respecto al valor al nacer (0 = al nacer).',
    'growthHistoryTitle': '{label} (historial)',
    'invalidGrowthValue': 'Introduce un valor válido de {label}.',
    'growthSaved': '{label} guardado correctamente.',
    'growthEmpty': 'Aún no hay registros de {label}.',
    'exampleCard': 'Ejemplo de cartilla:',
    'reportDailyScreenTitle': 'Informe diario',
    'reportDayDetailsTitle': 'Detalles del día',
    'reportDailyPickDayTooltip': 'Elegir día',
    'reportDailySubtitleSleepQuality': 'Calidad del sueño',
    'reportDailySubtitleTotalSleep': 'Total dormido',
    'reportDailySubtitleLongestStretch': 'Mayor periodo continuo',
    'reportDailySubtitleFeedTotal': 'Total de tomas',
    'reportDailySubtitleFeedAvg': 'Duración media',
    'reportDailySubtitleFeedLast': 'Última toma',
    'reportDailySubtitleDiaperTotal': 'Total de cambios',
    'reportDailySubtitleDiaperWet': 'Pañales mojados',
    'reportDailySubtitleDiaperDirty': 'Pañales sucios',
    'reportDailySubtitleMoodMajority': 'La mayor parte del día',
    'reportDailySubtitleMoodIrrit': 'Irritabilidad',
    'reportDailySubtitleWeightLast': 'Última medición',
    'reportSleepQualityGood': 'Buena',
    'reportSleepQualityOk': 'Ok',
    'reportSleepQualityBad': 'Frágil',
    'reportSleepQualityMixed': 'Variable',
    'reportVsYesterdayShort': 'vs ayer',
    'reportVsYesterdayNA': '—',
    'reportVsYesterdayPct': '{pct}%',
    'reportLongestStretchHint': '{start} – {end}',
    'reportNapsLabel': 'Siestas',
    'reportTotalSmallLabel': 'Total',
    'reportComparedAgeLabel': 'Comparado con la media de la edad',
    'reportBenchmarkAbove': 'Por encima de la media',
    'reportBenchmarkNear': 'Cerca de la media',
    'reportBenchmarkBelow': 'Por debajo de la media',
    'reportIrritLow': 'Baja',
    'reportIrritMedium': 'Moderada',
    'reportIrritHigh': 'Alta',
    'reportIrritUnknown': 'Sin datos',
    'reportTabSleep': 'Sueño',
    'reportTabFeedings': 'Tomas',
    'reportTabDiapers': 'Pañales',
    'reportTabMood': 'Ánimo',
    'reportAiInsightsTitle': 'Insights',
    'reportTimelineTitle': 'Línea de tiempo del día',
    'reportShareSoon': 'Compartir (pronto)',
    'reportFeedingChartCaption': 'Tomas por hora',
    'reportSleepChartCaption': 'Sueño por hora',
    'reportNoDataHint': 'No hay registros suficientes para esta métrica.',
    'reportInsightSleepAgeGood':
        'El sueño total está cerca de lo esperado para la edad — buena señal de descanso reparador.',
    'reportInsightSleepAgeLow':
        'El sueño quedó por debajo de lo habitual para esta edad; observa señales de cansancio y la rutina nocturna.',
    'reportInsightFeedsOften':
        'Muchas tomas durante el día — común en etapas de crecimiento; registrar la duración ayuda a ver promedios.',
    'reportInsightDiapersFrequent':
        'Cambios de pañal frecuentes — puede indicar buena hidratación o necesidad de cuidar la piel; observa si son de pipí o popó.',
    'reportInsightMoodLine':
        'Ánimo predominante guardado en recuerdos: {mood}.',
    'reportWeeklyScreenTitle': 'Informe semanal',
    'reportWeekDetailsTitle': 'Detalles de la semana',
    'reportWeeklyPickWeekTooltip': 'Elegir semana (cualquier día)',
    'reportWeeklySummaryTitle': 'Resumen de la semana',
    'reportWeeklyTrendsTitle': 'Tendencias',
    'reportWeeklySeeFullDetails': 'Ver informe completo',
    'reportWeeklyPartialWeekHint':
        'Promedios y tendencias: lunes a {weekday} (semana hasta ahora).',
    'reportWeeklyFutureWeekHint':
        'Esta semana aún no empezó en el calendario — elige otra semana o vuelve cuando haya días registrados.',
    'reportWeeklyLoadErrorPrefix': 'No se pudo cargar el informe:',
    'reportWeeklyToneCalm': 'tranquila',
    'reportWeeklyToneActive': 'movida',
    'reportWeeklySleepUnknown':
        'No hay suficientes datos de sueño para comparar semanas.',
    'reportWeeklyFirstWeekSleepLine':
        'Esta es la primera semana con registros: sigue anotando para ver tendencias pronto.',
    'reportWeeklySleepStableShort':
        'El sueño se mantuvo estable frente a la semana anterior.',
    'reportWeeklySleepUp':
        'El sueño mejoró cerca de {pct}% frente a la semana anterior.',
    'reportWeeklySleepDown':
        'El sueño bajó cerca de {pct}% frente a la semana anterior.',
    'reportWeeklyFeedStableLine': 'Las tomas se mantuvieron regulares.',
    'reportWeeklyFeedUp':
        'Las tomas diarias aumentaron cerca de {pct}% en promedio.',
    'reportWeeklyFeedDown':
        'Las tomas diarias disminuyeron cerca de {pct}% en promedio.',
    'reportWeeklyHeroTemplate':
        '¡{name} tuvo una semana {tone}! {sleep} {feed}',
    'reportWeeklyTrendLabelImproved': 'Mejoró',
    'reportWeeklyTrendLabelWorse': 'Empeoró',
    'reportWeeklyTrendLabelStable': 'Estable',
    'reportWeeklyTrendLabelUnknown': '—',
    'reportWeeklyTrendLabelEvolving': 'Evolucionando',
    'reportWeeklyTrendLabelIncreased': 'Aumentó',
    'reportWeeklyTrendNA': '—',
    'reportWeeklyHighlightSleep':
        'Punto positivo: sueño más reparador esta semana.',
    'reportWeeklyHighlightFeedingStable':
        'Punto positivo: ritmo de alimentación constante.',
    'reportWeeklyHighlightDiaperUp':
        'Nota: más cambios — hidratación o digestión más activa.',
    'reportWeeklyHighlightWeight': 'Punto positivo: aumento saludable de peso.',
    'reportWeeklyHighlightGeneric':
        'Sigue registrando para ver tendencias más claras.',
    'reportWeeklyAvgFeedsDay': 'Promedio diario: {avg} tomas.',
    'reportWeeklyAvgDiapersDay': 'Promedio diario: {avg} cambios.',
    'reportWeeklySleepHoursChartTitle': 'Horas de sueño por día',
    'reportWeeklyAvgWeekLabel': 'Promedio semanal',
    'reportWeeklyVsPrevWeekShort': 'vs semana anterior',
    'reportWeeklyInsightsCardTitle': 'Insights de IA',
    'reportWeeklyPatternsTitle': 'Patrones detectados',
    'reportWeeklySeeAllAnalyses': 'Ver todos los análisis',
    'reportWeeklyHeatmapSoon': 'Mapa de calor por hora disponible pronto.',
    'reportWeeklyFeedChartCaption': 'Tomas por día',
    'reportWeeklyDiaperChartCaption': 'Cambios por día',
    'reportWeeklyPatternWeekend':
        'El sueño suele alargarse un poco los fines de semana.',
    'reportWeeklyPatternFeedingDown':
        'Menos tomas en promedio — común cuando los intervalos se amplían.',
    'reportWeeklyPatternDefault':
        'El patrón semanal parece estable — ajusta la rutina según el ritmo del bebé.',
    'reportWeeklyInsightSleepNeutral':
        'El sueño fue similar al de la semana anterior.',
    'reportWeeklyInsightSleepBetter':
        'Hay más horas de sueño que la semana pasada — buena señal.',
    'reportWeeklyInsightSleepLess':
        'El sueño total bajó frente a la semana anterior — conviene observar las noches.',
    'reportWeeklyInsightTemplate': '{name}: {sleep}',
    'reportMonthlyScreenTitle': 'Informe mensual',
    'reportMonthlyAvgWeight': 'Peso medio',
    'reportMonthlyAvgHeight': 'Altura media',
    'reportMonthlyGrowthChartEmpty':
        'Añade al menos dos registros de peso este mes para ver el gráfico.',
    'reportMonthlySleepSection': 'Sueño',
    'reportMonthlySleepAvg': 'Media mensual (por día)',
    'reportMonthlyVsPrevMonth': 'vs mes anterior',
    'reportMonthlyBestWeeks': 'Semanas con más sueño',
    'reportMonthlySleepTrendUp':
        'Tendencia general: más sueño reparador este mes.',
    'reportMonthlySleepTrendDown':
        'Tendencia general: menos sueño total que el mes pasado — conviene vigilar.',
    'reportMonthlySleepTrendStable':
        'Tendencia general: sueño estable durante el mes.',
    'reportMonthlySleepTrendUnknown':
        'No hay datos suficientes para comparar con el mes anterior.',
    'reportMonthlySleepExplain':
        'La media de sueño por día suma todas las sesiones registradas por día civil del mes y divide entre el número de días de ese mes (sesiones contadas por hora de fin). El porcentaje compara esa media con la del mes anterior. «Semanas con más sueño» muestra hasta dos semanas (lunes a domingo) con mayor sueño total.',
    'reportMonthlyFeedingSection': 'Alimentación',
    'reportMonthlyFeedFreq': 'Frecuencia media (tomas/día)',
    'reportMonthlyFeedingExplain':
        'La frecuencia media es el total de tomas al pecho o biberón registradas en el mes dividido entre los días del calendario de ese mes (incluye días sin registro). La comida sólida no entra en este recuento. Los horarios son hasta tres franjas en las que más tomas terminaron este mes.',
    'reportMonthlyPredominantHours': 'Horarios predominantes (fin de la toma)',
    'reportMonthlyMilestonesTitle': 'Hitos del mes',
    'reportMonthlyMilestonesEmpty':
        'Sin vacunas, consultas o recuerdos con insignia este mes.',
    'reportMonthlyMilestoneConsultationDefault': 'Consulta',
    'reportMonthlyMemoriesTitle': 'Recuerdos del mes',
    'reportMonthlySeeAllMemories': 'Ver todas',
    'reportMonthlyMemoriesEmpty': 'Sin fotos en los recuerdos de este mes.',
    'reportMonthlyVideosHint':
        'Los vídeos aparecerán cuando existan en los momentos guardados.',
    'reportSleepAdvScreenTitle': 'Informe de sueño',
    'reportSleepAdvScoreTitle': 'Puntuación de sueño',
    'reportSleepAdvMetricsTitle': 'Métricas de la semana',
    'reportSleepAdvEfficiency': 'Eficiencia del sueño',
    'reportSleepAdvVsPrevPct':
        'Variación de eficiencia: {pct}% (vs semana anterior)',
    'reportSleepAdvOnset': 'Tiempo hasta el primer sueño nocturno',
    'reportSleepAdvAwakenings': 'Despertares por noche (promedio)',
    'reportSleepAdvAwakeningsTotal': 'Despertares esta semana: {n}',
    'reportSleepAdvLongest': 'Mayor periodo continuo',
    'reportSleepAdvAvgDailySleep': 'Promedio de sueño por día',
    'reportSleepAdvIdealTitle': 'Mejor hora para dormirse',
    'reportSleepAdvIdealFooter':
        'Ventana estimada a partir de tus registros (no es consejo médico).',
    'reportSleepAdvSeeFullAnalysis': 'Ver análisis completo',
    'reportSleepAdvChartsSection': 'Sesión de sueño',
    'reportSleepAdvChartsSleepTrend': 'Ritmo del sueño (esta semana)',
    'reportSleepAdvChartsCompare': 'Comparación con la semana anterior',
    'reportSleepAdvChartsDistribution': 'Día y noche (suma de la semana)',
    'reportSleepAdvChartsBars': 'Volumen de sueño: esta semana vs anterior',
    'reportSleepAdvDayPhase': 'Sueño diurno (6h–18h)',
    'reportSleepAdvNightPhase': 'Sueño nocturno (18h–6h)',
    'reportSleepAdvDistributionEmpty': 'Sin datos para distribuir.',
    'reportSleepAdvLegendThisWeek': 'Esta semana',
    'reportSleepAdvLegendPrevWeek': 'Semana anterior',
    'reportSleepAdvScoreBreakdown': 'Qué refleja la puntuación',
    'reportSleepAdvBreakdownLine':
        'Eficiencia: {e} pts • Tramos largos: {s} pts • Despertares: {a} pts • Regularidad: {c} pts (orientativos).',
    'reportSleepAdvNotEnoughData':
        'Aún hay pocos registros esta semana — los valores son orientativos.',
    'reportSleepAdvStatusExcellent': 'Excelente',
    'reportSleepAdvStatusGood': 'Bueno',
    'reportSleepAdvStatusRegular': 'Regular',
    'reportSleepAdvStatusPoor': 'Frágil',
    'reportSleepAdvBadgeVeryGood': 'Muy bueno',
    'reportSleepAdvBadgeGood': 'Bueno',
    'reportSleepAdvBadgeOk': 'Moderado',
    'reportSleepAdvBadgeAttention': 'Acompañar',
    'reportSleepAdvBadgeIdeal': 'Ideal',
    'reportSleepAdvBadgeUnknown': 'Sin datos',
    'reportSleepAdvBadgeLow': 'Bajo',
    'reportSleepAdvBadgeModerate': 'Moderado',
    'reportSleepAdvBadgeHigh': 'Elevado',
    'alertsSectionFeeding': 'Alimentación',
    'alertsRuleFeeding':
        'Con la alerta activada, la app agenda una notificación local cuando pasan los minutos elegidos desde el fin del último registro de pecho o biberón. Al registrar una nueva toma, el plazo se recalcula desde esa hora.',
    'alertsSectionDiaper': 'Pañal',
    'alertsRuleDiaper':
        'La app sugiere un recordatorio unas 3 horas y 30 minutos después del último cambio registrado. Al guardar un nuevo cambio, el recordatorio se cancela y se agenda de nuevo.',
    'alertsSectionSleep': 'Sueño',
    'alertsRuleSleep':
        'Usando la última hora registrada de fin de sueño y la edad del bebé, la app puede agendar avisos antes o después de la ventana habitual de vigilia. Al guardar un nuevo sueño, los horarios se actualizan.',
    'alertsSectionGrowth': 'Crecimiento y mediciones',
    'alertsRuleGrowth':
        'Notifica cuando el peso más reciente queda por debajo del registro anterior. También avisa cuando pasan más de 30 días sin mediciones de peso, altura o perímetro guardadas en la app.',
    'diaperToggleAlerts': 'Recordatorios de pañal',
    'diaperToggleAlertsSubtitle': 'Aviso cerca del próximo cambio sugerido.',
    'healthGrowthToggleAlerts': 'Alertas de crecimiento',
    'healthGrowthToggleAlertsSubtitle':
        'Avisos de peso y ausencia prolongada de mediciones.',
  },
  AppLang.fr: {
    'appName': 'FaceBaby',
    'onbSelectDate': 'Sélectionner une date',
    'onbBabyFallback': 'bébé',
    'onbMomFallback': 'maman',
    'onbDadFallback': 'papa',
    'onbWelcomeTitle': 'Accompagner et suivre',
    'onbWelcomeSubtitle': 'le développement avec Amour.',
    'onbFeatureSleep': 'Sommeil',
    'onbFeatureFeeding': 'Alimentation',
    'onbFeatureGrowth': 'Croissance',
    'onbFeatureMemories': 'Souvenirs',
    'onbFeatureAlerts': 'Alertes',
    'onbFeatureLove': 'Beaucoup d’amour',
    'onbCreateBabyProfile': 'Créer le profil du bébé',
    'onbExistingAccountLogin': 'J’ai déjà un compte / Me connecter',
    'onbContinue': 'Continuer',
    'onbPrepareFaceBaby': 'Préparer FaceBaby',
    'onbPreparingTitle': 'Préparation de FaceBaby pour vous...',
    'onbPreparingSubtitle':
        'Personnalisation des alertes, souvenirs et routines du bébé.',
    'onbAuthTitle': 'Votre profil de base est prêt',
    'onbAuthSubtitle':
        'Créez maintenant votre compte pour tout garder en sécurité et synchroniser ensuite.',
    'onbSignInGoogle': 'Se connecter avec Google',
    'onbSignInApple': 'Se connecter avec Apple',
    'onbContinueEmail': 'Continuer avec e-mail',
    'onbAlreadyHaveAccount': 'J’ai déjà un compte',
    'onbWait': 'Veuillez patienter...',
    'onbDoneTitle': 'C’est prêt ! Le profil du bébé a été créé.',
    'onbStartTracking': 'Commencer le suivi',
    'onbCouldNotPrepare':
        'Impossible de préparer le profil maintenant. Réessayez.',
    'onbBabyNameTitle': 'Quel est le prénom du bébé ?',
    'onbBabyNameSubtitle': 'Rendons FaceBaby plus proche de votre famille.',
    'onbBabyNameHint': 'Prénom du bébé',
    'onbBabyBirthTitle': 'Quelle est la date de naissance ?',
    'onbBabyBirthSubtitle':
        'Nous utilisons l’âge pour personnaliser le sommeil, la routine et la croissance.',
    'onbBabyWeightTitle': 'Quel est le poids du bébé ?',
    'onbBabyWeightSubtitle':
        'Faites glisser la règle pour choisir. Vous pouvez passer de Kg à Lb.',
    'onbBabyHeightTitle': 'Quelle est la taille du bébé ?',
    'onbBabyHeightSubtitle':
        'Utilisez la règle pour indiquer la taille approximative dans l’unité souhaitée.',
    'onbMotherNameTitle': 'Quel est le prénom de maman ?',
    'onbMotherNameSubtitle':
        'Nous utiliserons son prénom dans les prochaines questions.',
    'onbMotherNameHint': 'Prénom de maman',
    'onbMotherBirthTitle': 'Quelle est la date de naissance de maman ?',
    'onbMotherBirthSubtitle': 'Ensuite, nous demanderons sa taille.',
    'onbMotherHeightTitle': 'Quelle est la taille de {name} ?',
    'onbMotherHeightSubtitle':
        'Cette information aide pour les rapports de croissance.',
    'onbRegisterFatherTitle': 'Souhaitez-vous aussi ajouter papa ?',
    'onbRegisterFatherSubtitle':
        'Si vous le souhaitez, FaceBaby personnalise aussi les informations de papa.',
    'onbFatherNameTitle': 'Quel est le prénom de papa ?',
    'onbFatherNameSubtitle': 'Sa règle sera ainsi personnalisée aussi.',
    'onbFatherNameHint': 'Prénom de papa',
    'onbFatherBirthTitle': 'Quelle est la date de naissance de papa ?',
    'onbFatherBirthSubtitle': 'Ensuite, nous demanderons sa taille.',
    'onbFatherHeightTitle': 'Quelle est la taille de {name} ?',
    'onbFatherHeightSubtitle':
        'Une valeur approximative suffit, vous pourrez l’ajuster plus tard.',
    'onbBabySexTitle': 'Quel est le sexe du bébé ?',
    'onbSexGirl': 'Fille',
    'onbSexBoy': 'Garçon',
    'onbSexUnknown': 'Je préfère ne pas répondre',
    'onbFirstBabyTitle': 'Est-ce votre premier bébé ?',
    'onbYes': 'Oui',
    'onbNo': 'Non',
    'onbConcernTitle':
        'Quelle est votre plus grande préoccupation maintenant ?',
    'onbConcernSubtitle': 'Vous pouvez en choisir plusieurs.',
    'onbConcernSleep': 'Sommeil du bébé',
    'onbConcernFeeding': 'Allaitement/alimentation',
    'onbConcernGrowth': 'Poids et croissance',
    'onbConcernRoutine': 'Routine quotidienne',
    'onbConcernMemories': 'Souvenirs et photos',
    'onbConcernDevelopment': 'Développement',
    'onbGoalsTitle': 'Quels sont vos objectifs ?',
    'onbGoalsSubtitle':
        'Nous utiliserons cela pour personnaliser votre expérience.',
    'onbGoalRoutine': 'Mieux suivre la routine',
    'onbGoalSleepAlerts': 'Recevoir des alertes de sommeil',
    'onbGoalMoments': 'Enregistrer les moments spéciaux',
    'onbGoalReports': 'Générer des rapports',
    'onbGoalMemoryBook': 'Créer un livre de souvenirs',
    'onbMessagePrefTitle': 'Maman spiritualisée, bébé heureux.',
    'onbMessagePrefSubtitle':
        'Souhaitez-vous recevoir des messages quotidiens ?',
    'onbMessagePrefChristian': 'Chrétienne',
    'onbMessagePrefHoroscope': 'Astrologique',
    'onbMessagePrefPhilosophical': 'Philosophique / Œcuménique',
    'onbMessagePrefSpiritist': 'Spiritistes',
    'onbMessagePrefJewish': 'Juives',
    'onbMessagePrefAll': 'Toutes',
    'onbDragToAdjust': 'Faites glisser pour ajuster',
    'onbEmailSheetTitle': 'Créer un compte avec e-mail',
    'onbYourNameHint': 'Votre nom',
    'onbEmailHint': 'E-mail',
    'onbPasswordHint': 'Mot de passe',
    'onbCreateAccount': 'Créer un compte',
    'onbValYourName': 'Indiquez votre nom.',
    'onbValEmailRequired': 'Indiquez votre e-mail.',
    'onbValEmailInvalid': 'E-mail invalide.',
    'onbValPasswordMin': 'Utilisez au moins 6 caractères.',
    'memoriesAlbumBackCoverBody':
        'FaceBaby est né pour transformer de simples instants en souvenirs éternels. Chaque sourire, découverte, câlin et moment précieux de votre bébé mérite d\u2019être conservé avec amour et tendresse.\n\nCe livre a été créé pour accompagner les premiers pas de cette merveilleuse aventure et préserver des souvenirs uniques pour toute une vie.\n\nBien plus que des photos et des notes, ces pages renferment des émotions, des histoires et des souvenirs que le temps n\u2019effacera jamais.\n\nMerci de permettre à FaceBaby de faire partie de l\u2019histoire de votre famille. 💛',
    'memoriesAlbumBackCoverFinale':
        'Parce que l\u2019enfance passe vite…\nmais les souvenirs peuvent durer pour toujours.',
    'memoriesAlbumQualityTitle': 'Qualité du PDF',
    'memoriesAlbumQualityShareTitle': 'Léger — pour partager',
    'memoriesAlbumQualityShareDesc':
        'Images compressées, fichier plus petit. Idéal pour WhatsApp et e-mail.',
    'memoriesAlbumQualityPrintTitle': 'Haute qualité — pour imprimer',
    'memoriesAlbumQualityPrintDesc':
        'Photos en plus haute résolution. Fichier plus volumineux ; idéal à l\u2019impression.',
    'memoriesAlbumExportTitle': 'Création du livre…',
    'memoriesAlbumProgressPreparing': 'Préparation des pages…',
    'memoriesAlbumProgressImages': 'Traitement des photos ({current}/{total})…',
    'memoriesAlbumProgressBuilding': 'Assemblage du PDF ({current}/{total})…',
    'memoriesAlbumProgressSaving': 'Enregistrement du fichier…',
    'memoriesAlbumCancelBtn': 'Annuler',
    'memoriesAlbumCanceled': 'Génération annulée.',
    'memoriesAlbumErrorNetwork':
        'Pas de connexion Internet. Vérifiez le réseau et réessayez.',
    'memoriesAlbumErrorStorage':
        'Espace insuffisant sur l\u2019appareil pour enregistrer le PDF.',
    'memoriesAlbumSkippedImages':
        '{count} photo(s) n\u2019ont pas pu être incluses (réseau ou fichier invalide).',
    'home': 'Accueil',
    'records': 'Journaux',
    'reports': 'Rapports',
    'memories': 'Souvenirs',
    'more': 'Plus',
    'helloMom': 'Salut, Maman !',
    'today': "Aujourd'hui",
    'shortcuts': 'Raccourcis',
    'registerNow': 'Enregistrer',
    'edit': 'Modifier',
    'todaySummary': "Résumé du jour",
    'nextEvents': 'Événements à venir',
    'quickRecordsTitle': 'Journaux rapides',
    'quickRecordsSubtitle': 'Ajoutez la routine de bébé en quelques touches.',
    'feedingAlertsSwitchTitle': 'Alerte alimentation',
    'feedingAlertsSwitchSubtitle':
        'Prévenir lorsque l’intervalle défini est écoulé depuis la dernière tétée ou le dernier biberon.',
    'feedingAlertsIntervalCaption':
        'Rappeler après la dernière tétée : {m} min (20–360)',
    'feedingAlertsShortcutTitle': 'Alerte alimentation',
    'scheduledFeedingReminderBody':
        'C’est l’heure du rappel d’alimentation. Touchez pour enregistrer.',
    'scheduledDiaperReminderTitle': 'Change de couche',
    'scheduledDiaperReminderBody':
        'Il est peut-être temps de changer la couche. Touchez pour enregistrer.',
    'whatHappenedNow': "Que s'est-il passé ?",
    'momNote': 'Note de maman',
    'saveRecord': 'Enregistrer',
    'reportsTitle': 'Rapports',
    'reportsSubtitle': 'Un résumé pour maman et le pédiatre.',
    'reportsHubAnchorLabel': 'Référence',
    'reportsHubPickDayTooltip': 'Choisir le jour de référence des rapports',
    'reportsHubSectionTitle': 'Rapports disponibles',
    'reportStubComingSoon':
        'Ce rapport sera mis à jour automatiquement avec les données de l’app pour la période sélectionnée.',
    'reportListDaily': 'Rapport quotidien',
    'reportListDailySub': 'Résumé et détails du jour sélectionné',
    'reportListWeekly': 'Rapport hebdomadaire',
    'reportListWeeklySub':
        'Résumé et détails de la semaine contenant le jour sélectionné',
    'reportListMonthly': 'Rapport mensuel',
    'reportListMonthlySub': 'Agrégats mensuels du mois du jour sélectionné',
    'reportListSleepAdv': 'Rapport avancé sur le sommeil',
    'reportListSleepAdvSub': 'Rythmes et métriques du sommeil',
    'reportListDevelopment': 'Rapport de développement',
    'reportListDevelopmentSub': 'Jalons et bonds de développement',
    'plusBrandTitle': 'FaceBaby Premium',
    'plusSheetHero':
        'Un seul déblocage pour toujours : de beaux PDF, le livre de souvenirs, plus de photos, sauvegarde cloud et des conseils pour maman.',
    'plusSheetPriceLabel': 'Paiement unique',
    'plusSheetBullets':
        '• Rapports PDF (sommeil, routine, croissance)\n• Livre de souvenirs en PDF\n• Export des badges (PNG / PDF)\n• Sauvegarde cloud entre appareils\n• Plus de souvenirs et de photos\n• Insights intelligents dans les rapports\n• Rapport pour le pédiatre\n• Statistiques avancées\n• Thèmes premium du livre',
    'plusCtaSubscribe': 'Débloquer pour toujours',
    'plusCtaRestore': 'Restaurer les achats',
    'plusCtaLater': 'Pas maintenant',
    'plusSheetFootnote':
        'Achat unique traité par Google Play ou l’App Store. Vous pouvez le restaurer sur un autre téléphone.',
    'plusWelcomeSnack': 'Premium activé. Merci de soutenir FaceBaby.',
    'plusPurchaseUnavailableSnack':
        'L’achat n’est pas disponible sur cet appareil.',
    'plusPurchaseSkuNotFoundSnack':
        'Produit introuvable dans la boutique : {id}',
    'plusPurchaseBillingLaunchFailedSnack':
        'Impossible d’ouvrir le paiement. Réessayez.',
    'plusPaywallSkuMissingHint':
        'Configurez le produit dans la boutique : {id}',
    'plusRestoreOkSnack': 'Achat restauré.',
    'plusRestoreEmptySnack': 'Aucun achat à restaurer n’a été trouvé.',
    'plusSnackLockedFeature': 'Cette fonction fait partie de FaceBaby Premium.',
    'plusMemoryLimitSnack':
        'Avec l’offre gratuite, vous pouvez enregistrer jusqu’à {max} photos sur les badges.',
    'plusMemoryLimitDialogTitle': 'Débloquez plus de souvenirs',
    'plusMemoryLimitDialogBody':
        'Avec l’offre gratuite, vous pouvez enregistrer jusqu’à {max} photos sur les badges.\n\nPassez à FaceBaby Premium en paiement unique — sans abonnement mensuel — pour des photos illimitées, des rapports, des exports et d’autres fonctions du portail.',
    'plusMemoryLimitDialogSubscribe': 'Passer à Premium',
    'plusMemoryCounterFree': '{n} sur {max} moments avec l’offre gratuite',
    'plusReportsLockedHint':
        'Les rapports PDF font partie de FaceBaby Premium.',
    'plusExportLockedHint':
        'L’export des badges fait partie de FaceBaby Premium.',
    'plusLifetimePaymentBadge': 'Paiement unique',
    'plusNoMonthlyBadge': 'Sans abonnement mensuel',
    'plusPremiumActiveTitle': 'Merci pour Premium',
    'plusPremiumActiveBody':
        'Toutes les fonctions premium sont actives pour toujours sur cet appareil. Restaurez vos achats si vous changez de téléphone.',
    'plusPurchaseErrorSnack': 'Impossible de finaliser l’achat. Réessayez.',
    'plusDoneClose': 'Fermer',
    'plusPaywallHeadline':
        'Chaque plan a été pensé pour\nvous accompagner à chaque étape.',
    'plusPaywallActiveNote':
        'Votre Premium est actif. Vous pouvez consulter les plans à tout moment.',
    'plusPaywallSecureNote':
        'Achat 100 % sécurisé. Vous pouvez annuler quand vous le souhaitez.',
    'plusPlanPremiumTitle': 'Premium',
    'plusPlanPremiumSubtitle': 'Tout pour prendre soin\net mieux accompagner',
    'plusPlanPremiumBadge': 'Le plus choisi',
    'plusPlanPremiumPriceSubActive': 'actif maintenant',
    'plusPlanPremiumPriceSubSecure': 'achat sécurisé',
    'plusPlanPremiumButtonActive': 'Plan actuel',
    'plusPlanPremiumButton': 'Je veux Premium',
    'plusPlanPremiumFeature1': 'Tout le plan Gratuit',
    'plusPlanPremiumFeature2': 'Rapports complets du bébé',
    'plusPlanPremiumFeature3':
        'Rapport pour le pédiatre (utile à partager avec votre médecin)',
    'plusPlanPremiumFeature4': 'Description des signes astrologiques',
    'plusPlanPremiumFeature5': 'Messages bibliques quotidiens',
    'plusPlanPremiumFeature6': 'Analyses et insights du développement',
    'plusPlanPremiumFeature7': 'Contenus et conseils exclusifs',
    'plusPlanPremiumFeature8': 'Support prioritaire',
    'plusPlanAiTitle': 'Nounou IA',
    'plusPlanAiSubtitle': 'Assistant intelligent\npour le quotidien',
    'plusPlanAiBadge': 'Bientôt',
    'plusPlanAiFeature1': 'Tout le plan Premium',
    'plusPlanAiFeature2': 'Nounou IA 24 h avec vous',
    'plusPlanAiFeature3': 'Réponses intelligentes',
    'plusPlanAiFeature4': 'Conseils personnalisés',
    'plusPlanAiFeature5': 'Alertes prédictives',
    'plusPlanAiFeature6': 'Routines personnalisées',
    'plusPlanAiFeature7': 'Contenus générés par IA',
    'plusPlanAiPrice': 'Bientôt',
    'plusPlanAiPriceSub': 'Restez à l’écoute !',
    'plusPlanAiButton': 'Me prévenir',
    'plusPlanFreeTitle': 'Gratuit',
    'plusPlanFreeSubtitle': 'Commencez avec l’essentiel',
    'plusPlanFreePrice': '0,00 €',
    'plusPlanCurrent': 'Plan actuel',
    'plusPlanFreeFeature1': 'Profils de base',
    'plusPlanFreeFeature2': 'Journal quotidien',
    'plusPlanFreeFeature3': 'Agendas et rappels',
    'plusPlanFreeFeature4': 'Poids et taille',
    'plusTrustData': 'Vos données\ntoujours protégées',
    'plusTrustFamily': 'Fait avec amour\npour les familles',
    'plusTrustContent': 'Contenus fiables\net à jour',
    'plusTrustSupport': 'Soutien à chaque\nmoment',
    'growth': 'Croissance',
    'pediatricReport': 'Rapport pédiatrique',
    'pediatricReportDesc':
        "Générez un PDF avec le poids, le sommeil, l'alimentation, les couches, les vaccins, les symptômes enregistrés dans Santé, les rendez-vous et les notes.",
    'reportListPediatric': 'Rapport pour le pédiatre',
    'reportListPediatricSub': 'PDF et données pour la consultation',
    'healthHubSymptomReports': 'Signaler un symptôme',
    'healthHubSymptomReportsSub':
        'Fièvre, coliques, médicaments et plus — inclus dans le rapport pédiatrique',
    'symptomReportTitle': 'Signaler un symptôme',
    'symptomReportEmpty':
        'Aucune entrée pour le moment. Touchez + pour ajouter.',
    'symptomReportNew': 'Nouvelle entrée',
    'symptomReportSave': 'Enregistrer',
    'symptomReportOccurredAt': 'Date et heure',
    'symptomReportPickDateTime': 'Modifier date et heure',
    'symptomReportMedication': 'Médicaments pris',
    'symptomReportMedicationHint': 'Nom ou courte note',
    'symptomReportFever': 'Fièvre',
    'symptomReportTemp': 'Température',
    'symptomReportTempHint': 'Selon vos unités dans Réglages',
    'symptomReportCrying': 'Pleurs sans cause apparente',
    'symptomReportPain': 'Douleur',
    'symptomReportColic': 'Coliques',
    'symptomReportReflux': 'Reflux',
    'symptomReportOther': 'Autre',
    'symptomReportOtherHint': 'Brève description',
    'symptomReportValidationNeedOne':
        'Sélectionnez au moins un symptôme ou remplissez un champ.',
    'symptomReportValidationFeverTemp':
        'Indiquez la température si la fièvre est cochée.',
    'symptomReportDeleteTitle': 'Supprimer l’entrée ?',
    'symptomReportDeleteBody': 'Cette action est irréversible.',
    'reportPediatricScreenTitle': 'Rapport pédiatrique',
    'reportPediatricPeriodPrefix': 'Période :',
    'reportPediatricFilterHint': 'Période du rapport',
    'reportPediatricDateFrom': 'Du',
    'reportPediatricDateTo': 'Au',
    'reportPediatricPickRange': 'Choisir les dates',
    'reportPediatricFilterMaxDaysHint':
        'Touchez pour modifier. Les plages très longues sont limitées à 366 jours.',
    'reportPediatricSectionGeneral': 'Informations générales',
    'reportPediatricSectionSummary': 'Résumé de la période',
    'reportPediatricSectionSleep': 'Sommeil',
    'reportPediatricSectionFeeding': 'Alimentation',
    'reportPediatricSectionSymptoms': 'Symptômes et suivis',
    'reportPediatricSectionObservations': 'Observations des parents',
    'reportPediatricLabelName': 'Nom',
    'reportPediatricLabelAge': 'Âge',
    'reportPediatricLabelBirth': 'Date de naissance',
    'reportPediatricLabelWeightCurrent': 'Poids (dernier dans la période)',
    'reportPediatricLabelHeight': 'Taille',
    'reportPediatricWeightStart': 'Poids initial (période)',
    'reportPediatricWeightEnd': 'Poids final (période)',
    'reportPediatricWeightGain': 'Variation de poids',
    'reportPediatricHeightStart': 'Taille initiale (période)',
    'reportPediatricHeightEnd': 'Taille finale (période)',
    'reportPediatricHeightGain': 'Croissance en taille',
    'reportPediatricAvgFeeds': 'Tétées/repas par jour (moy.)',
    'reportPediatricAvgSleep': 'Sommeil par jour (moy.)',
    'reportPediatricAvgDiapers': 'Changes par jour (moy.)',
    'reportPediatricFeverEpisodes': 'Épisodes de fièvre (suivi structuré)',
    'reportPediatricFeverNote': 'Note',
    'reportPediatricFeverFootnote':
        'Comptage à partir des suivis structurés dans Santé › Signaler un symptôme (température si fournie).',
    'reportPediatricVaccines': 'Vaccins administrés durant la période',
    'reportPediatricMedications':
        'Médicaments (suivis et mots-clés dans les notes)',
    'reportPediatricSleepAvgDaily': 'Sommeil quotidien moyen',
    'reportPediatricSleepAwakenings': 'Réveils nocturnes (moy.)',
    'reportPediatricSleepPattern': 'Schéma global du sommeil',
    'reportPediatricSleepPatternStable': 'Plutôt continu',
    'reportPediatricSleepPatternModerate': 'Intermédiaire',
    'reportPediatricSleepPatternFragmented': 'Plus fragmenté',
    'reportPediatricSleepLongest': 'Plus long sommeil continu',
    'reportPediatricFeedingBreast': 'Allaitement',
    'reportPediatricFeedingFormula': 'Lait infantile',
    'reportPediatricFeedingSolid': 'Aliments solides',
    'reportPediatricFeedingSessions': 'sessions',
    'reportPediatricFeedingAvgDur': 'durée moyenne',
    'reportPediatricSymptomReflux': 'Reflux (journaux ou suivis)',
    'reportPediatricSymptomColic': 'Coliques (journaux ou suivis)',
    'reportPediatricSymptomIrrit': 'Irritabilité (humeurs)',
    'reportPediatricIrritHigh': 'Plus marquée',
    'reportPediatricIrritMedium': 'Modérée',
    'reportPediatricIrritLow': 'Légère',
    'reportPediatricIrritUnknown': 'Pas de données',
    'reportPediatricYes': 'Oui',
    'reportPediatricNo': 'Non',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'Journaux du jour',
    'reportPediatricJournalNoteHint':
        'Détection par mots-clés dans le texte libre.',
    'reportPediatricObsHint':
        'Notes pour la consultation : symptômes, médicaments, changements de comportement…',
    'reportPediatricBtnShare': 'Partager',
    'reportPediatricBtnExportPdf': 'Exporter PDF',
    'reportPediatricBtnPrint': 'Imprimer',
    'reportPediatricBtnEmail': 'E-mail',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote':
        'Résumé informatif à partir des données locales. Ne remplace pas un avis médical.',
    'reportPediatricNone': 'Aucun',
    'reportPediatricPdfTitle': 'Rapport pédiatrique — FaceBaby',
    'reportPediatricPdfPeriod': 'Période :',
    'reportPediatricPdfFooter':
        'Généré dans FaceBaby. Contenu limité aux données stockées sur cet appareil (hors ligne possible).',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': 'Pleurs sans cause apparente (suivis)',
    'reportPediatricSymptomPain': 'Douleur (suivis)',
    'reportPediatricStructuredSymptoms': 'Suivis de symptômes (date et heure)',
    'reportPediatricStructuredSymptomsEmpty':
        'Aucun suivi structuré sur cette période.',
    'generatePdf': 'Générer PDF',
    'reportMonthlyMilestonesTitle': 'Jalons du mois',
    'reportMonthlyMilestonesEmpty':
        'Aucun vaccin, consultation ou souvenir avec badge ce mois-ci.',
    'reportMonthlyMilestoneConsultationDefault': 'Consultation',
    'memoriesTitle': 'Livre de souvenirs',
    'memoriesSubtitle': 'Des moments importants à garder.',
    'memoriesProgressSaved': '{filled} sur {total} moments enregistrés',
    'memoriesProgressStandardBadges': '({count} badges standard)',
    'memoriesCheerEmpty':
        'Touchez un badge avec + pour ajouter photos et histoires.',
    'memoriesAlbumPromoTitle': 'Votre livre de souvenirs complet',
    'memoriesAlbumPromoSubtitle':
        'Téléchargez un PDF élégant avec couverture FaceBaby, cadre décoratif et tous les badges remplis — idéal pour garder ou partager.',
    'memoriesAlbumDownloadCta': 'Télécharger le PDF de l’album',
    'memoriesAlbumGenerating': 'Création de l’album…',
    'memoriesAlbumNeedFilled':
        'Remplissez au moins un moment dans l’album pour générer le PDF.',
    'memoriesAlbumError': 'Impossible de générer le PDF.',
    'memoriesAlbumPdfReadyTitle': 'PDF de l’album prêt',
    'memoriesAlbumShareAction': 'Partager…',
    'memoriesAlbumSaveAction': 'Enregistrer / télécharger',
    'memoriesAlbumSavedSnack': 'PDF enregistré sur l’appareil.',
    'memoriesAlbumSaveFailedSnack': 'Impossible d’enregistrer le PDF.',
    'memoriesAlbumCoverMain': 'Livre de souvenirs',
    'memoriesAlbumCoverTagline': 'Moments précieux avec {name}',
    'memoriesAlbumFooter': 'Créé avec FaceBaby',
    'memoryBadgeMonthOne': '1 mois',
    'memoryBadgeMonthsMany': '{n} mois',
    'memoryBadgeYearOne': '1 an',
    'memoryBadgeYearsMany': '{n} ans',
    'memoryBadgeMonthUnitSingular': 'mois',
    'memoryBadgeMonthUnitPlural': 'mois',
    'badge_arrived_home': 'Arrivée à la maison',
    'badge_first_smile': 'Premier sourire',
    'badge_first_feeding': 'Premier repas',
    'badge_sleeping': 'Endormi',
    'badge_bath_time': 'Heure du bain',
    'badge_going_out': 'Promenade',
    'badge_first_laugh': 'Premier rire',
    'badge_found_hands': 'A découvert ses mains',
    'badge_lifted_head': 'A relevé la tête',
    'badge_at_park': 'Au parc',
    'badge_first_hug': 'Première étreinte',
    'badge_first_foods': 'Premiers aliments',
    'badge_first_bath': 'Premier bain',
    'badge_crib_sleep': 'Première sieste au lit',
    'badge_first_diaper_change': 'Premier change',
    'badge_first_burp': 'Premier rot',
    'badge_first_mom_cuddle': 'Premiers câlins avec maman',
    'badge_first_dad_cuddle': 'Premiers câlins avec papa',
    'badge_first_pediatrician': 'Première visite pédiatrique',
    'badge_first_vaccine': 'Premier vaccin',
    'badge_first_car_ride': 'Premier trajet en voiture',
    'badge_first_stroller_ride': 'Première sortie en poussette',
    'badge_favorite_toy': 'Jouet préféré',
    'badge_first_night_home': 'Première nuit à la maison',
    'badge_first_giggle': 'Premier gloussement',
    'badge_sun_bath': 'Premier bain de soleil',
    'badge_first_christmas': 'Premier Noël',
    'badge_first_new_year': 'Premier Nouvel An',
    'badge_first_mothers_day': 'Première fête des Mères',
    'badge_first_fathers_day': 'Première fête des Pères',
    'badge_first_tooth': 'Première dent',
    'badge_first_puree': 'Première purée',
    'badge_sat_alone': 'Assis sans appui',
    'badge_crawled': 'A quatre pattes',
    'badge_stood_up': 'Debout',
    'badge_first_steps': 'Premiers pas',
    'badge_first_word': 'Premier mot',
    'badge_favorite_song': 'Chanson préférée',
    'badge_first_trip': 'Premier voyage',
    'badge_family_birthday': 'Premier anniversaire en famille',
    'badge_first_beach': 'Première plage',
    'badge_first_pool': 'Première piscine',
    'badge_first_haircut': 'Première coupe de cheveux',
    'badge_first_shoes': 'Premières chaussures',
    'badge_special_outfit': 'Tenue spéciale',
    'badge_first_friend': 'Premier ami',
    'badge_first_party': 'Première fête',
    'badge_first_cartoon': 'Premier dessin animé',
    'badge_first_book': 'Premier livre',
    'badge_special_free': 'Moment spécial',
    'addMemory': 'Ajouter un souvenir',
    'memoryAddBadgeCta': 'Ajouter un badge',
    'memoryChooseBadgeTitle': 'Quel badge voulez-vous créer ?',
    'memoryOtherBadgeTitle': 'Autre',
    'memoryOtherBadgeNameLabel': 'Nom du badge',
    'memoryOtherBadgeNameHint': 'Ex : Premier déguisement',
    'memoryOtherBadgeNameRequired': 'Indiquez le nom du badge.',
    'memoryOtherBadgeNameTooLong': 'Utilisez 25 caractères maximum.',
    'settingsTitle': 'Plus',
    'registerMotherBaby': 'Inscription (maman & bébé)',
    'vaccinesCard': 'Vaccins (carnet)',
    'language': 'Langue',
    'unitsTitle': 'Unités de mesure',
    'unitsIntro':
        'Choisissez comment afficher les mesures. Nous commençons par une valeur par défaut selon la région de votre appareil.',
    'unitsLengthTitle': 'Unité de longueur',
    'unitsLengthSubtitle': 'Taille, périmètre et mesures en général.',
    'unitsWeightTitle': 'Unité de poids',
    'unitsWeightSubtitle': 'Poids de bébé et relevés associés.',
    'unitsLiquidTitle': 'Unité de liquides',
    'unitsLiquidSubtitle': 'Volume (ex. : biberon et autres).',
    'unitsTempTitle': 'Unité de température',
    'unitsTempSubtitle': 'Température corporelle et ambiante.',
    'unitsOptCm': 'cm',
    'unitsOptInch': 'in',
    'unitsOptKg': 'kg',
    'unitsOptLb': 'lb',
    'unitsOptSt': 'st',
    'unitsOptMl': 'ml',
    'unitsOptUkFloz': 'uk fl oz',
    'unitsOptUsFloz': 'us fl oz',
    'unitsOptC': '°C',
    'unitsOptF': '°F',
    'settingsSoonTitle': 'Bientôt',
    'settingsSoonBadge': 'Bientôt',
    'settingsRateUs': 'Notez-nous',
    'settingsVersion': 'Version',
    'settingsVersionDialogTitle': 'Version de l’app',
    'settingsVersionCopy': 'Copier',
    'settingsVersionCopied': 'Informations de version copiées',
    'settingsTermsOfUse': "Conditions d'utilisation",
    'settingsPrivacyPolicy': 'Politique de confidentialité',
    'settingsSpecialThanks': 'Remerciements spéciaux',
    'settingsTellFriend': 'Parlez-en à un ami',
    'settingsMotherProfile': 'Mon profil',
    'profileEditMother': 'Modifier les données de maman',
    'profileEditFather': 'Modifier les données de papa',
    'profileAddFather': 'Enregistrer papa',
    'profileFatherNotRegisteredTitle': 'Papa pas encore enregistré',
    'profileFatherNotRegisteredSubtitle':
        'Si vous n\'avez pas inclus papa lors de l\'inscription, vous pouvez ajouter ses données ici à tout moment.',
    'profileFatherAddCta': 'Enregistrer papa maintenant',
    'profileEditBaby': 'Modifier les données de bébé',
    'profileDataSaved': 'Données enregistrées.',
    'profileEditData': 'Modifier les données',
    'motherProfileTabPreferences': 'Préférences',
    'motherProfileTabMother': 'Maman',
    'motherProfileTabFather': 'Papa',
    'motherProfileTabBabies': 'Bébés',
    'profileLayoutTitle': 'Apparence de l’app',
    'profileLayoutSubtitle': 'Mode jour, nuit ou automatique selon l’heure.',
    'profileLayoutAutomatic': 'Automatique',
    'profileLayoutDay': 'Jour',
    'profileLayoutNight': 'Nuit',
    'profileLayoutUpdating': 'Mise à jour de l’apparence…',
    'motherProfileFieldFatherName': 'Nom',
    'motherProfileNoData':
        'Aucun profil trouvé. Réessayez dans quelques instants.',
    'motherProfileSectionInfo': 'Informations',
    'motherProfileFieldPhone': 'Téléphone',
    'motherProfileFieldBirth': 'Naissance',
    'motherProfileFieldHeight': 'Taille',
    'motherProfileFieldFatherHeight': 'Taille de papa',
    'profileFamilyMessagesTitle': 'Messages sur l’écran Famille',
    'profileShowChristian': 'Chrétienne',
    'profileShowHoroscope': 'Astrologique',
    'profileShowPhilosophical': 'Philosophique / Œcuménique',
    'profileShowSpiritist': 'Messages spiritistes',
    'profileShowJewish': 'Messages juives',
    'motherProfileAddBaby': 'Ajouter un autre bébé',
    'motherProfileNoBabies': 'Aucun bébé trouvé pour ce profil.',
    'motherProfileBabyBornAt': 'Naissance : {date}',
    'vaccinesTitle': 'Vaccins',
    'vaccinesSubtitle': 'Ajoutez vaccins, dates et prochaines doses.',
    'baby': 'Bébé',
    'selectBaby': 'Choisir bébé',
    'addVaccine': 'Ajouter un vaccin',
    'recordsTitle': 'Registres',
    'noVaccinesYet': 'Aucun vaccin pour le moment.',
    'seeAll': 'Voir tout',
    'changePhoto': 'Changer la photo',
    'motherPhotoTitle': 'Photo de maman',
    'babyPhotoTitle': 'Photo de bébé',
    'familyTitle': 'Famille',
    'familySubtitle': 'Arbre familial, signes et messages du jour.',
    'familyEdit': 'Modifier',
    'familyEditData': 'Modifier les données >',
    'familyTabMotherLabel': 'Maman',
    'familyTabFatherLabel': 'Papa',
    'familyRoleMother': 'Maman',
    'familyRoleFather': 'Papa',
    'familyRoleBaby': 'Bébé',
    'familyZodiacSolar': 'Signe solaire',
    'familyEntertainmentNote':
        'Complétez les données de naissance pour personnaliser ce contenu.',
    'familyChristianCardTitle': 'Message biblique',
    'familySpiritistCardTitle': 'Message spiritiste',
    'familyJewishCardTitle': 'Message juif',
    'familyChristianLine': 'Verset du jour · {ref}',
    'familyBornOn': 'Né(e) le {date}',
    'familyAgeOneYear': '1 an',
    'familyAgeYears': '{n} ans',
    'familyHeight': '{value}',
    'familyMotherBlurb':
        'Comme maman {sign}, elle peut montrer des traits comme {traits}.',
    'familyFatherBlurb':
        'Comme papa {sign}, il peut montrer des traits comme {traits}.',
    'familyBabyBlurb':
        'Comme bébé {sign}, il/elle peut montrer des traits comme {traits}.',
    'familyZodiacName_capricorn': 'Capricorne',
    'familyZodiacName_aquarius': 'Verseau',
    'familyZodiacName_pisces': 'Poissons',
    'familyZodiacName_aries': 'Bélier',
    'familyZodiacName_taurus': 'Taureau',
    'familyZodiacName_gemini': 'Gémeaux',
    'familyZodiacName_cancer': 'Cancer',
    'familyZodiacName_leo': 'Lion',
    'familyZodiacName_virgo': 'Vierge',
    'familyZodiacName_libra': 'Balance',
    'familyZodiacName_scorpio': 'Scorpion',
    'familyZodiacName_sagittarius': 'Sagittaire',
    'familyZodiacTrait_capricorn': 'discipliné et responsable',
    'familyZodiacTrait_aquarius': 'curieux et indépendant',
    'familyZodiacTrait_pisces': 'sensible et imaginatif',
    'familyZodiacTrait_aries': 'courageux et plein d’énergie',
    'familyZodiacTrait_taurus': 'calme et affectueux',
    'familyZodiacTrait_gemini': 'communicatif et curieux',
    'familyZodiacTrait_cancer': 'tendre et protecteur',
    'familyZodiacTrait_leo': 'joyeux et expressif',
    'familyZodiacTrait_virgo': 'observateur et soigneux',
    'familyZodiacTrait_libra': 'doux et sociable',
    'familyZodiacTrait_scorpio': 'intense et affectueux',
    'familyZodiacTrait_sagittarius': 'joyeux et explorateur',
    'familyFatherDataComplete': 'Données de papa complètes et à jour',
    'familyFatherDataIncomplete': 'Données de papa encore incomplètes',
    'familyAddFatherPrompt':
        'Voulez-vous ajouter les données de papa ? Complétez-les pour voir la taille estimée de votre bébé.',
    'familyAddFatherButton': 'Ajouter les données de papa',
    'familyCompleteBabySex':
        'Indiquez le sexe du bébé dans le profil pour calculer la taille estimée.',
    'familyEditBabyData': 'Modifier les données du bébé',
    'familyCompleteHeights':
        'Pour l’estimation, nous avons besoin de la taille de maman et de papa.',
    'familyCompleteHeightsButton': 'Compléter les tailles',
    'familyEstimatedHeightTitle': 'Taille estimée de {name}',
    'familyMotherHeightLabel': 'Taille de maman',
    'familyFatherHeightLabel': 'Taille de papa',
    'familyEstimatedGirl': 'Taille estimée pour une fille',
    'familyEstimatedBoy': 'Taille estimée pour un garçon',
    'familyEstimatedResult': 'environ {cm}',
    'familyHowCalculated': 'Comment est-ce calculé ?',
    'familyFormulaBoy':
        'Garçon : (taille du père + taille de la mère + 13) ÷ 2',
    'familyFormulaGirl':
        'Fille : (taille du père + taille de la mère − 13) ÷ 2',
    'familyEstimatedHeightDescription':
        'Estimation basée sur la taille des parents et le sexe du bébé. N\u2019intègre pas les facteurs environnementaux, nutritionnels, de santé ni autres. À titre indicatif seulement.',
    'familyFormulaExampleGirl': '({father} + {mother} − 13) ÷ 2 = {result} cm',
    'familyFormulaExampleBoy': '({father} + {mother} + 13) ÷ 2 = {result} cm',
    'familyHeightDisclaimer':
        'Il s’agit d’une estimation simple utilisée comme référence en pédiatrie. La taille finale peut varier selon la génétique, l’alimentation, le sommeil, la santé, la puberté et d’autres facteurs.',
    'familyZodiacReadMore': 'Lire le texte complet',
    'familyPremiumZodiacLocked':
        'Les signes solaires et textes personnalisés sont réservés à FaceBaby Premium.',
    'familyPremiumHeightLocked':
        'La taille adulte estimée est réservée à FaceBaby Premium.',
    'familyPremiumUnlockCta': 'Débloquer Premium',
    'familyScreenTitle': 'Famille 💜',
    'familyPersonalInfoTitle': 'Informations personnelles',
    'familyHoroscopeCardTitle': 'Horoscope de {sign}',
    'familyBibleVerseCardTitle': 'Verset biblique du jour.',
    'familyDailySummaryTitle': 'Résumé du jour',
    'familySummaryFeeding': 'Allaitement',
    'familySummaryDiapers': 'Couches',
    'familySummarySleep': 'Sommeil',
    'familySummaryWeight': 'Poids',
    'familyQuickLabelBirth': 'Né(e)',
    'familyQuickLabelTime': 'Heure',
    'familySummaryFeedingsToday': '{n} tétées',
    'familySummaryDiaperChangesCount': '{n} changes',
    'familySummaryLastAt': 'Dernière à {time}',
    'familySummaryLastSleepAt': 'Dernier à {time}',
    'familySummaryWeightDayLine': 'Jour sélectionné',
    'familyFieldBirthDate': 'Naissance',
    'familyFieldSign': 'Signe',
    'familyFieldElement': 'Élément',
    'familyFieldAge': 'Âge',
    'familyFieldHeight': 'Taille',
    'familyFieldWeight': 'Poids',
    'familyPremiumShortBadge': 'Premium',
    'familyPremiumFeatureLockedBody':
        'Contenu exclusif pour les familles Premium.',
    'familyPremiumBannerTitle': 'Débloquez les contenus Premium',
    'familyPremiumBannerBody':
        'Accédez aux descriptions de signes, à la taille estimée et aux contenus personnalisés.',
    'familyPremiumViewPlans': 'Voir les plans',
    'familyAddFatherCardTitle': 'Ajouter papa',
    'familyElementFire': 'Feu',
    'familyElementEarth': 'Terre',
    'familyElementAir': 'Air',
    'familyElementWater': 'Eau',
    'familyTapToOpen': 'Touchez pour voir les détails',
    'familyCarouselSwipe': 'Faites glisser pour changer de membre',
    'familyTabNene': 'Bébé',
    'familyTabsHint': 'Touchez une photo pour changer de membre',
    'familyTapToClose': 'Touchez pour fermer',
    'familyShareCard': 'Partager la carte',
    'changeBabyTooltip': 'Changer de bébé',
    'notificationsInboxTitle': 'Notifications',
    'notificationsInboxSubtitle':
        '3 derniers jours (envoyées et programmées, enregistrées dans l’app)',
    'notificationsEmpty': 'Aucune notification enregistrée pour cette période.',
    'notificationsKindShown': 'Envoyée',
    'notificationsKindScheduled': 'Programmée',
    'notificationsOpenTarget': 'Touchez pour ouvrir',
    'notificationsSelectAll': 'Tout sélectionner',
    'deleteAccountTitle': 'Supprimer le compte',
    'deleteAccountBody':
        'Cela supprimera votre compte et TOUTES vos données (maman, bébé et registres) du cloud.\n\nCette action est irréversible.',
    'deleteAccountConfirm': 'Tout supprimer',
    'deleteAccountDeleting': 'Suppression de votre compte...',
    'deleteAccountSuccess': 'Compte supprimé avec succès.',
    'deleteAccountReauthTitle': 'Confirmer mot de passe ou Google',
    'deleteAccountReauthBody':
        'Dernière étape avant suppression : confirmez la même méthode de connexion (mot de passe e-mail ou compte Google/Gmail).',
    'deleteAccountReauthGoogleSection': 'Connexion avec Google / Gmail',
    'deleteAccountReauthGoogleAccountHint': 'Compte Google : {email}',
    'deleteAccountReauthPasswordSection':
        'Connexion par e-mail et mot de passe',
    'deleteAccountReauthOrDivider': 'ou',
    'deleteAccountReauthEmailLabel': 'E-mail du compte',
    'deleteAccountReauthPasswordHint': 'Mot de passe actuel',
    'deleteAccountReauthPasswordRequired':
        'Saisissez le mot de passe actuel du compte.',
    'deleteAccountReauthGoogle': 'Confirmer avec Google (Gmail)',
    'deleteAccountReauthContinue': 'Confirmer avec le mot de passe',
    'deleteAccountReauthCantPassword':
        'Utilisez le bouton de la même méthode de connexion (Google/Gmail ou e-mail et mot de passe) qu’à la création du compte.',
    'deleteAccountTypeWordTitle': 'Confirmation finale',
    'deleteAccountTypeWordInstruction':
        'Pour supprimer définitivement le compte, tapez delete dans le champ. Ensuite nous demanderons une confirmation par mot de passe ou Google (Gmail).',
    'deleteAccountTypeWordFieldLabel': 'delete',
    'homeBabyBannerForecastSleep': 'Prévision de sommeil',
    'homeBabyBannerForecastWake': 'Prévision de réveil',
    'homeBabyBannerForecastSubtitleSleep':
        'Signes de sommeil détectés\nselon l’heure actuelle',
    'homeBabyBannerForecastSubtitleWake':
        'Selon l’heure actuelle et le modèle par âge',
    'homeBabyBannerEtaIn': 'dans {d}',
    'homeBabyBannerLastDiaper': 'Dernière couche',
    'homeBabyBannerNoRecordsYet': 'Aucun enregistrement',
    'homeBabyBannerNextBetween': 'Prochaine entre {range}',
    'homeBabyBannerDiaperRecommendedUntil': 'Changement recommandé jusqu’à {d}',
    'homeBabyBannerIdealWindow': 'Fenêtre idéale : {range}',
    'homeConsultationScheduled': 'Rendez-vous programmé',
    'homeBannerChipConsultation': 'Rendez-vous',
    'homeBannerChipDiaper': 'Couche',
    'homeBannerChipFeed': 'Tétée',
    'homeBannerChipSleep': 'Sommeil',
    'homeBannerOverdueSleep': "C'est l'heure de dormir (dépassée)",
    'homeBannerOverdueWake': "C'est l'heure de se réveiller (dépassée)",
    'homeBannerHungry': 'Affamé',
    'homeBannerDiaperDirty': 'Peut être sale',
    'homeBannerExhausted': 'ÉPUISÉ',
    'homeBannerChipVaccine': 'Vaccin aujourd’hui',
    'homeMotivationBanner':
        'Vous faites un excellent travail ! Petits suivis, grands souvenirs.',
    'homeMotivationBannerOpenMemories': 'Ouvrir le livre de souvenirs',
    'healthHubTitle': 'Santé',
    'healthHubIntro':
        'Vaccins, consultations et soins de bébé au même endroit.',
    'healthHubSection': 'Accès rapide',
    'healthHubVaccines': 'Carnet de vaccination',
    'healthHubVaccinesSub': 'Enregistrez et consultez les vaccins de bébé',
    'vaccineReminderNotifTitle': 'Vaccin',
    'vaccineReminderNotifBody': 'Vaccin prévu aujourd’hui : {name}.',
    'vaccDueConfirmCheckbox':
        'Je confirme que cette dose a déjà été administrée.',
    'vaccDueSavedOk': 'Vaccin marqué comme administré.',
    'vaccDuePickTitle': 'Vaccins prévus pour aujourd’hui',
    'homeSummaryHealthStripTitle': 'Vaccins et consultations ce jour',
    'homeSummaryHealthStripEmpty':
        'Aucun vaccin ni consultation enregistré ce jour.',
    'consultationReminderNotifTitle': 'Consultation programmée',
    'consultationReminderNotifBody': 'Demain · {title} · {when}',
    'consultationTodayReminderNotifBody': 'Aujourd’hui · {title} · {when}',
    'memoryTellMomentTitle': 'Racontez ce moment',
    'memoryTellMomentHint':
        'Comment cela s’est-il passé ? Partagez les détails à garder…',
    'memoryBabyInfoOptionalTitle': 'Infos bébé (optionnel)',
    'memoryBabyMoodLabel': 'Humeur/état',
    'memoryBabyMoodHint': 'Ex. : Heureux',
    'memoryMomentInfoTitle': 'Infos sur ce moment',
    'memoryStatAgeLabel': 'Âge',
    'memoryStatWeightLabel': 'Poids',
    'memoryStatHeightLabel': 'Taille',
    'memoryStatMoodLabel': 'Comment allait-il·elle',
    'memoryMotherNotesLabel': 'Notes de maman',
    'memoryTipForYouTitle': 'Un conseil pour vous',
    'memoryShareButton': 'Partager',
    'memoryFavoriteButton': 'Mettre en favori',
    'memoryFavoritedButton': 'En favori',
    'weeklyPhotoPublicExplainer':
        'En la marquant comme publique, cette photo pourra participer à la Photo de la semaine et être vue par d’autres mamans dans FaceBaby.',
    'weeklyPhotoPublicOff': 'Privée',
    'weeklyPhotoPublicOn': 'Publique',
    'weeklyPhotoPublicNeedPhoto':
        'Ajoutez une photo pour rendre ce souvenir public.',
    'weeklyPhotoConfirmTitle': 'Rendre cette photo publique ?',
    'weeklyPhotoConfirmBody':
        'Acceptez-vous d’afficher cette photo à d’autres utilisateurs si vous êtes tirée au sort de la semaine ?',
    'weeklyPhotoConfirmNo': 'Non',
    'weeklyPhotoConfirmYes': 'Oui',
    'weeklyPhotoParticipatingBadge': 'Participe à la Photo de la semaine',
    'weeklyPhotoWinnerBadge':
        'Ce souvenir a été choisi comme Photo de la semaine 💜',
    'weeklyPhotoShowBabyFirstName':
        'Afficher le prénom de bébé sur le mur public',
    'weeklyPhotoDisclaimerFooter':
        'Seules les photos marquées comme publiques participent. Vous pouvez retirer cette option à tout moment.',
    'weeklyPhotoReportLink': 'Signaler',
    'weeklyPhotoReportTitle': 'Signaler la photo',
    'weeklyPhotoReportHint':
        'Décrivez le motif du signalement. L’équipe FaceBaby l’examinera.',
    'weeklyPhotoReportMessageLabel': 'Motif du signalement',
    'weeklyPhotoReportSubmit': 'Envoyer le signalement',
    'weeklyPhotoReportSuccess':
        'Signalement envoyé. Merci d’aider à garder la communauté sûre.',
    'weeklyPhotoReportNeedLogin': 'Connectez-vous pour envoyer un signalement.',
    'weeklyPhotoReportMessageTooShort':
        'Écrivez au moins 5 caractères dans le motif du signalement.',
    'weeklyPhotoReportMessageTooLong': 'Le texte du signalement est trop long.',
    'weeklyPhotoReportFailed':
        'Impossible d’envoyer le signalement. Réessayez.',
    'weeklyPhotoSectionTitleMale': 'Prince de la semaine',
    'weeklyPhotoSectionTitleFemale': 'Princesse de la semaine',
    'weeklyPhotoHomeHeroMale': 'PRINCE DE LA SEMAINE',
    'weeklyPhotoHomeHeroFemale': 'PRINCESSE DE LA SEMAINE',
    'weeklyPhotoSectionSubtitle':
        'Un souvenir spécial partagé par une maman FaceBaby.',
    'weeklyPhotoViewMemory': 'Voir le souvenir',
    'weeklyPhotoBabyFallback': 'Un bébé FaceBaby',
    'weeklyPhotoDisclaimerShort':
        'Seules les photos marquées comme publiques participent. Vous pouvez retirer cette option à tout moment.',
    'weeklyPhotoPublicDetailAppBar': 'Souvenir de la semaine',
    'weeklyPhotoWinnerCongratsTitle': 'Félicitations, Maman !',
    'weeklyPhotoWinnerCongratsBody':
        'La photo de votre Princesse a été choisie cette semaine ! Allons tous la célébrer.\n\nLa famille FaceBaby vous remercie de partager ce beau moment avec nous ! 💜',
    'weeklyPhotoWinnerCongratsBodyMale':
        'La photo de votre Prince a été choisie cette semaine ! Allons tous le célébrer.\n\nLa famille FaceBaby vous remercie de partager ce beau moment avec nous ! 💜',
    'weeklyPhotoWinnerCongratsBodyFemale':
        'La photo de votre Princesse a été choisie cette semaine ! Allons tous la célébrer.\n\nLa famille FaceBaby vous remercie de partager ce beau moment avec nous ! 💜',
    'weeklyPhotoWinnerCongratsOk': 'Confirmer',
    'memoryEditTitle': 'Modifier le souvenir',
    'memoryNewTitle': 'Nouveau souvenir',
    'memoryMomNotesFieldLabel': 'Remarques de maman',
    'memorySaveChanges': 'Enregistrer les modifications',
    'memorySaveNew': 'Enregistrer le souvenir',
    'memoryNoDescription': 'Pas encore de description pour ce moment.',
    'memoryPhotoAddTitle': 'Ajoutez une photo',
    'memoryPhotoEditTitle': 'Changer la photo',
    'memoryTapToPickPhoto': 'Toucher',
    'memoryAgeHintExample': 'Ex. : 10 jours',
    'memoryWeightHintExample': 'Ex. : 3,28',
    'memoryHeightHintExample': 'Ex. : 49',
    'memorySaveNeedPhotoOrText':
        'Ajoutez une photo ou une description pour enregistrer.',
    'memorySaveFail': 'Enregistrement impossible :',
    'memoryShareWebOnlyMobile':
        'Le partage image/PDF est disponible dans l’app installée (Android/iOS).',
    'memoryShareSheetJpegTitle': 'Image (JPG)',
    'memoryShareSheetJpegSubtitle': 'Choisissez WhatsApp, e-mail, Bluetooth…',
    'memoryShareSheetPdfTitle': 'PDF (une page)',
    'memoryShareSheetPdfSubtitle': 'Pratique pour e-mail ou archives',
    'memorySharePlatformUnavailable': 'Indisponible sur cette plateforme.',
    'memoryShareError': 'Partage impossible : {error}',
    'memoryFooterBranding': 'FaceBaby • Livre de souvenirs',
    'memoryTipFirstSmile':
        'Le sourire est l’une des premières façons de se lier. Continuez à lui parler et à sourire !',
    'memoryTipFirstLaugh':
        'Le rire renforce le lien. Reproduisez les jeux qui font rire bébé.',
    'memoryTipFirstFeeding':
        'Les premiers jours d’allaitement sont une adaptation. En cas de doute, demandez un avis pro.',
    'memoryTipFirstSteps':
        'Chaque bébé a son rythme. Cadre sécurisé, encouragement sans pression.',
    'memoryTipDefault':
        'Ces moments restent dans la famille pour toujours. Continuez à les noter.',
    'memoryAgeOneDay': '1 jour',
    'memoryAgeManyDays': '{n} jours',
    'helloMomNamed': 'Salut, Maman {name} !',
    'registerVerb': 'Enregistrer',
    'viewCalendar': 'Voir le calendrier',
    'shortcutMilk': 'Biberon',
    'shortcutSleep': 'Sommeil',
    'shortcutVaccines': 'Vaccins',
    'shortcutFamily': 'Famille',
    'shortcutFamilyHomeSub': 'Arbre et profil familial',
    'shortcutHealthHomeSub': 'Vaccins, consultations et symptômes',
    'shortcutFeedingSession': 'Alimentation',
    'homeFedAgo': 'A mangé il y a {when}',
    'homePeeAgo': 'Pipi il y a {when}',
    'homePooAgo': 'Caca il y a {when}',
    'homeNextNow': 'Prochaine : maintenant.',
    'homeNextIn': 'Prochaine dans {n} min.',
    'homeStatusOk': 'Tout va bien',
    'homeStatusWarn': 'Attention légère',
    'homeStatusHungry': 'Peut avoir faim',
    'homeTipTitle': 'Astuce du jour',
    'homeTipBody': 'Des routines douces aident {name} à mieux dormir la nuit.',
    'homeYesterdayBabaTitle': 'IA Nounou · hier',
    'homeYesterdayBabaFallback':
        'Notez la routine de {name} pour une lecture pédiatrique.',
    'homeYesterdayBabaRoutineQuiet':
        'Peu de saisies — une routine prévisible aide la régulation émotionnelle.',
    'homeYesterdayBabaRoutine':
        '{feeds} tétées · sommeil {sleep} · {diapers} changes.',
    'homeYesterdayBabaRoutineLowSleep':
        '{feeds} tétées · sommeil {sleep} (faible) · {diapers} changes.',
    'homeYesterdayBabaGrowthBothWithin':
        'Poids et taille sur la courbe de référence.',
    'homeYesterdayBabaGrowthNoData': 'Mettez à jour poids/taille sur la courbe.',
    'homeYesterdayBabaGrowthBelow':
        'Croissance sous la courbe — en parler au pédiatre.',
    'homeYesterdayBabaGrowthAbove':
        'Croissance au-dessus de la courbe — à revoir en consultation.',
    'homeYesterdayBabaGrowthCombo': 'Courbe : poids {weight}, taille {height}.',
    'homeYesterdayBabaBandWithin': 'adéquat',
    'homeYesterdayBabaBandBelow': 'bas',
    'homeYesterdayBabaBandAbove': 'haut',
    'homeYesterdayBabaBandUnknown': '—',
    'homeGreetingSubtitle': 'Quel plaisir de vous voir ici aujourd’hui !',
    'summaryWeightNotYet': 'Pas encore enregistré',
    'summarySleepNotYet': 'Aucun sommeil enregistré aujourd’hui',
    'shortcutMilkHomeSub': 'Enregistrer une tétée',
    'shortcutGrowthHomeSub': 'Enregistrer poids et taille',
    'shortcutSleepHomeSub': 'Enregistrer le sommeil',
    'homeTileDiapers': 'Changes de couche',
    'homeOneDayOld': '1 jour',
    'homeDaysOld': '{d} jours',
    'babyAgeOneWeek': '1 semaine',
    'babyAgeWeeks': '{n} semaines',
    'babyAgeOneMonth': '1 mois',
    'babyAgeMonths': '{n} mois',
    'babyAgeOneYear': '1 an',
    'babyAgeYears': '{n} ans',
    'summaryFeedings': 'TÉTÉES',
    'summarySleep': 'SOMMEIL TOTAL',
    'summaryLastFeed': 'Dernière à {time}',
    'summaryLastSleep': 'Dernier à {time}',
    'summaryDiapers': 'COUCHES',
    'summaryFeedingsValue': '{n} · {m} min',
    'summaryFeedingsCountOne': '1 tétée',
    'summaryFeedingsCountMany': '{n} tétées',
    'summaryFeedingsMinutes': '{m} min',
    'summaryDiapersValue': 'Total {total} · Pipi {pee} · Caca {poo}',
    'summaryDiapersTotal': 'Total {total} changes',
    'summaryDiapersChangesOne': '1 change',
    'summaryDiapersChangesMany': '{n} changes',
    'summaryDiapersPeePoo': '{pee} - Pipi    {poo} - Caca',
    'summarySleepValue': '{s} · {t}',
    'summarySleepSessionsOne': '1 sieste',
    'summarySleepSessionsMany': '{s} siestes',
    'summaryWeight': 'POIDS',
    'homeSummaryExtraHint': 'Totaux du jour sélectionné',
    'add': 'Ajouter',
    'labelWeight': 'Poids',
    'labelHeight': 'Taille',
    'labelHead': 'Périmètre crânien',
    'growthTabWeight': 'Poids',
    'growthTabHeight': 'Taille',
    'growthTabHead': 'Tête',
    'growthTabSummary': 'Résumé',
    'growthAtBirth': 'À la naissance',
    'growthCardCurrent': 'Actuel',
    'growthCardChange': 'Variation',
    'growthAddWeight': 'Ajouter le poids',
    'growthAddHeight': 'Ajouter la taille',
    'growthAddHead': 'Ajouter le périmètre',
    'growthSummaryIntro': 'Vue d’ensemble du poids et de la taille.',
    'growthChartCaption': '{name} — {metric}',
    'growthChartDeltaHint':
        'Axe vertical : variation par rapport à la valeur de naissance (0 = naissance).',
    'growthHistoryTitle': '{label} (historique)',
    'invalidGrowthValue': 'Saisissez une valeur valide pour {label}.',
    'growthSaved': '{label} enregistré avec succès.',
    'growthEmpty': 'Aucun enregistrement de {label} pour le moment.',
    'notifyGrowthWeightDownTitle': 'Poids inférieur au précédent',
    'notifyGrowthWeightDownBody':
        'Le dernier poids enregistré est inférieur au précédent. En cas de doute, contactez votre pédiatre.',
    'notifyGrowthStaleTitle': 'Aucune mesure de croissance depuis un moment',
    'notifyGrowthStaleBody':
        'Plus de 30 jours se sont écoulés depuis la dernière mesure de croissance (poids, taille ou périmètre crânien). Cela fait {days} jours — ajoutez une nouvelle mesure.',
    'reportDailyScreenTitle': 'Rapport quotidien',
    'reportDayDetailsTitle': 'Détails du jour',
    'reportDailyPickDayTooltip': 'Choisir le jour',
    'reportDailySubtitleSleepQuality': 'Qualité du sommeil',
    'reportDailySubtitleTotalSleep': 'Sommeil total',
    'reportDailySubtitleLongestStretch': 'Plus longue période continue',
    'reportDailySubtitleFeedTotal': 'Total des tétées',
    'reportDailySubtitleFeedAvg': 'Durée moyenne',
    'reportDailySubtitleFeedLast': 'Dernière tétée',
    'reportDailySubtitleDiaperTotal': 'Total des changes',
    'reportDailySubtitleDiaperWet': 'Couches mouillées',
    'reportDailySubtitleDiaperDirty': 'Couches sales',
    'reportDailySubtitleMoodMajority': 'La plupart du jour',
    'reportDailySubtitleMoodIrrit': 'Irritabilité',
    'reportDailySubtitleWeightLast': 'Dernière mesure',
    'reportSleepQualityGood': 'Bonne',
    'reportSleepQualityOk': 'Ok',
    'reportSleepQualityBad': 'Fragile',
    'reportSleepQualityMixed': 'Variable',
    'reportVsYesterdayShort': 'vs hier',
    'reportVsYesterdayNA': '—',
    'reportVsYesterdayPct': '{pct}%',
    'reportLongestStretchHint': '{start} – {end}',
    'reportNapsLabel': 'Siestes',
    'reportTotalSmallLabel': 'Total',
    'reportComparedAgeLabel': 'Comparé à la moyenne d’âge',
    'reportBenchmarkAbove': 'Au-dessus de la moyenne',
    'reportBenchmarkNear': 'Proche de la moyenne',
    'reportBenchmarkBelow': 'Sous la moyenne',
    'reportIrritLow': 'Faible',
    'reportIrritMedium': 'Modérée',
    'reportIrritHigh': 'Élevée',
    'reportIrritUnknown': 'Pas de données',
    'reportTabSleep': 'Sommeil',
    'reportTabFeedings': 'Tétées',
    'reportTabDiapers': 'Couches',
    'reportTabMood': 'Humeur',
    'reportAiInsightsTitle': 'Insights',
    'reportTimelineTitle': 'Chronologie du jour',
    'reportShareSoon': 'Partager (bientôt)',
    'reportFeedingChartCaption': 'Tétées par heure',
    'reportSleepChartCaption': 'Sommeil par heure',
    'reportNoDataHint':
        'Pas assez de données enregistrées pour cette métrique.',
    'reportInsightSleepAgeGood':
        'Le sommeil total est proche de ce qui est attendu pour l’âge — bon signe de repos récupérateur.',
    'reportInsightSleepAgeLow':
        'Le sommeil est sous la plage habituelle pour cet âge ; surveillez les signes de fatigue et le rythme du soir.',
    'reportInsightFeedsOften':
        'Beaucoup de tétées dans la journée — fréquent lors des poussées de croissance ; noter la durée aide à voir les moyennes.',
    'reportInsightDiapersFrequent':
        'Changes fréquents — l’hydratation peut être bonne ou la peau peut nécessiter de l’attention.',
    'reportInsightMoodLine':
        'Humeur dominante enregistrée dans les souvenirs : {mood}.',
    'reportWeeklyScreenTitle': 'Rapport hebdomadaire',
    'reportWeekDetailsTitle': 'Détails de la semaine',
    'reportWeeklyPickWeekTooltip': 'Choisir une semaine (n’importe quel jour)',
    'reportWeeklySummaryTitle': 'Résumé de la semaine',
    'reportWeeklyTrendsTitle': 'Tendances',
    'reportWeeklySeeFullDetails': 'Voir le rapport complet',
    'reportWeeklyPartialWeekHint':
        'Moyennes et tendances : lundi à {weekday} (semaine en cours).',
    'reportWeeklyFutureWeekHint':
        'Cette semaine n’a pas encore commencé dans le calendrier — choisissez une autre semaine.',
    'reportWeeklyLoadErrorPrefix': 'Impossible de charger le rapport :',
    'reportWeeklyToneCalm': 'calme',
    'reportWeeklyToneActive': 'chargée',
    'reportWeeklySleepUnknown':
        'Pas assez de données de sommeil pour comparer les semaines.',
    'reportWeeklyFirstWeekSleepLine':
        'C’est la première semaine avec des entrées : continuez à noter pour voir les tendances.',
    'reportWeeklySleepStableShort':
        'Le sommeil est resté stable par rapport à la semaine précédente.',
    'reportWeeklySleepUp':
        'Le sommeil s’est amélioré d’environ {pct}% par rapport à la semaine précédente.',
    'reportWeeklySleepDown':
        'Le sommeil a baissé d’environ {pct}% par rapport à la semaine précédente.',
    'reportWeeklyFeedStableLine': 'Les tétées sont restées régulières.',
    'reportWeeklyFeedUp':
        'Les tétées quotidiennes ont augmenté d’environ {pct}% en moyenne.',
    'reportWeeklyFeedDown':
        'Les tétées quotidiennes ont diminué d’environ {pct}% en moyenne.',
    'reportWeeklyHeroTemplate':
        '{name} a eu une semaine {tone} ! {sleep} {feed}',
    'reportWeeklyTrendLabelImproved': 'Amélioré',
    'reportWeeklyTrendLabelWorse': 'Moins bien',
    'reportWeeklyTrendLabelStable': 'Stable',
    'reportWeeklyTrendLabelUnknown': '—',
    'reportWeeklyTrendLabelEvolving': 'En évolution',
    'reportWeeklyTrendLabelIncreased': 'Augmenté',
    'reportWeeklyTrendNA': '—',
    'reportWeeklyHighlightSleep':
        'Point positif : sommeil plus récupérateur cette semaine.',
    'reportWeeklyHighlightFeedingStable':
        'Point positif : rythme d’alimentation stable.',
    'reportWeeklyHighlightDiaperUp':
        'Note : plus de changes — hydratation ou digestion plus active.',
    'reportWeeklyHighlightWeight': 'Point positif : prise de poids saine.',
    'reportWeeklyHighlightGeneric':
        'Continuez à enregistrer pour des tendances plus claires.',
    'reportWeeklyAvgFeedsDay': 'Moyenne quotidienne : {avg} tétées.',
    'reportWeeklyAvgDiapersDay': 'Moyenne quotidienne : {avg} changes.',
    'reportWeeklySleepHoursChartTitle': 'Heures de sommeil par jour',
    'reportWeeklyAvgWeekLabel': 'Moyenne hebdomadaire',
    'reportWeeklyVsPrevWeekShort': 'vs semaine précédente',
    'reportWeeklyInsightsCardTitle': 'Insights IA',
    'reportWeeklyPatternsTitle': 'Schémas détectés',
    'reportWeeklySeeAllAnalyses': 'Voir toutes les analyses',
    'reportWeeklyHeatmapSoon': 'Carte thermique horaire bientôt disponible.',
    'reportWeeklyFeedChartCaption': 'Tétées par jour',
    'reportWeeklyDiaperChartCaption': 'Changes par jour',
    'reportWeeklyPatternWeekend':
        'Le sommeil tend à s’allonger un peu le week-end.',
    'reportWeeklyPatternFeedingDown':
        'Moins de tétées en moyenne — fréquent quand les intervalles s’allongent.',
    'reportWeeklyPatternDefault':
        'Le schéma hebdomadaire semble stable — ajustez selon le rythme de bébé.',
    'reportWeeklyInsightSleepNeutral':
        'Le sommeil était similaire à la semaine précédente.',
    'reportWeeklyInsightSleepBetter':
        'Plus de sommeil que la semaine dernière — bon signe.',
    'reportWeeklyInsightSleepLess':
        'Le sommeil total a baissé — à surveiller la nuit.',
    'reportWeeklyInsightTemplate': '{name} : {sleep}',
    'reportMonthlyScreenTitle': 'Rapport mensuel',
    'reportMonthlyAvgWeight': 'Poids moyen',
    'reportMonthlyAvgHeight': 'Taille moyenne',
    'reportMonthlyGrowthChartEmpty':
        'Ajoutez au moins deux relevés de poids ce mois-ci pour voir le graphique.',
    'reportMonthlySleepSection': 'Sommeil',
    'reportMonthlySleepAvg': 'Moyenne mensuelle (par jour)',
    'reportMonthlyVsPrevMonth': 'vs mois précédent',
    'reportMonthlyBestWeeks': 'Semaines avec le plus de sommeil',
    'reportMonthlySleepTrendUp':
        'Tendance générale : sommeil plus récupérateur ce mois-ci.',
    'reportMonthlySleepTrendDown':
        'Tendance générale : moins de sommeil total que le mois précédent.',
    'reportMonthlySleepTrendStable':
        'Tendance générale : sommeil stable durant le mois.',
    'reportMonthlySleepTrendUnknown':
        'Pas assez de données pour comparer avec le mois précédent.',
    'reportMonthlySleepExplain':
        'La moyenne de sommeil par jour additionne les sessions enregistrées par jour civil du mois et divise par le nombre de jours du mois.',
    'reportMonthlyFeedingSection': 'Alimentation',
    'reportMonthlyFeedFreq': 'Fréquence moyenne (tétées/jour)',
    'reportMonthlyFeedingExplain':
        'La fréquence moyenne correspond au total des tétées ou biberons du mois divisé par les jours du calendrier.',
    'reportMonthlyPredominantHours':
        'Horaires les plus fréquents (fin de tétée)',
    'reportMonthlyMemoriesTitle': 'Souvenirs du mois',
    'reportMonthlySeeAllMemories': 'Voir tout',
    'reportMonthlyMemoriesEmpty': 'Aucune photo dans les souvenirs de ce mois.',
    'reportMonthlyVideosHint':
        'Les vidéos apparaîtront lorsqu’elles seront enregistrées dans vos moments.',
    'reportSleepAdvScreenTitle': 'Rapport de sommeil',
    'reportSleepAdvScoreTitle': 'Score de sommeil',
    'reportSleepAdvMetricsTitle': 'Métriques de la semaine',
    'reportSleepAdvEfficiency': 'Efficacité du sommeil',
    'reportSleepAdvVsPrevPct':
        'Variation d’efficacité : {pct}% (vs semaine précédente)',
    'reportSleepAdvOnset': 'Temps jusqu’au premier sommeil nocturne',
    'reportSleepAdvAwakenings': 'Réveils par nuit (moy.)',
    'reportSleepAdvAwakeningsTotal': 'Réveils cette semaine : {n}',
    'reportSleepAdvLongest': 'Plus longue période continue',
    'reportSleepAdvAvgDailySleep': 'Sommeil moyen par jour',
    'reportSleepAdvIdealTitle': 'Meilleure heure pour s’endormir',
    'reportSleepAdvIdealFooter':
        'Fenêtre estimée depuis vos données (pas un avis médical).',
    'reportSleepAdvSeeFullAnalysis': 'Voir l’analyse complète',
    'reportSleepAdvChartsSection': 'Session de sommeil',
    'reportSleepAdvChartsSleepTrend': 'Rythme du sommeil (cette semaine)',
    'reportSleepAdvChartsCompare': 'Comparaison avec la semaine précédente',
    'reportSleepAdvChartsDistribution': 'Jour et nuit (total semaine)',
    'reportSleepAdvChartsBars':
        'Volume de sommeil : cette semaine vs précédente',
    'reportSleepAdvDayPhase': 'Sommeil de jour (6h–18h)',
    'reportSleepAdvNightPhase': 'Sommeil de nuit (18h–6h)',
    'reportSleepAdvDistributionEmpty': 'Pas de données à répartir.',
    'reportSleepAdvLegendThisWeek': 'Cette semaine',
    'reportSleepAdvLegendPrevWeek': 'Semaine précédente',
    'reportSleepAdvScoreBreakdown': 'Ce que reflète le score',
    'reportSleepAdvBreakdownLine':
        'Efficacité : {e} pts • Longues périodes : {s} pts • Réveils : {a} pts • Régularité : {c} pts.',
    'reportSleepAdvNotEnoughData':
        'Encore peu de données cette semaine — valeurs indicatives.',
    'reportSleepAdvStatusExcellent': 'Excellent',
    'reportSleepAdvStatusGood': 'Bon',
    'reportSleepAdvStatusRegular': 'Régulier',
    'reportSleepAdvStatusPoor': 'Fragile',
    'reportSleepAdvBadgeVeryGood': 'Très bon',
    'reportSleepAdvBadgeGood': 'Bon',
    'reportSleepAdvBadgeOk': 'Modéré',
    'reportSleepAdvBadgeAttention': 'À suivre',
    'reportSleepAdvBadgeIdeal': 'Idéal',
    'reportSleepAdvBadgeUnknown': 'Pas de données',
    'reportSleepAdvBadgeLow': 'Faible',
    'reportSleepAdvBadgeModerate': 'Modéré',
    'reportSleepAdvBadgeHigh': 'Élevé',
    'alertsScreenIntro':
        'Choisissez quels rappels FaceBaby peut vous envoyer. Toutes les notifications restent locales sur cet appareil.',
    'alertsExactAlarmAndroidTitle': 'Autorisation d’alarmes exactes (Android)',
    'alertsExactAlarmAndroidBody':
        'Pour recevoir les rappels à l’heure prévue, autorisez FaceBaby à utiliser les alarmes exactes / « Alarmes et rappels » dans les paramètres du système. Sans cela, Android peut retarder ou ignorer la notification.',
    'alertsExactAlarmAndroidOpenSettings': 'Ouvrir les paramètres',
    'alertsSectionFeeding': 'Alimentation',
    'alertsRuleFeeding':
        'Lorsque l’alerte est activée, l’app programme une notification après le délai choisi depuis la dernière tétée ou le dernier biberon.',
    'alertsSectionDiaper': 'Couche',
    'alertsRuleDiaper':
        'L’app suggère un rappel environ 3 h 30 après le dernier change enregistré. Un nouveau change annule et reprogramme le rappel.',
    'alertsSectionSleep': 'Sommeil',
    'alertsRuleSleep':
        'Avec la fin du dernier sommeil enregistré et l’âge de bébé, l’app peut programmer des rappels autour de la fenêtre d’éveil.',
    'alertsSectionGrowth': 'Croissance et mesures',
    'alertsRuleGrowth':
        'Avertit si le dernier poids est inférieur au précédent, ou si aucune mesure n’a été enregistrée depuis plus de 30 jours.',
    'alertsTestTitle': 'Tester les notifications',
    'alertsTestBody':
        'Déclenche une notification immédiate et en programme une autre dans environ 30 secondes. Utile pour vérifier que le système délivre les notifications de l’app.',
    'alertsTestRun': 'Lancer le test',
    'alertsTestResync': 'Forcer la reprogrammation (rappels réels)',
    'alertsTestImmediateTitle': 'FaceBaby — test immédiat',
    'alertsTestImmediateBody':
        'Si vous voyez ce message, le canal immédiat fonctionne.',
    'alertsTestScheduledTitle': 'FaceBaby — test programmé',
    'alertsTestScheduledBody':
        'Cette notification a été programmée via AlarmManager (~30 s).',
    'alertsTestAllScheduleModesFailed': 'AlarmManager a refusé tous les modes',
    'alertsTestSentOk':
        'Envoyé. Vous devriez recevoir maintenant l’immédiate et dans ~30 s la programmée.',
    'alertsTestFailed': 'Échec : {errors}',
    'sleepToggleAlertsSubtitle':
        'Rappels basés sur la fin du dernier sommeil et l’âge de bébé.',
    'diaperToggleAlerts': 'Rappels de couche',
    'diaperToggleAlertsSubtitle':
        'Notification autour du prochain change suggéré.',
    'healthGrowthToggleAlerts': 'Alertes de croissance',
    'healthGrowthToggleAlertsSubtitle':
        'Alertes de poids et d’absence prolongée de mesures.',
    'feedingScreenAlertsHint': 'Pour modifier le délai, ouvrez Plus › Alertes.',
    'sleepBannerEmpty': 'Aucun sommeil enregistré pour l’instant.',
    'sleepAlertsWakeWindowRulerValueAuto':
        'Temps effectif sur cette échelle : {m} min (automatique selon l’âge).',
    'sleepAlertsWakeWindowRulerValueCustom':
        'Temps sur cette échelle : {m} min (valeur personnalisée).',
    'sleepAlertsWakeWindowSliderLabelAuto': '{m} min · auto',
    'sleepAlertsWakeWindowSliderLabelCustom': '{m} min',
    'sleepAlertsApproachRulerValueDefault':
        'Anticipation effective sur cette échelle : {m} min (par défaut).',
    'sleepAlertsApproachRulerValueCustom':
        'Anticipation sur cette échelle : {m} min.',
    'sleepAlertsApproachSliderLabelDefault': '{m} min · défaut',
    'sleepAlertsApproachSliderLabelCustom': '{m} min',
    'sleepAlertsWakeWindowAutomatic':
        'Limite d’éveil utilisée pour l’alerte : {m} min (automatique selon le tableau par âge).',
    'sleepAlertsWakeWindowAutomaticNoBirth':
        'Ajoutez la date de naissance de bébé dans le profil pour la bonne valeur ; en attendant nous utilisons {m} min de référence.',
    'sleepAlertsMonthsApprox': 'Tableau de référence : ~{n} mois',
    'sleepAlertsWakeWindowCustom': 'Limite d’éveil personnalisée : {m} min.',
    'sleepAlertsApproachAuto':
        'Avertissement avant la limite : {m} min d’avance (valeur par défaut).',
    'sleepAlertsApproachCustom':
        'Avertissement avant la limite : {m} min d’avance (personnalisé).',
    'sleepAppBar': 'Sommeil',
    'sleepTitle': 'Sommeil',
    'sleepIntro': 'Enregistrez et suivez les siestes et le sommeil nocturne.',
    'sleepComingTitle': 'Bientôt',
    'sleepComingBody':
        'Cet écran est prêt pour l’enregistrement du sommeil.\nNous connecterons bientôt la base de données pour afficher le dernier sommeil, le total du jour et l’historique.',
    'sleepSessionTitle': 'Sommeil en cours',
    'sleepSessionStartedAt': 'Démarré à {time}',
    'sleepStatusSleeping': 'Dort',
    'sleepStatusPaused': 'En pause',
    'sleepWakeButton': 'S’EST RÉVEILLÉ ?',
    'sleepThisCardTitle': 'Ce sommeil',
    'sleepLabelStart': 'Début',
    'sleepLabelEnd': 'Fin',
    'sleepLabelDuration': 'Durée',
    'sleepLabelQuality': 'Qualité',
    'sleepObservationsTitle': 'Observations',
    'sleepObservationHint': 'Ajouter une observation…',
    'sleepPause': 'Pause',
    'sleepResume': 'Reprendre',
    'sleepCancelSession': 'Annuler le sommeil',
    'sleepStartButton': 'DÉMARRER LE SOMMEIL',
    'sleepSavedOk': 'Sommeil enregistré.',
    'sleepResultDialogTitle': 'État du sommeil',
    'sleepResultShortTitle': 'A dormi moins que prévu',
    'sleepResultExpectedTitle': 'Sommeil dans la norme',
    'sleepResultLongTitle': 'A dormi plus que prévu',
    'sleepResultDurationLine': 'Durée enregistrée : {duration}.',
    'sleepResultExpectedLine':
        'Référence pour l’âge : environ {min}–{max} min.',
    'sleepResultShortBody':
        'Sommeil court. Surveillez les signes de fatigue et préparez un environnement calme pour le prochain repos.',
    'sleepResultExpectedBody':
        'Bonne fenêtre de repos. Ce sommeil est proche de ce qui est attendu pour cet âge.',
    'sleepResultLongBody':
        'Sommeil plus long. Peut être une récupération de fatigue ; surveillez si cela se répète souvent.',
    'sleepConfirmBackTitle': 'Quitter le suivi du sommeil ?',
    'sleepConfirmBackBody':
        'Cette session n’est pas encore enregistrée. La supprimer ?',
    'sleepConfirmCancelSessionTitle': 'Annuler le sommeil ?',
    'sleepConfirmCancelSessionBody': 'Le temps de cette session sera perdu.',
    'sleepDiscard': 'Supprimer',
    'sleepHistoryTitle': 'Historique du sommeil',
    'sleepHistoryEmpty': 'Aucune session de sommeil pour l’instant.',
    'historyShowButton': 'Voir l’historique',
    'historyHideButton': 'Masquer l’historique',
    'historyViewMoreButton': 'Voir plus',
    'sleepUpdatedOk': 'Sommeil mis à jour.',
    'sleepBannerNextNap': 'Prochaine sieste dans ~{min} min',
    'sleepWindowTitle': 'Fenêtre de sommeil actuelle',
    'sleepWindowEarly': 'Avant la fenêtre idéale',
    'sleepWindowIdeal': 'Idéale',
    'sleepWindowLate': 'En retard',
    'sleepRoutineLastLabel': 'Dernier sommeil : il y a {ago}',
    'sleepRoutineLastNever': 'Dernier sommeil : aucun enregistrement',
    'sleepRoutineNextPrefix': 'Prochaine sieste :',
    'sleepNextApproxMin': 'dans ~{min} min',
    'sleepRoutineNextNow': 'maintenant — bon moment pour essayer',
    'sleepStatusEarly': '🟡 Avant la fenêtre idéale',
    'sleepStatusIdeal': '🟢 Fenêtre idéale',
    'sleepStatusOverdue': '🔴 Probablement très fatigué',
    'sleepHeroAwakeBadge': 'Éveillé',
    'sleepHeroAwakeCaption':
        'La barre verte → jaune → rouge indique depuis combien de temps bébé est éveillé et quand la sieste est due. Pour dormir, touchez DÉMARRER LE SOMMEIL.',
    'sleepHeroSleepingBadge': 'Dort',
    'sleepHeroSleepingCaption':
        'À son réveil, touchez Terminer le sommeil pour enregistrer cette session.',
    'sleepRoutineCardTitle': 'Prochain sommeil',
    'sleepRoutineVigilHighlight':
        'Fenêtre d’éveil dans l’app : {min}–{max} min entre les sommeils (fixe selon l’âge en mois — non configurable).',
    'sleepRoutineStatusLine': 'État : {status}',
    'sleepIdealForAge': 'Même tableau (selon l’âge)',
    'sleepAgeMonthsLabel': '{n} mois',
    'sleepWindowMinMax': '{min}–{max} min',
    'sleepLegendG': '🟢 fenêtre idéale',
    'sleepLegendY': '🟡 avant la fenêtre idéale',
    'sleepLegendR': '🔴 en retard',
    'sleepWakeWindowExplainer':
        'Indique depuis combien de temps bébé est éveillé depuis la fin du dernier sommeil (pas la durée du sommeil). Jaune : pas encore dans la fenêtre typique de la prochaine sieste.',
    'sleepFinalizeButton': 'TERMINER',
    'sleepSleepingFor': 'Dort depuis {when}',
    'sleepInsightTitle': 'Résumé du jour',
    'sleepInsightNaps': 'Aujourd’hui : {n} siestes',
    'sleepInsightAvg': 'Moyenne : {min} min',
    'sleepInsightTrendDown': '💡 Moins de sommeil que d’habitude aujourd’hui',
    'sleepInsightTrendOk': '💡 Rythme de sommeil stable aujourd’hui',
    'sleepHistoryToday': 'Aujourd’hui',
    'sleepToggleAlerts': 'Activer les alertes de sommeil',
    'sleepNotifTitle': 'Sommeil',
    'sleepNotifBeforeBody': 'C’est peut-être un bon moment pour coucher bébé.',
    'sleepNotifOverdueBody':
        'Votre bébé peut être fatigué — essayez de commencer le sommeil calmement.',
    'sleepNotifWakeOverdueBodyMale':
        'Cela fait plus de {hours} h qu’il dort, va le voir, Maman.',
    'sleepNotifWakeOverdueBodyFemale':
        'Cela fait plus de {hours} h qu’elle dort, va la voir, Maman.',
    'notifChannelRemindersName': 'Rappels',
    'notifChannelRemindersDesc':
        'Alertes d’alimentation, de couches et de sommeil.',
    'notifChannelGrowthName': 'Croissance',
    'notifChannelGrowthDesc':
        'Alertes de poids et d’absence prolongée de mesures.',
    'exampleCard': 'Exemple de carnet :',
  },
  AppLang.de: {
    'appName': 'FaceBaby',
    'onbSelectDate': 'Datum auswählen',
    'onbBabyFallback': 'Baby',
    'onbMomFallback': 'Mama',
    'onbDadFallback': 'Papa',
    'onbWelcomeTitle': 'Begleiten und beobachten',
    'onbWelcomeSubtitle': 'die Entwicklung mit Liebe.',
    'onbFeatureSleep': 'Schlaf',
    'onbFeatureFeeding': 'Ernährung',
    'onbFeatureGrowth': 'Wachstum',
    'onbFeatureMemories': 'Erinnerungen',
    'onbFeatureAlerts': 'Warnungen',
    'onbFeatureLove': 'Viel Liebe',
    'onbCreateBabyProfile': 'Babyprofil erstellen',
    'onbExistingAccountLogin': 'Ich habe bereits ein Konto / Einloggen',
    'onbContinue': 'Weiter',
    'onbPrepareFaceBaby': 'FaceBaby vorbereiten',
    'onbPreparingTitle': 'FaceBaby wird für dich vorbereitet...',
    'onbPreparingSubtitle':
        'Benachrichtigungen, Erinnerungen und Routinen werden personalisiert.',
    'onbAuthTitle': 'Dein Basisprofil ist fertig',
    'onbAuthSubtitle':
        'Erstelle jetzt dein Konto, um alles sicher zu speichern und später zu synchronisieren.',
    'onbSignInGoogle': 'Mit Google einloggen',
    'onbSignInApple': 'Mit Apple einloggen',
    'onbContinueEmail': 'Mit E-Mail fortfahren',
    'onbAlreadyHaveAccount': 'Ich habe schon ein Konto',
    'onbWait': 'Bitte warten...',
    'onbDoneTitle': 'Fertig! Das Babyprofil wurde erstellt.',
    'onbStartTracking': 'Begleitung starten',
    'onbCouldNotPrepare':
        'Das Profil konnte gerade nicht vorbereitet werden. Bitte versuche es erneut.',
    'onbBabyNameTitle': 'Wie heißt das Baby?',
    'onbBabyNameSubtitle':
        'So fühlt sich FaceBaby mehr nach deiner Familie an.',
    'onbBabyNameHint': 'Name des Babys',
    'onbBabyBirthTitle': 'Wie lautet das Geburtsdatum?',
    'onbBabyBirthSubtitle':
        'Wir nutzen das Alter, um Schlaf, Routine und Wachstum zu personalisieren.',
    'onbBabyWeightTitle': 'Wie viel wiegt das Baby?',
    'onbBabyWeightSubtitle':
        'Ziehe am Lineal, um auszuwählen. Du kannst zwischen Kg und Lb wechseln.',
    'onbBabyHeightTitle': 'Wie groß ist das Baby?',
    'onbBabyHeightSubtitle':
        'Nutze das Lineal, um die ungefähre Größe in deiner bevorzugten Einheit einzugeben.',
    'onbMotherNameTitle': 'Wie heißt Mama?',
    'onbMotherNameSubtitle':
        'Wir verwenden ihren Namen in den nächsten Fragen.',
    'onbMotherNameHint': 'Name der Mama',
    'onbMotherBirthTitle': 'Wie lautet Mamas Geburtsdatum?',
    'onbMotherBirthSubtitle': 'Danach fragen wir nach ihrer Größe.',
    'onbMotherHeightTitle': 'Wie groß ist {name}?',
    'onbMotherHeightSubtitle':
        'Diese Information hilft bei den Wachstumsberichten.',
    'onbRegisterFatherTitle': 'Möchtest du den Papa auch eintragen?',
    'onbRegisterFatherSubtitle':
        'Wenn du möchtest, personalisiert FaceBaby auch Papas Daten.',
    'onbFatherNameTitle': 'Wie heißt Papa?',
    'onbFatherNameSubtitle': 'So wird auch sein Lineal personalisiert.',
    'onbFatherNameHint': 'Name des Papas',
    'onbFatherBirthTitle': 'Wie lautet Papas Geburtsdatum?',
    'onbFatherBirthSubtitle': 'Danach fragen wir nach seiner Größe.',
    'onbFatherHeightTitle': 'Wie groß ist {name}?',
    'onbFatherHeightSubtitle':
        'Ein ungefährer Wert reicht, du kannst ihn später anpassen.',
    'onbBabySexTitle': 'Welches Geschlecht hat das Baby?',
    'onbSexGirl': 'Mädchen',
    'onbSexBoy': 'Junge',
    'onbSexUnknown': 'Möchte ich nicht angeben',
    'onbFirstBabyTitle': 'Ist es dein erstes Baby?',
    'onbYes': 'Ja',
    'onbNo': 'Nein',
    'onbConcernTitle': 'Was ist gerade deine größte Sorge?',
    'onbConcernSubtitle': 'Du kannst mehrere auswählen.',
    'onbConcernSleep': 'Schlaf des Babys',
    'onbConcernFeeding': 'Stillen/Ernährung',
    'onbConcernGrowth': 'Gewicht und Wachstum',
    'onbConcernRoutine': 'Tagesroutine',
    'onbConcernMemories': 'Erinnerungen und Fotos',
    'onbConcernDevelopment': 'Entwicklung',
    'onbGoalsTitle': 'Was sind deine Ziele?',
    'onbGoalsSubtitle': 'Damit personalisieren wir deine Erfahrung.',
    'onbGoalRoutine': 'Routine besser verfolgen',
    'onbGoalSleepAlerts': 'Schlafhinweise erhalten',
    'onbGoalMoments': 'Besondere Momente festhalten',
    'onbGoalReports': 'Berichte erstellen',
    'onbGoalMemoryBook': 'Erinnerungsbuch erstellen',
    'onbMessagePrefTitle': 'Spirituelle Mama, glückliches Baby.',
    'onbMessagePrefSubtitle': 'Möchtest du tägliche Nachrichten erhalten?',
    'onbMessagePrefChristian': 'Christlich',
    'onbMessagePrefHoroscope': 'Astrologisch',
    'onbMessagePrefPhilosophical': 'Philosophisch / Ökumenisch',
    'onbMessagePrefSpiritist': 'Spiritistische',
    'onbMessagePrefJewish': 'Jüdische',
    'onbMessagePrefAll': 'Alle',
    'onbDragToAdjust': 'Zum Anpassen ziehen',
    'onbEmailSheetTitle': 'Konto mit E-Mail erstellen',
    'onbYourNameHint': 'Dein Name',
    'onbEmailHint': 'E-Mail',
    'onbPasswordHint': 'Passwort',
    'onbCreateAccount': 'Konto erstellen',
    'onbValYourName': 'Gib deinen Namen ein.',
    'onbValEmailRequired': 'Gib deine E-Mail ein.',
    'onbValEmailInvalid': 'Ungültige E-Mail.',
    'onbValPasswordMin': 'Verwende mindestens 6 Zeichen.',
    'memoriesAlbumBackCoverBody':
        'FaceBaby wurde geschaffen, um kleine Momente in unvergessliche Erinnerungen zu verwandeln. Jedes Lächeln, jede Entdeckung, jede Umarmung und jeder besondere Meilenstein Ihres Babys verdient es, mit Liebe bewahrt zu werden.\n\nDieses Buch begleitet die ersten Schritte dieser wundervollen Reise und hält Erinnerungen fest, die ein Leben lang bleiben können.\n\nMehr als nur Fotos und Notizen – diese Seiten bewahren Gefühle, Geschichten und Emotionen, die die Zeit niemals auslöschen wird.\n\nDanke, dass FaceBaby Teil der Geschichte Ihrer Familie sein darf. 💛',
    'memoriesAlbumBackCoverFinale':
        'Denn die Kindheit vergeht schnell…\naber Erinnerungen bleiben für immer.',
    'memoriesAlbumQualityTitle': 'PDF-Qualität',
    'memoriesAlbumQualityShareTitle': 'Leicht — zum Teilen',
    'memoriesAlbumQualityShareDesc':
        'Komprimierte Bilder, kleinere Datei. Ideal für WhatsApp und E-Mail.',
    'memoriesAlbumQualityPrintTitle': 'Hohe Qualität — zum Drucken',
    'memoriesAlbumQualityPrintDesc':
        'Höhere Fotoauflösung. Größere Datei; besser zum Drucken.',
    'memoriesAlbumExportTitle': 'Album wird erstellt…',
    'memoriesAlbumProgressPreparing': 'Seiten werden vorbereitet…',
    'memoriesAlbumProgressImages':
        'Fotos werden verarbeitet ({current}/{total})…',
    'memoriesAlbumProgressBuilding': 'PDF wird erstellt ({current}/{total})…',
    'memoriesAlbumProgressSaving': 'Datei wird gespeichert…',
    'memoriesAlbumCancelBtn': 'Abbrechen',
    'memoriesAlbumCanceled': 'Erstellung abgebrochen.',
    'memoriesAlbumErrorNetwork':
        'Keine Internetverbindung. Netzwerk prüfen und erneut versuchen.',
    'memoriesAlbumErrorStorage':
        'Nicht genug Speicherplatz auf dem Gerät für das PDF.',
    'memoriesAlbumSkippedImages':
        '{count} Foto(s) konnten nicht eingefügt werden (Netzwerk oder ungültige Datei).',
    'home': 'Start',
    'records': 'Protokolle',
    'reports': 'Berichte',
    'memories': 'Erinnerungen',
    'more': 'Mehr',
    'helloMom': 'Hallo, Mama!',
    'today': 'Heute',
    'shortcuts': 'Schnellzugriffe',
    'registerNow': 'Jetzt eintragen',
    'edit': 'Bearbeiten',
    'todaySummary': 'Heutige Übersicht',
    'nextEvents': 'Nächste Ereignisse',
    'quickRecordsTitle': 'Schnellprotokolle',
    'quickRecordsSubtitle': 'Erfasse die Baby-Routine in wenigen Tipps.',
    'feedingAlertsSwitchTitle': 'Ernährungsalarm',
    'feedingAlertsSwitchSubtitle':
        'Benachrichtigt, wenn das eingestellte Intervall seit dem letzten Stillen oder Fläschchen vergangen ist.',
    'feedingAlertsIntervalCaption':
        'Nach der letzten Mahlzeit erinnern: {m} Min. (20–360)',
    'feedingAlertsShortcutTitle': 'Ernährungsalarm',
    'scheduledFeedingReminderBody':
        'Zeit für die Erinnerung zur Mahlzeit. Tippe zum Eintragen.',
    'scheduledDiaperReminderTitle': 'Windelwechsel',
    'scheduledDiaperReminderBody':
        'Es ist vielleicht Zeit für einen Windelwechsel. Tippe zum Eintragen.',
    'whatHappenedNow': 'Was ist gerade passiert?',
    'momNote': 'Notiz der Mama',
    'saveRecord': 'Speichern',
    'reportsTitle': 'Berichte',
    'reportsSubtitle': 'Zusammenfassung für Mama und Kinderarzt.',
    'reportsHubAnchorLabel': 'Referenz',
    'reportsHubPickDayTooltip': 'Referenztag für Berichte wählen',
    'reportsHubSectionTitle': 'Verfügbare Berichte',
    'reportStubComingSoon':
        'Dieser Bericht wird automatisch mit den App-Daten des ausgewählten Zeitraums aktualisiert.',
    'reportListDaily': 'Tagesbericht',
    'reportListDailySub': 'Zusammenfassung und Details des ausgewählten Tages',
    'reportListWeekly': 'Wochenbericht',
    'reportListWeeklySub':
        'Zusammenfassung und Details der Woche des ausgewählten Tages',
    'reportListMonthly': 'Monatsbericht',
    'reportListMonthlySub':
        'Monatliche Werte für den Monat des ausgewählten Tages',
    'reportListSleepAdv': 'Erweiterter Schlafbericht',
    'reportListSleepAdvSub': 'Schlafmuster und Kennzahlen',
    'reportListDevelopment': 'Entwicklungsbericht',
    'reportListDevelopmentSub': 'Meilensteine und Entwicklungsschübe',
    'plusBrandTitle': 'FaceBaby Premium',
    'plusSheetHero':
        'Ein einmaliges Freischalten für immer: schöne PDFs, Erinnerungsbuch, mehr Fotos, Cloud-Backup und hilfreiche Einblicke für Mama.',
    'plusSheetPriceLabel': 'Einmalzahlung',
    'plusSheetBullets':
        '• PDF-Berichte (Schlaf, Routine, Wachstum)\n• Erinnerungsbuch als PDF\n• Badges exportieren (PNG / PDF)\n• Cloud-Backup zwischen Geräten\n• Mehr Erinnerungen und Fotos\n• Intelligente Einblicke in Berichten\n• Bericht für den Kinderarzt\n• Erweiterte Statistiken\n• Premium-Buchthemen',
    'plusCtaSubscribe': 'Für immer freischalten',
    'plusCtaRestore': 'Käufe wiederherstellen',
    'plusCtaLater': 'Jetzt nicht',
    'plusSheetFootnote':
        'Einmaliger Kauf über Google Play oder den App Store. Auf einem neuen Telefon kannst du ihn wiederherstellen.',
    'plusWelcomeSnack':
        'Premium aktiviert. Danke, dass du FaceBaby unterstützt.',
    'plusPurchaseUnavailableSnack':
        'Der Kauf ist auf diesem Gerät nicht verfügbar.',
    'plusPurchaseSkuNotFoundSnack': 'Produkt im Store nicht gefunden: {id}',
    'plusPurchaseBillingLaunchFailedSnack':
        'Zahlung konnte nicht geöffnet werden. Bitte versuche es erneut.',
    'plusPaywallSkuMissingHint': 'Konfiguriere das Produkt im Store: {id}',
    'plusRestoreOkSnack': 'Kauf wiederhergestellt.',
    'plusRestoreEmptySnack':
        'Wir haben keinen Kauf zum Wiederherstellen gefunden.',
    'plusSnackLockedFeature': 'Diese Funktion ist Teil von FaceBaby Premium.',
    'plusMemoryLimitSnack':
        'Im kostenlosen Plan kannst du bis zu {max} Fotos auf Badges speichern.',
    'plusMemoryLimitDialogTitle': 'Mehr Erinnerungen freischalten',
    'plusMemoryLimitDialogBody':
        'Im kostenlosen Plan kannst du bis zu {max} Fotos auf Badges speichern.\n\nHol dir FaceBaby Premium mit Einmalzahlung — ohne Monatsabo — für unbegrenzte Fotos, Berichte, Exporte und weitere Portal-Funktionen.',
    'plusMemoryLimitDialogSubscribe': 'Premium holen',
    'plusMemoryCounterFree': '{n} von {max} Momenten im kostenlosen Plan',
    'plusReportsLockedHint': 'PDF-Berichte sind Teil von FaceBaby Premium.',
    'plusExportLockedHint': 'Der Badge-Export ist Teil von FaceBaby Premium.',
    'plusLifetimePaymentBadge': 'Einmalzahlung',
    'plusNoMonthlyBadge': 'Kein Monatsabo',
    'plusPremiumActiveTitle': 'Danke für Premium',
    'plusPremiumActiveBody':
        'Alle Premium-Funktionen sind auf diesem Gerät dauerhaft aktiv. Stelle Käufe wieder her, wenn du das Telefon wechselst.',
    'plusPurchaseErrorSnack':
        'Der Kauf konnte nicht abgeschlossen werden. Bitte versuche es erneut.',
    'plusDoneClose': 'Schließen',
    'plusPaywallHeadline':
        'Jeder Plan wurde entwickelt,\num dich in jeder Phase zu unterstützen.',
    'plusPaywallActiveNote':
        'Dein Premium ist aktiv. Du kannst die Pläne jederzeit ansehen.',
    'plusPaywallSecureNote':
        '100 % sicherer Kauf. Du kannst jederzeit kündigen.',
    'plusPlanPremiumTitle': 'Premium',
    'plusPlanPremiumSubtitle': 'Alles, um besser zu\nbegleiten und zu sorgen',
    'plusPlanPremiumBadge': 'Am häufigsten gewählt',
    'plusPlanPremiumPriceSubActive': 'jetzt aktiv',
    'plusPlanPremiumPriceSubSecure': 'sicherer Kauf',
    'plusPlanPremiumButtonActive': 'Aktueller Plan',
    'plusPlanPremiumButton': 'Ich möchte Premium',
    'plusPlanPremiumFeature1': 'Alles aus dem kostenlosen Plan',
    'plusPlanPremiumFeature2': 'Vollständige Babyberichte',
    'plusPlanPremiumFeature3':
        'Bericht für den Kinderarzt (praktisch zum Teilen mit deinem Arzt)',
    'plusPlanPremiumFeature4': 'Beschreibung der Sternzeichen',
    'plusPlanPremiumFeature5': 'Tägliche Bibelbotschaften',
    'plusPlanPremiumFeature6': 'Analysen und Einblicke zur Entwicklung',
    'plusPlanPremiumFeature7': 'Exklusive Inhalte und Tipps',
    'plusPlanPremiumFeature8': 'Priorisierter Support',
    'plusPlanAiTitle': 'KI-Nanny',
    'plusPlanAiSubtitle': 'Intelligente Assistenz\nfür den Alltag',
    'plusPlanAiBadge': 'Demnächst',
    'plusPlanAiFeature1': 'Alles aus dem Premium-Plan',
    'plusPlanAiFeature2': '24h KI-Nanny an deiner Seite',
    'plusPlanAiFeature3': 'Intelligente Antworten',
    'plusPlanAiFeature4': 'Personalisierte Orientierung',
    'plusPlanAiFeature5': 'Vorausschauende Hinweise',
    'plusPlanAiFeature6': 'Personalisierte Routinen',
    'plusPlanAiFeature7': 'KI-generierte Inhalte',
    'plusPlanAiPrice': 'Demnächst',
    'plusPlanAiPriceSub': 'Bleib dran!',
    'plusPlanAiButton': 'Benachrichtigen',
    'plusPlanFreeTitle': 'Kostenlos',
    'plusPlanFreeSubtitle': 'Starte mit dem Wesentlichen',
    'plusPlanFreePrice': '0,00 €',
    'plusPlanCurrent': 'Aktueller Plan',
    'plusPlanFreeFeature1': 'Basisprofile',
    'plusPlanFreeFeature2': 'Tägliche Einträge',
    'plusPlanFreeFeature3': 'Kalender und Erinnerungen',
    'plusPlanFreeFeature4': 'Gewicht und Größe',
    'plusTrustData': 'Deine Daten\nimmer geschützt',
    'plusTrustFamily': 'Mit Liebe gemacht\nfür Familien',
    'plusTrustContent': 'Verlässliche, aktuelle\nInhalte',
    'plusTrustSupport': 'Unterstützung in jedem\nMoment',
    'growth': 'Wachstum',
    'pediatricReport': 'Kinderarztbericht',
    'pediatricReportDesc':
        'PDF mit Gewicht, Schlaf, Ernährung, Windeln, Impfungen, in „Gesundheit“ erfassten Symptomen, Terminen und Notizen erstellen.',
    'reportListPediatric': 'Bericht für den Kinderarzt',
    'reportListPediatricSub': 'PDF und Daten für den Arztbesuch',
    'healthHubSymptomReports': 'Symptom melden',
    'healthHubSymptomReportsSub':
        'Fieber, Koliken, Medikamente u. a. — im Kinderarztbericht enthalten',
    'symptomReportTitle': 'Symptom melden',
    'symptomReportEmpty': 'Noch keine Einträge. Tippe auf + zum Hinzufügen.',
    'symptomReportNew': 'Neuer Eintrag',
    'symptomReportSave': 'Speichern',
    'symptomReportOccurredAt': 'Datum und Uhrzeit',
    'symptomReportPickDateTime': 'Datum und Uhrzeit ändern',
    'symptomReportMedication': 'Eingenommene Medikamente',
    'symptomReportMedicationHint': 'Name oder kurze Notiz',
    'symptomReportFever': 'Fieber',
    'symptomReportTemp': 'Temperatur',
    'symptomReportTempHint':
        'Entsprechend deinen Einheiten in den Einstellungen',
    'symptomReportCrying': 'Weinen ohne erkennbare Ursache',
    'symptomReportPain': 'Schmerzen',
    'symptomReportColic': 'Koliken',
    'symptomReportReflux': 'Reflux',
    'symptomReportOther': 'Sonstiges',
    'symptomReportOtherHint': 'Kurze Beschreibung',
    'symptomReportValidationNeedOne':
        'Wähle mindestens ein Symptom oder fülle ein Feld aus.',
    'symptomReportValidationFeverTemp':
        'Gib die Temperatur an, wenn Fieber aktiviert ist.',
    'symptomReportDeleteTitle': 'Eintrag löschen?',
    'symptomReportDeleteBody': 'Das kann nicht rückgängig gemacht werden.',
    'reportPediatricScreenTitle': 'Kinderarztbericht',
    'reportPediatricPeriodPrefix': 'Zeitraum:',
    'reportPediatricFilterHint': 'Berichtszeitraum',
    'reportPediatricDateFrom': 'Von',
    'reportPediatricDateTo': 'Bis',
    'reportPediatricPickRange': 'Daten wählen',
    'reportPediatricFilterMaxDaysHint':
        'Zum Ändern tippen. Sehr lange Zeiträume sind auf 366 Tage begrenzt.',
    'reportPediatricSectionGeneral': 'Allgemeine Angaben',
    'reportPediatricSectionSummary': 'Zusammenfassung des Zeitraums',
    'reportPediatricSectionSleep': 'Schlaf',
    'reportPediatricSectionFeeding': 'Ernährung',
    'reportPediatricSectionSymptoms': 'Symptome und Einträge',
    'reportPediatricSectionObservations': 'Elternbeobachtungen',
    'reportPediatricLabelName': 'Name',
    'reportPediatricLabelAge': 'Alter',
    'reportPediatricLabelBirth': 'Geburtsdatum',
    'reportPediatricLabelWeightCurrent': 'Gewicht (letztes im Zeitraum)',
    'reportPediatricLabelHeight': 'Größe',
    'reportPediatricWeightStart': 'Startgewicht (Zeitraum)',
    'reportPediatricWeightEnd': 'Endgewicht (Zeitraum)',
    'reportPediatricWeightGain': 'Gewichtsänderung',
    'reportPediatricHeightStart': 'Startgröße (Zeitraum)',
    'reportPediatricHeightEnd': 'Endgröße (Zeitraum)',
    'reportPediatricHeightGain': 'Größenwachstum',
    'reportPediatricAvgFeeds': 'Mahlzeiten pro Tag (Ø)',
    'reportPediatricAvgSleep': 'Schlaf pro Tag (Ø)',
    'reportPediatricAvgDiapers': 'Windelwechsel pro Tag (Ø)',
    'reportPediatricFeverEpisodes': 'Fieberepisoden (strukturiert)',
    'reportPediatricFeverNote': 'Hinweis',
    'reportPediatricFeverFootnote':
        'Zählung aus strukturierten Einträgen unter Gesundheit › Symptom melden (mit Temperatur, falls angegeben).',
    'reportPediatricVaccines': 'Impfungen im Zeitraum',
    'reportPediatricMedications':
        'Medikamente (strukturierte Einträge & Stichworte in Notizen)',
    'reportPediatricSleepAvgDaily': 'Durchschnittlicher Tageschlaf',
    'reportPediatricSleepAwakenings': 'Nächtliches Aufwachen (Ø)',
    'reportPediatricSleepPattern': 'Schlafmuster insgesamt',
    'reportPediatricSleepPatternStable': 'Überwiegend durchgehend',
    'reportPediatricSleepPatternModerate': 'Mittel',
    'reportPediatricSleepPatternFragmented': 'Stärker unterbrochen',
    'reportPediatricSleepLongest': 'Längster durchgehender Schlaf',
    'reportPediatricFeedingBreast': 'Stillen',
    'reportPediatricFeedingFormula': 'Pre-Nahrung',
    'reportPediatricFeedingSolid': 'Beikost',
    'reportPediatricFeedingSessions': 'Sessions',
    'reportPediatricFeedingAvgDur': 'Ø-Dauer',
    'reportPediatricSymptomReflux': 'Reflux (Tagebuch oder strukturiert)',
    'reportPediatricSymptomColic': 'Koliken (Tagebuch oder strukturiert)',
    'reportPediatricSymptomIrrit': 'Reizbarkeit (Stimmungen)',
    'reportPediatricIrritHigh': 'Deutlicher',
    'reportPediatricIrritMedium': 'Mittel',
    'reportPediatricIrritLow': 'Gering',
    'reportPediatricIrritUnknown': 'Keine Daten',
    'reportPediatricYes': 'Ja',
    'reportPediatricNo': 'Nein',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'Tagebucheinträge',
    'reportPediatricJournalNoteHint': 'Erkennung per Stichwort im Freitext.',
    'reportPediatricObsHint':
        'Notizen zum Termin: Symptome, Medikamente, Verhaltensänderungen …',
    'reportPediatricBtnShare': 'Teilen',
    'reportPediatricBtnExportPdf': 'PDF exportieren',
    'reportPediatricBtnPrint': 'Drucken',
    'reportPediatricBtnEmail': 'E-Mail',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote':
        'Informative Zusammenfassung aus lokalen Daten. Kein Ersatz für eine ärztliche Bewertung.',
    'reportPediatricNone': 'Keine',
    'reportPediatricPdfTitle': 'Kinderarztbericht — FaceBaby',
    'reportPediatricPdfPeriod': 'Zeitraum:',
    'reportPediatricPdfFooter':
        'In FaceBaby erzeugt. Inhalt beschränkt auf Daten auf diesem Gerät (offline möglich).',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': 'Weinen ohne Ursache (strukturiert)',
    'reportPediatricSymptomPain': 'Schmerzen (strukturiert)',
    'reportPediatricStructuredSymptoms':
        'Strukturierte Symptomeinträge (Datum und Uhrzeit)',
    'reportPediatricStructuredSymptomsEmpty':
        'Keine strukturierten Einträge in diesem Zeitraum.',
    'generatePdf': 'PDF erstellen',
    'reportMonthlyMilestonesTitle': 'Meilensteine des Monats',
    'reportMonthlyMilestonesEmpty':
        'Keine Impfungen, Termine oder Erinnerungen mit Abzeichen in diesem Monat.',
    'reportMonthlyMilestoneConsultationDefault': 'Termin',
    'homeBannerChipVaccine': 'Impfung heute',
    'homeMotivationBanner':
        'Du machst das großartig! Kleine Einträge, große Erinnerungen.',
    'homeMotivationBannerOpenMemories': 'Erinnerungsbuch öffnen',
    'healthHubTitle': 'Gesundheit',
    'healthHubIntro': 'Impfungen, Termine und Babypflege an einem Ort.',
    'healthHubSection': 'Schnellzugriff',
    'healthHubVaccines': 'Impfpass',
    'healthHubVaccinesSub': 'Impfungen des Babys eintragen und prüfen',
    'vaccineReminderNotifTitle': 'Impfung',
    'vaccineReminderNotifBody': 'Impfung heute fällig: {name}.',
    'vaccDueConfirmCheckbox':
        'Ich bestätige, dass diese Dosis bereits verabreicht wurde.',
    'vaccDueSavedOk': 'Impfung als verabreicht gespeichert.',
    'vaccDuePickTitle': 'Für heute geplante Impfungen',
    'homeSummaryHealthStripTitle': 'Impfungen und Termine an diesem Tag',
    'homeSummaryHealthStripEmpty':
        'Keine Impfungen oder Termine für diesen Tag eingetragen.',
    'consultationReminderNotifTitle': 'Geplanter Termin',
    'consultationReminderNotifBody': 'Morgen · {title} · {when}',
    'consultationTodayReminderNotifBody': 'Heute · {title} · {when}',
    'weeklyPhotoPublicExplainer':
        'Wenn du diese Erinnerung öffentlich machst, kann das Foto am Foto der Woche teilnehmen und von anderen Mamas in FaceBaby gesehen werden.',
    'weeklyPhotoPublicOff': 'Privat',
    'weeklyPhotoPublicOn': 'Öffentlich',
    'weeklyPhotoPublicNeedPhoto':
        'Füge ein Foto hinzu, um diese Erinnerung öffentlich zu machen.',
    'weeklyPhotoConfirmTitle': 'Dieses Foto öffentlich machen?',
    'weeklyPhotoConfirmBody':
        'Stimmst du zu, dieses Foto anderen Nutzern zu zeigen, falls du als Gewinnerin der Woche ausgelost wirst?',
    'weeklyPhotoConfirmNo': 'Nein',
    'weeklyPhotoConfirmYes': 'Ja',
    'weeklyPhotoParticipatingBadge': 'Nimmt am Foto der Woche teil',
    'weeklyPhotoWinnerBadge':
        'Diese Erinnerung wurde als Foto der Woche ausgewählt 💜',
    'weeklyPhotoShowBabyFirstName':
        'Vornamen des Babys auf der öffentlichen Pinnwand anzeigen',
    'weeklyPhotoDisclaimerFooter':
        'Nur als öffentlich markierte Fotos nehmen teil. Du kannst diese Option jederzeit entfernen.',
    'weeklyPhotoReportLink': 'Melden',
    'weeklyPhotoReportTitle': 'Foto melden',
    'weeklyPhotoReportHint':
        'Beschreibe den Grund der Meldung. Das FaceBaby-Team prüft sie.',
    'weeklyPhotoReportMessageLabel': 'Grund der Meldung',
    'weeklyPhotoReportSubmit': 'Meldung senden',
    'weeklyPhotoReportSuccess':
        'Meldung gesendet. Danke, dass du die Community sicher hältst.',
    'weeklyPhotoReportNeedLogin': 'Melde dich an, um eine Meldung zu senden.',
    'weeklyPhotoReportMessageTooShort':
        'Schreibe mindestens 5 Zeichen als Meldegrund.',
    'weeklyPhotoReportMessageTooLong': 'Der Meldetext ist zu lang.',
    'weeklyPhotoReportFailed':
        'Meldung konnte nicht gesendet werden. Bitte erneut versuchen.',
    'weeklyPhotoSectionTitleMale': 'Prinz der Woche',
    'weeklyPhotoSectionTitleFemale': 'Prinzessin der Woche',
    'weeklyPhotoHomeHeroMale': 'PRINZ DER WOCHE',
    'weeklyPhotoHomeHeroFemale': 'PRINZESSIN DER WOCHE',
    'weeklyPhotoSectionSubtitle':
        'Eine besondere Erinnerung, geteilt von einer FaceBaby-Mama.',
    'weeklyPhotoViewMemory': 'Erinnerung ansehen',
    'weeklyPhotoBabyFallback': 'Ein FaceBaby-Baby',
    'weeklyPhotoDisclaimerShort':
        'Nur als öffentlich markierte Fotos nehmen teil. Du kannst diese Option jederzeit entfernen.',
    'weeklyPhotoPublicDetailAppBar': 'Erinnerung der Woche',
    'weeklyPhotoWinnerCongratsTitle': 'Herzlichen Glückwunsch, Mama!',
    'weeklyPhotoWinnerCongratsBody':
        'Das Foto deiner Prinzessin wurde zum Foto der Woche gewählt! Lasst uns sie gemeinsam feiern.\n\nDie FaceBaby-Familie dankt dir, dass du diesen schönen Moment mit uns teilst! 💜',
    'weeklyPhotoWinnerCongratsBodyMale':
        'Das Foto deines Prinzen wurde zum Foto der Woche gewählt! Lasst uns ihn gemeinsam feiern.\n\nDie FaceBaby-Familie dankt dir, dass du diesen schönen Moment mit uns teilst! 💜',
    'weeklyPhotoWinnerCongratsBodyFemale':
        'Das Foto deiner Prinzessin wurde zum Foto der Woche gewählt! Lasst uns sie gemeinsam feiern.\n\nDie FaceBaby-Familie dankt dir, dass du diesen schönen Moment mit uns teilst! 💜',
    'weeklyPhotoWinnerCongratsOk': 'Bestätigen',
    'memoriesTitle': 'Erinnerungsbuch',
    'memoriesSubtitle': 'Wichtige Momente für später.',
    'memoriesProgressSaved': '{filled} von {total} Momenten gespeichert',
    'memoriesProgressStandardBadges': '({count} Standard-Badges)',
    'memoriesCheerEmpty':
        'Tippe auf ein Badge mit +, um Fotos und Geschichten hinzuzufügen.',
    'memoriesAlbumPromoTitle': 'Dein vollständiges Erinnerungsbuch',
    'memoriesAlbumPromoSubtitle':
        'Lade ein elegantes PDF mit FaceBaby-Cover, dekorativem Rahmen und allen ausgefüllten Badges herunter — ideal zum Bewahren oder Teilen.',
    'memoriesAlbumDownloadCta': 'Album-PDF herunterladen',
    'memoriesAlbumGenerating': 'Album wird erstellt…',
    'memoriesAlbumNeedFilled':
        'Fülle mindestens einen Moment im Album aus, um das PDF zu erstellen.',
    'memoriesAlbumError': 'PDF konnte nicht erstellt werden.',
    'memoriesAlbumPdfReadyTitle': 'Album-PDF bereit',
    'memoriesAlbumShareAction': 'Teilen…',
    'memoriesAlbumSaveAction': 'Speichern / herunterladen',
    'memoriesAlbumSavedSnack': 'PDF auf dem Gerät gespeichert.',
    'memoriesAlbumSaveFailedSnack': 'PDF konnte nicht gespeichert werden.',
    'memoriesAlbumCoverMain': 'Erinnerungsbuch',
    'memoriesAlbumCoverTagline': 'Besondere Momente mit {name}',
    'memoriesAlbumFooter': 'Erstellt mit FaceBaby',
    'memoryBadgeMonthOne': '1 Monat',
    'memoryBadgeMonthsMany': '{n} Monate',
    'memoryBadgeYearOne': '1 Jahr',
    'memoryBadgeYearsMany': '{n} Jahre',
    'memoryBadgeMonthUnitSingular': 'Monat',
    'memoryBadgeMonthUnitPlural': 'Monate',
    'badge_arrived_home': 'Zuhause angekommen',
    'badge_first_smile': 'Erstes Lächeln',
    'badge_first_feeding': 'Erste Mahlzeit',
    'badge_sleeping': 'Schläft',
    'badge_bath_time': 'Badezeit',
    'badge_going_out': 'Spaziergang',
    'badge_first_laugh': 'Erstes Lachen',
    'badge_found_hands': 'Hände entdeckt',
    'badge_lifted_head': 'Kopf gehoben',
    'badge_at_park': 'Im Park',
    'badge_first_hug': 'Erste Umarmung',
    'badge_first_foods': 'Erste Beikost',
    'badge_first_bath': 'Erstes Bad',
    'badge_crib_sleep': 'Erster Nickerchen im Bett',
    'badge_first_diaper_change': 'Erster Windelwechsel',
    'badge_first_burp': 'Erstes Bäuerchen',
    'badge_first_mom_cuddle': 'Erste Kuschelzeit mit Mama',
    'badge_first_dad_cuddle': 'Erste Kuschelzeit mit Papa',
    'badge_first_pediatrician': 'Erster Kinderarztbesuch',
    'badge_first_vaccine': 'Erste Impfung',
    'badge_first_car_ride': 'Erste Autofahrt',
    'badge_first_stroller_ride': 'Erste Ausfahrt mit dem Kinderwagen',
    'badge_favorite_toy': 'Lieblingsspielzeug',
    'badge_first_night_home': 'Erste Nacht zu Hause',
    'badge_first_giggle': 'Erstes Kichern',
    'badge_sun_bath': 'Erstes Sonnenbad',
    'badge_first_christmas': 'Erstes Weihnachten',
    'badge_first_new_year': 'Erstes Neujahr',
    'badge_first_mothers_day': 'Erster Muttertag',
    'badge_first_fathers_day': 'Erster Vatertag',
    'badge_first_tooth': 'Erster Zahn',
    'badge_first_puree': 'Erster Brei',
    'badge_sat_alone': 'Saß ohne Stütze',
    'badge_crawled': 'Gekrabbelt',
    'badge_stood_up': 'Aufgestanden',
    'badge_first_steps': 'Erste Schritte',
    'badge_first_word': 'Erstes Wort',
    'badge_favorite_song': 'Lieblingslied',
    'badge_first_trip': 'Erste Reise',
    'badge_family_birthday': 'Erster Familiengeburtstag',
    'badge_first_beach': 'Erster Strandtag',
    'badge_first_pool': 'Erstes Schwimmbad',
    'badge_first_haircut': 'Erster Haarschnitt',
    'badge_first_shoes': 'Erste Schühchen',
    'badge_special_outfit': 'Besonderes Outfit',
    'badge_first_friend': 'Erster Freund',
    'badge_first_party': 'Erste Party',
    'badge_first_cartoon': 'Erster Zeichentrick',
    'badge_first_book': 'Erstes Buch',
    'badge_special_free': 'Besonderer Moment',
    'addMemory': 'Erinnerung hinzufügen',
    'memoryAddBadgeCta': 'Badge hinzufügen',
    'memoryChooseBadgeTitle': 'Welches Badge möchtest du erstellen?',
    'memoryOtherBadgeTitle': 'Andere',
    'memoryOtherBadgeNameLabel': 'Badge-Name',
    'memoryOtherBadgeNameHint': 'Z. B.: Erstes Kostüm',
    'memoryOtherBadgeNameRequired': 'Gib den Badge-Namen ein.',
    'memoryOtherBadgeNameTooLong': 'Verwende höchstens 25 Zeichen.',
    'settingsTitle': 'Mehr',
    'registerMotherBaby': 'Registrierung (Mama & Baby)',
    'vaccinesCard': 'Impfungen (Heft)',
    'language': 'Sprache',
    'settingsSoonTitle': 'Demnächst',
    'settingsSoonBadge': 'Bald',
    'settingsRateUs': 'Bewerte uns',
    'settingsVersion': 'Version',
    'settingsVersionDialogTitle': 'App-Version',
    'settingsVersionCopy': 'Kopieren',
    'settingsVersionCopied': 'Versionsinfo kopiert',
    'settingsTermsOfUse': 'Nutzungsbedingungen',
    'settingsPrivacyPolicy': 'Datenschutzerklärung',
    'settingsSpecialThanks': 'Besonderer Dank',
    'settingsTellFriend': 'Einem Freund erzählen',
    'settingsMotherProfile': 'Mein Profil',
    'profileEditMother': 'Daten der Mama bearbeiten',
    'profileEditFather': 'Daten des Papas bearbeiten',
    'profileAddFather': 'Papa registrieren',
    'profileFatherNotRegisteredTitle': 'Papa noch nicht registriert',
    'profileFatherNotRegisteredSubtitle':
        'Wenn Sie Papa bei der Anmeldung übersprungen haben, können Sie seine Daten hier jederzeit ergänzen.',
    'profileFatherAddCta': 'Papa jetzt registrieren',
    'profileEditBaby': 'Daten des Babys bearbeiten',
    'profileDataSaved': 'Daten gespeichert.',
    'profileEditData': 'Daten bearbeiten',
    'motherProfileTabPreferences': 'Einstellungen',
    'motherProfileTabMother': 'Mama',
    'motherProfileTabFather': 'Papa',
    'motherProfileTabBabies': 'Babys',
    'profileLayoutTitle': 'App-Layout',
    'profileLayoutSubtitle': 'Tag-, Nacht- oder Automatikmodus nach Uhrzeit.',
    'profileLayoutAutomatic': 'Automatisch',
    'profileLayoutDay': 'Tag',
    'profileLayoutNight': 'Nacht',
    'profileLayoutUpdating': 'Layout wird aktualisiert…',
    'motherProfileFieldFatherName': 'Name',
    'motherProfileNoData':
        'Kein Profil gefunden. Bitte versuche es gleich erneut.',
    'motherProfileSectionInfo': 'Informationen',
    'motherProfileFieldPhone': 'Telefon',
    'motherProfileFieldBirth': 'Geburt',
    'motherProfileFieldHeight': 'Größe',
    'motherProfileFieldFatherHeight': 'Größe des Papas',
    'profileFamilyMessagesTitle': 'Nachrichten auf der Familienseite',
    'profileShowChristian': 'Christlich',
    'profileShowHoroscope': 'Astrologisch',
    'profileShowPhilosophical': 'Philosophisch / Ökumenisch',
    'profileShowSpiritist': 'Spiritistische Nachrichten',
    'profileShowJewish': 'Jüdische Nachrichten',
    'motherProfileAddBaby': 'Weiteres Baby hinzufügen',
    'motherProfileNoBabies': 'Für dieses Profil wurde kein Baby gefunden.',
    'motherProfileBabyBornAt': 'Geburt: {date}',
    'vaccinesTitle': 'Impfungen',
    'vaccinesSubtitle': 'Impfungen, Daten und nächste Dosen hinzufügen.',
    'baby': 'Baby',
    'selectBaby': 'Baby auswählen',
    'addVaccine': 'Impfung hinzufügen',
    'recordsTitle': 'Einträge',
    'noVaccinesYet': 'Noch keine Impfungen.',
    'seeAll': 'Alle anzeigen',
    'changePhoto': 'Foto ändern',
    'motherPhotoTitle': 'Mamas Foto',
    'babyPhotoTitle': 'Babyfoto',
    'familyTitle': 'Familie',
    'familySubtitle': 'Familienstammbaum, Sternzeichen und Tagesbotschaften.',
    'familyEdit': 'Bearbeiten',
    'familyEditData': 'Daten bearbeiten >',
    'familyTabMotherLabel': 'Mama',
    'familyTabFatherLabel': 'Papa',
    'familyRoleMother': 'Mama',
    'familyRoleFather': 'Papa',
    'familyRoleBaby': 'Baby',
    'familyZodiacSolar': 'Sonnenzeichen',
    'familyEntertainmentNote':
        'Vervollständige die Geburtsdaten, um diesen Inhalt zu personalisieren.',
    'familyChristianCardTitle': 'Biblische Botschaft',
    'familySpiritistCardTitle': 'Spiritistische Botschaft',
    'familyJewishCardTitle': 'Jüdische Botschaft',
    'familyChristianLine': 'Vers des Tages · {ref}',
    'familyBornOn': 'Geb. {date}',
    'familyAgeOneYear': '1 Jahr',
    'familyAgeYears': '{n} Jahre',
    'familyHeight': '{value}',
    'familyMotherBlurb':
        'Als {sign}-Mama kann sie Eigenschaften wie {traits} zeigen.',
    'familyFatherBlurb':
        'Als {sign}-Papa kann er Eigenschaften wie {traits} zeigen.',
    'familyBabyBlurb':
        'Als {sign}-Baby kann es Eigenschaften wie {traits} zeigen.',
    'familyZodiacName_capricorn': 'Steinbock',
    'familyZodiacName_aquarius': 'Wassermann',
    'familyZodiacName_pisces': 'Fische',
    'familyZodiacName_aries': 'Widder',
    'familyZodiacName_taurus': 'Stier',
    'familyZodiacName_gemini': 'Zwillinge',
    'familyZodiacName_cancer': 'Krebs',
    'familyZodiacName_leo': 'Löwe',
    'familyZodiacName_virgo': 'Jungfrau',
    'familyZodiacName_libra': 'Waage',
    'familyZodiacName_scorpio': 'Skorpion',
    'familyZodiacName_sagittarius': 'Schütze',
    'familyZodiacTrait_capricorn': 'diszipliniert und verantwortungsvoll',
    'familyZodiacTrait_aquarius': 'neugierig und unabhängig',
    'familyZodiacTrait_pisces': 'sensibel und fantasievoll',
    'familyZodiacTrait_aries': 'mutig und voller Energie',
    'familyZodiacTrait_taurus': 'ruhig und liebevoll',
    'familyZodiacTrait_gemini': 'kommunikativ und neugierig',
    'familyZodiacTrait_cancer': 'liebevoll und beschützend',
    'familyZodiacTrait_leo': 'fröhlich und ausdrucksstark',
    'familyZodiacTrait_virgo': 'aufmerksam und sorgfältig',
    'familyZodiacTrait_libra': 'sanft und gesellig',
    'familyZodiacTrait_scorpio': 'intensiv und liebevoll',
    'familyZodiacTrait_sagittarius': 'fröhlich und entdeckungsfreudig',
    'familyFatherDataComplete': 'Papas Daten sind vollständig und aktuell',
    'familyFatherDataIncomplete': 'Papas Daten sind noch unvollständig',
    'familyAddFatherPrompt':
        'Möchtest du Papas Daten hinzufügen? Vervollständige sie, um die geschätzte Größe deines Babys zu sehen.',
    'familyAddFatherButton': 'Papas Daten hinzufügen',
    'familyCompleteBabySex':
        'Gib das Geschlecht des Babys im Profil an, um die geschätzte Größe zu berechnen.',
    'familyEditBabyData': 'Babydaten bearbeiten',
    'familyCompleteHeights':
        'Für die Schätzung brauchen wir die Größe von Mama und Papa.',
    'familyCompleteHeightsButton': 'Größen ergänzen',
    'familyEstimatedHeightTitle': 'Geschätzte Größe von {name}',
    'familyMotherHeightLabel': 'Größe der Mama',
    'familyFatherHeightLabel': 'Größe des Papas',
    'familyEstimatedGirl': 'Geschätzte Größe für Mädchen',
    'familyEstimatedBoy': 'Geschätzte Größe für Jungen',
    'familyEstimatedResult': 'ungefähr {cm}',
    'familyHowCalculated': 'Wie wird das berechnet?',
    'familyFormulaBoy': 'Junge: (Größe Vater + Größe Mutter + 13) ÷ 2',
    'familyFormulaGirl': 'Mädchen: (Größe Vater + Größe Mutter − 13) ÷ 2',
    'familyEstimatedHeightDescription':
        'Schätzung auf Basis der Elterngröße und des Geschlechts des Babys. Umwelt-, Ernährungs-, Gesundheits- und andere Faktoren werden nicht berücksichtigt. Nur als Orientierung.',
    'familyFormulaExampleGirl': '({father} + {mother} − 13) ÷ 2 = {result} cm',
    'familyFormulaExampleBoy': '({father} + {mother} + 13) ÷ 2 = {result} cm',
    'familyHeightDisclaimer':
        'Dies ist eine einfache Schätzung als pädiatrische Orientierung. Die endgültige Größe kann durch Genetik, Ernährung, Schlaf, Gesundheit, Pubertät und andere Faktoren variieren.',
    'familyZodiacReadMore': 'Vollständigen Text lesen',
    'familyPremiumZodiacLocked':
        'Sonnenzeichen und personalisierte Texte sind exklusiv in FaceBaby Premium.',
    'familyPremiumHeightLocked':
        'Die geschätzte Erwachsenengröße ist exklusiv in FaceBaby Premium.',
    'familyPremiumUnlockCta': 'Premium freischalten',
    'familyScreenTitle': 'Familie 💜',
    'familyPersonalInfoTitle': 'Persönliche Informationen',
    'familyHoroscopeCardTitle': 'Horoskop für {sign}',
    'familyBibleVerseCardTitle': 'Bibelvers des Tages.',
    'familyDailySummaryTitle': 'Tagesübersicht',
    'familySummaryFeeding': 'Stillen',
    'familySummaryDiapers': 'Windeln',
    'familySummarySleep': 'Schlaf',
    'familySummaryWeight': 'Gewicht',
    'familyQuickLabelBirth': 'Geb.',
    'familyQuickLabelTime': 'Uhrzeit',
    'familySummaryFeedingsToday': '{n} Mahlzeiten',
    'familySummaryDiaperChangesCount': '{n} Wechsel',
    'familySummaryLastAt': 'Letzte um {time}',
    'familySummaryLastSleepAt': 'Letzter um {time}',
    'familySummaryWeightDayLine': 'Ausgewählter Tag',
    'familyFieldBirthDate': 'Geburt',
    'familyFieldSign': 'Sternzeichen',
    'familyFieldElement': 'Element',
    'familyFieldAge': 'Alter',
    'familyFieldHeight': 'Größe',
    'familyFieldWeight': 'Gewicht',
    'familyPremiumShortBadge': 'Premium',
    'familyPremiumFeatureLockedBody': 'Exklusiver Inhalt für Premium-Familien.',
    'familyPremiumBannerTitle': 'Premium-Inhalte freischalten',
    'familyPremiumBannerBody':
        'Erhalte Sternzeichenbeschreibungen, geschätzte Größe und personalisierte Inhalte.',
    'familyPremiumViewPlans': 'Pläne ansehen',
    'familyAddFatherCardTitle': 'Papa hinzufügen',
    'familyElementFire': 'Feuer',
    'familyElementEarth': 'Erde',
    'familyElementAir': 'Luft',
    'familyElementWater': 'Wasser',
    'familyTapToOpen': 'Tippen, um Details zu sehen',
    'familyCarouselSwipe': 'Wischen, um Familienmitglied zu wechseln',
    'familyTabNene': 'Baby',
    'familyTabsHint': 'Tippe auf ein Foto, um Familienmitglied zu wechseln',
    'familyTapToClose': 'Tippen zum Schließen',
    'familyShareCard': 'Karte teilen',
    'changeBabyTooltip': 'Baby wechseln',
    'notificationsInboxTitle': 'Benachrichtigungen',
    'notificationsInboxSubtitle':
        'Letzte 3 Tage (zugestellte und geplante Benachrichtigungen, in der App erfasst)',
    'notificationsEmpty':
        'In diesem Zeitraum sind noch keine Benachrichtigungen erfasst.',
    'notificationsKindShown': 'Zugestellt',
    'notificationsKindScheduled': 'Geplant',
    'notificationsOpenTarget': 'Zum Öffnen tippen',
    'notificationsSelectAll': 'Alle auswählen',
    'homeBabyBannerForecastSleep': 'Schlafprognose',
    'homeBabyBannerForecastWake': 'Aufwachprognose',
    'homeBabyBannerForecastSubtitleSleep':
        'Schlafsignale erkannt\nbasierend auf der aktuellen Uhrzeit',
    'homeBabyBannerForecastSubtitleWake':
        'Basierend auf aktueller Uhrzeit und Altersmuster',
    'homeBabyBannerEtaIn': 'in {d}',
    'homeBabyBannerLastDiaper': 'Letzte Windel',
    'homeBabyBannerNoRecordsYet': 'Noch keine Einträge',
    'homeBabyBannerNextBetween': 'Nächste zwischen {range}',
    'homeBabyBannerDiaperRecommendedUntil': 'Wechsel empfohlen bis {d}',
    'homeBabyBannerIdealWindow': 'Ideales Fenster: {range}',
    'homeConsultationScheduled': 'Termin geplant',
    'homeBannerChipConsultation': 'Termin',
    'homeBannerChipDiaper': 'Windel',
    'homeBannerChipFeed': 'Mahlzeit',
    'homeBannerChipSleep': 'Schlaf',
    'homeBannerOverdueSleep': 'Schlafenszeit überschritten',
    'homeBannerOverdueWake': 'Aufwachzeit überschritten',
    'homeBannerHungry': 'Vielleicht hungrig',
    'homeBannerDiaperDirty': 'Vielleicht schmutzig',
    'homeBannerExhausted': 'ERSCHÖPFT',
    'helloMomNamed': 'Hallo, Mama {name}!',
    'registerVerb': 'Eintragen',
    'viewCalendar': 'Kalender ansehen',
    'shortcutMilk': 'Stillen',
    'shortcutSleep': 'Schlaf',
    'shortcutVaccines': 'Impfungen',
    'shortcutFamily': 'Familie',
    'shortcutFamilyHomeSub': 'Familienstammbaum und Profile',
    'shortcutHealthHomeSub': 'Impfungen, Termine und Symptome',
    'shortcutFeedingSession': 'Ernährung',
    'homeFedAgo': 'Gefüttert vor {when}',
    'homePeeAgo': 'Pipi vor {when}',
    'homePooAgo': 'Windel vor {when}',
    'homeFedAt': 'Mahlzeit um {time}',
    'homePeeAt': 'Pipi um {time}',
    'homePooAt': 'Stuhl um {time}',
    'homeDiaperChangeAgo': 'Windelwechsel vor {when}',
    'homeDiaperChangeAt': 'Windelwechsel um {time}',
    'homeSleepEndedAgo': 'Letzter Schlaf vor {when}',
    'homeSleepEndedAt': 'Letzter Schlaf um {time}',
    'homeSleepInProgress': 'Schläft · {elapsed}',
    'homeSleepPausedBanner': 'Schlaf pausiert · {elapsed}',
    'homeNextNow': 'Nächste: jetzt.',
    'homeNextIn': 'Nächste in {n} Min.',
    'homeStatusOk': 'Alles gut',
    'homeStatusWarn': 'Leichte Warnung',
    'homeStatusHungry': 'Vielleicht hungrig',
    'homeTimeToFeed': 'Zeit zum Füttern!',
    'homeStatusDetailFed': 'Kürzlich gefüttert',
    'homeStatusDetailNear': 'Kurz vor der Mahlzeit',
    'homeStatusDetailLate': 'Schon eine Weile her',
    'homePickDayLabel': 'Übersichtstag',
    'homeTodayLabel': 'Heute',
    'homeYesterdayLabel': 'Gestern',
    'homeSummaryOnDate': 'Übersicht — {date}',
    'homeSummaryPickDayTooltip': 'Tag für die Übersicht wählen',
    'sleepBannerEmpty': 'Noch keine Schlafaufzeichnungen.',
    'homePastDayBadge': 'Vergangener Tag',
    'homePastDayDetail': 'An diesem Tag erfasste Zeiten',
    'homeBannerAlertCheckDiaper': 'Windel prüfen',
    'homeBannerAlertTimeToSleep': 'Zeit zum Schlafen',
    'homeBannerAlertSleepingLong': 'Schläft schon lange',
    'homeCriticalCareTitle': 'Pflegepunkte mit Aufmerksamkeit',
    'homeCriticalCareCount': '{n} Pflegepunkte brauchen Aufmerksamkeit',
    'homeCriticalFeedingTitle': 'Vielleicht ist es Zeit zu füttern',
    'homeCriticalSleepTitle': 'Vielleicht ist es Zeit zu schlafen',
    'homeCriticalDiaperTitle': 'Vielleicht ist es Zeit für einen Windelwechsel',
    'homeCriticalFeedingSubtitle':
        'Seit der letzten Mahlzeit ist möglicherweise mehr Zeit als erwartet vergangen.',
    'homeCriticalSleepSubtitle': 'Das Wachfenster könnte überschritten sein.',
    'homeCriticalWakeTitle': 'Aufwachzeit überschritten',
    'homeCriticalWakeSubtitle':
        'Die Schlafsession könnte die empfohlene Dauer überschritten haben.',
    'homeCriticalDiaperSubtitle':
        'Seit dem letzten Wechsel ist möglicherweise eine Weile vergangen.',
    'homeSleepBarAwakeTitle': 'Wach · Fenster bis zum Schlaf',
    'homeSleepBarSleepTitle': 'Schläft · Sitzungszeit',
    'homeFeedingCounterTitle': 'Mahlzeit · Zeit bis zum nächsten Intervall',
    'homeFeedingCounterHint': 'Countdown (Intervall in Schnellprotokolle)',
    'homeSleepBarAwakeHintEarly': '≈ {m} Min. bis zum idealen Fenster',
    'homeSleepBarAwakeHintIdeal': '≈ {m} Min. bis zum Ende des Fensters',
    'homeSleepBarAwakeHintOverdue': 'Fenster überschritten · Schlaf erwägen',
    'homeSleepBarSleepHint': '{remaining} übrig · Sitzungsgrenze ~{cap} Min.',
    'homeSleepBarNeedLastSleep':
        'Letzten Schlaf eintragen, um die Leiste zu sehen',
    'homeTipTitle': 'Tipp für heute',
    'homeTipBody': 'Sanfte Routinen helfen {name}, nachts besser zu schlafen.',
    'homeYesterdayBabaTitle': 'KI-Babysitter · gestern',
    'homeYesterdayBabaFallback':
        'Routine von {name} eintragen — pädiatrische Einordnung.',
    'homeYesterdayBabaRoutineQuiet':
        'Wenig Einträge — verlässliche Routinen stützen die Emotionsregulation.',
    'homeYesterdayBabaRoutine':
        '{feeds} Mahlzeiten · Schlaf {sleep} · {diapers} Windeln.',
    'homeYesterdayBabaRoutineLowSleep':
        '{feeds} Mahlzeiten · Schlaf {sleep} (wenig) · {diapers} Windeln.',
    'homeYesterdayBabaGrowthBothWithin':
        'Gewicht und Länge auf der Referenzkurve.',
    'homeYesterdayBabaGrowthNoData': 'Gewicht/Länge in der Kurve aktualisieren.',
    'homeYesterdayBabaGrowthBelow':
        'Wachstum unter der Kurve — mit Kinderarzt besprechen.',
    'homeYesterdayBabaGrowthAbove':
        'Wachstum über der Kurve — in der Sprechstunde prüfen.',
    'homeYesterdayBabaGrowthCombo': 'Kurve: Gewicht {weight}, Länge {height}.',
    'homeYesterdayBabaBandWithin': 'adäquat',
    'homeYesterdayBabaBandBelow': 'unten',
    'homeYesterdayBabaBandAbove': 'oben',
    'homeYesterdayBabaBandUnknown': '—',
    'homeGreetingSubtitle': 'Schön, dich heute hier zu sehen!',
    'summaryWeightNotYet': 'Noch nicht eingetragen',
    'summarySleepNotYet': 'Heute noch kein Schlaf eingetragen',
    'shortcutMilkHomeSub': 'Mahlzeit eintragen',
    'shortcutGrowthHomeSub': 'Gewicht und Größe eintragen',
    'shortcutSleepHomeSub': 'Schlaf eintragen',
    'homeTileDiapers': 'Windelwechsel',
    'homeOneDayOld': '1 Tag',
    'homeDaysOld': '{d} Tage',
    'babyAgeOneWeek': '1 Woche',
    'babyAgeWeeks': '{n} Wochen',
    'babyAgeOneMonth': '1 Monat',
    'babyAgeMonths': '{n} Monate',
    'babyAgeOneYear': '1 Jahr',
    'babyAgeYears': '{n} Jahre',
    'summaryFeedings': 'MAHLZEITEN',
    'summarySleep': 'SCHLAF GESAMT',
    'summaryLastFeed': 'Letzte um {time}',
    'summaryLastSleep': 'Letzter um {time}',
    'summaryDiapers': 'WINDELN',
    'summaryFeedingsValue': '{n} · {m} Min.',
    'summaryFeedingsCountOne': '1 Mahlzeit',
    'summaryFeedingsCountMany': '{n} Mahlzeiten',
    'summaryFeedingsMinutes': '{m} Min.',
    'summaryDiapersValue': 'Gesamt {total} · Pipi {pee} · Stuhl {poo}',
    'summaryDiapersTotal': 'Gesamt {total} Wechsel',
    'summaryDiapersChangesOne': '1 Wechsel',
    'summaryDiapersChangesMany': '{n} Wechsel',
    'summaryDiapersPeePoo': '{pee} - Pipi    {poo} - Stuhl',
    'summarySleepValue': '{s} · {t}',
    'summarySleepSessionsOne': '1 Nickerchen',
    'summarySleepSessionsMany': '{s} Nickerchen',
    'summaryWeight': 'GEWICHT',
    'homeSummaryExtraHint': 'Summen des ausgewählten Tages',
    'add': 'Hinzufügen',
    'labelWeight': 'Gewicht',
    'labelHeight': 'Größe',
    'labelHead': 'Kopfumfang',
    'growthTabWeight': 'Gewicht',
    'growthTabHeight': 'Größe',
    'growthTabHead': 'Kopf',
    'growthTabSummary': 'Zusammenfassung',
    'growthAtBirth': 'Bei Geburt',
    'growthCardCurrent': 'Aktuell',
    'growthCardChange': 'Änderung',
    'growthAddWeight': 'Gewicht hinzufügen',
    'growthAddHeight': 'Größe hinzufügen',
    'growthAddHead': 'Kopfumfang hinzufügen',
    'growthSummaryIntro': 'Übersicht über Gewicht und Größe.',
    'growthChartCaption': '{name} — {metric}',
    'growthChartDeltaHint':
        'Vertikale Achse: Änderung gegenüber dem Geburtswert (0 = Geburt).',
    'growthHistoryTitle': '{label} (Verlauf)',
    'invalidGrowthValue': 'Gib einen gültigen Wert für {label} ein.',
    'growthSaved': '{label} erfolgreich gespeichert.',
    'growthEmpty': 'Noch keine Einträge für {label}.',
    'notifyGrowthWeightDownTitle': 'Gewicht niedriger als zuvor',
    'notifyGrowthWeightDownBody':
        'Der letzte Gewichtseintrag liegt unter dem vorherigen. Wende dich bei Unsicherheit an den Kinderarzt.',
    'notifyGrowthStaleTitle': 'Seit einiger Zeit kein Wachstumseintrag',
    'notifyGrowthStaleBody':
        'Seit der letzten Wachstumsmessung (Gewicht, Größe oder Kopfumfang) sind mehr als 30 Tage vergangen. Es sind {days} Tage — füge einen neuen Eintrag hinzu.',
    'reportDailyScreenTitle': 'Tagesbericht',
    'reportDayDetailsTitle': 'Tagesdetails',
    'reportDailyPickDayTooltip': 'Tag wählen',
    'reportDailySubtitleSleepQuality': 'Schlafqualität',
    'reportDailySubtitleTotalSleep': 'Gesamtschlaf',
    'reportDailySubtitleLongestStretch': 'Längste durchgehende Phase',
    'reportDailySubtitleFeedTotal': 'Mahlzeiten gesamt',
    'reportDailySubtitleFeedAvg': 'Durchschnittsdauer',
    'reportDailySubtitleFeedLast': 'Letzte Mahlzeit',
    'reportDailySubtitleDiaperTotal': 'Wechsel gesamt',
    'reportDailySubtitleDiaperWet': 'Nasse Windeln',
    'reportDailySubtitleDiaperDirty': 'Schmutzige Windeln',
    'reportDailySubtitleMoodMajority': 'Meiste Zeit',
    'reportDailySubtitleMoodIrrit': 'Reizbarkeit',
    'reportDailySubtitleWeightLast': 'Letzte Messung',
    'reportSleepQualityGood': 'Gut',
    'reportSleepQualityOk': 'Ok',
    'reportSleepQualityBad': 'Fragil',
    'reportSleepQualityMixed': 'Gemischt',
    'reportVsYesterdayShort': 'vs gestern',
    'reportVsYesterdayNA': '—',
    'reportVsYesterdayPct': '{pct}%',
    'reportLongestStretchHint': '{start} – {end}',
    'reportNapsLabel': 'Nickerchen',
    'reportTotalSmallLabel': 'Gesamt',
    'reportComparedAgeLabel': 'Verglichen mit dem Altersdurchschnitt',
    'reportBenchmarkAbove': 'Über dem Durchschnitt',
    'reportBenchmarkNear': 'Nahe am Durchschnitt',
    'reportBenchmarkBelow': 'Unter dem Durchschnitt',
    'reportIrritLow': 'Niedrig',
    'reportIrritMedium': 'Mittel',
    'reportIrritHigh': 'Hoch',
    'reportIrritUnknown': 'Keine Daten',
    'reportTabSleep': 'Schlaf',
    'reportTabFeedings': 'Mahlzeiten',
    'reportTabDiapers': 'Windeln',
    'reportTabMood': 'Stimmung',
    'reportAiInsightsTitle': 'Insights',
    'reportTimelineTitle': 'Tagesverlauf',
    'reportShareSoon': 'Teilen (bald)',
    'reportFeedingChartCaption': 'Mahlzeiten pro Stunde',
    'reportSleepChartCaption': 'Schlaf pro Stunde',
    'reportNoDataHint': 'Nicht genug Daten für diese Kennzahl.',
    'reportInsightSleepAgeGood':
        'Der Gesamtschlaf liegt nahe am typischen Bereich für dieses Alter — ein gutes Zeichen für Erholung.',
    'reportInsightSleepAgeLow':
        'Der Schlaf lag unter dem üblichen Bereich für dieses Alter; achte auf Müdigkeitssignale und Abendroutine.',
    'reportInsightFeedsOften':
        'Viele Mahlzeiten am Tag — häufig bei Wachstumsschüben; die Dauer hilft beim Erkennen von Durchschnittswerten.',
    'reportInsightDiapersFrequent':
        'Häufige Windelwechsel — Hydration kann gut sein oder die Haut braucht Pflege.',
    'reportInsightMoodLine': 'Überwiegende Stimmung in Erinnerungen: {mood}.',
    'reportWeeklyScreenTitle': 'Wochenbericht',
    'reportWeekDetailsTitle': 'Wochendetails',
    'reportWeeklyPickWeekTooltip': 'Woche wählen (beliebiger Tag)',
    'reportWeeklySummaryTitle': 'Wochenübersicht',
    'reportWeeklyTrendsTitle': 'Trends',
    'reportWeeklySeeFullDetails': 'Vollständigen Bericht ansehen',
    'reportWeeklyPartialWeekHint':
        'Durchschnitte und Trends: Montag bis {weekday} (laufende Woche).',
    'reportWeeklyFutureWeekHint':
        'Diese Woche hat im Kalender noch nicht begonnen — wähle eine andere Woche.',
    'reportWeeklyLoadErrorPrefix': 'Bericht konnte nicht geladen werden:',
    'reportWeeklyToneCalm': 'ruhige',
    'reportWeeklyToneActive': 'bewegte',
    'reportWeeklySleepUnknown':
        'Nicht genug Schlafdaten für den Wochenvergleich.',
    'reportWeeklyFirstWeekSleepLine':
        'Dies ist die erste Woche mit Einträgen — weiter protokollieren, damit Trends sichtbar werden.',
    'reportWeeklySleepStableShort':
        'Der Schlaf blieb gegenüber der Vorwoche stabil.',
    'reportWeeklySleepUp':
        'Der Schlaf verbesserte sich um etwa {pct}% gegenüber der Vorwoche.',
    'reportWeeklySleepDown':
        'Der Schlaf sank um etwa {pct}% gegenüber der Vorwoche.',
    'reportWeeklyFeedStableLine': 'Die Mahlzeiten blieben regelmäßig.',
    'reportWeeklyFeedUp':
        'Die täglichen Mahlzeiten stiegen im Schnitt um etwa {pct}%.',
    'reportWeeklyFeedDown':
        'Die täglichen Mahlzeiten sanken im Schnitt um etwa {pct}%.',
    'reportWeeklyHeroTemplate':
        '{name} hatte eine {tone} Woche! {sleep} {feed}',
    'reportWeeklyTrendLabelImproved': 'Verbessert',
    'reportWeeklyTrendLabelWorse': 'Schlechter',
    'reportWeeklyTrendLabelStable': 'Stabil',
    'reportWeeklyTrendLabelUnknown': '—',
    'reportWeeklyTrendLabelEvolving': 'Entwickelt sich',
    'reportWeeklyTrendLabelIncreased': 'Gestiegen',
    'reportWeeklyTrendNA': '—',
    'reportWeeklyHighlightSleep':
        'Positiv: erholsamerer Schlaf in dieser Woche.',
    'reportWeeklyHighlightFeedingStable':
        'Positiv: stabiler Ernährungsrhythmus.',
    'reportWeeklyHighlightDiaperUp':
        'Hinweis: mehr Wechsel — Hydration oder Verdauung aktiver.',
    'reportWeeklyHighlightWeight': 'Positiv: gesunde Gewichtszunahme.',
    'reportWeeklyHighlightGeneric': 'Weiter protokollieren für klarere Trends.',
    'reportWeeklyAvgFeedsDay': 'Tagesdurchschnitt: {avg} Mahlzeiten.',
    'reportWeeklyAvgDiapersDay': 'Tagesdurchschnitt: {avg} Wechsel.',
    'reportWeeklySleepHoursChartTitle': 'Schlafstunden pro Tag',
    'reportWeeklyAvgWeekLabel': 'Wochendurchschnitt',
    'reportWeeklyVsPrevWeekShort': 'vs Vorwoche',
    'reportWeeklyInsightsCardTitle': 'KI-Insights',
    'reportWeeklyPatternsTitle': 'Erkannte Muster',
    'reportWeeklySeeAllAnalyses': 'Alle Analysen ansehen',
    'reportWeeklyHeatmapSoon': 'Optionale Stunden-Heatmap kommt bald.',
    'reportWeeklyFeedChartCaption': 'Mahlzeiten pro Tag',
    'reportWeeklyDiaperChartCaption': 'Wechsel pro Tag',
    'reportWeeklyPatternWeekend':
        'Am Wochenende dehnt sich der Schlaf oft etwas aus.',
    'reportWeeklyPatternFeedingDown':
        'Weniger Mahlzeiten im Schnitt — häufig, wenn Intervalle länger werden.',
    'reportWeeklyPatternDefault':
        'Das Wochenmuster wirkt stabil — passe Routinen nach Bedarf an.',
    'reportWeeklyInsightSleepNeutral':
        'Der Schlaf war ähnlich wie in der Vorwoche.',
    'reportWeeklyInsightSleepBetter':
        'Mehr Schlaf als letzte Woche — ein gutes Zeichen.',
    'reportWeeklyInsightSleepLess':
        'Der Gesamtschlaf sank gegenüber letzter Woche — nachts beobachten.',
    'reportWeeklyInsightTemplate': '{name}: {sleep}',
    'reportMonthlyScreenTitle': 'Monatsbericht',
    'reportMonthlyAvgWeight': 'Durchschnittsgewicht',
    'reportMonthlyAvgHeight': 'Durchschnittsgröße',
    'reportMonthlyGrowthChartEmpty':
        'Füge diesen Monat mindestens zwei Gewichtseinträge hinzu, um das Diagramm zu sehen.',
    'reportMonthlySleepSection': 'Schlaf',
    'reportMonthlySleepAvg': 'Monatsdurchschnitt (pro Tag)',
    'reportMonthlyVsPrevMonth': 'vs Vormonat',
    'reportMonthlyBestWeeks': 'Wochen mit dem meisten Schlaf',
    'reportMonthlySleepTrendUp':
        'Gesamttrend: mehr erholsamer Schlaf in diesem Monat.',
    'reportMonthlySleepTrendDown':
        'Gesamttrend: weniger Gesamtschlaf als im Vormonat.',
    'reportMonthlySleepTrendStable':
        'Gesamttrend: stabiler Schlaf im Monatsverlauf.',
    'reportMonthlySleepTrendUnknown':
        'Nicht genug Daten für den Vergleich mit dem Vormonat.',
    'reportMonthlySleepExplain':
        'Der Durchschnitt pro Tag addiert alle Schlafsessions des Monats und teilt durch die Anzahl der Kalendertage.',
    'reportMonthlyFeedingSection': 'Ernährung',
    'reportMonthlyFeedFreq': 'Durchschnittliche Häufigkeit (Mahlzeiten/Tag)',
    'reportMonthlyFeedingExplain':
        'Die durchschnittliche Häufigkeit ist die Summe der Still- oder Fläschcheneinträge im Monat geteilt durch die Kalendertage.',
    'reportMonthlyPredominantHours': 'Häufigste Zeiten (Ende der Mahlzeit)',
    'reportMonthlyMemoriesTitle': 'Erinnerungen dieses Monats',
    'reportMonthlySeeAllMemories': 'Alle anzeigen',
    'reportMonthlyMemoriesEmpty':
        'Keine Fotos in Erinnerungen für diesen Monat.',
    'reportMonthlyVideosHint':
        'Videos erscheinen, wenn sie in Momenten gespeichert sind.',
    'reportSleepAdvScreenTitle': 'Schlafbericht',
    'reportSleepAdvScoreTitle': 'Schlafscore',
    'reportSleepAdvMetricsTitle': 'Wochenkennzahlen',
    'reportSleepAdvEfficiency': 'Schlafeffizienz',
    'reportSleepAdvVsPrevPct': 'Effizienzänderung: {pct}% (vs Vorwoche)',
    'reportSleepAdvOnset': 'Zeit bis zum ersten Nachtschlaf',
    'reportSleepAdvAwakenings': 'Aufwachen pro Nacht (Ø)',
    'reportSleepAdvAwakeningsTotal': 'Aufwachen diese Woche: {n}',
    'reportSleepAdvLongest': 'Längste durchgehende Phase',
    'reportSleepAdvAvgDailySleep': 'Durchschnittlicher Schlaf pro Tag',
    'reportSleepAdvIdealTitle': 'Beste Einschlafzeit',
    'reportSleepAdvIdealFooter':
        'Fenster aus deinen Einträgen geschätzt (kein medizinischer Rat).',
    'reportSleepAdvSeeFullAnalysis': 'Vollständige Analyse ansehen',
    'reportSleepAdvChartsSection': 'Schlafsession',
    'reportSleepAdvChartsSleepTrend': 'Schlafrhythmus (diese Woche)',
    'reportSleepAdvChartsCompare': 'Vergleich mit der Vorwoche',
    'reportSleepAdvChartsDistribution': 'Tag und Nacht (Wochensumme)',
    'reportSleepAdvChartsBars': 'Schlafvolumen: diese Woche vs vorherige',
    'reportSleepAdvDayPhase': 'Tagschlaf (6–18 Uhr)',
    'reportSleepAdvNightPhase': 'Nachtschlaf (18–6 Uhr)',
    'reportSleepAdvDistributionEmpty': 'Keine Daten zur Verteilung.',
    'reportSleepAdvLegendThisWeek': 'Diese Woche',
    'reportSleepAdvLegendPrevWeek': 'Vorwoche',
    'reportSleepAdvScoreBreakdown': 'Was der Score abbildet',
    'reportSleepAdvBreakdownLine':
        'Effizienz: {e} Pkt. • Lange Phasen: {s} Pkt. • Aufwachen: {a} Pkt. • Regelmäßigkeit: {c} Pkt.',
    'reportSleepAdvNotEnoughData':
        'Noch wenige Einträge diese Woche — Werte sind Richtwerte.',
    'reportSleepAdvStatusExcellent': 'Ausgezeichnet',
    'reportSleepAdvStatusGood': 'Gut',
    'reportSleepAdvStatusRegular': 'Regelmäßig',
    'reportSleepAdvStatusPoor': 'Fragil',
    'reportSleepAdvBadgeVeryGood': 'Sehr gut',
    'reportSleepAdvBadgeGood': 'Gut',
    'reportSleepAdvBadgeOk': 'Moderat',
    'reportSleepAdvBadgeAttention': 'Beobachten',
    'reportSleepAdvBadgeIdeal': 'Ideal',
    'reportSleepAdvBadgeUnknown': 'Keine Daten',
    'reportSleepAdvBadgeLow': 'Niedrig',
    'reportSleepAdvBadgeModerate': 'Moderat',
    'reportSleepAdvBadgeHigh': 'Hoch',
    'alertsScreenIntro':
        'Wähle, welche Erinnerungen FaceBaby senden darf. Alle Benachrichtigungen bleiben lokal auf diesem Gerät.',
    'alertsExactAlarmAndroidTitle': 'Berechtigung für genaue Alarme (Android)',
    'alertsExactAlarmAndroidBody':
        'Damit Erinnerungen pünktlich ankommen, erlaube FaceBaby in den Systemeinstellungen genaue Alarme / „Alarme & Erinnerungen“. Ohne diese Berechtigung kann Android Benachrichtigungen verzögern oder überspringen.',
    'alertsExactAlarmAndroidOpenSettings': 'Einstellungen öffnen',
    'alertsSectionFeeding': 'Ernährung',
    'alertsRuleFeeding':
        'Wenn aktiviert, plant die App eine lokale Benachrichtigung nach dem gewählten Intervall seit der letzten Still- oder Fläschchenmahlzeit.',
    'alertsSectionDiaper': 'Windel',
    'alertsRuleDiaper':
        'Die App schlägt etwa 3 h 30 nach dem letzten gespeicherten Wechsel eine Erinnerung vor. Ein neuer Wechsel plant sie neu.',
    'alertsSectionSleep': 'Schlaf',
    'alertsRuleSleep':
        'Mit dem Ende des letzten gespeicherten Schlafs und dem Alter des Babys kann die App Erinnerungen rund um das Wachfenster planen.',
    'alertsSectionGrowth': 'Wachstum und Messungen',
    'alertsRuleGrowth':
        'Benachrichtigt, wenn das neueste Gewicht unter dem vorherigen liegt oder mehr als 30 Tage keine Messung gespeichert wurde.',
    'alertsTestTitle': 'Benachrichtigungen testen',
    'alertsTestBody':
        'Löst eine sofortige Benachrichtigung aus und plant eine weitere in etwa 30 Sekunden. Nützlich, um zu prüfen, ob das System App-Benachrichtigungen zustellt.',
    'alertsTestRun': 'Test auslösen',
    'alertsTestResync': 'Neuplanung erzwingen (echte Erinnerungen)',
    'alertsTestImmediateTitle': 'FaceBaby — Soforttest',
    'alertsTestImmediateBody':
        'Wenn du diese Nachricht siehst, funktioniert der Sofortkanal.',
    'alertsTestScheduledTitle': 'FaceBaby — geplanter Test',
    'alertsTestScheduledBody':
        'Diese Benachrichtigung wurde über AlarmManager geplant (~30 s).',
    'alertsTestAllScheduleModesFailed': 'AlarmManager hat alle Modi abgelehnt',
    'alertsTestSentOk':
        'Gesendet. Du solltest jetzt die sofortige und in ~30 s die geplante Benachrichtigung erhalten.',
    'alertsTestFailed': 'Fehlgeschlagen: {errors}',
    'sleepToggleAlertsSubtitle':
        'Erinnerungen basierend auf dem letzten Schlafende und dem Alter des Babys.',
    'diaperToggleAlerts': 'Windel-Erinnerungen',
    'diaperToggleAlertsSubtitle':
        'Benachrichtigung rund um den empfohlenen nächsten Wechsel.',
    'healthGrowthToggleAlerts': 'Wachstumsalarme',
    'healthGrowthToggleAlertsSubtitle': 'Gewichts- und Messpausen-Hinweise.',
    'feedingScreenAlertsHint': 'Zum Ändern der Zeit öffne Mehr › Alarme.',
    'sleepNotifTitle': 'Schlaf',
    'sleepNotifBeforeBody':
        'Es könnte ein guter Moment sein, das Baby schlafen zu legen.',
    'sleepNotifOverdueBody':
        'Dein Baby könnte müde sein — versuche, den Schlaf ruhig einzuleiten.',
    'sleepNotifWakeOverdueBodyMale':
        'Er schläft schon seit mehr als {hours} Std., schau bitte nach ihm, Mama.',
    'sleepNotifWakeOverdueBodyFemale':
        'Sie schläft schon seit mehr als {hours} Std., schau bitte nach ihr, Mama.',
    'notifChannelRemindersName': 'Erinnerungen',
    'notifChannelRemindersDesc': 'Alarme für Ernährung, Windeln und Schlaf.',
    'notifChannelGrowthName': 'Wachstum',
    'notifChannelGrowthDesc':
        'Alarme zu Gewicht und längeren Pausen bei Messungen.',
    'sleepAlertsWakeWindowRulerValueAuto':
        'Effektive Zeit auf dieser Skala: {m} Min. (automatisch nach Alter).',
    'sleepAlertsWakeWindowRulerValueCustom':
        'Zeit auf dieser Skala: {m} Min. (eigener Wert).',
    'sleepAlertsWakeWindowSliderLabelAuto': '{m} Min. · auto',
    'sleepAlertsWakeWindowSliderLabelCustom': '{m} Min.',
    'sleepAlertsApproachRulerValueDefault':
        'Effektiver Vorlauf auf dieser Skala: {m} Min. (Standard).',
    'sleepAlertsApproachRulerValueCustom': 'Vorlauf auf dieser Skala: {m} Min.',
    'sleepAlertsApproachSliderLabelDefault': '{m} Min. · Standard',
    'sleepAlertsApproachSliderLabelCustom': '{m} Min.',
    'sleepAlertsWakeWindowAutomatic':
        'Wachfenster-Limit für die Erinnerung: {m} Min. (automatisch nach Alterstabelle).',
    'sleepAlertsWakeWindowAutomaticNoBirth':
        'Geburtsdatum des Babys im Profil hinzufügen für den richtigen Wert; bis dahin nutzen wir {m} Min. als Referenz.',
    'sleepAlertsMonthsApprox': 'Referenztabelle: ~{n} Monate',
    'sleepAlertsWakeWindowCustom': 'Eigenes Wachfenster-Limit: {m} Min.',
    'sleepAlertsApproachAuto':
        'Hinweis vor dem Limit: {m} Min. Vorlauf (Standardwert).',
    'sleepAlertsApproachCustom':
        'Hinweis vor dem Limit: {m} Min. Vorlauf (angepasst).',
    'sleepAppBar': 'Schlaf',
    'sleepTitle': 'Schlaf',
    'sleepIntro': 'Mittagsschlaf und Nachtschlaf erfassen und verfolgen.',
    'sleepComingTitle': 'Demnächst',
    'sleepComingBody':
        'Dieser Bildschirm ist bereit für die Schlafaufzeichnung.\nAls Nächstes verbinden wir die Datenbank und zeigen letzten Schlaf, Tagesgesamt und Verlauf.',
    'sleepSessionTitle': 'Schlaf läuft',
    'sleepSessionStartedAt': 'Gestartet um {time}',
    'sleepStatusSleeping': 'Schläft',
    'sleepStatusPaused': 'Pausiert',
    'sleepWakeButton': 'WACH GEWORDEN?',
    'sleepThisCardTitle': 'Dieser Schlaf',
    'sleepLabelStart': 'Beginn',
    'sleepLabelEnd': 'Ende',
    'sleepLabelDuration': 'Dauer',
    'sleepLabelQuality': 'Qualität',
    'sleepObservationsTitle': 'Notizen',
    'sleepObservationHint': 'Notiz hinzufügen…',
    'sleepPause': 'Pause',
    'sleepResume': 'Fortsetzen',
    'sleepCancelSession': 'Schlaf abbrechen',
    'sleepStartButton': 'SCHLAF STARTEN',
    'sleepSavedOk': 'Schlaf gespeichert.',
    'sleepResultDialogTitle': 'Schlafstatus',
    'sleepResultShortTitle': 'Kürzer geschlafen als erwartet',
    'sleepResultExpectedTitle': 'Schlaf im erwarteten Bereich',
    'sleepResultLongTitle': 'Länger geschlafen als erwartet',
    'sleepResultDurationLine': 'Erfasste Dauer: {duration}.',
    'sleepResultExpectedLine': 'Altersreferenz: etwa {min}–{max} Min.',
    'sleepResultShortBody':
        'Kurzer Schlaf. Achte auf Müdigkeitssignale und bereite die nächste Ruhe ruhig vor.',
    'sleepResultExpectedBody':
        'Gutes Ruhefenster. Dieser Schlaf lag nahe am Erwarteten für dieses Alter.',
    'sleepResultLongBody':
        'Längerer Schlaf. Kann Erholung von Müdigkeit sein; beobachte es, wenn es oft vorkommt.',
    'sleepConfirmBackTitle': 'Schlafverfolgung verlassen?',
    'sleepConfirmBackBody':
        'Diese Sitzung ist noch nicht gespeichert. Verwerfen?',
    'sleepConfirmCancelSessionTitle': 'Schlaf abbrechen?',
    'sleepConfirmCancelSessionBody': 'Die Zeit dieser Sitzung geht verloren.',
    'sleepDiscard': 'Verwerfen',
    'sleepHistoryTitle': 'Schlafverlauf',
    'sleepHistoryEmpty': 'Noch keine Schlafsitzungen.',
    'historyShowButton': 'Verlauf anzeigen',
    'historyHideButton': 'Verlauf ausblenden',
    'historyViewMoreButton': 'Mehr anzeigen',
    'sleepUpdatedOk': 'Schlaf aktualisiert.',
    'sleepBannerNextNap': 'Nächster Nickerchen in ~{min} Min.',
    'sleepWindowTitle': 'Aktuelles Schlaffenster',
    'sleepWindowEarly': 'Vor dem idealen Fenster',
    'sleepWindowIdeal': 'Ideal',
    'sleepWindowLate': 'Überfällig',
    'sleepRoutineLastLabel': 'Letzter Schlaf: vor {ago}',
    'sleepRoutineLastNever': 'Letzter Schlaf: noch keine Einträge',
    'sleepRoutineNextPrefix': 'Nächstes Nickerchen:',
    'sleepNextApproxMin': 'in ~{min} Min.',
    'sleepRoutineNextNow': 'jetzt — guter Zeitpunkt zum Versuchen',
    'sleepStatusEarly': '🟡 Vor dem idealen Fenster',
    'sleepStatusIdeal': '🟢 Ideales Fenster',
    'sleepStatusOverdue': '🔴 Wahrscheinlich übermüdet',
    'sleepHeroAwakeBadge': 'Wach',
    'sleepHeroAwakeCaption':
        'Die grüne → gelbe → rote Leiste zeigt, wie lange das Baby wach ist und wann ein Nickerchen fällig ist. Zum Schlafen SCHLAF STARTEN tippen.',
    'sleepHeroSleepingBadge': 'Schläft',
    'sleepHeroSleepingCaption':
        'Beim Aufwachen Schlaf beenden tippen, um diese Sitzung zu speichern.',
    'sleepRoutineCardTitle': 'Nächster Schlaf',
    'sleepRoutineVigilHighlight':
        'Wachfenster der App: {min}–{max} Min. wach zwischen Schlafphasen (fest nach Alter in Monaten — nicht einstellbar).',
    'sleepRoutineStatusLine': 'Status: {status}',
    'sleepIdealForAge': 'Gleiche Tabelle (nach Alter)',
    'sleepAgeMonthsLabel': '{n} Monate',
    'sleepWindowMinMax': '{min}–{max} Min.',
    'sleepLegendG': '🟢 ideales Fenster',
    'sleepLegendY': '🟡 vor dem idealen Fenster',
    'sleepLegendR': '🔴 überfällig',
    'sleepWakeWindowExplainer':
        'Zeigt, wie lange das Baby seit dem Ende des letzten Schlafs wach ist (nicht wie lange es geschlafen hat). Gelb: noch nicht im typischen Fenster für das nächste Nickerchen.',
    'sleepFinalizeButton': 'BEENDEN',
    'sleepSleepingFor': 'Schläft seit {when}',
    'sleepInsightTitle': 'Tagesübersicht',
    'sleepInsightNaps': 'Heute: {n} Nickerchen',
    'sleepInsightAvg': 'Durchschnitt: {min} Min.',
    'sleepInsightTrendDown': '💡 Heute weniger Schlaf als üblich',
    'sleepInsightTrendOk': '💡 Schlafmuster heute stabil',
    'sleepHistoryToday': 'Heute',
    'sleepToggleAlerts': 'Schlaferinnerungen aktivieren',
    'exampleCard': 'Beispiel-Impfheft:',
  },
  AppLang.it: {
    'appName': 'FaceBaby',
    'memoriesAlbumBackCoverBody':
        'FaceBaby è nato per trasformare semplici momenti in ricordi eterni. Ogni sorriso, scoperta, abbraccio e traguardo del tuo bambino merita di essere custodito con amore e significato.\n\nQuesto libro è stato creato per accompagnare i primi passi di questo meraviglioso viaggio, conservando ricordi preziosi da rivivere per sempre.\n\nPiù di semplici foto o annotazioni, queste pagine custodiscono emozioni, storie e sentimenti che il tempo non cancellerà mai.\n\nGrazie per aver permesso a FaceBaby di fare parte della storia della tua famiglia. 💛',
    'memoriesAlbumBackCoverFinale':
        'Perché i bambini crescono in fretta…\nma i ricordi possono durare per sempre.',
    'memoriesAlbumQualityTitle': 'Qualità del PDF',
    'memoriesAlbumQualityShareTitle': 'Leggero — per condividere',
    'memoriesAlbumQualityShareDesc':
        'Immagini compresse, file più piccolo. Ideale per WhatsApp ed e-mail.',
    'memoriesAlbumQualityPrintTitle': 'Alta qualità — per stampare',
    'memoriesAlbumQualityPrintDesc':
        'Foto ad alta risoluzione. File più grande; migliore per la stampa.',
    'memoriesAlbumExportTitle': 'Creazione del libro…',
    'memoriesAlbumProgressPreparing': 'Preparazione pagine…',
    'memoriesAlbumProgressImages': 'Elaborazione foto ({current}/{total})…',
    'memoriesAlbumProgressBuilding': 'Creazione PDF ({current}/{total})…',
    'memoriesAlbumProgressSaving': 'Salvataggio file…',
    'memoriesAlbumCancelBtn': 'Annulla',
    'memoriesAlbumCanceled': 'Generazione annullata.',
    'memoriesAlbumErrorNetwork':
        'Nessuna connessione Internet. Controlla la rete e riprova.',
    'memoriesAlbumErrorStorage':
        'Spazio insufficiente sul dispositivo per salvare il PDF.',
    'memoriesAlbumSkippedImages':
        '{count} foto non incluse (rete o file non valido).',
    'home': 'Home',
    'records': 'Registri',
    'reports': 'Report',
    'memories': 'Ricordi',
    'more': 'Altro',
    'helloMom': 'Ciao, Mamma!',
    'today': 'Oggi',
    'shortcuts': 'Scorciatoie',
    'registerNow': 'Registra ora',
    'edit': 'Modifica',
    'delete': 'Elimina',
    'cancel': 'Annulla',
    'confirmDelete': 'Sei sicura di voler eliminare questo registro?',
    'deletedOk': 'Eliminato correttamente.',
    'deleteFail': 'Impossibile eliminare:',
    'todaySummary': 'Riepilogo di oggi',
    'nextEvents': 'Prossimi eventi',
    'quickRecordsTitle': 'Registri rapidi',
    'quickRecordsSubtitle': 'Aggiungi la routine del bimbo in pochi tocchi.',
    'feedingAlertsSwitchTitle': 'Avviso alimentazione',
    'feedingAlertsSwitchSubtitle':
        'Avvisa quando è passato l’intervallo impostato dall’ultima poppata o biberon.',
    'feedingAlertsIntervalCaption':
        'Ricorda dopo l’ultima poppata: {m} min (20–360)',
    'feedingAlertsShortcutTitle': 'Avviso alimentazione',
    'scheduledFeedingReminderBody':
        'È il momento del promemoria per la poppata. Tocca per registrare.',
    'scheduledDiaperReminderTitle': 'Cambio pannolino',
    'scheduledDiaperReminderBody':
        'È passato il tempo suggerito dall’ultimo cambio. Tocca per registrare.',
    'whatHappenedNow': 'Cosa è successo ora?',
    'momNote': 'Nota della mamma',
    'saveRecord': 'Salva',
    'reportsTitle': 'Report',
    'reportsSubtitle': 'Un riepilogo per la mamma e il pediatra.',
    'reportsHubAnchorLabel': 'Riferimento',
    'reportsHubPickDayTooltip': 'Scegli il giorno di riferimento per i report',
    'reportsHubSectionTitle': 'Report disponibili',
    'reportStubComingSoon':
        'Questo report si aggiornerà automaticamente con i dati dell’app per il periodo selezionato.',
    'reportListDaily': 'Report giornaliero',
    'reportListDailySub': 'Riepilogo e dettagli del giorno selezionato',
    'reportListWeekly': 'Report settimanale',
    'reportListWeeklySub':
        'Riepilogo e dettagli della settimana del giorno selezionato',
    'reportListMonthly': 'Report mensile',
    'reportListMonthlySub': 'Aggregati mensili del mese del giorno selezionato',
    'reportListSleepAdv': 'Report avanzato del sonno',
    'reportListSleepAdvSub': 'Pattern e metriche del sonno',
    'reportListDevelopment': 'Report di sviluppo',
    'reportListDevelopmentSub': 'Traguardi e salti di sviluppo',
    'plusBrandTitle': 'FaceBaby Premium',
    'plusSheetHero':
        'Un unico gesto per sempre: PDF eleganti, libro dei ricordi, più foto in bacheca, backup nel cloud e strumenti che rendono più leggera la giornata della mamma.',
    'plusSheetPriceLabel': 'Pagamento unico',
    'plusSheetBullets':
        '• Report in PDF (sonno, routine, crescita)\n• Libro dei ricordi in PDF\n• Esporta badge (PNG / PDF)\n• Backup cloud tra telefoni\n• Più ricordi e foto\n• Insight intelligenti nei report\n• Report per il pediatra\n• Statistiche avanzate\n• Temi premium del libro',
    'plusCtaSubscribe': 'Sblocca per sempre',
    'plusCtaRestore': 'Ripristina acquisti',
    'plusCtaLater': 'Non ora',
    'plusSheetFootnote':
        'Acquisto unico elaborato da Google Play o App Store. Dalle impostazioni dell’account puoi ripristinarlo su un altro telefono.',
    'plusWelcomeSnack':
        'Grazie per aver scelto FaceBaby Premium — i ricordi del bimbo sono ancora più al sicuro.',
    'plusPurchaseUnavailableSnack':
        'Impossibile avviare l’acquisto. Controlla il prodotto nello store o riprova più tardi.',
    'plusPurchaseSkuNotFoundSnack':
        'Google Play non ha restituito il prodotto "{id}". Nel Play Console crea un prodotto in-app gestito attivo con questo ID esatto, oppure usa --dart-define=FACEBABY_PREMIUM_SKU=… nella build.',
    'plusPurchaseBillingLaunchFailedSnack':
        'Impossibile aprire il pagamento su Google Play. Installa l’app dal test interno/chiuso o dallo store, usa un account tester e riprova.',
    'plusPaywallSkuMissingHint':
        'Prezzo dello store ancora non disponibile per "{id}". Controlla che il prodotto sia attivo nel Play Console o attendi la sincronizzazione.',
    'plusRestoreOkSnack': 'Acquisti ripristinati correttamente.',
    'plusRestoreEmptySnack':
        'Non abbiamo trovato un acquisto precedente su questo account.',
    'plusSnackLockedFeature': 'Incluso in FaceBaby Premium.',
    'plusMemoryLimitSnack':
        'Nel piano gratuito puoi salvare fino a {max} foto sui badge.',
    'plusMemoryLimitDialogTitle': 'Sblocca più ricordi',
    'plusMemoryLimitDialogBody':
        'Nel piano gratuito puoi salvare fino a {max} foto sui badge.\n\nPassa a FaceBaby Premium con pagamento unico — senza abbonamento mensile — per foto illimitate, report, export e altre funzioni del portale.',
    'plusMemoryLimitDialogSubscribe': 'Passa a Premium',
    'plusReportsLockedHint': 'Report FaceBaby Premium',
    'plusExportLockedHint': 'Esportazione FaceBaby Premium',
    'plusLifetimePaymentBadge': 'Pagamento unico',
    'plusNoMonthlyBadge': 'Nessun abbonamento mensile',
    'plusPremiumActiveTitle': 'Grazie per Premium',
    'plusPremiumActiveBody':
        'Hai tutte le funzioni premium attive per sempre su questo dispositivo. Puoi ripristinare gli acquisti su un altro telefono quando serve.',
    'plusPurchaseErrorSnack':
        'Qualcosa è andato storto. Riprova o usa Ripristina acquisti.',
    'plusDoneClose': 'Chiudi',
    'plusPaywallHeadline':
        'Ogni piano è pensato per\nsupportarti in ogni fase.',
    'plusPaywallActiveNote':
        'Il tuo Premium è attivo. Puoi consultare i piani in qualsiasi momento.',
    'plusPaywallSecureNote':
        'Acquisto 100% sicuro. Puoi annullare quando vuoi.',
    'plusPlanPremiumTitle': 'Premium',
    'plusPlanPremiumSubtitle': 'Tutto per prenderti cura\ne seguire al meglio',
    'plusPlanPremiumBadge': 'Più scelto',
    'plusPlanPremiumPriceSubActive': 'attivo ora',
    'plusPlanPremiumPriceSubSecure': 'acquisto sicuro',
    'plusPlanPremiumButtonActive': 'Piano attuale',
    'plusPlanPremiumButton': 'Voglio Premium',
    'plusPlanPremiumFeature1': 'Tutto del piano Gratuito',
    'plusPlanPremiumFeature2': 'Report completi del bimbo',
    'plusPlanPremiumFeature3':
        'Report per il pediatra (utile da condividere con il tuo pediatra)',
    'plusPlanPremiumFeature4': 'Descrizione dei segni zodiacali',
    'plusPlanPremiumFeature5': 'Messaggi biblici quotidiani',
    'plusPlanPremiumFeature6': 'Analisi e insight dello sviluppo',
    'plusPlanPremiumFeature7': 'Contenuti e consigli esclusivi',
    'plusPlanPremiumFeature8': 'Supporto prioritario',
    'plusPlanAiTitle': 'IA Tata',
    'plusPlanAiSubtitle': 'Assistente intelligente\nper tutti i giorni',
    'plusPlanAiBadge': 'Presto',
    'plusPlanAiFeature1': 'Tutto del piano Premium',
    'plusPlanAiFeature2': 'IA Tata 24h con te',
    'plusPlanAiFeature3': 'Risposte intelligenti',
    'plusPlanAiFeature4': 'Indicazioni personalizzate',
    'plusPlanAiFeature5': 'Avvisi predittivi',
    'plusPlanAiFeature6': 'Routine personalizzate',
    'plusPlanAiFeature7': 'Contenuti generati dall’IA',
    'plusPlanAiPrice': 'Presto',
    'plusPlanAiPriceSub': 'Resta aggiornata!',
    'plusPlanAiButton': 'Avvisami',
    'plusPlanFreeTitle': 'Gratuito',
    'plusPlanFreeSubtitle': 'Inizia il tuo percorso con l’essenziale',
    'plusPlanFreePrice': '0,00 €',
    'plusPlanCurrent': 'Piano attuale',
    'plusPlanFreeFeature1': 'Profili base',
    'plusPlanFreeFeature2': 'Registrazione quotidiana',
    'plusPlanFreeFeature3': 'Agenda e promemoria',
    'plusPlanFreeFeature4': 'Peso e altezza',
    'plusTrustData': 'I tuoi dati\nsempre sicuri',
    'plusTrustFamily': 'Creato con amore\nper le famiglie',
    'plusTrustContent': 'Contenuti affidabili\ne aggiornati',
    'plusTrustSupport': 'Supporto in ogni\nmomento',
    'settingsPlusCardTitle': 'FaceBaby Premium',
    'settingsPlusCardBodyFree':
        'PDF, libro dei ricordi, più foto, backup cloud, report per il pediatra e statistiche avanzate — con un unico pagamento.',
    'settingsPlusCardBodyActive':
        'FaceBaby Premium è attivo — grazie per sostenere il progetto.',
    'settingsPlusUpgradeCta': 'Sblocca Premium',
    'settingsPlusManageCta': 'Vedi Premium',
    'plusMemoryCounterFree': '{n} di {max} momenti nel piano gratuito',
    'growth': 'Crescita',
    'pediatricReport': 'Report pediatrico',
    'pediatricReportDesc':
        'Genera un PDF con peso, sonno, alimentazione, pannolini, vaccini, sintomi registrati in Salute, visite e note.',
    'reportListPediatric': 'Report per il pediatra',
    'reportListPediatricSub': 'PDF e dati per la visita medica',
    'healthHubSymptomReports': 'Segnala sintomo',
    'healthHubSymptomReportsSub':
        'Febbre, coliche, farmaci e altro — inclusi nel report pediatrico',
    'symptomReportTitle': 'Segnala sintomo',
    'symptomReportEmpty': 'Nessuna voce. Tocca + per aggiungerne una.',
    'symptomReportNew': 'Nuova voce',
    'symptomReportSave': 'Salva',
    'symptomReportOccurredAt': 'Data e ora',
    'symptomReportPickDateTime': 'Modifica data e ora',
    'symptomReportMedication': 'Farmaci assunti',
    'symptomReportMedicationHint': 'Nome o nota breve',
    'symptomReportFever': 'Febbre',
    'symptomReportTemp': 'Temperatura',
    'symptomReportTempHint': 'Secondo le unità nelle Impostazioni',
    'symptomReportCrying': 'Pianto senza causa apparente',
    'symptomReportPain': 'Dolore',
    'symptomReportColic': 'Coliche',
    'symptomReportReflux': 'Reflusso',
    'symptomReportOther': 'Altro',
    'symptomReportOtherHint': 'Breve descrizione',
    'symptomReportValidationNeedOne':
        'Seleziona almeno un sintomo o compila un campo.',
    'symptomReportValidationFeverTemp':
        'Inserisci la temperatura se segni la febbre.',
    'symptomReportDeleteTitle': 'Eliminare la voce?',
    'symptomReportDeleteBody': 'Questa azione non può essere annullata.',
    'reportPediatricScreenTitle': 'Report pediatrico',
    'reportPediatricPeriodPrefix': 'Periodo:',
    'reportPediatricFilterHint': 'Periodo del report',
    'reportPediatricDateFrom': 'Da',
    'reportPediatricDateTo': 'A',
    'reportPediatricPickRange': 'Scegli date',
    'reportPediatricFilterMaxDaysHint':
        'Tocca per modificare. Intervalli molto lunghi sono limitati a 366 giorni.',
    'reportPediatricSectionGeneral': 'Informazioni generali',
    'reportPediatricSectionSummary': 'Riepilogo del periodo',
    'reportPediatricSectionSleep': 'Sonno',
    'reportPediatricSectionFeeding': 'Alimentazione',
    'reportPediatricSectionSymptoms': 'Sintomi e registrazioni',
    'reportPediatricSectionObservations': 'Osservazioni dei genitori',
    'reportPediatricLabelName': 'Nome',
    'reportPediatricLabelAge': 'Età',
    'reportPediatricLabelBirth': 'Data di nascita',
    'reportPediatricLabelWeightCurrent': 'Peso (ultimo nel periodo)',
    'reportPediatricLabelHeight': 'Altezza',
    'reportPediatricWeightStart': 'Peso iniziale (periodo)',
    'reportPediatricWeightEnd': 'Peso finale (periodo)',
    'reportPediatricWeightGain': 'Variazione di peso',
    'reportPediatricHeightStart': 'Altezza iniziale (periodo)',
    'reportPediatricHeightEnd': 'Altezza finale (periodo)',
    'reportPediatricHeightGain': 'Crescita in altezza',
    'reportPediatricAvgFeeds': 'Pasti/alimentazioni al giorno (media)',
    'reportPediatricAvgSleep': 'Sonno al giorno (media)',
    'reportPediatricAvgDiapers': 'Cambi pannolino al giorno (media)',
    'reportPediatricFeverEpisodes':
        'Episodi di febbre (registrazione strutturata)',
    'reportPediatricFeverNote': 'Nota',
    'reportPediatricFeverFootnote':
        'Conteggio dalle registrazioni strutturate in Salute › Segnala sintomo (con temperatura se indicata).',
    'reportPediatricVaccines': 'Vaccini nel periodo',
    'reportPediatricMedications':
        'Farmaci (registrazioni e parole chiave nelle note)',
    'reportPediatricSleepAvgDaily': 'Sonno medio giornaliero',
    'reportPediatricSleepAwakenings': 'Risvegli notturni (media)',
    'reportPediatricSleepPattern': 'Andamento generale del sonno',
    'reportPediatricSleepPatternStable': 'Prevalentemente continuo',
    'reportPediatricSleepPatternModerate': 'Intermedio',
    'reportPediatricSleepPatternFragmented': 'Più frammentato',
    'reportPediatricSleepLongest': 'Sonno continuo più lungo',
    'reportPediatricFeedingBreast': 'Allattamento',
    'reportPediatricFeedingFormula': 'Formula',
    'reportPediatricFeedingSolid': 'Solidi',
    'reportPediatricFeedingSessions': 'sessioni',
    'reportPediatricFeedingAvgDur': 'durata media',
    'reportPediatricSymptomReflux': 'Reflusso (diari o registrazioni)',
    'reportPediatricSymptomColic': 'Coliche (diari o registrazioni)',
    'reportPediatricSymptomIrrit': 'Irritabilità (umori)',
    'reportPediatricIrritHigh': 'Più evidente',
    'reportPediatricIrritMedium': 'Moderata',
    'reportPediatricIrritLow': 'Lieve',
    'reportPediatricIrritUnknown': 'Nessun dato',
    'reportPediatricYes': 'Sì',
    'reportPediatricNo': 'No',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'Diari del giorno',
    'reportPediatricJournalNoteHint':
        'Rilevamento parole chiave nel testo libero.',
    'reportPediatricObsHint':
        'Note per la visita: sintomi, farmaci, cambiamenti di comportamento…',
    'reportPediatricBtnShare': 'Condividi',
    'reportPediatricBtnExportPdf': 'Esporta PDF',
    'reportPediatricBtnPrint': 'Stampa',
    'reportPediatricBtnEmail': 'Email',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote':
        'Documento informativo dai dati locali. Non sostituisce una valutazione clinica.',
    'reportPediatricNone': 'Nessuno',
    'reportPediatricPdfTitle': 'Report pediatrico — FaceBaby',
    'reportPediatricPdfPeriod': 'Periodo:',
    'reportPediatricPdfFooter':
        'Generato in FaceBaby. Contenuto limitato ai dati su questo dispositivo (anche offline).',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomFromJournal': 'citato nel diario (senza orario)',
    'reportPediatricSymptomCrying': 'Pianto senza causa (registrazioni)',
    'reportPediatricSymptomPain': 'Dolore (registrazioni)',
    'reportPediatricStructuredSymptoms': 'Registrazioni sintomi (data e ora)',
    'reportPediatricStructuredSymptomsEmpty':
        'Nessuna registrazione strutturata in questo periodo.',
    'reportDevScreenTitle': 'Sviluppo',
    'reportDevSubtitle': 'Traguardi delicati da seguire al ritmo del bimbo.',
    'reportDevScoreTitle': 'Punteggio di sviluppo',
    'reportDevScoreStatusOnTrack': 'Nel range previsto',
    'reportDevScoreStatusWatch': 'Spazio per far sbocciare nuove abilità',
    'reportDevScoreStatusEarly': 'Cresce al suo dolce ritmo',
    'reportDevSectionMotor': 'Sviluppo motorio',
    'reportDevSectionCognitive': 'Sviluppo cognitivo',
    'reportDevSectionSocial': 'Sociale ed emotivo',
    'reportDevAchieved': 'In linea',
    'reportDevGrowing': 'In sviluppo',
    'reportDevInsightTitle': 'Insight delicato',
    'reportDevSeeAllMarcos': 'Vedi tutti i traguardi',
    'reportDevFootnote':
        'I traguardi sono guide generali; ogni bimbo è diverso. In caso di dubbi, chiedi al pediatra.',
    'reportDevNeedBirth':
        'Aggiungi la data di nascita del bimbo per vedere questo report.',
    'devReport_motor_head': 'Tiene su la testa',
    'devReport_motor_roll': 'Si gira (es. da pancia in giù a schiena)',
    'devReport_motor_sit': 'Sta seduto (con o senza supporto)',
    'devReport_motor_crawl': 'Gattona o si muove su mani e ginocchia',
    'devReport_motor_walk': 'Fa passi / cammina con supporto',
    'devReport_cog_faces': 'Riconosce volti familiari',
    'devReport_cog_sounds': 'Risponde a suoni e voci',
    'devReport_cog_track': 'Segue oggetti con gli occhi',
    'devReport_cog_babble': 'Lallazione o vocalizzi',
    'devReport_cog_visual': 'Mantiene il contatto visivo nel gioco',
    'devReport_soc_smile': 'Sorriso sociale',
    'devReport_soc_emotion_resp': 'Risposte emotive ai caregiver',
    'devReport_soc_family': 'Interazione con la famiglia vicina',
    'devReport_soc_emotion_react': 'Reazioni emotive alle situazioni',
    'devReportInsightNewborn':
        'Nei primi giorni, legame e sicurezza contano più di tutto — ogni piccolo segnale è importante.',
    'devReportInsightOnTrack':
        'Ciò che vediamo qui rientra nei pattern comuni per bimbi di questa età.',
    'devReportInsightVariety':
        'È normale che le abilità arrivino un po’ prima o un po’ dopo.',
    'devReportInsightPatience':
        'Alcuni traguardi stanno ancora maturando — tummy time, voce e gioco dolce aiutano.',
    'devReportInsightBalanced':
        'Celebra le piccole conquiste; calore e routine delicate sono stimoli potenti.',
    'generatePdf': 'Genera PDF',
    'reportMonthlyMilestonesTitle': 'Traguardi del mese',
    'reportMonthlyMilestonesEmpty':
        'Nessun vaccino, visita o ricordo con badge questo mese.',
    'reportMonthlyMilestoneConsultationDefault': 'Visita',
    'memoriesProgressSaved': '{filled} di {total} momenti salvati',
    'memoriesProgressStandardBadges': '({count} badge standard)',
    'memoriesCheerEmpty': 'Tocca un badge con + per aggiungere foto e storie.',
    'memoriesAlbumPromoTitle': 'Il tuo libro dei ricordi completo',
    'memoriesAlbumPromoSubtitle':
        'Scarica un PDF elegante con copertina FaceBaby, cornice decorativa e tutti i badge compilati — perfetto da conservare o condividere.',
    'memoriesAlbumDownloadCta': 'Scarica album PDF',
    'memoriesAlbumGenerating': 'Creazione dell’album…',
    'memoriesAlbumNeedFilled':
        'Compila almeno un momento nell’album per generare il PDF.',
    'memoriesAlbumError': 'Impossibile generare il PDF.',
    'memoriesAlbumPdfReadyTitle': 'Album PDF pronto',
    'memoriesAlbumShareAction': 'Condividi…',
    'memoriesAlbumSaveAction': 'Salva / scarica',
    'memoriesAlbumSavedSnack': 'PDF salvato sul dispositivo.',
    'memoriesAlbumSaveFailedSnack': 'Impossibile salvare il PDF.',
    'memoriesAlbumCoverMain': 'Libro dei ricordi',
    'memoriesAlbumCoverTagline': 'Momenti speciali con {name}',
    'memoriesAlbumFooter': 'Creato con FaceBaby',
    'memoryBadgeMonthOne': '1 mese',
    'memoryBadgeMonthsMany': '{n} mesi',
    'memoryBadgeYearOne': '1 anno',
    'memoryBadgeYearsMany': '{n} anni',
    'memoryBadgeMonthUnitSingular': 'mese',
    'memoryBadgeMonthUnitPlural': 'mesi',
    'badge_arrived_home': 'Finalmente a casa',
    'badge_first_smile': 'Primo sorriso',
    'badge_first_feeding': 'Prima poppata',
    'badge_sleeping': 'Dormendo',
    'badge_bath_time': 'Ora del bagnetto',
    'badge_going_out': 'Prima passeggiata',
    'badge_first_laugh': 'Prima risata',
    'badge_found_hands': 'Ha scoperto le manine',
    'badge_lifted_head': 'Ha sollevato la testa',
    'badge_at_park': 'Al parco',
    'badge_first_hug': 'Primo abbraccio',
    'badge_first_foods': 'Primi alimenti',
    'badge_first_bath': 'Primo bagnetto',
    'badge_crib_sleep': 'Primo sonnellino nella culla',
    'badge_first_diaper_change': 'Primo cambio pannolino',
    'badge_first_burp': 'Primo ruttino',
    'badge_first_mom_cuddle': 'Prime coccole con mamma',
    'badge_first_dad_cuddle': 'Prime coccole con papà',
    'badge_first_pediatrician': 'Prima visita pediatrica',
    'badge_first_vaccine': 'Primo vaccino',
    'badge_first_car_ride': 'Primo viaggio in auto',
    'badge_first_stroller_ride': 'Prima uscita in passeggino',
    'badge_favorite_toy': 'Gioco preferito',
    'badge_first_night_home': 'Prima notte a casa',
    'badge_first_giggle': 'Prima risatina',
    'badge_sun_bath': 'Primo bagnetto di sole',
    'badge_first_christmas': 'Primo Natale',
    'badge_first_new_year': 'Primo Capodanno',
    'badge_first_mothers_day': 'Prima Festa della mamma',
    'badge_first_fathers_day': 'Prima Festa del papà',
    'badge_first_tooth': 'Primo dentino',
    'badge_first_puree': 'Prima pappa',
    'badge_sat_alone': 'Seduto senza appoggio',
    'badge_crawled': 'Ha gattonato',
    'badge_stood_up': 'Si è alzato in piedi',
    'badge_first_steps': 'Primi passi',
    'badge_first_word': 'Prima parola',
    'badge_favorite_song': 'Canzone preferita',
    'badge_first_trip': 'Primo viaggio',
    'badge_family_birthday': 'Primo compleanno in famiglia',
    'badge_first_beach': 'Prima giornata al mare',
    'badge_first_pool': 'Prima piscina',
    'badge_first_haircut': 'Primo taglio di capelli',
    'badge_first_shoes': 'Prime scarpine',
    'badge_special_outfit': 'Look speciale',
    'badge_first_friend': 'Primo amichetto',
    'badge_first_party': 'Prima festa',
    'badge_first_cartoon': 'Primo cartone animato',
    'badge_first_book': 'Primo libro',
    'badge_special_free': 'Momento speciale',
    'homeBannerChipVaccine': 'Vaccino oggi',
    'homeMotivationBanner':
        'Stai facendo un ottimo lavoro! Piccoli registri, grandi ricordi.',
    'homeMotivationBannerOpenMemories': 'Apri il libro dei ricordi',
    'healthHubTitle': 'Salute',
    'healthHubIntro': 'Vaccini, visite e cure del bimbo in un unico posto.',
    'healthHubSection': 'Accesso rapido',
    'healthHubVaccines': 'Libretto vaccinale',
    'healthHubVaccinesSub': 'Registra e controlla i vaccini del bimbo',
    'vaccDueConfirmCheckbox':
        'Confermo che questa dose è già stata somministrata.',
    'vaccDueSavedOk': 'Vaccino registrato come somministrato.',
    'vaccDuePickTitle': 'Vaccini previsti per oggi',
    'homeSummaryHealthStripTitle': 'Vaccini e visite in questo giorno',
    'homeSummaryHealthStripEmpty':
        'Nessun vaccino o visita registrati per questo giorno.',
    'weeklyPhotoPublicExplainer':
        'Quando lo rendi pubblico, questo ricordo potrà partecipare alla Foto della settimana ed essere visto da altre mamme in FaceBaby.',
    'weeklyPhotoPublicOff': 'Privato',
    'weeklyPhotoPublicOn': 'Pubblico',
    'weeklyPhotoPublicNeedPhoto':
        'Aggiungi una foto per rendere pubblico questo ricordo.',
    'weeklyPhotoConfirmTitle': 'Rendere pubblica questa foto?',
    'weeklyPhotoConfirmBody':
        'Accetti di mostrare questa foto ad altri utenti se vieni estratta come vincitrice della settimana?',
    'weeklyPhotoConfirmNo': 'No',
    'weeklyPhotoConfirmYes': 'Sì',
    'weeklyPhotoParticipatingBadge': 'Partecipa alla Foto della settimana',
    'weeklyPhotoWinnerBadge':
        'Questo ricordo è stato scelto come Foto della settimana 💜',
    'weeklyPhotoShowBabyFirstName':
        'Mostra il nome del bimbo nella bacheca pubblica',
    'weeklyPhotoDisclaimerFooter':
        'Partecipano solo le foto segnate come pubbliche. Puoi rimuovere questa opzione in qualsiasi momento.',
    'weeklyPhotoReportLink': 'Segnala',
    'weeklyPhotoReportTitle': 'Segnala foto',
    'weeklyPhotoReportHint':
        'Descrivi il motivo della segnalazione. Il team FaceBaby la esaminerà.',
    'weeklyPhotoReportMessageLabel': 'Motivo della segnalazione',
    'weeklyPhotoReportSubmit': 'Invia segnalazione',
    'weeklyPhotoReportSuccess':
        'Segnalazione inviata. Grazie per aiutare a mantenere la community sicura.',
    'weeklyPhotoReportNeedLogin':
        'Accedi al tuo account per inviare una segnalazione.',
    'weeklyPhotoReportMessageTooShort':
        'Scrivi almeno 5 caratteri nel motivo della segnalazione.',
    'weeklyPhotoReportMessageTooLong':
        'Il testo della segnalazione è troppo lungo.',
    'weeklyPhotoReportFailed': 'Impossibile inviare la segnalazione. Riprova.',
    'weeklyPhotoSectionTitleMale': 'Principe della settimana',
    'weeklyPhotoSectionTitleFemale': 'Principessa della settimana',
    'weeklyPhotoHomeHeroMale': 'PRINCIPE DELLA SETTIMANA',
    'weeklyPhotoHomeHeroFemale': 'PRINCIPESSA DELLA SETTIMANA',
    'weeklyPhotoSectionSubtitle':
        'Un ricordo speciale condiviso da una mamma FaceBaby.',
    'weeklyPhotoViewMemory': 'Vedi ricordo',
    'weeklyPhotoBabyFallback': 'Un bimbo FaceBaby',
    'weeklyPhotoDisclaimerShort':
        'Partecipano solo le foto segnate come pubbliche. Puoi rimuovere questa opzione in qualsiasi momento.',
    'weeklyPhotoPublicDetailAppBar': 'Ricordo della settimana',
    'weeklyPhotoWinnerCongratsTitle': 'Congratulazioni, Mamma!',
    'weeklyPhotoWinnerCongratsBody':
        'La foto della tua Principessa è stata scelta per questa settimana! Festeggiamola tutti insieme.\n\nLa famiglia FaceBaby ti ringrazia per aver condiviso questo bellissimo momento con noi! 💜',
    'weeklyPhotoWinnerCongratsBodyMale':
        'La foto del tuo Principe è stata scelta per questa settimana! Festeggiamolo tutti insieme.\n\nLa famiglia FaceBaby ti ringrazia per aver condiviso questo bellissimo momento con noi! 💜',
    'weeklyPhotoWinnerCongratsBodyFemale':
        'La foto della tua Principessa è stata scelta per questa settimana! Festeggiamola tutti insieme.\n\nLa famiglia FaceBaby ti ringrazia per aver condiviso questo bellissimo momento con noi! 💜',
    'weeklyPhotoWinnerCongratsOk': 'Conferma',
    'commonCouldNotSave': 'Impossibile salvare.',
    'commonSaving': 'Salvataggio…',
    'commonSave': 'Salva',
    'commonSelect': 'Seleziona',
    'commonBack': 'Indietro',
    'commonAdvance': 'Avanti',
    'commonClose': 'Chiudi',
    'commonName': 'Nome',
    'commonPhone': 'Telefono',
    'openingGallery': 'Apertura galleria…',
    'memoriesPhotoError': 'Impossibile selezionare la foto.',
    'memoriesTodayTitle': 'Ricordi di oggi',
    'memoriesTodayAsk': 'Hai già aggiunto la foto di oggi?',
    'memoriesNotYet': 'Non ancora',
    'memoriesAddPhotoDialog': 'Aggiungi foto',
    'memoriesAlreadyPostedToday': 'Hai già aggiunto la foto di oggi.',
    'memoriesWallEmpty':
        'La tua bacheca è ancora vuota. Aggiungi la prima foto del giorno!',
    'memoriesHighlights': 'In evidenza',
    'memoriesWallSection': 'Bacheca',
    'memoryTellMomentTitle': 'Racconta questo momento',
    'memoryTellMomentHint':
        'Com’è stato? Condividi i dettagli che vuoi conservare…',
    'memoryBabyInfoOptionalTitle': 'Info bimbo (opzionale)',
    'memoryBabyMoodLabel': 'Umore/stato',
    'memoryBabyMoodHint': 'Es.: Felice',
    'memoryMomentInfoTitle': 'Informazioni sul momento',
    'memoryStatAgeLabel': 'Età',
    'memoryStatWeightLabel': 'Peso',
    'memoryStatHeightLabel': 'Altezza',
    'memoryStatMoodLabel': 'Com’era',
    'memoryMotherNotesLabel': 'Note della mamma',
    'memoryTipForYouTitle': 'Un consiglio per te',
    'memoryShareButton': 'Condividi',
    'memoryFavoriteButton': 'Preferito',
    'memoryFavoritedButton': 'Nei preferiti',
    'memoryEditTitle': 'Modifica ricordo',
    'memoryNewTitle': 'Nuovo ricordo',
    'memoryMomNotesFieldLabel': 'Osservazioni della mamma',
    'memorySaveChanges': 'Salva modifiche',
    'memorySaveNew': 'Salva ricordo',
    'memoryNoDescription': 'Ancora nessuna descrizione per questo momento.',
    'memoryPhotoAddTitle': 'Aggiungi una foto',
    'memoryPhotoEditTitle': 'Cambia la foto',
    'memoryTapToPickPhoto': 'Tocca',
    'memoryAgeHintExample': 'Es.: 10 giorni',
    'memoryWeightHintExample': 'Es.: 3,28',
    'memoryHeightHintExample': 'Es.: 49',
    'memorySaveNeedPhotoOrText':
        'Aggiungi una foto o scrivi una descrizione per salvare.',
    'memorySaveFail': 'Impossibile salvare:',
    'memoryShareWebOnlyMobile':
        'La condivisione di immagine o PDF è disponibile nell’app installata (Android/iOS).',
    'memoryShareSheetJpegTitle': 'Immagine (JPG)',
    'memoryShareSheetJpegSubtitle':
        'Scegli WhatsApp, email, Bluetooth… dal foglio di sistema',
    'memoryShareSheetPdfTitle': 'PDF (una pagina)',
    'memoryShareSheetPdfSubtitle': 'Comodo per email o archivio',
    'memorySharePlatformUnavailable': 'Non disponibile su questa piattaforma.',
    'memoryShareError': 'Impossibile condividere: {error}',
    'memoryFooterBranding': 'FaceBaby • Libro dei ricordi',
    'memoryTipFirstSmile':
        'Il sorriso è uno dei primi modi per creare legame. Continua a parlargli e sorridergli!',
    'memoryTipFirstLaugh':
        'La risata rafforza il legame. Ripeti i giochi che fanno ridere il bimbo.',
    'memoryTipFirstFeeding':
        'I primi giorni di allattamento sono un adattamento. Se hai dubbi, chiedi supporto al pediatra o a una consulente.',
    'memoryTipFirstSteps':
        'Ogni bimbo ha il suo ritmo. Offri uno spazio sicuro e incoraggia senza pressione.',
    'memoryTipDefault':
        'Momenti così restano per sempre nella memoria della famiglia. Continua a registrare ciò che conta.',
    'memoryAgeOneDay': '1 giorno',
    'memoryAgeManyDays': '{n} giorni',
    'memoriesTitle': 'Libro dei ricordi',
    'memoriesSubtitle': 'Momenti importanti da conservare.',
    'addMemory': 'Aggiungi ricordo',
    'memoryAddBadgeCta': 'Aggiungi badge',
    'memoryChooseBadgeTitle': 'Quale badge vuoi creare?',
    'memoryOtherBadgeTitle': 'Altro',
    'memoryOtherBadgeNameLabel': 'Nome del badge',
    'memoryOtherBadgeNameHint': 'Es: Primo costume',
    'memoryOtherBadgeNameRequired': 'Inserisci il nome del badge.',
    'memoryOtherBadgeNameTooLong': 'Usa al massimo 25 caratteri.',
    'settingsTitle': 'Altro',
    'dailyJournalTitle': 'Riepilogo giornaliero',
    'dailyJournalPickDay': 'Scegli giorno',
    'dailyJournalOnDate': 'Riepilogo del {d}',
    'dailyJournalHint': 'Scrivi qui il riepilogo della giornata…',
    'dailyJournalSave': 'Salva riepilogo',
    'dailyJournalSaving': 'Salvataggio riepilogo…',
    'dailyJournalSaved': 'Riepilogo salvato.',
    'dailyJournalNoBaby':
        'Crea/seleziona un bimbo per usare il riepilogo giornaliero.',
    'registerMotherBaby': 'Registrazione (mamma e bimbo)',
    'vaccinesCard': 'Vaccini (libretto)',
    'language': 'Lingua',
    'unitsTitle': 'Unità di misura',
    'unitsIntro':
        'Scegli come visualizzare le misure. Partiamo da un valore automatico in base alla regione del dispositivo.',
    'unitsLengthTitle': 'Unità di lunghezza',
    'unitsLengthSubtitle': 'Altezza, circonferenza e misure in generale.',
    'unitsWeightTitle': 'Unità di peso',
    'unitsWeightSubtitle': 'Peso del bimbo e registrazioni correlate.',
    'unitsLiquidTitle': 'Unità per liquidi',
    'unitsLiquidSubtitle': 'Volume (es.: biberon e altri).',
    'unitsTempTitle': 'Unità di temperatura',
    'unitsTempSubtitle': 'Temperatura corporea e ambiente.',
    'unitsOptCm': 'cm',
    'unitsOptInch': 'in',
    'unitsOptKg': 'kg',
    'unitsOptLb': 'lb',
    'unitsOptSt': 'st',
    'unitsOptMl': 'ml',
    'unitsOptUkFloz': 'uk fl oz',
    'unitsOptUsFloz': 'us fl oz',
    'unitsOptC': '°C',
    'unitsOptF': '°F',
    'authLoginTitle': 'Accedi',
    'authWelcome': 'Benvenuta',
    'authEmailLabel': 'Email',
    'authPasswordLabel': 'Password',
    'authForgotPassword': 'Password dimenticata',
    'authSignIn': 'Accedi',
    'authSigningIn': 'Accesso...',
    'authSignInGoogle': 'Accedi con Google',
    'authSignInApple': 'Accedi con Apple',
    'authSignInEmail': 'Accedi con email',
    'authAppleSignInPlaceholder':
        'L’accesso con Apple sarà configurato più avanti.',
    'authCreateAccount': 'Crea account',
    'authForgotDialogTitle': 'Password dimenticata',
    'authForgotDialogBody':
        'Ti invieremo via email un link per reimpostare la password.',
    'authForgotSend': 'Invia',
    'authResetEmailSentSnackbar': 'Email inviata. Controlla la posta.',
    'authRegisterAppBarTitle': 'Crea account',
    'authRegisterTitle': 'Registrati',
    'authRegisterNameLabel': 'Nome (come vuoi essere chiamata)',
    'authRegisterPasswordLabel': 'Password',
    'authRegisterSubmit': 'Crea account',
    'authRegisterCreating': 'Creazione...',
    'authValEmailRequired': 'Inserisci la tua email',
    'authValEmailInvalid': 'Email non valida',
    'authValPasswordRequired': 'Inserisci la password',
    'authValPasswordMin6': 'Almeno 6 caratteri',
    'authValNameRequired': 'Inserisci il tuo nome',
    'authValNameShort': 'Nome troppo corto',
    'authErrWeakPassword': 'Password debole. Usa almeno 6 caratteri.',
    'authErrInvalidEmail': 'Email non valida.',
    'authErrUserDisabled': 'Questo account è stato disattivato.',
    'authErrUserNotFound': 'Nessun account trovato per questa email.',
    'authErrWrongPassword': 'Password errata.',
    'authErrEmailInUse': 'Esiste già un account con questa email.',
    'authErrInvalidCredential': 'Credenziali non valide. Riprova.',
    'authErrCredentialsGeneric': 'Impossibile accedere. Riprova.',
    'authErrGoogleConfigAndroid':
        'Accesso Google non riuscito per configurazione dell’app (errore 10).\n\n'
            '1) Firebase: impostazioni progetto → app Android → aggiungi SHA-1 del debug keystore.\n'
            '2) Nella cartella android esegui: gradlew signingReport e copia lo SHA-1 "debug".\n'
            '3) Authentication → abilita provider Google.\n'
            '4) Scarica di nuovo google-services.json in android/app/.',
    'authErrLoginCancelled': 'Accesso annullato.',
    'authErrAppleFailed':
        'Impossibile accedere con Apple. Riprova o usa un altro metodo.',
    'authErrAppleUnavailable':
        'Accedi con Apple è disponibile solo su iPhone o iPad.',
    'authErrUnexpected': 'Qualcosa è andato storto.',
    'onbSelectDate': 'Seleziona data',
    'onbBabyFallback': 'bebè',
    'onbMomFallback': 'mamma',
    'onbDadFallback': 'papà',
    'onbWelcomeTitle': 'Accompagnando e monitorando',
    'onbWelcomeSubtitle': 'lo sviluppo con Amore.',
    'onbFeatureSleep': 'Sonno',
    'onbFeatureFeeding': 'Alimentazione',
    'onbFeatureGrowth': 'Crescita',
    'onbFeatureMemories': 'Ricordi',
    'onbFeatureAlerts': 'Avvisi',
    'onbFeatureLove': 'Tanto Amore',
    'onbCreateBabyProfile': 'Crea profilo del bebè',
    'onbExistingAccountLogin': 'Ho già un account / Accedi',
    'onbContinue': 'Continua',
    'onbPrepareFaceBaby': 'Prepara FaceBaby',
    'onbPreparingTitle': 'Stiamo preparando FaceBaby per te...',
    'onbPreparingSubtitle':
        'Personalizziamo avvisi, ricordi e routine del bebè.',
    'onbAuthTitle': 'Il profilo di base è pronto',
    'onbAuthSubtitle':
        'Ora crea il tuo account per salvare tutto in sicurezza e sincronizzare dopo.',
    'onbSignInGoogle': 'Accedi con Google',
    'onbSignInApple': 'Accedi con Apple',
    'onbContinueEmail': 'Continua con email',
    'onbAlreadyHaveAccount': 'Ho già un account',
    'onbWait': 'Attendi...',
    'onbDoneTitle': 'Fatto! Il profilo del bebè è stato creato.',
    'onbStartTracking': 'Inizia a seguire',
    'onbCouldNotPrepare':
        'Non è stato possibile preparare il profilo ora. Riprova.',
    'onbBabyNameTitle': 'Come si chiama il bebè?',
    'onbBabyNameSubtitle': 'Rendiamo FaceBaby più vicino alla tua famiglia.',
    'onbBabyNameHint': 'Nome del bebè',
    'onbBabyBirthTitle': 'Qual è la data di nascita?',
    'onbBabyBirthSubtitle':
        'Usiamo l’età per personalizzare sonno, routine e crescita.',
    'onbBabyWeightTitle': 'Qual è il peso del bebè?',
    'onbBabyWeightSubtitle':
        'Trascina il righello per scegliere. Puoi alternare tra Kg e Lb.',
    'onbBabyHeightTitle': 'Qual è l’altezza del bebè?',
    'onbBabyHeightSubtitle':
        'Usa il righello per indicare la misura approssimativa nell’unità che preferisci.',
    'onbMotherNameTitle': 'Come si chiama la mamma?',
    'onbMotherNameSubtitle': 'Useremo il suo nome nelle prossime domande.',
    'onbMotherNameHint': 'Nome della mamma',
    'onbMotherBirthTitle': 'Qual è la data di nascita della mamma?',
    'onbMotherBirthSubtitle': 'Dopo chiederemo la sua altezza.',
    'onbMotherHeightTitle': 'Qual è l’altezza di {name}?',
    'onbMotherHeightSubtitle':
        'Questa informazione aiuta nei report di crescita.',
    'onbRegisterFatherTitle': 'Vuoi registrare anche il papà?',
    'onbRegisterFatherSubtitle':
        'Se vuoi, FaceBaby personalizza anche i dati del papà.',
    'onbFatherNameTitle': 'Come si chiama il papà?',
    'onbFatherNameSubtitle': 'Così anche il suo righello sarà personalizzato.',
    'onbFatherNameHint': 'Nome del papà',
    'onbFatherBirthTitle': 'Qual è la data di nascita del papà?',
    'onbFatherBirthSubtitle': 'Dopo chiederemo la sua altezza.',
    'onbFatherHeightTitle': 'Qual è l’altezza di {name}?',
    'onbFatherHeightSubtitle':
        'Può essere approssimativa, potrai modificarla dopo.',
    'onbBabySexTitle': 'Qual è il sesso del bebè?',
    'onbSexGirl': 'Bambina',
    'onbSexBoy': 'Bambino',
    'onbSexUnknown': 'Preferisco non dirlo',
    'onbFirstBabyTitle': 'È il tuo primo bebè?',
    'onbYes': 'Sì',
    'onbNo': 'No',
    'onbConcernTitle': 'Qual è la tua preoccupazione principale ora?',
    'onbConcernSubtitle': 'Puoi sceglierne più di una.',
    'onbConcernSleep': 'Sonno del bebè',
    'onbConcernFeeding': 'Allattamento/alimentazione',
    'onbConcernGrowth': 'Peso e crescita',
    'onbConcernRoutine': 'Routine quotidiana',
    'onbConcernMemories': 'Ricordi e foto',
    'onbConcernDevelopment': 'Sviluppo',
    'onbGoalsTitle': 'Quali sono i tuoi obiettivi?',
    'onbGoalsSubtitle': 'Lo useremo per personalizzare la tua esperienza.',
    'onbGoalRoutine': 'Seguire meglio la routine',
    'onbGoalSleepAlerts': 'Ricevere avvisi sul sonno',
    'onbGoalMoments': 'Registrare momenti speciali',
    'onbGoalReports': 'Generare report',
    'onbGoalMemoryBook': 'Creare libro dei ricordi',
    'onbMessagePrefTitle': 'Mamma spiritualizzata, bebè felice.',
    'onbMessagePrefSubtitle': 'Vuoi ricevere messaggi quotidiani?',
    'onbMessagePrefChristian': 'Cristiana',
    'onbMessagePrefHoroscope': 'Astrologica',
    'onbMessagePrefPhilosophical': 'Filosofica / Ecumenica',
    'onbMessagePrefSpiritist': 'Spiritiste',
    'onbMessagePrefJewish': 'Ebraiche',
    'onbMessagePrefAll': 'Tutte',
    'onbDragToAdjust': 'Trascina per regolare',
    'onbEmailSheetTitle': 'Crea account con email',
    'onbYourNameHint': 'Il tuo nome',
    'onbEmailHint': 'Email',
    'onbPasswordHint': 'Password',
    'onbCreateAccount': 'Crea account',
    'onbValYourName': 'Inserisci il tuo nome.',
    'onbValEmailRequired': 'Inserisci la tua email.',
    'onbValEmailInvalid': 'Email non valida.',
    'onbValPasswordMin': 'Usa almeno 6 caratteri.',
    'regAppBarTitle': 'Registrazione',
    'regLetsStart': 'Iniziamo',
    'regSubtitleMandatory': 'Dati principali per personalizzare FaceBaby.',
    'regSubtitleOptional': 'Questi dati aiutano nei report e nelle stime.',
    'regStepMother': 'Mamma',
    'regStepBaby': 'Bimbo',
    'regMotherSection': 'Dati della mamma',
    'regBabySection': 'Dati del bimbo',
    'regBirthLabel': 'Data di nascita',
    'regMotherHeight': 'Altezza della mamma',
    'regFatherHeight': 'Altezza del papà',
    'fatherPhotoTitle': 'Foto del papà',
    'regFatherPhotoAdd': 'Aggiungi foto del papà',
    'regFatherPhotoChange': 'Cambia foto del papà',
    'regMotherPhotoAdd': 'Aggiungi foto della mamma',
    'regMotherPhotoChange': 'Cambia foto della mamma',
    'regBabyPhotoAdd': 'Aggiungi foto del bimbo',
    'regBabyPhotoChange': 'Cambia foto del bimbo',
    'regSaveMotherAdvance': 'Salva e continua',
    'regSaveBaby': 'Salva bimbo',
    'regSelectMotherPrompt': 'Seleziona la mamma',
    'regMotherLabel': 'Mamma',
    'regBabyGirl': 'Bimba',
    'regBabyBoy': 'Bimbo',
    'regZodiacLine': 'Segno: {sign}',
    'regBabyWeight': 'Peso del bimbo',
    'regRegisteredList': 'Registrati',
    'regNoneYet': 'Ancora nessun registro.',
    'regBabyPrompt': 'Dati del bimbo',
    'regPromptBabyName': 'Nome del bimbo di {mom}',
    'regMomGeneric': 'Mamma',
    'regMomWithName': 'Mamma {name}',
    'regListBaby': 'Bimbo: {name}',
    'regListBirth': 'Nascita: {date}',
    'regListSign': 'Segno: {sign}',
    'regListPhone': 'Telefono: {phone}',
    'regSavingMother': 'Salvataggio mamma…',
    'regSavingBaby': 'Salvataggio bimbo…',
    'regSnackMotherBirth': 'Inserisci la data di nascita della mamma.',
    'regSnackMotherOk': 'Dati della mamma salvati.',
    'regSnackSelectMother': 'Seleziona una mamma per continuare.',
    'regSnackBabyBirth': 'Inserisci la data di nascita del bimbo.',
    'regSnackPickMother': 'Scegli prima la mamma.',
    'regSnackBabyOk': 'Dati del bimbo salvati.',
    'valNameEmpty': 'Inserisci il nome.',
    'valNameShort': 'Nome troppo corto.',
    'valPhoneEmpty': 'Inserisci il telefono.',
    'valPhoneInvalid': 'Telefono non valido.',
    'valHeightEmpty': 'Inserisci l’altezza.',
    'valHeightInvalid': 'Altezza non valida.',
    'valHeightMotherRange': 'Controlla l’altezza della mamma.',
    'valFatherHeightEmpty': 'Inserisci l’altezza del papà.',
    'valWeightEmpty': 'Inserisci il peso.',
    'valWeightInvalid': 'Peso non valido.',
    'valWeightRange': 'Controlla il peso inserito.',
    'valBabyHeightRange': 'Controlla l’altezza del bimbo.',
    'placeholderBabyName': 'Nome del bimbo',
    'termsLoadError': 'Impossibile caricare i termini.',
    'settingsInviteShareText':
        'Prova FaceBaby — routine e ricordi del bimbo in un unico posto.\nhttps://play.google.com/store/apps/details?id=com.facebaby.app',
    'settingsPremiumBenefitsTitle': 'Vantaggi FaceBaby Premium',
    'settingsPremiumBannerHint':
        'Tocca per vedere cosa è incluso nel tuo piano.',
    'settingsRateCouldNotOpen':
        'Impossibile aprire lo store. Riprova più tardi.',
    'settingsMotherProfile': 'Il mio profilo',
    'profileEditMother': 'Modifica dati della mamma',
    'profileEditFather': 'Modifica dati del papà',
    'profileAddFather': 'Registra papà',
    'profileFatherNotRegisteredTitle': 'Papà non ancora registrato',
    'profileFatherNotRegisteredSubtitle':
        'Se non hai incluso il papà al primo accesso, puoi aggiungere i suoi dati qui in qualsiasi momento.',
    'profileFatherAddCta': 'Registra papà ora',
    'profileEditBaby': 'Modifica dati del bimbo',
    'profileDataSaved': 'Salvato.',
    'profileEditData': 'Modifica dati',
    'settingsBabyData': 'Dati del bimbo',
    'settingsAlerts': 'Avvisi',
    'settingsPrivacy': 'Privacy',
    'settingsSaaS': 'Piano SaaS futuro',
    'contactTitle': 'Contatto',
    'contactIntro':
        'Invia un messaggio via email. Apriremo la tua app email con i campi già compilati.',
    'contactFieldName': 'Nome',
    'contactFieldEmail': 'Email',
    'contactFieldAge': 'Età',
    'contactFieldMessage': 'Messaggio',
    'contactSend': 'Invia',
    'contactEmailSubject': 'Contatto app',
    'contactBodyName': 'Nome:',
    'contactBodyEmail': 'Email:',
    'contactBodyAge': 'Età:',
    'contactBodyMessage': 'Messaggio:',
    'contactCouldNotOpenEmail': 'Impossibile aprire l’app email.',
    'contactValidationRequired': 'Campo obbligatorio.',
    'contactValidationEmail': 'Inserisci un’email valida.',
    'contactValidationAge': 'Inserisci un’età valida.',
    'motherProfileTabPreferences': 'Preferenze',
    'motherProfileTabMother': 'Mamma',
    'motherProfileTabFather': 'Papà',
    'motherProfileTabBabies': 'Bimbi',
    'profileLayoutTitle': 'Layout dell’app',
    'profileLayoutSubtitle':
        'Modalità giorno, notte o automatica in base all’orario.',
    'profileLayoutAutomatic': 'Automatico',
    'profileLayoutDay': 'Giorno',
    'profileLayoutNight': 'Notte',
    'profileLayoutUpdating': 'Aggiornamento layout…',
    'motherProfileFieldFatherName': 'Nome',
    'motherProfileNoData': 'Nessun profilo trovato. Riprova tra poco.',
    'motherProfileSectionInfo': 'Info',
    'motherProfileFieldPhone': 'Telefono',
    'motherProfileFieldBirth': 'Data di nascita',
    'motherProfileFieldHeight': 'Altezza',
    'motherProfileFieldFatherHeight': 'Altezza del papà',
    'profileFamilyMessagesTitle': 'Messaggi nella schermata Famiglia',
    'profileShowChristian': 'Cristiana',
    'profileShowHoroscope': 'Astrologica',
    'profileShowPhilosophical': 'Filosofica / Ecumenica',
    'profileShowSpiritist': 'Messaggi spiritisti',
    'profileShowJewish': 'Messaggi ebraici',
    'motherProfileAddBaby': 'Aggiungi un altro bimbo',
    'motherProfileNoBabies': 'Nessun bimbo trovato per questo profilo.',
    'motherProfileBabyBornAt': 'Nato il: {date}',
    'settingsSoonTitle': 'In arrivo',
    'settingsSoonBadge': 'Presto',
    'settingsRateUs': 'Valutaci',
    'settingsVersion': 'Versione',
    'settingsVersionDialogTitle': 'Versione dell’app',
    'settingsVersionCopy': 'Copia',
    'settingsVersionCopied': 'Informazioni versione copiate',
    'settingsTermsOfUse': "Termini d'uso",
    'settingsPrivacyPolicy': 'Informativa sulla privacy',
    'settingsSpecialThanks': 'Ringraziamenti speciali',
    'settingsTellFriend': 'Dillo a un amico',
    'vaccinesTitle': 'Vaccini',
    'vaccinesSubtitle': 'Aggiungi vaccini, date e prossime dosi.',
    'baby': 'Bimbo',
    'selectBaby': 'Seleziona bimbo',
    'addVaccine': 'Aggiungi vaccino',
    'recordsTitle': 'Registri',
    'noVaccinesYet': 'Nessun vaccino ancora.',
    'seeAll': 'Vedi tutto',
    'changePhoto': 'Cambia foto',
    'motherPhotoTitle': 'Foto della mamma',
    'babyPhotoTitle': 'Foto del bimbo',
    'familyTitle': 'Famiglia',
    'familySubtitle': 'Albero familiare, segni e messaggi del giorno.',
    'familyEdit': 'Modifica',
    'familyEditData': 'Modifica dati >',
    'familyTabMotherLabel': 'Mamma',
    'familyTabFatherLabel': 'Papà',
    'familyRoleMother': 'Mamma',
    'familyRoleFather': 'Papà',
    'familyRoleBaby': 'Bebè',
    'familyZodiacSolar': 'Segno solare',
    'familyEntertainmentNote':
        'Completa i dati di nascita per personalizzare questo contenuto.',
    'familyChristianCardTitle': 'Messaggio biblico',
    'familySpiritistCardTitle': 'Messaggio spiritista',
    'familyJewishCardTitle': 'Messaggio ebraico',
    'familyChristianLine': 'Versetto del giorno · {ref}',
    'familyBornOn': 'Nato/a il {date}',
    'familyAgeOneYear': '1 anno',
    'familyAgeYears': '{n} anni',
    'familyHeight': '{value}',
    'familyMotherBlurb':
        'Come mamma {sign}, può mostrare tratti come {traits}.',
    'familyFatherBlurb': 'Come papà {sign}, può mostrare tratti come {traits}.',
    'familyBabyBlurb': 'Come bebè {sign}, può mostrare tratti come {traits}.',
    'familyZodiacName_capricorn': 'Capricorno',
    'familyZodiacName_aquarius': 'Acquario',
    'familyZodiacName_pisces': 'Pesci',
    'familyZodiacName_aries': 'Ariete',
    'familyZodiacName_taurus': 'Toro',
    'familyZodiacName_gemini': 'Gemelli',
    'familyZodiacName_cancer': 'Cancro',
    'familyZodiacName_leo': 'Leone',
    'familyZodiacName_virgo': 'Vergine',
    'familyZodiacName_libra': 'Bilancia',
    'familyZodiacName_scorpio': 'Scorpione',
    'familyZodiacName_sagittarius': 'Sagittario',
    'familyZodiacTrait_capricorn': 'disciplinato e responsabile',
    'familyZodiacTrait_aquarius': 'curioso e indipendente',
    'familyZodiacTrait_pisces': 'sensibile e fantasioso',
    'familyZodiacTrait_aries': 'coraggioso e pieno di energia',
    'familyZodiacTrait_taurus': 'tranquillo e affettuoso',
    'familyZodiacTrait_gemini': 'comunicativo e curioso',
    'familyZodiacTrait_cancer': 'affettuoso e protettivo',
    'familyZodiacTrait_leo': 'allegro ed espressivo',
    'familyZodiacTrait_virgo': 'osservatore e attento',
    'familyZodiacTrait_libra': 'dolce e socievole',
    'familyZodiacTrait_scorpio': 'intenso e affettuoso',
    'familyZodiacTrait_sagittarius': 'allegro ed esploratore',
    'familyFatherDataComplete': 'Dati del papà completi e aggiornati',
    'familyFatherDataIncomplete': 'Dati del papà ancora incompleti',
    'familyAddFatherPrompt':
        'Vuoi aggiungere i dati del papà? Completali per vedere l’altezza stimata del tuo bebè.',
    'familyAddFatherButton': 'Aggiungi dati del papà',
    'familyCompleteBabySex':
        'Indica il sesso del bebè nel profilo per calcolare l’altezza stimata.',
    'familyEditBabyData': 'Modifica dati del bebè',
    'familyCompleteHeights':
        'Per la stima abbiamo bisogno dell’altezza di mamma e papà.',
    'familyCompleteHeightsButton': 'Completa altezze',
    'familyEstimatedHeightTitle': 'Altezza stimata di {name}',
    'familyMotherHeightLabel': 'Altezza della mamma',
    'familyFatherHeightLabel': 'Altezza del papà',
    'familyEstimatedGirl': 'Altezza stimata per femmina',
    'familyEstimatedBoy': 'Altezza stimata per maschio',
    'familyEstimatedResult': 'circa {cm}',
    'familyHowCalculated': 'Come viene calcolata?',
    'familyFormulaBoy': 'Maschio: (altezza padre + altezza madre + 13) ÷ 2',
    'familyFormulaGirl': 'Femmina: (altezza padre + altezza madre − 13) ÷ 2',
    'familyEstimatedHeightDescription':
        'Stima basata sull\u2019altezza dei genitori e sul sesso del bebè. Non considera fattori ambientali, nutrizionali, di salute o altri. Solo come riferimento orientativo.',
    'familyFormulaExampleGirl': '({father} + {mother} − 13) ÷ 2 = {result} cm',
    'familyFormulaExampleBoy': '({father} + {mother} + 13) ÷ 2 = {result} cm',
    'familyHeightDisclaimer':
        'È una stima semplice usata come riferimento pediatrico. L’altezza finale può variare per genetica, alimentazione, sonno, salute, pubertà e altri fattori.',
    'familyZodiacReadMore': 'Leggi il testo completo',
    'familyPremiumZodiacLocked':
        'Segni solari e testi personalizzati sono esclusivi di FaceBaby Premium.',
    'familyPremiumHeightLocked':
        'L’altezza adulta stimata è esclusiva di FaceBaby Premium.',
    'familyPremiumUnlockCta': 'Sblocca Premium',
    'familyScreenTitle': 'Famiglia 💜',
    'familyPersonalInfoTitle': 'Informazioni personali',
    'familyHoroscopeCardTitle': 'Oroscopo di {sign}',
    'familyBibleVerseCardTitle': 'Versetto biblico di oggi.',
    'familyDailySummaryTitle': 'Riepilogo del giorno',
    'familySummaryFeeding': 'Poppate',
    'familySummaryDiapers': 'Pannolini',
    'familySummarySleep': 'Sonno',
    'familySummaryWeight': 'Peso',
    'familyQuickLabelBirth': 'Nato/a',
    'familyQuickLabelTime': 'Ora',
    'familySummaryFeedingsToday': '{n} poppate',
    'familySummaryDiaperChangesCount': '{n} cambi',
    'familySummaryLastAt': 'Ultima alle {time}',
    'familySummaryLastSleepAt': 'Ultimo alle {time}',
    'familySummaryWeightDayLine': 'Giorno selezionato',
    'familyFieldBirthDate': 'Nascita',
    'familyFieldSign': 'Segno',
    'familyFieldElement': 'Elemento',
    'familyFieldAge': 'Età',
    'familyFieldHeight': 'Altezza',
    'familyFieldWeight': 'Peso',
    'familyPremiumShortBadge': 'Premium',
    'familyPremiumFeatureLockedBody':
        'Contenuto esclusivo per famiglie Premium.',
    'familyPremiumBannerTitle': 'Sblocca contenuti Premium',
    'familyPremiumBannerBody':
        'Accedi alle descrizioni dei segni, all’altezza stimata e ai contenuti personalizzati.',
    'familyPremiumViewPlans': 'Vedi piani',
    'familyAddFatherCardTitle': 'Aggiungi papà',
    'familyElementFire': 'Fuoco',
    'familyElementEarth': 'Terra',
    'familyElementAir': 'Aria',
    'familyElementWater': 'Acqua',
    'familyTapToOpen': 'Tocca per vedere i dettagli',
    'familyCarouselSwipe': 'Scorri per cambiare familiare',
    'familyTabNene': 'Bebè',
    'familyTabsHint': 'Tocca una foto per cambiare familiare',
    'familyTapToClose': 'Tocca per chiudere',
    'familyShareCard': 'Condividi scheda',
    'changeBabyTooltip': 'Cambia bimbo',
    'notificationsInboxTitle': 'Notifiche',
    'notificationsInboxSubtitle':
        'Ultimi 3 giorni (inviate e programmate, registrate nell’app)',
    'notificationsEmpty': 'Nessuna notifica registrata in questo periodo.',
    'notificationsKindShown': 'Inviata',
    'notificationsKindScheduled': 'Programmata',
    'notificationsOpenTarget': 'Tocca per aprire',
    'notificationsSelectAll': 'Seleziona tutto',
    'deleteAccountTitle': 'Elimina account',
    'deleteAccountBody':
        'Questo eliminerà il tuo account e TUTTI i dati (mamma, bimbo e registri) dal cloud.\n\nQuesta azione non può essere annullata.',
    'deleteAccountConfirm': 'Elimina tutto',
    'deleteAccountDeleting': 'Eliminazione account...',
    'deleteAccountSuccess': 'Account eliminato correttamente.',
    'deleteAccountReauthTitle': 'Conferma password o Google',
    'deleteAccountReauthBody':
        'Ultimo passo prima dell’eliminazione: conferma lo stesso metodo di accesso (password e-mail o account Google/Gmail).',
    'deleteAccountReauthGoogleSection': 'Accesso con Google / Gmail',
    'deleteAccountReauthGoogleAccountHint': 'Account Google: {email}',
    'deleteAccountReauthPasswordSection': 'Accesso con e-mail e password',
    'deleteAccountReauthOrDivider': 'oppure',
    'deleteAccountReauthEmailLabel': 'E-mail dell’account',
    'deleteAccountReauthPasswordHint': 'Password attuale',
    'deleteAccountReauthPasswordRequired':
        'Inserisci la password attuale dell’account.',
    'deleteAccountReauthGoogle': 'Conferma con Google (Gmail)',
    'deleteAccountReauthContinue': 'Conferma con password',
    'deleteAccountReauthCantPassword':
        'Usa il pulsante dello stesso metodo di accesso (Google/Gmail o e-mail e password) usato alla creazione dell’account.',
    'deleteAccountTypeWordTitle': 'Conferma finale',
    'deleteAccountTypeWordInstruction':
        'Per eliminare definitivamente l’account, digita delete nel campo. Poi chiederemo conferma con password o Google (Gmail).',
    'deleteAccountTypeWordFieldLabel': 'elimina',
    'homeBabyBannerForecastSleep': 'Previsione sonno',
    'homeBabyBannerForecastWake': 'Previsione risveglio',
    'homeBabyBannerForecastSubtitleSleep':
        'Segnali di sonno rilevati\nin base all’ora attuale',
    'homeBabyBannerForecastSubtitleWake':
        'In base all’ora attuale e al modello per età',
    'homeBabyBannerEtaIn': 'tra {d}',
    'homeBabyBannerLastDiaper': 'Ultimo pannolino',
    'homeBabyBannerNoRecordsYet': 'Nessun registro',
    'homeBabyBannerNextBetween': 'Prossimo tra {range}',
    'homeBabyBannerDiaperRecommendedUntil': 'Cambio consigliato entro {d}',
    'homeBabyBannerIdealWindow': 'Finestra ideale: {range}',
    'homeConsultationScheduled': 'Visita programmata',
    'homeBannerChipConsultation': 'Visita',
    'homeBannerChipDiaper': 'Pannolino',
    'homeBannerChipFeed': 'Poppata',
    'homeBannerChipSleep': 'Sonno',
    'homeBannerOverdueSleep': 'È passata l’ora di dormire',
    'homeBannerOverdueWake': 'È passata l’ora di svegliarsi',
    'homeBannerHungry': 'Potrebbe avere fame',
    'homeBannerDiaperDirty': 'Potrebbe essere sporco',
    'homeBannerExhausted': 'STANCO',
    'helloMomNamed': 'Ciao, Mamma {name}!',
    'registerVerb': 'Registra',
    'viewCalendar': 'Vedi calendario',
    'shortcutMilk': 'Poppata',
    'shortcutSleep': 'Sonno',
    'shortcutVaccines': 'Vaccini',
    'shortcutFamily': 'Famiglia',
    'shortcutFamilyHomeSub': 'Albero e profilo familiare',
    'shortcutHealthHomeSub': 'Vaccini, visite e sintomi',
    'homeFedAgo': 'Ha mangiato {when} fa',
    'homePeeAgo': 'Pipi {when} fa',
    'homePooAgo': 'Pupù {when} fa',
    'homeNextNow': 'Prossima: ora.',
    'homeNextIn': 'Tra {n} min.',
    'homeStatusOk': 'Tutto ok',
    'homeStatusWarn': 'Attenzione',
    'homeStatusHungry': 'Potrebbe avere fame',
    'homeTimeToFeed': 'È ora della poppata!',
    'homeStatusDetailFed': 'Poppata recente',
    'homeStatusDetailNear': 'Vicino all’ora della poppata',
    'homeStatusDetailLate': 'È passato un po’ di tempo',
    'homePickDayLabel': 'Giorno del riepilogo',
    'homeTodayLabel': 'Oggi',
    'homeYesterdayLabel': 'Ieri',
    'homeSummaryOnDate': 'Riepilogo — {date}',
    'homeSummaryPickDayTooltip': 'Scegli il giorno del riepilogo',
    'homeFedAt': 'Poppata alle {time}',
    'homePeeAt': 'Pipì alle {time}',
    'homePooAt': 'Pupù alle {time}',
    'homeDiaperChangeAgo': 'Cambio pannolino {when} fa',
    'homeDiaperChangeAt': 'Cambio pannolino alle {time}',
    'homeSleepEndedAgo': 'Ultimo sonno {when} fa',
    'homeSleepEndedAt': 'Ultimo sonno alle {time}',
    'homeSleepInProgress': 'Dorme · {elapsed}',
    'homeSleepPausedBanner': 'Sonno in pausa · {elapsed}',
    'sleepBannerEmpty': 'Nessun registro di sonno ancora.',
    'homePastDayBadge': 'Giorno passato',
    'homePastDayDetail': 'Orari registrati in questo giorno',
    'homeBannerAlertCheckDiaper': 'Controlla pannolino',
    'homeBannerAlertTimeToSleep': 'È ora di dormire',
    'homeBannerAlertSleepingLong': 'Sta dormendo da molto',
    'homeCriticalCareTitle': 'Cure che richiedono attenzione',
    'homeCriticalCareCount': '{n} attenzioni richiedono controllo',
    'homeCriticalFeedingTitle': 'Potrebbe essere ora di mangiare',
    'homeCriticalSleepTitle': 'Potrebbe essere ora di dormire',
    'homeCriticalDiaperTitle': 'Potrebbe essere ora di cambiare il pannolino',
    'homeCriticalFeedingSubtitle':
        'Potrebbe essere passato il tempo previsto dall’ultima poppata.',
    'homeCriticalSleepSubtitle':
        'La finestra di veglia potrebbe essere stata superata.',
    'homeCriticalWakeTitle': 'Oltre l\'ora di sveglia',
    'homeCriticalWakeSubtitle':
        'La sessione di sonno potrebbe aver superato la durata consigliata.',
    'homeCriticalDiaperSubtitle':
        'Potrebbe essere passato un po’ dall’ultimo cambio.',
    'homeSleepBarAwakeTitle': 'Sveglio · finestra fino al sonno',
    'homeSleepBarSleepTitle': 'Dorme · durata sessione',
    'homeFeedingCounterTitle': 'Poppata · tempo al prossimo intervallo',
    'homeFeedingCounterHint':
        'Conto alla rovescia (intervallo nei registri rapidi)',
    'homeSleepBarAwakeHintEarly': '≈ {m} min fino alla finestra ideale',
    'homeSleepBarAwakeHintIdeal': '≈ {m} min fino alla fine della finestra',
    'homeSleepBarAwakeHintOverdue': 'Finestra superata · valuta il sonno',
    'homeSleepBarSleepHint':
        '{remaining} restanti · limite sessione ~{cap} min',
    'homeSleepBarNeedLastSleep': 'Registra l’ultimo sonno per vedere la barra',
    'homeTipTitle': 'Suggerimento di oggi',
    'homeTipBody': 'Routine leggere aiutano {name} a dormire meglio la notte.',
    'homeYesterdayBabaTitle': 'IA Tata · ieri',
    'homeYesterdayBabaFallback':
        'Registra la routine di {name} per una lettura pediatrica.',
    'homeYesterdayBabaRoutineQuiet':
        'Pochi registri — routine prevedibili favoriscono la regolazione emotiva.',
    'homeYesterdayBabaRoutine':
        '{feeds} poppate · sonno {sleep} · {diapers} pannolini.',
    'homeYesterdayBabaRoutineLowSleep':
        '{feeds} poppate · sonno {sleep} (basso) · {diapers} pannolini.',
    'homeYesterdayBabaGrowthBothWithin':
        'Peso e statura sulla curva di riferimento.',
    'homeYesterdayBabaGrowthNoData': 'Aggiorna peso/statura nella curva.',
    'homeYesterdayBabaGrowthBelow':
        'Antropometria sotto la curva — parlane con il pediatra.',
    'homeYesterdayBabaGrowthAbove':
        'Antropometria sopra la curva — verifica in visita.',
    'homeYesterdayBabaGrowthCombo': 'Curva: peso {weight}, statura {height}.',
    'homeYesterdayBabaBandWithin': 'adeguato',
    'homeYesterdayBabaBandBelow': 'sotto',
    'homeYesterdayBabaBandAbove': 'sopra',
    'homeYesterdayBabaBandUnknown': '—',
    'homeGreetingSubtitle': 'Che bello vederti qui oggi!',
    'summaryWeightNotYet': 'Non ancora registrato',
    'summarySleepNotYet': 'Nessun sonno registrato oggi',
    'shortcutMilkHomeSub': 'Registra una poppata',
    'shortcutGrowthHomeSub': 'Registra peso e altezza',
    'shortcutSleepHomeSub': 'Registra sonno',
    'homeTileDiapers': 'Cambi pannolino',
    'homeOneDayOld': '1 giorno',
    'homeDaysOld': '{d} giorni',
    'babyAgeOneWeek': '1 settimana',
    'babyAgeWeeks': '{n} settimane',
    'babyAgeOneMonth': '1 mese',
    'babyAgeMonths': '{n} mesi',
    'babyAgeOneYear': '1 anno',
    'babyAgeYears': '{n} anni',
    'summaryFeedings': 'POPPIATE',
    'summarySleep': 'SONNO TOTALE',
    'summaryLastFeed': 'Ultima alle {time}',
    'summaryLastSleep': 'Ultimo alle {time}',
    'summaryDiapers': 'PANNOLINI',
    'summaryFeedingsValue': '{n} · {m} min',
    'summaryFeedingsCountOne': '1 poppata',
    'summaryFeedingsCountMany': '{n} poppate',
    'summaryFeedingsMinutes': '{m} min',
    'summaryDiapersValue': 'Totale {total} · Pipì {pee} · Pupù {poo}',
    'summaryDiapersTotal': 'Totale {total} cambi',
    'summaryDiapersChangesOne': '1 cambio',
    'summaryDiapersChangesMany': '{n} cambi',
    'summaryDiapersPeePoo': '{pee} - Pipì    {poo} - Pupù',
    'summarySleepValue': '{s} · {t}',
    'summarySleepSessionsOne': '1 pisolino',
    'summarySleepSessionsMany': '{s} pisolini',
    'summaryWeight': 'PESO',
    'homeSummaryExtraHint': 'Totali del giorno selezionato',
    'add': 'Aggiungi',
    'labelWeight': 'Peso',
    'labelHeight': 'Altezza',
    'labelHead': 'Circonferenza testa',
    'growthTabWeight': 'Peso',
    'growthTabHeight': 'Altezza',
    'growthTabHead': 'Testa',
    'growthTabSummary': 'Riepilogo',
    'growthAtBirth': 'Alla nascita',
    'growthCardCurrent': 'Attuale',
    'growthCardChange': 'Variazione',
    'growthAddWeight': 'Aggiungi peso',
    'growthAddHeight': 'Aggiungi altezza',
    'growthAddHead': 'Aggiungi testa',
    'growthSummaryIntro': 'Panoramica di peso e altezza.',
    'growthChartCaption': '{name} — {metric}',
    'growthChartDeltaHint':
        'Asse verticale: variazione rispetto al valore alla nascita (0 = nascita).',
    'growthHistoryTitle': '{label} (storico)',
    'invalidGrowthValue': 'Inserisci un valore valido per {label}.',
    'growthSaved': '{label} salvato correttamente.',
    'growthEmpty': 'Nessun registro di {label} ancora.',
    'notifyGrowthWeightDownTitle': 'Peso più basso del precedente',
    'notifyGrowthWeightDownBody':
        'L’ultimo peso registrato è inferiore al precedente. In caso di dubbio, contatta il pediatra.',
    'notifyGrowthStaleTitle': 'Nessuna misura di crescita da un po’',
    'notifyGrowthStaleBody':
        'Sono passati più di 30 giorni dall’ultima misurazione di crescita (peso, altezza o testa). Sono passati {days} giorni — aggiungi una nuova registrazione.',
    'momNoteHint': 'Es.: ha dormito meglio dopo il bagnetto...',
    'shortcutDiaper': 'Pannolino',
    'diaperPagePlaceholder':
        'Presto potrai registrare i cambi pannolino. Questa sezione è in arrivo.',
    'shortcutHealth': 'Salute',
    'shortcutHealthSubtitle': 'Vaccini e visite',
    'shortcutFeedingSession': 'Alimentazione',
    'shortcutFeedingSessionSub': 'Poppate e pasti',
    'vaccineReminderNotifTitle': 'Vaccino',
    'vaccineReminderNotifBody': 'Vaccino previsto oggi: {name}.',
    'healthHubConsultations': 'Visite',
    'healthHubConsultationsSub': 'Pediatra e controlli',
    'consultationsTitle': 'Visite',
    'consultationsIntro':
        'Registra visite con data e ora; appariranno nel riepilogo del giorno in Home.',
    'consultationsSoonTitle': 'In arrivo',
    'consultationsComingBody':
        'Presto potrai registrare visite, allegare note e promemoria di ritorno.',
    'consultationTitleLabel': 'Motivo o specialità',
    'consultationNotesHint': 'Note (opzionale)',
    'consultationWhenLabel': 'Data e ora',
    'consultationTitleEmpty':
        'Inserisci il motivo o la specialità della visita.',
    'consultationPhoneLabel': 'Telefono della clinica',
    'consultationAddressLabel': 'Indirizzo',
    'consultationDetailWhen': 'Quando',
    'consultationDetailPhone': 'Telefono',
    'consultationDetailAddress': 'Indirizzo',
    'consultationDetailNotes': 'Note',
    'consultationReminderNotifTitle': 'Visita in arrivo',
    'consultationReminderNotifBody': 'Domani · {title} · {when}',
    'consultationTodayReminderNotifBody': 'Oggi · {title} · {when}',
    'homeConsultationBannerChip': 'Visita · {title} · {t}',
    'consultationsEmpty': 'Nessuna visita registrata.',
    'consultationsDayEmpty': 'Nessuna visita in questo giorno.',
    'feedingSessionTitle': 'Sessione di alimentazione',
    'feedingSessionIntro':
        'La scorciatoia in Home appare dai 7 mesi o se la attivi in Altro.',
    'feedingSessionSoonTitle': 'Prossimi passi',
    'feedingSessionSoonBody':
        'Idee per pasti, foto e riepiloghi giornalieri saranno qui. Per ora usa Registri e il piano del pediatra.',
    'settingsFeedingEarlyTitle': 'Scorciatoia solidi prima dei 7 mesi',
    'settingsFeedingEarlySub':
        'Mostra la scorciatoia “Solidi” in Home anche se il bimbo ha meno di 7 mesi.',
    'settingsAiMicTitle': 'Assistente vocale (microfono)',
    'settingsAiMicSub':
        'Mostra il pulsante del microfono in Home (in lavorazione).',
    'reportNoWeight': 'Ancora nessun dato di peso.',
    'reportNoHeight': 'Ancora nessun dato di altezza.',
    'reportDailyScreenTitle': 'Report giornaliero',
    'reportDayDetailsTitle': 'Dettagli del giorno',
    'reportDailyPickDayTooltip': 'Scegli giorno',
    'reportDailySubtitleSleepQuality': 'Qualità del sonno',
    'reportDailySubtitleTotalSleep': 'Sonno totale',
    'reportDailySubtitleLongestStretch': 'Periodo continuo più lungo',
    'reportDailySubtitleFeedTotal': 'Totale poppate',
    'reportDailySubtitleFeedAvg': 'Durata media',
    'reportDailySubtitleFeedLast': 'Ultima poppata',
    'reportDailySubtitleDiaperTotal': 'Totale cambi',
    'reportDailySubtitleDiaperWet': 'Pannolini bagnati',
    'reportDailySubtitleDiaperDirty': 'Pannolini sporchi',
    'reportDailySubtitleMoodMajority': 'La maggior parte del giorno',
    'reportDailySubtitleMoodIrrit': 'Irritabilità',
    'reportDailySubtitleWeightLast': 'Ultima misurazione',
    'reportSleepQualityGood': 'Buona',
    'reportSleepQualityOk': 'Ok',
    'reportSleepQualityBad': 'Fragile',
    'reportSleepQualityMixed': 'Variabile',
    'reportVsYesterdayShort': 'vs ieri',
    'reportVsYesterdayNA': '—',
    'reportVsYesterdayPct': '{pct}%',
    'reportLongestStretchHint': '{start} – {end}',
    'reportNapsLabel': 'Pisolini',
    'reportTotalSmallLabel': 'Totale',
    'reportComparedAgeLabel': 'Confrontato con la media per età',
    'reportBenchmarkAbove': 'Sopra la media',
    'reportBenchmarkNear': 'Vicino alla media',
    'reportBenchmarkBelow': 'Sotto la media',
    'reportIrritLow': 'Bassa',
    'reportIrritMedium': 'Moderata',
    'reportIrritHigh': 'Alta',
    'reportIrritUnknown': 'Nessun dato',
    'reportTabSleep': 'Sonno',
    'reportTabFeedings': 'Poppate',
    'reportTabDiapers': 'Pannolini',
    'reportTabMood': 'Umore',
    'reportAiInsightsTitle': 'Insight',
    'reportTimelineTitle': 'Timeline del giorno',
    'reportShareSoon': 'Condividi (presto)',
    'reportFeedingChartCaption': 'Poppate per ora',
    'reportSleepChartCaption': 'Sonno per ora',
    'reportNoDataHint': 'Dati insufficienti per questa metrica.',
    'reportInsightSleepAgeGood':
        'Il sonno totale è vicino a quanto tipico per l’età — buon segno di riposo.',
    'reportInsightSleepAgeLow':
        'Il sonno è sotto il range abituale per questa età; osserva segnali di stanchezza e routine serale.',
    'reportInsightFeedsOften':
        'Molte poppate durante il giorno — comune nelle fasi di crescita; registrare la durata aiuta a vedere le medie.',
    'reportInsightDiapersFrequent':
        'Cambi pannolino frequenti — idratazione probabilmente buona o pelle da controllare.',
    'reportInsightMoodLine': 'Umore predominante nei ricordi: {mood}.',
    'reportWeeklyScreenTitle': 'Report settimanale',
    'reportWeekDetailsTitle': 'Dettagli della settimana',
    'reportWeeklyPickWeekTooltip': 'Scegli settimana (qualsiasi giorno)',
    'reportWeeklySummaryTitle': 'Riepilogo della settimana',
    'reportWeeklyTrendsTitle': 'Tendenze',
    'reportWeeklySeeFullDetails': 'Vedi report completo',
    'reportWeeklyPartialWeekHint':
        'Medie e tendenze: da lunedì a {weekday} (settimana in corso).',
    'reportWeeklyFutureWeekHint':
        'Questa settimana non è ancora iniziata nel calendario — scegli un’altra settimana.',
    'reportWeeklyLoadErrorPrefix': 'Impossibile caricare il report:',
    'reportWeeklyToneCalm': 'tranquilla',
    'reportWeeklyToneActive': 'movimentata',
    'reportWeeklySleepUnknown':
        'Dati di sonno insufficienti per confrontare le settimane.',
    'reportWeeklyFirstWeekSleepLine':
        'Questa è la prima settimana con registrazioni: continua ad annotare per vedere le tendenze.',
    'reportWeeklySleepStableShort':
        'Il sonno è rimasto stabile rispetto alla settimana precedente.',
    'reportWeeklySleepUp':
        'Il sonno è migliorato di circa {pct}% rispetto alla settimana precedente.',
    'reportWeeklySleepDown':
        'Il sonno è calato di circa {pct}% rispetto alla settimana precedente.',
    'reportWeeklyFeedStableLine': 'Le poppate sono rimaste regolari.',
    'reportWeeklyFeedUp':
        'Le poppate giornaliere sono aumentate di circa {pct}% in media.',
    'reportWeeklyFeedDown':
        'Le poppate giornaliere sono diminuite di circa {pct}% in media.',
    'reportWeeklyHeroTemplate':
        '{name} ha avuto una settimana {tone}! {sleep} {feed}',
    'reportWeeklyTrendLabelImproved': 'Migliorato',
    'reportWeeklyTrendLabelWorse': 'Peggiorato',
    'reportWeeklyTrendLabelStable': 'Stabile',
    'reportWeeklyTrendLabelUnknown': '—',
    'reportWeeklyTrendLabelEvolving': 'In evoluzione',
    'reportWeeklyTrendLabelIncreased': 'Aumentato',
    'reportWeeklyTrendNA': '—',
    'reportWeeklyHighlightSleep':
        'Aspetto positivo: sonno più riposante questa settimana.',
    'reportWeeklyHighlightFeedingStable':
        'Aspetto positivo: ritmo di alimentazione stabile.',
    'reportWeeklyHighlightDiaperUp':
        'Nota: più cambi — idratazione o digestione più attiva.',
    'reportWeeklyHighlightWeight': 'Aspetto positivo: aumento di peso sano.',
    'reportWeeklyHighlightGeneric':
        'Continua a registrare per tendenze più chiare.',
    'reportWeeklyAvgFeedsDay': 'Media giornaliera: {avg} poppate.',
    'reportWeeklyAvgDiapersDay': 'Media giornaliera: {avg} cambi.',
    'reportWeeklySleepHoursChartTitle': 'Ore di sonno al giorno',
    'reportWeeklyAvgWeekLabel': 'Media settimanale',
    'reportWeeklyVsPrevWeekShort': 'vs settimana precedente',
    'reportWeeklyInsightsCardTitle': 'Insight IA',
    'reportWeeklyPatternsTitle': 'Pattern rilevati',
    'reportWeeklySeeAllAnalyses': 'Vedi tutte le analisi',
    'reportWeeklyHeatmapSoon': 'Mappa oraria disponibile presto.',
    'reportWeeklyFeedChartCaption': 'Poppate al giorno',
    'reportWeeklyDiaperChartCaption': 'Cambi al giorno',
    'reportWeeklyPatternWeekend':
        'Nel weekend il sonno tende ad allungarsi un po’.',
    'reportWeeklyPatternFeedingDown':
        'Meno poppate in media — comune quando gli intervalli si allungano.',
    'reportWeeklyPatternDefault':
        'Il pattern settimanale sembra stabile — adatta la routine al ritmo del bimbo.',
    'reportWeeklyInsightSleepNeutral':
        'Il sonno è stato simile alla settimana precedente.',
    'reportWeeklyInsightSleepBetter':
        'Più sonno rispetto alla settimana scorsa — buon segno.',
    'reportWeeklyInsightSleepLess':
        'Il sonno totale è calato rispetto alla settimana precedente — da osservare.',
    'reportWeeklyInsightTemplate': '{name}: {sleep}',
    'reportMonthlyScreenTitle': 'Report mensile',
    'reportMonthlyAvgWeight': 'Peso medio',
    'reportMonthlyAvgHeight': 'Altezza media',
    'reportMonthlyGrowthChartEmpty':
        'Aggiungi almeno due registrazioni di peso questo mese per vedere il grafico.',
    'reportMonthlySleepSection': 'Sonno',
    'reportMonthlySleepAvg': 'Media mensile (al giorno)',
    'reportMonthlyVsPrevMonth': 'vs mese precedente',
    'reportMonthlyBestWeeks': 'Settimane con più sonno',
    'reportMonthlySleepTrendUp':
        'Tendenza generale: sonno più riposante questo mese.',
    'reportMonthlySleepTrendDown':
        'Tendenza generale: meno sonno totale rispetto al mese precedente.',
    'reportMonthlySleepTrendStable':
        'Tendenza generale: sonno stabile durante il mese.',
    'reportMonthlySleepTrendUnknown':
        'Dati insufficienti per confrontare con il mese precedente.',
    'reportMonthlySleepExplain':
        'La media del sonno per giorno somma le sessioni registrate nel mese e divide per i giorni del calendario.',
    'reportMonthlyFeedingSection': 'Alimentazione',
    'reportMonthlyFeedFreq': 'Frequenza media (poppate/giorno)',
    'reportMonthlyFeedingExplain':
        'La frequenza media è il totale delle poppate o biberon del mese diviso per i giorni del calendario.',
    'reportMonthlyPredominantHours': 'Orari più comuni (fine poppata)',
    'reportMonthlyMemoriesTitle': 'Ricordi del mese',
    'reportMonthlySeeAllMemories': 'Vedi tutto',
    'reportMonthlyMemoriesEmpty': 'Nessuna foto nei ricordi di questo mese.',
    'reportMonthlyVideosHint':
        'I video appariranno quando saranno salvati nei momenti.',
    'reportSleepAdvScreenTitle': 'Report del sonno',
    'reportSleepAdvScoreTitle': 'Punteggio sonno',
    'reportSleepAdvMetricsTitle': 'Metriche della settimana',
    'reportSleepAdvEfficiency': 'Efficienza del sonno',
    'reportSleepAdvVsPrevPct':
        'Variazione efficienza: {pct}% (vs settimana precedente)',
    'reportSleepAdvOnset': 'Tempo fino al primo sonno notturno',
    'reportSleepAdvAwakenings': 'Risvegli per notte (media)',
    'reportSleepAdvAwakeningsTotal': 'Risvegli questa settimana: {n}',
    'reportSleepAdvLongest': 'Periodo continuo più lungo',
    'reportSleepAdvAvgDailySleep': 'Sonno medio al giorno',
    'reportSleepAdvIdealTitle': 'Orario migliore per addormentarsi',
    'reportSleepAdvIdealFooter':
        'Finestra stimata dai tuoi dati (non è un consiglio medico).',
    'reportSleepAdvSeeFullAnalysis': 'Vedi analisi completa',
    'reportSleepAdvChartsSection': 'Sessione di sonno',
    'reportSleepAdvChartsSleepTrend': 'Ritmo del sonno (questa settimana)',
    'reportSleepAdvChartsCompare': 'Confronto con la settimana precedente',
    'reportSleepAdvChartsDistribution': 'Giorno e notte (totale settimana)',
    'reportSleepAdvChartsBars':
        'Volume di sonno: questa settimana vs precedente',
    'reportSleepAdvDayPhase': 'Sonno diurno (6–18)',
    'reportSleepAdvNightPhase': 'Sonno notturno (18–6)',
    'reportSleepAdvDistributionEmpty': 'Nessun dato da distribuire.',
    'reportSleepAdvLegendThisWeek': 'Questa settimana',
    'reportSleepAdvLegendPrevWeek': 'Settimana precedente',
    'reportSleepAdvScoreBreakdown': 'Cosa riflette il punteggio',
    'reportSleepAdvBreakdownLine':
        'Efficienza: {e} pt • Tratti lunghi: {s} pt • Risvegli: {a} pt • Regolarità: {c} pt.',
    'reportSleepAdvNotEnoughData':
        'Ancora pochi dati questa settimana — valori indicativi.',
    'reportSleepAdvStatusExcellent': 'Eccellente',
    'reportSleepAdvStatusGood': 'Buono',
    'reportSleepAdvStatusRegular': 'Regolare',
    'reportSleepAdvStatusPoor': 'Fragile',
    'reportSleepAdvBadgeVeryGood': 'Molto buono',
    'reportSleepAdvBadgeGood': 'Buono',
    'reportSleepAdvBadgeOk': 'Moderato',
    'reportSleepAdvBadgeAttention': 'Da seguire',
    'reportSleepAdvBadgeIdeal': 'Ideale',
    'reportSleepAdvBadgeUnknown': 'Nessun dato',
    'reportSleepAdvBadgeLow': 'Basso',
    'reportSleepAdvBadgeModerate': 'Moderato',
    'reportSleepAdvBadgeHigh': 'Alto',
    'alertsSectionFeeding': 'Alimentazione',
    'alertsRuleFeeding':
        'Quando attivo, l’app programma una notifica dopo l’intervallo scelto dall’ultima poppata o biberon.',
    'alertsSectionDiaper': 'Pannolino',
    'alertsRuleDiaper':
        'L’app suggerisce un promemoria circa 3 ore e 30 minuti dopo l’ultimo cambio registrato. Un nuovo cambio lo riprogramma.',
    'alertsSectionSleep': 'Sonno',
    'alertsRuleSleep':
        'Usando la fine dell’ultimo sonno registrato e l’età del bimbo, l’app può programmare avvisi attorno alla finestra di veglia.',
    'alertsSectionGrowth': 'Crescita e misurazioni',
    'alertsRuleGrowth':
        'Avvisa se il peso più recente è sotto il precedente o se passano più di 30 giorni senza misurazioni.',
    'alertsScreenIntro':
        'Come funziona ogni promemoria. Puoi cambiare questi interruttori qui o nelle schermate alimentazione, pannolino, sonno e crescita/salute.',
    'alertsExactAlarmAndroidTitle': 'Avvisi puntuali (Android)',
    'alertsExactAlarmAndroidBody':
        'Per ricevere i promemoria all’orario previsto, consenti a FaceBaby di usare sveglie/allarmi esatti nelle impostazioni di sistema. Senza questo permesso Android può ritardare o saltare la notifica.',
    'alertsExactAlarmAndroidOpenSettings': 'Apri impostazioni',
    'alertsTestTitle': 'Test notifiche',
    'alertsTestBody':
        'Invia una notifica ora e ne programma un’altra tra 30 secondi. Utile per confermare che il sistema sta consegnando le notifiche dell’app.',
    'alertsTestRun': 'Esegui test',
    'alertsTestResync': 'Forza riprogrammazione (promemoria reali)',
    'alertsTestImmediateTitle': 'FaceBaby — test immediato',
    'alertsTestImmediateBody':
        'Se vedi questo messaggio, il canale immediato funziona.',
    'alertsTestScheduledTitle': 'FaceBaby — test programmato',
    'alertsTestScheduledBody':
        'Questo è stato programmato con AlarmManager (~30s).',
    'alertsTestAllScheduleModesFailed':
        'AlarmManager ha rifiutato tutte le modalità',
    'alertsTestSentOk':
        'Inviato. Dovresti riceverne una ora e un’altra tra ~30s.',
    'alertsTestFailed': 'Errore: {errors}',
    'sleepToggleAlertsSubtitle':
        'Promemoria basati sull’ultimo sonno concluso e sull’età del bimbo.',
    'sleepAlertsWakeWindowRulerValueAuto':
        'Valore effettivo su questa scala: {m} min (automatico per età).',
    'sleepAlertsWakeWindowRulerValueCustom':
        'Valore su questa scala: {m} min (personalizzato).',
    'sleepAlertsWakeWindowSliderLabelAuto': '{m} min · auto',
    'sleepAlertsWakeWindowSliderLabelCustom': '{m} min',
    'sleepAlertsApproachRulerValueDefault':
        'Anticipo su questa scala: {m} min (predefinito).',
    'sleepAlertsApproachRulerValueCustom': 'Anticipo su questa scala: {m} min.',
    'sleepAlertsApproachSliderLabelDefault': '{m} min · predefinito',
    'sleepAlertsApproachSliderLabelCustom': '{m} min',
    'sleepAlertsWakeWindowAutomatic':
        'Limite finestra di veglia per l’avviso: {m} min (automatico per età).',
    'sleepAlertsWakeWindowAutomaticNoBirth':
        'Aggiungi la data di nascita del bimbo nel profilo per tempi più accurati; per ora usiamo {m} min.',
    'sleepAlertsMonthsApprox': 'Fascia tabella età: ~{n} mesi',
    'sleepAlertsWakeWindowCustom':
        'Limite finestra di veglia personalizzato: {m} min.',
    'sleepAlertsApproachAuto':
        'Promemoria prima del limite: anticipo predefinito di {m} min.',
    'sleepAlertsApproachCustom':
        'Promemoria prima del limite: anticipo personalizzato di {m} min.',
    'loadingMotherPhoto': 'Aggiornamento foto della mamma…',
    'loadingBabyPhoto': 'Aggiornamento foto del bimbo…',
    'loadingBabies': 'Caricamento bimbi…',
    'gateLoadProfilesError':
        'Impossibile leggere i dati salvati. Potrebbero essere ancora su questo dispositivo — riprova prima di registrarti di nuovo.',
    'gateRetry': 'Riprova',
    'pickBabyTitle': 'Seleziona bimbo',
    'switchingBaby': 'Cambio bimbo…',
    'sleepAppBar': 'Sonno',
    'sleepTitle': 'Sonno',
    'sleepIntro': 'Registra e segui pisolini e sonno notturno.',
    'sleepComingTitle': 'In arrivo',
    'sleepComingBody':
        'Questa schermata è pronta per registrare il sonno.\nPoi collegheremo il database e mostreremo ultimo sonno, totale giornaliero e storico.',
    'sleepSessionTitle': 'Sonno in corso',
    'sleepSessionStartedAt': 'Iniziato alle {time}',
    'sleepStatusSleeping': 'Dorme',
    'sleepStatusPaused': 'In pausa',
    'sleepWakeButton': 'SI È SVEGLIATO?',
    'sleepThisCardTitle': 'Questo sonno',
    'sleepLabelStart': 'Inizio',
    'sleepLabelEnd': 'Fine',
    'sleepLabelDuration': 'Durata',
    'sleepLabelQuality': 'Qualità',
    'sleepObservationsTitle': 'Note',
    'sleepObservationHint': 'Aggiungi una nota…',
    'sleepPause': 'Pausa',
    'sleepResume': 'Riprendi',
    'sleepCancelSession': 'Annulla sonno',
    'sleepStartButton': 'INIZIA SONNO',
    'sleepSavedOk': 'Sonno salvato.',
    'sleepResultDialogTitle': 'Stato del sonno',
    'sleepResultShortTitle': 'Ha dormito meno del previsto',
    'sleepResultExpectedTitle': 'Sonno nella norma',
    'sleepResultLongTitle': 'Ha dormito più del previsto',
    'sleepResultDurationLine': 'Durata registrata: {duration}.',
    'sleepResultExpectedLine': 'Riferimento per l\'età: circa {min}–{max} min.',
    'sleepResultShortBody':
        'Sonno breve. Osserva i segnali di stanchezza e prepara un ambiente calmo per il prossimo riposo.',
    'sleepResultExpectedBody':
        'Buona finestra di riposo. Questo sonno è vicino a quanto previsto per l\'età.',
    'sleepResultLongBody':
        'Sonno più lungo. Può essere recupero di stanchezza; osserva se si ripete spesso.',
    'sleepConfirmBackTitle': 'Uscire dal monitoraggio sonno?',
    'sleepConfirmBackBody':
        'Questa sessione non è ancora salvata. Vuoi scartarla?',
    'sleepConfirmCancelSessionTitle': 'Annullare sonno?',
    'sleepConfirmCancelSessionBody':
        'Il tempo registrato in questa sessione andrà perso.',
    'sleepDiscard': 'Scarta',
    'sleepHistoryTitle': 'Storico sonno',
    'sleepHistoryEmpty': 'Nessuna sessione di sonno ancora.',
    'historyShowButton': 'Vedi storico',
    'historyHideButton': 'Nascondi storico',
    'historyViewMoreButton': 'Vedi altro',
    'sleepUpdatedOk': 'Sonno aggiornato.',
    'sleepBannerNextNap': 'Prossimo pisolino tra ~{min} min',
    'sleepWindowTitle': 'Finestra di sonno attuale',
    'sleepWindowEarly': 'Prima della finestra ideale',
    'sleepWindowIdeal': 'Ideale',
    'sleepWindowLate': 'In ritardo',
    'sleepRoutineLastLabel': 'Ultimo sonno: {ago}',
    'sleepRoutineLastNever': 'Ultimo sonno: nessun registro',
    'sleepRoutineNextPrefix': 'Prossimo pisolino:',
    'sleepNextApproxMin': 'tra ~{min} min',
    'sleepRoutineNextNow': 'ora — buon momento per provare',
    'sleepStatusEarly': '🟡 Prima della finestra ideale',
    'sleepStatusIdeal': '🟢 Finestra ideale',
    'sleepStatusOverdue': '🔴 Probabilmente molto stanco',
    'sleepHeroAwakeBadge': 'Sveglio',
    'sleepHeroAwakeCaption':
        'La barra verde → gialla → rossa mostra da quanto tempo è sveglio e quando di solito arriva il prossimo pisolino. Quando lo metti a dormire, tocca INIZIA SONNO.',
    'sleepHeroSleepingBadge': 'Dorme',
    'sleepHeroSleepingCaption':
        'Quando si sveglia, tocca Fine sonno per salvare questa sessione.',
    'sleepRoutineCardTitle': 'Prossimo sonno',
    'sleepRoutineVigilHighlight':
        'Finestra di veglia dell’app: {min}–{max} min tra i sonni (fissa per età in mesi — non configurabile).',
    'sleepRoutineStatusLine': 'Stato: {status}',
    'sleepIdealForAge': 'Stessa tabella (per età)',
    'sleepAgeMonthsLabel': '{n} mesi',
    'sleepWindowMinMax': '{min}–{max} min',
    'sleepLegendG': '🟢 finestra ideale',
    'sleepLegendY': '🟡 prima della finestra ideale',
    'sleepLegendR': '🔴 oltre il limite',
    'sleepWakeWindowExplainer':
        'Mostra da quanto tempo il bimbo è sveglio dalla fine dell’ultimo sonno. Giallo: non è ancora nella finestra tipica del prossimo pisolino.',
    'sleepFinalizeButton': 'FINE',
    'sleepSleepingFor': 'Dorme da {when}',
    'sleepInsightTitle': 'Riepilogo di oggi',
    'sleepInsightNaps': 'Oggi: {n} pisolini',
    'sleepInsightAvg': 'Media: {min} min',
    'sleepInsightTrendDown': '💡 Meno sonno del solito oggi',
    'sleepInsightTrendOk': '💡 Pattern di sonno stabile oggi',
    'sleepHistoryToday': 'Oggi',
    'sleepToggleAlerts': 'Attiva promemoria sonno',
    'feedingScreenAlertsHint': 'Per cambiare i tempi, apri Altro › Avvisi.',
    'sleepNotifTitle': 'Sonno',
    'sleepNotifBeforeBody':
        'Potrebbe essere un buon momento per aiutare il bimbo ad addormentarsi.',
    'sleepNotifOverdueBody':
        'Il bimbo potrebbe essere stanco — prova ad avviare il sonno con calma.',
    'sleepNotifWakeOverdueBodyMale':
        'È da più di {hours} h che dorme, guardalo, mamma.',
    'sleepNotifWakeOverdueBodyFemale':
        'È da più di {hours} h che dorme, guardala, mamma.',
    'notifChannelRemindersName': 'Promemoria',
    'notifChannelRemindersDesc':
        'Avvisi per alimentazione, pannolini, sonno, visite e vaccini.',
    'notifChannelGrowthName': 'Crescita',
    'notifChannelGrowthDesc':
        'Avvisi sul peso e su lunghi intervalli tra misurazioni.',
    'diaperIntro':
        'Registra un cambio per mantenere attivi i promemoria. Nella lista puoi modificare o eliminare ogni voce.',
    'diaperSavedOk': 'Cambio salvato.',
    'diaperUpdatedOk': 'Cambio aggiornato.',
    'diaperHistoryTitle': 'Storico',
    'diaperHistoryEmpty': 'Nessun cambio pannolino ancora.',
    'diaperKindPee': 'Pipì',
    'diaperKindPoo': 'Pupù',
    'diaperKindBoth': 'Pipì e pupù',
    'diaperKindLabel': 'Tipo',
    'diaperDashTitle': 'Ultimi registri',
    'diaperDashLastPee': 'Ultima pipì',
    'diaperDashLastPoo': 'Ultima pupù',
    'diaperDashNoRecordYet': 'Ancora nulla',
    'diaperDashJustNow': 'Adesso',
    'diaperDashAgoLine': '{ago}\u00A0fa',
    'diaperChangedAtLabel': 'Data e ora',
    'diaperNoteOptional': 'Nota (opzionale)',
    'diaperToggleAlerts': 'Promemoria pannolino',
    'diaperToggleAlertsSubtitle': 'Avviso vicino al prossimo cambio suggerito.',
    'healthGrowthToggleAlerts': 'Avvisi crescita',
    'healthGrowthToggleAlertsSubtitle':
        'Avvisi su peso e assenza prolungata di misurazioni.',
    'feedingTitle': 'Alimentazione',
    'feedingSelectBabyFirst': 'Seleziona un bimbo prima di iniziare.',
    'feedingNoRunning': 'Impossibile terminare: nessuna poppata in corso.',
    'feedingSavedOk': 'Poppata salvata.',
    'feedingSaveFail': 'Impossibile salvare:',
    'feedingSaving': 'Salvataggio poppata…',
    'feedingQuickSummary': 'Riepilogo rapido',
    'feedingNoBabyHint':
        'Registra prima un bimbo in "Altro > Registrazione (mamma e bimbi)".',
    'feedingPickBabyLabel': 'Seleziona bimbo',
    'feedingEmptyDataHint':
        'Ancora nessun dato. Usa "Inizia poppata" per registrare con un tocco.',
    'feedingLast': 'Ultima poppata',
    'feedingNextEst': 'Prossima stima',
    'feedingNextIn': 'tra ~{n} min',
    'feedingStatusOk': 'OK',
    'feedingStatusLate': 'In ritardo',
    'feedingStatusWarn': 'Attenzione',
    'feedingFinish': 'Termina poppata',
    'feedingStart': 'Inizia poppata',
    'feedingAfterFinish': 'Registra (dopo aver finito)',
    'feedingTypeBreast': 'Seno',
    'feedingTypeBottle': 'Biberon',
    'feedingTypeSolid': 'Solidi',
    'feedingTypeLabel': 'Tipo',
    'feedingTabBreastfeeding': 'Allattamento',
    'feedingTabBottle': 'Biberon',
    'feedingTabSolids': 'Solidi',
    'feedingHubTapSidesHint':
        'Tocca S o D per avviare il timer. Tocca di nuovo lo stesso lato per salvare.',
    'feedingHubLetterLeft': 'S',
    'feedingHubLetterRight': 'D',
    'feedingHubAddManualEntry': 'Aggiungi voce manuale',
    'feedingHubOverviewTitle': 'Panoramica registri',
    'feedingHubManualTitle': 'Voce manuale (seno)',
    'feedingHubManualMinutes': 'Durata (minuti)',
    'feedingHubManualInvalid': 'Inserisci una durata maggiore di zero.',
    'feedingHubSaveBottle': 'Registra biberon',
    'feedingHubSaveSolid': 'Registra pasto',
    'feedingHubSolidDescribe': 'Cosa è stato offerto? (opzionale)',
    'feedingHubOverviewEmpty': 'Ancora nessuna voce in questa lista.',
    'feedingHubMlRequired': 'Inserisci la quantità in ml.',
    'feedingHubTimerTooShort':
        'Lascia il timer attivo qualche secondo prima di salvare questa poppata.',
    'feedingHubBreastPieTitle': 'Quale lato viene usato di più?',
    'feedingHubBreastPieEmpty':
        'Registra alcune poppate (S/D) per vedere il grafico.',
    'feedingHubFeedingUpdatedOk': 'Voce aggiornata.',
    'feedingSideLeft': 'Sinistro',
    'feedingSideRight': 'Destro',
    'feedingSideBoth': 'Entrambi',
    'feedingSideLabel': 'Lato',
    'feedingQty': 'Quantità',
    'feedingQtyMl': 'Quantità (ml) (opzionale)',
    'feedingNote': 'Nota (opzionale)',
    'feedingHintRunning': 'Termina per salvare.',
    'feedingHintIdle':
        'Pronta per registrare la prossima poppata con un tocco.',
    'feedingHistory': 'Storico',
    'feedingNoRecords': 'Nessun registro ancora.',
    'feedingHistoryLine': '{time} min • {side}',
    'feedingInsights': 'Insight',
    'feedingInsightsNeed': 'Registra almeno 2 poppate per vedere i pattern.',
    'feedingAvgDurFmt': 'Durata media: {m} min',
    'feedingAvgIntervalFmt': 'Intervallo medio: {h}h{m}',
    'feedingAlertSection': 'Avviso (opzionale)',
    'feedingAlertTitle': 'Attiva avviso prossima poppata',
    'feedingModeAvg': 'Media automatica',
    'feedingModeManual': 'Intervallo manuale',
    'feedingNotifyNote':
        'Nota: per ora è solo visivo. Le notifiche arriveranno più avanti.',
    'feedingAgoMinutes': '{m} min fa',
    'feedingAgoHours': '{h}h{m} fa',
    'feedingDurationShort': '{m}m {s}s',
    'feedingDurationSeconds': '{s}s',
    'vaccAddTitle': 'Aggiungi vaccino',
    'vaccNameField': 'Nome del vaccino',
    'vaccDoseOpt': 'Dose (opzionale)',
    'vaccDoseHint': 'Es.: 1ª dose, richiamo',
    'vaccApplied': 'Data di applicazione',
    'vaccNext': 'Prossima dose',
    'vaccNotesOpt': 'Note (opzionale)',
    'vaccNameEmpty': 'Inserisci il nome del vaccino.',
    'vaccSaving': 'Salvataggio vaccino…',
    'vaccUpdatedOk': 'Vaccino aggiornato.',
    'vaccNoBabies': 'Registra prima un bimbo.',
    'vaccTableVac': 'Vaccino',
    'vaccTableDose': 'Dose',
    'vaccTableDate': 'Data',
    'vaccTableNext': 'Prossima',
    'vaccTableNotes': 'Note',
    'exampleCard': 'Esempio libretto:',
  },
  AppLang.hi: {
    'appName': 'FaceBaby',
    'home': 'होम',
    'records': 'रिकॉर्ड',
    'reports': 'रिपोर्ट',
    'memories': 'यादें',
    'more': 'अधिक',
    'helloMom': 'नमस्ते, माँ!',
    'today': 'आज',
    'shortcuts': 'शॉर्टकट',
    'registerNow': 'अभी दर्ज करें',
    'edit': 'संपादित करें',
    'todaySummary': 'आज का सारांश',
    'nextEvents': 'आगामी घटनाएँ',
    'quickRecordsTitle': 'त्वरित रिकॉर्ड',
    'quickRecordsSubtitle': 'कुछ टैप में बच्चे की दिनचर्या जोड़ें।',
    'whatHappenedNow': 'अभी क्या हुआ?',
    'momNote': 'माँ की नोट',
    'saveRecord': 'सेव करें',
    'reportsTitle': 'रिपोर्ट',
    'reportsSubtitle': 'माँ और बाल रोग विशेषज्ञ के लिए सारांश।',
    'growth': 'वृद्धि',
    'pediatricReport': 'बाल रोग रिपोर्ट',
    'pediatricReportDesc':
        'वजन, नींद, खाना, डायपर, टीके, स्वास्थ्य में दर्ज लक्षण, अपॉइंटमेंट और नोट्स के साथ PDF बनाएं।',
    'reportListPediatric': 'बाल चिकित्सक के लिए रिपोर्ट',
    'reportListPediatricSub': 'PDF और चिकित्सा विज़िट के लिए डेटा',
    'healthHubSymptomReports': 'लक्षण दर्ज करें',
    'healthHubSymptomReportsSub':
        'बुखार, कोलिक, दवाएँ और अन्य — बाल रोग रिपोर्ट में शामिल',
    'symptomReportTitle': 'लक्षण दर्ज करें',
    'symptomReportEmpty': 'अभी कोई प्रविष्टि नहीं। जोड़ने के लिए + दबाएँ।',
    'symptomReportNew': 'नई प्रविष्टि',
    'symptomReportSave': 'सेव करें',
    'symptomReportOccurredAt': 'दिनांक और समय',
    'symptomReportPickDateTime': 'दिनांक और समय बदलें',
    'symptomReportMedication': 'ली गई दवाइयाँ',
    'symptomReportMedicationHint': 'नाम या छोटा विवरण',
    'symptomReportFever': 'बुखार',
    'symptomReportTemp': 'तापमान',
    'symptomReportTempHint': 'सेटिंग्स में चुनी इकाइयों के अनुसार',
    'symptomReportCrying': 'कारण के बिना रोना',
    'symptomReportPain': 'दर्द',
    'symptomReportColic': 'कोलिक',
    'symptomReportReflux': 'रिफ्लक्स',
    'symptomReportOther': 'अन्य',
    'symptomReportOtherHint': 'संक्षिप्त विवरण',
    'symptomReportValidationNeedOne':
        'कम से कम एक लक्षण चुनें या कोई फ़ील्ड भरें।',
    'symptomReportValidationFeverTemp':
        'बुखार चिह्नित होने पर तापमान दर्ज करें।',
    'symptomReportDeleteTitle': 'प्रविष्टि हटाएँ?',
    'symptomReportDeleteBody': 'इसे पूर्ववत नहीं किया जा सकता।',
    'reportPediatricScreenTitle': 'बाल रोग रिपोर्ट',
    'reportPediatricPeriodPrefix': 'अवधि:',
    'reportPediatricFilterHint': 'रिपोर्ट की अवधि',
    'reportPediatricDateFrom': 'से',
    'reportPediatricDateTo': 'तक',
    'reportPediatricPickRange': 'तारीखें चुनें',
    'reportPediatricFilterMaxDaysHint':
        'बदलने के लिए टैप करें। बहुत लंबी अवधि 366 दिनों तक सीमित है।',
    'reportPediatricSectionGeneral': 'सामान्य जानकारी',
    'reportPediatricSectionSummary': 'अवधि का सारांश',
    'reportPediatricSectionSleep': 'नींद',
    'reportPediatricSectionFeeding': 'खाना',
    'reportPediatricSectionSymptoms': 'लक्षण और रिकॉर्ड',
    'reportPediatricSectionObservations': 'माता-पिता की टिप्पणियाँ',
    'reportPediatricLabelName': 'नाम',
    'reportPediatricLabelAge': 'आयु',
    'reportPediatricLabelBirth': 'जन्म तिथि',
    'reportPediatricLabelWeightCurrent': 'वजन (अवधि में नवीनतम)',
    'reportPediatricLabelHeight': 'लंबाई',
    'reportPediatricWeightStart': 'प्रारंभिक वजन (अवधि)',
    'reportPediatricWeightEnd': 'अंतिम वजन (अवधि)',
    'reportPediatricWeightGain': 'वजन परिवर्तन',
    'reportPediatricAvgFeeds': 'प्रति दिन फ़ीडिंग (औसत)',
    'reportPediatricAvgSleep': 'प्रति दिन नींद (औसत)',
    'reportPediatricAvgDiapers': 'प्रति दिन डायपर बदलाव (औसत)',
    'reportPediatricFeverEpisodes': 'बुखार की घटनाएँ (संरचित)',
    'reportPediatricFeverNote': 'नोट',
    'reportPediatricFeverFootnote':
        'गिनती स्वास्थ्य › लक्षण दर्ज करें से संरचित प्रविष्टियों से (तापमान यदि दिया गया हो)।',
    'reportPediatricVaccines': 'अवधि में लगे टीके',
    'reportPediatricMedications':
        'दवाइयाँ (संरचित प्रविष्टियाँ और नोट्स में कीवर्ड)',
    'reportPediatricSleepAvgDaily': 'औसत दैनिक नींद',
    'reportPediatricSleepAwakenings': 'रात में जागना (औसत)',
    'reportPediatricSleepPattern': 'नींद का समग्र पैटर्न',
    'reportPediatricSleepPatternStable': 'ज़्यादातर निरंतर',
    'reportPediatricSleepPatternModerate': 'मध्यम',
    'reportPediatricSleepPatternFragmented': 'अधिक टूटा हुआ',
    'reportPediatricSleepLongest': 'सबसे लंबी निरंतर नींद',
    'reportPediatricFeedingBreast': 'स्तनपान',
    'reportPediatricFeedingFormula': 'फ़ॉर्मूला',
    'reportPediatricFeedingSolid': 'ठोस भोजन',
    'reportPediatricFeedingSessions': 'सत्र',
    'reportPediatricFeedingAvgDur': 'औसत अवधि',
    'reportPediatricSymptomReflux': 'रिफ्लक्स (डायरी या संरचित)',
    'reportPediatricSymptomColic': 'कोलिक (डायरी या संरचित)',
    'reportPediatricSymptomIrrit': 'चिड़चिड़ापन (मूड)',
    'reportPediatricIrritHigh': 'अधिक ध्यान देने योग्य',
    'reportPediatricIrritMedium': 'मध्यम',
    'reportPediatricIrritLow': 'हल्का',
    'reportPediatricIrritUnknown': 'कोई डेटा नहीं',
    'reportPediatricYes': 'हाँ',
    'reportPediatricNo': 'नहीं',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'दिन की डायरी',
    'reportPediatricJournalNoteHint': 'मुक्त पाठ में कीवर्ड पहचान।',
    'reportPediatricObsHint':
        'विज़िट के लिए नोट्स: लक्षण, दवाइयाँ, व्यवहार में बदलाव…',
    'reportPediatricBtnShare': 'शेयर करें',
    'reportPediatricBtnExportPdf': 'PDF निर्यात',
    'reportPediatricBtnPrint': 'प्रिंट',
    'reportPediatricBtnEmail': 'ईमेल',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote':
        'स्थानीय डेटा से सूचनात्मक सारांश। चिकित्सकीय मूल्यांकन का विकल्प नहीं।',
    'reportPediatricNone': 'कोई नहीं',
    'reportPediatricPdfTitle': 'बाल रोग रिपोर्ट — FaceBaby',
    'reportPediatricPdfPeriod': 'अवधि:',
    'reportPediatricPdfFooter':
        'FaceBaby में बनाया गया। सामग्री इस डिवाइस पर डेटा तक सीमित (ऑफ़लाइन संभव)।',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': 'कारण के बिना रोना (संरचित)',
    'reportPediatricSymptomPain': 'दर्द (संरचित)',
    'reportPediatricStructuredSymptoms':
        'संरचित लक्षण प्रविष्टियाँ (दिनांक और समय)',
    'reportPediatricStructuredSymptomsEmpty':
        'इस अवधि में कोई संरचित प्रविष्टि नहीं।',
    'generatePdf': 'PDF बनाएं',
    'reportMonthlyMilestonesTitle': 'महीने की उपलब्धियाँ',
    'reportMonthlyMilestonesEmpty':
        'इस महीने कोई टीकाकरण, परामर्श या बैज वाली यादें नहीं।',
    'reportMonthlyMilestoneConsultationDefault': 'परामर्श',
    'memoriesTitle': 'यादों की किताब',
    'memoriesSubtitle': 'महत्वपूर्ण पलों को संजोएं।',
    'addMemory': 'याद जोड़ें',
    'settingsTitle': 'अधिक',
    'registerMotherBaby': 'पंजीकरण (माँ और बच्चा)',
    'vaccinesCard': 'टीके (कार्ड)',
    'language': 'भाषा',
    'settingsSoonTitle': 'जल्द आ रहा है',
    'settingsSoonBadge': 'जल्द',
    'settingsRateUs': 'हमें रेट करें',
    'settingsTermsOfUse': 'उपयोग की शर्तें',
    'settingsPrivacyPolicy': 'गोपनीयता नीति',
    'settingsSpecialThanks': 'विशेष धन्यवाद',
    'settingsTellFriend': 'दोस्त को बताएं',
    'vaccinesTitle': 'टीके',
    'vaccinesSubtitle': 'टीके, तारीखें और अगली खुराक जोड़ें।',
    'baby': 'बच्चा',
    'selectBaby': 'बच्चा चुनें',
    'addVaccine': 'टीका जोड़ें',
    'recordsTitle': 'रिकॉर्ड',
    'noVaccinesYet': 'अभी कोई टीका नहीं।',
    'seeAll': 'सभी देखें',
    'changePhoto': 'फोटो बदलें',
    'motherPhotoTitle': 'माँ की फोटो',
    'babyPhotoTitle': 'बच्चे की फोटो',
    'changeBabyTooltip': 'बच्चा बदलें',
    'helloMomNamed': 'नमस्ते, माँ {name}!',
    'registerVerb': 'दर्ज करें',
    'viewCalendar': 'कैलेंडर देखें',
    'shortcutMilk': 'दूध',
    'shortcutSleep': 'नींद',
    'shortcutVaccines': 'टीके',
    'homeFedAgo': '{when} पहले खाया',
    'homePeeAgo': '{when} पहले पेशाब',
    'homePooAgo': '{when} पहले potty',
    'homeNextNow': 'अगली: अभी।',
    'homeNextIn': '{n} मि. में अगली।',
    'homeStatusOk': 'सब ठीक',
    'homeStatusWarn': 'हल्का ध्यान',
    'homeStatusHungry': 'भूख लग सकती है',
    'homeTipTitle': 'आज की सलाह',
    'homeTipBody':
        'हल्की दिनचर्या {name} को रात में बेहतर सोने में मदद करती है।',
    'summaryFeedings': 'फीडिंग',
    'summarySleep': 'कुल नींद',
    'summaryLastFeed': 'आखिरी {time}',
    'summaryLastSleep': 'आखिरी {time}',
    'cancel': 'रद्द करें',
    'delete': 'हटाएँ',
    'notificationsInboxTitle': 'सूचनाएँ',
    'notificationsInboxSubtitle':
        'पिछले 3 दिन (ऐप में दर्ज भेजी गई व निर्धारित)',
    'notificationsEmpty': 'इस अवधि में अभी कोई सूचना दर्ज नहीं।',
    'notificationsKindShown': 'वितरित',
    'notificationsKindScheduled': 'निर्धारित',
    'notificationsOpenTarget': 'खोलने के लिए टैप करें',
    'notificationsSelectAll': 'सभी चुनें',
    'homeTodayLabel': 'आज',
    'homeYesterdayLabel': 'कल',
    'homeBabyBannerForecastSleep': 'सोने का अनुमान',
    'homeBabyBannerForecastWake': 'जागने का अनुमान',
    'homeBabyBannerForecastSubtitleSleep':
        'वर्तमान समय के आधार पर\nनींद के संकेत',
    'homeBabyBannerForecastSubtitleWake':
        'वर्तमान समय और उम्र के पैटर्न के अनुसार',
    'homeBabyBannerEtaIn': '{d} में',
    'homeBabyBannerLastDiaper': 'अंतिम डायपर',
    'homeBabyBannerNoRecordsYet': 'अभी कोई रिकॉर्ड नहीं',
    'homeBabyBannerNextBetween': 'अगला {range} के बीच',
    'homeBabyBannerDiaperRecommendedUntil': 'सुझाया गया बदलाव {d} तक',
    'homeBabyBannerIdealWindow': 'आदर्श खिड़की: {range}',
    'homeConsultationScheduled': 'निर्धारित परामर्श',
    'homeBannerChipConsultation': 'परामर्श',
    'homeBannerChipDiaper': 'डायपर',
    'homeBannerChipFeed': 'खिलाना',
    'homeBannerChipSleep': 'नींद',
    'homeBannerOverdueSleep': 'सोने का समय बीत चुका',
    'homeBannerOverdueWake': 'जागने का समय बीत चुका',
    'homeBannerHungry': 'भूखा',
    'homeBannerDiaperDirty': 'गंदा हो सकता है',
    'homeBannerExhausted': 'थका हुआ',
    'homeBannerChipVaccine': 'आज टीका',
    'homeConsultationBannerChip': 'परामर्श · {title} · {t}',
    'feedingLast': 'अंतिम स्तनपान',
    'memoriesProgressSaved': '{total} में से {filled} क्षण सहेजे',
    'memoriesCheerEmpty': '+ वाले बैज पर टैप करके फ़ोटो और बातें जोड़ें।',
    'feedingNoBabyHint': 'पहले बच्चा जोड़ें: अधिक > पंजीकरण (माँ और बच्चे)।',
    'memoriesAlbumPromoTitle': 'आपकी पूरी यादों की किताब',
    'memoriesAlbumPromoSubtitle':
        'FaceBaby कवर, सजावटी फ़्रेम और भरे हुए सभी बैज के साथ एक सुंदर PDF डाउनलोड करें।',
    'memoriesAlbumDownloadCta': 'एल्बम PDF डाउनलोड करें',
    'memoriesAlbumGenerating': 'आपका एल्बम बन रहा है…',
    'memoriesAlbumNeedFilled':
        'PDF बनाने के लिए एल्बम में कम से कम एक क्षण भरें।',
    'memoriesAlbumError': 'PDF नहीं बनाया जा सका।',
    'memoriesAlbumPdfReadyTitle': 'एल्बम PDF तैयार',
    'memoriesAlbumShareAction': 'शेयर करें…',
    'memoriesAlbumSaveAction': 'सेव / डाउनलोड',
    'memoriesAlbumSavedSnack': 'PDF डिवाइस पर सेव हो गया।',
    'memoriesAlbumSaveFailedSnack': 'PDF सेव नहीं हो सका।',
    'memoriesAlbumCoverMain': 'यादों की किताब',
    'memoriesAlbumCoverTagline': '{name} के साथ खास पल',
    'memoriesAlbumFooter': 'FaceBaby से बनाया गया',
    'vaccNoBabies':
        'अभी कोई बच्चा पंजीकृत नहीं। अधिक > पंजीकरण (माँ और बच्चा) में जाएँ।',
    'exampleCard': 'उदाहरण कार्ड:',
  },
  AppLang.id: {
    'appName': 'FaceBaby',
    'home': 'Beranda',
    'records': 'Catatan',
    'reports': 'Laporan',
    'memories': 'Kenangan',
    'more': 'Lainnya',
    'helloMom': 'Hai, Ibu!',
    'today': 'Hari ini',
    'shortcuts': 'Pintasan',
    'registerNow': 'Catat sekarang',
    'edit': 'Edit',
    'todaySummary': 'Ringkasan hari ini',
    'nextEvents': 'Acara berikutnya',
    'quickRecordsTitle': 'Catatan cepat',
    'quickRecordsSubtitle': 'Tambahkan rutinitas bayi dengan beberapa ketukan.',
    'whatHappenedNow': 'Apa yang terjadi sekarang?',
    'momNote': 'Catatan ibu',
    'saveRecord': 'Simpan',
    'reportsTitle': 'Laporan',
    'reportsSubtitle': 'Ringkasan untuk ibu dan dokter anak.',
    'growth': 'Pertumbuhan',
    'pediatricReport': 'Laporan dokter anak',
    'pediatricReportDesc':
        'Buat PDF dengan berat, tidur, makan, popok, vaksin, gejala yang dicatat di Kesehatan, janji temu, dan catatan.',
    'reportListPediatric': 'Laporan untuk dokter anak',
    'reportListPediatricSub': 'PDF dan data untuk kunjungan medis',
    'healthHubSymptomReports': 'Catat gejala',
    'healthHubSymptomReportsSub':
        'Demam, kolik, obat, dan lainnya — termasuk dalam laporan pediatri',
    'symptomReportTitle': 'Catat gejala',
    'symptomReportEmpty': 'Belum ada entri. Ketuk + untuk menambah.',
    'symptomReportNew': 'Entri baru',
    'symptomReportSave': 'Simpan',
    'symptomReportOccurredAt': 'Tanggal & waktu',
    'symptomReportPickDateTime': 'Ubah tanggal & waktu',
    'symptomReportMedication': 'Obat yang diminum',
    'symptomReportMedicationHint': 'Nama atau catatan singkat',
    'symptomReportFever': 'Demam',
    'symptomReportTemp': 'Suhu',
    'symptomReportTempHint': 'Sesuai unit di Pengaturan',
    'symptomReportCrying': 'Menangis tanpa penyebab jelas',
    'symptomReportPain': 'Nyeri',
    'symptomReportColic': 'Kolik',
    'symptomReportReflux': 'Refluks',
    'symptomReportOther': 'Lainnya',
    'symptomReportOtherHint': 'Deskripsi singkat',
    'symptomReportValidationNeedOne':
        'Pilih setidaknya satu gejala atau isi sebuah kolom.',
    'symptomReportValidationFeverTemp': 'Masukkan suhu jika demam dicentang.',
    'symptomReportDeleteTitle': 'Hapus entri?',
    'symptomReportDeleteBody': 'Tindakan ini tidak dapat dibatalkan.',
    'reportPediatricScreenTitle': 'Laporan pediatri',
    'reportPediatricPeriodPrefix': 'Periode:',
    'reportPediatricFilterHint': 'Periode laporan',
    'reportPediatricDateFrom': 'Dari',
    'reportPediatricDateTo': 'Sampai',
    'reportPediatricPickRange': 'Pilih tanggal',
    'reportPediatricFilterMaxDaysHint':
        'Ketuk untuk mengubah. Rentang sangat panjang dibatasi 366 hari.',
    'reportPediatricSectionGeneral': 'Informasi umum',
    'reportPediatricSectionSummary': 'Ringkasan periode',
    'reportPediatricSectionSleep': 'Tidur',
    'reportPediatricSectionFeeding': 'Makan',
    'reportPediatricSectionSymptoms': 'Gejala dan catatan',
    'reportPediatricSectionObservations': 'Observasi orang tua',
    'reportPediatricLabelName': 'Nama',
    'reportPediatricLabelAge': 'Usia',
    'reportPediatricLabelBirth': 'Tanggal lahir',
    'reportPediatricLabelWeightCurrent': 'Berat (terbaru dalam periode)',
    'reportPediatricLabelHeight': 'Tinggi',
    'reportPediatricWeightStart': 'Berat awal (periode)',
    'reportPediatricWeightEnd': 'Berat akhir (periode)',
    'reportPediatricWeightGain': 'Perubahan berat',
    'reportPediatricAvgFeeds': 'Makan/minum per hari (rata-rata)',
    'reportPediatricAvgSleep': 'Tidur per hari (rata-rata)',
    'reportPediatricAvgDiapers': 'Ganti popok per hari (rata-rata)',
    'reportPediatricFeverEpisodes': 'Episode demam (terstruktur)',
    'reportPediatricFeverNote': 'Catatan',
    'reportPediatricFeverFootnote':
        'Dihitung dari catatan terstruktur di Kesehatan › Catat gejala (dengan suhu jika ada).',
    'reportPediatricVaccines': 'Vaksin dalam periode',
    'reportPediatricMedications':
        'Obat (catatan terstruktur & kata kunci di catatan)',
    'reportPediatricSleepAvgDaily': 'Rata-rata tidur harian',
    'reportPediatricSleepAwakenings': 'Bangun malam (rata-rata)',
    'reportPediatricSleepPattern': 'Pola tidur secara keseluruhan',
    'reportPediatricSleepPatternStable': 'Mayoritas berkelanjutan',
    'reportPediatricSleepPatternModerate': 'Sedang',
    'reportPediatricSleepPatternFragmented': 'Lebih terfragmentasi',
    'reportPediatricSleepLongest': 'Tidur terpanjang tanpa putus',
    'reportPediatricFeedingBreast': 'ASI',
    'reportPediatricFeedingFormula': 'Susu formula',
    'reportPediatricFeedingSolid': 'Makanan padat',
    'reportPediatricFeedingSessions': 'sesi',
    'reportPediatricFeedingAvgDur': 'durasi rata-rata',
    'reportPediatricSymptomReflux': 'Refluks (jurnal atau terstruktur)',
    'reportPediatricSymptomColic': 'Kolik (jurnal atau terstruktur)',
    'reportPediatricSymptomIrrit': 'Irritabilitas (suasana hati)',
    'reportPediatricIrritHigh': 'Lebih terlihat',
    'reportPediatricIrritMedium': 'Sedang',
    'reportPediatricIrritLow': 'Ringan',
    'reportPediatricIrritUnknown': 'Tidak ada data',
    'reportPediatricYes': 'Ya',
    'reportPediatricNo': 'Tidak',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'Jurnal harian',
    'reportPediatricJournalNoteHint': 'Deteksi kata kunci dalam teks bebas.',
    'reportPediatricObsHint':
        'Catatan untuk kunjungan: gejala, obat, perubahan perilaku…',
    'reportPediatricBtnShare': 'Bagikan',
    'reportPediatricBtnExportPdf': 'Ekspor PDF',
    'reportPediatricBtnPrint': 'Cetak',
    'reportPediatricBtnEmail': 'Email',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote':
        'Ringkasan informatif dari data lokal. Bukan pengganti penilaian klinis.',
    'reportPediatricNone': 'Tidak ada',
    'reportPediatricPdfTitle': 'Laporan pediatri — FaceBaby',
    'reportPediatricPdfPeriod': 'Periode:',
    'reportPediatricPdfFooter':
        'Dibuat di FaceBaby. Konten terbatas pada data di perangkat ini (dapat offline).',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': 'Menangis tanpa penyebab (terstruktur)',
    'reportPediatricSymptomPain': 'Nyeri (terstruktur)',
    'reportPediatricStructuredSymptoms':
        'Catatan gejala terstruktur (tanggal & waktu)',
    'reportPediatricStructuredSymptomsEmpty':
        'Tidak ada catatan terstruktur dalam periode ini.',
    'generatePdf': 'Buat PDF',
    'reportMonthlyMilestonesTitle': 'Pencapaian bulan ini',
    'reportMonthlyMilestonesEmpty':
        'Tidak ada vaksin, kunjungan dokter, atau kenangan dengan lencana bulan ini.',
    'reportMonthlyMilestoneConsultationDefault': 'Kunjungan',
    'memoriesTitle': 'Buku kenangan',
    'memoriesSubtitle': 'Momen penting untuk disimpan.',
    'addMemory': 'Tambah kenangan',
    'settingsTitle': 'Lainnya',
    'registerMotherBaby': 'Daftar (ibu & bayi)',
    'vaccinesCard': 'Vaksin (kartu)',
    'language': 'Bahasa',
    'settingsSoonTitle': 'Segera hadir',
    'settingsSoonBadge': 'Segera',
    'settingsRateUs': 'Beri penilaian',
    'settingsTermsOfUse': 'Ketentuan penggunaan',
    'settingsPrivacyPolicy': 'Kebijakan privasi',
    'settingsSpecialThanks': 'Ucapan terima kasih khusus',
    'settingsTellFriend': 'Beri tahu teman',
    'vaccinesTitle': 'Vaksin',
    'vaccinesSubtitle': 'Tambah vaksin, tanggal, dan dosis berikutnya.',
    'baby': 'Bayi',
    'selectBaby': 'Pilih bayi',
    'addVaccine': 'Tambah vaksin',
    'recordsTitle': 'Catatan',
    'noVaccinesYet': 'Belum ada vaksin.',
    'seeAll': 'Lihat semua',
    'changePhoto': 'Ganti foto',
    'motherPhotoTitle': 'Foto ibu',
    'babyPhotoTitle': 'Foto bayi',
    'changeBabyTooltip': 'Ganti bayi',
    'helloMomNamed': 'Hai, Ibu {name}!',
    'registerVerb': 'Catat',
    'viewCalendar': 'Lihat kalender',
    'shortcutMilk': 'Menyusui',
    'shortcutSleep': 'Tidur',
    'shortcutVaccines': 'Vaksin',
    'homeFedAgo': 'Menyusu {when} lalu',
    'homePeeAgo': 'Pipis {when} lalu',
    'homePooAgo': 'Poop {when} lalu',
    'homeNextNow': 'Berikutnya: sekarang.',
    'homeNextIn': 'Berikutnya dalam {n} mnt.',
    'homeStatusOk': 'Semua baik',
    'homeStatusWarn': 'Perhatian ringan',
    'homeStatusHungry': 'Mungkin lapar',
    'homeTipTitle': 'Tips hari ini',
    'homeTipBody':
        'Rutinitas ringan membantu {name} tidur lebih nyenyak di malam hari.',
    'summaryFeedings': 'MENYUSUI',
    'summarySleep': 'TIDUR TOTAL',
    'summaryLastFeed': 'Terakhir jam {time}',
    'summaryLastSleep': 'Terakhir jam {time}',
    'exampleCard': 'Contoh kartu:',
  },
  AppLang.ja: {
    'appName': 'FaceBaby',
    'home': 'ホーム',
    'records': '記録',
    'reports': 'レポート',
    'memories': '思い出',
    'more': 'その他',
    'helloMom': 'こんにちは、ママ！',
    'today': '今日',
    'shortcuts': 'ショートカット',
    'registerNow': '今すぐ記録',
    'edit': '編集',
    'todaySummary': '今日のまとめ',
    'nextEvents': '次の予定',
    'quickRecordsTitle': 'クイック記録',
    'quickRecordsSubtitle': '数回のタップで赤ちゃんの記録を追加できます。',
    'whatHappenedNow': 'いま何が起きた？',
    'momNote': 'ママのメモ',
    'saveRecord': '保存',
    'reportsTitle': 'レポート',
    'reportsSubtitle': 'ママと小児科医のための要約。',
    'growth': '成長',
    'pediatricReport': '小児科レポート',
    'pediatricReportDesc': '体重、睡眠、授乳/食事、おむつ、ワクチン、ヘルスで記録した症状、受診、メモを含むPDFを生成します。',
    'reportListPediatric': '小児科医向けレポート',
    'reportListPediatricSub': '診察用のPDFとデータ',
    'healthHubSymptomReports': '症状を記録',
    'healthHubSymptomReportsSub': '発熱、疝痛、服薬など — 小児科レポートに反映',
    'symptomReportTitle': '症状を記録',
    'symptomReportEmpty': '記録はまだありません。「+」で追加してください。',
    'symptomReportNew': '新しい記録',
    'symptomReportSave': '保存',
    'symptomReportOccurredAt': '日付と時刻',
    'symptomReportPickDateTime': '日付と時刻を変更',
    'symptomReportMedication': '服用した薬',
    'symptomReportMedicationHint': '名前または短いメモ',
    'symptomReportFever': '発熱',
    'symptomReportTemp': '体温',
    'symptomReportTempHint': '設定の単位に合わせます',
    'symptomReportCrying': '原因のわからない泣き',
    'symptomReportPain': '痛み',
    'symptomReportColic': '疝痛',
    'symptomReportReflux': '逆流（逆流性）',
    'symptomReportOther': 'その他',
    'symptomReportOtherHint': '簡潔な説明',
    'symptomReportValidationNeedOne': '症状を1つ以上選ぶか、項目を入力してください。',
    'symptomReportValidationFeverTemp': '発熱にチェックがあるときは体温を入力してください。',
    'symptomReportDeleteTitle': '記録を削除しますか？',
    'symptomReportDeleteBody': '元に戻せません。',
    'reportPediatricScreenTitle': '小児科臨床レポート',
    'reportPediatricPeriodPrefix': '期間:',
    'reportPediatricFilterHint': 'レポートの期間',
    'reportPediatricDateFrom': '開始',
    'reportPediatricDateTo': '終了',
    'reportPediatricPickRange': '日付を選ぶ',
    'reportPediatricFilterMaxDaysHint': 'タップして変更。長すぎる期間は366日までに制限されます。',
    'reportPediatricSectionGeneral': '基本情報',
    'reportPediatricSectionSummary': '期間の概要',
    'reportPediatricSectionSleep': '睡眠',
    'reportPediatricSectionFeeding': '授乳・離乳',
    'reportPediatricSectionSymptoms': '症状と記録',
    'reportPediatricSectionObservations': '保護者の所見',
    'reportPediatricLabelName': '名前',
    'reportPediatricLabelAge': '月齢・年齢',
    'reportPediatricLabelBirth': '生年月日',
    'reportPediatricLabelWeightCurrent': '体重（期内の最新）',
    'reportPediatricLabelHeight': '身長',
    'reportPediatricWeightStart': '期間開始時の体重',
    'reportPediatricWeightEnd': '期間終了時の体重',
    'reportPediatricWeightGain': '体重の変化',
    'reportPediatricAvgFeeds': '1日あたりの授乳・離乳（平均）',
    'reportPediatricAvgSleep': '1日あたりの睡眠（平均）',
    'reportPediatricAvgDiapers': '1日あたりのおむつ交換（平均）',
    'reportPediatricFeverEpisodes': '発熱の記録（構造化）',
    'reportPediatricFeverNote': '注記',
    'reportPediatricFeverFootnote': 'ヘルス › 症状を記録 の構造化データから集計（体温がある場合は含む）。',
    'reportPediatricVaccines': '期内のワクチン接種',
    'reportPediatricMedications': '薬（構造化記録とメモのキーワード）',
    'reportPediatricSleepAvgDaily': '1日平均の睡眠',
    'reportPediatricSleepAwakenings': '夜間の覚醒（平均）',
    'reportPediatricSleepPattern': '睡眠の全体的な傾向',
    'reportPediatricSleepPatternStable': 'おおむね連続',
    'reportPediatricSleepPatternModerate': '中程度',
    'reportPediatricSleepPatternFragmented': 'より断片的',
    'reportPediatricSleepLongest': '最長の連続睡眠',
    'reportPediatricFeedingBreast': '母乳',
    'reportPediatricFeedingFormula': 'ミルク',
    'reportPediatricFeedingSolid': '離乳食',
    'reportPediatricFeedingSessions': '回',
    'reportPediatricFeedingAvgDur': '平均時間',
    'reportPediatricSymptomReflux': '逆流（日記または構造化記録）',
    'reportPediatricSymptomColic': '疝痛（日記または構造化記録）',
    'reportPediatricSymptomIrrit': 'かんしゃく・機嫌（ムード）',
    'reportPediatricIrritHigh': '気になりやすい',
    'reportPediatricIrritMedium': '中程度',
    'reportPediatricIrritLow': '軽い',
    'reportPediatricIrritUnknown': 'データなし',
    'reportPediatricYes': 'はい',
    'reportPediatricNo': 'いいえ',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'その日の日記',
    'reportPediatricJournalNoteHint': '自由記述からキーワード検出。',
    'reportPediatricObsHint': '受診用メモ：症状、薬、行動の変化など…',
    'reportPediatricBtnShare': '共有',
    'reportPediatricBtnExportPdf': 'PDFを書き出す',
    'reportPediatricBtnPrint': '印刷',
    'reportPediatricBtnEmail': 'メール',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote': '端末の記録に基づく情報です。診断の代替にはなりません。',
    'reportPediatricNone': 'なし',
    'reportPediatricPdfTitle': '小児科臨床レポート — FaceBaby',
    'reportPediatricPdfPeriod': '期間:',
    'reportPediatricPdfFooter': 'FaceBabyで作成。この端末に保存されたデータのみ（オフライン可）。',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': '原因のわからない泣き（構造化記録）',
    'reportPediatricSymptomPain': '痛み（構造化記録）',
    'reportPediatricStructuredSymptoms': '構造化された症状記録（日時）',
    'reportPediatricStructuredSymptomsEmpty': 'この期間に構造化記録はありません。',
    'generatePdf': 'PDF生成',
    'reportMonthlyMilestonesTitle': '今月のマイルストーン',
    'reportMonthlyMilestonesEmpty': '今月はワクチン・受診・バッジ付き思い出はありません。',
    'reportMonthlyMilestoneConsultationDefault': '受診',
    'memoriesTitle': '思い出の本',
    'memoriesSubtitle': '大切な瞬間を残そう。',
    'addMemory': '思い出を追加',
    'settingsTitle': 'その他',
    'registerMotherBaby': '登録（ママ＆赤ちゃん）',
    'vaccinesCard': 'ワクチン（カード）',
    'language': '言語',
    'settingsSoonTitle': '近日公開',
    'settingsSoonBadge': '近日',
    'settingsRateUs': '評価する',
    'settingsTermsOfUse': '利用規約',
    'settingsPrivacyPolicy': 'プライバシーポリシー',
    'settingsSpecialThanks': '特別な感謝',
    'settingsTellFriend': '友達に教える',
    'vaccinesTitle': 'ワクチン',
    'vaccinesSubtitle': 'ワクチン、日付、次回接種を追加。',
    'baby': '赤ちゃん',
    'selectBaby': '赤ちゃんを選択',
    'addVaccine': 'ワクチン追加',
    'recordsTitle': '記録',
    'noVaccinesYet': 'まだワクチンがありません。',
    'seeAll': 'すべて表示',
    'changePhoto': '写真を変更',
    'motherPhotoTitle': 'ママの写真',
    'babyPhotoTitle': '赤ちゃんの写真',
    'changeBabyTooltip': '赤ちゃんを切替',
    'helloMomNamed': 'こんにちは、ママ {name}！',
    'registerVerb': '記録',
    'viewCalendar': 'カレンダーを見る',
    'shortcutMilk': '授乳',
    'shortcutSleep': '睡眠',
    'shortcutVaccines': 'ワクチン',
    'homeFedAgo': '{when}前に授乳',
    'homePeeAgo': 'おしっこは{when}前',
    'homePooAgo': 'うんちは{when}前',
    'homeNextNow': '次：今。',
    'homeNextIn': '次は{n}分後。',
    'homeStatusOk': '問題なし',
    'homeStatusWarn': '注意',
    'homeStatusHungry': 'お腹がすいたかも',
    'homeTipTitle': '今日のヒント',
    'homeTipBody': 'ゆるいルーティンは{name}の夜の睡眠を助けます。',
    'summaryFeedings': '授乳',
    'summarySleep': '合計睡眠',
    'summaryLastFeed': '最後 {time}',
    'summaryLastSleep': '最後 {time}',
    'cancel': 'キャンセル',
    'delete': '削除',
    'notificationsInboxTitle': '通知',
    'notificationsInboxSubtitle': '過去3日間（アプリに記録された送信済み・予定）',
    'notificationsEmpty': 'この期間の通知はまだありません。',
    'notificationsKindShown': '配信済み',
    'notificationsKindScheduled': '予定',
    'notificationsOpenTarget': 'タップして開く',
    'notificationsSelectAll': 'すべて選択',
    'homeTodayLabel': '今日',
    'homeYesterdayLabel': '昨日',
    'homeBabyBannerForecastSleep': '睡眠の予測',
    'homeBabyBannerForecastWake': '起床の予測',
    'homeBabyBannerForecastSubtitleSleep': '現在時刻に基づく\n睡眠サイン',
    'homeBabyBannerForecastSubtitleWake': '現在時刻と月齢のパターンに基づく',
    'homeBabyBannerEtaIn': '{d}後',
    'homeBabyBannerLastDiaper': '最後のおむつ',
    'homeBabyBannerNoRecordsYet': 'まだ記録がありません',
    'homeBabyBannerNextBetween': '次は {range}',
    'homeBabyBannerDiaperRecommendedUntil': 'おすすめの交換 {d} まで',
    'homeBabyBannerIdealWindow': '理想的な時間帯: {range}',
    'homeConsultationScheduled': '予約済みの受診',
    'homeBannerChipConsultation': '受診',
    'homeBannerChipDiaper': 'おむつ',
    'homeBannerChipFeed': '授乳',
    'homeBannerChipSleep': '睡眠',
    'homeBannerOverdueSleep': '寝る時間を過ぎています',
    'homeBannerOverdueWake': '起きる時間を過ぎています',
    'homeBannerHungry': 'お腹がすいたかも',
    'homeBannerDiaperDirty': '汚れているかも',
    'homeBannerExhausted': 'くたくた',
    'homeBannerChipVaccine': '今日ワクチン',
    'homeConsultationBannerChip': '受診 · {title} · {t}',
    'feedingLast': '最後の授乳',
    'memoriesProgressSaved': '{total}枚中{filled}枚を記録',
    'memoriesCheerEmpty': '＋のついたバッジをタップして写真やエピソードを追加しましょう。',
    'feedingNoBabyHint': '先に赤ちゃんを登録してください。「その他 > 登録（ママと赤ちゃん）」。',
    'memoriesAlbumPromoTitle': '思い出アルバム一式',
    'memoriesAlbumPromoSubtitle': 'FaceBaby表紙・装飾フレーム・埋めたバッジすべて入りのPDFをダウンロード。',
    'memoriesAlbumDownloadCta': 'アルバムPDFをダウンロード',
    'memoriesAlbumGenerating': 'アルバムを作成中…',
    'memoriesAlbumNeedFilled': 'PDFを作るにはアルバムを1つ以上埋めてください。',
    'memoriesAlbumError': 'PDFを作成できませんでした。',
    'memoriesAlbumPdfReadyTitle': 'アルバムPDFの準備完了',
    'memoriesAlbumShareAction': '共有…',
    'memoriesAlbumSaveAction': '保存／ダウンロード',
    'memoriesAlbumSavedSnack': 'PDFを端末に保存しました。',
    'memoriesAlbumSaveFailedSnack': 'PDFを保存できませんでした。',
    'memoriesAlbumCoverMain': '思い出の本',
    'memoriesAlbumCoverTagline': '{name}との特別な瞬間',
    'memoriesAlbumFooter': 'FaceBabyで作成',
    'memoriesAlbumBackCoverBody':
        'FaceBaby は、何気ない瞬間を一生の思い出に変えるために生まれました。赤ちゃんの笑顔、発見、ハグ、そして成長のひとつひとつを、大切に残していきます。\n\nこの本は、かけがえのない成長の時間を記録し、いつまでも振り返ることのできる宝物となるよう作られています。\n\n写真やメモだけではなく、このページには時間が経っても消えることのない想いと物語が詰まっています。\n\nFaceBaby がご家族の物語の一部になれることを心より嬉しく思います。 💛',
    'memoriesAlbumBackCoverFinale': '子どもの成長はあっという間ですが…\n思い出は永遠に残ります。',
    'vaccNoBabies': 'まだ赤ちゃんが登録されていません。「その他 > 登録（ママと赤ちゃん）」へ。',
    'exampleCard': 'カード例：',
  },
  AppLang.ko: {
    'appName': 'FaceBaby',
    'home': '홈',
    'records': '기록',
    'reports': '리포트',
    'memories': '추억',
    'more': '더보기',
    'helloMom': '안녕하세요, 엄마!',
    'today': '오늘',
    'shortcuts': '바로가기',
    'registerNow': '지금 기록',
    'edit': '편집',
    'todaySummary': '오늘 요약',
    'nextEvents': '다음 일정',
    'quickRecordsTitle': '빠른 기록',
    'quickRecordsSubtitle': '몇 번의 탭으로 아기 루틴을 기록하세요.',
    'whatHappenedNow': '지금 무슨 일이 있었나요?',
    'momNote': '엄마 메모',
    'saveRecord': '저장',
    'reportsTitle': '리포트',
    'reportsSubtitle': '엄마와 소아과 의사를 위한 요약입니다.',
    'growth': '성장',
    'pediatricReport': '소아과 리포트',
    'pediatricReportDesc':
        '체중, 수면, 수유/식사, 기저귀, 예방접종, 건강에서 기록한 증상, 예약, 메모가 포함된 PDF를 생성합니다.',
    'reportListPediatric': '소아과 진료용 리포트',
    'reportListPediatricSub': '진료를 위한 PDF와 데이터',
    'healthHubSymptomReports': '증상 기록',
    'healthHubSymptomReportsSub': '열, 배앓이, 약물 등 — 소아과 리포트에 포함',
    'symptomReportTitle': '증상 기록',
    'symptomReportEmpty': '아직 기록이 없습니다. +를 눌러 추가하세요.',
    'symptomReportNew': '새 기록',
    'symptomReportSave': '저장',
    'symptomReportOccurredAt': '날짜 및 시간',
    'symptomReportPickDateTime': '날짜·시간 변경',
    'symptomReportMedication': '복용한 약',
    'symptomReportMedicationHint': '이름 또는 짧은 메모',
    'symptomReportFever': '발열',
    'symptomReportTemp': '체온',
    'symptomReportTempHint': '설정의 단위를 따릅니다',
    'symptomReportCrying': '원인 없는 울음',
    'symptomReportPain': '통증',
    'symptomReportColic': '복통(배앓이)',
    'symptomReportReflux': '역류',
    'symptomReportOther': '기타',
    'symptomReportOtherHint': '짧은 설명',
    'symptomReportValidationNeedOne': '증상을 하나 이상 선택하거나 항목을 입력하세요.',
    'symptomReportValidationFeverTemp': '발열을 선택하면 체온을 입력하세요.',
    'symptomReportDeleteTitle': '기록을 삭제할까요?',
    'symptomReportDeleteBody': '되돌릴 수 없습니다.',
    'reportPediatricScreenTitle': '소아과 임상 리포트',
    'reportPediatricPeriodPrefix': '기간:',
    'reportPediatricFilterHint': '리포트 기간',
    'reportPediatricDateFrom': '시작',
    'reportPediatricDateTo': '종료',
    'reportPediatricPickRange': '날짜 선택',
    'reportPediatricFilterMaxDaysHint': '탭하여 변경. 너무 긴 기간은 최대 366일로 제한됩니다.',
    'reportPediatricSectionGeneral': '일반 정보',
    'reportPediatricSectionSummary': '기간 요약',
    'reportPediatricSectionSleep': '수면',
    'reportPediatricSectionFeeding': '수유·이유',
    'reportPediatricSectionSymptoms': '증상 및 기록',
    'reportPediatricSectionObservations': '보호자 관찰',
    'reportPediatricLabelName': '이름',
    'reportPediatricLabelAge': '나이',
    'reportPediatricLabelBirth': '생년월일',
    'reportPediatricLabelWeightCurrent': '체중(기간 내 최신)',
    'reportPediatricLabelHeight': '키',
    'reportPediatricWeightStart': '시작 체중(기간)',
    'reportPediatricWeightEnd': '종료 체중(기간)',
    'reportPediatricWeightGain': '체중 변화',
    'reportPediatricAvgFeeds': '하루 수유·식사 횟수(평균)',
    'reportPediatricAvgSleep': '하루 수면(평균)',
    'reportPediatricAvgDiapers': '하루 기저귀 교체(평균)',
    'reportPediatricFeverEpisodes': '발열 기록(구조화)',
    'reportPediatricFeverNote': '참고',
    'reportPediatricFeverFootnote': '건강 › 증상 기록의 구조화된 항목으로 집계(체온이 있으면 포함).',
    'reportPediatricVaccines': '기간 내 예방접종',
    'reportPediatricMedications': '약물(구조화 기록 및 메모 키워드)',
    'reportPediatricSleepAvgDaily': '하루 평균 수면',
    'reportPediatricSleepAwakenings': '야간 깨어남(평균)',
    'reportPediatricSleepPattern': '수면 전반 패턴',
    'reportPediatricSleepPatternStable': '대체로 연속적',
    'reportPediatricSleepPatternModerate': '중간',
    'reportPediatricSleepPatternFragmented': '더 잘게 끊김',
    'reportPediatricSleepLongest': '가장 긴 연속 수면',
    'reportPediatricFeedingBreast': '모유',
    'reportPediatricFeedingFormula': '분유',
    'reportPediatricFeedingSolid': '이유식',
    'reportPediatricFeedingSessions': '회',
    'reportPediatricFeedingAvgDur': '평균 시간',
    'reportPediatricSymptomReflux': '역류(일지 또는 구조화 기록)',
    'reportPediatricSymptomColic': '배앓이(일지 또는 구조화 기록)',
    'reportPediatricSymptomIrrit': '과민·짜증(기분)',
    'reportPediatricIrritHigh': '눈에 띔',
    'reportPediatricIrritMedium': '중간',
    'reportPediatricIrritLow': '약함',
    'reportPediatricIrritUnknown': '데이터 없음',
    'reportPediatricYes': '예',
    'reportPediatricNo': '아니오',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': '하루 일지',
    'reportPediatricJournalNoteHint': '자유 텍스트 키워드 감지.',
    'reportPediatricObsHint': '진료 메모: 증상, 약물, 행동 변화 등…',
    'reportPediatricBtnShare': '공유',
    'reportPediatricBtnExportPdf': 'PDF 내보내기',
    'reportPediatricBtnPrint': '인쇄',
    'reportPediatricBtnEmail': '이메일',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote': '기기에 저장된 기록을 바탕으로 한 정보입니다. 진료를 대체하지 않습니다.',
    'reportPediatricNone': '없음',
    'reportPediatricPdfTitle': '소아과 임상 리포트 — FaceBaby',
    'reportPediatricPdfPeriod': '기간:',
    'reportPediatricPdfFooter': 'FaceBaby에서 생성. 이 기기에 저장된 데이터만 포함(오프라인 가능).',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': '원인 없는 울음(구조화 기록)',
    'reportPediatricSymptomPain': '통증(구조화 기록)',
    'reportPediatricStructuredSymptoms': '구조화된 증상 기록(날짜·시간)',
    'reportPediatricStructuredSymptomsEmpty': '이 기간에 구조화된 기록이 없습니다.',
    'generatePdf': 'PDF 생성',
    'reportMonthlyMilestonesTitle': '이번 달 이정표',
    'reportMonthlyMilestonesEmpty': '이번 달 예방접종·진료·배지 추억이 없습니다.',
    'reportMonthlyMilestoneConsultationDefault': '진료',
    'memoriesTitle': '추억 책',
    'memoriesSubtitle': '중요한 순간을 간직하세요.',
    'addMemory': '추억 추가',
    'settingsTitle': '더보기',
    'registerMotherBaby': '등록(엄마 & 아기)',
    'vaccinesCard': '예방접종(카드)',
    'language': '언어',
    'settingsSoonTitle': '곧 제공',
    'settingsSoonBadge': '곧',
    'settingsRateUs': '평가하기',
    'settingsTermsOfUse': '이용 약관',
    'settingsPrivacyPolicy': '개인정보 처리방침',
    'settingsSpecialThanks': '특별한 감사',
    'settingsTellFriend': '친구에게 알리기',
    'vaccinesTitle': '예방접종',
    'vaccinesSubtitle': '예방접종, 날짜, 다음 접종을 추가하세요.',
    'baby': '아기',
    'selectBaby': '아기 선택',
    'addVaccine': '예방접종 추가',
    'recordsTitle': '기록',
    'noVaccinesYet': '아직 예방접종이 없습니다.',
    'seeAll': '전체 보기',
    'changePhoto': '사진 변경',
    'motherPhotoTitle': '엄마 사진',
    'babyPhotoTitle': '아기 사진',
    'changeBabyTooltip': '아기 바꾸기',
    'helloMomNamed': '안녕하세요, 엄마 {name}!',
    'registerVerb': '기록',
    'viewCalendar': '달력 보기',
    'shortcutMilk': '수유',
    'shortcutSleep': '수면',
    'shortcutVaccines': '예방접종',
    'homeFedAgo': '{when} 전 수유',
    'homePeeAgo': '소변 {when} 전',
    'homePooAgo': '대변 {when} 전',
    'homeNextNow': '다음: 지금.',
    'homeNextIn': '{n}분 후 다음.',
    'homeStatusOk': '괜찮아요',
    'homeStatusWarn': '가벼운 주의',
    'homeStatusHungry': '배고플 수 있어요',
    'homeTipTitle': '오늘의 팁',
    'homeTipBody': '가벼운 루틴은 {name}의 밤잠을 돕습니다.',
    'summaryFeedings': '수유',
    'summarySleep': '총 수면',
    'summaryLastFeed': '마지막 {time}',
    'summaryLastSleep': '마지막 {time}',
    'cancel': '취소',
    'delete': '삭제',
    'notificationsInboxTitle': '알림',
    'notificationsInboxSubtitle': '최근 3일(앱에 기록된 발송·예정)',
    'notificationsEmpty': '이 기간에 아직 알림이 없습니다.',
    'notificationsKindShown': '발송됨',
    'notificationsKindScheduled': '예정',
    'notificationsOpenTarget': '탭하여 열기',
    'notificationsSelectAll': '모두 선택',
    'homeTodayLabel': '오늘',
    'homeYesterdayLabel': '어제',
    'homeBabyBannerForecastSleep': '수면 예측',
    'homeBabyBannerForecastWake': '기상 예측',
    'homeBabyBannerForecastSubtitleSleep': '현재 시각 기준\n수면 신호',
    'homeBabyBannerForecastSubtitleWake': '현재 시각과 월령 패턴 기준',
    'homeBabyBannerEtaIn': '{d} 후',
    'homeBabyBannerLastDiaper': '마지막 기저귀',
    'homeBabyBannerNoRecordsYet': '아직 기록 없음',
    'homeBabyBannerNextBetween': '다음 {range} 사이',
    'homeBabyBannerDiaperRecommendedUntil': '{d}까지 갈아주기 권장',
    'homeBabyBannerIdealWindow': '적정 시간대: {range}',
    'homeConsultationScheduled': '예약된 진료',
    'homeBannerChipConsultation': '진료',
    'homeBannerChipDiaper': '기저귀',
    'homeBannerChipFeed': '수유',
    'homeBannerChipSleep': '수면',
    'homeBannerOverdueSleep': '잘 시간이 지났어요',
    'homeBannerOverdueWake': '일어날 시간이 지났어요',
    'homeBannerHungry': '배고플 수 있어요',
    'homeBannerDiaperDirty': '더러울 수 있어요',
    'homeBannerExhausted': '지쳤어요',
    'homeBannerChipVaccine': '오늘 예방접종',
    'homeConsultationBannerChip': '진료 · {title} · {t}',
    'feedingLast': '마지막 수유',
    'memoriesProgressSaved': '{total}개 중 {filled}개 순간 저장됨',
    'memoriesCheerEmpty': '+가 있는 배지를 탭해 사진과 이야기를 추가하세요.',
    'feedingNoBabyHint': '먼저 아기를 등록하세요. «더보기 > 등록(엄마와 아기)».',
    'memoriesAlbumPromoTitle': '완성된 추억 앨범',
    'memoriesAlbumPromoSubtitle':
        'FaceBaby 표지와 장식 프레임, 채운 배지까지 담은 PDF를 내려받으세요.',
    'memoriesAlbumDownloadCta': '앨범 PDF 받기',
    'memoriesAlbumGenerating': '앨범 만드는 중…',
    'memoriesAlbumNeedFilled': 'PDF를 만들려면 앨범을 하나 이상 채우세요.',
    'memoriesAlbumError': 'PDF를 만들 수 없습니다.',
    'memoriesAlbumPdfReadyTitle': '앨범 PDF 준비됨',
    'memoriesAlbumShareAction': '공유…',
    'memoriesAlbumSaveAction': '저장 / 다운로드',
    'memoriesAlbumSavedSnack': 'PDF가 기기에 저장되었습니다.',
    'memoriesAlbumSaveFailedSnack': 'PDF를 저장하지 못했습니다.',
    'memoriesAlbumCoverMain': '추억 책',
    'memoriesAlbumCoverTagline': '{name}와(과) 함께한 특별한 순간',
    'memoriesAlbumFooter': 'FaceBaby로 제작',
    'memoriesAlbumBackCoverBody':
        'FaceBaby는 소중한 순간들을 영원한 추억으로 남기기 위해 만들어졌습니다. 아기의 모든 미소, 발견, 포옹, 그리고 특별한 순간들은 사랑과 의미로 간직될 가치가 있습니다.\n\n이 책은 아름다운 성장의 첫걸음을 함께하며, 평생 간직할 수 있는 소중한 기억들을 담기 위해 제작되었습니다.\n\n사진과 메모 그 이상의 의미를 담아, 이 페이지들은 시간이 지나도 사라지지 않을 감정과 이야기를 간직합니다.\n\nFaceBaby가 가족의 이야기에 함께할 수 있도록 해주셔서 감사합니다. 💛',
    'memoriesAlbumBackCoverFinale': '아이들은 너무 빨리 자라지만…\n추억은 영원히 남을 수 있습니다.',
    'vaccNoBabies': '등록된 아기가 없습니다. «더보기 > 등록(엄마와 아기)»으로 이동하세요.',
    'exampleCard': '카드 예시:',
  },
  AppLang.ru: {
    'appName': 'FaceBaby',
    'home': 'Главная',
    'records': 'Записи',
    'reports': 'Отчёты',
    'memories': 'Воспоминания',
    'more': 'Ещё',
    'helloMom': 'Привет, мама!',
    'today': 'Сегодня',
    'shortcuts': 'Быстрые действия',
    'registerNow': 'Записать сейчас',
    'edit': 'Редактировать',
    'todaySummary': 'Итоги дня',
    'nextEvents': 'Следующие события',
    'quickRecordsTitle': 'Быстрые записи',
    'quickRecordsSubtitle': 'Добавляйте события рутины малыша в пару касаний.',
    'whatHappenedNow': 'Что произошло сейчас?',
    'momNote': 'Заметка мамы',
    'saveRecord': 'Сохранить',
    'reportsTitle': 'Отчёты',
    'reportsSubtitle': 'Сводка для мамы и педиатра.',
    'growth': 'Рост',
    'pediatricReport': 'Педиатрический отчёт',
    'pediatricReportDesc':
        'Создайте PDF с весом, сном, кормлением, подгузниками, прививками, симптомами из раздела «Здоровье», визитами и заметками.',
    'reportListPediatric': 'Отчёт для педиатра',
    'reportListPediatricSub': 'PDF и данные для приёма',
    'healthHubSymptomReports': 'Записать симптом',
    'healthHubSymptomReportsSub':
        'Лихорадка, колики, лекарства и др. — в педиатрическом отчёте',
    'symptomReportTitle': 'Записать симптом',
    'symptomReportEmpty': 'Пока нет записей. Нажмите +, чтобы добавить.',
    'symptomReportNew': 'Новая запись',
    'symptomReportSave': 'Сохранить',
    'symptomReportOccurredAt': 'Дата и время',
    'symptomReportPickDateTime': 'Изменить дату и время',
    'symptomReportMedication': 'Принятые лекарства',
    'symptomReportMedicationHint': 'Название или краткая заметка',
    'symptomReportFever': 'Лихорадка',
    'symptomReportTemp': 'Температура',
    'symptomReportTempHint': 'По единицам измерения в настройках',
    'symptomReportCrying': 'Плач без видимой причины',
    'symptomReportPain': 'Боль',
    'symptomReportColic': 'Колики',
    'symptomReportReflux': 'Рефлюкс',
    'symptomReportOther': 'Другое',
    'symptomReportOtherHint': 'Краткое описание',
    'symptomReportValidationNeedOne':
        'Выберите хотя бы один симптом или заполните поле.',
    'symptomReportValidationFeverTemp':
        'Укажите температуру, если отмечена лихорадка.',
    'symptomReportDeleteTitle': 'Удалить запись?',
    'symptomReportDeleteBody': 'Это действие нельзя отменить.',
    'reportPediatricScreenTitle': 'Педиатрический клинический отчёт',
    'reportPediatricPeriodPrefix': 'Период:',
    'reportPediatricFilterHint': 'Период отчёта',
    'reportPediatricDateFrom': 'С',
    'reportPediatricDateTo': 'По',
    'reportPediatricPickRange': 'Выбрать даты',
    'reportPediatricFilterMaxDaysHint':
        'Нажмите, чтобы изменить. Очень длинные диапазоны ограничены 366 днями.',
    'reportPediatricSectionGeneral': 'Общая информация',
    'reportPediatricSectionSummary': 'Сводка за период',
    'reportPediatricSectionSleep': 'Сон',
    'reportPediatricSectionFeeding': 'Питание',
    'reportPediatricSectionSymptoms': 'Симптомы и записи',
    'reportPediatricSectionObservations': 'Наблюдения родителей',
    'reportPediatricLabelName': 'Имя',
    'reportPediatricLabelAge': 'Возраст',
    'reportPediatricLabelBirth': 'Дата рождения',
    'reportPediatricLabelWeightCurrent': 'Вес (последний за период)',
    'reportPediatricLabelHeight': 'Рост',
    'reportPediatricWeightStart': 'Начальный вес (период)',
    'reportPediatricWeightEnd': 'Конечный вес (период)',
    'reportPediatricWeightGain': 'Изменение веса',
    'reportPediatricAvgFeeds': 'Кормлений в день (сред.)',
    'reportPediatricAvgSleep': 'Сна в день (сред.)',
    'reportPediatricAvgDiapers': 'Смен подгузников в день (сред.)',
    'reportPediatricFeverEpisodes': 'Эпизоды лихорадки (структурировано)',
    'reportPediatricFeverNote': 'Примечание',
    'reportPediatricFeverFootnote':
        'Подсчёт из структурированных записей: Здоровье › Записать симптом (с температурой, если указана).',
    'reportPediatricVaccines': 'Прививки за период',
    'reportPediatricMedications':
        'Лекарства (структурированные записи и ключевые слова в заметках)',
    'reportPediatricSleepAvgDaily': 'Средний дневной сон',
    'reportPediatricSleepAwakenings': 'Ночные пробуждения (сред.)',
    'reportPediatricSleepPattern': 'Общий паттерн сна',
    'reportPediatricSleepPatternStable': 'В основном непрерывный',
    'reportPediatricSleepPatternModerate': 'Умеренный',
    'reportPediatricSleepPatternFragmented': 'Более прерывистый',
    'reportPediatricSleepLongest': 'Самый длинный непрерывный сон',
    'reportPediatricFeedingBreast': 'Грудное вскармливание',
    'reportPediatricFeedingFormula': 'Смесь',
    'reportPediatricFeedingSolid': 'Прикорм',
    'reportPediatricFeedingSessions': 'сеансов',
    'reportPediatricFeedingAvgDur': 'средняя длительность',
    'reportPediatricSymptomReflux':
        'Рефлюкс (дневник или структурированные записи)',
    'reportPediatricSymptomColic':
        'Колики (дневник или структурированные записи)',
    'reportPediatricSymptomIrrit': 'Раздражительность (настроение)',
    'reportPediatricIrritHigh': 'Заметнее',
    'reportPediatricIrritMedium': 'Умеренная',
    'reportPediatricIrritLow': 'Слабая',
    'reportPediatricIrritUnknown': 'Нет данных',
    'reportPediatricYes': 'Да',
    'reportPediatricNo': 'Нет',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'Дневные записи',
    'reportPediatricJournalNoteHint': 'Поиск ключевых слов в свободном тексте.',
    'reportPediatricObsHint':
        'Заметки к визиту: симптомы, лекарства, изменения поведения…',
    'reportPediatricBtnShare': 'Поделиться',
    'reportPediatricBtnExportPdf': 'Экспорт PDF',
    'reportPediatricBtnPrint': 'Печать',
    'reportPediatricBtnEmail': 'Почта',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote':
        'Информационная сводка по локальным данным. Не заменяет клиническую оценку.',
    'reportPediatricNone': 'Нет',
    'reportPediatricPdfTitle': 'Педиатрический клинический отчёт — FaceBaby',
    'reportPediatricPdfPeriod': 'Период:',
    'reportPediatricPdfFooter':
        'Создано в FaceBaby. Только данные на этом устройстве (можно офлайн).',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying':
        'Плач без причины (структурированные записи)',
    'reportPediatricSymptomPain': 'Боль (структурированные записи)',
    'reportPediatricStructuredSymptoms':
        'Структурированные записи симптомов (дата и время)',
    'reportPediatricStructuredSymptomsEmpty':
        'За этот период нет структурированных записей.',
    'generatePdf': 'Сгенерировать PDF',
    'reportMonthlyMilestonesTitle': 'Вехи месяца',
    'reportMonthlyMilestonesEmpty':
        'Нет прививок, визитов к врачу или воспоминаний со значком за этот месяц.',
    'reportMonthlyMilestoneConsultationDefault': 'Приём',
    'memoriesTitle': 'Книга воспоминаний',
    'memoriesSubtitle': 'Важные моменты, чтобы сохранить их.',
    'addMemory': 'Добавить воспоминание',
    'settingsTitle': 'Ещё',
    'registerMotherBaby': 'Регистрация (мама и малыш)',
    'vaccinesCard': 'Прививки (карта)',
    'language': 'Язык',
    'settingsSoonTitle': 'Скоро',
    'settingsSoonBadge': 'Скоро',
    'settingsRateUs': 'Оцените нас',
    'settingsTermsOfUse': 'Условия использования',
    'settingsPrivacyPolicy': 'Политика конфиденциальности',
    'settingsSpecialThanks': 'Особые благодарности',
    'settingsTellFriend': 'Рассказать другу',
    'vaccinesTitle': 'Прививки',
    'vaccinesSubtitle': 'Добавляйте прививки, даты и следующие дозы.',
    'baby': 'Малыш',
    'selectBaby': 'Выбрать малыша',
    'addVaccine': 'Добавить прививку',
    'recordsTitle': 'Записи',
    'noVaccinesYet': 'Пока нет прививок.',
    'seeAll': 'Показать все',
    'changePhoto': 'Сменить фото',
    'motherPhotoTitle': 'Фото мамы',
    'babyPhotoTitle': 'Фото малыша',
    'changeBabyTooltip': 'Сменить малыша',
    'helloMomNamed': 'Привет, мама {name}!',
    'registerVerb': 'Записать',
    'viewCalendar': 'Календарь',
    'shortcutMilk': 'Кормление',
    'shortcutSleep': 'Сон',
    'shortcutVaccines': 'Прививки',
    'homeFedAgo': 'Кормили {when} назад',
    'homePeeAgo': 'Писал {when} назад',
    'homePooAgo': 'Какал {when} назад',
    'homeNextNow': 'След.: сейчас.',
    'homeNextIn': 'След. через {n} мин.',
    'homeStatusOk': 'Всё хорошо',
    'homeStatusWarn': 'Лёгкое внимание',
    'homeStatusHungry': 'Может быть голоден',
    'homeTipTitle': 'Совет на сегодня',
    'homeTipBody': 'Лёгкие рутины помогают {name} лучше спать ночью.',
    'summaryFeedings': 'КОРМЛЕНИЯ',
    'summarySleep': 'СОН ВСЕГО',
    'summaryLastFeed': 'Последнее в {time}',
    'summaryLastSleep': 'Последний в {time}',
    'exampleCard': 'Пример карты:',
  },
  AppLang.tr: {
    'appName': 'FaceBaby',
    'home': 'Ana sayfa',
    'records': 'Kayıtlar',
    'reports': 'Raporlar',
    'memories': 'Anılar',
    'more': 'Daha',
    'helloMom': 'Merhaba anne!',
    'today': 'Bugün',
    'shortcuts': 'Kısayollar',
    'registerNow': 'Şimdi kaydet',
    'edit': 'Düzenle',
    'todaySummary': 'Bugünün özeti',
    'nextEvents': 'Sonraki etkinlikler',
    'quickRecordsTitle': 'Hızlı kayıtlar',
    'quickRecordsSubtitle': 'Bebeğin rutinini birkaç dokunuşla ekleyin.',
    'whatHappenedNow': 'Az önce ne oldu?',
    'momNote': 'Anne notu',
    'saveRecord': 'Kaydet',
    'reportsTitle': 'Raporlar',
    'reportsSubtitle': 'Anne ve çocuk doktoru için özet.',
    'growth': 'Büyüme',
    'pediatricReport': 'Pediatrik rapor',
    'pediatricReportDesc':
        'Kilo, uyku, beslenme, bez, aşılar, Sağlık bölümünde kaydedilen semptomlar, randevular ve notlarla PDF oluşturun.',
    'reportListPediatric': 'Çocuk doktoru için rapor',
    'reportListPediatricSub': 'Muayene için PDF ve veriler',
    'healthHubSymptomReports': 'Semptom kaydet',
    'healthHubSymptomReportsSub':
        'Ateş, kolik, ilaçlar ve daha fazlası — pediatrik rapora dahil',
    'symptomReportTitle': 'Semptom kaydet',
    'symptomReportEmpty': 'Henüz kayıt yok. Eklemek için + dokunun.',
    'symptomReportNew': 'Yeni kayıt',
    'symptomReportSave': 'Kaydet',
    'symptomReportOccurredAt': 'Tarih ve saat',
    'symptomReportPickDateTime': 'Tarih ve saati değiştir',
    'symptomReportMedication': 'Alınan ilaçlar',
    'symptomReportMedicationHint': 'Ad veya kısa not',
    'symptomReportFever': 'Ateş',
    'symptomReportTemp': 'Sıcaklık',
    'symptomReportTempHint': 'Ayarlarınızdaki birimlere göre',
    'symptomReportCrying': 'Belirsiz ağlama',
    'symptomReportPain': 'Ağrı',
    'symptomReportColic': 'Kolik',
    'symptomReportReflux': 'Reflü',
    'symptomReportOther': 'Diğer',
    'symptomReportOtherHint': 'Kısa açıklama',
    'symptomReportValidationNeedOne':
        'En az bir semptom seçin veya bir alan doldurun.',
    'symptomReportValidationFeverTemp': 'Ateş işaretliyken sıcaklığı girin.',
    'symptomReportDeleteTitle': 'Kayıt silinsin mi?',
    'symptomReportDeleteBody': 'Bu işlem geri alınamaz.',
    'reportPediatricScreenTitle': 'Pediatrik klinik rapor',
    'reportPediatricPeriodPrefix': 'Dönem:',
    'reportPediatricFilterHint': 'Rapor dönemi',
    'reportPediatricDateFrom': 'Başlangıç',
    'reportPediatricDateTo': 'Bitiş',
    'reportPediatricPickRange': 'Tarih seç',
    'reportPediatricFilterMaxDaysHint':
        'Değiştirmek için dokunun. Çok uzun aralıklar 366 günle sınırlıdır.',
    'reportPediatricSectionGeneral': 'Genel bilgiler',
    'reportPediatricSectionSummary': 'Dönem özeti',
    'reportPediatricSectionSleep': 'Uyku',
    'reportPediatricSectionFeeding': 'Beslenme',
    'reportPediatricSectionSymptoms': 'Semptomlar ve kayıtlar',
    'reportPediatricSectionObservations': 'Ebeveyn gözlemleri',
    'reportPediatricLabelName': 'Ad',
    'reportPediatricLabelAge': 'Yaş',
    'reportPediatricLabelBirth': 'Doğum tarihi',
    'reportPediatricLabelWeightCurrent': 'Kilo (dönemdeki son)',
    'reportPediatricLabelHeight': 'Boy',
    'reportPediatricWeightStart': 'Başlangıç kilosu (dönem)',
    'reportPediatricWeightEnd': 'Bitiş kilosu (dönem)',
    'reportPediatricWeightGain': 'Kilo değişimi',
    'reportPediatricAvgFeeds': 'Günlük beslenme (ortalama)',
    'reportPediatricAvgSleep': 'Günlük uyku (ortalama)',
    'reportPediatricAvgDiapers': 'Günlük bez değişimi (ortalama)',
    'reportPediatricFeverEpisodes': 'Ateş epizotları (yapılandırılmış)',
    'reportPediatricFeverNote': 'Not',
    'reportPediatricFeverFootnote':
        'Sağlık › Semptom kaydet altındaki yapılandırılmış kayıtlardan sayım (sıcaklık varsa).',
    'reportPediatricVaccines': 'Dönemdeki aşılar',
    'reportPediatricMedications':
        'İlaçlar (yapılandırılmış kayıt ve notlarda anahtar kelimeler)',
    'reportPediatricSleepAvgDaily': 'Günlük ortalama uyku',
    'reportPediatricSleepAwakenings': 'Gece uyanmaları (ortalama)',
    'reportPediatricSleepPattern': 'Genel uyku düzeni',
    'reportPediatricSleepPatternStable': 'Çoğunlukla kesintisiz',
    'reportPediatricSleepPatternModerate': 'Orta',
    'reportPediatricSleepPatternFragmented': 'Daha parçalı',
    'reportPediatricSleepLongest': 'En uzun kesintisiz uyku',
    'reportPediatricFeedingBreast': 'Emzirme',
    'reportPediatricFeedingFormula': 'Mama',
    'reportPediatricFeedingSolid': 'Katı gıda',
    'reportPediatricFeedingSessions': 'oturum',
    'reportPediatricFeedingAvgDur': 'ortalama süre',
    'reportPediatricSymptomReflux': 'Reflü (günlük veya yapılandırılmış)',
    'reportPediatricSymptomColic': 'Kolik (günlük veya yapılandırılmış)',
    'reportPediatricSymptomIrrit': 'Huzursuzluk (mod)',
    'reportPediatricIrritHigh': 'Daha belirgin',
    'reportPediatricIrritMedium': 'Orta',
    'reportPediatricIrritLow': 'Hafif',
    'reportPediatricIrritUnknown': 'Veri yok',
    'reportPediatricYes': 'Evet',
    'reportPediatricNo': 'Hayır',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': 'Günlük notlar',
    'reportPediatricJournalNoteHint':
        'Serbest metinde anahtar kelime algılama.',
    'reportPediatricObsHint':
        'Muayene için notlar: semptomlar, ilaçlar, davranış değişiklikleri…',
    'reportPediatricBtnShare': 'Paylaş',
    'reportPediatricBtnExportPdf': 'PDF dışa aktar',
    'reportPediatricBtnPrint': 'Yazdır',
    'reportPediatricBtnEmail': 'E-posta',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote':
        'Yerel kayıtlardan bilgilendirici özet. Klinik değerlendirmenin yerini tutmaz.',
    'reportPediatricNone': 'Yok',
    'reportPediatricPdfTitle': 'Pediatrik klinik rapor — FaceBaby',
    'reportPediatricPdfPeriod': 'Dönem:',
    'reportPediatricPdfFooter':
        'FaceBaby’de oluşturuldu. Yalnızca bu cihazdaki veriler (çevrimdışı mümkün).',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': 'Belirsiz ağlama (yapılandırılmış)',
    'reportPediatricSymptomPain': 'Ağrı (yapılandırılmış)',
    'reportPediatricStructuredSymptoms':
        'Yapılandırılmış semptom kayıtları (tarih ve saat)',
    'reportPediatricStructuredSymptomsEmpty':
        'Bu dönemde yapılandırılmış kayıt yok.',
    'generatePdf': 'PDF oluştur',
    'reportMonthlyMilestonesTitle': 'Ayın kilometre taşları',
    'reportMonthlyMilestonesEmpty': 'Bu ay aşı, muayene veya rozetli anı yok.',
    'reportMonthlyMilestoneConsultationDefault': 'Muayene',
    'memoriesTitle': 'Anı defteri',
    'memoriesSubtitle': 'Önemli anları saklayın.',
    'addMemory': 'Anı ekle',
    'settingsTitle': 'Daha',
    'registerMotherBaby': 'Kayıt (anne & bebek)',
    'vaccinesCard': 'Aşılar (kart)',
    'language': 'Dil',
    'settingsSoonTitle': 'Çok yakında',
    'settingsSoonBadge': 'Yakında',
    'settingsRateUs': 'Bizi değerlendirin',
    'settingsTermsOfUse': 'Kullanım şartları',
    'settingsPrivacyPolicy': 'Gizlilik politikası',
    'settingsSpecialThanks': 'Özel teşekkürler',
    'settingsTellFriend': 'Bir arkadaşına anlat',
    'vaccinesTitle': 'Aşılar',
    'vaccinesSubtitle': 'Aşı, tarih ve sonraki dozu ekleyin.',
    'baby': 'Bebek',
    'selectBaby': 'Bebeği seç',
    'addVaccine': 'Aşı ekle',
    'recordsTitle': 'Kayıtlar',
    'noVaccinesYet': 'Henüz aşı yok.',
    'seeAll': 'Tümünü gör',
    'changePhoto': 'Fotoğrafı değiştir',
    'motherPhotoTitle': 'Anne fotoğrafı',
    'babyPhotoTitle': 'Bebek fotoğrafı',
    'changeBabyTooltip': 'Bebeği değiştir',
    'helloMomNamed': 'Merhaba anne {name}!',
    'registerVerb': 'Kaydet',
    'viewCalendar': 'Takvimi gör',
    'shortcutMilk': 'Emzirme',
    'shortcutSleep': 'Uyku',
    'shortcutVaccines': 'Aşılar',
    'homeFedAgo': '{when} önce emdi',
    'homePeeAgo': '{when} önce çiş',
    'homePooAgo': '{when} önce kaka',
    'homeNextNow': 'Sıradaki: şimdi.',
    'homeNextIn': '{n} dk sonra.',
    'homeStatusOk': 'Her şey yolunda',
    'homeStatusWarn': 'Hafif uyarı',
    'homeStatusHungry': 'Aç olabilir',
    'homeTipTitle': 'Bugünün ipucu',
    'homeTipBody':
        'Hafif rutinler {name}’ın geceleri daha iyi uyumasını sağlar.',
    'summaryFeedings': 'EMZİRME',
    'summarySleep': 'TOPLAM UYKU',
    'summaryLastFeed': 'Son {time}',
    'summaryLastSleep': 'Son {time}',
    'exampleCard': 'Kart örneği:',
  },
  AppLang.zh: {
    'appName': 'FaceBaby',
    'home': '首页',
    'records': '记录',
    'reports': '报告',
    'memories': '回忆',
    'more': '更多',
    'helloMom': '你好，妈妈！',
    'today': '今天',
    'shortcuts': '快捷方式',
    'registerNow': '立即记录',
    'edit': '编辑',
    'todaySummary': '今日总结',
    'nextEvents': '接下来事项',
    'quickRecordsTitle': '快速记录',
    'quickRecordsSubtitle': '几次点击即可添加宝宝日常。',
    'whatHappenedNow': '刚刚发生了什么？',
    'momNote': '妈妈备注',
    'saveRecord': '保存',
    'reportsTitle': '报告',
    'reportsSubtitle': '给妈妈和儿科医生的总结。',
    'growth': '成长',
    'pediatricReport': '儿科报告',
    'pediatricReportDesc': '生成包含体重、睡眠、喂养、尿布、疫苗、在「健康」中记录的症状、就诊与备注的PDF。',
    'reportListPediatric': '儿科门诊报告',
    'reportListPediatricSub': '就诊用的PDF与数据',
    'healthHubSymptomReports': '记录症状',
    'healthHubSymptomReportsSub': '发热、肠绞痛、用药等 — 纳入儿科报告',
    'symptomReportTitle': '记录症状',
    'symptomReportEmpty': '暂无记录。点按 + 添加。',
    'symptomReportNew': '新建记录',
    'symptomReportSave': '保存',
    'symptomReportOccurredAt': '日期与时间',
    'symptomReportPickDateTime': '更改日期与时间',
    'symptomReportMedication': '已服药物',
    'symptomReportMedicationHint': '名称或简短备注',
    'symptomReportFever': '发热',
    'symptomReportTemp': '体温',
    'symptomReportTempHint': '遵循设置中的单位',
    'symptomReportCrying': '无故哭闹',
    'symptomReportPain': '疼痛',
    'symptomReportColic': '肠绞痛',
    'symptomReportReflux': '反流',
    'symptomReportOther': '其他',
    'symptomReportOtherHint': '简短描述',
    'symptomReportValidationNeedOne': '请至少选择一项症状或填写字段。',
    'symptomReportValidationFeverTemp': '勾选发热时请填写体温。',
    'symptomReportDeleteTitle': '删除记录？',
    'symptomReportDeleteBody': '此操作无法撤销。',
    'reportPediatricScreenTitle': '儿科临床报告',
    'reportPediatricPeriodPrefix': '时间段：',
    'reportPediatricFilterHint': '报告时间段',
    'reportPediatricDateFrom': '从',
    'reportPediatricDateTo': '至',
    'reportPediatricPickRange': '选择日期',
    'reportPediatricFilterMaxDaysHint': '点按更改。过长区间上限为366天。',
    'reportPediatricSectionGeneral': '基本信息',
    'reportPediatricSectionSummary': '时间段摘要',
    'reportPediatricSectionSleep': '睡眠',
    'reportPediatricSectionFeeding': '喂养',
    'reportPediatricSectionSymptoms': '症状与记录',
    'reportPediatricSectionObservations': '家长观察',
    'reportPediatricLabelName': '姓名',
    'reportPediatricLabelAge': '年龄',
    'reportPediatricLabelBirth': '出生日期',
    'reportPediatricLabelWeightCurrent': '体重（期内最近）',
    'reportPediatricLabelHeight': '身高',
    'reportPediatricWeightStart': '期初体重',
    'reportPediatricWeightEnd': '期末体重',
    'reportPediatricWeightGain': '体重变化',
    'reportPediatricAvgFeeds': '每日喂养次数（平均）',
    'reportPediatricAvgSleep': '每日睡眠（平均）',
    'reportPediatricAvgDiapers': '每日换尿布（平均）',
    'reportPediatricFeverEpisodes': '发热次数（结构化记录）',
    'reportPediatricFeverNote': '说明',
    'reportPediatricFeverFootnote': '统计自「健康 › 记录症状」的结构化条目（含体温时）。',
    'reportPediatricVaccines': '期内接种疫苗',
    'reportPediatricMedications': '药物（结构化记录与备注关键词）',
    'reportPediatricSleepAvgDaily': '日均睡眠',
    'reportPediatricSleepAwakenings': '夜间醒来（平均）',
    'reportPediatricSleepPattern': '睡眠总体模式',
    'reportPediatricSleepPatternStable': '多为连续',
    'reportPediatricSleepPatternModerate': '中等',
    'reportPediatricSleepPatternFragmented': '更易间断',
    'reportPediatricSleepLongest': '最长连续睡眠',
    'reportPediatricFeedingBreast': '母乳',
    'reportPediatricFeedingFormula': '配方奶',
    'reportPediatricFeedingSolid': '辅食',
    'reportPediatricFeedingSessions': '次',
    'reportPediatricFeedingAvgDur': '平均时长',
    'reportPediatricSymptomReflux': '反流（日记或结构化记录）',
    'reportPediatricSymptomColic': '肠绞痛（日记或结构化记录）',
    'reportPediatricSymptomIrrit': '易激惹（情绪）',
    'reportPediatricIrritHigh': '较明显',
    'reportPediatricIrritMedium': '中等',
    'reportPediatricIrritLow': '较轻',
    'reportPediatricIrritUnknown': '无数据',
    'reportPediatricYes': '是',
    'reportPediatricNo': '否',
    'reportPediatricNa': '-',
    'reportPediatricJournalNote': '当日日记',
    'reportPediatricJournalNoteHint': '自由文本关键词检测。',
    'reportPediatricObsHint': '就诊备注：症状、用药、行为变化等…',
    'reportPediatricBtnShare': '分享',
    'reportPediatricBtnExportPdf': '导出PDF',
    'reportPediatricBtnPrint': '打印',
    'reportPediatricBtnEmail': '电子邮件',
    'reportPediatricBtnWhatsApp': 'WhatsApp',
    'reportPediatricScreenFootnote': '基于本机记录的信息摘要，不能替代临床评估。',
    'reportPediatricNone': '无',
    'reportPediatricPdfTitle': '儿科临床报告 — FaceBaby',
    'reportPediatricPdfPeriod': '时间段：',
    'reportPediatricPdfFooter': '由 FaceBaby 生成，仅限本机存储的数据（可离线）。',
    'reportPediatricFeverDisclaimerShort': '0',
    'reportPediatricSymptomCrying': '无故哭闹（结构化）',
    'reportPediatricSymptomPain': '疼痛（结构化）',
    'reportPediatricStructuredSymptoms': '结构化症状记录（日期与时间）',
    'reportPediatricStructuredSymptomsEmpty': '本时间段无结构化记录。',
    'generatePdf': '生成PDF',
    'reportMonthlyMilestonesTitle': '本月里程碑',
    'reportMonthlyMilestonesEmpty': '本月尚无疫苗、就诊或带徽章的回忆。',
    'reportMonthlyMilestoneConsultationDefault': '就诊',
    'memoriesTitle': '回忆册',
    'memoriesSubtitle': '把重要时刻保存下来。',
    'addMemory': '添加回忆',
    'settingsTitle': '更多',
    'registerMotherBaby': '注册（妈妈和宝宝）',
    'vaccinesCard': '疫苗（卡片）',
    'language': '语言',
    'settingsSoonTitle': '即将推出',
    'settingsSoonBadge': '即将',
    'settingsRateUs': '给我们评分',
    'settingsTermsOfUse': '使用条款',
    'settingsPrivacyPolicy': '隐私政策',
    'settingsSpecialThanks': '特别鸣谢',
    'settingsTellFriend': '告诉朋友',
    'vaccinesTitle': '疫苗',
    'vaccinesSubtitle': '添加疫苗、日期和下次接种。',
    'baby': '宝宝',
    'selectBaby': '选择宝宝',
    'addVaccine': '添加疫苗',
    'recordsTitle': '记录',
    'noVaccinesYet': '暂无疫苗记录。',
    'seeAll': '查看全部',
    'changePhoto': '更换照片',
    'motherPhotoTitle': '妈妈照片',
    'babyPhotoTitle': '宝宝照片',
    'changeBabyTooltip': '切换宝宝',
    'helloMomNamed': '你好，妈妈 {name}！',
    'registerVerb': '记录',
    'viewCalendar': '查看日历',
    'shortcutMilk': '喂奶',
    'shortcutSleep': '睡眠',
    'shortcutVaccines': '疫苗',
    'homeFedAgo': '{when}前喂过',
    'homePeeAgo': '{when}前小便',
    'homePooAgo': '{when}前大便',
    'homeNextNow': '下次：现在。',
    'homeNextIn': '{n}分钟后。',
    'homeStatusOk': '一切正常',
    'homeStatusWarn': '轻微提醒',
    'homeStatusHungry': '可能饿了',
    'homeTipTitle': '今日提示',
    'homeTipBody': '轻松的规律有助于{name}夜间睡得更好。',
    'summaryFeedings': '喂奶',
    'summarySleep': '总睡眠',
    'summaryLastFeed': '上次 {time}',
    'summaryLastSleep': '上次 {time}',
    'exampleCard': '卡片示例：',
  },
};
