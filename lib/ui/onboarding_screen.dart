import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/controller.dart';
import 'providers.dart';
import 'theme.dart';

enum _StepId { restricted, accessibility, activity, notifications, battery }

class _Step {
  const _Step(this.id, this.title, this.why, this.action, {this.optional = false});
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
    'Android 13+ blocks accessibility for sideloaded apps until you allow it. '
        'Open App info → ⋮ menu (top right) → "Allow restricted settings", then come back.',
    'Open App info',
  ),
  _Step(
    _StepId.accessibility,
    'Turn on scroll measuring',
    'An accessibility service measures how far you scroll and draws the frost. It only receives scroll '
        'distances and which app is open: it cannot read your screen.',
    'Open accessibility settings',
  ),
  _Step(
    _StepId.activity,
    'Count your walking',
    'Physical-activity access lets the step sensor pay your debt down in metres.',
    'Allow',
  ),
  _Step(
    _StepId.notifications,
    'Status notification',
    'A quiet notification shows your debt and holds the emergency pass button.',
    'Allow',
    optional: true,
  ),
  _Step(
    _StepId.battery,
    'Keep running in the background',
    'Exempt Scroll Debt from battery optimisation so Android doesn\'t stop the tracker.',
    'Allow',
    optional: true,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.standalone = false});

  /// Opened from settings (has a back button) rather than as the root.
  final bool standalone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with WidgetsBindingObserver {
  final Map<_StepId, bool> _done = {};
  Timer? _poll;
  bool _activityWasGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    // Live status: poll while visible so steps tick off the moment they're granted.
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

  ScrollDebtController get _c => ref.read(controllerProvider);

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
      _done[_StepId.accessibility] = st.accessibilityEnabled;
      // Restricted settings only matter on 13+ and only until accessibility is on.
      _done[_StepId.restricted] =
          st.sdk < 33 || st.accessibilityEnabled || st.restrictedSettingsAllowed != false;
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final current = _current;
    final steps = _visible;
    final doneCount = steps.where((s) => _done[s.id] == true).length;
    return Scaffold(
      appBar: widget.standalone ? AppBar(title: const Text('Setup')) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            if (!widget.standalone) ...[
              Text('SCROLL DEBT', style: t.labelSmall?.copyWith(color: Palette.glacier, fontSize: 12)),
              const SizedBox(height: 12),
              Text('Every metre you scroll,\nyou walk back.',
                  style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w300, height: 1.15)),
              const SizedBox(height: 10),
              Text(
                'Scroll Debt measures thumb travel across your apps in metres. Past your free allowance it becomes '
                'a debt, the apps frost over, and walking clears it. Everything stays on this phone.',
                style: t.bodyMedium?.copyWith(color: Palette.mist),
              ),
              const SizedBox(height: 24),
            ],
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: steps.isEmpty ? 1 : doneCount / steps.length,
                    minHeight: 6,
                    backgroundColor: Palette.slate,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$doneCount / ${steps.length}', style: t.bodySmall?.copyWith(color: Palette.mist)),
            ]),
            const SizedBox(height: 16),
            for (final s in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: _StepCard(
                    step: s,
                    done: _done[s.id] == true,
                    active: identical(s, current),
                    onAct: () => _act(s),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (_done[_StepId.accessibility] == true)
              FilledButton(
                onPressed: () async {
                  await _c.completeOnboarding();
                  if (widget.standalone && context.mounted) Navigator.of(context).pop();
                },
                child: Text(current == null ? 'Start climbing' : 'Continue without the rest'),
              )
            else
              Text('Scroll measuring is the one step that can\'t be skipped.',
                  textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: Palette.mist)),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.done, required this.active, required this.onAct});
  final _Step step;
  final bool done;
  final bool active;
  final VoidCallback onAct;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      color: active ? Palette.slate : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: active ? Palette.glacier.withValues(alpha: 0.6) : const Color(0x332E4A6B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
              done ? Icons.check_circle_rounded : (active ? Icons.radio_button_checked : Icons.radio_button_off),
              color: done ? Palette.moss : (active ? Palette.glacier : Palette.mist),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(step.title, style: t.titleMedium)),
            if (step.optional && !done) Text('optional', style: t.bodySmall?.copyWith(color: Palette.mist)),
          ]),
          if (active || !done) ...[
            const SizedBox(height: 8),
            Text(step.why, style: t.bodyMedium?.copyWith(color: Palette.mist)),
          ],
          if (!done) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: active
                  ? FilledButton(onPressed: onAct, child: Text(step.action))
                  : OutlinedButton(onPressed: onAct, child: Text(step.action)),
            ),
          ],
        ]),
      ),
    );
  }
}
