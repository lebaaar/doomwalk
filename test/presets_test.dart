import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/presets.dart';
import 'package:doomwalk/core/scroll_wallet.dart';

void main() {
  test('the default config is Balanced', () {
    expect(Strictness.of(const WalletConfig()), Strictness.balanced);
  });

  test('applying a preset sets the price rules and keeps the rest, bank size included', () {
    final c = Strictness.strict.applyTo(const WalletConfig(weightKg: 82, overridesPerDay: 1, bankCapM: 80));
    expect(Strictness.of(c), Strictness.strict);
    expect(c.startPrice, 3);
    expect(c.priceStepM, 25);
    expect(c.maxPrice, 8);
    expect(c.bankCapM, 80);
    expect(c.weightKg, 82);
    expect(c.overridesPerDay, 1);
  });

  test('every preset starts at or below its cap; only Gentle starts at 1x', () {
    for (final s in Strictness.values) {
      expect(s.startPrice, lessThanOrEqualTo(s.maxPrice));
    }
    expect(Strictness.values.where((s) => s.startPrice == 1), [Strictness.gentle]);
  });

  test('the bank size is not part of a preset; price rules are', () {
    expect(Strictness.of(const WalletConfig(bankCapM: 100)), Strictness.balanced);
    expect(Strictness.of(const WalletConfig(maxPrice: 4)), isNull);
    expect(Strictness.of(const WalletConfig(startPrice: 1)), isNull);
  });
}
