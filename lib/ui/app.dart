import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'providers.dart';
import 'theme.dart';

class ScrollDebtApp extends ConsumerWidget {
  const ScrollDebtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(controllerProvider.select((c) => c.themeMode));
    return MaterialApp(
      title: 'Scroll Debt',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: const _Root(),
    );
  }
}

/// Shows onboarding until the user has finished it, then the dashboard.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    return c.onboardingDone ? const HomeScreen() : const OnboardingScreen();
  }
}
