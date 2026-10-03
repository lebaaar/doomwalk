import 'package:flutter/material.dart';

/// One cool neutral scale and a single accent (alpenglow orange) used for
/// debt and primary actions only. No secondary accent colours anywhere.
abstract final class Palette {
  static const ink = Color(0xFF0D1014);
  static const raised = Color(0xFF151A20);
  static const raised2 = Color(0xFF1C232B);
  static const hairline = Color(0xFF252D37);
  static const text = Color(0xFFE8ECF0);
  static const muted = Color(0xFF8C96A3);
  static const faint = Color(0xFF5D6773);
  static const accent = Color(0xFFE58A57);
  static const onAccent = Color(0xFF1A0F08);
}

/// One radius scale: surfaces 16, small elements 8, buttons are pills.
abstract final class Radii {
  static const surface = 16.0;
  static const small = 8.0;
}

const tabular = [FontFeature.tabularFigures()];

/// Figures use tabular digits so values don't jitter as they change.
const numeric = TextStyle(fontFamily: 'Geist', fontFeatures: tabular);

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    surface: Palette.ink,
    surfaceContainerLowest: Palette.ink,
    surfaceContainerLow: Palette.raised,
    surfaceContainer: Palette.raised,
    surfaceContainerHigh: Palette.raised2,
    surfaceContainerHighest: Palette.raised2,
    onSurface: Palette.text,
    onSurfaceVariant: Palette.muted,
    primary: Palette.accent,
    onPrimary: Palette.onAccent,
    secondary: Palette.text,
    onSecondary: Palette.ink,
    secondaryContainer: Palette.raised2,
    onSecondaryContainer: Palette.text,
    error: Palette.accent,
    outline: Palette.faint,
    outlineVariant: Palette.hairline,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Geist');
  final t = base.textTheme.apply(bodyColor: Palette.text, displayColor: Palette.text);
  const pill = StadiumBorder();
  return base.copyWith(
    scaffoldBackgroundColor: Palette.ink,
    splashFactory: InkSparkle.splashFactory,
    textTheme: t.copyWith(
      displayLarge: t.displayLarge?.copyWith(fontWeight: FontWeight.w300, letterSpacing: -2.5, height: 1),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w400, letterSpacing: -0.8, height: 1.15),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.3),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.1),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
      bodySmall: t.bodySmall?.copyWith(color: Palette.muted, height: 1.4),
      labelSmall: t.labelSmall?.copyWith(color: Palette.muted, letterSpacing: 0.2),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Geist', fontSize: 20, fontWeight: FontWeight.w500, color: Palette.text),
    ),
    cardTheme: const CardThemeData(
      color: Palette.raised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.surface))),
    ),
    dividerTheme: const DividerThemeData(color: Palette.hairline, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        backgroundColor: Palette.accent,
        foregroundColor: Palette.onAccent,
        disabledBackgroundColor: Palette.raised2,
        disabledForegroundColor: Palette.faint,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        foregroundColor: Palette.text,
        side: const BorderSide(color: Palette.hairline),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: pill, foregroundColor: Palette.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: const WidgetStatePropertyAll(BorderSide(color: Palette.hairline)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Palette.raised2 : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Palette.text : Palette.muted),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Palette.text,
      inactiveTrackColor: Palette.hairline,
      thumbColor: Palette.text,
      overlayColor: const Color(0x14E8ECF0),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      trackHeight: 3,
      showValueIndicator: ShowValueIndicator.never,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.onAccent : Palette.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.accent : Palette.raised2),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Palette.muted, contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Palette.raised2,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.small)),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: Palette.muted),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.text),
  );
}

/// Section heading: plain sentence case, no eyebrow styling.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 32, bottom: 12),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ]),
      );
}
