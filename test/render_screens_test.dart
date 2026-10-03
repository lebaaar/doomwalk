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
import 'package:scrolldebt/core/debt_engine.dart';
import 'package:scrolldebt/services/controller.dart';
import 'package:scrolldebt/ui/home_screen.dart';
import 'package:scrolldebt/ui/onboarding_screen.dart';
import 'package:scrolldebt/ui/providers.dart';
import 'package:scrolldebt/ui/share_card.dart';
import 'package:scrolldebt/ui/theme.dart';
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

    late ScrollDebtController c;
    await tester.runAsync(() async {
      await _loadFonts();
      final f = File('${await getDatabasesPath()}/scrolldebt.db');
      if (f.existsSync()) f.deleteSync();
      c = await ScrollDebtController.start();
      await c.updateConfig(const DebtConfig(allowanceM: 60));
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

    Future<void> back() async {
      await tester.pageBack();
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    }

    await shot('home', const HomeScreen());
    await tester.tap(find.textContaining('adds up'));
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
    await tester.tap(find.widgetWithText(SwitchListTile, 'Developer options'));
    await tester.pump(const Duration(seconds: 1));
    tester.view.physicalSize = const Size(1080, 5000);
    await shot('settings_developer', null);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Developer options'));
    await tester.pump(const Duration(seconds: 1));
    tester.view.physicalSize = const Size(1080, 2400);
    for (final (page, name) in [('Apps that count', 'apps_that_count'), ('Custom rules', 'custom_rules')]) {
      await tester.drag(find.byType(ListView).last, const Offset(0, 600));
      await tester.pump();
      await open(page);
      await shot('settings_$name', null);
      await back();
    }
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

    // Unmounting the scope disposes the controller (and closes the DB).
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  });
}
