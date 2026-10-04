import 'scroll_wallet.dart';

enum Strictness {
  gentle('Gentle', priceTiers: [4, 9, 14, 22, 32], priceStepM: 50),
  balanced(
    'Balanced',
    priceTiers: WalletConfig.defaultPriceTiers,
    priceStepM: WalletConfig.defaultPriceStepM,
  ),
  strict('Strict', priceTiers: [8, 18, 30, 46, 70], priceStepM: 25);

  const Strictness(
    this.label, {
    required this.priceTiers,
    required this.priceStepM,
  });

  final String label;

  final List<double> priceTiers;

  final double priceStepM;

  WalletConfig applyTo(WalletConfig c) =>
      c.copyWith(priceTiers: priceTiers, priceStepM: priceStepM);

  static Strictness? of(WalletConfig c) {
    for (final s in values) {
      if (_matches(c, s.priceTiers, s.priceStepM)) return s;
    }
    return null;
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
