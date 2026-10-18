import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class JiraniTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: JiraniColors.brand,
      brightness: brightness,
      error: JiraniColors.critical,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JiraniRadius.field),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: JiraniSpace.m,
          vertical: JiraniSpace.m,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(jiraniMinTapTarget + 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JiraniRadius.button),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JiraniRadius.card),
        ),
      ),
    );
  }
}
