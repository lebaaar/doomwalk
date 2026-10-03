import 'package:flutter/material.dart';

/// Night-on-the-mountain palette.
abstract final class Palette {
  static const night = Color(0xFF0B1220);
  static const ridge = Color(0xFF131D30);
  static const slate = Color(0xFF1B2840);
  static const line = Color(0xFF2E4A6B);
  static const glacier = Color(0xFF8FD3FF);
  static const summit = Color(0xFFFFB86B);
  static const alpenglow = Color(0xFFFF7A6B);
  static const moss = Color(0xFF7FE0B0);
  static const snow = Color(0xFFE6EEF6);
  static const mist = Color(0xFF9FB3C8);
}

const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.glacier,
    brightness: Brightness.dark,
  ).copyWith(
    surface: Palette.night,
    surfaceContainerLowest: Palette.night,
    surfaceContainerLow: Palette.ridge,
    surfaceContainer: Palette.ridge,
    surfaceContainerHigh: Palette.slate,
    primary: Palette.glacier,
    onPrimary: Palette.night,
    secondary: Palette.summit,
    tertiary: Palette.moss,
    error: Palette.alpenglow,
    outlineVariant: Palette.line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.night,
    textTheme: base.textTheme.apply(bodyColor: Palette.snow, displayColor: Palette.snow).copyWith(
          labelSmall: base.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.8,
            color: Palette.mist,
            fontWeight: FontWeight.w600,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.night,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Palette.ridge,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x332E4A6B)),
      ),
    ),
    sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.onDrag),
    dividerTheme: const DividerThemeData(color: Color(0x332E4A6B)),
  );
}
