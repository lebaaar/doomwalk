import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/presets.dart';
import 'package:doomwalk/core/scroll_wallet.dart';

void main() {
  test('the default config is Balanced: 4x, 6x, 9x, 12x, 18x', () {
    expect(Strictness.of(const WalletConfig()), Strictness.balanced);
    expect(Strictness.balanced.priceTiers, [4, 6, 9, 12, 18]);
  });

  test('applying a preset sets the price rules and keeps the rest, bank size included', () {
    final c = Strictness.strict.applyTo(
      const WalletConfig(weightKg: 82, overridesPerDay: 1, bankCapM: 80),
    );
    expect(Strictness.of(c), Strictness.strict);
    expect(c.priceTiers, [6, 9, 12, 18, 25]);
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

  test(
    'every preset costs more walking than before, on the original tier lengths',
    () {
      expect([for (final s in Strictness.values) s.priceStepM], [50, 50, 25]);
      for (final s in Strictness.values) {
        final before = s.earlier.first.$1;
        for (var i = 0; i < before.length; i++) {
          expect(s.priceTiers[i], greaterThan(before[i]));
        }
      }
    },
  );

  test('a model 4 or 5 config on a preset moves to its current rules; custom rules stay', () {
    const oldStrict = WalletConfig(
      priceTiers: [5, 7, 10, 15, 20],
      priceStepM: 25,
      bankCapM: 80,
    );
    final up = Strictness.upgrade(oldStrict);
    expect(Strictness.of(up), Strictness.strict);
    expect(up.bankCapM, 80);
    const model5Balanced = WalletConfig(
      priceTiers: [3, 5, 7, 10, 15],
      priceStepM: 75,
    );
    expect(
      Strictness.of(Strictness.upgrade(model5Balanced)),
      Strictness.balanced,
    );
    const model5Gentle = WalletConfig(
      priceTiers: [2, 3, 5, 7, 10],
      priceStepM: 100,
    );
    expect(Strictness.of(Strictness.upgrade(model5Gentle)), Strictness.gentle);
    const custom = WalletConfig(priceTiers: [3, 5, 7, 10, 15], priceStepM: 125);
    expect(Strictness.upgrade(custom).priceStepM, 125);
    expect(Strictness.upgrade(custom).priceTiers, [3, 5, 7, 10, 15]);
  });
}
