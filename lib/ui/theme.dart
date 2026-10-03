import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Frost": cool neutrals (near-black or off-white) with the icon's frost
/// blue / navy as the single accent. Cards are separated by a hairline, not
/// by tinting the page; the accent marks debt and primary actions only. Read colours
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
    required this.ridge,
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

  /// Upper slope of the gauge's main ridge.
  final Color ridge;

  /// The Today card while you owe: a deep navy fill ([heroFrom]) lit by a
  /// soft radial glow ([heroTo]) from the top corner, so "go walk" is the
  /// loudest thing on screen.
  final Color heroFrom;
  final Color heroTo;
  final Color onHero;
  final Color onHeroMuted;

  /// The Today card while scrolling is still free: a plain card ([calmFrom])
  /// with a much fainter glow ([calmTo]).
  final Color calmFrom;
  final Color calmTo;

  /// Dark: near-black with a cool tint, frost blue as the one accent.
  static const dark = Palette(
    ink: Color(0xFF0A0C0F),
    raised: Color(0xFF12151A),
    raised2: Color(0xFF1B1F25),
    hairline: Color(0xFF232830),
    text: Color(0xFFEDF0F3),
    muted: Color(0xFF8D96A1),
    faint: Color(0xFF4A525C),
    accent: Color(0xFFA9D3EC),
    onAccent: Color(0xFF0A0C0F),
    accentContainer: Color(0xFF16232E),
    onAccentContainer: Color(0xFFCDE6F5),
    danger: Color(0xFFF2B8B5),
    ridge: Color(0xFF1B2733),
    heroFrom: Color(0xFF101C27),
    heroTo: Color(0xFFA9D3EC),
    onHero: Color(0xFFEDF0F3),
    onHeroMuted: Color(0xFF93A9BA),
    calmFrom: Color(0xFF12151A),
    calmTo: Color(0xFFA9D3EC),
  );

  /// Light: off-white and white, the logo's navy as the one accent.
  static const light = Palette(
    ink: Color(0xFFF5F6F8),
    raised: Color(0xFFFFFFFF),
    raised2: Color(0xFFEDEFF2),
    hairline: Color(0xFFE3E6EA),
    text: Color(0xFF0C1117),
    muted: Color(0xFF5B6470),
    faint: Color(0xFFA5ADB7),
    accent: Color(0xFF0E4166),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFE2EDF5),
    onAccentContainer: Color(0xFF0E4166),
    danger: Color(0xFFB3261E),
    ridge: Color(0xFFD5E3EE),
    heroFrom: Color(0xFF0B1E2E),
    heroTo: Color(0xFF5B9BC7),
    onHero: Color(0xFFF4F7FA),
    onHeroMuted: Color(0xFFA3B9CA),
    calmFrom: Color(0xFFFFFFFF),
    calmTo: Color(0xFF5B9BC7),
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

/// One corner scale: cards 20, sheets 28, buttons, inputs and inner
/// elements 12, chips and tags 8.
abstract final class Radii {
  static const surface = 20.0;
  static const sheet = 28.0;
  static const small = 12.0;
  static const tag = 8.0;
}

/// 4 dp spacing grid: screen margin 20, gaps between cards 12.
abstract final class Gaps {
  static const margin = 20.0;
  static const card = 12.0;
}

const font = 'Geist';

const tabular = [FontFeature.tabularFigures()];

/// Figures use tabular digits so values don't jitter as they change.
const numeric = TextStyle(fontFamily: font, fontFeatures: tabular);

