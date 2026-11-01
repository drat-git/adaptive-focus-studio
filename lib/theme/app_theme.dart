import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const maroon = Color(0xFF6D2637);
  const background = Color(0xFFFBF6EC);
  const paper = Color(0xFFFFFCF7);
  const ink = Color(0xFF302220);
  const secondaryText = Color(0xFF705953);
  const line = Color(0xFFDCCBC0);
  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  final colors = ColorScheme.fromSeed(
    seedColor: maroon,
    primary: maroon,
    onPrimary: paper,
    primaryContainer: const Color(0xFFF2DED5),
    onPrimaryContainer: maroon,
    secondary: const Color(0xFFA9443D),
    onSecondary: paper,
    surface: paper,
    onSurface: ink,
    onSurfaceVariant: secondaryText,
    outline: secondaryText,
    outlineVariant: line,
    error: const Color(0xFF9F2929),
  );
  final text = ThemeData(useMaterial3: true).textTheme;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: background,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        color: maroon,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: text.titleLarge?.copyWith(
        color: ink,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: text.titleMedium?.copyWith(
        color: ink,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: text.bodyLarge?.copyWith(color: ink),
      bodyMedium: text.bodyMedium?.copyWith(color: ink, height: 1.4),
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: background,
      foregroundColor: maroon,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: maroon,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      shape: Border(bottom: BorderSide(color: line)),
    ),
    cardTheme: const CardThemeData(
      color: paper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 24),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: maroon),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: buttonShape,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: maroon,
      foregroundColor: paper,
      elevation: 0,
      shape: buttonShape,
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: paper,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: secondaryText),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: maroon, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );
}
