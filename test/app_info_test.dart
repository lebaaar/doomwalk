import 'dart:convert';

import 'package:doomwalk/services/feedback.dart';
import 'package:doomwalk/ui/app_info_screen.dart';
import 'package:doomwalk/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: buildTheme(Brightness.dark), home: child);

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'DoomWalk',
      packageName: 'com.lebaaar.doomwalk',
      version: '0.1.2',
      buildNumber: '3',
      buildSignature: '',
    ),
  );

  group('feedbackPayload', () {
    test(
      'carries the message, reply address and versions, and pings no one',
      () {
        final p = feedbackPayload(
          kind: FeedbackKind.bug,
          message: '  @everyone it crashed  ',
          replyTo: 'me@example.com',
          appVersion: '0.1.2+3',
          osVersion: 'Android 14',
        );
        expect(p['allowed_mentions'], {'parse': <String>[]});
        final embed = (p['embeds']! as List).single as Map;
        expect(embed['title'], 'Bug report');
        expect(embed['description'], '@everyone it crashed');
        final fields = (embed['fields']! as List).cast<Map>();
        expect(fields.map((f) => f['name']), ['Reply to', 'App', 'Android']);
        expect(fields.first['value'], 'me@example.com');
      },
    );

    test('leaves out an empty reply address and caps long messages', () {
      final p = feedbackPayload(
        kind: FeedbackKind.contact,
        message: 'x' * 5000,
        replyTo: ' ',
        appVersion: '0.1.2+3',
        osVersion: '',
      );
      final embed = (p['embeds']! as List).single as Map;
      expect((embed['description'] as String).length, maxFeedbackLength);
      final fields = (embed['fields']! as List).cast<Map>();
      expect(fields.map((f) => f['name']), ['App', 'Android']);
      expect(fields.last['value'], '-');
      // Encodes cleanly for the request body
      expect(() => jsonEncode(p), returnsNormally);
    });

    test('an unconfigured build refuses to send', () async {
      var calls = 0;
      final sender = FeedbackSender(
        client: MockClient((_) async {
          calls++;
          return http.Response('', 204);
        }),
      );
      // Tests run without --dart-define-from-file, so neither webhook is set
      expect(FeedbackKind.contact.configured, isFalse);
      await expectLater(
        sender.send(
          kind: FeedbackKind.contact,
          message: 'hi',
          appVersion: '0.1.2+3',
        ),
        throwsStateError,
      );
      expect(calls, 0);
    });
  });

  group('App info', () {
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
      view.physicalSize = const Size(1080, 2400);
      view.devicePixelRatio = 2.625;
    });
    tearDown(
      () => TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!
          .reset(),
    );

    testWidgets('shows the spinner for at least a second, then the Play link', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(AppInfoScreen(checkForUpdate: () async => false)),
      );
      await tester.pump();
      expect(find.text('Checking for updates'), findsOneWidget);
      expect(find.text('v0.1.2+3'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Checking for updates'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('Checking for updates'), findsNothing);
      expect(find.text('View on Google Play'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('View source code'), 200);
      expect(find.text('Contact developer'), findsOneWidget);
      expect(find.text('Report a bug'), findsOneWidget);
      expect(find.text('View source code'), findsOneWidget);
    });

    testWidgets('offers the update when Play has one', (tester) async {
      await tester.pumpWidget(
        _app(AppInfoScreen(checkForUpdate: () async => true)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('View on Google Play'), findsNothing);
    });

    testWidgets('a failing check falls back to the Play link', (tester) async {
      await tester.pumpWidget(
        _app(AppInfoScreen(checkForUpdate: () => Future.error('no Play'))),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('View on Google Play'), findsOneWidget);
    });

    testWidgets('the bug form opens and can\'t send without a webhook', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(AppInfoScreen(checkForUpdate: () async => false)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Report a bug'), 200);
      await tester.tap(find.text('Report a bug'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'It crashed');
      await tester.pump();
      expect(
        find.text('This build of DoomWalk can\'t send messages.'),
        findsOneWidget,
      );
      final send = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Send'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(send.onPressed, isNull);
    });
  });
}
