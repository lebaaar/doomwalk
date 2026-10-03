/// Pixel <-> metre conversion.
///
/// Density assumption: Android reports the physical vertical pixel density of
/// the panel as `DisplayMetrics.ydpi`. One inch is 0.0254 m, so a vertical
/// scroll of `px` pixels moved the content `px / ydpi * 0.0254` metres across
/// the glass. Some OEM builds report a bogus ydpi (0, 160 on a 450 dpi panel,
/// ...); [sanitizeDpi] falls back to the logical `densityDpi` bucket when the
/// reported ydpi is implausible or disagrees with it by more than 40 %.
library;

const double metresPerInch = 0.0254;

double pixelsToMetres(num pixels, double ydpi) {
  if (ydpi <= 0) return 0;
  return pixels.abs() / ydpi * metresPerInch;
}

double metresToPixels(double metres, double ydpi) => metres / metresPerInch * ydpi;

double sanitizeDpi({required double ydpi, required double densityDpi}) {
  final fallback = densityDpi > 0 ? densityDpi : 420.0;
  if (ydpi.isNaN || ydpi < 100 || ydpi > 900) return fallback;
  final drift = (ydpi - fallback).abs() / fallback;
  return drift > 0.4 ? fallback : ydpi;
}

/// Human formatting for distances: "12.4 m", "1.28 km".
String formatMetres(double m, {int decimals = 1}) {
  if (double.parse(m.toStringAsFixed(decimals)).abs() >= 1000) return '${(m / 1000).toStringAsFixed(2)} km';
  return '${m.toStringAsFixed(decimals)} m';
}

/// Round figures for settings and goals: "60 m", "5 km", "1.5 km".
/// Rounds before picking the unit, so 999.6 is "1 km", not "1000 m".
String formatRound(double m) {
  if (m.round().abs() >= 1000) return '${_trim((m / 1000).toStringAsFixed(1))} km';
  return '${m.round()} m';
}

/// Multipliers: "3×", "1.5×".
String formatTimes(double v) => '${_trim(v.toStringAsFixed(1))}×';

String _trim(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
