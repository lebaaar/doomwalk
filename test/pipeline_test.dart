// End-to-end test of the Dart side with the native shim mocked out:
// accessibility scroll events in -> wallet -> frost/notification/widget out,
// walk in -> frost cleared, persistence across a controller restart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/app_catalog.dart';
import 'package:doomwalk/core/presets.dart';
import 'package:doomwalk/core/scroll_wallet.dart';
import 'package:doomwalk/services/controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/mocks.dart';

/// Small numbers so a few metres of scrolling freeze an app.
const _fast = WalletConfig(bankCapM: 50, priceTiers: [1, 2, 3], priceStepM: 5, frostAtM: 5);

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
    await c.updateConfig(_fast); // bank of 50 m, price steps of 5 m, frost at 5 m

    // Instagram comes to the foreground and the user scrolls hard.
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 't': 0});
    final t0 = DateTime.now().millisecondsSinceEpoch;
    // 400 px at 400 dpi = 2.54 cm per event; 600 events ≈ 15.2 m raw.
    for (var i = 0; i < 600; i++) {
      await sendNative('onScroll', scrollEvent('com.instagram.android', t0 + i * 120, 400));
    }
    expect(c.state.scrolledTodayM, closeTo(15.24, 0.01));
    expect(c.todayApps['com.instagram.android']!.rawM, closeTo(15.24, 0.01));
    // The day starts with an empty bank, so all of it is owed.
    expect(c.overdraftM, closeTo(15.24, 0.01));
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

    // Walk (debug hook = same path as the pedometer) at today's price (3:1
    // after 15 m): what's owed first, then the bank fills to its cap.
    expect(c.priceNow, 3);
    await sendNative('debugInjectWalk', {'metres': (c.overdraftM - 2) * 3});
    expect(c.frostLevel, closeTo(0.4, 1e-6));
    await sendNative('debugInjectWalk', {'metres': 1000.0});
    expect(c.overdraftM, 0);
    expect(c.bankM, 50);
    expect(c.bankFull, isTrue);
    expect(frostCalls.last, 0);
    expect(c.state.walkedTodayM, greaterThan(1000));

    // Batched persistence: flush and restart the controller.
    await c.flush();
    final scrolled = c.state.scrolledTodayM;
    c.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final c2 = await DoomWalkController.start();
    expect(c2.state.scrolledTodayM, closeTo(scrolled, 1e-9));
    expect(c2.config.priceStepM, 5);
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
    await c.updateConfig(const WalletConfig(bankCapM: 100));
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
    expect(c.config.bankCapM, 100);
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
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'X', 't': 0});
    c.devAddScroll('com.instagram.android', 4); // empty bank: 4 m owed, full frost at 20
    expect(frostCalls.last, closeTo(4 / 20, 0.01));
    expect(frostArgs.last['title'], 'Take a walk first');
    // (4 owed + the 50 m bank) at 4x = 216 m walked = 288 steps.
    expect(frostArgs.last['body'], contains('288\u00A0steps (about 3 minutes) puts 50\u00A0m in it'));
    c.devAddScroll('com.instagram.android', 20);
    expect(frostCalls.last, 1);
    expect(frostArgs.last['title'], 'Instagram is blocked');
    expect(frostArgs.last['body'], startsWith('Take a walk:'));
    expect(walkNudges.any((n) => (frostArgs.last['body'] as String).endsWith(n)), isTrue);
    c.dispose();
  });

  test('a running pass counts down over the app it unfroze and in the notification', () async {
    final c = await DoomWalkController.start();
    await c.updateConfig(_fast);
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

  test('an empty bank says so as it runs out, then once per app on opening', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    c.devAddSteps(80); // 60 m walked at 4x: 15 m in the bank
    await sendNative('onWindow', {'pkg': 'com.reddit.frontpage', 'cls': 'X', 't': 0});
    expect(notices, isEmpty); // scrolling left
    c.devAddScroll('com.reddit.frontpage', 15); // exactly used up, nothing owed
    await Future<void>.delayed(Duration.zero);
    expect(notices, hasLength(1)); // the moment it ran out
    expect(notices.last['title'], 'Your bank is empty');
    expect(notices.last['body'], 'Take a walk first: 267 steps puts 50 m in it for Reddit.');
    await sendNative('onWindow', {'pkg': 'com.android.chrome', 'cls': 'X', 't': 0}); // doesn't count
    expect(notices, hasLength(1));
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'X', 't': 0});
    expect(notices, hasLength(2));
    expect(notices.last['body'], contains('Instagram'));
    await sendNative('onWindow', {'pkg': 'com.android.chrome', 'cls': 'X', 't': 0});
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'X', 't': 0});
    expect(notices, hasLength(2)); // not again within 10 minutes
    c.dispose();
  });

  test('scrolling past a landmark pops nothing up', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    c.devAddSteps(1000); // a full bank, so no empty-bank notice
    await sendNative('onWindow', {'pkg': 'com.instagram.android', 'cls': 'X', 't': 0});
    c.devAddScroll('com.instagram.android', 40); // past 1 m, the giraffe, the bus and the whale
    await Future<void>.delayed(Duration.zero);
    expect(notices, isEmpty);
    c.dispose();
  });

  test('erase all data starts over as on a fresh install', () async {
    final c = await DoomWalkController.start();
    await c.completeIntro();
    await c.completeOnboarding();
    await c.setThemeMode('dark');
    await c.updateConfig(Strictness.strict.applyTo(c.config.copyWith(bankCapM: 80, strideM: 0.9)));
    await c.setCategoryRestricted(AppCategory.browser, true);
    await c.setAppCounts('com.reddit.frontpage', false);
    await c.setDeveloperOptions(true);
    c.devAddSteps(100);
    c.devAddScroll('com.instagram.android', 10);
    await c.eraseEverything();
    expect(c.introSeen, isFalse);
    expect(c.onboardingDone, isFalse);
    expect(c.themeMode, 'system');
    expect(c.developerOptions, isFalse);
    expect(Strictness.of(c.config), Strictness.balanced);
    expect(c.config.bankCapM, 50);
    expect(c.config.strideM, 0.75);
    expect(c.catalog.restricted, defaultRestricted);
    expect(c.catalog.overrides, isEmpty);
    expect(c.state.scrolledTodayM, 0);
    expect(c.todayApps, isEmpty);
    c.dispose();
    // And it stays that way after a restart.
    final c2 = await DoomWalkController.start();
    expect(c2.introSeen, isFalse);
    expect(c2.onboardingDone, isFalse);
    expect(c2.config.bankCapM, 50);
    expect(c2.catalog.overrides, isEmpty);
    c2.dispose();
  });

  test('developer scroll is priced like real scrolling', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    c.devAddSteps(32); // 24 m walked at 4x: 6 m in the bank
    c.devAddScroll('com.instagram.android', 10); // 6 from the bank, 4 owed
    expect(c.bankM, 0);
    expect(c.overdraftM, closeTo(4, 1e-9));
    expect(c.todayApps['com.instagram.android']!.rawM, closeTo(10, 1e-9));
    c.devAddScroll('com.android.chrome', 10); // browsers aren't restricted by default
    expect(c.overdraftM, closeTo(4, 1e-9));
    await c.setCategoryRestricted(AppCategory.browser, true);
    c.devAddScroll('com.android.chrome', 10); // now it counts
    expect(c.overdraftM, closeTo(14, 1e-9));
    c.devAddScroll('com.google.android.apps.maps', 10); // doesn't count
    c.devAddScroll('com.android.settings', 10); // exempt
    expect(c.state.scrolledTodayM, closeTo(20, 1e-9));
    await sendNative('debugInjectScroll', {'pkg': 'com.reddit.frontpage', 'metres': 1.0});
    expect(c.todayApps['com.reddit.frontpage']!.rawM, closeTo(1, 1e-9));
    c.dispose();
  });

  test('widget shows the bank, or the steps to fill it', () async {
    final c = await DoomWalkController.start();
    await c.flush();
    // The day starts with an empty bank.
    // Filling the 50 m bank at 4x: 200 m walked = 267 steps.
    expect(widgetData['debt_text'], '267');
    expect(widgetData['caption_text'], 'steps for 50 m');
    expect(widgetData['progress'], 0); // today's walking goal
    expect(widgetData['landmark_text'], contains('Eiffel'));
    expect(notifications, isNotEmpty);
    expect(notifications.last['title'], 'Bank empty. Walk 267 steps for 50 m');
    c.dispose();
  });

  test('the capped bank and rising price, end to end', () async {
    final c = await DoomWalkController.start();
    await c.setDeveloperOptions(true);
    c.devAddSteps(400); // 300 m walked at 4x = 75 m, but the bank holds 50
    expect(c.bankM, 50);
    expect(c.bankFull, isTrue);
    expect(c.state.overflowWalkTodayM, closeTo(100, 1e-9));
    await Future<void>.delayed(const Duration(milliseconds: 300)); // notification is debounced
    expect(notifications.last['title'], 'Bank full: 50 m to scroll');
    c.devAddScroll('com.instagram.android', 40);
    expect(c.bankM, closeTo(10, 1e-9));
    expect(c.priceNow, 4); // 40 m scrolled today
    c.devAddScroll('com.instagram.android', 20); // 10 from the bank, 10 owed
    expect(c.priceNow, 6); // 60 m scrolled today: the next tier
    c.devAddSteps(100); // 75 m walked at 6x = 12.5 m: 10 pays what's owed, 2.5 to the bank
    expect(c.overdraftM, 0);
    expect(c.bankM, closeTo(2.5, 1e-9));
    c.devAddScroll('com.instagram.android', 22.5); // 2.5 from the bank, 20 owed
    expect(c.overdraftM, closeTo(20, 1e-9));
    expect(c.frostLevel, 1);
    await c.updateConfig(c.config.copyWith(bankCapM: WalletConfig.maxBankCapM));
    c.devAddSteps(10000);
    expect(c.bankM, 100);
    c.dispose();
  });

  test('our own frost windows do not lift the frost', () async {
    final c = await DoomWalkController.start();
    await c.updateConfig(_fast);
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
    await c.updateConfig(const WalletConfig(overridesPerDay: 2));
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
