import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'providers.dart';
import 'theme.dart';

class ScrollDebtApp extends StatelessWidget {
  const ScrollDebtApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Scroll Debt',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildTheme(),
        themeMode: ThemeMode.dark,
        home: const _Root(),
      );
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
