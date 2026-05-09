import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../i18n/app_i18n.dart';
import '../theme/app_theme.dart';
import 'app_gate.dart';
import 'app_locale.dart';
import '../utils/portal_layout.dart';
import '../widgets/loading_scope.dart';
import '../widgets/loading_navigator_observer.dart';
import '../pages/auth/auth_gate.dart';

class FaceBabyApp extends StatelessWidget {
  const FaceBabyApp({super.key});

  static AppLanguageController get language => kAppLanguage;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AppI18nScope(
      notifier: kAppLanguage,
      child: AnimatedBuilder(
        animation: kAppLanguage,
        builder: (context, _) {
          final s = S.of(context);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: s.appName,
            theme: AppTheme.light(),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(textScaler: portalTypographyScaler(context)),
                child: child ?? const SizedBox.shrink(),
              );
            },
            navigatorKey: navigatorKey,
            navigatorObservers: [LoadingNavigatorObserver(navigatorKey)],
            locale: kAppLanguage.locale,
            supportedLocales: const [
              Locale('pt', 'BR'),
              Locale('en', 'US'),
              Locale('es', 'ES'),
              Locale('fr', 'FR'),
              Locale('de', 'DE'),
              Locale('it', 'IT'),
              Locale('hi', 'IN'),
              Locale('id', 'ID'),
              Locale('ja', 'JP'),
              Locale('ko', 'KR'),
              Locale('ru', 'RU'),
              Locale('tr', 'TR'),
              Locale('zh', 'CN'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeListResolutionCallback: (locales, supported) {
              if (locales == null || locales.isEmpty) {
                return kAppLanguage.locale;
              }
              for (final device in locales) {
                for (final s in supported) {
                  if (s.languageCode != device.languageCode) continue;
                  if (device.countryCode == null ||
                      s.countryCode == null ||
                      s.countryCode == device.countryCode) {
                    return s;
                  }
                }
              }
              return supported.first;
            },
            home: const AuthGate(child: LoadingScope(child: AppGate())),
          );
        },
      ),
    );
  }
}
