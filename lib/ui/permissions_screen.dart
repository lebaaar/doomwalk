import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/controller.dart';
import '../services/native_bridge.dart';
import 'icons.dart';
import 'providers.dart';
import 'theme.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  Timer? _poll;
  bool _activity = false;
  bool _notifications = false;
  bool _restarting = false;

  DoomWalkController get _c => ref.read(controllerProvider);

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

  Future<void> _refresh() async {
    final st = await _c.refreshStatus();
    final activity = await Permission.activityRecognition.isGranted;
    final notifications = await Permission.notification.isGranted;
    if (activity && !_activity) unawaited(_c.startWalkTracking());
    if (!mounted) return;
    setState(() {
      _activity = activity;
      _notifications = notifications;
      if (st.serviceConnected) _restarting = false;
    });
  }

  Future<void> _permission(Permission p, bool granted) async {
    if (!granted) {
      final r = await p.request();
      if (!r.isPermanentlyDenied) return _refresh();
    }
    await openAppSettings();
  }

  Future<void> _restart() async {
    setState(() => _restarting = true);
    final ok = await _c.restartScrollMeasuring();
    if (!ok) {
      setState(() => _restarting = false);
      await _c.native.openAccessibilitySettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    final st = c.status;
    final col = context.colors;
    final restricted = st.sdk >= 33;
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (st.serviceStalled)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gaps.margin,
                8,
                Gaps.margin,
                0,
              ),
              child: _StoppedCard(
                status: st,
                restarting: _restarting,
                onRestart: _restart,
              ),
            ),
          const SectionTitle('Required'),
          TileGroup(
            dividerIndent: 56,
            children: [
              _Row(
                state: st.serviceConnected
                    ? _State.ok
                    : st.accessibilityEnabled
                    ? _State.problem
                    : _State.off,
                title: 'Scroll measuring',
                subtitle: st.serviceConnected
                    ? 'On and running'
                    : st.accessibilityEnabled
                    ? 'On, but not running'
                    : 'Off. Nothing is measured or locked.',
                action: 'Accessibility',
                onTap: c.native.openAccessibilitySettings,
              ),
              if (restricted)
                _Row(
                  state: switch (st.restrictedSettingsAllowed) {
                    true => _State.ok,
                    false when !st.accessibilityEnabled => _State.problem,
                    _ => _State.neutral,
                  },
                  title: 'Restricted settings',
                  subtitle: switch (st.restrictedSettingsAllowed) {
                    true => 'Allowed',
                    false => 'Blocked. Needed to switch scroll measuring on.',
                    null => 'Android doesn\'t say. Only needed if scroll measuring can\'t be switched on.',
                  },
                  action: 'App info',
                  onTap: c.native.openAppDetails,
                ),
              _Row(
                state: _activity ? _State.ok : _State.problem,
                title: 'Physical activity',
                subtitle: _activity
                    ? 'Allowed. Steps earn you scrolling.'
                    : 'Not allowed. Walking isn\'t counted.',
                action: _activity ? 'App info' : 'Allow',
                onTap: () =>
                    _permission(Permission.activityRecognition, _activity),
              ),
            ],
          ),
          const SectionTitle('Recommended'),
          TileGroup(
            dividerIndent: 56,
            children: [
              _Row(
                state: _notifications ? _State.ok : _State.off,
                title: 'Notifications',
                subtitle: _notifications
                    ? 'Allowed'
                    : 'Off. No status notification or pass button.',
                action: _notifications ? 'App info' : 'Allow',
                onTap: () =>
                    _permission(Permission.notification, _notifications),
              ),
              _Row(
                state: st.ignoringBatteryOptimizations ? _State.ok : _State.off,
                title: 'Battery',
                subtitle: st.ignoringBatteryOptimizations
                    ? 'Unrestricted'
                    : 'Optimised. Android may stop tracking in the background.',
                action: 'Battery',
                onTap: c.native.requestIgnoreBatteryOptimizations,
              ),
            ],
          ),
          if (st.lastExit != null && !st.serviceStalled) ...[
            const SectionTitle('Last stop'),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gaps.margin + 4,
                0,
                Gaps.margin + 4,
                0,
              ),
              child: Text(
                'The app last stopped ${_when(st.lastExit!.time)} because ${st.lastExit!.label}.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: col.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _State { ok, problem, off, neutral }

class _Row extends StatelessWidget {
  const _Row({
    required this.state,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });
  final _State state;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final (IconData icon, Color color, String said) = switch (state) {
      _State.ok => (PhFill.checkCircle, col.accent, 'On'),
      _State.problem => (Ph.warningCircle, col.danger, 'Needs attention'),
      _State.off => (Ph.circle, col.faint, 'Off'),
      _State.neutral => (Ph.circle, col.faint, 'Unknown'),
    };
    return ListTile(
      onTap: onTap,
      leading: Semantics(
        label: said,
        child: Icon(icon, size: 24, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontSize: 13),
        ),
        onPressed: onTap,
        child: Text(action),
      ),
    );
  }
}

class _StoppedCard extends StatelessWidget {
  const _StoppedCard({
    required this.status,
    required this.restarting,
    required this.onRestart,
  });
  final NativeStatus status;
  final bool restarting;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final exit = status.lastExit;
    final why = exit == null
        ? 'This happens when the app\'s process ends unexpectedly.'
        : 'The app stopped ${_when(exit.time)} because ${exit.label}. When that happens Android '
              'treats scroll measuring as broken and won\'t start it again by itself.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Ph.warningCircle, size: 20, color: col.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Scroll measuring has stopped',
                    style: t.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'It\'s switched on in Settings, but Android isn\'t running it, so nothing is measured or locked. $why',
              style: t.bodyMedium?.copyWith(color: col.muted),
            ),
            const SizedBox(height: 16),
            if (status.canRestartService)
              FilledButton.icon(
                onPressed: restarting ? null : onRestart,
                icon: restarting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Ph.arrowCounterClockwise, size: 18),
                label: Text(
                  restarting ? 'Restarting' : 'Restart scroll measuring',
                ),
              )
            else ...[
              FilledButton(
                onPressed: onRestart,
                child: const Text('Open accessibility settings'),
              ),
              const SizedBox(height: 8),
              Text(
                'Switch DoomWalk off, then on again, and come back.',
                style: t.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _when(DateTime t) {
  final now = DateTime.now();
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final today = t.year == now.year && t.month == now.month && t.day == now.day;
  return today ? 'today at $hm' : 'on ${t.day}.${t.month}. at $hm';
}
