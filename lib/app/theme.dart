import 'package:flutter/material.dart';

/// ألوان التطبيق مأخوذة من شعار شركة الحفر العراقية.
class AppColors {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color brand;
  final Color brand2;
  final Color accent;
  final Color accentSoft;
  final Color gold;
  final Color goldSoft;
  final Color green;
  final Color greenSoft;
  final Color red;
  final Color redSoft;
  final Color blue;
  final Color blueSoft;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.brand,
    required this.brand2,
    required this.accent,
    required this.accentSoft,
    required this.gold,
    required this.goldSoft,
    required this.green,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
    required this.blue,
    required this.blueSoft,
  });

  static const light = AppColors(
    bg: Color(0xFFEEF1F5),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF5F7FA),
    line: Color(0xFFE4E8EE),
    ink: Color(0xFF0E1B2A),
    ink2: Color(0xFF4A5767),
    ink3: Color(0xFF8A96A5),
    brand: Color(0xFF0F2A44),
    brand2: Color(0xFF163B5E),
    accent: Color(0xFF9A2F63),
    accentSoft: Color(0xFFF6E7EF),
    gold: Color(0xFFD08A1E),
    goldSoft: Color(0xFFFDF1DF),
    green: Color(0xFF1E9E6A),
    greenSoft: Color(0xFFE3F5EC),
    red: Color(0xFFD2453D),
    redSoft: Color(0xFFFBE7E5),
    blue: Color(0xFF163B5E),
    blueSoft: Color(0xFFE6EEF7),
  );

  static const dark = AppColors(
    bg: Color(0xFF0B1420),
    surface: Color(0xFF132132),
    surface2: Color(0xFF182A3E),
    line: Color(0xFF22364C),
    ink: Color(0xFFEDF2F7),
    ink2: Color(0xFFB3C0CE),
    ink3: Color(0xFF7C8C9E),
    brand: Color(0xFF0A1A2B),
    brand2: Color(0xFF163B5E),
    accent: Color(0xFFE07AAA),
    accentSoft: Color(0xFF3A1F30),
    gold: Color(0xFFF0B354),
    goldSoft: Color(0xFF3A2E18),
    green: Color(0xFF4CC994),
    greenSoft: Color(0xFF17352A),
    red: Color(0xFFF07A72),
    redSoft: Color(0xFF3B1F1E),
    blue: Color(0xFF8DB7E2),
    blueSoft: Color(0xFF1A2D44),
  );
}

class AppTheme extends ThemeExtension<AppTheme> {
  final AppColors c;
  const AppTheme(this.c);

  @override
  AppTheme copyWith({AppColors? c}) => AppTheme(c ?? this.c);

  @override
  AppTheme lerp(covariant AppTheme? other, double t) => t < .5 ? this : (other ?? this);
}

extension AppThemeX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppTheme>()!.c;
}

const kFont = 'IBMPlexSansArabic';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: brightness,
    primary: c.accent,
    surface: c.surface,
    error: c.red,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kFont,
    scaffoldBackgroundColor: c.bg,
    extensions: [AppTheme(c)],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink, fontFamily: kFont),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: kFont, fontSize: 20, fontWeight: FontWeight.w700, color: c.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: TextStyle(color: c.ink3, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.accent, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.red, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontFamily: kFont, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accentSoft,
      surfaceTintColor: Colors.transparent,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: kFont,
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.accent : c.ink3,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 23,
            color: s.contains(WidgetState.selected) ? c.accent : c.ink3,
          )),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(fontFamily: kFont, color: c.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    }),
  );
}
