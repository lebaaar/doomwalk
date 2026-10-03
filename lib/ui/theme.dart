import 'package:flutter/material.dart';

/// "Glacier": cool neutrals and a single frost-cyan accent, the same colour
/// language as the frost overlay. The accent marks debt and primary actions
/// only. Dark and light variants share the structure; read them through
/// `context.colors` so widgets follow the active theme.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.ink,
    required this.raised,
    required this.raised2,
    required this.hairline,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.ridge,
  });

  final Color ink;
  final Color raised;
  final Color raised2;
  final Color hairline;
  final Color text;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color onAccent;

  /// Upper slope of the gauge's main ridge.
  final Color ridge;

  static const dark = Palette(
    ink: Color(0xFF0B0F14),
    raised: Color(0xFF121821),
    raised2: Color(0xFF18202B),
    hairline: Color(0xFF1F2A36),
    text: Color(0xFFE6EDF3),
    muted: Color(0xFF7D8B99),
    faint: Color(0xFF55626F),
    accent: Color(0xFF7CC4E8),
    onAccent: Color(0xFF06131C),
    ridge: Color(0xFF243344),
  );

  /// Light: the accent is deepened to keep 4.5:1 contrast on white.
  static const light = Palette(
    ink: Color(0xFFF4F6F9),
    raised: Color(0xFFFFFFFF),
    raised2: Color(0xFFE9EDF2),
    hairline: Color(0xFFDCE2E9),
    text: Color(0xFF111821),
    muted: Color(0xFF5A6774),
    faint: Color(0xFF94A0AC),
    accent: Color(0xFF16739E),
    onAccent: Color(0xFFFFFFFF),
    ridge: Color(0xFFC9D6E3),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      ink: l(ink, other.ink),
      raised: l(raised, other.raised),
      raised2: l(raised2, other.raised2),
      hairline: l(hairline, other.hairline),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      ridge: l(ridge, other.ridge),
    );
  }
}

extension PaletteContext on BuildContext {
  Palette get colors => Theme.of(this).extension<Palette>()!;
}

/// One radius scale: surfaces 16, small elements 8, buttons are pills.
abstract final class Radii {
  static const surface = 16.0;
  static const small = 8.0;
}

const tabular = [FontFeature.tabularFigures()];

/// Figures use tabular digits so values don't jitter as they change.
const numeric = TextStyle(fontFamily: 'Geist', fontFeatures: tabular);

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: brightness).copyWith(
    surface: p.ink,
    surfaceContainerLowest: p.ink,
    surfaceContainerLow: p.raised,
    surfaceContainer: p.raised,
    surfaceContainerHigh: p.raised2,
    surfaceContainerHighest: p.raised2,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.text,
    onSecondary: p.ink,
    secondaryContainer: p.raised2,
    onSecondaryContainer: p.text,
    error: p.accent,
    outline: p.faint,
    outlineVariant: p.hairline,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Geist', extensions: [p]);
  final t = base.textTheme.apply(bodyColor: p.text, displayColor: p.text);
  const pill = StadiumBorder();
  return base.copyWith(
    scaffoldBackgroundColor: p.ink,
    splashFactory: InkSparkle.splashFactory,
    textTheme: t.copyWith(
      displayLarge: t.displayLarge?.copyWith(fontWeight: FontWeight.w300, letterSpacing: -2.5, height: 1),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w400, letterSpacing: -0.8, height: 1.15),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.3),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.1),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
      bodySmall: t.bodySmall?.copyWith(color: p.muted, height: 1.4),
      labelSmall: t.labelSmall?.copyWith(color: p.muted, letterSpacing: 0.2),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.ink,
      scrolledUnderElevation: 0,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Geist', fontSize: 20, fontWeight: FontWeight.w500, color: p.text),
    ),
    cardTheme: CardThemeData(
      color: p.raised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.surface))),
    ),
    dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.raised2,
        disabledForegroundColor: p.faint,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        foregroundColor: p.text,
        side: BorderSide(color: p.hairline),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: pill, foregroundColor: p.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStatePropertyAll(BorderSide(color: p.hairline)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.raised2 : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.text : p.muted),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.text,
      inactiveTrackColor: p.hairline,
      thumbColor: p.text,
      overlayColor: p.text.withValues(alpha: 0.08),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      trackHeight: 3,
      showValueIndicator: ShowValueIndicator.never,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.raised2),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(iconColor: p.muted, contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.raised2,
      isDense: true,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.small)),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: p.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.raised2,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: 'Geist',
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w500 : FontWeight.w400,
            color: s.contains(WidgetState.selected) ? p.text : p.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? p.accent : p.muted)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.text),
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
