import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/controller.dart';
import 'ui/app.dart';
import 'ui/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Not awaited: with no activity yet (service-started engine) Android never answers system-UI calls, and awaiting hung main() before runApp
  _applyEdgeToEdge();
  AppLifecycleListener(onResume: _applyEdgeToEdge);
  final controller = await DoomWalkController.start();
  runApp(
    ProviderScope(
      overrides: [controllerProvider.overrideWith((ref) => controller)],
      child: const DoomWalkApp(),
    ),
  );
}

void _applyEdgeToEdge() =>
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
