import 'package:flutter/material.dart';

/// Design tokens for the "dark console" look (see design/build_screens.py).
abstract final class T {
  static const bg = Color(0xFF0B0D10);
  static const surface = Color(0xFF101418);
  static const surface2 = Color(0xFF14181D);
  static const surface3 = Color(0xFF0F1317);
  static const line = Color(0xFF1F252C);
  static const line2 = Color(0xFF262D35);
  static const text = Color(0xFFE8ECF1);
  static const text2 = Color(0xFFC9D1DA);
  static const text3 = Color(0xFF8B95A2);
  static const muted = Color(0xFF6B7684);
  static const dim = Color(0xFF4A5461);
  static const accent = Color(0xFF5EE0FF);
  static const ok = Color(0xFF7DFFB0);
  static const danger = Color(0xFFFF6B6B);
  static const grid = Color(0xFF1C2229);

  static const sans = 'Space Grotesk';
  static const mono = 'JetBrains Mono';

  static const r10 = BorderRadius.all(Radius.circular(10));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r14 = BorderRadius.all(Radius.circular(14));
  static const r16 = BorderRadius.all(Radius.circular(16));

  /// Small uppercase mono caption, e.g. section labels.
  static const label = TextStyle(
    fontFamily: mono,
    fontSize: 10,
    color: dim,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w500,
  );

  static const monoSmall = TextStyle(fontFamily: mono, fontSize: 11, color: muted);
}

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: T.accent,
    onPrimary: T.bg,
    secondary: T.accent,
    onSecondary: T.bg,
    error: T.danger,
    onError: T.bg,
    surface: T.surface,
    onSurface: T.text,
    surfaceContainerHighest: T.surface2,
    onSurfaceVariant: T.text3,
    outline: T.line2,
    outlineVariant: T.line,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: T.bg,
    fontFamily: T.sans,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: T.text, fontSize: 14),
      bodySmall: TextStyle(color: T.muted, fontSize: 12),
      titleLarge: TextStyle(color: T.text, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: TextStyle(color: T.text, fontSize: 16, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(color: T.text, fontSize: 14, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: T.surface2,
      hintStyle: const TextStyle(color: T.dim),
      labelStyle: const TextStyle(color: T.muted),
      border: OutlineInputBorder(borderRadius: T.r12, borderSide: const BorderSide(color: T.line2)),
      enabledBorder: OutlineInputBorder(borderRadius: T.r12, borderSide: const BorderSide(color: T.line2)),
      focusedBorder: OutlineInputBorder(borderRadius: T.r12, borderSide: const BorderSide(color: T.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: T.accent,
      inactiveTrackColor: T.line2,
      thumbColor: T.accent,
      overlayColor: Color(0x335EE0FF),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? T.bg : T.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? T.accent : T.surface2),
      trackOutlineColor: const WidgetStatePropertyAll(T.line2),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: T.surface,
      dragHandleColor: T.line2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: T.surface,
      shape: RoundedRectangleBorder(borderRadius: T.r16),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: T.surface2,
      contentTextStyle: TextStyle(color: T.text, fontFamily: T.sans),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: T.line,
  );
}
