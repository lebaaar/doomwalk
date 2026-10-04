import 'scroll_wallet.dart';

/// One-tap economies, so most people never touch the individual rules.
/// Balanced is the app's default config.
enum Strictness {
  gentle('Gentle', allowanceM: 300, priceStepM: 200, maxPrice: 3),
  balanced('Balanced', allowanceM: 150, priceStepM: 100, maxPrice: 5),
  strict('Strict', allowanceM: 50, priceStepM: 50, maxPrice: 5);

  const Strictness(
    this.label, {
    required this.allowanceM,
    required this.priceStepM,
    required this.maxPrice,
  });

  final String label;
  final double allowanceM;
  final double priceStepM;
  final double maxPrice;

  WalletConfig applyTo(WalletConfig c) => c.copyWith(
        allowanceM: allowanceM,
        priceStepM: priceStepM,
        maxPrice: maxPrice,
      );

  /// The preset [c] matches exactly, or null when the rules were customised.
  static Strictness? of(WalletConfig c) {
    bool near(double a, double b) => (a - b).abs() < 1e-6;
    for (final s in values) {
      if (near(c.allowanceM, s.allowanceM) && near(c.priceStepM, s.priceStepM) && near(c.maxPrice, s.maxPrice)) {
        return s;
      }
    }
    return null;
  }
}
