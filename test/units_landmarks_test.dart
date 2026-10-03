import 'package:flutter_test/flutter_test.dart';
import 'package:scrolldebt/core/landmarks.dart';
import 'package:scrolldebt/core/units.dart';

void main() {
  group('pixels to metres', () {
    test('one inch of pixels is 2.54 cm', () {
      expect(pixelsToMetres(420, 420), closeTo(0.0254, 1e-12));
    });
    test('sign is ignored and round trip holds', () {
      expect(pixelsToMetres(-840, 420), closeTo(0.0508, 1e-12));
      expect(metresToPixels(pixelsToMetres(1234, 401.5), 401.5), closeTo(1234, 1e-6));
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
      expect(describeTier(828, LandmarkTier.week), '1.0 Burj Khalifa this week');
      expect(describeTier(4424.5, LandmarkTier.lifetime), '0.5 Everests lifetime');
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
  });
}
