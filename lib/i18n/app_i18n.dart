import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory_badge.dart';
import 'development_leaps_translated.dart';

// Common languages across Play Store / App Store audiences.
// (We keep pt/en/es plus: fr, de, it, hi, id, ja, ko, ru, tr, zh)
enum AppLang { pt, en, es, fr, de, it, hi, id, ja, ko, ru, tr, zh }

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
          if (_lang != v) {
            _lang = v;
            notifyListeners();
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
    switch (code) {
      case 'pt':
        return AppLang.pt;
      case 'en':
        return AppLang.en;
      case 'es':
        return AppLang.es;
      case 'fr':
        return AppLang.fr;
      case 'de':
        return AppLang.de;
      case 'it':
        return AppLang.it;
      case 'hi':
        return AppLang.hi;
      case 'id':
        return AppLang.id;
      case 'ja':
        return AppLang.ja;
      case 'ko':
        return AppLang.ko;
      case 'ru':
        return AppLang.ru;
      case 'tr':
        return AppLang.tr;
      case 'zh':
      case 'cmn':
        return AppLang.zh;
      default:
        return AppLang.en;
    }
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
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
    unawaited(_persistLang());
  }

  Future<void> _persistLang() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _lang.name);
  }
}

class AppI18nScope extends InheritedNotifier<AppLanguageController> {
  const AppI18nScope({super.key, required super.notifier, required super.child});

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
  String get growth => _t('growth');
  String get pediatricReport => _t('pediatricReport');
  String get pediatricReportDesc => _t('pediatricReportDesc');
  String get generatePdf => _t('generatePdf');

  String get memoriesTitle => _t('memoriesTitle');
  String get memoriesSubtitle => _t('memoriesSubtitle');
  String memoriesProgressSaved(int filled, int total) =>
      _t('memoriesProgressSaved').replaceAll('{filled}', '$filled').replaceAll('{total}', '$total');
  String get memoriesCheerEmpty => _t('memoriesCheerEmpty');
  String get memoriesAlbumPromoTitle => _t('memoriesAlbumPromoTitle');
  String get memoriesAlbumPromoSubtitle => _t('memoriesAlbumPromoSubtitle');
  String get memoriesAlbumDownloadCta => _t('memoriesAlbumDownloadCta');
  String get memoriesAlbumGenerating => _t('memoriesAlbumGenerating');
  String get memoriesAlbumNeedFilled => _t('memoriesAlbumNeedFilled');
  String get memoriesAlbumError => _t('memoriesAlbumError');
  String get memoriesAlbumCoverMain => _t('memoriesAlbumCoverMain');
  String memoriesAlbumCoverTagline(String name) =>
      _t('memoriesAlbumCoverTagline').replaceAll('{name}', name);
  String get memoriesAlbumFooter => _t('memoriesAlbumFooter');
  String get addMemory => _t('addMemory');

  String get memoryBadgeMonthOne => _t('memoryBadgeMonthOne');
  String memoryBadgeMonthsMany(int n) => _t('memoryBadgeMonthsMany').replaceAll('{n}', '$n');
  String get memoryBadgeYearOne => _t('memoryBadgeYearOne');
  String memoryBadgeYearsMany(int n) => _t('memoryBadgeYearsMany').replaceAll('{n}', '$n');

