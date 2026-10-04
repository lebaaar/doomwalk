import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/debt_engine.dart';

void main() {
  final t0 = DateTime(2026, 10, 3, 10);
  DebtEngine fresh([DebtConfig c = const DebtConfig()]) =>
      DebtEngine(config: c, state: DebtState.fresh(t0));

  group('allowance and ratio', () {
    test('scrolling inside the allowance is free', () {
      final e = fresh();
      final c = e.applyScroll(metres: 150, appRate: 1, at: t0);
      expect(c.costM, 0);
      expect(e.debtM, 0);
      expect(e.allowanceLeftM, closeTo(50, 1e-9));
    });

    test('excess is charged at rate x RATIO', () {
      final e = fresh();
      e.applyScroll(metres: 150, appRate: 1, at: t0);
      final c = e.applyScroll(metres: 100, appRate: 2, at: t0);
      // 50 free, 50 excess * 2 (app) * 2 (ratio)
      expect(c.freeM, closeTo(50, 1e-9));
      expect(c.costM, closeTo(200, 1e-9));
      expect(e.debtM, closeTo(200, 1e-9));
      expect(e.state.scrolledTodayM, closeTo(250, 1e-9));
    });

    test('0x apps are not counted and do not consume allowance', () {
      final e = fresh();
      e.applyScroll(metres: 500, appRate: 0, at: t0);
      expect(e.state.scrolledTodayM, 0);
      expect(e.allowanceLeftM, 200);
    });

    test('velocity weight scales the charge', () {
      final e = fresh(const DebtConfig(allowanceM: 0));
      e.applyScroll(metres: 10, appRate: 1, at: t0, velocityWeight: 0.5);
      expect(e.debtM, closeTo(10, 1e-9));
    });
  });

  group('walking', () {
    test('walking pays down debt and never goes below zero', () {
      final e = fresh(const DebtConfig(allowanceM: 0));
      e.applyScroll(metres: 10, appRate: 1, at: t0); // 20 debt
      expect(e.applyWalk(15, t0), closeTo(15, 1e-9));
      expect(e.debtM, closeTo(5, 1e-9));
      expect(e.applyWalk(100, t0), closeTo(5, 1e-9));
      expect(e.debtM, 0);
      expect(e.state.walkedTodayM, closeTo(115, 1e-9));
    });

    test('walking while debt-free does not bank credit', () {
      final e = fresh(const DebtConfig(allowanceM: 0));
      e.applyWalk(500, t0);
      e.applyScroll(metres: 10, appRate: 1, at: t0);
      expect(e.debtM, closeTo(20, 1e-9));
    });

    test('progress toward zero is relative to the daily peak', () {
      final e = fresh(const DebtConfig(allowanceM: 0));
      e.applyScroll(metres: 50, appRate: 1, at: t0); // 100
      e.applyWalk(25, t0);
      expect(e.progressToZero, closeTo(0.25, 1e-9));
    });
  });

  group('frost', () {
    test('frost is 0 at no debt and 1 at 150 m', () {
      final e = fresh(const DebtConfig(allowanceM: 0));
      expect(e.frostLevel, 0);
      e.applyScroll(metres: 37.5, appRate: 1, at: t0); // 75
      expect(e.frostLevel, closeTo(0.5, 1e-9));
      e.applyScroll(metres: 500, appRate: 1, at: t0);
      expect(e.frostLevel, 1);
    });

    test('demo mode shrinks the economy', () {
      final e = fresh(const DebtConfig(demoMode: true));
      e.applyScroll(metres: 2, appRate: 2, at: t0);
      expect(e.debtM, 0);
      e.applyScroll(metres: 7.5, appRate: 2, at: t0); // 7.5*2*1 = 15
      expect(e.debtM, closeTo(15, 1e-9));
      expect(e.frostLevel, 1);
    });
  });

  group('day rollover and interest', () {
    test('allowance resets at local midnight and interest accrues', () {
      final e = fresh(const DebtConfig(allowanceM: 0, interestRate: 0.1));
      e.applyScroll(metres: 50, appRate: 1, at: t0); // 100
      final r = e.rollover(DateTime(2026, 10, 4, 0, 1));
      expect(r.closedDays, ['2026-10-03']);
      expect(r.interestM, closeTo(10, 1e-9));
      expect(e.debtM, closeTo(110, 1e-9));
      expect(e.state.scrolledTodayM, 0);
      expect(e.state.peakDebtTodayM, closeTo(110, 1e-9));
      expect(e.state.dayKey, '2026-10-04');
    });

    test('interest compounds once per night over multi-day gaps', () {
      final e = fresh(const DebtConfig(allowanceM: 0, interestRate: 0.1));
      e.applyScroll(metres: 50, appRate: 1, at: t0); // 100
      e.rollover(DateTime(2026, 10, 6, 9));
      expect(e.debtM, closeTo(133.1, 1e-9));
      expect(e.state.lastInterestM, closeTo(33.1, 1e-9));
    });

    test('no interest when debt is zero; repeated rollover is idempotent', () {
      final e = fresh();
      final next = DateTime(2026, 10, 4, 8);
      e.rollover(next);
      expect(e.rollover(next).happened, isFalse);
      expect(e.debtM, 0);
    });

    test('clock going backwards does not charge interest', () {
      final e = fresh(const DebtConfig(allowanceM: 0, interestRate: 0.5));
      e.applyScroll(metres: 10, appRate: 1, at: t0);
      e.rollover(DateTime(2026, 10, 1));
      expect(e.debtM, closeTo(20, 1e-9));
    });
  });

  group('emergency override', () {
    test('override is limited per day and charges the penalty', () {
      final e = fresh(const DebtConfig(allowanceM: 0, overridesPerDay: 1));
      expect(e.startOverride(t0), isTrue);
      e.applyScroll(metres: 10, appRate: 1, at: t0); // 10*1*2*3
      expect(e.debtM, closeTo(60, 1e-9));
      final later = t0.add(const Duration(minutes: 6));
      expect(e.overrideActive(later), isFalse);
      expect(e.startOverride(later), isFalse);
      expect(e.startOverride(DateTime(2026, 10, 4, 9)), isTrue);
    });
  });

  test('state survives a JSON round trip', () {
    final e = fresh(const DebtConfig(allowanceM: 0));
    e.applyScroll(metres: 12, appRate: 2, at: t0);
    e.applyWalk(3, t0);
    final copy = DebtState.fromJson(e.state.toJson());
    expect(copy.toJson(), e.state.toJson());
    final cfg = DebtConfig.fromJson(const DebtConfig(ratio: 3, demoMode: true).toJson());
    expect(cfg.ratio, 3);
    expect(cfg.demoMode, isTrue);
  });
}
