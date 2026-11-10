import 'package:flutter/material.dart';

/// The dashboard uses light cards, independently of the login screen's theme.
class DashboardTheme {
  static const ink = Color(0xFF172B24);
  static const muted = Color(0xFF52645A);
  static const green = Color(0xFF15803D);
  static const canvas = Color(0xFFF8FFF9);

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme:
            ColorScheme.fromSeed(seedColor: green, brightness: Brightness.light)
                .copyWith(
          primary: green,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: ink,
          onSurfaceVariant: muted,
        ),
        popupMenuTheme: const PopupMenuThemeData(
            color: Colors.white, surfaceTintColor: Colors.transparent),
        dialogTheme: const DialogThemeData(
            backgroundColor: canvas, surfaceTintColor: Colors.transparent),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(foregroundColor: green)),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                backgroundColor: green, foregroundColor: Colors.white)),
        inputDecorationTheme: const InputDecorationTheme(
            labelStyle: TextStyle(color: muted),
            hintStyle: TextStyle(color: muted)),
      );
}
