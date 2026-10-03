// End-to-end test of the Dart side with the native shim mocked out:
// accessibility scroll events in -> ledger -> frost/notification/widget out,
// walk in -> frost cleared, persistence across a controller restart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scrolldebt/core/debt_engine.dart';
import 'package:scrolldebt/services/controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  tearDown(() => Future<void>.delayed(const Duration(milliseconds: 50)));

  setUp(() async {
    final dir = await getDatabasesPath();
    final f = File('$dir/scrolldebt.db');
    if (f.existsSync()) f.deleteSync();
    frostCalls.clear();
    notifications.clear();
    widgetData.clear();
    installMocks();
  });

  test('scroll -> debt -> frost -> walk -> clear, persisted', () async {
    final c = await ScrollDebtController.start();
    await c.updateConfig(const DebtConfig(demoMode: true)); // 2 m free, ratio 1, frost at 15 m

    // Instagram comes to the foreground and the user scrolls hard.
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 't': 0});
    final t0 = DateTime.now().millisecondsSinceEpoch;
    // 400 px at 400 dpi = 2.54 cm per event; 600 events ≈ 15.2 m raw.
    for (var i = 0; i < 600; i++) {
      await sendNative('onScroll', scrollEvent('com.instagram.android', t0 + i * 120, 400));
    }
    expect(c.state.scrolledTodayM, closeTo(15.24, 0.01));
    expect(c.todayApps['com.instagram.android']!.rawM, closeTo(15.24, 0.01));
    expect(c.debtM, greaterThan(15)); // (15.24 - 2) * 2x app * weight >= 1
    expect(c.frostLevel, 1);
    expect(c.targetFrost, 1);
    expect(frostCalls.last, 1);

    // Exempt apps are never frosted: open the dialer.
    await sendNative('onWindow', {'pkg': 'com.google.android.dialer', 't': 0});
    expect(frostCalls.last, 0);
    // Keyboard popping up does not count as an app switch.
    await sendNative('onWindow', {'pkg': 'com.google.android.inputmethod.latin', 't': 0});
    expect(c.foreground, 'com.google.android.dialer');
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 't': 0});
    expect(frostCalls.last, 1);

    // Emergency pass lifts the frost and charges 3x.
    final before = c.debtM;
    expect(c.startOverride(), isTrue);
    expect(frostCalls.last, 0);
    await sendNative('onScroll', scrollEvent('com.instagram.android', t0 + 200000, 400));
    final w = (c.debtM - before) / (0.0254 * 2 * 1 * 3);
    expect(w, inInclusiveRange(0.5, 1.6)); // velocity weight bounds
    c.endOverride();
    expect(frostCalls.last, 1);

    // Walk it off (debug hook = same path as the pedometer).
    await sendNative('debugInjectWalk', {'metres': c.debtM / 2});
    expect(c.frostLevel, lessThan(1));
    await sendNative('debugInjectWalk', {'metres': 1000.0});
    expect(c.debtM, 0);
    expect(frostCalls.last, 0);
    expect(c.state.walkedTodayM, greaterThan(1000));

    // Batched persistence: flush and restart the controller.
    await c.flush();
    final scrolled = c.state.scrolledTodayM;
    c.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final c2 = await ScrollDebtController.start();
    expect(c2.state.scrolledTodayM, closeTo(scrolled, 1e-9));
    expect(c2.config.demoMode, isTrue);
    expect(c2.todayApps['com.instagram.android']!.rawM, closeTo(scrolled, 1e-6));
    c2.dispose();
  });

  test('0x and exempt apps are not counted', () async {
    final c = await ScrollDebtController.start();
    final t0 = DateTime.now().millisecondsSinceEpoch;
    for (final pkg in ['com.google.android.apps.maps', 'com.android.settings', 'com.lan.scrolldebt']) {
      await sendNative('onScroll', scrollEvent(pkg, t0, 4000));
    }
    expect(c.state.scrolledTodayM, 0);
    await c.setRate('com.google.android.apps.maps', 1);
    await sendNative('onScroll', scrollEvent('com.google.android.apps.maps', t0 + 1000, 4000));
    expect(c.state.scrolledTodayM, closeTo(0.254, 1e-9));
    c.dispose();
  });

  test('accessibility switched off then on is charged as a tamper gap', () async {
    final c = await ScrollDebtController.start();
    final t0 = DateTime.now().millisecondsSinceEpoch;
    await sendNative('onScroll', scrollEvent('com.android.chrome', t0, 400));
    // Pretend the service was disabled 2 hours ago and is now back.
    c.debugOpenGap(DateTime.now().subtract(const Duration(hours: 2)));
    await sendNative('onServiceState', {'connected': true});
    expect(c.gaps, hasLength(1));
    // No history yet: fallback 25 m/h * 2 h * ratio 2 = 100 m.
    expect(c.state.tamperChargedTodayM, closeTo(100, 0.5));
    expect(c.debtM, closeTo(100, 0.5));
    c.dispose();
  });

  test('widget data is pushed with metres only', () async {
    final c = await ScrollDebtController.start();
    await c.flush();
    expect(widgetData['debt_text'], '0.0 m');
    expect(widgetData['progress'], 100);
    expect(widgetData['landmark_text'], contains('Eiffel'));
    expect(notifications, isNotEmpty);
    c.dispose();
  });
}
