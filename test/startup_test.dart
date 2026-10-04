// Started by a service after an update or reboot, the engine has no activity,
// and Android never answers system-UI calls. main() must still reach runApp,
// or the app opens to a blank screen.

import 'dart:async';
import 'dart:io';

import 'package:doomwalk/main.dart' as app;
import 'package:doomwalk/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/mocks.dart';

void main() {
  testWidgets('main() reaches runApp when system-UI calls are never answered', (tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    installMocks();
    final silent = Completer<Object?>(); // never completes, like a headless engine
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) => silent.future);

    await tester.runAsync(() async {
      await databaseFactory.setDatabasesPath(Directory.systemTemp.createTempSync('startup').path);
      await app.main().timeout(const Duration(seconds: 10));
    });
    await tester.pump();
    expect(find.byType(DoomWalkApp), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // disposes the controller
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  });
}
