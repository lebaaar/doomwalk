import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/presets.dart';
import 'package:doomwalk/core/scroll_wallet.dart';

void main() {
  test('the default config is Balanced: 3x, 5x, 7x, 10x, 15x', () {
    expect(Strictness.of(const WalletConfig()), Strictness.balanced);
    expect(Strictness.balanced.priceTiers, [3, 5, 7, 10, 15]);
  });

  test('applying a preset sets the price rules and keeps the rest, bank size included', () {
    final c = Strictness.strict.applyTo(const WalletConfig(weightKg: 82, overridesPerDay: 1, bankCapM: 80));
    expect(Strictness.of(c), Strictness.strict);
    expect(c.priceTiers, [5, 7, 10, 15, 20]);
    expect(c.priceStepM, 50);
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
    expect(Strictness.of(const WalletConfig(bankCapM: 100)), Strictness.balanced);
    expect(Strictness.of(const WalletConfig(priceTiers: [3, 5])), isNull);
    expect(Strictness.of(const WalletConfig(priceStepM: 60)), isNull);
  });

  test('every preset lets you scroll longer per tier than before', () {
    expect([for (final s in Strictness.values) s.priceStepM], [100, 75, 50]);
    for (final s in Strictness.values) {
      expect(s.priceStepM, greaterThan(s.oldPriceStepM));
    }
  });

  test('a model 4 config on a preset moves to its new tiers; custom rules stay', () {
    final oldStrict = const WalletConfig(priceTiers: [5, 7, 10, 15, 20], priceStepM: 25, bankCapM: 80);
    final up = Strictness.upgradeFromModel4(oldStrict);
    expect(Strictness.of(up), Strictness.strict);
    expect(up.bankCapM, 80);
    expect(Strictness.of(Strictness.upgradeFromModel4(const WalletConfig(priceStepM: 50))), Strictness.balanced);
    const custom = WalletConfig(priceStepM: 125);
    expect(Strictness.upgradeFromModel4(custom).priceStepM, 125);
  });
}
