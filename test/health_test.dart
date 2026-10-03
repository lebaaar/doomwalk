import 'package:flutter_test/flutter_test.dart';
import 'package:scrolldebt/core/health.dart';

void main() {
  test('kcal scales with weight and distance', () {
    expect(kcalForWalk(1000, 70), closeTo(37.1, 1e-9));
    expect(kcalForWalk(5000, 80), closeTo(212, 1e-9));
    expect(kcalForWalk(-5, 70), 0);
  });

  test('metres for kcal is the inverse', () {
    expect(metresForKcal(kcalForWalk(2345, 63), 63), closeTo(2345, 1e-6));
  });

  test('streak counts back and tolerates an unfinished today', () {
    expect(walkStreak([], 5000), 0);
    expect(walkStreak([6000, 5200, 5000, 100], 5000), 3);
    expect(walkStreak([1200, 5200, 7000, 4000], 5000), 2);
    expect(walkStreak([1200, 300], 5000), 0);
  });
}
