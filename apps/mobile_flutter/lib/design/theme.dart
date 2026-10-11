import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class KColors {
  static const bg = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF1F1F1);
  static const ink = Color(0xFF161616);
  static const muted = Color(0xFF858585);
  static const line = Color(0xFFEBEBEB);
  static const error = Color(0xFFC74141);
}

abstract final class KRadius {
  static const card = 28.0;
  static const sheet = 34.0;
  static const button = 26.0;
}

ThemeData kakaTheme() => ThemeData(
  useMaterial3: false,
  scaffoldBackgroundColor: KColors.bg,
  canvasColor: KColors.bg,
  splashColor: Colors.transparent,
  highlightColor: Colors.transparent,
  fontFamily: 'Roboto',
  colorScheme: const ColorScheme.light(
    primary: KColors.ink,
    onPrimary: KColors.surface,
    surface: KColors.surface,
    onSurface: KColors.ink,
    error: KColors.error,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(fontSize: 29, fontWeight: FontWeight.w650, letterSpacing: -1.1, color: KColors.ink),
    headlineMedium: TextStyle(fontSize: 23, fontWeight: FontWeight.w600, letterSpacing: -.6, color: KColors.ink),
    titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: KColors.ink),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: KColors.ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: KColors.ink),
    bodySmall: TextStyle(fontSize: 12, color: KColors.muted),
  ),
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
  }),
);

void configureSystemChrome() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: KColors.bg,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}
