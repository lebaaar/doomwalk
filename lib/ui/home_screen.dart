import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_catalog.dart';
import '../core/landmarks.dart';
import '../core/units.dart';
import '../services/controller.dart';
import '../services/native_bridge.dart';
import '../services/store.dart';
import 'altitude_gauge.dart';
import 'icons.dart';
import 'onboarding_screen.dart';
import 'providers.dart';
import 'settings_screen.dart';
import 'share_card.dart';
import 'theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  bool _week = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keeps the emergency-pass countdown fresh.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (ref.read(controllerProvider).overrideActive && mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) ref.read(controllerProvider).refreshStatus();
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scroll Debt'),
        actions: [
          if (c.config.demoMode)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text('Demo', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.accent)),
              ),
            ),
          IconButton(
            tooltip: dark ? 'Light mode' : 'Dark mode',
            icon: Icon(dark ? Ph.sun : Ph.moon, size: 22),
            onPressed: () => c.setThemeMode(dark ? 'light' : 'dark'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Ph.slidersHorizontal, size: 22),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            if (!c.status.accessibilityEnabled) const _TrackingOff(),
            const SizedBox(height: 20),
            _Hero(c: c),
            const SizedBox(height: 20),
            _Gauge(c: c),
            const SizedBox(height: 24),
            _Stats(c: c),
            _EmergencyPass(c: c),
            const SectionTitle('Health'),
            _Health(c: c),
            const SectionTitle('Landmarks'),
            _Landmarks(c: c),
            SectionTitle(
              'By app',
              trailing: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Today')),
                  ButtonSegment(value: true, label: Text('7 days')),
                ],
                selected: {_week},
                onSelectionChanged: (s) => setState(() => _week = s.first),
              ),
            ),
            _AppList(c: c, week: _week),
            const SectionTitle('Ledger'),
            _Ledger(c: c),
            if (kDebugMode) ...[
              const SectionTitle('Debug build'),
              _DebugTools(c: c),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackingOff extends StatelessWidget {
  const _TrackingOff();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: context.colors.raised,
        borderRadius: BorderRadius.circular(Radii.surface),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.surface),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const OnboardingScreen(standalone: true))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Ph.warningCircle, color: context.colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Scroll measuring is off', style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text('Time without tracking is charged at your average scroll rate.', style: t.bodySmall),
                ]),
              ),
              Icon(Ph.caretRight, size: 18, color: context.colors.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final debt = c.debtM;
    final free = debt < 0.05;
    final km = debt >= 1000;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: debt),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              km ? (v / 1000).toStringAsFixed(2) : v.toStringAsFixed(1),
              style: t.displayLarge?.copyWith(
                fontSize: 76,
                color: free ? context.colors.text : context.colors.accent,
                fontFeatures: tabular,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(km ? 'km' : 'm', style: t.headlineMedium?.copyWith(color: context.colors.muted)),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        free
            ? 'Nothing owed. ${formatMetres(c.allowanceLeftM, decimals: 0)} of free scrolling left today.'
            : 'to walk before the frost lifts. About ${c.debtKcal.round()} kcal.',
        style: t.bodyLarge?.copyWith(color: context.colors.muted),
      ),
    ]);
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final frac = c.frostMaxDebtM <= 0 ? 0.0 : c.debtM / c.frostMaxDebtM;
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.surface),
        child: SizedBox(height: 196, child: AltitudeGauge(fraction: frac, frostMaxM: c.frostMaxDebtM)),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Icon(Ph.snowflake, size: 16, color: context.colors.muted),
        const SizedBox(width: 6),
        Text('Frost ${(c.frostLevel * 100).round()}%', style: t.bodySmall?.merge(numeric)),
        const Spacer(),
        Text(
          c.status.serviceConnected ? 'Tracking' : 'Not tracking',
          style: t.bodySmall?.copyWith(color: c.status.serviceConnected ? context.colors.muted : context.colors.accent),
        ),
      ]),
    ]);
  }
}

