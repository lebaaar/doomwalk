import 'scroll_wallet.dart';

/// One-tap price rules, so most people never touch the individual ones.
/// Balanced is the app's default config. The bank size is its own setting.
enum Strictness {
  gentle('Gentle', priceTiers: [2, 3, 5, 7, 10], priceStepM: 100, oldPriceStepM: 50),
  balanced('Balanced', priceTiers: WalletConfig.defaultPriceTiers, priceStepM: WalletConfig.defaultPriceStepM,
      oldPriceStepM: 50),
  strict('Strict', priceTiers: [5, 7, 10, 15, 20], priceStepM: 50, oldPriceStepM: 25);

  const Strictness(this.label, {required this.priceTiers, required this.priceStepM, required this.oldPriceStepM});

  final String label;

  /// Metres walked per metre of scrolling, tier by tier through the day.
  final List<double> priceTiers;

  /// Scrolled per tier.
  final double priceStepM;

  /// The tier length before config model 5 raised it.
  final double oldPriceStepM;

  WalletConfig applyTo(WalletConfig c) => c.copyWith(priceTiers: priceTiers, priceStepM: priceStepM);

  /// The preset [c] matches exactly, or null when the rules were customised.
  static Strictness? of(WalletConfig c) {
    for (final s in values) {
      if (_same(c.priceTiers, s.priceTiers) && (c.priceStepM - s.priceStepM).abs() < 1e-6) return s;
    }
    return null;
  }

  /// A config saved by model 4: one that was on a preset moves to that
  /// preset's longer tiers; custom rules stay as they were.
  static WalletConfig upgradeFromModel4(WalletConfig c) {
    for (final s in values) {
      if (_same(c.priceTiers, s.priceTiers) && (c.priceStepM - s.oldPriceStepM).abs() < 1e-6) return s.applyTo(c);
    }
    return c;
  }
}

bool _same(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > 1e-6) return false;
  }
  return true;
}
