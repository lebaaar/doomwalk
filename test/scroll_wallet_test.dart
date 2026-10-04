import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/scroll_wallet.dart';

void main() {
  final t0 = DateTime(2026, 10, 3, 10);
  ScrollWallet fresh([WalletConfig c = const WalletConfig()]) =>
      ScrollWallet(config: c, state: WalletState.fresh(t0));

  group('price steps', () {
    const c = WalletConfig(); // 100 m steps, capped at 5:1

    test('starts at 1:1 and goes up by one every step, up to the cap', () {
      expect(priceAt(0, c), 1);
      expect(priceAt(99.9, c), 1);
      expect(priceAt(100, c), 2);
      expect(priceAt(250, c), 3);
      expect(priceAt(400, c), 5);
      expect(priceAt(5000, c), 5);
    });

    test('walk cost adds up across steps', () {
      expect(walkCost(0, 100, c), closeTo(100, 1e-9));
      expect(walkCost(0, 200, c), closeTo(300, 1e-9));
      expect(walkCost(0, 400, c), closeTo(1000, 1e-9));
      // 50 m at 1:1, then 50 m at 2:1.
      expect(walkCost(50, 100, c), closeTo(150, 1e-9));
      // Past the cap every metre is 5.
      expect(walkCost(600, 10, c), closeTo(50, 1e-9));
    });

    test('scrollFor is the inverse of walkCost', () {
      for (final start in [0.0, 37.0, 100.0, 180.0, 450.0]) {
        for (final bank in [0.0, 1.0, 99.0, 150.0, 777.0]) {
          final s = scrollFor(start, bank, c);
          expect(walkCost(start, s, c), closeTo(bank, 1e-6), reason: 'start=$start bank=$bank');
        }
      }
    });

    test('a cap of 1 keeps it 1:1 forever', () {
      const flat = WalletConfig(maxPrice: 1);
      expect(walkCost(0, 1000, flat), closeTo(1000, 1e-9));
      expect(scrollFor(500, 80, flat), closeTo(80, 1e-9));
    });
  });

  group('free allowance', () {
    test('scrolling inside the allowance is free', () {
      final w = fresh();
      final c = w.applyScroll(metres: 100, at: t0);
      expect(c.costM, 0);
      expect(w.overdraftM, 0);
      expect(w.allowanceLeftM, closeTo(50, 1e-9));
      expect(w.frostLevel, 0);
    });
  });

  group('walk first, then scroll', () {
    test('walking before the allowance runs out is banked and spent later', () {
      final w = fresh();
      w.applyWalk(120, t0);
      expect(w.bankM, closeTo(120, 1e-9));
      // 150 free + 100 at 1:1 + 10 at 2:1 = 120 walked.
      w.applyScroll(metres: 260, at: t0);
      expect(w.bankM, closeTo(0, 1e-9));
      expect(w.overdraftM, closeTo(0, 1e-9));
      expect(w.state.earnedScrolledTodayM, closeTo(110, 1e-9));
      expect(w.priceNow, 2);
    });

    test('earned scrolling left follows the price', () {
      final w = fresh(const WalletConfig(allowanceM: 0));
      w.applyWalk(300, t0);
      expect(w.earnedScrollLeftM, closeTo(200, 1e-9));
    });

    test('an empty bank runs an overdraft and frosts', () {
      final w = fresh(const WalletConfig(allowanceM: 0));
      final c = w.applyScroll(metres: 5, at: t0);
      expect(c.costM, closeTo(5, 1e-9));
      expect(w.overdraftM, closeTo(5, 1e-9));
      expect(w.frostLevel, closeTo(0.25, 1e-9)); // 5 of 20
      w.applyScroll(metres: 30, at: t0);
      expect(w.frostLevel, 1);
    });

    test('walking clears the overdraft first, then fills the bank', () {
      final w = fresh(const WalletConfig(allowanceM: 0));
      w.applyScroll(metres: 10, at: t0);
      expect(w.applyWalk(4, t0), 0);
      expect(w.overdraftM, closeTo(6, 1e-9));
      expect(w.applyWalk(20, t0), closeTo(14, 1e-9));
      expect(w.overdraftM, 0);
      expect(w.bankM, closeTo(14, 1e-9));
      expect(w.frostLevel, 0);
      expect(w.state.walkedTodayM, closeTo(24, 1e-9));
    });

    test('walkToUnlock includes what is owed and the price', () {
      final w = fresh(const WalletConfig(allowanceM: 0));
      expect(w.walkToUnlock(100), closeTo(100, 1e-9));
      w.applyScroll(metres: 110, at: t0); // 100 at 1 + 10 at 2 = 120 owed
      expect(w.overdraftM, closeTo(120, 1e-9));
      // Clear 120, then the next 100 m cost 90 at 2 + 10 at 3.
      expect(w.walkToUnlock(100), closeTo(120 + 180 + 30, 1e-9));
      w.applyWalk(50, t0);
      expect(w.walkToUnlock(100), closeTo(70 + 210, 1e-9));
    });
  });

  group('emergency pass', () {
    test('three a day, scrolling during one is free', () {
      final w = fresh(const WalletConfig(allowanceM: 0));
      expect(w.startOverride(t0), isTrue);
      final c = w.applyScroll(metres: 50, at: t0.add(const Duration(minutes: 1)));
      expect(c.costM, 0);
      expect(w.overdraftM, 0);
      expect(w.state.earnedScrolledTodayM, 0);
      expect(w.state.scrolledTodayM, closeTo(50, 1e-9));
      w.endOverride();
      expect(w.startOverride(t0), isTrue);
      w.endOverride();
      expect(w.startOverride(t0), isTrue);
      w.endOverride();
      expect(w.startOverride(t0), isFalse);
      expect(w.overridesLeft(t0), 0);
    });

    test('a pass expires after its minutes', () {
      final w = fresh(const WalletConfig(allowanceM: 0));
      w.startOverride(t0);
      w.applyScroll(metres: 10, at: t0.add(const Duration(minutes: 6)));
      expect(w.overdraftM, closeTo(10, 1e-9));
    });
  });

  group('midnight', () {
    test('everything starts over: allowance, price, bank and overdraft', () {
      final w = fresh(const WalletConfig(allowanceM: 0));
      w.applyWalk(500, t0);
      w.applyScroll(metres: 300, at: t0); // costs 100 + 200 + 300: the bank's 500, then 100 owed
      w.applyScroll(metres: 20, at: t0);
      w.startOverride(t0);
      final next = DateTime(2026, 10, 4, 7);
      expect(w.rollover(next), isTrue);
      expect(w.state.dayKey, '2026-10-04');
      expect(w.bankM, 0);
      expect(w.overdraftM, 0);
      expect(w.priceNow, 1);
      expect(w.state.walkedTodayM, 0);
      expect(w.overridesLeft(next), 3);
      expect(w.state.lifetimeWalkedM, closeTo(500, 1e-9));
      expect(w.state.lifetimeScrolledM, closeTo(320, 1e-9));
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

  group('demo mode', () {
    test('replaces the economy, keeps personal settings', () {
      final w = fresh(const WalletConfig(demoMode: true, strideM: 0.8));
      w.applyScroll(metres: 2, at: t0);
      expect(w.allowanceLeftM, 0);
      w.applyScroll(metres: 5, at: t0);
      expect(w.frostLevel, 1);
      expect(w.config.effective.strideM, 0.8);
    });
  });

  group('persistence', () {
    test('state round-trips through JSON', () {
      final w = fresh(const WalletConfig(allowanceM: 10));
      w.applyWalk(40, t0);
      w.applyScroll(metres: 70, at: t0);
      final back = WalletState.fromJson(w.state.toJson());
      expect(back.toJson(), w.state.toJson());
    });

    test('config round-trips through JSON', () {
      const c = WalletConfig(allowanceM: 80, priceStepM: 60, maxPrice: 4, frostAtM: 30, weightKg: 90);
      expect(WalletConfig.fromJson(c.toJson()).toJson(), c.toJson());
    });

    test('an old debt-model state keeps today and lifetime totals, not its debt', () {
      final s = WalletState.fromJson({
        'dayKey': '2026-10-03',
        'debtM': 340.0,
        'allowanceUsedM': 200.0,
        'scrolledTodayM': 260.0,
        'walkedTodayM': 120.0,
        'lifetimeScrolledM': 9000.0,
        'lifetimeWalkedM': 40000.0,
        'interestTotalM': 12.0,
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
      expect(c.allowanceM, const WalletConfig().allowanceM);
      expect(c.frostAtM, const WalletConfig().frostAtM);
      expect(c.strideM, 0.7);
      expect(c.weightKg, 64);
      expect(c.walkGoalM, 8000);
      expect(c.overridesPerDay, 2);
    });
  });
}
