import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/scroll_wallet.dart';

void main() {
  final t0 = DateTime(2026, 10, 3, 10);
  // Round numbers for the mechanics: 1:1 at first, +1 every 100 m up to 5,
  // a 100 m bank. The defaults have their own tests.
  const simple = WalletConfig(bankCapM: 100, priceTiers: [1, 2, 3, 4, 5], priceStepM: 100);
  ScrollWallet fresh([WalletConfig c = simple]) => ScrollWallet(config: c, state: WalletState.fresh(t0));

  group('defaults', () {
    test('a 50 m bank; walking at 4x, then 6x, 9x, 12x and 18x, a tier per 50 m', () {
      const c = WalletConfig();
      expect(c.bankCapM, 50);
      expect(<double>[0, 49.9, 50, 100, 150, 200, 1000].map((m) => priceAt(m, c)), [4, 4, 6, 9, 12, 18, 18]);
      final w = fresh(c);
      expect(w.applyWalk(60, t0), closeTo(15, 1e-9)); // 60 m walked at 4x
      w.applyWalk(1000, t0);
      expect(w.bankM, 50);
    });

    test('saved tiers must be numbers of at least 1 that never go down', () {
      List<double> tiers(Object? v) => WalletConfig.fromJson({'priceTiers': v}).priceTiers;
      expect(tiers([2, 4, 4, 9]), [2, 4, 4, 9]);
      for (final bad in [<Object>[], [5, 3], [0.5, 2], ['x'], 7]) {
        expect(tiers(bad), WalletConfig.defaultPriceTiers, reason: '$bad');
      }
    });
  });

  group('price', () {
    const c = simple; // +1 every 100 m scrolled, capped at 5

    test('starts at the starting price and goes up by one every step, up to the cap', () {
      expect(priceAt(0, c), 1);
      expect(priceAt(99.9, c), 1);
      expect(priceAt(100, c), 2);
      expect(priceAt(250, c), 3);
      expect(priceAt(400, c), 5);
      expect(priceAt(5000, c), 5);
    });

    test('a cap of 1 keeps it 1:1 forever', () {
      expect(priceAt(10000, const WalletConfig(priceTiers: [1])), 1);
    });
  });

  group('the bank', () {
    test('starts empty: the first scroll is already owed', () {
      final w = fresh();
      expect(w.bankM, 0);
      final c = w.applyScroll(metres: 5, at: t0);
      expect(c.fromBankM, 0);
      expect(c.owedM, closeTo(5, 1e-9));
      expect(w.frostLevel, closeTo(0.25, 1e-9)); // 5 of 20
    });

    test('walking fills it 1:1 at first, scrolling spends it', () {
      final w = fresh();
      expect(w.applyWalk(80, t0), closeTo(80, 1e-9));
      final c = w.applyScroll(metres: 50, at: t0);
      expect(c.fromBankM, closeTo(50, 1e-9));
      expect(w.bankM, closeTo(30, 1e-9));
      expect(w.frostLevel, 0);
    });

    test('is capped: walking with it full counts for nothing', () {
      final w = fresh();
      w.applyWalk(5000, t0);
      expect(w.bankM, 100);
      expect(w.bankFull, isTrue);
      expect(w.state.addedTodayM, closeTo(100, 1e-9));
      expect(w.state.overflowWalkTodayM, closeTo(4900, 1e-9));
      w.applyScroll(metres: 50, at: t0);
      expect(w.bankFull, isFalse);
      expect(w.applyWalk(500, t0), closeTo(50, 1e-9));
    });

    test('the price rises with what was scrolled today', () {
      final w = fresh();
      w.applyWalk(100, t0);
      w.applyScroll(metres: 90, at: t0);
      expect(w.priceNow, 1);
      w.applyScroll(metres: 20, at: t0); // 10 from the bank, 10 owed
      expect(w.priceNow, 2);
      // 40 m walked at 2x = 20 m: 10 pays what's owed, 10 to the bank.
      expect(w.applyWalk(40, t0), closeTo(10, 1e-9));
      expect(w.bankM, closeTo(10, 1e-9));
    });

    test('lowering the cap trims the bank', () {
      final w = fresh();
      w.applyWalk(100, t0);
      w.config = simple.copyWith(bankCapM: 50);
      expect(w.bankM, 50);
    });
  });

  group('overdraft', () {
    test('walking pays what is owed first, then fills the bank', () {
      final w = fresh();
      w.applyScroll(metres: 10, at: t0);
      expect(w.applyWalk(4, t0), 0);
      expect(w.overdraftM, closeTo(6, 1e-9));
      expect(w.applyWalk(20, t0), closeTo(14, 1e-9));
      expect(w.overdraftM, 0);
      expect(w.bankM, closeTo(14, 1e-9));
      expect(w.state.walkedTodayM, closeTo(24, 1e-9));
    });

    test('frost is full at frostAtM owed', () {
      final w = fresh();
      w.applyScroll(metres: 30, at: t0);
      expect(w.frostLevel, 1);
    });

    test('walkToUnlock clears what is owed and fills to the amount, at the price', () {
      final w = fresh();
      expect(w.walkToUnlock(100), closeTo(100, 1e-9));
      w.applyScroll(metres: 110, at: t0); // 110 owed, price now 2
      expect(w.walkToUnlock(100), closeTo((110 + 100) * 2, 1e-9));
      w.applyWalk(300, t0); // pays 150 of scrolling: 110 owed, 40 to the bank
      expect(w.bankM, closeTo(40, 1e-9));
      expect(w.walkToUnlock(100), closeTo(60 * 2, 1e-9));
      // Never more than the bank holds (100 m).
      expect(w.walkToUnlock(1000), closeTo(60 * 2, 1e-9));
    });

    test('a tracking gap spends the bank first, the rest is owed', () {
      final w = fresh();
      w.applyWalk(15, t0);
      w.chargeGap(40, t0);
      expect(w.bankM, 0);
      expect(w.overdraftM, closeTo(25, 1e-9));
      expect(w.state.tamperChargedTodayM, closeTo(40, 1e-9));
    });
  });

  group('emergency pass', () {
    test('three a day, scrolling during one is free and does not raise the price', () {
      final w = fresh();
      expect(w.startOverride(t0), isTrue);
      final c = w.applyScroll(metres: 500, at: t0.add(const Duration(minutes: 1)));
      expect(c.owedM, 0);
      expect(w.overdraftM, 0);
      expect(w.priceNow, 1);
      expect(w.state.scrolledTodayM, closeTo(500, 1e-9));
      w.endOverride();
      expect(w.startOverride(t0), isTrue);
      w.endOverride();
      expect(w.startOverride(t0), isTrue);
      w.endOverride();
      expect(w.startOverride(t0), isFalse);
      expect(w.overridesLeft(t0), 0);
    });

    test('a pass expires after its minutes', () {
      final w = fresh();
      w.startOverride(t0);
      w.applyScroll(metres: 10, at: t0.add(const Duration(minutes: 6)));
      expect(w.overdraftM, closeTo(10, 1e-9));
    });
  });

  group('midnight', () {
    test('everything starts over: bank, overdraft and price', () {
      final w = fresh();
      w.applyWalk(250, t0); // fills the 100 m bank
      w.applyScroll(metres: 300, at: t0); // 100 from the bank, 200 owed
      w.startOverride(t0);
      final next = DateTime(2026, 10, 4, 7);
      expect(w.rollover(next), isTrue);
      expect(w.state.dayKey, '2026-10-04');
      expect(w.bankM, 0);
      expect(w.overdraftM, 0);
      expect(w.priceNow, 1);
      expect(w.state.walkedTodayM, 0);
      expect(w.overridesLeft(next), 3);
      expect(w.state.lifetimeWalkedM, closeTo(250, 1e-9));
      expect(w.state.lifetimeScrolledM, closeTo(300, 1e-9));
    });

    test('same day is not a rollover, a clock set back to another day is', () {
      final w = fresh();
      expect(w.rollover(t0.add(const Duration(hours: 3))), isFalse);
      w.applyWalk(10, t0);
      expect(w.rollover(DateTime(2026, 10, 1, 9)), isTrue);
      expect(w.bankM, 0);
    });

    test('passes left on a day nobody has rolled over to yet', () {
      final w = fresh();
      w.startOverride(t0);
      expect(w.overridesLeft(t0), 2);
      expect(w.overridesLeft(DateTime(2026, 10, 4, 1)), 3);
    });
  });

  group('persistence', () {
    test('state round-trips through JSON', () {
      final w = fresh();
      w.applyWalk(40, t0);
      w.applyScroll(metres: 70, at: t0);
      final back = WalletState.fromJson(w.state.toJson());
      expect(back.toJson(), w.state.toJson());
    });

    test('config round-trips through JSON, the cap stays in range', () {
      const c = WalletConfig(
          bankCapM: 80, priceTiers: [2, 4, 8], priceStepM: 60, frostAtM: 30, weightKg: 90, stepGoal: 12500);
      expect(WalletConfig.fromJson(c.toJson()).toJson(), c.toJson());
      expect(WalletConfig.fromJson({'bankCapM': 9000}).bankCapM, WalletConfig.maxBankCapM);
    });

    test('the step goal defaults to 10,000; an old goal in metres becomes steps', () {
      expect(const WalletConfig().stepGoal, 10000);
      expect(const WalletConfig(stepGoal: 8000, strideM: 0.8).walkGoalM, closeTo(6400, 1e-9));
      // The old 5 km default is replaced by the new default.
      expect(WalletConfig.fromJson({'walkGoalM': 5000.0, 'strideM': 0.75}).stepGoal, 10000);
      expect(WalletConfig.fromJson({'walkGoalM': 6000.0, 'strideM': 0.75}).stepGoal, 8000);
      expect(WalletConfig.fromJson({'stepGoal': 99999}).stepGoal, WalletConfig.maxStepGoal);
    });

    test('an older state keeps today and lifetime totals, not its debt or bank', () {
      final s = WalletState.fromJson({
        'dayKey': '2026-10-03',
        'debtM': 340.0,
        'bankM': 120.0, // walking metres in the previous model
        'allowanceUsedM': 200.0,
        'scrolledTodayM': 260.0,
        'walkedTodayM': 120.0,
        'lifetimeScrolledM': 9000.0,
        'lifetimeWalkedM': 40000.0,
        'overridesUsedToday': 1,
      });
      expect(s.scrolledTodayM, 260);
      expect(s.walkedTodayM, 120);
      expect(s.lifetimeWalkedM, 40000);
      expect(s.overdraftM, 0);
      expect(s.bankM, 0);
      expect(s.overridesUsedToday, 1);
    });

    test('an old debt-model config keeps only personal settings', () {
      final c = WalletConfig.fromLegacyJson({
        'allowanceM': 75.0,
        'ratio': 3.0,
        'frostMaxDebtM': 100.0,
        'interestRate': 0.04,
        'strideM': 0.7,
        'weightKg': 64.0,
        'walkGoalM': 8000.0,
        'overridesPerDay': 2,
      });
      expect(c.bankCapM, const WalletConfig().bankCapM);
      expect(c.frostAtM, const WalletConfig().frostAtM);
      expect(c.strideM, 0.7);
      expect(c.weightKg, 64);
      expect(c.stepGoal, 11429); // 8 km at a 0.7 m stride
      expect(c.overridesPerDay, 2);
    });
  });
}
