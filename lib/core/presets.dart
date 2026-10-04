import 'scroll_wallet.dart';

/// One-tap price rules, so most people never touch the individual ones.
/// Balanced is the app's default config. The bank size is its own setting.
enum Strictness {
  gentle('Gentle', priceTiers: [3, 4, 6, 9, 12], priceStepM: 50, earlier: [
    ([2, 3, 5, 7, 10], 50), // model 4
    ([2, 3, 5, 7, 10], 100), // model 5
  ]),
  balanced('Balanced', priceTiers: WalletConfig.defaultPriceTiers, priceStepM: WalletConfig.defaultPriceStepM, earlier: [
    ([3, 5, 7, 10, 15], 50),
    ([3, 5, 7, 10, 15], 75),
  ]),
  strict('Strict', priceTiers: [6, 9, 12, 18, 25], priceStepM: 25, earlier: [
    ([5, 7, 10, 15, 20], 25),
    ([5, 7, 10, 15, 20], 50),
  ]);

  const Strictness(this.label, {required this.priceTiers, required this.priceStepM, required this.earlier});

  final String label;

  /// Metres walked per metre of scrolling, tier by tier through the day.
  final List<double> priceTiers;

  /// Scrolled per tier.
  final double priceStepM;

  /// This preset's rules (tiers, tier length) in older config models.
  final List<(List<double>, double)> earlier;

  WalletConfig applyTo(WalletConfig c) => c.copyWith(priceTiers: priceTiers, priceStepM: priceStepM);

  /// The preset [c] matches exactly, or null when the rules were customised.
  static Strictness? of(WalletConfig c) {
    for (final s in values) {
      if (_matches(c, s.priceTiers, s.priceStepM)) return s;
    }
    return null;
  }

  /// A config saved by an older model: one that was on a preset moves to
  /// that preset's current rules; custom rules stay as they were.
  static WalletConfig upgrade(WalletConfig c) {
    for (final s in values) {
      if (s.earlier.any((e) => _matches(c, e.$1, e.$2))) return s.applyTo(c);
    }
    return c;
  }
}

bool _matches(WalletConfig c, List<double> tiers, double stepM) =>
    _same(c.priceTiers, tiers) && (c.priceStepM - stepM).abs() < 1e-6;

bool _same(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > 1e-6) return false;
  }
  return true;
}