  /// Título do selo no Livro de memórias para o idioma atual.
  String memoryBadgeTitle(MemoryBadge badge) {
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
  String dailyJournalOnDate(String date) => _t('dailyJournalOnDate').replaceAll('{d}', date);
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
  String get settingsTermsOfUse => _t('settingsTermsOfUse');
  String get settingsPrivacyPolicy => _t('settingsPrivacyPolicy');
  String get settingsSpecialThanks => _t('settingsSpecialThanks');
  String get settingsTellFriend => _t('settingsTellFriend');
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
  String get authErrInvalidCredential => _t('authErrInvalidCredential');
  String get authErrCredentialsGeneric => _t('authErrCredentialsGeneric');
  String get authErrGoogleConfigAndroid => _t('authErrGoogleConfigAndroid');
  String get authErrLoginCancelled => _t('authErrLoginCancelled');
  String get authErrUnexpected => _t('authErrUnexpected');

  /// Mensagens de erro de login/registo alinhadas ao idioma atual.
  String userFacingAuthError(Object error) {
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
        case 'email-already-in-use':
          return authErrEmailInUse;
        case 'invalid-credential':
        case 'invalid-verification-code':
        case 'invalid-verification-id':
          return authErrInvalidCredential;
        default:
          return authErrCredentialsGeneric;
      }
    }
    final s = error.toString();
    if (s.contains('ApiException: 10') || s.contains('DEVELOPER_ERROR') || s.contains('sign_in_failed')) {
      return authErrGoogleConfigAndroid;
    }
    if (s.contains('Login cancelado') ||
        s.contains('login canceled') ||
        s.contains('Login canceled') ||
        s.contains('sign_in_canceled') ||
        s.contains('SIGN_IN_CANCELED')) {
      return authErrLoginCancelled;
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
  String get babyPhotoTitle => _t('babyPhotoTitle');
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
  String get deleteAccountReauthPasswordHint => _t('deleteAccountReauthPasswordHint');
  String get deleteAccountReauthGoogle => _t('deleteAccountReauthGoogle');
  String get deleteAccountReauthContinue => _t('deleteAccountReauthContinue');
  String get deleteAccountReauthCantPassword => _t('deleteAccountReauthCantPassword');
  String get homeBabyBannerForecastSleep => _t('homeBabyBannerForecastSleep');
  String get homeBabyBannerForecastWake => _t('homeBabyBannerForecastWake');
  String get homeBabyBannerForecastSubtitleSleep => _t('homeBabyBannerForecastSubtitleSleep');
  String get homeBabyBannerForecastSubtitleWake => _t('homeBabyBannerForecastSubtitleWake');
  String homeBabyBannerEtaIn(String d) => _t('homeBabyBannerEtaIn').replaceAll('{d}', d);
  String get homeBabyBannerLastDiaper => _t('homeBabyBannerLastDiaper');
  String get homeBabyBannerNoRecordsYet => _t('homeBabyBannerNoRecordsYet');
  String homeBabyBannerNextBetween(String range) => _t('homeBabyBannerNextBetween').replaceAll('{range}', range);
  String homeBabyBannerDiaperRecommendedUntil(String d) =>
      _t('homeBabyBannerDiaperRecommendedUntil').replaceAll('{d}', d);
  String homeBabyBannerIdealWindow(String range) => _t('homeBabyBannerIdealWindow').replaceAll('{range}', range);
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
  String get memorySharePlatformUnavailable => _t('memorySharePlatformUnavailable');
  String memoryShareError(Object e) => _t('memoryShareError').replaceAll('{error}', '$e');

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
  String memorySuggestedAgeBetween({required DateTime birth, required DateTime when}) {
    final days = when.difference(DateTime(birth.year, birth.month, birth.day)).inDays;
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
  String summaryFeedingsValue(int n, int minutes) =>
      _t('summaryFeedingsValue').replaceAll('{n}', '$n').replaceAll('{m}', '$minutes');
  String summaryFeedingsCount(int n) =>
      (n == 1 ? _t('summaryFeedingsCountOne') : _t('summaryFeedingsCountMany')).replaceAll('{n}', '$n');
  String summaryFeedingsMinutes(int minutes) => _t('summaryFeedingsMinutes').replaceAll('{m}', '$minutes');
  String summaryDiapersValue(int total, int pee, int poo) => _t('summaryDiapersValue')
      .replaceAll('{total}', '$total')
      .replaceAll('{pee}', '$pee')
      .replaceAll('{poo}', '$poo');
  String summaryDiapersTotal(int total) => _t('summaryDiapersTotal').replaceAll('{total}', '$total');
  String summaryDiapersChanges(int n) =>
      (n == 1 ? _t('summaryDiapersChangesOne') : _t('summaryDiapersChangesMany')).replaceAll('{n}', '$n');
  String summaryDiapersPeePoo(int pee, int poo) =>
      _t('summaryDiapersPeePoo').replaceAll('{pee}', '$pee').replaceAll('{poo}', '$poo');
  String summarySleepValue(int sessions, String totalCompact) =>
      _t('summarySleepValue').replaceAll('{s}', '$sessions').replaceAll('{t}', totalCompact);
  String summarySleepSessions(int sessions) =>
      (sessions == 1 ? _t('summarySleepSessionsOne') : _t('summarySleepSessionsMany')).replaceAll('{s}', '$sessions');
  String get homeSummaryExtraHint => _t('homeSummaryExtraHint');
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
  String homeCriticalCareCount(int n) => _t('homeCriticalCareCount').replaceAll('{n}', '$n');
  String get homeCriticalFeedingTitle => _t('homeCriticalFeedingTitle');
  String get homeCriticalSleepTitle => _t('homeCriticalSleepTitle');
  String get homeCriticalDiaperTitle => _t('homeCriticalDiaperTitle');
  String get homeCriticalFeedingSubtitle => _t('homeCriticalFeedingSubtitle');
  String get homeCriticalSleepSubtitle => _t('homeCriticalSleepSubtitle');
  String get homeCriticalDiaperSubtitle => _t('homeCriticalDiaperSubtitle');
  String get homeSleepBarAwakeTitle => _t('homeSleepBarAwakeTitle');
  String get homeSleepBarSleepTitle => _t('homeSleepBarSleepTitle');
  String get homeFeedingCounterTitle => _t('homeFeedingCounterTitle');
  String get homeFeedingCounterHint => _t('homeFeedingCounterHint');
  String homeSleepBarAwakeHintEarly(int m) => _t('homeSleepBarAwakeHintEarly').replaceAll('{m}', '$m');
  String homeSleepBarAwakeHintIdeal(int m) => _t('homeSleepBarAwakeHintIdeal').replaceAll('{m}', '$m');
  String get homeSleepBarAwakeHintOverdue => _t('homeSleepBarAwakeHintOverdue');
  String homeSleepBarSleepHint(String remaining, int cap) =>
      _t('homeSleepBarSleepHint').replaceAll('{remaining}', remaining).replaceAll('{cap}', '$cap');
  String get homeSleepBarNeedLastSleep => _t('homeSleepBarNeedLastSleep');

  String helloMomNamed(String name) => _t('helloMomNamed').replaceAll('{name}', name.trim());
  String homeFedAgo(String when) => _t('homeFedAgo').replaceAll('{when}', when);
  String homePeeAgo(String when) => _t('homePeeAgo').replaceAll('{when}', when);
  String homePooAgo(String when) => _t('homePooAgo').replaceAll('{when}', when);
  String homeNextIn(int n) => _t('homeNextIn').replaceAll('{n}', '$n');
  String summaryLastFeed(String time) => _t('summaryLastFeed').replaceAll('{time}', time);
  String summaryLastSleep(String time) => _t('summaryLastSleep').replaceAll('{time}', time);
  String homeTipBody(String name) => _t('homeTipBody').replaceAll('{name}', name);
  String get homeGreetingSubtitle => _t('homeGreetingSubtitle');
  String get homeMotivationBanner => _t('homeMotivationBanner');
  String get homeMotivationBannerOpenMemories => _t('homeMotivationBannerOpenMemories');
  String get summaryWeightNotYet => _t('summaryWeightNotYet');
  String get summarySleepNotYet => _t('summarySleepNotYet');
  String get shortcutMilkHomeSub => _t('shortcutMilkHomeSub');
  String get shortcutGrowthHomeSub => _t('shortcutGrowthHomeSub');
  String get shortcutSleepHomeSub => _t('shortcutSleepHomeSub');
  String get homeTileDiapers => _t('homeTileDiapers');
  String homeDaysOld(int days) =>
      days == 1 ? _t('homeOneDayOld') : _t('homeDaysOld').replaceAll('{d}', '$days');

  /// Idade do bebé no cartão/banner (dias → semanas → meses → anos), conforme o idioma.
  String babyAgeLabel(DateTime birthDate, DateTime now) {
    final days = now.difference(birthDate).inDays;
    if (days < 0) return '—';
    if (days < 7) return homeDaysOld(days);
    final weeks = (days / 7).floor();
    if (weeks < 8) {
      return weeks == 1 ? _t('babyAgeOneWeek') : _t('babyAgeWeeks').replaceAll('{n}', '$weeks');
    }
    final months = (days / 30).floor();
    if (months < 24) {
      return months == 1 ? _t('babyAgeOneMonth') : _t('babyAgeMonths').replaceAll('{n}', '$months');
    }
    final years = (days / 365).floor();
    return years == 1 ? _t('babyAgeOneYear') : _t('babyAgeYears').replaceAll('{n}', '$years');
  }

  String homeSummaryOnDate(String date) => _t('homeSummaryOnDate').replaceAll('{date}', date);
  String get homeSummaryPickDayTooltip => _t('homeSummaryPickDayTooltip');
  String homeFedAt(String time) => _t('homeFedAt').replaceAll('{time}', time);
  String homePeeAt(String time) => _t('homePeeAt').replaceAll('{time}', time);
  String homePooAt(String time) => _t('homePooAt').replaceAll('{time}', time);
  String homeDiaperChangeAgo(String when) => _t('homeDiaperChangeAgo').replaceAll('{when}', when);
  String homeDiaperChangeAt(String time) => _t('homeDiaperChangeAt').replaceAll('{time}', time);
  String homeSleepEndedAgo(String when) => _t('homeSleepEndedAgo').replaceAll('{when}', when);
  String homeSleepEndedAt(String time) => _t('homeSleepEndedAt').replaceAll('{time}', time);
  String homeSleepInProgress(String elapsed) => _t('homeSleepInProgress').replaceAll('{elapsed}', elapsed);
  String homeSleepPausedBanner(String elapsed) => _t('homeSleepPausedBanner').replaceAll('{elapsed}', elapsed);
  String get sleepBannerEmpty => _t('sleepBannerEmpty');

  String growthHistoryTitle(String label) => _t('growthHistoryTitle').replaceAll('{label}', label);
  String invalidGrowthValue(String label) => _t('invalidGrowthValue').replaceAll('{label}', label);
  String growthSaved(String label) => _t('growthSaved').replaceAll('{label}', label);
  String growthEmpty(String label) => _t('growthEmpty').replaceAll('{label}', label);
  String get notifyGrowthWeightDownTitle => _t('notifyGrowthWeightDownTitle');
  String get notifyGrowthWeightDownBody => _t('notifyGrowthWeightDownBody');
  String get notifyGrowthStaleTitle => _t('notifyGrowthStaleTitle');
  String notifyGrowthStaleBody(int days) => _t('notifyGrowthStaleBody').replaceAll('{days}', '$days');
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
      _t('growthChartCaption').replaceAll('{name}', name).replaceAll('{metric}', metric);
  String get growthChartDeltaHint => _t('growthChartDeltaHint');
  String feedingAgoMinutes(int m) => _t('feedingAgoMinutes').replaceAll('{m}', '$m');
  String feedingAgoHours(int h, String mPadded) => _t('feedingAgoHours').replaceAll('{h}', '$h').replaceAll('{m}', mPadded);
  String feedingNextInMinutes(int n) => _t('feedingNextIn').replaceAll('{n}', '$n');
  String feedingHistoryLine(int minutes, String side) =>
      _t('feedingHistoryLine').replaceAll('{time}', '$minutes').replaceAll('{side}', side);
  String feedingAvgDurMinutes(int m) => _t('feedingAvgDurFmt').replaceAll('{m}', '$m');
  String feedingAvgIntervalFmt(int h, String mPadded) =>
      _t('feedingAvgIntervalFmt').replaceAll('{h}', '$h').replaceAll('{m}', mPadded);
  String regZodiacLine(String sign) => _t('regZodiacLine').replaceAll('{sign}', sign);
  String regPromptBabyNameLine(String mom) => _t('regPromptBabyName').replaceAll('{mom}', mom);
  String regListBabyLine(String name) => _t('regListBaby').replaceAll('{name}', name);
  String regListBirthLine(String date) => _t('regListBirth').replaceAll('{date}', date);
  String regListSignLine(String sign) => _t('regListSign').replaceAll('{sign}', sign);
  String regListPhoneLine(String phone) => _t('regListPhone').replaceAll('{phone}', phone);
  String regMomDisplay(String? mName) {
    final t = (mName == null || mName.isEmpty) ? regMomGeneric : regMomWithName(mName);
    return t;
  }

  String regMomWithName(String name) => _t('regMomWithName').replaceAll('{name}', name);

  String get add => _t('add');
  String get labelWeight => _t('labelWeight');
  String get labelHeight => _t('labelHeight');
  String get momNoteHint => _t('momNoteHint');
  String get shortcutDiaper => _t('shortcutDiaper');
  String get diaperPagePlaceholder => _t('diaperPagePlaceholder');
  String get shortcutHealth => _t('shortcutHealth');
  String get shortcutHealthSubtitle => _t('shortcutHealthSubtitle');
  String get shortcutFeedingSession => _t('shortcutFeedingSession');
  String get shortcutFeedingSessionSub => _t('shortcutFeedingSessionSub');
  String get healthHubTitle => _t('healthHubTitle');
  String get healthHubIntro => _t('healthHubIntro');
  String get healthHubSection => _t('healthHubSection');
  String get healthHubVaccines => _t('healthHubVaccines');
  String get healthHubVaccinesSub => _t('healthHubVaccinesSub');
  String get vaccineReminderNotifTitle => _t('vaccineReminderNotifTitle');
  String vaccineReminderNotifBody(String name) => _t('vaccineReminderNotifBody').replaceAll('{name}', name);
  String get homeBannerChipVaccine => _t('homeBannerChipVaccine');
  String get healthHubConsultations => _t('healthHubConsultations');
  String get healthHubConsultationsSub => _t('healthHubConsultationsSub');
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
  String get consultationReminderNotifTitle => _t('consultationReminderNotifTitle');
  String consultationReminderNotifBody(String title, String whenFormatted) =>
      _t('consultationReminderNotifBody').replaceAll('{title}', title).replaceAll('{when}', whenFormatted);
  String homeConsultationBannerChip(String title, String timeHm) =>
      _t('homeConsultationBannerChip').replaceAll('{title}', title).replaceAll('{t}', timeHm);
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
  String get motherProfileTabMother => _t('motherProfileTabMother');
  String get motherProfileTabBabies => _t('motherProfileTabBabies');
  String get motherProfileNoData => _t('motherProfileNoData');
  String get motherProfileSectionInfo => _t('motherProfileSectionInfo');
  String get motherProfileFieldPhone => _t('motherProfileFieldPhone');
  String get motherProfileFieldBirth => _t('motherProfileFieldBirth');
  String get motherProfileFieldHeight => _t('motherProfileFieldHeight');
  String get motherProfileFieldFatherHeight => _t('motherProfileFieldFatherHeight');
  String get motherProfileAddBaby => _t('motherProfileAddBaby');
  String get motherProfileNoBabies => _t('motherProfileNoBabies');
  String motherProfileBabyBornAt(String date) => _t('motherProfileBabyBornAt').replaceAll('{date}', date);
  String get settingsBabyData => _t('settingsBabyData');
  String get settingsAlerts => _t('settingsAlerts');
  String get alertsScreenIntro => _t('alertsScreenIntro');
  String get alertsExactAlarmAndroidTitle => _t('alertsExactAlarmAndroidTitle');
  String get alertsExactAlarmAndroidBody => _t('alertsExactAlarmAndroidBody');
  String get alertsExactAlarmAndroidOpenSettings => _t('alertsExactAlarmAndroidOpenSettings');
  String get alertsSectionFeeding => _t('alertsSectionFeeding');
  String get alertsRuleFeeding => _t('alertsRuleFeeding');
  String get alertsSectionDiaper => _t('alertsSectionDiaper');
  String get alertsRuleDiaper => _t('alertsRuleDiaper');
  String get alertsSectionSleep => _t('alertsSectionSleep');
  String get alertsRuleSleep => _t('alertsRuleSleep');
  String get alertsSectionGrowth => _t('alertsSectionGrowth');
  String get alertsRuleGrowth => _t('alertsRuleGrowth');
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
  String sleepSessionStartedAt(String time) => _t('sleepSessionStartedAt').replaceAll('{time}', time);
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
  String get sleepConfirmBackTitle => _t('sleepConfirmBackTitle');
  String get sleepConfirmBackBody => _t('sleepConfirmBackBody');
  String get sleepConfirmCancelSessionTitle => _t('sleepConfirmCancelSessionTitle');
  String get sleepConfirmCancelSessionBody => _t('sleepConfirmCancelSessionBody');
  String get sleepDiscard => _t('sleepDiscard');
  String get sleepHistoryTitle => _t('sleepHistoryTitle');
  String get sleepHistoryEmpty => _t('sleepHistoryEmpty');
  String get sleepUpdatedOk => _t('sleepUpdatedOk');
  String sleepBannerNextNap(int min) => _t('sleepBannerNextNap').replaceAll('{min}', '$min');
  String get sleepWindowTitle => _t('sleepWindowTitle');
  String get sleepWindowEarly => _t('sleepWindowEarly');
  String get sleepWindowIdeal => _t('sleepWindowIdeal');
  String get sleepWindowLate => _t('sleepWindowLate');
  String sleepRoutineLastLabel(String ago) => _t('sleepRoutineLastLabel').replaceAll('{ago}', ago);
  String get sleepRoutineLastNever => _t('sleepRoutineLastNever');
  String get sleepRoutineNextPrefix => _t('sleepRoutineNextPrefix');
  String sleepNextApproxMin(int min) => _t('sleepNextApproxMin').replaceAll('{min}', '$min');
  String get sleepRoutineNextNow => _t('sleepRoutineNextNow');
  String get sleepStatusEarly => _t('sleepStatusEarly');
  String get sleepStatusIdeal => _t('sleepStatusIdeal');
  String get sleepStatusOverdue => _t('sleepStatusOverdue');
  String get sleepHeroAwakeBadge => _t('sleepHeroAwakeBadge');
  String get sleepHeroAwakeCaption => _t('sleepHeroAwakeCaption');
  String get sleepHeroSleepingBadge => _t('sleepHeroSleepingBadge');
  String get sleepHeroSleepingCaption => _t('sleepHeroSleepingCaption');
  String get sleepRoutineCardTitle => _t('sleepRoutineCardTitle');
  String sleepRoutineStatusLine(String status) => _t('sleepRoutineStatusLine').replaceAll('{status}', status);
  /// Limites de vigília vêm da tabela fixa do app (ver `SleepRoutine`) — não há registo nas Definições.
  String sleepRoutineVigilHighlight(int min, int max) =>
      _t('sleepRoutineVigilHighlight').replaceAll('{min}', '$min').replaceAll('{max}', '$max');
  String get sleepIdealForAge => _t('sleepIdealForAge');
  String sleepAgeMonthsLabel(int n) => _t('sleepAgeMonthsLabel').replaceAll('{n}', '$n');
  String sleepWindowMinMax(int min, int max) => _t('sleepWindowMinMax').replaceAll('{min}', '$min').replaceAll('{max}', '$max');
  String get sleepLegendG => _t('sleepLegendG');
  String get sleepLegendY => _t('sleepLegendY');
  String get sleepLegendR => _t('sleepLegendR');
  String get sleepWakeWindowExplainer => _t('sleepWakeWindowExplainer');
  String get sleepFinalizeButton => _t('sleepFinalizeButton');
  String sleepSleepingFor(String when) => _t('sleepSleepingFor').replaceAll('{when}', when);
  String get sleepInsightTitle => _t('sleepInsightTitle');
  String sleepInsightNaps(int n) => _t('sleepInsightNaps').replaceAll('{n}', '$n');
  String sleepInsightAvg(int min) => _t('sleepInsightAvg').replaceAll('{min}', '$min');
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
  String sleepAlertsWakeWindowAutomatic(int m) => _t('sleepAlertsWakeWindowAutomatic').replaceAll('{m}', '$m');
  String sleepAlertsWakeWindowAutomaticNoBirth(int m) =>
      _t('sleepAlertsWakeWindowAutomaticNoBirth').replaceAll('{m}', '$m');
  String sleepAlertsMonthsApprox(int n) => _t('sleepAlertsMonthsApprox').replaceAll('{n}', '$n');
  String sleepAlertsWakeWindowCustom(int m) => _t('sleepAlertsWakeWindowCustom').replaceAll('{m}', '$m');
  String sleepAlertsApproachAuto(int m) => _t('sleepAlertsApproachAuto').replaceAll('{m}', '$m');
  String sleepAlertsApproachCustom(int m) => _t('sleepAlertsApproachCustom').replaceAll('{m}', '$m');
  String get diaperToggleAlerts => _t('diaperToggleAlerts');
  String get diaperToggleAlertsSubtitle => _t('diaperToggleAlertsSubtitle');
  String get healthGrowthToggleAlerts => _t('healthGrowthToggleAlerts');
  String get healthGrowthToggleAlertsSubtitle => _t('healthGrowthToggleAlertsSubtitle');
  String get feedingScreenAlertsHint => _t('feedingScreenAlertsHint');
  String get sleepNotifTitle => _t('sleepNotifTitle');
  String get sleepNotifBeforeBody => _t('sleepNotifBeforeBody');
  String get sleepNotifOverdueBody => _t('sleepNotifOverdueBody');

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
  String diaperDashAgoLine(String compactAgo) => _t('diaperDashAgoLine').replaceAll('{ago}', compactAgo);
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
  String get feedingHubOverviewEmpty => _t('feedingHubOverviewEmpty');
  String get feedingHubMlRequired => _t('feedingHubMlRequired');
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
  String devLeapsIntro(String babyName) => _t('devLeapsIntro').replaceAll('{name}', babyName);
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
  String developmentLeapBannerRange(String bannerKey) => _t('devLeap_${bannerKey}_range');
  String developmentLeapBannerTitle(String bannerKey) => _t('devLeap_${bannerKey}_title');
  String developmentLeapBannerLead(String bannerKey) => _t('devLeap_${bannerKey}_lead');
  String developmentLeapBannerEmotion(String bannerKey) => _t('devLeap_${bannerKey}_emotion');

  /// Corpo da fase no card/página de detalhe (lista: uma linha por item).
  List<String> developmentLeapHomeBullets(String bannerKey) =>
      _splitLeapLines(_t('devLeap_${bannerKey}_homeBullets'));

  String developmentLeapDetailWhats(String bannerKey) => _t('devLeap_${bannerKey}_detailWhats');

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
  String get regFatherHeight => _t('regFatherHeight');
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

  String _t(String key) {
    final map = _strings[lang] ?? _strings[AppLang.pt]!;
    final en = _strings[AppLang.en]!;
    final pt = _strings[AppLang.pt]!;
    final primary = map[key];
    if (primary != null) return primary;

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
    'quickRecordsSubtitle': 'Adicione eventos da rotina da bebê em poucos toques.',
    'feedingAlertsSwitchTitle': 'Alerta de Amamentação',
    'feedingAlertsSwitchSubtitle':
        'Aviso quando passar o tempo desde a última amamentação ao seio ou mamadeira (push).',
    'feedingAlertsIntervalCaption': 'Tempo para avisar após a última amamentação: {m} min (20–360)',
    'feedingAlertsShortcutTitle': 'Alerta de alimentação',
    'scheduledFeedingReminderBody': 'Momento do lembrete de amamentação. Toque para registar.',
    'scheduledDiaperReminderTitle': 'Troca de fralda',
    'scheduledDiaperReminderBody': 'Já passou o tempo sugerido desde a última troca. Toque para registar.',
    'whatHappenedNow': 'O que aconteceu agora?',
    'momNote': 'Observação da mamãe',
    'saveRecord': 'Salvar registro',
    'reportsTitle': 'Relatórios',
    'reportsSubtitle': 'Resumo para a mamãe e para o pediatra.',
    'growth': 'Crescimento',
    'pediatricReport': 'Relatório pediátrico',
    'pediatricReportDesc': 'Gere um PDF com peso, sono, alimentação, fraldas, vacinas, consultas e observações.',
    'generatePdf': 'Gerar PDF',
    'memoriesTitle': 'Livro de memórias',
    'memoriesSubtitle': 'Momentos importantes para transformar em recordações.',
    'memoriesProgressSaved': '{filled} de {total} momentos guardados',
    'memoriesCheerEmpty': 'Toque num selo com + para registrar fotos e histórias.',
    'memoriesAlbumPromoTitle': 'O seu livro de recordação completo',
    'memoriesAlbumPromoSubtitle':
        'Baixe um PDF elegante com capa FaceBaby, moldura decorativa e todas as badges que já preencheu — ideal para guardar ou partilhar.',
    'memoriesAlbumDownloadCta': 'Baixar PDF do álbum',
    'memoriesAlbumGenerating': 'A gerar o seu álbum…',
    'memoriesAlbumNeedFilled': 'Preencha pelo menos um momento no álbum para gerar o PDF.',
    'memoriesAlbumError': 'Não foi possível gerar o PDF.',
    'memoriesAlbumCoverMain': 'Livro de recordação',
    'memoriesAlbumCoverTagline': 'Momentos especiais com {name}',
    'memoriesAlbumFooter': 'Gerado com FaceBaby',
    'addMemory': 'Adicionar memória',
    'memoryBadgeMonthOne': '1 mês',
    'memoryBadgeMonthsMany': '{n} meses',
    'memoryBadgeYearOne': '1 ano',
    'memoryBadgeYearsMany': '{n} anos',
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
    'badge_sat_alone': 'Sentou sozinha',
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
    'dailyJournalHint': 'Escreva aqui o resumo de hoje (ou do dia selecionado)…',
    'dailyJournalSave': 'Salvar resumo',
    'dailyJournalSaving': 'Salvando resumo…',
    'dailyJournalSaved': 'Resumo salvo.',
    'dailyJournalNoBaby': 'Cadastre/seleciona um bebê para usar o resumo do dia.',
    'registerMotherBaby': 'Cadastro (mãe e bebê)',
    'vaccinesCard': 'Vacinas (carteirinha)',
    'language': 'Idioma',
    'settingsSoonTitle': 'Em breve',
    'settingsSoonBadge': 'Em breve',
    'settingsRateUs': 'Avalie-nos',
    'settingsTermsOfUse': 'Termos de uso',
    'settingsPrivacyPolicy': 'Política de privacidade',
    'settingsSpecialThanks': 'Agradecimentos especiais',
    'settingsTellFriend': 'Conte a um amigo',
    'unitsTitle': 'Unidades de medida',
    'unitsIntro': 'Escolha como prefere ver as medidas. Começamos com um padrão automático baseado na região do seu celular.',
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
    'authCreateAccount': 'Criar conta',
    'authForgotDialogTitle': 'Esqueci minha senha',
    'authForgotDialogBody': 'Vamos enviar um link para redefinir sua senha.',
    'authForgotSend': 'Enviar',
    'authResetEmailSentSnackbar': 'E-mail enviado. Verifique sua caixa de entrada.',
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
    'authErrEmailInUse': 'Já existe conta com esse e-mail.',
    'authErrInvalidCredential': 'Credenciais inválidas. Tente novamente.',
    'authErrCredentialsGeneric': 'Não foi possível entrar. Tente novamente.',
    'authErrGoogleConfigAndroid':
        'Login com Google falhou por configuração do app (erro 10).\n\n'
            '1) No Firebase: Configurações do projeto → app Android → cadastre a impressão SHA-1 do keystore de debug.\n'
            '2) Na pasta android, rode: gradlew signingReport e copie o SHA-1 de "debug".\n'
            '3) Em Autenticação → Google → ative.\n'
            '4) Baixe de novo o google-services.json em android/app/.',
    'authErrLoginCancelled': 'Login cancelado.',
    'authErrUnexpected': 'Ocorreu um erro inesperado.',
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
    'changeBabyTooltip': 'Trocar bebê',
    'notificationsInboxTitle': 'Notificações',
    'notificationsInboxSubtitle': 'Últimos 3 dias (enviadas e agendadas registadas na app)',
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
    'deleteAccountReauthTitle': 'Confirmar identidade',
    'deleteAccountReauthBody':
        'Por segurança, precisamos confirmar que é mesmo você. Escolha o mesmo método de acesso habitual e concluiremos o apagar da conta.',
    'deleteAccountReauthPasswordHint': 'Palavra-passe atual',
    'deleteAccountReauthGoogle': 'Confirmar com Google',
    'deleteAccountReauthContinue': 'Confirmar palavra-passe',
    'deleteAccountReauthCantPassword':
        'Use o botão com o mesmo método de login (ex.: Google) que usou ao criar a conta.',
    'homeBabyBannerForecastSleep': 'Previsão de dormir',
    'homeBabyBannerForecastWake': 'Previsão de acordar',
    'homeBabyBannerForecastSubtitleSleep': 'Sinais de sono detectados\ncom base no horário atual',
    'homeBabyBannerForecastSubtitleWake': 'Baseado no horário atual e padrão para a idade',
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
    'memoryTellMomentHint': 'Como foi esse momento? Conte detalhes que você quer guardar…',
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
    'memorySaveNeedPhotoOrText': 'Adicione uma foto ou escreva uma descrição para salvar.',
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
    'homeSummaryPickDayTooltip': 'Escolher dia do resumo (histórico guardado após o dia terminar)',
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
    'homeCriticalFeedingSubtitle': 'Passou do horário esperado desde a última mamada.',
    'homeCriticalSleepSubtitle': 'A janela de sono pode ter sido ultrapassada.',
    'homeCriticalDiaperSubtitle': 'Já faz um tempo desde a última troca.',
    'homeSleepBarAwakeTitle': 'Acordado · janela até dormir',
    'homeSleepBarSleepTitle': 'A dormir · tempo da sessão',
    'homeFeedingCounterTitle': 'Alimentação · tempo até ao próximo intervalo',
    'homeFeedingCounterHint': 'Contagem decrescente (intervalo em Registos rápidos)',
    'homeSleepBarAwakeHintEarly': '≈ {m} min até a janela ideal',
    'homeSleepBarAwakeHintIdeal': '≈ {m} min até o fim da janela',
    'homeSleepBarAwakeHintOverdue': 'Janela ultrapassada · pode ser hora de dormir',
    'homeSleepBarSleepHint': '{remaining} restantes · limite da sessão ~{cap} min',
    'homeSleepBarNeedLastSleep': 'Registe o último sono para ver a linha',
    'homeTipTitle': 'Dica do dia',
    'homeTipBody': 'Rotinas consistentes ajudam seu bebê a se sentir seguro e tranquilo.',
    'homeGreetingSubtitle': 'Que bom te ver aqui hoje!',
    'homeMotivationBanner': 'Você está fazendo um ótimo trabalho! Pequenos registros, grandes lembranças.',
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
    'growthSummaryIntro': 'Visão geral de peso, altura e perímetro da cabeça.',
    'growthChartCaption': '{name} — {metric}',
    'growthChartDeltaHint':
        'Eixo vertical: variação em relação ao valor ao nascer (0 = ao nascer).',
    'growthHistoryTitle': '{label} (histórico)',
    'invalidGrowthValue': 'Informe um valor válido de {label}.',
    'growthSaved': '{label} registrado com sucesso.',
    'growthEmpty': 'Nenhum registro de {label} ainda.',
    'notifyGrowthWeightDownTitle': 'Peso menor que antes',
    'notifyGrowthWeightDownBody':
        'O último registro de peso está abaixo do anterior. Em caso de dúvida, fale com o pediatra.',
    'notifyGrowthStaleTitle': 'Há tempo sem registar o crescimento',
    'notifyGrowthStaleBody':
        'Passaram mais de 30 dias desde a última medição (peso, altura ou cabeça). Já são {days} dias — atualize nos registros.',
    'momNoteHint': 'Ex: dormiu melhor depois do banho...',
    'shortcutDiaper': 'Fralda',
    'diaperPagePlaceholder':
        'Em breve você poderá registrar trocas (xixi e cocô). Estamos preparando esta área.',
    'shortcutHealth': 'Saúde',
    'shortcutHealthSubtitle': 'Vacinas e consultas',
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
    'healthHubConsultations': 'Consultas',
    'healthHubConsultationsSub': 'Pediatra e retornos',
    'consultationsTitle': 'Consultas',
    'consultationsIntro': 'Registe consultas com data e hora; aparecem no resumo do dia na Home.',
    'consultationsSoonTitle': 'Em breve',
    'consultationsComingBody':
        'Em breve você poderá registrar consultas, anexar notas e lembretes de retorno.',
    'homeSummaryHealthStripTitle': 'Vacinas e consultas neste dia',
    'homeSummaryHealthStripEmpty': 'Nenhuma vacina nem consulta registada neste dia.',
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
    'settingsAiMicSub': 'Mostra o botão do microfone na tela inicial (em desenvolvimento).',
    'reportNoWeight': 'Sem dados de peso ainda.',
    'reportNoHeight': 'Sem dados de altura ainda.',
    'memoriesPhotoError': 'Não foi possível selecionar a foto.',
    'memoriesTodayTitle': 'Memórias de hoje',
    'memoriesTodayAsk': 'Você já adicionou sua foto de hoje?',
    'memoriesNotYet': 'Ainda não',
    'memoriesAddPhotoDialog': 'Adicionar foto',
    'memoriesAlreadyPostedToday': 'Você já adicionou a foto de hoje.',
    'memoriesWallEmpty': 'Seu mural ainda está vazio. Adicione a primeira foto do dia!',
    'memoriesHighlights': 'Destaques',
    'memoriesWallSection': 'Mural',
    'settingsMotherProfile': 'Meu Perfil',
    'profileEditMother': 'Editar dados da mãe',
    'profileEditBaby': 'Editar dados do bebê',
    'profileDataSaved': 'Dados atualizados.',
    'profileEditData': 'Editar dados',
    'contactTitle': 'Contato',
    'contactIntro': 'Envie uma mensagem por e-mail. Vamos abrir seu app de e-mail com os dados preenchidos.',
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
    'motherProfileTabMother': 'Mãe',
    'motherProfileTabBabies': 'Bebês',
    'motherProfileNoData': 'Nenhum perfil encontrado. Tente novamente em instantes.',
    'motherProfileSectionInfo': 'Informações',
    'motherProfileFieldPhone': 'Telefone',
    'motherProfileFieldBirth': 'Nascimento',
    'motherProfileFieldHeight': 'Altura',
    'motherProfileFieldFatherHeight': 'Altura do pai',
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
        'Usando a última hora em que terminou um sono registado e a idade da bebé em meses (data de nascimento no perfil), a app marca até dois tipos de aviso quando o alerta está ligado: um pouco antes de atingir a janela de vigília habitual e outro quando essa janela já pode ter sido ultrapassada. Ao gravar um novo período de sono, os horários são atualizados.',
    'alertsSectionGrowth': 'Crescimento e medições',
    'alertsRuleGrowth':
        'Notificação quando o peso mais recente fica abaixo do registo de peso anterior (por data de medição). Outro aviso quando passam mais de 30 dias sem qualquer medição de peso, altura ou perímetro craniano guardada na app.',
    'sleepToggleAlertsSubtitle': 'Lembretes com base no último sono terminado e na idade.',
    'sleepAlertsWakeWindowRulerValueAuto': 'Tempo efetivo nesta régua: {m} min (automático pela idade).',
    'sleepAlertsWakeWindowRulerValueCustom': 'Tempo nesta régua: {m} min (valor personalizado).',
    'sleepAlertsWakeWindowSliderLabelAuto': '{m} min · auto',
    'sleepAlertsWakeWindowSliderLabelCustom': '{m} min',
    'sleepAlertsApproachRulerValueDefault': 'Antecedência efetiva nesta régua: {m} min (padrão).',
    'sleepAlertsApproachRulerValueCustom': 'Antecedência nesta régua: {m} min.',
    'sleepAlertsApproachSliderLabelDefault': '{m} min · padrão',
    'sleepAlertsApproachSliderLabelCustom': '{m} min',
    'sleepAlertsWakeWindowAutomatic': 'Limite de vigília usado no alerta: {m} min (automático pela tabela por idade).',
    'sleepAlertsWakeWindowAutomaticNoBirth':
        'Adicione a data de nascimento do bebé no perfil para o padrão certo; até lá usamos referência de {m} min.',
    'sleepAlertsMonthsApprox': 'Tabela de referência: ~{n} meses',
    'sleepAlertsWakeWindowCustom': 'Limite de vigília personalizado: {m} min.',
    'sleepAlertsApproachAuto': 'Aviso antes do limite: {m} min antecedência (valor padrão).',
    'sleepAlertsApproachCustom': 'Aviso antes do limite: {m} min antecedência (personalizado).',
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
    'sleepConfirmBackTitle': 'Sair do sono?',
    'sleepConfirmBackBody': 'O registro ainda não foi salvo. Deseja descartar esta sessão?',
    'sleepConfirmCancelSessionTitle': 'Cancelar sono?',
    'sleepConfirmCancelSessionBody': 'O tempo desta sessão será descartado.',
    'sleepDiscard': 'Descartar',
    'sleepHistoryTitle': 'Histórico de sonos',
    'sleepHistoryEmpty': 'Ainda não há sonos registados.',
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
    'sleepHeroSleepingCaption': 'Quando acordar, toque em Terminar sono para gravar este período.',
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
    'healthGrowthToggleAlertsSubtitle': 'Avisos de peso e ausência prolongada de medições.',
    'feedingScreenAlertsHint': 'Para mudar os minutos, use Mais › Alertas.',
    'sleepNotifTitle': 'Sono',
    'sleepNotifBeforeBody':
        'Pode ser um bom momento para colocar o bebê para dormir.',
    'sleepNotifOverdueBody':
        'Seu bebê pode estar cansado — tente iniciar o sono com calma.',
    'notifChannelRemindersName': 'Lembretes',
    'notifChannelRemindersDesc': 'Alertas de alimentação, fraldas e sono.',
    'notifChannelGrowthName': 'Crescimento',
    'notifChannelGrowthDesc': 'Alertas de peso e ausência prolongada de medições.',
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
    'feedingNoRunning': 'Não foi possível finalizar: nenhuma amamentação em andamento.',
    'feedingSavedOk': 'Amamentação registrada.',
    'feedingSaveFail': 'Não foi possível salvar:',
    'feedingSaving': 'Salvando amamentação…',
    'feedingQuickSummary': 'Resumo rápido',
    'feedingNoBabyHint': 'Cadastre um bebê primeiro em "Mais > Cadastro (mãe e bebês)".',
    'feedingPickBabyLabel': 'Selecionar bebê',
    'feedingEmptyDataHint': 'Sem dados ainda. Use "Iniciar amamentação" para registrar com 1 toque.',
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
    'feedingHubTapSidesHint': 'Toque em E ou D para iniciar o cronômetro. Toque novamente para salvar.',
    'feedingHubLetterLeft': 'E',
    'feedingHubLetterRight': 'D',
    'feedingHubAddManualEntry': 'Adicionar entrada manual',
    'feedingHubOverviewTitle': 'Visão geral dos registros',
    'feedingHubManualTitle': 'Entrada manual (peito)',
    'feedingHubManualMinutes': 'Duração (minutos)',
    'feedingHubManualInvalid': 'Informe uma duração maior que zero.',
    'feedingHubSaveBottle': 'Registrar mamadeira',
    'feedingHubSaveSolid': 'Registrar refeição',
    'feedingHubSolidDescribe': 'O que foi oferecido? (opcional)',
    'feedingHubOverviewEmpty': 'Nenhum registro nesta faixa.',
    'feedingHubMlRequired': 'Informe a quantidade em ml.',
    'feedingHubTimerTooShort': 'Espere pelo menos alguns segundos antes de salvar esta amamentação.',
    'feedingHubBreastPieTitle': 'Qual lado está sendo mais usado?',
    'feedingHubBreastPieEmpty': 'Registre algumas amamentações (E/D) para ver o gráfico.',
    'feedingHubFeedingUpdatedOk': 'Registro atualizado.',
    'feedingSideLeft': 'Esquerdo',
    'feedingSideRight': 'Direito',
    'feedingSideBoth': 'Ambos',
    'feedingSideLabel': 'Lado',
    'feedingQty': 'Quantidade',
    'feedingQtyMl': 'Quantidade (ml) (opcional)',
    'feedingNote': 'Observação (opcional)',
    'feedingHintRunning': 'Finalize para salvar.',
    'feedingHintIdle': 'Pronto para registrar a próxima amamentação com 1 toque.',
    'feedingHistory': 'Histórico',
    'feedingNoRecords': 'Ainda sem registros.',
    'feedingHistoryLine': '{time} min • {side}',
    'feedingInsights': 'Insights',
    'feedingInsightsNeed': 'Registre pelo menos 2 amamentações para ver padrões.',
    'feedingAvgDurFmt': 'Média de tempo: {m} min',
    'feedingAvgIntervalFmt': 'Intervalo médio: {h}h{m}',
    'feedingAlertSection': 'Alerta (opcional)',
    'feedingAlertTitle': 'Ativar alerta de próxima amamentação',
    'feedingModeAvg': 'Média automática',
    'feedingModeManual': 'Intervalo manual',
    'feedingNotifyNote': 'Obs: por enquanto é só configuração visual. Depois a gente liga notificação.',
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
    'vaccNoBabies': 'Nenhum bebê cadastrado ainda. Vá em "Mais > Cadastro (mãe e bebê)".',
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
    'devLeapsIntro': 'Fases comuns do desenvolvimento de {name}. Os textos são acolhedores e sem alarmismo.',
    'devLeapsNeedBirth': 'Para mostrar as fases por idade, preencha a data de nascimento do bebê no perfil.',
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
    'devLeap_dv02_lead': '{baby_name} pode estar começando a perceber melhor vozes e rostos.',
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
    'devLeap_dv05_lead': '{baby_name} pode estar percebendo mais os próprios movimentos.',
    'devLeap_dv05_emotion': 'O corpo começa a ganhar significado.',
    'devLeap_dv06_range': 'Semana 6',
    'devLeap_dv06_title': 'Mais conectado',
    'devLeap_dv06_lead': '{baby_name} pode estar mais atento às emoções das pessoas.',
    'devLeap_dv06_emotion': 'O vínculo emocional continua se fortalecendo.',
    'devLeap_dv07_range': 'Semana 7–8',
    'devLeap_dv07_title': 'Sono diferente',
    'devLeap_dv07_lead': '{baby_name} pode estar passando por mudanças importantes no sono.',
    'devLeap_dv07_emotion': 'O cérebro está amadurecendo rapidamente.',
    'devLeap_dv08_range': '2–3 meses',
    'devLeap_dv08_title': 'Mais consciente',
    'devLeap_dv08_lead': '{baby_name} pode estar percebendo mais o próprio corpo e o ambiente.',
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
    'devLeap_dv11_lead': '{baby_name} pode estar tentando interagir cada vez mais.',
    'devLeap_dv11_emotion': 'A comunicação começa a ganhar força.',
    'devLeap_dv12_range': '6–7 meses',
    'devLeap_dv12_title': 'Mundo maior',
    'devLeap_dv12_lead': '{baby_name} pode estar percebendo melhor o espaço e o ambiente.',
    'devLeap_dv12_emotion': 'O mundo parece cada vez maior.',
    'devLeap_dv13_range': '7–8 meses',
    'devLeap_dv13_title': 'Mais apego',
    'devLeap_dv13_lead': '{baby_name} pode estar vivendo uma fase de maior necessidade emocional.',
    'devLeap_dv13_emotion': 'O vínculo emocional se fortalece.',
    'devLeap_dv14_range': '8–9 meses',
    'devLeap_dv14_title': 'Muitas conexões',
    'devLeap_dv14_lead': '{baby_name} pode estar criando novas conexões rapidamente.',
    'devLeap_dv14_emotion': 'O cérebro está extremamente ativo.',
    'devLeap_dv15_range': '9–10 meses',
    'devLeap_dv15_title': 'Não para quieto',
    'devLeap_dv15_lead': '{baby_name} pode estar em uma fase de muita movimentação.',
    'devLeap_dv15_emotion': 'O corpo e o cérebro trabalham juntos nessa fase.',
    'devLeap_dv16_range': '10–11 meses',
    'devLeap_dv16_title': 'Tentando se comunicar',
    'devLeap_dv16_lead': '{baby_name} pode estar observando e imitando muito mais.',
    'devLeap_dv16_emotion': 'A comunicação ganha força.',
    'devLeap_dv17_range': '11–12 meses',
    'devLeap_dv17_title': 'Mais autonomia',
    'devLeap_dv17_lead': '{baby_name} pode estar tentando fazer mais coisas sozinho.',
    'devLeap_dv17_emotion': 'A independência começa a aparecer.',
    'devLeap_dv18_range': '12–18 meses',
    'devLeap_dv18_title': 'Muitas emoções',
    'devLeap_dv18_lead': '{baby_name} pode estar vivendo emoções mais intensas.',
    'devLeap_dv18_emotion': 'O mundo emocional está crescendo rapidamente.',
    'devLeap_dv19_range': '18–24 meses',
    'devLeap_dv19_title': 'Faz de conta',
    'devLeap_dv19_lead': '{baby_name} pode estar entrando em uma fase de imaginação intensa.',
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
    'devLeap_dv01_keywords': 'adaptação\nvínculo\nsegurança\nsensibilidade\nacolhimento',
    'devLeap_dv01_detailMay':
        'choros frequentes\ndespertares frequentes\nnecessidade constante de colo\nsono irregular\nmaior sensibilidade',
    'devLeap_dv01_detailHelp': 'pele com pele\nvoz calma\npouca luz\nreduzir estímulos\nacolhimento constante',
    'devLeap_dv01_detailSkills': 'reconhecer cheiro da mãe\nreagir a sons\nreflexos primitivos',
    'devLeap_dv01_detailEmotional':
        'Seu bebê ainda não entende rotina. Ele entende presença, calor e segurança.',
    'devLeap_dv02_homeBullets':
        'observa mais\nreconhece vozes\nfica atento ao colo\ncomeça pequenas interações',
    'devLeap_dv02_detailWhats':
        'O bebê começa lentamente a perceber rostos, vozes, cheiros e presença emocional. A voz da mãe costuma trazer conforto e previsibilidade.',
    'devLeap_dv02_keywords': 'reconhecimento\nconexão\nconforto\npresença\nobservação',
    'devLeap_dv02_detailMay':
        'mais observação\nperíodos acordado maior\nreação à voz\nmais calma no colo',
    'devLeap_dv02_detailHelp': 'conversar olhando nos olhos\ncantar músicas suaves\ncontato visual\nacolhimento',
    'devLeap_dv02_detailSkills': 'acompanhar rostos\nreconhecer vozes\nobservar movimentos',
    'devLeap_dv02_detailEmotional': 'Mesmo pequeno, o bebê já começa a construir memórias emocionais.',
    'devLeap_dv03_homeBullets':
        'chora mais no fim do dia\nquer mais colo\nse irrita facilmente\ntem dificuldade para relaxar',
    'devLeap_dv03_detailWhats':
        'O sistema nervoso do bebê ainda está muito imaturo. Tudo pode parecer intenso: sons, luzes, fome, cansaço e estímulos.',
    'devLeap_dv03_keywords': 'sensibilidade\nirritação\nacolhimento\nsobrecarga\nnecessidade emocional',
    'devLeap_dv03_detailMay':
        'choros no fim do dia\nagitação\ndificuldade para dormir\nnecessidade maior de colo',
    'devLeap_dv03_detailHelp': 'ambiente silencioso\npouca luz\ncolo\nembalo suave\nreduzir estímulos',
    'devLeap_dv03_detailSkills': 'mais expressões faciais\nmaior atenção ao ambiente',
    'devLeap_dv03_detailEmotional':
        'Seu bebê não está “difícil”. Ele ainda está aprendendo a lidar com o mundo.',
    'devLeap_dv04_homeBullets':
        'observa rostos\nacompanha movimentos\ndemonstra atenção\nreage mais às pessoas',
    'devLeap_dv04_detailWhats':
        'O bebê começa a prestar mais atenção, acompanhar pessoas, perceber expressões e reagir ao ambiente.',
    'devLeap_dv04_keywords': 'interação\natenção\nobservação\nexpressões\nconexão',
    'devLeap_dv04_detailMay':
        'mais atenção visual\nsons diferentes\nmais períodos acordado\nreação social maior',
    'devLeap_dv04_detailHelp':
        'conversar bastante\nfazer expressões faciais\nmostrar objetos simples\nrespeitar sinais de sono',
    'devLeap_dv04_detailSkills': 'acompanhar objetos\ndemonstrar interesse social\nreagir a expressões',
    'devLeap_dv04_detailEmotional': 'O bebê aprende sobre o mundo através das relações.',
    'devLeap_dv05_homeBullets': 'observa as mãos\nmovimenta mais os braços\nfaz novos sons\nfica mais curioso',
    'devLeap_dv05_detailWhats': 'O bebê começa a perceber mãos, braços, movimentos e sensações corporais.',
    'devLeap_dv05_keywords': 'corpo\ndescoberta\ncoordenação\ncuriosidade\nmovimento',
    'devLeap_dv05_detailMay': 'observar as mãos\nmovimentos repetitivos\nnovos sons\nmais expressões',
    'devLeap_dv05_detailHelp': 'tummy time\nbrinquedos leves\ncontato visual\nconversa constante',
    'devLeap_dv05_detailSkills': 'levantar cabeça\nobservar mãos\nreagir ao próprio movimento',
    'devLeap_dv05_detailEmotional': 'Cada descoberta ajuda o bebê a construir confiança.',
    'devLeap_dv06_homeBullets':
        'observa expressões\nreage ao tom de voz\nquer mais interação\nfica mais sociável',
    'devLeap_dv06_detailWhats':
        'O bebê começa a perceber emoções, tom de voz, expressões faciais e presença emocional.',
    'devLeap_dv06_keywords': 'emoções\nvínculo\ninteração\nsegurança\npresença',
    'devLeap_dv06_detailMay':
        'mais sorrisos\nsons diferentes\nbusca por interação\nmais atenção social',
    'devLeap_dv06_detailHelp':
        'sorrir para o bebê\nconversar frequentemente\nusar voz tranquila\ninteragir com calma',
    'devLeap_dv06_detailSkills': 'sorriso social\nreação emocional\ninteração maior',
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
    'devLeap_dv07_detailSkills': 'mais interação\ncuriosidade maior\nnovas expressões',
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
    'devLeap_dv08_detailEmotional': 'Cada nova descoberta fortalece a confiança do bebê.',
    'devLeap_dv09_homeBullets': 'ri mais\nresponde às pessoas\nfaz sons\nquer brincar',
    'devLeap_dv09_detailWhats':
        'O bebê começa a perceber melhor emoções, vozes, expressões e interação social.',
    'devLeap_dv09_keywords': 'socialização\ngargalhadas\ncomunicação\nexpressões\nvínculo',
    'devLeap_dv09_detailMay':
        'mais risadas\nsons repetitivos\nmaior interação\nbusca por brincadeiras',
    'devLeap_dv09_detailHelp':
        'brincar bastante\nfazer expressões\nresponder aos sons\nconversar frequentemente',
    'devLeap_dv09_detailSkills': 'gargalhadas\nreação emocional intensa\ninteresse social',
    'devLeap_dv09_detailEmotional':
        'Seu bebê aprende amor e segurança através das interações.',
    'devLeap_dv10_homeBullets':
        'tenta pegar objetos\nleva coisas à boca\nobserva detalhes\nquer explorar',
    'devLeap_dv10_detailWhats':
        'O bebê desenvolve coordenação, curiosidade intensa, exploração sensorial e percepção espacial.',
    'devLeap_dv10_keywords': 'exploração\ncoordenação\ncuriosidade\nsensações\ndescoberta',
    'devLeap_dv10_detailMay':
        'pegar objetos\nlevar itens à boca\nmais energia\nmais atenção visual',
    'devLeap_dv10_detailHelp':
        'brinquedos seguros\nestímulos variados\nsupervisão constante\npermitir exploração',
    'devLeap_dv10_detailSkills': 'rolar\nalcançar objetos\nmanipular brinquedos',
    'devLeap_dv10_detailEmotional': 'Explorar é a principal forma de aprendizado nessa fase.',
    'devLeap_dv11_homeBullets':
        'faz novos sons\nresponde às pessoas\nquer brincar\ndemonstra emoções',
    'devLeap_dv11_detailWhats':
        'O bebê aprende interação social, troca emocional, comunicação inicial e resposta ao ambiente.',
    'devLeap_dv11_keywords': 'linguagem\ncomunicação\ninteração\nsocialização\nvínculo',
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
    'devLeap_dv12_detailSkills': 'arrastar\nalcançar objetos distantes\nsentar melhor',
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
    'devLeap_dv14_keywords': 'lógica\nconexões\nobservação\naprendizado\npadrões',
    'devLeap_dv14_detailMay':
        'brincar escondendo objetos\nrepetir ações\ncuriosidade intensa\nexplorar reações',
    'devLeap_dv14_detailHelp':
        'brincadeiras simples\nesconder brinquedos\nmúsicas repetitivas\ninteração constante',
    'devLeap_dv14_detailSkills': 'bater palmas\nengatinhar\nprocurar objetos',
    'devLeap_dv14_detailEmotional': 'O bebê aprende muito através da repetição.',
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
    'devLeap_dv15_detailSkills':
        'levantar\napoiar em móveis\nexplorar a casa',
    'devLeap_dv15_detailEmotional': 'Explorar é a forma do bebê entender o mundo.',
    'devLeap_dv16_homeBullets':
        'repete sons\nobserva expressões\ntenta interagir\nresponde mais às pessoas',
    'devLeap_dv16_detailWhats':
        'O bebê descobre que sons têm significado, gestos geram respostas e comunicação aproxima pessoas.',
    'devLeap_dv16_keywords': 'linguagem\nimitação\ncomunicação\nexpressão\ninteração',
    'devLeap_dv16_detailMay':
        'sons repetitivos\ntentativa de chamar atenção\nmais expressões\nobservação intensa',
    'devLeap_dv16_detailHelp':
        'conversar bastante\nnomear objetos\nresponder aos sons\nler livros simples',
    'devLeap_dv16_detailSkills': 'apontar\nrepetir sons\nentender palavras simples',
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
    'devLeap_dv17_detailSkills': 'primeiros passos\nprimeiras palavras\nmais autonomia',
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
    'regFatherHeight': 'Altura do papai (cm)',
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
    'scheduledFeedingReminderBody': 'Time for your feeding reminder. Tap to log.',
    'scheduledDiaperReminderTitle': 'Diaper change',
    'scheduledDiaperReminderBody': 'It may be time for a diaper change. Tap to log.',
    'whatHappenedNow': 'What happened now?',
    'momNote': "Mom's note",
    'saveRecord': 'Save log',
    'reportsTitle': 'Reports',
    'reportsSubtitle': 'A summary for Mom and the pediatrician.',
    'growth': 'Growth',
    'pediatricReport': 'Pediatric report',
    'pediatricReportDesc': 'Generate a PDF with weight, sleep, feeding, diapers, vaccines, appointments and notes.',
    'generatePdf': 'Generate PDF',
    'memoriesTitle': 'Memory book',
    'memoriesSubtitle': 'Important moments to keep forever.',
    'memoriesProgressSaved': '{filled} of {total} moments saved',
    'memoriesCheerEmpty': 'Tap a badge with + to add photos and stories.',
    'memoriesAlbumPromoTitle': 'Your complete keepsake book',
    'memoriesAlbumPromoSubtitle':
        'Download an elegant PDF with a FaceBaby cover, decorative frame, and every badge you have filled in — perfect to keep or share.',
    'memoriesAlbumDownloadCta': 'Download album PDF',
    'memoriesAlbumGenerating': 'Creating your album…',
    'memoriesAlbumNeedFilled': 'Fill in at least one moment in the album to generate the PDF.',
    'memoriesAlbumError': 'Could not generate the PDF.',
    'memoriesAlbumCoverMain': 'Keepsake memory book',
    'memoriesAlbumCoverTagline': 'Special moments with {name}',
    'memoriesAlbumFooter': 'Made with FaceBaby',
    'addMemory': 'Add memory',
    'memoryBadgeMonthOne': '1 month',
    'memoryBadgeMonthsMany': '{n} months',
    'memoryBadgeYearOne': '1 year',
    'memoryBadgeYearsMany': '{n} years',
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
    'badge_sat_alone': 'Sat alone',
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
    'settingsTermsOfUse': 'Terms of use',
    'settingsPrivacyPolicy': 'Privacy policy',
    'settingsSpecialThanks': 'Special thanks',
    'settingsTellFriend': 'Tell a friend',
    'unitsTitle': 'Measurement units',
    'unitsIntro': 'Choose how you want measurements to be shown. We start with an automatic default based on your device region.',
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
    'authErrEmailInUse': 'An account already exists with this email.',
    'authErrInvalidCredential': 'Invalid credentials. Try again.',
    'authErrCredentialsGeneric': 'Could not sign in. Try again.',
    'authErrGoogleConfigAndroid':
        'Google sign-in failed due to app configuration (error 10).\n\n'
            '1) Firebase: Project settings → your Android app → add your debug keystore SHA-1.\n'
            '2) In the android folder run: gradlew signingReport and copy the "debug" SHA-1.\n'
            '3) Authentication → enable Google provider.\n'
            '4) Download google-services.json again into android/app/.',
    'authErrLoginCancelled': 'Sign-in cancelled.',
    'authErrUnexpected': 'Something went wrong.',
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
    'changeBabyTooltip': 'Switch baby',
    'notificationsInboxTitle': 'Notifications',
    'notificationsInboxSubtitle': 'Last 3 days (delivered and scheduled, logged in the app)',
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
    'deleteAccountReauthTitle': 'Confirm identity',
    'deleteAccountReauthBody':
        'For your security we need one more verification. Use the same sign-in method you normally use — then we\'ll finish deleting your account.',
    'deleteAccountReauthPasswordHint': 'Current password',
    'deleteAccountReauthGoogle': 'Confirm with Google',
    'deleteAccountReauthContinue': 'Confirm password',
    'deleteAccountReauthCantPassword':
        'Use the button for the sign-in provider you originally used (e.g. Google).',
    'homeBabyBannerForecastSleep': 'Sleep forecast',
    'homeBabyBannerForecastWake': 'Wake-up forecast',
    'homeBabyBannerForecastSubtitleSleep': 'Sleep cues detected\nbased on the current time',
    'homeBabyBannerForecastSubtitleWake': 'Based on current time and age pattern',
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
    'memoryShareWebOnlyMobile': 'Sharing image or PDF is available in the installed app (Android/iOS).',
    'memoryShareSheetJpegTitle': 'Image (JPG)',
    'memoryShareSheetJpegSubtitle': 'Choose WhatsApp, email, Bluetooth… in the system sheet',
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
    'homeSummaryPickDayTooltip': 'Pick summary day (history saved after each day ends)',
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
    'homeCriticalFeedingSubtitle': 'It may have passed the expected time since the last feeding.',
    'homeCriticalSleepSubtitle': 'The awake window may have been exceeded.',
    'homeCriticalDiaperSubtitle': 'It may have been a while since the last change.',
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
    'homeGreetingSubtitle': 'Good to see you here today!',
    'homeMotivationBanner': "You're doing a great job! Small logs, big memories.",
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
    'growthSummaryIntro': 'Overview of weight, height and head circumference.',
    'growthChartCaption': '{name} — {metric}',
    'growthChartDeltaHint': 'Vertical axis: change from the at-birth value (0 = at birth).',
    'growthHistoryTitle': '{label} (history)',
    'invalidGrowthValue': 'Enter a valid {label} value.',
    'growthSaved': '{label} saved successfully.',
    'growthEmpty': 'No {label} records yet.',
    'notifyGrowthWeightDownTitle': 'Weight lower than before',
    'notifyGrowthWeightDownBody':
        'The latest weight entry is below the previous one. When in doubt, contact your pediatrician.',
    'notifyGrowthStaleTitle': 'No growth log in a while',
    'notifyGrowthStaleBody':
        'It has been over 30 days since the last growth measurement (weight, height, or head). It has been {days} days — add a new entry.',
    'momNoteHint': 'E.g. slept better after bath...',
    'shortcutDiaper': 'Diaper',
    'diaperPagePlaceholder': 'Soon you will be able to log diaper changes. This section is coming.',
    'shortcutHealth': 'Health',
    'shortcutHealthSubtitle': 'Vaccines & visits',
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
    'healthHubConsultations': 'Checkups',
    'healthHubConsultationsSub': 'Pediatrician and follow-ups',
    'consultationsTitle': 'Checkups',
    'consultationsIntro': 'Log visits with date and time; they show in the Home day summary.',
    'consultationsSoonTitle': 'Coming soon',
    'consultationsComingBody':
        'Soon you will be able to log visits, attach notes and return reminders.',
    'homeSummaryHealthStripTitle': 'Vaccines and checkups this day',
    'homeSummaryHealthStripEmpty': 'No vaccines or checkups logged for this day.',
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
    'settingsAiMicSub': 'Shows the microphone button on Home (work in progress).',
    'reportNoWeight': 'No weight data yet.',
    'reportNoHeight': 'No height data yet.',
    'memoriesPhotoError': 'Could not select the photo.',
    'memoriesTodayTitle': "Today's memories",
    'memoriesTodayAsk': 'Have you added your photo for today?',
    'memoriesNotYet': 'Not yet',
    'memoriesAddPhotoDialog': 'Add photo',
    'memoriesAlreadyPostedToday': "You've already added today's photo.",
    'memoriesWallEmpty': 'Your wall is still empty. Add the first photo of the day!',
    'memoriesHighlights': 'Highlights',
    'memoriesWallSection': 'Wall',
    'settingsMotherProfile': 'My profile',
    'profileEditMother': 'Edit mother\'s details',
    'profileEditBaby': 'Edit baby\'s details',
    'profileDataSaved': 'Saved.',
    'profileEditData': 'Edit details',
    'contactTitle': 'Contact',
    'contactIntro': 'Send a message by email. We will open your email app with the fields filled in.',
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
    'motherProfileTabMother': 'Mom',
    'motherProfileTabBabies': 'Babies',
    'motherProfileNoData': 'No profile found. Please try again in a moment.',
    'motherProfileSectionInfo': 'Info',
    'motherProfileFieldPhone': 'Phone',
    'motherProfileFieldBirth': 'Birth date',
    'motherProfileFieldHeight': 'Height',
    'motherProfileFieldFatherHeight': "Father's height",
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
    'sleepToggleAlertsSubtitle': 'Reminders based on last sleep ended and baby’s age.',
    'sleepAlertsWakeWindowRulerValueAuto': 'Effective value on this ruler: {m} min (automatic by age).',
    'sleepAlertsWakeWindowRulerValueCustom': 'Value on this ruler: {m} min (custom).',
    'sleepAlertsWakeWindowSliderLabelAuto': '{m} min · auto',
    'sleepAlertsWakeWindowSliderLabelCustom': '{m} min',
    'sleepAlertsApproachRulerValueDefault': 'Lead time on this ruler: {m} min (default).',
    'sleepAlertsApproachRulerValueCustom': 'Lead time on this ruler: {m} min.',
    'sleepAlertsApproachSliderLabelDefault': '{m} min · default',
    'sleepAlertsApproachSliderLabelCustom': '{m} min',
    'sleepAlertsWakeWindowAutomatic': 'Awake-window limit for the alert: {m} min (automatic from age table).',
    'sleepAlertsWakeWindowAutomaticNoBirth':
        'Add your baby’s birth date in Profile for accurate timing; for now using a fallback of {m} min.',
    'sleepAlertsMonthsApprox': 'Age table bracket: ~{n} mo',
    'sleepAlertsWakeWindowCustom': 'Custom awake-window limit: {m} min.',
    'sleepAlertsApproachAuto': 'Reminder before limit: default {m} min lead time.',
    'sleepAlertsApproachCustom': 'Reminder before limit: custom {m} min lead time.',
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
    'sleepConfirmBackTitle': 'Leave sleep tracking?',
    'sleepConfirmBackBody': 'This session is not saved yet. Discard it?',
    'sleepConfirmCancelSessionTitle': 'Cancel sleep?',
    'sleepConfirmCancelSessionBody': 'Time recorded in this session will be lost.',
    'sleepDiscard': 'Discard',
    'sleepHistoryTitle': 'Sleep history',
    'sleepHistoryEmpty': 'No sleep sessions yet.',
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
    'sleepHeroSleepingCaption': 'When she wakes up, tap End sleep to save this session.',
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
    'diaperToggleAlertsSubtitle': 'Get notified around the suggested next change.',
    'healthGrowthToggleAlerts': 'Growth alerts',
    'healthGrowthToggleAlertsSubtitle': 'Weight-loss vs. last log and overdue measurements.',
    'feedingScreenAlertsHint': 'To change timing, open More › Alerts.',
    'sleepNotifTitle': 'Sleep',
    'sleepNotifBeforeBody': 'It may be a good time to help baby settle to sleep.',
    'sleepNotifOverdueBody': 'Your baby may be tired — try starting sleep gently.',
    'notifChannelRemindersName': 'Reminders',
    'notifChannelRemindersDesc': 'Alerts for feeding, diapers, sleep, visits, and vaccines.',
    'notifChannelGrowthName': 'Growth',
    'notifChannelGrowthDesc': 'Weight alerts and long gaps between measurements.',
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
    'feedingNoBabyHint': 'Register a baby first in "More > Register (mom & babies)".',
    'feedingPickBabyLabel': 'Select baby',
    'feedingEmptyDataHint': 'No data yet. Use "Start feeding" to log with one tap.',
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
    'feedingHubSolidDescribe': 'What was offered? (optional)',
    'feedingHubOverviewEmpty': 'No entries in this list yet.',
    'feedingHubMlRequired': 'Enter amount in ml.',
    'feedingHubTimerTooShort': 'Keep the timer running a few seconds before saving this feeding.',
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
    'feedingNotifyNote': 'Note: for now this is visual only. Notifications will come later.',
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
    'vaccNoBabies': 'No baby registered yet. Go to "More > Register (mom & baby)".',
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
    'devLeapsIntro': 'Common development phases for {name}. The text is supportive and not alarmist.',
    'devLeapsNeedBirth': 'To show phases by age, add the baby’s birth date in the profile.',
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
    'devLeap_dv01_lead': '{baby_name} may be having an intense adjustment to the new surroundings.',
    'devLeap_dv01_emotion': 'Everything is still very new.',
    'devLeap_dv02_range': 'Week 2',
    'devLeap_dv02_title': 'More alert',
    'devLeap_dv02_lead': '{baby_name} may be starting to notice voices and faces a little better.',
    'devLeap_dv02_emotion': 'The emotional bond keeps growing.',
    'devLeap_dv03_range': 'Week 3',
    'devLeap_dv03_title': 'More sensitive',
    'devLeap_dv03_lead': '{baby_name} may be more sensitive to the environment around them.',
    'devLeap_dv03_emotion': 'The brain is maturing quickly.',
    'devLeap_dv04_range': 'Week 4',
    'devLeap_dv04_title': 'Small interactions',
    'devLeap_dv04_lead': '{baby_name} may be beginning to interact a bit more.',
    'devLeap_dv04_emotion': 'Your baby starts building social connections.',
    'devLeap_dv05_range': 'Week 5',
    'devLeap_dv05_title': 'New discoveries',
    'devLeap_dv05_lead': '{baby_name} may be noticing more of their own movements.',
    'devLeap_dv05_emotion': 'Their body starts to gain meaning.',
    'devLeap_dv06_range': 'Week 6',
    'devLeap_dv06_title': 'More connected',
    'devLeap_dv06_lead': '{baby_name} may be more tuned in to people\'s emotions.',
    'devLeap_dv06_emotion': 'The emotional bond keeps strengthening.',
    'devLeap_dv07_range': 'Weeks 7–8',
    'devLeap_dv07_title': 'Changing sleep',
    'devLeap_dv07_lead': '{baby_name} may be going through important sleep shifts.',
    'devLeap_dv07_emotion': 'The brain is maturing quickly.',
    'devLeap_dv08_range': '2–3 months',
    'devLeap_dv08_title': 'More awareness',
    'devLeap_dv08_lead': '{baby_name} may be noticing more of their body and the world around them.',
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
    'devLeap_dv12_lead': '{baby_name} may be understanding space and the environment better.',
    'devLeap_dv12_emotion': 'The world feels bigger each day.',
    'devLeap_dv13_range': '7–8 months',
    'devLeap_dv13_title': 'More attachment',
    'devLeap_dv13_lead': '{baby_name} may be in a phase of greater emotional need.',
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
    'devLeap_dv19_lead': '{baby_name} may be entering a phase of vivid imagination.',
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
    'devLeap_dv01_keywords': 'adjustment\nbond\nsecurity\nsensitivity\nwelcoming calm',
    'devLeap_dv01_detailMay':
        'frequent crying\nfrequent wake-ups\nconstant need for cuddling\nirregular sleep\ngreater sensitivity',
    'devLeap_dv01_detailHelp':
        'skin-to-skin\ncalm voice\ndim light\nfewer stimuli\nsteady soothing',
    'devLeap_dv01_detailSkills': 'notice caregiver scent\nreact to sounds\nprimitive reflexes',
    'devLeap_dv01_detailEmotional':
        'Your baby does not grasp routines yet. They understand presence, warmth, and safety.',
    'devLeap_dv02_homeBullets':
        'watches more\nrecognises voices\nattentive when held\nbegins tiny interactions',
    'devLeap_dv02_detailWhats':
        'Little by little babies notice faces, voices, scents, and emotional presence. Mom’s voice usually brings comfort and predictability.',
    'devLeap_dv02_keywords': 'recognition\nconnection\ncomfort\npresence\nobservation',
    'devLeap_dv02_detailMay':
        'more watching\nlonger awake periods\nreaction to voice\ncalm in arms',
    'devLeap_dv02_detailHelp':
        'talk eye-to-eye\nsing softly\neye contact\nsoothing',
    'devLeap_dv02_detailSkills': 'track faces\nrecognise voices\nwatch movements',
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
    'devLeap_dv03_detailSkills': 'more facial expressions\nmore attention to surroundings',
    'devLeap_dv03_detailEmotional':
        'Your baby is not “difficult”; they’re still learning the world.',
    'devLeap_dv04_homeBullets':
        'watches faces\nfollows movements\nshows attention\nresponds more to people',
    'devLeap_dv04_detailWhats':
        'They pay closer attention follow people spot expressions and react to what is around.',
    'devLeap_dv04_keywords': 'interaction\nattention\nobservation\nexpressions\nbond',
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
    'devLeap_dv07_detailSkills': 'stronger interplay curiosity richer expressions',
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
    'devLeap_dv09_homeBullets': 'laughs more answers people makes sounds seeks play',
    'devLeap_dv09_detailWhats':
        'They read emotions voices faces and joyful back-and-forth better.',
    'devLeap_dv09_keywords':
        'social life laughter communication expressions attachment',
    'devLeap_dv09_detailMay':
        'big giggles\nlooping sounds\nspirited play\nseeks playful games',
    'devLeap_dv09_detailHelp': 'play often mirror moods echo coos chatter daily',
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
    'devLeap_dv10_detailEmotional':
        'Exploring is central learning here.',
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
    'devLeap_dv11_detailEmotional':
        'Connection blossoms before fluent words.',
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
    'devLeap_dv12_detailEmotional': 'Exploring the space around them builds confidence.',
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
    'devLeap_dv14_detailSkills':
        'clapping\ncrawling\nfinds hidden objects',
    'devLeap_dv14_detailEmotional':
        'Repetition anchors big learning leaps.',
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
    'devLeap_dv15_detailSkills':
        'pulls up\ncruises furniture\nmaps the room',
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
    'devLeap_dv16_detailSkills':
        'points\nrepeats sounds\nnotices simple words',
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
    'devLeap_dv17_detailSkills':
        'first steps first words\nmore independence',
    'devLeap_dv17_detailEmotional':
        'Each brave try strengthens self-trust.',
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
    'regFatherHeight': "Dad's height (cm)",
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
    'scheduledFeedingReminderBody':
        'Momento del recordatorio de alimentación. Toca para registrar.',
    'scheduledDiaperReminderTitle': 'Cambio de pañal',
    'scheduledDiaperReminderBody':
        'Puede ser hora de cambiar el pañal desde la última vez. Toca para registrar.',
    'homeTimeToFeed': '¡Hora de alimentar!',
    'sleepNotifTitle': 'Sueño',
    'sleepNotifBeforeBody': 'Puede ser un buen momento para ayudar al bebé a dormir.',
    'sleepNotifOverdueBody':
        'Tu bebé puede estar cansado — intenta iniciar el sueño con calma.',
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
    'notifChannelRemindersName': 'Recordatorios',
    'notifChannelRemindersDesc': 'Alertas de alimentación, pañales y sueño.',
    'notifChannelGrowthName': 'Crecimiento',
    'notifChannelGrowthDesc': 'Alertas de peso y ausencia prolongada de mediciones.',
    'whatHappenedNow': '¿Qué pasó ahora?',
    'momNote': 'Nota de mamá',
    'saveRecord': 'Guardar registro',
    'reportsTitle': 'Informes',
    'reportsSubtitle': 'Resumen para mamá y el pediatra.',
    'growth': 'Crecimiento',
    'pediatricReport': 'Informe pediátrico',
    'pediatricReportDesc': 'Genera un PDF con peso, sueño, alimentación, pañales, vacunas, citas y notas.',
    'generatePdf': 'Generar PDF',
    'memoriesTitle': 'Libro de recuerdos',
    'memoriesSubtitle': 'Momentos importantes para guardar para siempre.',
    'memoriesAlbumPromoTitle': 'O seu livro de recordação completo',
    'memoriesAlbumPromoSubtitle':
        'Descarregue un PDF elegante con cubierta FaceBaby, marco decorativo y todas las insignias que ya completó.',
    'memoriesAlbumDownloadCta': 'Descargar PDF del álbum',
    'memoriesAlbumGenerating': 'Generando su álbum…',
    'memoriesAlbumNeedFilled': 'Complete al menos un momento en el álbum para generar el PDF.',
    'memoriesAlbumError': 'No se pudo generar el PDF.',
    'memoriesAlbumCoverMain': 'Libro de recuerdos',
    'memoriesAlbumCoverTagline': 'Momentos especiales con {name}',
    'memoriesAlbumFooter': 'Creado con FaceBaby',
    'addMemory': 'Agregar recuerdo',
    'settingsTitle': 'Más',
    'registerMotherBaby': 'Registro (mamá y bebé)',
    'vaccinesCard': 'Vacunas (cartilla)',
    'language': 'Idioma',
    'settingsSoonTitle': 'Próximamente',
    'settingsSoonBadge': 'Pronto',
    'settingsRateUs': 'Califícanos',
    'settingsTermsOfUse': 'Términos de uso',
    'settingsPrivacyPolicy': 'Política de privacidad',
    'settingsSpecialThanks': 'Agradecimientos especiales',
    'settingsTellFriend': 'Cuéntale a un amigo',
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
    'authForgotDialogBody': 'Te enviaremos un enlace para restablecer tu contraseña.',
    'authForgotSend': 'Enviar',
    'authResetEmailSentSnackbar': 'Correo enviado. Revisa tu bandeja de entrada.',
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
    'authErrCredentialsGeneric': 'No se pudo iniciar sesión. Inténtalo de nuevo.',
    'authErrGoogleConfigAndroid':
        'El inicio con Google falló por configuración de la app (error 10).\n\n'
            '1) Firebase: Ajustes del proyecto → app Android → añade el SHA-1 del keystore de depuración.\n'
            '2) En la carpeta android ejecuta: gradlew signingReport y copia el SHA-1 "debug".\n'
            '3) Autenticación → activa Google.\n'
            '4) Vuelve a descargar google-services.json en android/app/.',
    'authErrLoginCancelled': 'Inicio de sesión cancelado.',
    'authErrUnexpected': 'Ocurrió un error inesperado.',
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
    'changeBabyTooltip': 'Cambiar bebé',
    'notificationsInboxTitle': 'Notificaciones',
    'notificationsInboxSubtitle': 'Últimos 3 días (entregadas y programadas, registradas en la app)',
    'notificationsEmpty': 'Aún no hay notificaciones registradas en este período.',
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
    'deleteAccountReauthTitle': 'Confirmar identidad',
    'deleteAccountReauthBody':
        'Por seguridad necesitamos verificar tu identidad. Usa el mismo método de acceso habitual y terminaremos de borrar la cuenta.',
    'deleteAccountReauthPasswordHint': 'Contraseña actual',
    'deleteAccountReauthGoogle': 'Confirmar con Google',
    'deleteAccountReauthContinue': 'Confirmar contraseña',
    'deleteAccountReauthCantPassword':
        'Usa el botón del mismo método de entrada (ej. Google) con el que creaste la cuenta.',
    'homeBabyBannerForecastSleep': 'Previsión de sueño',
    'homeBabyBannerForecastWake': 'Previsión de despertar',
    'homeBabyBannerForecastSubtitleSleep': 'Señales de sueño detectadas\nsegún la hora actual',
    'homeBabyBannerForecastSubtitleWake': 'Según la hora actual y el patrón por edad',
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
    'memorySaveNeedPhotoOrText': 'Añade una foto o una descripción para guardar.',
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
    'homeFedAgo': 'Comió hace {when}',
    'homePeeAgo': 'Pipi hace {when}',
    'homePooAgo': 'Popó hace {when}',
    'homeNextNow': 'Próxima: ahora.',
    'homeNextIn': 'Próxima en {n} min.',
    'homeStatusOk': 'Todo bien ahora',
    'homeStatusWarn': 'Alerta leve',
    'homeStatusHungry': 'Puede tener hambre',
    'homeTipTitle': 'Consejo de hoy',
    'homeTipBody': 'Rutinas suaves ayudan a {name} a dormir mejor por la noche.',
    'summaryFeedings': 'TOMAS',
    'summarySleep': 'SUEÑO TOTAL',
    'summaryLastFeed': 'Última a las {time}',
    'summaryLastSleep': 'Último a las {time}',
    'exampleCard': 'Ejemplo de cartilla:',
  },
  AppLang.fr: {
    'appName': 'FaceBaby',
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
    'whatHappenedNow': "Que s'est-il passé ?",
    'momNote': 'Note de maman',
    'saveRecord': 'Enregistrer',
    'reportsTitle': 'Rapports',
    'reportsSubtitle': 'Un résumé pour maman et le pédiatre.',
    'growth': 'Croissance',
    'pediatricReport': 'Rapport pédiatrique',
    'pediatricReportDesc':
        "Générez un PDF avec le poids, le sommeil, l'alimentation, les couches, les vaccins, les rendez-vous et les notes.",
    'generatePdf': 'Générer PDF',
    'memoriesTitle': 'Livre de souvenirs',
    'memoriesSubtitle': 'Des moments importants à garder.',
    'addMemory': 'Ajouter un souvenir',
    'settingsTitle': 'Plus',
    'registerMotherBaby': 'Inscription (maman & bébé)',
    'vaccinesCard': 'Vaccins (carnet)',
    'language': 'Langue',
    'settingsSoonTitle': 'Bientôt',
    'settingsSoonBadge': 'Bientôt',
    'settingsRateUs': 'Notez-nous',
    'settingsTermsOfUse': "Conditions d'utilisation",
    'settingsPrivacyPolicy': 'Politique de confidentialité',
    'settingsSpecialThanks': 'Remerciements spéciaux',
    'settingsTellFriend': 'Parlez-en à un ami',
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
    'changeBabyTooltip': 'Changer de bébé',
    'notificationsInboxTitle': 'Notifications',
    'notificationsInboxSubtitle': '3 derniers jours (envoyées et programmées, enregistrées dans l’app)',
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
    'deleteAccountReauthTitle': 'Confirmer l’identité',
    'deleteAccountReauthBody':
        'Pour des raisons de sécurité, confirmez votre identité avec la même méthode de connexion que d’habitude — nous terminerons la suppression.',
    'deleteAccountReauthPasswordHint': 'Mot de passe actuel',
    'deleteAccountReauthGoogle': 'Confirmer avec Google',
    'deleteAccountReauthContinue': 'Confirmer le mot de passe',
    'deleteAccountReauthCantPassword':
        'Utilisez le bouton correspondant au fournisseur avec lequel le compte a été créé (ex. Google).',
    'homeBabyBannerForecastSleep': 'Prévision de sommeil',
    'homeBabyBannerForecastWake': 'Prévision de réveil',
    'homeBabyBannerForecastSubtitleSleep': 'Signes de sommeil détectés\nselon l’heure actuelle',
    'homeBabyBannerForecastSubtitleWake': 'Selon l’heure actuelle et le modèle par âge',
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
    'memoryTellMomentTitle': 'Racontez ce moment',
    'memoryTellMomentHint': 'Comment cela s’est-il passé ? Partagez les détails à garder…',
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
    'memorySaveNeedPhotoOrText': 'Ajoutez une photo ou une description pour enregistrer.',
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
    'summaryFeedings': 'TÉTÉES',
    'summarySleep': 'SOMMEIL TOTAL',
    'summaryLastFeed': 'Dernière à {time}',
    'summaryLastSleep': 'Dernier à {time}',
    'exampleCard': 'Exemple de carnet :',
  },
  AppLang.de: {
    'appName': 'FaceBaby',
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
    'whatHappenedNow': 'Was ist gerade passiert?',
    'momNote': 'Notiz der Mama',
    'saveRecord': 'Speichern',
    'reportsTitle': 'Berichte',
    'reportsSubtitle': 'Zusammenfassung für Mama und Kinderarzt.',
    'growth': 'Wachstum',
    'pediatricReport': 'Kinderarztbericht',
    'pediatricReportDesc': 'PDF mit Gewicht, Schlaf, Ernährung, Windeln, Impfungen, Terminen und Notizen erstellen.',
    'generatePdf': 'PDF erstellen',
    'memoriesTitle': 'Erinnerungsbuch',
    'memoriesSubtitle': 'Wichtige Momente für später.',
    'addMemory': 'Erinnerung hinzufügen',
    'settingsTitle': 'Mehr',
    'registerMotherBaby': 'Registrierung (Mama & Baby)',
    'vaccinesCard': 'Impfungen (Heft)',
    'language': 'Sprache',
    'settingsSoonTitle': 'Demnächst',
    'settingsSoonBadge': 'Bald',
    'settingsRateUs': 'Bewerte uns',
    'settingsTermsOfUse': 'Nutzungsbedingungen',
    'settingsPrivacyPolicy': 'Datenschutzerklärung',
    'settingsSpecialThanks': 'Besonderer Dank',
    'settingsTellFriend': 'Einem Freund erzählen',
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
    'changeBabyTooltip': 'Baby wechseln',
    'helloMomNamed': 'Hallo, Mama {name}!',
    'registerVerb': 'Eintragen',
    'viewCalendar': 'Kalender ansehen',
    'shortcutMilk': 'Stillen',
    'shortcutSleep': 'Schlaf',
    'shortcutVaccines': 'Impfungen',
    'homeFedAgo': 'Gefüttert vor {when}',
    'homePeeAgo': 'Pipi vor {when}',
    'homePooAgo': 'Windel vor {when}',
    'homeNextNow': 'Nächste: jetzt.',
    'homeNextIn': 'Nächste in {n} Min.',
    'homeStatusOk': 'Alles gut',
    'homeStatusWarn': 'Leichte Warnung',
    'homeStatusHungry': 'Vielleicht hungrig',
    'homeTipTitle': 'Tipp für heute',
    'homeTipBody': 'Sanfte Routinen helfen {name}, nachts besser zu schlafen.',
    'summaryFeedings': 'MAHIZEITEN',
    'summarySleep': 'SCHLAF GESAMT',
    'summaryLastFeed': 'Letzte um {time}',
    'summaryLastSleep': 'Letzter um {time}',
    'exampleCard': 'Beispiel-Impfheft:',
  },
  AppLang.it: {
    'appName': 'FaceBaby',
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
    'todaySummary': 'Riepilogo di oggi',
    'nextEvents': 'Prossimi eventi',
    'quickRecordsTitle': 'Registri rapidi',
    'quickRecordsSubtitle': 'Aggiungi la routine del bimbo in pochi tocchi.',
    'whatHappenedNow': 'Cosa è successo ora?',
    'momNote': 'Nota della mamma',
    'saveRecord': 'Salva',
    'reportsTitle': 'Report',
    'reportsSubtitle': 'Un riepilogo per la mamma e il pediatra.',
    'growth': 'Crescita',
    'pediatricReport': 'Report pediatrico',
    'pediatricReportDesc': 'Genera un PDF con peso, sonno, alimentazione, pannolini, vaccini, visite e note.',
    'generatePdf': 'Genera PDF',
    'memoriesTitle': 'Libro dei ricordi',
    'memoriesSubtitle': 'Momenti importanti da conservare.',
    'addMemory': 'Aggiungi ricordo',
    'settingsTitle': 'Altro',
    'registerMotherBaby': 'Registrazione (mamma e bimbo)',
    'vaccinesCard': 'Vaccini (libretto)',
    'language': 'Lingua',
    'settingsSoonTitle': 'In arrivo',
    'settingsSoonBadge': 'Presto',
    'settingsRateUs': 'Valutaci',
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
    'changeBabyTooltip': 'Cambia bimbo',
    'helloMomNamed': 'Ciao, Mamma {name}!',
    'registerVerb': 'Registra',
    'viewCalendar': 'Vedi calendario',
    'shortcutMilk': 'Poppata',
    'shortcutSleep': 'Sonno',
    'shortcutVaccines': 'Vaccini',
    'homeFedAgo': 'Ha mangiato {when} fa',
    'homePeeAgo': 'Pipi {when} fa',
    'homePooAgo': 'Pupù {when} fa',
    'homeNextNow': 'Prossima: ora.',
    'homeNextIn': 'Tra {n} min.',
    'homeStatusOk': 'Tutto ok',
    'homeStatusWarn': 'Attenzione',
    'homeStatusHungry': 'Potrebbe avere fame',
    'homeTipTitle': 'Suggerimento di oggi',
    'homeTipBody': 'Routine leggere aiutano {name} a dormire meglio la notte.',
    'summaryFeedings': 'POPPIATE',
    'summarySleep': 'SONNO TOTALE',
    'summaryLastFeed': 'Ultima alle {time}',
    'summaryLastSleep': 'Ultimo alle {time}',
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
    'pediatricReportDesc': 'वजन, नींद, दूध/खाना, डायपर, टीके, अपॉइंटमेंट और नोट्स के साथ PDF बनाएं।',
    'generatePdf': 'PDF बनाएं',
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
    'homeTipBody': 'हल्की दिनचर्या {name} को रात में बेहतर सोने में मदद करती है।',
    'summaryFeedings': 'फीडिंग',
    'summarySleep': 'कुल नींद',
    'summaryLastFeed': 'आखिरी {time}',
    'summaryLastSleep': 'आखिरी {time}',
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
    'pediatricReportDesc': 'Buat PDF dengan berat, tidur, makan, popok, vaksin, janji temu, dan catatan.',
    'generatePdf': 'Buat PDF',
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
    'homeTipBody': 'Rutinitas ringan membantu {name} tidur lebih nyenyak di malam hari.',
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
    'pediatricReportDesc': '体重、睡眠、授乳/食事、おむつ、ワクチン、受診、メモを含むPDFを生成します。',
    'generatePdf': 'PDF生成',
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
    'pediatricReportDesc': '체중, 수면, 수유/식사, 기저귀, 예방접종, 예약, 메모가 포함된 PDF를 생성합니다.',
    'generatePdf': 'PDF 생성',
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
    'pediatricReportDesc': 'Сформируйте PDF с весом, сном, кормлением, подгузниками, прививками, визитами и заметками.',
    'generatePdf': 'Сгенерировать PDF',
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
    'pediatricReportDesc': 'Kilo, uyku, beslenme, bez, aşılar, randevular ve notlarla PDF oluşturun.',
    'generatePdf': 'PDF oluştur',
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
    'homeTipBody': 'Hafif rutinler {name}’ın geceleri daha iyi uyumasını sağlar.',
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
    'pediatricReportDesc': '生成包含体重、睡眠、喂养、尿布、疫苗、就诊与备注的PDF。',
    'generatePdf': '生成PDF',
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