/// Walking as exercise, independent of debt: goal, calories, streak and
/// the last seven days.
class _Health extends StatelessWidget {
  const _Health({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final goal = c.config.walkGoalM;
    final series = c.weekWalkSeries;
    final peak = [goal, ...series].reduce((a, b) => a > b ? a : b);
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday; // 1 = Monday
    Widget fact(IconData icon, String value, String label) => Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: col.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: numeric.copyWith(fontSize: 16, color: col.text)),
                Text(label, style: t.bodySmall),
              ]),
            ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(formatMetres(c.state.walkedTodayM), style: t.headlineMedium?.merge(numeric)),
          const SizedBox(width: 8),
          Text('of ${formatMetres(goal, decimals: 0)} walked today', style: t.bodyMedium?.copyWith(color: col.muted)),
        ],
      ),
      const SizedBox(height: 16),
      // Seven days, oldest left. The dashed line is the daily goal.
      SizedBox(
        height: 96,
        child: LayoutBuilder(builder: (context, box) {
          final goalY = peak <= 0 ? 0.0 : 72 * goal / peak;
          return Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 20 + goalY,
              child: Row(children: [
                for (var x = 0; x < 40; x++)
                  Expanded(child: Container(height: 1, color: x.isEven ? col.faint : Colors.transparent)),
              ]),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Container(
                      height: peak <= 0 ? 2 : (72 * series[i] / peak).clamp(2.0, 72.0),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: series[i] >= goal
                            ? col.accent
                            : (i == 6 ? col.text.withValues(alpha: 0.75) : col.muted.withValues(alpha: 0.45)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(days[(today - 7 + i) % 7], style: t.bodySmall?.copyWith(fontSize: 11)),
                  ]),
                ),
            ]),
          ]);
        }),
      ),
      const SizedBox(height: 16),
      Row(children: [
        fact(Ph.fire, '${c.kcalToday.round()} kcal', 'burned today'),
        fact(Ph.lightning, '${c.kcalWeek.round()} kcal', 'last 7 days'),
        fact(Ph.target, '${c.streakDays} ${c.streakDays == 1 ? 'day' : 'days'}', 'goal streak'),
      ]),
      const SizedBox(height: 10),
      Text(
        'Calories are an estimate for walking at ${c.config.weightKg.toStringAsFixed(0)} kg. '
        'Set your weight and goal in Settings.',
        style: t.bodySmall,
      ),
    ]);
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget stat(String value, String label) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: numeric.copyWith(fontSize: 20, color: context.colors.text)),
            ),
            const SizedBox(height: 4),
            Text(label, style: t.bodySmall),
          ]),
        );

    return Column(children: [
      const Divider(),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          stat(formatMetres(c.state.scrolledTodayM), 'scrolled today'),
          stat(formatMetres(c.state.walkedTodayM), c.walkError == null ? 'walked today' : 'step sensor off'),
          stat(formatMetres(c.allowanceLeftM, decimals: 0),
              'free of ${formatMetres(c.config.effective.allowanceM, decimals: 0)}'),
        ]),
      ),
      const Divider(),
    ]);
  }
}

class _EmergencyPass extends StatelessWidget {
  const _EmergencyPass({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final active = c.overrideActive;
    final left = c.overridesLeft;
    final penalty = c.config.overridePenalty.toStringAsFixed(0);
    String remaining() {
      final s = c.overrideUntil!.difference(DateTime.now()).inSeconds.clamp(0, 99999);
      return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Icon(Ph.lifebuoy, color: active ? context.colors.accent : context.colors.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(active ? 'Emergency pass, ${remaining()} left' : 'Emergency pass', style: t.titleSmall),
              const SizedBox(height: 2),
              Text(
                active
                    ? 'Frost lifted. Scrolling costs $penalty× until it ends.'
                    : 'Lifts the frost for ${c.config.overrideMinutes} minutes at $penalty× cost. $left left today.',
                style: t.bodySmall,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          if (active)
            OutlinedButton(onPressed: c.endOverride, child: const Text('End'))
          else
            OutlinedButton(onPressed: left > 0 ? c.startOverride : null, child: const Text('Use')),
        ]),
      ),
      const Divider(),
    ]);
  }
}

