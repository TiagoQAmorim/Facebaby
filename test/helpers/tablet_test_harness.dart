import 'package:facebaby_flutter/app/app_locale.dart';
import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Tablet ~10" 16:10 (logical px).
const tablet10Landscape = Size(1280, 800);
const tablet10Portrait = Size(800, 1280);

Widget tabletTestApp({
  required Widget child,
  required Size size,
}) {
  return AppI18nScope(
    notifier: kAppLanguage,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: 2.0,
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
        ),
        child: child,
      ),
    ),
  );
}
