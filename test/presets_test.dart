import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/presets.dart';
import 'package:doomwalk/core/scroll_wallet.dart';

void main() {
  test('the default config is Balanced', () {
    expect(Strictness.of(const WalletConfig()), Strictness.balanced);
  });

  test('applying a preset sets the economy rules and keeps the rest', () {
    final c = Strictness.strict.applyTo(const WalletConfig(weightKg: 82, overridesPerDay: 1));
    expect(Strictness.of(c), Strictness.strict);
    expect(c.allowanceM, 50);
    expect(c.priceStepM, 50);
    expect(c.weightKg, 82);
    expect(c.overridesPerDay, 1);
  });

  test('any customised rule means no preset', () {
    expect(Strictness.of(const WalletConfig(allowanceM: 60)), isNull);
    expect(Strictness.of(const WalletConfig(maxPrice: 4)), isNull);
  });
}
