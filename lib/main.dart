import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/controller.dart';
import 'ui/app.dart';
import 'ui/providers.dart';

/// Entry point. The native shim starts this in a cached, headless engine
/// from its services; the activity attaches to the same engine, so the
/// controller below lives as long as the process, with or without UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars (see overlayStyle). Never
  // awaited: when a service starts the engine (after an update, a reboot or
  // a kill, with scroll measuring on) there is no activity yet, and Android
  // drops system-UI calls without ever answering them. Awaiting it here hung
  // main() before runApp, so the app opened to a blank screen until the
  // process died. Applied again once the activity is in front.
  _applyEdgeToEdge();
  AppLifecycleListener(onResume: _applyEdgeToEdge);
  final controller = await DoomWalkController.start();
  runApp(ProviderScope(
    overrides: [controllerProvider.overrideWith((ref) => controller)],
    child: const DoomWalkApp(),
  ));
}

void _applyEdgeToEdge() => unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
