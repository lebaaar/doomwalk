import 'debt_engine.dart';

/// One-tap economies, so most people never touch the individual rules.
/// Balanced is the app's default config.
enum Strictness {
  gentle('Gentle', allowanceM: 400, ratio: 1, frostMaxDebtM: 300, interestRate: 0),
  balanced('Balanced', allowanceM: 200, ratio: 2, frostMaxDebtM: 150, interestRate: 0.02),
  strict('Strict', allowanceM: 75, ratio: 3, frostMaxDebtM: 100, interestRate: 0.04);

  const Strictness(
    this.label, {
    required this.allowanceM,
    required this.ratio,
    required this.frostMaxDebtM,
    required this.interestRate,
  });

  final String label;
  final double allowanceM;
  final double ratio;
  final double frostMaxDebtM;
  final double interestRate;

  DebtConfig applyTo(DebtConfig c) => c.copyWith(
        allowanceM: allowanceM,
        ratio: ratio,
        frostMaxDebtM: frostMaxDebtM,
        interestRate: interestRate,
      );

  /// The preset [c] matches exactly, or null when the rules were customised.
  static Strictness? of(DebtConfig c) {
    bool near(double a, double b) => (a - b).abs() < 1e-6;
    for (final s in values) {
      if (near(c.allowanceM, s.allowanceM) &&
          near(c.ratio, s.ratio) &&
          near(c.frostMaxDebtM, s.frostMaxDebtM) &&
          near(c.interestRate, s.interestRate)) {
        return s;
      }
    }
    return null;
  }
}
