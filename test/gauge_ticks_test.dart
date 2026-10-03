import 'package:flutter_test/flutter_test.dart';
import 'package:scrolldebt/ui/altitude_gauge.dart';

void main() {
  test('gauge ticks land on round numbers', () {
    expect(niceTickStep(150), 50); // 50, 100 under the summit
    expect(niceTickStep(15), 5); // demo mode
    expect(niceTickStep(60), 20);
    expect(niceTickStep(400), 100);
    expect(niceTickStep(0), 0);
  });
}
