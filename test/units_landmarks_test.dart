import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/landmarks.dart';
import 'package:doomwalk/core/units.dart';

void main() {
  test('round figures drop needless decimals', () {
    expect(formatRound(60), '60 m');
    expect(formatRound(5000), '5 km');
    expect(formatRound(1500), '1.5 km');
    expect(formatRound(999.6), '1 km');
    expect(formatRound(1960), '2 km');
    expect(formatRound(-1500), '-1.5 km');
  });

  test('distances switch to km after rounding', () {
    expect(formatMetres(999.94), '999.9 m');
    expect(formatMetres(999.96), '1.00 km');
    expect(formatMetres(1280), '1.28 km');
  });

  test('multipliers drop needless decimals', () {
    expect(formatTimes(3), '3×');
    expect(formatTimes(1.5), '1.5×');
  });

  test('counts get thousands separators', () {
    expect(formatCount(0), '0');
    expect(formatCount(999), '999');
    expect(formatCount(1133), '1,133');
    expect(formatCount(182340), '182,340');
    expect(formatCount(1234567), '1,234,567');
  });

  group('pixels to metres', () {
    test('one inch of pixels is 2.54 cm', () {
      expect(pixelsToMetres(420, 420), closeTo(0.0254, 1e-12));
    });
    test('sign is ignored and round trip holds', () {
      expect(pixelsToMetres(-840, 420), closeTo(0.0508, 1e-12));
      expect(
        metresToPixels(pixelsToMetres(1234, 401.5), 401.5),
        closeTo(1234, 1e-6),
      );
    });
    test('zero dpi yields zero', () => expect(pixelsToMetres(100, 0), 0));
    test('sanitizeDpi falls back on implausible ydpi', () {
      expect(sanitizeDpi(ydpi: 411.0, densityDpi: 420), 411.0);
      expect(sanitizeDpi(ydpi: 0, densityDpi: 420), 420);
      expect(sanitizeDpi(ydpi: 160, densityDpi: 480), 480);
      expect(sanitizeDpi(ydpi: 1200, densityDpi: 440), 440);
    });
  });

  group('landmarks', () {
    test('tier text', () {
      expect(describeTier(759, LandmarkTier.today), '2.3 Eiffel Towers today');
      expect(
        describeTier(828, LandmarkTier.week),
        '1.0 Burj Khalifa this week',
      );
      expect(
        describeTier(4424.5, LandmarkTier.lifetime),
        '0.5 Everests lifetime',
      );
    });
    test('nearest landmark on a log scale', () {
      expect(nearestLandmark(0), eiffel);
      expect(nearestLandmark(100), eiffel);
      expect(nearestLandmark(600), burj);
      expect(nearestLandmark(5000), everest);
      expect(nearestLandmark(40000), karman);
      expect(nearestText(165), '0.5 Eiffel Towers');
    });
    test('progress toward the next landmark', () {
      final p = progressToward(165);
      expect(p.next, eiffel);
      expect(p.fraction, closeTo(0.5, 1e-9));
      final q = progressToward(1000);
      expect(q.next, everest);
      expect(q.passed, [eiffel, burj]);
      expect(progressToward(150000).next, karman);
    });
    test('the climb has a landmark close by from the first metres', () {
      final p = progressToward(3, ladder: climb);
      expect(p.next, giraffe);
      expect(p.passed, isEmpty);
      final q = progressToward(100, ladder: climb);
      expect(q.next, eiffel);
      expect(q.passed, [giraffe, bus, whale, liberty]);
      expect(progressToward(5000, ladder: climb).next, everest);
      expect(progressToward(5000, ladder: climb).passed.last, triglav);
      for (var i = 1; i < climb.length; i++) {
        expect(climb[i].heightM, greaterThan(climb[i - 1].heightM));
      }
    });
    test('nearest on the climb picks small things for small distances', () {
      expect(nearestLandmark(0, ladder: climb), giraffe);
      expect(nearestLandmark(6, ladder: climb), giraffe);
      expect(nearestLandmark(28, ladder: climb), whale);
      expect(nearestLandmark(106.7, ladder: climb), liberty);
      expect(nearestLandmark(400, ladder: climb), eiffel);
    });
  });
}
