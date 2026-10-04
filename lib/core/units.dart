const double metresPerInch = 0.0254;

double pixelsToMetres(num pixels, double ydpi) {
  if (ydpi <= 0) return 0;
  return pixels.abs() / ydpi * metresPerInch;
}

double metresToPixels(double metres, double ydpi) =>
    metres / metresPerInch * ydpi;

// Some OEM builds report a bogus ydpi, so fall back to densityDpi when it is implausible or off by more than 40%
double sanitizeDpi({required double ydpi, required double densityDpi}) {
  final fallback = densityDpi > 0 ? densityDpi : 420.0;
  if (ydpi.isNaN || ydpi < 100 || ydpi > 900) return fallback;
  final drift = (ydpi - fallback).abs() / fallback;
  return drift > 0.4 ? fallback : ydpi;
}

String formatMetres(double m, {int decimals = 1}) {
  if (double.parse(m.toStringAsFixed(decimals)).abs() >= 1000) {
    return '${(m / 1000).toStringAsFixed(2)} km';
  }
  return '${m.toStringAsFixed(decimals)} m';
}

// Rounds before picking the unit, so 999.6 is "1 km", not "1000 m"
String formatRound(double m) {
  if (m.round().abs() >= 1000) {
    return '${_trim((m / 1000).toStringAsFixed(1))} km';
  }
  return '${m.round()} m';
}

String formatTimes(double v) => '${_trim(v.toStringAsFixed(1))}×';

String _trim(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;

String formatCount(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String tiersText(List<double> tiers) {
  final t = tiers.map(formatTimes).toList();
  if (t.length < 2) return t.join();
  return '${t.sublist(0, t.length - 1).join(', ')} and ${t.last}';
}
