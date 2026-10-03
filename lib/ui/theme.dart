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
    accentContainer: Color(0xFF1C3646),
    onAccentContainer: Color(0xFFBFE3F5),
    danger: Color(0xFFF2B8B5),
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
    accentContainer: Color(0xFFD6E8F2),
    onAccentContainer: Color(0xFF0D4A66),
    danger: Color(0xFFB3261E),
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
