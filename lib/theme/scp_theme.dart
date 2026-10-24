import 'package:flutter/material.dart';

class ScpColors {
  // Base background & surfaces
  static const bg = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF1F5F9);
  static const nav = Colors.white;
  static const line = Color(0xFFE2E8F0);

  // Typography
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const muted = Color(0xFF64748B);

  // Brand primary
  static const blue = Color(0xFF1D4ED8);
  static const blueDark = Color(0xFF1E40AF);
  static const blueLight = Color(0xFFDBEAFE);

  // Accents / Status
  static const green = Color(0xFF10B981);
  static const greenCard = Color(0xFFECFDF5);
  static const greenBorder = Color(0xFFA7F3D0);

  static const red = Color(0xFFEF4444);
  static const redCard = Color(0xFFFEF2F2);
  static const redBorder = Color(0xFFFECDD3);

  static const amber = Color(0xFFF59E0B);
  static const amberCard = Color(0xFFFFFBEB);
  static const amberBorder = Color(0xFFFDE68A);

  static const purple = Color(0xFF7C3AED);
  static const purpleCard = Color(0xFFF5F3FF);
  static const purpleBorder = Color(0xFFDDD6FE);

  static const teal = Color(0xFF0D9488);
  static const tealCard = Color(0xFFF0FDFA);
  static const tealBorder = Color(0xFF99F6E4);

  // Professional Gradients
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
  );

  static const tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
  );

  static const navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF334155)],
  );

  static const purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
  );

  static const amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB45309), Color(0xFFD97706)],
  );
}

ThemeData scpTheme() {
  const scheme = ColorScheme.light(
    primary: ScpColors.blue,
    onPrimary: Colors.white,
    secondary: ScpColors.teal,
    onSecondary: Colors.white,
    surface: ScpColors.surface,
    onSurface: ScpColors.text,
    surfaceContainerHighest: ScpColors.surfaceAlt,
    error: ScpColors.red,
    outline: ScpColors.line,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: ScpColors.bg,
    colorScheme: scheme,
    dividerColor: ScpColors.line,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ScpColors.text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: ScpColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: ScpColors.text),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: ScpColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ScpColors.line, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: ScpColors.muted),
      hintStyle: const TextStyle(color: ScpColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ScpColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ScpColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ScpColors.blue, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ScpColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ScpColors.blue,
        side: const BorderSide(color: ScpColors.blue, width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

ThemeData scpDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: Color(0xFF93C5FD),
    onPrimary: Color(0xFF172554),
    secondary: Color(0xFF5EEAD4),
    onSecondary: Color(0xFF042F2E),
    surface: Color(0xFF1E293B),
    onSurface: Color(0xFFE2E8F0),
    surfaceContainerHighest: Color(0xFF334155),
    error: Color(0xFFFCA5A5),
    outline: Color(0xFF475569),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    colorScheme: scheme,
    dividerColor: scheme.outline,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E293B),
      foregroundColor: Color(0xFFE2E8F0),
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Color(0xFFE2E8F0),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: Color(0xFFE2E8F0)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: scheme.onSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
