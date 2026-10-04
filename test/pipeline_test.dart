// End-to-end test of the Dart side with the native shim mocked out:
// accessibility scroll events in -> wallet -> frost/notification/widget out,
// walk in -> frost cleared, persistence across a controller restart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/app_catalog.dart';
import 'package:doomwalk/core/scroll_wallet.dart';
import 'package:doomwalk/services/controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  tearDown(() => Future<void>.delayed(const Duration(milliseconds: 50)));

  setUp(() async {
    final dir = await getDatabasesPath();
    final f = File('$dir/doomwalk.db');
    if (f.existsSync()) f.deleteSync();
    frostCalls.clear();
    frostArgs.clear();
    notices.clear();
    notifications.clear();
    widgetData.clear();
    statusOverrides.clear();
    restartCalls = 0;
    installMocks();
  });

  test('scroll -> overdraft -> frost -> walk -> clear, persisted', () async {
    final c = await DoomWalkController.start();
    await c.updateConfig(const WalletConfig(demoMode: true)); // 2 m free, steps of 5 m, frost at 5 m

    // Instagram comes to the foreground and the user scrolls hard.
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 't': 0});
    final t0 = DateTime.now().millisecondsSinceEpoch;
    // 400 px at 400 dpi = 2.54 cm per event; 600 events ≈ 15.2 m raw.
    for (var i = 0; i < 600; i++) {
      await sendNative('onScroll', scrollEvent('com.instagram.android', t0 + i * 120, 400));
    }
    expect(c.state.scrolledTodayM, closeTo(15.24, 0.01));
    expect(c.todayApps['com.instagram.android']!.rawM, closeTo(15.24, 0.01));
    // 13.24 m past the free 2 m with an empty bank: 5 at 1:1, 5 at 2:1, the rest at 3:1.
    expect(c.overdraftM, closeTo(5 + 10 + 3.24 * 3, 0.05));
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

    // Emergency pass lifts the frost, and scrolling during it is free.
    final before = c.overdraftM;
    expect(c.startOverride(), isTrue);
    expect(frostCalls.last, 0);
    await sendNative('onScroll', scrollEvent('com.instagram.android', t0 + 200000, 400));
    expect(c.overdraftM, before);
    c.endOverride();
    expect(frostCalls.last, 1);

    // Walk (debug hook = same path as the pedometer): the overdraft first,
    // then the bank fills.
    await sendNative('debugInjectWalk', {'metres': c.overdraftM - 2});
    expect(c.frostLevel, closeTo(0.4, 1e-6));
    await sendNative('debugInjectWalk', {'metres': 1000.0});
    expect(c.overdraftM, 0);
    expect(c.bankM, closeTo(998, 1e-6));
    expect(frostCalls.last, 0);
    expect(c.state.walkedTodayM, greaterThan(1000));

    // Batched persistence: flush and restart the controller.
    await c.flush();
    final scrolled = c.state.scrolledTodayM;
    c.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final c2 = await DoomWalkController.start();
    expect(c2.state.scrolledTodayM, closeTo(scrolled, 1e-9));
    expect(c2.config.demoMode, isTrue);
    expect(c2.todayApps['com.instagram.android']!.rawM, closeTo(scrolled, 1e-6));
    c2.dispose();
  });

  test('apps that don\'t count and exempt apps are not counted', () async {
    final c = await DoomWalkController.start();
    final t0 = DateTime.now().millisecondsSinceEpoch;
    for (final pkg in ['com.google.android.apps.maps', 'com.android.settings', 'com.lebaaar.doomwalk']) {
      await sendNative('onScroll', scrollEvent(pkg, t0, 4000));
    }
    expect(c.state.scrolledTodayM, 0);
    await c.setAppCounts('com.google.android.apps.maps', true);
    await sendNative('onScroll', scrollEvent('com.google.android.apps.maps', t0 + 1000, 4000));
    expect(c.state.scrolledTodayM, closeTo(0.254, 1e-9));
    c.dispose();
  });

  test('accessibility switched off then on is charged as a tamper gap', () async {
    final c = await DoomWalkController.start();
    final t0 = DateTime.now().millisecondsSinceEpoch;
    await sendNative('onScroll', scrollEvent('com.android.chrome', t0, 400));
    // Pretend the service was disabled 2 hours ago and is now back.
    c.debugOpenGap(DateTime.now().subtract(const Duration(hours: 2)));
    await sendNative('onServiceState', {'connected': true});
    expect(c.gaps, hasLength(1));
    // No history yet: fallback 25 m/h * 2 h = 50 m of walking, owed.
    expect(c.state.tamperChargedTodayM, closeTo(50, 0.5));
    expect(c.overdraftM, closeTo(50, 0.5));
    c.dispose();
  });

  test('developer tools do nothing until developer options are on', () async {
    final c = await DoomWalkController.start();
    await c.updateConfig(const WalletConfig(allowanceM: 0));
    c.devAddScroll('com.instagram.android', 10);
    c.devAddSteps(1000);
    expect(c.state.scrolledTodayM, 0);
    expect(c.state.walkedTodayM, 0);
    await c.setDeveloperOptions(true);
    c.devAddScroll('com.instagram.android', 10);
    expect(c.state.scrolledTodayM, closeTo(10, 1e-9));
    c.devAddSteps(1000); // stride 0.75 m
    expect(c.state.walkedTodayM, closeTo(750, 1e-9));
    c.dispose();
  });

  test('developer reset zeroes walking, scrolling and the wallet but keeps settings', () async {
    final c = await DoomWalkController.start();
    await c.updateConfig(const WalletConfig(allowanceM: 0));
    await c.setDeveloperOptions(true);
    c.devAddScroll('com.instagram.android', 10);
    c.devAddSteps(10);
    expect(c.overdraftM, greaterThan(0));
    await c.setDeveloperOptions(false);
    await c.devResetTracking(); // switch off: nothing happens
    expect(c.state.scrolledTodayM, closeTo(10, 1e-9));
    await c.setDeveloperOptions(true);
    await c.devResetTracking();
    expect(c.overdraftM, 0);
    expect(c.bankM, 0);
    expect(c.state.scrolledTodayM, 0);
    expect(c.state.walkedTodayM, 0);
    expect(c.todayApps, isEmpty);
    expect(c.config.allowanceM, 0);
    c.dispose();
  });

  test('a stopped service is restarted once confirmed, at most once a minute', () async {
    final c = await DoomWalkController.start();
    statusOverrides.addAll({'serviceConnected': false, 'canRestartService': true});
    await c.refreshStatus(); // first sighting: may still be connecting
    expect(restartCalls, 0);
    await c.refreshStatus();
    expect(restartCalls, 1);
    await c.refreshStatus();
    await c.refreshStatus();
    expect(restartCalls, 1);
    c.dispose();
  });

  test('without WRITE_SECURE_SETTINGS a stopped service is only reported', () async {
    statusOverrides.addAll({
      'serviceConnected': false,
      'exitReason': 8,
      'exitTimeMs': 1700000000000,
    });
    final c = await DoomWalkController.start();
    await c.refreshStatus();
    await c.refreshStatus();
    expect(restartCalls, 0);
    expect(c.status.serviceStalled, isTrue);
    expect(c.status.lastExit!.label, 'a permission was changed');
    c.dispose();
  });

  test('a frozen app gets a card saying take a walk, in steps', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    await c.updateConfig(const WalletConfig(allowanceM: 2)); // full frost at 20 m owed
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'X', 't': 0});
    c.devAddScroll('com.instagram.android', 6); // 2 free, then 4 m owed at 1:1
    expect(frostCalls.last, closeTo(4 / 20, 0.01));
    expect(frostArgs.last['title'], 'Take a walk first');
    // 4 owed + the next 100 m (96 at 1:1, 4 at 2:1) = 108 m = 144 steps.
    expect(frostArgs.last['body'], contains('144\u00A0steps (about 2 minutes) unlocks 100\u00A0m'));
    c.devAddScroll('com.instagram.android', 20);
    expect(frostCalls.last, 1);
    expect(frostArgs.last['title'], 'Instagram is frozen');
    expect(frostArgs.last['body'], startsWith('Take a walk:'));
    expect(walkNudges.any((n) => (frostArgs.last['body'] as String).endsWith(n)), isTrue);
    c.dispose();
  });

  test('a running pass counts down over the app it unfroze and in the notification', () async {
    final c = await DoomWalkController.start();
    await c.updateConfig(const WalletConfig(demoMode: true));
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'X', 't': 0});
    await c.setDeveloperOptions(true);
    c.devAddScroll('com.instagram.android', 20);
    expect(frostArgs.last['passUntilMs'], isNull);
    expect(c.startOverride(), isTrue);
    final until = c.state.overrideUntilMs!;
    expect(frostCalls.last, 0);
    expect(frostArgs.last['passUntilMs'], until);
    await sendNative('onWindow', {'pkg': 'com.android.settings', 'cls': 'X', 't': 0}); // exempt
    expect(frostArgs.last['passUntilMs'], isNull);
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'X', 't': 0});
    expect(frostArgs.last['passUntilMs'], until);
    await Future<void>.delayed(const Duration(milliseconds: 300)); // notification is debounced
    expect(notifications.last['overrideUntilMs'], until);
    c.endOverride();
    expect(frostArgs.last['passUntilMs'], isNull);
    c.dispose();
  });

  test('running out of free scrolling says so, then once per app on opening', () async {
    final c = await DoomWalkController.start();
    await c.updateConfig(const WalletConfig(allowanceM: 5));
    await c.setDeveloperOptions(true);
    await c.setMilestoneToasts(false); // only the used-up notice here
    await sendNative('onWindow', {'pkg': 'com.reddit.frontpage', 'cls': 'X', 't': 0});
    expect(notices, isEmpty); // free scrolling left
    c.devAddScroll('com.reddit.frontpage', 5); // exactly used up, nothing owed
    await Future<void>.delayed(Duration.zero);
    expect(notices, hasLength(1)); // the moment it ran out
    expect(notices.last['body'], contains('Take a walk first: 134 steps unlocks 100 m'));
    await sendNative('onWindow', {'pkg': 'com.android.chrome', 'cls': 'X', 't': 0}); // doesn't count
    expect(notices, hasLength(1));
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'X', 't': 0});
    expect(notices, hasLength(2));
    expect(notices.last['title'], 'Free scrolling used up');
    expect(notices.last['body'], contains('Instagram'));
    await sendNative('onWindow', {'pkg': 'com.android.chrome', 'cls': 'X', 't': 0});
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'X', 't': 0});
    expect(notices, hasLength(2)); // not again within 10 minutes
    // With walking in the bank, it says how far that goes instead.
    c.devAddSteps(100); // 75 m
    await sendNative('onWindow', {'pkg': 'com.pinterest', 'cls': 'X', 't': 0});
    expect(notices.last['body'], contains('75 m earned left'));
    c.dispose();
  });

  test('passing a milestone pops up once, and can be switched off', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'X', 't': 0});
    c.devAddScroll('com.instagram.android', 0.5);
    expect(notices, isEmpty);
    c.devAddScroll('com.instagram.android', 5.5); // past 1 m and the giraffe at once
    await Future<void>.delayed(Duration.zero);
    expect(notices, hasLength(1));
    expect(notices.last['title'], contains('giraffe'));
    c.devAddScroll('com.instagram.android', 1);
    await Future<void>.delayed(Duration.zero);
    expect(notices, hasLength(1)); // nothing new passed
    // Survives a restart, and switched off it stays quiet.
    await c.setMilestoneToasts(false);
    c.dispose();
    final c2 = await DoomWalkController.start();
    expect(c2.milestoneToasts, isFalse);
    await c2.setDeveloperOptions(true);
    c2.devAddScroll('com.instagram.android', 10);
    await Future<void>.delayed(Duration.zero);
    expect(notices, hasLength(1));
    c2.dispose();
  });

  test('inside DoomWalk a milestone comes back to the caller, not as a banner', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    await sendNative('onWindow', {'pkg': 'com.lebaaar.doomwalk', 'cls': 'com.lebaaar.doomwalk.MainActivity', 't': 0});
    expect(c.devAddScroll('com.instagram.android', 0.5), isNull);
    expect(c.devAddScroll('com.instagram.android', 30)!.title, contains('whale'));
    await Future<void>.delayed(Duration.zero);
    expect(notices, isEmpty);
    c.dispose();
  });

  test('turning developer options off also ends demo mode', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    await c.updateConfig(c.config.copyWith(demoMode: true));
    await c.setDeveloperOptions(false);
    expect(c.config.demoMode, isFalse);
    expect(c.developerOptions, isFalse);
    c.dispose();
  });

  test('developer scroll is priced like real scrolling', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    await c.updateConfig(const WalletConfig(allowanceM: 5, priceStepM: 10));
    c.devAddScroll('com.instagram.android', 10); // 5 free, 5 at 1:1, nothing banked
    expect(c.overdraftM, closeTo(5, 1e-9));
    expect(c.todayApps['com.instagram.android']!.rawM, closeTo(10, 1e-9));
    expect(c.todayApps['com.instagram.android']!.chargedM, closeTo(5, 1e-9));
    c.devAddScroll('com.android.chrome', 10); // browsers aren't restricted by default
    expect(c.overdraftM, closeTo(5, 1e-9));
    await c.setCategoryRestricted(AppCategory.browser, true);
    c.devAddScroll('com.android.chrome', 10); // now it counts: 5 at 1:1, 5 at 2:1
    expect(c.overdraftM, closeTo(20, 1e-9));
    c.devAddScroll('com.google.android.apps.maps', 10); // doesn't count
    c.devAddScroll('com.android.settings', 10); // exempt
    expect(c.state.scrolledTodayM, closeTo(20, 1e-9));
    await sendNative('debugInjectScroll', {'pkg': 'com.reddit.frontpage', 'metres': 1.0});
    expect(c.todayApps['com.reddit.frontpage']!.rawM, closeTo(1, 1e-9));
    c.dispose();
  });

  test('widget shows scrolling left, or the steps to unlock more', () async {
    final c = await DoomWalkController.start();
    await c.flush();
    expect(widgetData['debt_text'], '150 m');
    expect(widgetData['caption_text'], 'left to scroll');
    expect(widgetData['progress'], 0); // today's walking goal
    expect(widgetData['landmark_text'], contains('Eiffel'));
    expect(notifications, isNotEmpty);
    expect(notifications.last['title'], '150 m free scrolling left');
    c.dispose();
  });

  test('the walk bank and rising price, end to end', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    await c.updateConfig(const WalletConfig(allowanceM: 10)); // steps of 100 m
    c.devAddSteps(400); // 300 m banked before any scrolling
    expect(c.bankM, closeTo(300, 1e-9));
    expect(c.earnedScrollLeftM, closeTo(200, 1e-9)); // 100 at 1:1 + 100 at 2:1
    c.devAddScroll('com.instagram.android', 160); // 10 free, 100 at 1, 50 at 2
    expect(c.bankM, closeTo(100, 1e-9));
    expect(c.priceNow, 2);
    expect(c.earnedScrollLeftM, closeTo(50, 1e-9));
    expect(c.frostLevel, 0);
    c.devAddScroll('com.instagram.android', 60); // 50 at 2 empties it, 10 at 3 owed
    expect(c.overdraftM, closeTo(30, 1e-9));
    expect(c.frostLevel, 1);
    c.dispose();
  });

  test('our own frost windows do not lift the frost', () async {
    final c = await DoomWalkController.start();
    await c.updateConfig(const WalletConfig(demoMode: true));
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'com.instagram.mainactivity.MainActivity', 't': 0});
    await c.setDeveloperOptions(true);
    c.devAddScroll('com.instagram.android', 20);
    expect(frostCalls.last, 1);

    // Adding the overlay and its action bar makes Android announce both
    // windows as window-state events from our package.
    await sendNative('onWindow', {'pkg': selfPackage, 'cls': 'android.widget.FrameLayout', 't': 0});
    await sendNative('onWindow', {'pkg': selfPackage, 'cls': 'android.widget.LinearLayout', 't': 0});
    expect(c.foreground, 'com.instagram.android');
    expect(frostCalls.last, 1);

    // Opening DoomWalk itself still lifts it.
    await sendNative('onWindow', {'pkg': selfPackage, 'cls': selfActivity, 't': 0});
    expect(c.foreground, selfPackage);
    expect(frostCalls.last, 0);
    c.dispose();
  });

  test('a day change from a pass or a getter reloads today', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    await c.updateConfig(const WalletConfig(allowanceM: 0, overridesPerDay: 2));
    c.devAddScroll('com.instagram.android', 1);
    expect(c.startOverride(), isTrue);
    expect(c.overridesLeft, 1);
    expect(c.passesUsedToday, 1);
    // Pretend the wallet is from yesterday: reading passes must not roll it.
    c.state.dayKey = '2000-01-01';
    expect(c.overridesLeft, 2);
    expect(c.passesUsedToday, 0);
    expect(c.state.dayKey, '2000-01-01');
    c.dispose();
  });
}
