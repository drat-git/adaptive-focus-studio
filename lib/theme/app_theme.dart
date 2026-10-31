import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const teal = Color(0xFF386B6A);
  const background = Color(0xFFF3F5F4);
  const ink = Color(0xFF233335);
  const secondaryText = Color(0xFF50645F);
  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(6)),
  );

  final colors = ColorScheme.fromSeed(
    seedColor: teal,
    primary: teal,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: ink,
    onSurfaceVariant: secondaryText,
    outline: secondaryText,
    outlineVariant: const Color(0xFFCBD7D3),
    error: const Color(0xFF8E3737),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarThemeData(
      backgroundColor: background,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFCBD7D3),
      thickness: 1,
      space: 24,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: secondaryText),
        shape: buttonShape,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: teal,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: buttonShape,
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: secondaryText),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: teal, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
  );
}
