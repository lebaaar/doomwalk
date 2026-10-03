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
  // Draw behind the status and navigation bars (see overlayStyle).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final controller = await ScrollDebtController.start();
  runApp(ProviderScope(
    overrides: [controllerProvider.overrideWith((ref) => controller)],
    child: const ScrollDebtApp(),
  ));
}
