import 'package:flutter/material.dart';

/// "Frost", taken from the app icon: navy on white and frost blue, and the
/// same mark inverted for dark mode. The accent marks debt and primary
/// actions only. Read colours through `context.colors` so widgets follow the
/// active theme.
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
    required this.accentContainer,
    required this.onAccentContainer,
    required this.danger,
    required this.ridge,
  });

  final Color ink;
  final Color raised;
  final Color raised2;
  final Color hairline;
  final Color text;
  final Color muted;
  /// Decoration only (dividers' big brother, chart guides). Below 4.5:1, so
  /// never for text.
  final Color faint;
  final Color accent;
  final Color onAccent;

  /// Tonal fill for secondary actions and the selected nav item.
  final Color accentContainer;
  final Color onAccentContainer;

  /// Problems that need fixing (tracking off). Never used for debt.
  final Color danger;

  /// Upper slope of the gauge's main ridge.
  final Color ridge;

  /// Dark: the logo inverted, frost-blue ticks on deep navy.
  static const dark = Palette(
    ink: Color(0xFF07131F),
    raised: Color(0xFF0D1F30),
    raised2: Color(0xFF14304A),
    hairline: Color(0xFF1B3A56),
    text: Color(0xFFE6F1F8),
    muted: Color(0xFF8EA9BD),
    faint: Color(0xFF4C6A80),
    accent: Color(0xFFA9D3EC),
    onAccent: Color(0xFF07131F),
    accentContainer: Color(0xFF16395A),
    onAccentContainer: Color(0xFFD6ECF8),
    danger: Color(0xFFF2B8B5),
    ridge: Color(0xFF1E3D59),
  );

  /// Light: the logo itself, navy on white and frost blue.
  static const light = Palette(
    ink: Color(0xFFF7FBFE),
    raised: Color(0xFFFFFFFF),
    raised2: Color(0xFFE2F0F8),
    hairline: Color(0xFFD3E6F1),
    text: Color(0xFF0B2235),
    muted: Color(0xFF4F6B80),
    faint: Color(0xFF9DB6C7),
    accent: Color(0xFF0E4166),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFE2F0F8),
    onAccentContainer: Color(0xFF0E4166),
    danger: Color(0xFFB3261E),
    ridge: Color(0xFFC9DEEC),
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
      accentContainer: l(accentContainer, other.accentContainer),
      onAccentContainer: l(onAccentContainer, other.onAccentContainer),
      danger: l(danger, other.danger),
      ridge: l(ridge, other.ridge),
    );
  }
}

extension PaletteContext on BuildContext {
  Palette get colors => Theme.of(this).extension<Palette>()!;
}

/// Material 3 corner scale: cards 12 (medium), sheets 28 (extra large),
/// small elements 8, buttons are pills.
abstract final class Radii {
  static const surface = 12.0;
  static const sheet = 28.0;
  static const small = 8.0;
}

/// 8 dp spacing grid: screen margin 16, gaps between cards 12.
abstract final class Gaps {
  static const margin = 16.0;
  static const card = 12.0;
}

const font = 'RobotoFlex';

const tabular = [FontFeature.tabularFigures()];

/// Figures use tabular digits so values don't jitter as they change.
const numeric = TextStyle(fontFamily: font, fontFeatures: tabular);

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
    primaryContainer: p.accentContainer,
    onPrimaryContainer: p.onAccentContainer,
    secondaryContainer: p.accentContainer,
    onSecondaryContainer: p.onAccentContainer,
    error: p.danger,
    outline: p.faint,
    outlineVariant: p.hairline,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: font, extensions: [p]);
  final t = base.textTheme.apply(bodyColor: p.text, displayColor: p.text);
  const pill = StadiumBorder();
  return base.copyWith(
    scaffoldBackgroundColor: p.ink,
    splashFactory: InkSparkle.splashFactory,
    textTheme: t.copyWith(
      displayLarge: t.displayLarge?.copyWith(fontWeight: FontWeight.w300, letterSpacing: -1.5, height: 1),
      displayMedium: t.displayMedium?.copyWith(fontWeight: FontWeight.w300, letterSpacing: -1, height: 1),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w400, height: 1.15),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w500),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w500),
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
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 22, fontWeight: FontWeight.w400, color: p.text),
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
        disabledForegroundColor: p.muted,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        foregroundColor: p.text,
        side: BorderSide(color: p.hairline),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: pill,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: p.faint)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.accentContainer : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.onAccentContainer : p.text),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: font, fontWeight: FontWeight.w500, fontSize: 14)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.raised2,
      thumbColor: p.accent,
      overlayColor: p.accent.withValues(alpha: 0.12),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      trackHeight: 4,
      showValueIndicator: ShowValueIndicator.never,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.raised2),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: Gaps.margin),
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 16, color: p.text),
      subtitleTextStyle: TextStyle(fontFamily: font, fontSize: 14, height: 1.4, color: p.muted),
      minVerticalPadding: 12,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.faint,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.sheet))),
    ),
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
      indicatorColor: p.accentContainer,
      height: 80,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: font,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w500 : FontWeight.w400,
            color: s.contains(WidgetState.selected) ? p.text : p.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? p.onAccentContainer : p.muted)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.raised2,
      circularTrackColor: p.raised2,
      linearMinHeight: 8,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
    ),
  );
}

/// Group heading in a list, Material style: small, accent coloured, sitting
/// on the margin above the group it names.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.margin, 24, Gaps.margin, 8),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.colors.accent),
          ),
        ),
      );
}
