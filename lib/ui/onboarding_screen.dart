import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/units.dart';
import '../services/controller.dart';
import 'icons.dart';
import 'logo.dart';
import 'providers.dart';
import 'theme.dart';

enum _StepId { restricted, accessibility, activity, notifications, battery }

class _Step {
  const _Step(
    this.id,
    this.title,
    this.why,
    this.action, {
    this.optional = false,
  });
  final _StepId id;
  final String title;
  final String why;
  final String action;
  final bool optional;
}

const _steps = [
  _Step(
    _StepId.restricted,
    'Allow restricted settings',
    'Android 13 and later block accessibility for sideloaded apps until you allow it. '
        'In App info, open the menu in the top right and tap "Allow restricted settings", then come back.',
    'Open App info',
  ),
  _Step(
    _StepId.accessibility,
    'Turn on scroll measuring',
    'An accessibility service measures how far you scroll and blurs apps once your limit is hit. It receives scroll '
        'distances and the name of the open app. It cannot read your screen.',
    'Open accessibility settings',
  ),
  _Step(
    _StepId.activity,
    'Count your walking',
    'Physical activity access lets the step sensor turn your walking into scrolling.',
    'Allow',
  ),
  _Step(
    _StepId.notifications,
    'Status notification',
    'A silent notification shows how much scrolling you have left and has the emergency pass button.',
    'Allow',
    optional: true,
  ),
  _Step(
    _StepId.battery,
    'Keep running in the background',
    'Exempt DoomWalk from battery optimisation so Android doesn\'t stop the tracker.',
    'Allow',
    optional: true,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  final Map<_StepId, bool> _done = {};
  Timer? _poll;
  bool _activityWasGranted = false;
  bool _loaded = false;

  bool _enabled = false;
  bool _stalled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DoomWalkController get _c => ref.read(controllerProvider);

  Future<void> _refresh() async {
    final st = await _c.refreshStatus();
    final activity = await Permission.activityRecognition.isGranted;
    final notif = await Permission.notification.isGranted;
    if (activity && !_activityWasGranted) {
      _activityWasGranted = true;
      unawaited(_c.startWalkTracking());
    }
    if (!mounted) return;
    setState(() {
      _loaded = true;
      // Done means running: Android can leave the service on but stopped
      _done[_StepId.accessibility] = st.serviceConnected;
      _enabled = st.accessibilityEnabled;
      _stalled = st.serviceStalled;
      _done[_StepId.restricted] =
          st.sdk < 33 ||
          st.accessibilityEnabled ||
          st.restrictedSettingsAllowed != false;
      _done[_StepId.activity] = activity;
      _done[_StepId.notifications] = notif;
      _done[_StepId.battery] = st.ignoringBatteryOptimizations;
    });
  }

  List<_Step> get _visible => _steps
      .where((s) => s.id != _StepId.restricted || _c.status.sdk >= 33)
      .toList();

  _Step? get _current {
    for (final s in _visible) {
      if (_done[s.id] != true) return s;
    }
    return null;
  }

  Future<void> _act(_Step s) async {
    final n = _c.native;
    switch (s.id) {
      case _StepId.restricted:
        await n.openAppDetails();
      case _StepId.accessibility:
        await n.openAccessibilitySettings();
      case _StepId.activity:
        final r = await Permission.activityRecognition.request();
        if (r.isPermanentlyDenied) await openAppSettings();
      case _StepId.notifications:
        final r = await Permission.notification.request();
        if (r.isPermanentlyDenied) await openAppSettings();
      case _StepId.battery:
        await n.requestIgnoreBatteryOptimizations();
    }
    await _refresh();
  }

  Future<void> _finish() async {
    await _c.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final current = _current;
    final steps = _visible;
    final doneCount = steps.where((s) => _done[s.id] == true).length;
    final canFinish = _enabled;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          children: [
            Row(
              children: [
                IconBadge(
                  size: 36,
                  background: context.colors.accentContainer,
                  child: DepthTicks(
                    size: 20,
                    color: context.colors.onAccentContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Text('DoomWalk', style: t.titleMedium),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              'Want to scroll? Take a walk first.',
              style: t.headlineLarge?.copyWith(
                fontSize: 34,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Walking fills a small bank of scrolling, and social apps spend it. It starts empty every day and '
              'holds up to ${formatRound(_c.bankCapM)}. Each metre of scrolling costs ${formatRound(_c.config.startPrice)} '
              'of walking at first, and more the more you scroll. Run out, and the apps lock until you go.',
              style: t.bodyLarge?.copyWith(color: context.colors.muted),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Text('Setup', style: t.titleSmall),
                const Spacer(),
                Text(
                  _loaded
                      ? '$doneCount of ${steps.length} done'
                      : 'Checking permissions',
                  style: t.bodySmall?.merge(numeric),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: _loaded && _done[steps[i].id] == true
                              ? context.colors.accent
                              : context.colors.raised2,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final s in _loaded ? steps : const <_Step>[])
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: identical(s, current)
                    ? _ActiveStep(
                        step: s,
                        onAct: () => _act(s),
                        why: s.id == _StepId.accessibility && _stalled
                            ? 'Scroll measuring is switched on, but Android isn\'t running it. In accessibility '
                                  'settings, switch DoomWalk off, then on again.'
                            : null,
                      )
                    : _StepRow(
                        step: s,
                        done: _done[s.id] == true,
                        onAct: () => _act(s),
                      ),
              ),
            const SizedBox(height: 24),
            if (!_loaded)
              const SizedBox.shrink()
            else if (canFinish && current == null)
              FilledButton(onPressed: _finish, child: const Text('Start'))
            else if (canFinish)
              OutlinedButton(
                onPressed: _finish,
                child: const Text('Continue without the rest'),
              )
            else
              Text(
                'Scroll measuring is the one step you can\'t skip.',
                style: t.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveStep extends StatelessWidget {
  const _ActiveStep({required this.step, required this.onAct, this.why});
  final _Step step;
  final VoidCallback onAct;

  final String? why;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.raised,
        borderRadius: BorderRadius.circular(Radii.surface),
        border: Border.all(color: context.colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(step.title, style: t.titleMedium)),
              if (step.optional) Text('Optional', style: t.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            why ?? step.why,
            style: t.bodyMedium?.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: onAct, child: Text(step.action)),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.done, required this.onAct});
  final _Step step;
  final bool done;
  final VoidCallback onAct;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.small),
      onTap: done ? null : onAct,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              done ? PhFill.checkCircle : Ph.circle,
              size: 22,
              color: done ? context.colors.accent : context.colors.faint,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                step.title,
                style: t.bodyLarge?.copyWith(
                  color: done ? context.colors.muted : context.colors.text,
                ),
              ),
            ),
            if (step.optional && !done) Text('Optional', style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}
