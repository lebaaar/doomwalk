import 'scroll_wallet.dart';

/// One-tap price rules, so most people never touch the individual ones.
/// Balanced is the app's default config. The bank size is its own setting.
enum Strictness {
  gentle('Gentle', priceStepM: 200, maxPrice: 3),
  balanced('Balanced', priceStepM: 100, maxPrice: 5),
  strict('Strict', priceStepM: 50, maxPrice: 5);

  const Strictness(this.label, {required this.priceStepM, required this.maxPrice});

  final String label;
  final double priceStepM;
  final double maxPrice;

  WalletConfig applyTo(WalletConfig c) => c.copyWith(priceStepM: priceStepM, maxPrice: maxPrice);

  /// The preset [c] matches exactly, or null when the rules were customised.
  static Strictness? of(WalletConfig c) {
    bool near(double a, double b) => (a - b).abs() < 1e-6;
    for (final s in values) {
      if (near(c.priceStepM, s.priceStepM) && near(c.maxPrice, s.maxPrice)) return s;
    }
    return null;
  }
}
