import 'package:flutter/material.dart';

/// "Frost", taken from the app icon: navy on white and frost blue, and the
/// same mark inverted for dark mode. The page is tinted frost so plain cards
/// lift off it; the accent marks debt and primary actions only. Read colours
/// through `context.colors` so widgets follow the active theme.
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
    required this.heroFrom,
    required this.heroTo,
    required this.onHero,
    required this.onHeroMuted,
    required this.calmFrom,
    required this.calmTo,
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

  /// The Today card while you owe: the icon's strongest colour as a
  /// gradient, so "go walk" is the loudest thing on screen.
  final Color heroFrom;
  final Color heroTo;
  final Color onHero;
  final Color onHeroMuted;

  /// The Today card while scrolling is still free: the icon's background.
  final Color calmFrom;
  final Color calmTo;

  /// Dark: the logo inverted, frost-blue ticks on deep navy.
  static const dark = Palette(
    ink: Color(0xFF07131F),
    raised: Color(0xFF0E1F30),
    raised2: Color(0xFF173350),
    hairline: Color(0xFF1B3A56),
    text: Color(0xFFE6F1F8),
    muted: Color(0xFF8EA9BD),
    faint: Color(0xFF4C6A80),
    accent: Color(0xFFA9D3EC),
    onAccent: Color(0xFF07131F),
    accentContainer: Color(0xFF16395A),
    onAccentContainer: Color(0xFFD6ECF8),
    danger: Color(0xFFF2B8B5),
    heroFrom: Color(0xFFBFE0F3),
    heroTo: Color(0xFF86BCDD),
    onHero: Color(0xFF07131F),
    onHeroMuted: Color(0xFF1F4462),
    calmFrom: Color(0xFF173A5A),
    calmTo: Color(0xFF0E1F30),
  );

  /// Light: the logo itself, navy on white and frost blue.
  static const light = Palette(
    ink: Color(0xFFEEF4F9),
    raised: Color(0xFFFFFFFF),
    raised2: Color(0xFFE2F0F8),
    hairline: Color(0xFFD3E3EE),
    text: Color(0xFF0B2235),
    muted: Color(0xFF4F6B80),
    faint: Color(0xFF9DB6C7),
    accent: Color(0xFF0E4166),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFD2E6F4),
    onAccentContainer: Color(0xFF0E4166),
    danger: Color(0xFFB3261E),
    heroFrom: Color(0xFF15527E),
    heroTo: Color(0xFF0A2E4A),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFB4D3E8),
    calmFrom: Color(0xFFD6EAF7),
    calmTo: Color(0xFFFFFFFF),
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
      heroFrom: l(heroFrom, other.heroFrom),
      heroTo: l(heroTo, other.heroTo),
      onHero: l(onHero, other.onHero),
      onHeroMuted: l(onHeroMuted, other.onHeroMuted),
      calmFrom: l(calmFrom, other.calmFrom),
      calmTo: l(calmTo, other.calmTo),
    );
  }
}

extension PaletteContext on BuildContext {
  Palette get colors => Theme.of(this).extension<Palette>()!;
}

/// Material 3 expressive corner scale: cards 24 (extra large), sheets 32,
/// small elements 12, buttons are pills.
abstract final class Radii {
  static const surface = 24.0;
  static const sheet = 32.0;
  static const small = 12.0;
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
    // Heavy, tightly tracked figures and headings; light body text.
    textTheme: t.copyWith(
      displayLarge: t.displayLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -2.5, height: 1),
      displayMedium: t.displayMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -2, height: 1),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5, height: 1.15),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3, height: 1.2),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
      toolbarHeight: 72,
      titleSpacing: Gaps.margin + 4,
      titleTextStyle:
          TextStyle(fontFamily: font, fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.8, color: p.text),
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
        shape: const WidgetStatePropertyAll(pill),
        minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
        side: WidgetStatePropertyAll(BorderSide(color: p.hairline)),
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
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w500, color: p.text),
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
    // Same colour as the page, so the bar reads as part of it rather than a
    // separate slab; the pill indicator carries the selection.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accentContainer,
      indicatorShape: const StadiumBorder(),
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: font,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
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

/// Group heading in a list: small, muted, sitting on the margin above the
/// group it names.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;

  /// Optional link at the end of the row, like "See all".
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(Gaps.margin + 4, 24, action == null ? Gaps.margin : 4, 8),
      child: Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: t.titleSmall?.copyWith(color: context.colors.muted, letterSpacing: 0.1)),
          ),
        ),
        if (action != null)
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 32), visualDensity: VisualDensity.compact),
            onPressed: onAction,
            child: Text(action!),
          ),
      ]),
    );
  }
}

/// Rows grouped into one rounded container on the page margin, the way
/// current Android settings lay out related options.
class TileGroup extends StatelessWidget {
  const TileGroup({super.key, required this.children, this.margin = true});
  final List<Widget> children;

  /// False when the parent already pads to the page margin.
  final bool margin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: margin ? Gaps.margin : 0),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );
}

/// An icon on a tonal rounded square, as list leading or stat marker.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, this.icon, this.child, this.size = 40, this.background, this.foreground});
  final IconData? icon;

  /// Drawn instead of [icon] (the logo ticks, for example).
  final Widget? child;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final fg = foreground ?? col.onAccentContainer;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? col.accentContainer,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: IconTheme(
        data: IconThemeData(color: fg, size: size * 0.5),
        child: child ?? Icon(icon),
      ),
    );
  }
}
