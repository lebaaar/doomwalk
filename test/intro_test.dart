import 'package:doomwalk/core/presets.dart';
import 'package:doomwalk/core/scroll_wallet.dart';
import 'package:doomwalk/ui/intro_stories.dart';
import 'package:doomwalk/ui/price_table.dart';
import 'package:doomwalk/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('price table', () {
    test('Balanced: a tier per 50 m, steps to fill a 50 m bank', () {
      final rows = priceRows(const WalletConfig());
      expect(rows.map((r) => r.price), [4, 6, 9, 12, 18]);
      expect(rows.map((r) => r.fromM), [0, 50, 100, 150, 200]);
      expect(rows.last.toM, isNull); // 200 m and up
      // 50 m at 4x = 200 m walked = 267 steps at 0.75 m.
      expect(rows.map((r) => r.stepsToFill), [267, 400, 600, 800, 1200]);
    });

    test('follows the preset, the bank size and the stride', () {
      final gentle = priceRows(
        Strictness.gentle.applyTo(
          const WalletConfig(strideM: 0.8, bankCapM: 100),
        ),
      );
      expect(gentle.map((r) => r.price), [3, 4, 6, 9, 12]);
      expect(gentle.map((r) => r.fromM), [0, 50, 100, 150, 200]);
      expect(
        gentle.first.stepsToFill,
        375,
      ); // 100 m at 3x = 300 m at 0.8 m a step
    });
  });

  group('intro stories', () {
    Future<void> show(WidgetTester tester, VoidCallback onDone) =>
        tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(Brightness.dark),
            home: IntroStories(config: const WalletConfig(), onDone: onDone),
          ),
        );

    testWidgets(
      'tap right goes on, tap left goes back, time moves on by itself',
      (tester) async {
        await show(tester, () {});
        expect(find.textContaining('Take a walk first.'), findsOneWidget);
        await tester.tapAt(const Offset(700, 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Your scrolling, in metres'), findsOneWidget);
        await tester.tapAt(const Offset(20, 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.textContaining('Take a walk first.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Your scrolling, in metres'), findsOneWidget);
      },
    );

    testWidgets('holding pauses at once; letting go resumes without skipping', (
      tester,
    ) async {
      await show(tester, () {});
      final g = await tester.createGesture();
      await g.down(const Offset(400, 300), timeStamp: Duration.zero);
      await tester.pump(
        const Duration(seconds: 10),
      ); // far past the 7 s a slide lasts
      expect(find.textContaining('Take a walk first.'), findsOneWidget);
      await g.up(timeStamp: const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.textContaining('Take a walk first.'),
        findsOneWidget,
      ); // no skip on release
      await tester.pump(
        const Duration(seconds: 8),
      ); // resumed: moves on by itself
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Your scrolling, in metres'), findsOneWidget);
    });

    testWidgets('the system bars are see-through with light icons', (
      tester,
    ) async {
      await show(tester, () {});
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).last,
      );
      expect(region.value.systemNavigationBarColor, Colors.transparent);
      expect(region.value.statusBarColor, Colors.transparent);
      expect(region.value.systemNavigationBarIconBrightness, Brightness.light);
      expect(region.value.systemNavigationBarContrastEnforced, isFalse);
    });

    testWidgets('skip finishes, and the last slide waits for its button', (
      tester,
    ) async {
      var done = 0;
      await show(tester, () => done++);
      await tester.tap(find.text('Skip'));
      expect(done, 1);
      for (var i = 0; i < 12; i++) {
        await tester.tapAt(const Offset(700, 400));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.text('Nothing leaves your phone'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10)); // doesn't close by itself
      expect(find.text('Nothing leaves your phone'), findsOneWidget);
      await tester.tap(find.text('Set it up'));
      expect(done, 2);
    });
  });
}
