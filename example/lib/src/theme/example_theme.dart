import 'package:flutter/material.dart';

const wisperBotOrange = Color(0xFFFF762E);

ThemeData buildExampleTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: wisperBotOrange,
  ).copyWith(
    primary: wisperBotOrange,
    secondary: wisperBotOrange,
    onPrimary: Colors.white,
    surface: Colors.white,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      foregroundColor: Color(0xFF000000),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: wisperBotOrange,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: wisperBotOrange,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: wisperBotOrange),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    useMaterial3: true,
  );
}