class _Landmarks extends StatelessWidget {
  const _Landmarks({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final today = c.state.scrolledTodayM;
    final next = progressToward(today);
    Widget line(String text, double metres) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Expanded(child: Text(text, style: t.bodyMedium)),
            Text(formatMetres(metres), style: t.bodySmall?.merge(numeric)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(LandmarkTier.today.yardstick.count(today), style: t.headlineMedium),
      const SizedBox(height: 4),
      Text(
        'scrolled today. ${(next.fraction * 100).toStringAsFixed(0)}% of the way to '
        '${next.next == eiffel ? 'the first one' : 'the ${next.next.name}'}.',
        style: t.bodySmall,
      ),
      const SizedBox(height: 8),
      line('${LandmarkTier.week.yardstick.count(c.weekRawM)} in 7 days', c.weekRawM),
      line('${LandmarkTier.lifetime.yardstick.count(c.lifetimeRawM)} all time', c.lifetimeRawM),
      const SizedBox(height: 12),
      Text(
        '${(c.lifetimeRawM / karman.heightM * 100).toStringAsFixed(c.lifetimeRawM < 1000 ? 3 : 1)}% of the way '
        'to space (the Kármán line, 100 km up).',
        style: t.bodySmall,
      ),
    ]);
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.c, required this.week});
  final ScrollDebtController c;
  final bool week;

  @override
  Widget build(BuildContext context) {
    final rows = c.ranked(week ? c.weekApps : c.todayApps);
    if (rows.isEmpty) {
      return Text(
        'Nothing counted yet. Scrolling in other apps shows up here, per app.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.muted),
      );
    }
    final max = rows.first.rawM;
    final shown = rows.take(12).toList();
    return Column(children: [
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const Divider(indent: 48),
        _AppRow(c: c, row: shown[i], max: max),
      ],
    ]);
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.c, required this.row, required this.max});
  final ScrollDebtController c;
  final AppTotals row;
  final double max;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final icon = c.appMeta[row.pkg]?.icon;
    final rate = c.catalog.rateFor(row.pkg);
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.small),
      onTap: () => showShareCard(context, c, row.pkg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.small),
            child: icon != null
                ? Image.memory(icon, width: 32, height: 32, gaplessPlayback: true)
                : Container(
                    width: 32,
                    height: 32,
                    color: context.colors.raised2,
                    child: Icon(Ph.squaresFour, size: 16, color: context.colors.muted),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(c.labelFor(row.pkg), style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(rateLabel(rate), style: t.bodySmall?.merge(numeric)),
              ]),
              const SizedBox(height: 8),
              // Bar without a track: its length alone carries the comparison.
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: max <= 0 ? 0 : (row.rawM / max).clamp(0.02, 1.0),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: context.colors.muted.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatMetres(row.rawM), style: numeric.copyWith(fontSize: 14, color: context.colors.text)),
            const SizedBox(height: 2),
            Text(
              row.chargedM < 0.05 ? 'free' : '+${formatMetres(row.chargedM)}',
              style: numeric.copyWith(fontSize: 12, color: row.chargedM < 0.05 ? context.colors.faint : context.colors.accent),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = c.state;
    final cfg = c.config;
    Widget line(String a, String b, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(a, style: t.bodyMedium?.copyWith(color: context.colors.muted))),
            Text(b, style: numeric.copyWith(fontSize: 14, color: color ?? context.colors.text)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      line('Charged today', '+${formatMetres(s.chargedTodayM)}', color: context.colors.accent),
      line('Walked off today', '−${formatMetres(s.paidTodayM)}'),
      if (s.tamperChargedTodayM > 0)
        line('Charged for tracking gaps', '+${formatMetres(s.tamperChargedTodayM)}', color: context.colors.accent),
      const SizedBox(height: 8),
      const Divider(),
      const SizedBox(height: 8),
      line('Overnight interest', '${(cfg.interestRate * 100).toStringAsFixed(1)}% per night'),
      line('Interest last night', '+${formatMetres(s.lastInterestM)}'),
      line('Interest so far', formatMetres(s.interestTotalM)),
      line('Exchange rate', '1 m scrolled = ${cfg.effective.ratio.toStringAsFixed(1)} m walked'),
      if (c.gaps.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'Tracking gaps, charged at your average of ${formatMetres(c.averageScrollPerHour)} per hour',
          style: t.bodySmall,
        ),
        for (final g in c.gaps.take(3))
          line('${_fmt(g.start)} to ${_fmt(g.end)}, ${g.reason}', '+${formatMetres(g.chargedM)}',
              color: context.colors.accent),
      ],
    ]);
  }

  static String _fmt(DateTime t) =>
      '${t.day}.${t.month}. ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _DebugTools extends StatefulWidget {
  const _DebugTools({required this.c});
  final ScrollDebtController c;

  @override
  State<_DebugTools> createState() => _DebugToolsState();
}

/// Debug builds only: fake scrolling in any app and fake walking, both
/// through the same pricing path as the real sensors.
class _DebugToolsState extends State<_DebugTools> {
  late final Future<List<AppMeta>> _apps;
  String? _pkg;

  @override
  void initState() {
    super.initState();
    _apps = widget.c.launchableApps().catchError((Object _) => <AppMeta>[]);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final t = Theme.of(context).textTheme;
    return FutureBuilder<List<AppMeta>>(
      future: _apps,
      builder: (context, snap) {
        final apps = (snap.data ?? const <AppMeta>[]).where((a) => !c.catalog.isExempt(a.pkg)).toList()
          ..sort((a, b) {
            final r = (c.catalog.isRestricted(b.pkg) ? 1 : 0) - (c.catalog.isRestricted(a.pkg) ? 1 : 0);
            return r != 0 ? r : a.label.toLowerCase().compareTo(b.label.toLowerCase());
          });
        final pkg = _pkg ?? (apps.isNotEmpty ? apps.first.pkg : null);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add scrolling to an app', style: t.bodyMedium),
          const SizedBox(height: 8),
          if (apps.isEmpty)
            Text('Loading apps…', style: t.bodySmall)
          else
            DropdownButtonFormField<String>(
              initialValue: pkg,
              isExpanded: true,
              icon: Icon(Ph.caretDown, size: 16, color: context.colors.muted),
              dropdownColor: context.colors.raised2,
              borderRadius: BorderRadius.circular(Radii.small),
              items: [
                for (final a in apps)
                  DropdownMenuItem(
                    value: a.pkg,
                    child: Text('${a.label}  ${rateLabel(c.catalog.rateFor(a.pkg))}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _pkg = v),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in [1.0, 10.0, 50.0])
              OutlinedButton(
                onPressed: pkg == null ? null : () => c.debugInjectScroll(pkg, m),
                child: Text('Scroll ${m.toStringAsFixed(0)} m'),
              ),
          ]),
          const SizedBox(height: 20),
          Text('Pay it back', style: t.bodyMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in [5.0, 25.0, 100.0])
              OutlinedButton(onPressed: () => c.debugInjectWalk(m), child: Text('Walk ${m.toStringAsFixed(0)} m')),
            OutlinedButton(onPressed: c.resetAll, child: const Text('Reset')),
          ]),
        ]);
      },
    );
  }
}