/// System bars for edge-to-edge drawing: both transparent, so the page (and
/// the bottom navigation bar) runs behind them. The contrast scrim Android
/// adds behind three-button navigation is turned off; without that it shows
/// as a grey band under the back, home and recents buttons.
SystemUiOverlayStyle overlayStyle(Brightness brightness) {
  final icons = brightness == Brightness.dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    statusBarBrightness: brightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );
}

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
  const button = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.small)));
  const label = TextStyle(fontFamily: font, fontWeight: FontWeight.w500, fontSize: 15, letterSpacing: -0.1);
  return base.copyWith(
    scaffoldBackgroundColor: p.ink,
    // A quiet press highlight instead of Material's sparkle.
    splashFactory: InkRipple.splashFactory,
    splashColor: p.text.withValues(alpha: 0.05),
    highlightColor: p.text.withValues(alpha: 0.04),
    // Tight, heavy figures and headings; relaxed body text.
    textTheme: t.copyWith(
      displayLarge: t.displayLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -3, height: 1),
      displayMedium: t.displayMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -2, height: 1),
      headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1, height: 1.1),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.9, height: 1.15),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.6, height: 1.2),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.4),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyLarge: t.bodyLarge?.copyWith(letterSpacing: -0.1),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.45, letterSpacing: 0),
      bodySmall: t.bodySmall?.copyWith(color: p.muted, height: 1.4, letterSpacing: 0),
      labelSmall: t.labelSmall?.copyWith(color: p.muted, letterSpacing: 0.2),
    ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: overlayStyle(brightness),
      backgroundColor: p.ink,
      scrolledUnderElevation: 0,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 68,
      titleSpacing: Gaps.margin,
      titleTextStyle:
          TextStyle(fontFamily: font, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -1.1, color: p.text),
    ),
    // Cards sit on the page by a hairline, not by shadow or a tinted page.
    cardTheme: CardThemeData(
      color: p.raised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.surface)),
        side: BorderSide(color: p.hairline),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: button,
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.raised2,
        disabledForegroundColor: p.muted,
        minimumSize: const Size(64, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: label,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: button,
        foregroundColor: p.text,
        side: BorderSide(color: p.hairline),
        minimumSize: const Size(64, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: label,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: button,
        minimumSize: const Size(48, 44),
        textStyle: label,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.raised2,
      side: BorderSide.none,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.tag))),
      labelStyle: TextStyle(fontFamily: font, fontSize: 13, fontWeight: FontWeight.w500, color: p.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(button),
        minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
        side: WidgetStatePropertyAll(BorderSide(color: p.hairline)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.raised2 : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.text : p.muted),
        textStyle: const WidgetStatePropertyAll(label),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      horizontalTitleGap: 14,
      titleTextStyle:
          TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -0.2, color: p.text),
      subtitleTextStyle: TextStyle(fontFamily: font, fontSize: 14, height: 1.4, color: p.muted),
      minVerticalPadding: 12,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.faint,
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.sheet)),
        side: BorderSide(color: p.hairline),
      ),
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
    // Same colour as the page with a hairline on top. No indicator blob:
    // the selected tab is the one drawn in full-strength ink.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: font,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: s.contains(WidgetState.selected) ? p.text : p.faint,
          )),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? p.text : p.faint)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.raised2,
      circularTrackColor: p.raised2,
      linearMinHeight: 6,
      borderRadius: const BorderRadius.all(Radius.circular(3)),
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
    final col = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(Gaps.margin + 4, 28, action == null ? Gaps.margin : Gaps.margin - 8, 8),
      child: Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: t.labelLarge?.copyWith(color: col.muted, fontSize: 13)),
          ),
        ),
        if (action != null)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 32),
              visualDensity: VisualDensity.compact,
              foregroundColor: col.text,
              textStyle: const TextStyle(fontFamily: font, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            onPressed: onAction,
            child: Text(action!),
          ),
      ]),
    );
  }
}

/// Rows grouped into one rounded container on the page margin, split by
/// hairlines that start where the text does.
class TileGroup extends StatelessWidget {
  const TileGroup({super.key, required this.children, this.margin = true, this.dividerIndent = 16});
  final List<Widget> children;

  /// False when the parent already pads to the page margin.
  final bool margin;

  /// Where the hairlines start: 16 for plain rows, 64 past an [IconBadge].
  final double dividerIndent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: margin ? Gaps.margin : 0),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(indent: dividerIndent),
              children[i],
            ],
          ]),
        ),
      );
}

/// An icon on a small neutral rounded square, as list leading or stat marker.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, this.icon, this.child, this.size = 34, this.background, this.foreground});
  final IconData? icon;

  /// Drawn instead of [icon] (the logo ticks, for example).
  final Widget? child;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final fg = foreground ?? col.text;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? col.raised2,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: IconTheme(
        data: IconThemeData(color: fg, size: size * 0.54),
        child: child ?? Icon(icon),
      ),
    );
  }
}

/// A two-to-four way switch drawn as a sunken track with a raised thumb
/// that slides to the selection.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.selected, required this.onChanged});
  final List<(T, String)> options;

  /// Null when none of the options applies (custom rules, for example).
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final index = options.indexWhere((o) => o.$1 == selected);
    final still = MediaQuery.of(context).disableAnimations;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: col.raised2,
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / options.length;
        return Stack(children: [
          if (index >= 0)
            AnimatedPositioned(
              duration: still ? Duration.zero : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: w * index,
              top: 0,
              bottom: 0,
              width: w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: col.raised,
                  borderRadius: BorderRadius.circular(Radii.small - 3),
                  border: Border.all(color: col.hairline),
                  boxShadow: [
                    BoxShadow(color: col.ink.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 1)),
                  ],
                ),
              ),
            ),
          Row(children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(options[i].$1),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontFamily: font,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                          color: i == index ? col.text : col.muted,
                        ),
                        child: Text(options[i].$2),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}
