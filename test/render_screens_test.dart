// Renders the real screens on the host with the native shim mocked.
// Always a smoke test (no exceptions while building). With
//   RENDER_SCREENS=1 flutter test test/render_screens_test.dart
// it also writes PNGs to docs/screenshots/host_*.png for design review.
// (Emoji render as boxes on the host.)

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/services/controller.dart';
import 'package:doomwalk/ui/home_screen.dart';
import 'package:doomwalk/ui/intro_stories.dart';
import 'package:doomwalk/ui/onboarding_screen.dart';
import 'package:doomwalk/ui/providers.dart';
import 'package:doomwalk/ui/share_card.dart';
import 'package:doomwalk/ui/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/mocks.dart';

final _write = Platform.environment['RENDER_SCREENS'] == '1';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) l.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await l.load();
  }

  await load('Geist', [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/Geist-$w.ttf']);
  await load('Phosphor', ['assets/fonts/Phosphor-Regular.ttf']);
  // Back arrows etc. The flutter tool sets FLUTTER_ROOT for test runs.
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '';
  await load('MaterialIcons', ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  await load('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('render screens', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    installMocks();

    late DoomWalkController c;
    await tester.runAsync(() async {
      await _loadFonts();
      // Own directory: test files run in parallel, and the pipeline tests
      // delete the shared database file between their cases.
      await databaseFactory.setDatabasesPath(Directory.systemTemp.createTempSync('render').path);
      final f = File('${await getDatabasesPath()}/doomwalk.db');
      if (f.existsSync()) f.deleteSync();
      c = await DoomWalkController.start();
      final t0 = DateTime.now().millisecondsSinceEpoch;
      Future<void> scroll(String pkg, int n, int dy, int gapMs) async {
        await sendNative('onWindow', {'pkg': pkg, 't': 0});
        for (var i = 0; i < n; i++) {
          await sendNative('onScroll', scrollEvent(pkg, t0 + i * gapMs, dy));
        }
      }

      await scroll('com.android.chrome', 900, 900, 400);
      await scroll('com.reddit.frontpage', 700, 1100, 150);
      await scroll('com.zhiliaoapp.musically', 500, 1500, 100);
      await scroll('com.instagram.android', 1400, 1200, 110);
      await sendNative('debugInjectWalk', {'metres': 60.0});
      await c.flush();
    });

    final screen = ValueNotifier<Widget>(const SizedBox());
    final brightness = ValueNotifier<Brightness>(Brightness.dark);
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
      overrides: [controllerProvider.overrideWith((ref) => c)],
      child: RepaintBoundary(
        key: key,
        child: ValueListenableBuilder<Brightness>(
          valueListenable: brightness,
          builder: (_, b, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(b),
            home: ValueListenableBuilder<Widget>(valueListenable: screen, builder: (_, w, _) => w),
          ),
        ),
      ),
    ));

    Future<void> shot(String name, Widget? child) async {
      if (child != null) screen.value = child;
      // Small steps, like real frames: one big jump skips the end of the
      // theme animation and leaves buttons in the old theme's colours.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      if (!_write) return;
      await tester.runAsync(() async {
        final ro = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await ro.toImage(pixelRatio: 1.5);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory('docs/screenshots').createSync(recursive: true);
        File('docs/screenshots/host_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    Future<void> tab(String label) async {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> open(String text) async {
      await tester.tap(find.text(text).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    }

    Finder settingsList() =>
        find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;

    Future<void> toggleDev() async {
      final dev = find.widgetWithText(SwitchListTile, 'Developer options');
      // The settings list builds lazily: scroll until the switch exists.
      await tester.scrollUntilVisible(dev, 300, scrollable: settingsList());
      await tester.pump();
      await tester.tap(dev);
    }

    Future<void> back() async {
      await tester.pageBack();
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    }

    await shot('home', const HomeScreen());
    await tester.tap(find.text('How it works'));
    await tester.pump(const Duration(seconds: 1));
    await shot('ledger', null);
    Navigator.of(tester.element(find.byType(LedgerView))).pop();
    await tester.pump(const Duration(seconds: 1));
    tester.view.physicalSize = const Size(1080, 4000);
    await shot('tab_today', null);
    await tab('Activity');
    await shot('tab_activity', null);
    await tab('Settings');
    await shot('tab_settings', null);
    await toggleDev();
    await tester.pump(const Duration(seconds: 1));
    tester.view.physicalSize = const Size(1080, 5000);
    await shot('settings_developer', null);
    await toggleDev();
    await tester.pump(const Duration(seconds: 1));
    tester.view.physicalSize = const Size(1080, 2400);
    for (final (page, name) in [('Apps that count', 'apps_that_count'), ('Custom rules', 'custom_rules')]) {
      await tester.scrollUntilVisible(find.text(page), -300, scrollable: settingsList());
      await tester.pump();
      await open(page);
      await shot('settings_$name', null);
      await back();
    }
    await tester.ensureVisible(find.text('Permissions'));
    await tester.pump();
    await open('Permissions');
    await shot('permissions', null);
    await back();
    // Switched on but not running, after a permission change killed the app.
    statusOverrides.addAll({'serviceConnected': false, 'exitReason': 8, 'exitTimeMs': DateTime.now().millisecondsSinceEpoch});
    await tester.runAsync(c.refreshStatus);
    await toggleDev();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Permissions'));
    await tester.pump();
    await open('Permissions');
    tester.view.physicalSize = const Size(1080, 3200);
    await shot('permissions_stopped', null);
    tester.view.physicalSize = const Size(1080, 2400);
    await back();
    await toggleDev();
    await tester.pump(const Duration(seconds: 1));
    statusOverrides.clear();
    await tester.runAsync(c.refreshStatus);
    await tab('Today');
    await shot('onboarding', const OnboardingScreen());
    await shot('share_card', Scaffold(
      body: Center(child: Padding(padding: const EdgeInsets.all(20), child: ShareCard(c: c, pkg: 'com.instagram.android'))),
    ));

    brightness.value = Brightness.light;
    await shot('home_light', const HomeScreen());
    tester.view.physicalSize = const Size(1080, 4000);
    await tab('Activity');
    await shot('tab_activity_light', null);
    tester.view.physicalSize = const Size(1080, 2400);

    // Tapping an app opens its share card in a sheet with the buttons inside.
    await tester.tap(find.text('Instagram').first);
    await tester.pump(const Duration(seconds: 1));
    await shot('share_dialog_light', null);
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(seconds: 1));

    // The bank spent exactly, nothing owed: "take a walk first".
    await tester.runAsync(() async {
      await c.setDeveloperOptions(true);
      await c.devResetTracking();
      c.devAddSteps(80);
      c.devAddScroll('com.instagram.android', 60);
      await c.setDeveloperOptions(false);
    });
    await tab('Today');
    await shot('home_done_light', null);
    brightness.value = Brightness.dark;
    await shot('home_done', null);

    // A long landmark (the whale) lies under the text instead of squeezing
    // it, with some scrolling still in the bank.
    await tester.runAsync(() async {
      await c.setDeveloperOptions(true);
      await c.devResetTracking();
      c.devAddSteps(200);
      c.devAddScroll('com.instagram.android', 17.5);
      await c.setDeveloperOptions(false);
    });
    tester.view.physicalSize = const Size(1080, 3200);
    await shot('home_climb_long', null);
    tester.view.physicalSize = const Size(1080, 2400);

    // The story intro: a few slides, tapping the right side to go on.
    screen.value = IntroStories(config: c.config, onDone: () {});
    await tester.pump(const Duration(seconds: 1));
    final w = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (var i = 0; i < 9; i++) {
      if ({0, 2, 4, 5, 8}.contains(i)) {
        // shot() pumps 4 s more; slides move on at 7 s.
        await tester.pump(const Duration(seconds: 2));
        await shot('intro_$i', null);
      }
      await tester.tapAt(Offset(w - 20, 300));
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Unmounting the scope disposes the controller (and closes the DB).
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  });
}
