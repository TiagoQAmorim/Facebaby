import 'package:flutter/material.dart';

/// [GlobalKey]s for coach-mark targets in the app tour.
abstract final class AppTourKeys {
  AppTourKeys._();

  static final babyBannerSleep =
      GlobalKey(debugLabel: 'appTourBabyBannerSleep');
  static final babyBannerFeeding =
      GlobalKey(debugLabel: 'appTourBabyBannerFeeding');
  static final babyBannerDiaper =
      GlobalKey(debugLabel: 'appTourBabyBannerDiaper');
  static final weeklyPhoto = GlobalKey(debugLabel: 'appTourWeeklyPhoto');
  static final familyTree = GlobalKey(debugLabel: 'appTourFamilyTree');
  static final familyTourHeader =
      GlobalKey(debugLabel: 'appTourFamilyTourHeader');
  static final navRecords = GlobalKey(debugLabel: 'appTourNavRecords');
  static final navAiNanny = GlobalKey(debugLabel: 'appTourNavAiNanny');
  static final navMemories = GlobalKey(debugLabel: 'appTourNavMemories');
  static final quickRegisterHeader =
      GlobalKey(debugLabel: 'appTourQuickRegisterHeader');
  static final quickRegisterCategories =
      GlobalKey(debugLabel: 'appTourQuickRegisterCategories');
  static final quickRegisterReports =
      GlobalKey(debugLabel: 'appTourQuickRegisterReports');
}
