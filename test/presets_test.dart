import 'package:flutter_test/flutter_test.dart';
import 'package:scrolldebt/core/debt_engine.dart';
import 'package:scrolldebt/core/presets.dart';

void main() {
  test('the default config is Balanced', () {
    expect(Strictness.of(const DebtConfig()), Strictness.balanced);
  });

  test('applying a preset sets the four economy rules and keeps the rest', () {
    final c = Strictness.strict.applyTo(const DebtConfig(weightKg: 82, overridesPerDay: 1));
    expect(Strictness.of(c), Strictness.strict);
    expect(c.allowanceM, 75);
    expect(c.weightKg, 82);
    expect(c.overridesPerDay, 1);
  });

  test('any customised rule means no preset', () {
    expect(Strictness.of(const DebtConfig(allowanceM: 60)), isNull);
  });
}
