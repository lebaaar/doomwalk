import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/scroll_wallet.dart';

void main() {
  final t0 = DateTime(2026, 10, 3, 10);
  ScrollWallet fresh([WalletConfig c = const WalletConfig()]) =>
      ScrollWallet(config: c, state: WalletState.fresh(t0));

  group('price', () {
    const c = WalletConfig(); // +1 every 100 m scrolled, capped at 5

    test('starts at 1:1 and goes up by one every step, up to the cap', () {
      expect(priceAt(0, c), 1);
      expect(priceAt(99.9, c), 1);
      expect(priceAt(100, c), 2);
      expect(priceAt(250, c), 3);
      expect(priceAt(400, c), 5);
      expect(priceAt(5000, c), 5);
    });

    test('a cap of 1 keeps it 1:1 forever', () {
      expect(priceAt(10000, const WalletConfig(maxPrice: 1)), 1);
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
      expect(w.applyWalk(120, t0), closeTo(120, 1e-9));
      final c = w.applyScroll(metres: 80, at: t0);
      expect(c.fromBankM, closeTo(80, 1e-9));
      expect(w.bankM, closeTo(40, 1e-9));
      expect(w.frostLevel, 0);
    });

    test('is capped: walking with it full counts for nothing', () {
      final w = fresh();
      w.applyWalk(5000, t0);
      expect(w.bankM, 250);
      expect(w.bankFull, isTrue);
      expect(w.state.addedTodayM, closeTo(250, 1e-9));
      expect(w.state.overflowWalkTodayM, closeTo(4750, 1e-9));
      w.applyScroll(metres: 50, at: t0);
      expect(w.bankFull, isFalse);
      expect(w.applyWalk(500, t0), closeTo(50, 1e-9));
    });

    test('the price rises with what was scrolled today', () {
      final w = fresh();
      w.applyWalk(250, t0);
      w.applyScroll(metres: 150, at: t0);
      expect(w.priceNow, 2);
      expect(w.applyWalk(40, t0), closeTo(20, 1e-9));
      expect(w.bankM, closeTo(120, 1e-9));
    });

    test('lowering the cap trims the bank', () {
      final w = fresh();
      w.applyWalk(250, t0);
      w.config = const WalletConfig(bankCapM: 100);
      expect(w.bankM, 100);
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
      // Never more than the bank holds.
      expect(w.walkToUnlock(1000), closeTo(210 * 2, 1e-9));
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
      w.applyWalk(250, t0);
      w.applyScroll(metres: 300, at: t0); // 250 from the bank, 50 owed
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

  group('demo mode', () {
    test('replaces the economy, keeps personal settings', () {
      final w = fresh(const WalletConfig(demoMode: true, strideM: 0.8));
      w.applyWalk(100, t0);
      expect(w.bankM, 30);
      w.applyScroll(metres: 35, at: t0);
      expect(w.frostLevel, 1);
      expect(w.config.effective.strideM, 0.8);
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
      const c = WalletConfig(bankCapM: 400, priceStepM: 60, maxPrice: 4, frostAtM: 30, weightKg: 90);
      expect(WalletConfig.fromJson(c.toJson()).toJson(), c.toJson());
      expect(WalletConfig.fromJson({'bankCapM': 9000}).bankCapM, WalletConfig.maxBankCapM);
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
      expect(c.walkGoalM, 8000);
      expect(c.overridesPerDay, 2);
    });
  });
}
