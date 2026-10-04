import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/presets.dart';
import 'package:doomwalk/core/scroll_wallet.dart';

void main() {
  test('the default config is Balanced: 5x, 12x, 20x, 32x, 48x', () {
    expect(Strictness.of(const WalletConfig()), Strictness.balanced);
    expect(Strictness.balanced.priceTiers, [5, 12, 20, 32, 48]);
  });

  test('applying a preset sets the price rules and keeps the rest, bank size included', () {
    final c = Strictness.strict.applyTo(
      const WalletConfig(weightKg: 82, overridesPerDay: 1, bankCapM: 80),
    );
    expect(Strictness.of(c), Strictness.strict);
    expect(c.priceTiers, [8, 18, 30, 46, 70]);
    expect(c.priceStepM, 25);
    expect(c.bankCapM, 80);
    expect(c.weightKg, 82);
    expect(c.overridesPerDay, 1);
  });

  test('every preset climbs and never goes down', () {
    for (final s in Strictness.values) {
      for (var i = 1; i < s.priceTiers.length; i++) {
        expect(s.priceTiers[i], greaterThan(s.priceTiers[i - 1]));
      }
    }
  });

  test('the bank size is not part of a preset; price rules are', () {
    expect(
      Strictness.of(const WalletConfig(bankCapM: 100)),
      Strictness.balanced,
    );
    expect(Strictness.of(const WalletConfig(priceTiers: [3, 5])), isNull);
    expect(Strictness.of(const WalletConfig(priceStepM: 60)), isNull);
  });

  test('the tier length is 50 m, or 25 m for Strict', () {
    expect([for (final s in Strictness.values) s.priceStepM], [50, 50, 25]);
  });
}
