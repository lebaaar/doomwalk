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
  if (m.abs() >= 1000) return '${(m / 1000).toStringAsFixed(2)} km';
  return '${m.toStringAsFixed(decimals)} m';
}
