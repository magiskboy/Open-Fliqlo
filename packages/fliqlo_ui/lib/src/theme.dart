import 'package:flutter/material.dart';

/// Visual tokens for the Open Fliqlo clock face.
abstract final class FliqloTheme {
  static const Color background = Color(0xFF000000);
  static const Color digitBackground = Color(0xFF1A1A1A);
  static const Color digitForeground = Color(0xFFF5F5F5);
  static const Color hinge = Color(0xFF0A0A0A);
  static const Color sheetBackground = Color(0xFF141414);
  static const Color sheetForeground = Color(0xFFE8E8E8);

  static const Duration flipDuration = Duration(milliseconds: 500);

  /// Digit font from gluqlo.ttf (glyphs: 0–9, A, M, P).
  static const String digitFontFamily = 'Fliqlo';
  static const String digitFontPackage = 'fliqlo_ui';

  static ThemeData material() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: sheetBackground,
        onSurface: sheetForeground,
        primary: digitForeground,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: digitForeground,
        inactiveTrackColor: Color(0xFF333333),
        thumbColor: digitForeground,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => digitForeground,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF555555)
              : const Color(0xFF333333),
        ),
      ),
    );
  }
}
