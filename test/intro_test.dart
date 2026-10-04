import 'package:doomwalk/core/presets.dart';
import 'package:doomwalk/core/scroll_wallet.dart';
import 'package:doomwalk/ui/intro_stories.dart';
import 'package:doomwalk/ui/price_table.dart';
import 'package:doomwalk/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('price table', () {
    test('Balanced: five rows of 100 m, steps per 100 m at a 0.75 m stride', () {
      final rows = priceRows(const WalletConfig());
      expect(rows.map((r) => r.price), [1, 2, 3, 4, 5]);
      expect(rows.map((r) => r.fromM), [0, 100, 200, 300, 400]);
      expect(rows.last.toM, isNull); // 400 m and up
      expect(rows.map((r) => r.stepsPer100), [134, 267, 400, 534, 667]);
    });

    test('follows the preset and the stride', () {
      final gentle = priceRows(Strictness.gentle.applyTo(const WalletConfig(strideM: 0.8)));
      expect(gentle.map((r) => r.price), [1, 2, 3]);
      expect(gentle.map((r) => r.fromM), [0, 200, 400]);
      expect(gentle.first.stepsPer100, 125);
    });
  });

  group('intro stories', () {
    Future<void> show(WidgetTester tester, VoidCallback onDone) => tester.pumpWidget(MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: IntroStories(config: const WalletConfig(), onDone: onDone),
        ));

    testWidgets('tap right goes on, tap left goes back, time moves on by itself', (tester) async {
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
    });

    testWidgets('skip finishes, and the last slide waits for its button', (tester) async {
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
