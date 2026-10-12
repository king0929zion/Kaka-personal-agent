import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'motion.dart';

abstract final class KColors {
  static const bg = Color(0xFFF7F7F6);
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF0F0EF);
  static const ink = Color(0xFF161616);
  static const muted = Color(0xFF858585);
  static const line = Color(0xFFE7E7E5);
  static const error = Color(0xFFC74141);
}

/// Shared visual geometry. A control has two sizes: its visible artwork and
/// its (larger) hit target. Keep spacing optical, not just numerically equal.
abstract final class KLayout {
  static const double pageGutter = 22;
  static const double compactGutter = 16;
  static const double maxContentWidth = 720;
  static const double minTouchTarget = 48;
  static const double listGap = 10;
  static const double sectionGap = 24;
  static const double trailingIcon = 18;
  static const double bodyText = 16;
  static const double secondaryText = 13;
}

/// Center readable content on tablets without stretching a phone layout
/// across the entire screen. On phones this fills all available width.
class KakaContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const KakaContentWidth({
    super.key,
    required this.child,
    this.maxWidth = KLayout.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

abstract final class KRadius {
  static const card = 30.0;
  static const sheet = 40.0;
  static const button = 28.0;
}

ThemeData kakaTheme() => ThemeData(
  useMaterial3: false,
  scaffoldBackgroundColor: KColors.bg,
  canvasColor: KColors.bg,
  splashColor: Colors.transparent,
  dividerColor: Colors.transparent,
  focusColor: Colors.transparent,
  hoverColor: Colors.transparent,
  shadowColor: Colors.transparent,
  dialogTheme: const DialogThemeData(backgroundColor: KColors.surface),
  cardColor: KColors.surface,
  listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.zero),
  visualDensity: VisualDensity.standard,
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
    headlineLarge: TextStyle(fontSize: 29, fontWeight: FontWeight.w600, letterSpacing: -1.1, color: KColors.ink),
    headlineMedium: TextStyle(fontSize: 23, fontWeight: FontWeight.w600, letterSpacing: -.6, color: KColors.ink),
    titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: KColors.ink),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: KColors.ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: KColors.ink),
    bodySmall: TextStyle(fontSize: 12, color: KColors.muted),
  ),
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: KakaPageTransitionsBuilder(),
    TargetPlatform.iOS: KakaPageTransitionsBuilder(),
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
