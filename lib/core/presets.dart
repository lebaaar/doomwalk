import 'scroll_wallet.dart';

/// One-tap price rules, so most people never touch the individual ones.
/// Balanced is the app's default config. The bank size is its own setting.
enum Strictness {
  gentle('Gentle', startPrice: 1, priceStepM: 100, maxPrice: 4),
  balanced('Balanced', startPrice: 2, priceStepM: 50, maxPrice: 6),
  strict('Strict', startPrice: 3, priceStepM: 25, maxPrice: 8);

  const Strictness(this.label, {required this.startPrice, required this.priceStepM, required this.maxPrice});

  final String label;

  /// Metres walked per metre of scrolling at the start of the day.
  final double startPrice;
  final double priceStepM;
  final double maxPrice;

  WalletConfig applyTo(WalletConfig c) =>
      c.copyWith(startPrice: startPrice, priceStepM: priceStepM, maxPrice: maxPrice);

  /// The preset [c] matches exactly, or null when the rules were customised.
  static Strictness? of(WalletConfig c) {
    bool near(double a, double b) => (a - b).abs() < 1e-6;
    for (final s in values) {
      if (near(c.startPrice, s.startPrice) && near(c.priceStepM, s.priceStepM) && near(c.maxPrice, s.maxPrice)) {
        return s;
      }
    }
    return null;
  }
}
