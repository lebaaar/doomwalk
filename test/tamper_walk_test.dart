import 'package:flutter_test/flutter_test.dart';
import 'package:scrolldebt/core/debt_engine.dart';
import 'package:scrolldebt/core/tamper.dart';
import 'package:scrolldebt/core/walk_tracker.dart';

void main() {
  group('tamper gaps', () {
    const p = TamperPolicy();
    final start = DateTime(2026, 10, 3, 12);

    test('average rate over waking hours, fallback without history', () {
      expect(p.averageMetresPerHour([]), 25);
      expect(p.averageMetresPerHour([320, 0, 160]), closeTo(480 / 32, 1e-9));
    });

    test('short gaps are free', () {
      final g = TamperGap(start: start, end: start.add(const Duration(seconds: 90)), reason: 'x');
      expect(p.rawMetresFor(g, 30), 0);
    });

    test('gap is charged at the average rate times ratio', () {
      final g = TamperGap(start: start, end: start.add(const Duration(hours: 2)), reason: 'x');
      expect(p.rawMetresFor(g, 30), closeTo(60, 1e-9));
      expect(p.costFor(g, 30, 2), closeTo(120, 1e-9));
    });

    test('very long gaps are capped', () {
      final g = TamperGap(start: start, end: start.add(const Duration(days: 3)), reason: 'x');
      expect(p.rawMetresFor(g, 10), closeTo(160, 1e-9));
    });

    test('gap charge lands in the ledger as tamper debt', () {
      final e = DebtEngine(config: const DebtConfig(), state: DebtState.fresh(start));
      final g = TamperGap(start: start, end: start.add(const Duration(hours: 1)), reason: 'x');
      e.chargeFlat(p.costFor(g, 20, e.config.ratio), start, tamper: true);
      expect(e.debtM, closeTo(40, 1e-9));
      expect(e.state.tamperChargedTodayM, closeTo(40, 1e-9));
    });
  });

  group('WalkTracker', () {
    test('first reading sets the baseline only', () {
      final w = WalkTracker();
      expect(w.onCounter(1000), 0);
      expect(w.onCounter(1100), closeTo(75, 1e-9));
    });
    test('resumes from a persisted baseline', () {
      final w = WalkTracker(strideM: 0.8, baseline: 500);
      expect(w.onCounter(510), closeTo(8, 1e-9));
    });
    test('reboot resets the counter', () {
      final w = WalkTracker(baseline: 9000);
      expect(w.onCounter(40), closeTo(30, 1e-9));
    });
    test('implausible jumps are dropped', () {
      final w = WalkTracker(baseline: 0);
      expect(w.onCounter(100000), 0);
      expect(w.onCounter(100010), closeTo(7.5, 1e-9));
    });
    test('stride is editable within sane bounds', () {
      final w = WalkTracker()..strideM = 0.6;
      expect(w.strideM, 0.6);
      w.strideM = 5;
      expect(w.strideM, 0.6);
    });
  });
}
