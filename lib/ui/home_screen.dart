import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_catalog.dart';
import '../core/landmarks.dart';
import '../core/units.dart';
import '../services/controller.dart';
import '../services/store.dart';
import 'altitude_gauge.dart';
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
    // Keeps the override countdown fresh.
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
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Header(c: c),
            if (!c.status.accessibilityEnabled) ...[
              const SizedBox(height: 8),
              Card(
                color: Palette.alpenglow.withValues(alpha: 0.14),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Palette.alpenglow),
                  title: const Text('Scroll measuring is off'),
                  subtitle: const Text('Time with tracking off is charged at your average scroll rate.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const OnboardingScreen(standalone: true))),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _ClimbCard(c: c),
            const SizedBox(height: 12),
            _StatsRow(c: c),
            const SizedBox(height: 12),
            _OverrideCard(c: c),
            const SizedBox(height: 20),
            Text('LANDMARKS', style: t.labelSmall),
            const SizedBox(height: 8),
            _LandmarkCard(c: c),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text('BY APP', style: t.labelSmall)),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Today')),
                    ButtonSegment(value: true, label: Text('7 days')),
                  ],
                  selected: {_week},
                  onSelectionChanged: (s) => setState(() => _week = s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _AppList(c: c, week: _week),
            const SizedBox(height: 20),
            Text('LEDGER', style: t.labelSmall),
            const SizedBox(height: 8),
            _LedgerCard(c: c),
            if (kDebugMode) ...[
              const SizedBox(height: 20),
              Text('DEBUG (not in release)', style: t.labelSmall),
              const SizedBox(height: 8),
              _DebugCard(c: c),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final ok = c.status.serviceConnected;
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Text('SCROLL DEBT', style: t.labelSmall?.copyWith(color: Palette.glacier, fontSize: 12)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: (ok ? Palette.moss : Palette.alpenglow).withValues(alpha: 0.12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 7, color: ok ? Palette.moss : Palette.alpenglow),
            const SizedBox(width: 5),
            Text(ok ? 'tracking' : 'paused',
                style: t.labelSmall?.copyWith(
                    letterSpacing: 0.5, color: ok ? Palette.moss : Palette.alpenglow)),
          ]),
        ),
        if (c.config.demoMode) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: Palette.summit.withValues(alpha: 0.15),
            ),
            child: Text('DEMO', style: t.labelSmall?.copyWith(color: Palette.summit, letterSpacing: 1)),
          ),
        ],
        const Spacer(),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
        ),
      ],
    );
  }
}

class _ClimbCard extends StatelessWidget {
  const _ClimbCard({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final debt = c.debtM;
    final frac = c.frostMaxDebtM <= 0 ? 0.0 : debt / c.frostMaxDebtM;
    final free = debt < 0.05;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 300,
        child: Stack(
          children: [
            Positioned.fill(child: AltitudeGauge(fraction: frac, frostMaxM: c.frostMaxDebtM)),
            Positioned(
              right: 16,
              bottom: 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(free ? 'AT BASE CAMP' : 'CURRENT CLIMB',
                      style: t.labelSmall?.copyWith(color: Palette.mist)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: debt),
                    duration: const Duration(milliseconds: 600),
                    builder: (_, v, _) => Text(
                      v >= 1000 ? (v / 1000).toStringAsFixed(2) : v.toStringAsFixed(1),
                      style: t.displayLarge?.copyWith(
                        color: free ? Palette.moss : Palette.summit,
                        fontWeight: FontWeight.w300,
                        height: 1,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                  Text(
                    free
                        ? 'debt-free · ${formatMetres(c.allowanceLeftM, decimals: 0)} of free scroll left today'
                        : '${debt >= 1000 ? 'km' : 'metres'} owed · walk it off to descend',
                    textAlign: TextAlign.end,
                    style: t.bodySmall?.copyWith(color: Palette.mist),
                  ),
                  const SizedBox(height: 8),
                  _FrostChip(level: c.frostLevel, shown: c.targetFrost),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrostChip extends StatelessWidget {
  const _FrostChip({required this.level, required this.shown});
  final double level;
  final double shown;

  @override
  Widget build(BuildContext context) {
    final pct = (level * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: Palette.glacier.withValues(alpha: 0.10 + 0.25 * level),
        border: Border.all(color: Palette.glacier.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.ac_unit_rounded, size: 14, color: Palette.glacier),
        const SizedBox(width: 6),
        Text('Frost $pct%',
            style: const TextStyle(color: Palette.glacier, fontSize: 12, fontFeatures: tabular)),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _Stat(label: 'SCROLLED', value: formatMetres(c.state.scrolledTodayM), sub: 'today')),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(
              label: 'WALKED',
              value: formatMetres(c.state.walkedTodayM),
              sub: c.walkError == null ? 'today' : 'step sensor off',
              color: Palette.moss,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(
              label: 'FREE LEFT',
              value: formatMetres(c.allowanceLeftM, decimals: 0),
              sub: 'of ${formatMetres(c.config.effective.allowanceM, decimals: 0)}',
              color: Palette.glacier,
            ),
          ),
        ],
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.sub, this.color = Palette.snow});
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.labelSmall?.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: t.titleLarge?.copyWith(color: color, fontFeatures: tabular, fontWeight: FontWeight.w500)),
          ),
          Text(sub, style: t.bodySmall?.copyWith(color: Palette.mist)),
        ]),
      ),
    );
  }
}

class _OverrideCard extends StatelessWidget {
  const _OverrideCard({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final active = c.overrideActive;
    final left = c.overridesLeft;
    final penalty = c.config.overridePenalty;
    String remaining() {
      final d = c.overrideUntil!.difference(DateTime.now());
      final s = d.inSeconds.clamp(0, 99999);
      return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }

    return Card(
      color: active ? Palette.alpenglow.withValues(alpha: 0.12) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(children: [
          Icon(Icons.emergency_outlined, color: active ? Palette.alpenglow : Palette.mist),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(active ? 'Emergency pass active · ${remaining()}' : 'Emergency pass',
                  style: t.titleSmall),
              Text(
                active
                    ? 'Frost lifted. Every metre costs ${penalty.toStringAsFixed(0)}×.'
                    : '$left left today · lifts the frost for ${c.config.overrideMinutes} min at ${penalty.toStringAsFixed(0)}× cost',
                style: t.bodySmall?.copyWith(color: Palette.mist),
              ),
            ]),
          ),
          if (active)
            TextButton(onPressed: c.endOverride, child: const Text('End'))
          else
            FilledButton.tonal(
              onPressed: left > 0 ? c.startOverride : null,
              child: const Text('Use'),
            ),
        ]),
      ),
    );
  }
}

class _LandmarkCard extends StatelessWidget {
  const _LandmarkCard({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (LandmarkTier.today, c.state.scrolledTodayM),
      (LandmarkTier.week, c.weekRawM),
      (LandmarkTier.lifetime, c.lifetimeRawM),
    ];
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          for (final (tier, m) in rows) ...[
            _LandmarkRow(tier: tier, metres: m),
            if (tier != LandmarkTier.lifetime) const SizedBox(height: 14),
          ],
          const SizedBox(height: 12),
          Text(
            'Lifetime: ${(c.lifetimeRawM / karman.heightM * 100).toStringAsFixed(c.lifetimeRawM < 1000 ? 3 : 1)}% of the way to space',
            style: t.bodySmall?.copyWith(color: Palette.mist),
          ),
        ]),
      ),
    );
  }
}

class _LandmarkRow extends StatelessWidget {
  const _LandmarkRow({required this.tier, required this.metres});
  final LandmarkTier tier;
  final double metres;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = progressToward(metres);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(tier.yardstick.glyph, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(describeTier(metres, tier), style: t.titleSmall)),
        Text(formatMetres(metres), style: t.bodySmall?.copyWith(color: Palette.mist, fontFeatures: tabular)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: p.fraction,
          minHeight: 5,
          backgroundColor: Palette.slate,
          color: Palette.glacier,
        ),
      ),
      const SizedBox(height: 3),
      Text('${(p.fraction * 100).toStringAsFixed(0)}% of the way to ${p.next.name} (${formatMetres(p.next.heightM, decimals: 0)})',
          style: t.bodySmall?.copyWith(color: Palette.mist, fontSize: 11)),
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
    final t = Theme.of(context).textTheme;
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No counted scrolling yet. Go open a feed; we\'ll be watching the distance, never the content.',
              style: t.bodyMedium?.copyWith(color: Palette.mist)),
        ),
      );
    }
    final max = rows.first.rawM;
    return Card(
      child: Column(children: [
        for (final r in rows.take(12)) _AppRow(c: c, row: r, max: max, week: week),
      ]),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.c, required this.row, required this.max, required this.week});
  final ScrollDebtController c;
  final AppTotals row;
  final double max;
  final bool week;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final icon = c.appMeta[row.pkg]?.icon;
    final rate = c.catalog.rateFor(row.pkg);
    return InkWell(
      onTap: () => showShareCard(context, c, row.pkg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: icon != null
                ? Image.memory(icon, width: 36, height: 36, gaplessPlayback: true)
                : Container(width: 36, height: 36, color: Palette.slate, child: const Icon(Icons.apps, size: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(c.labelFor(row.pkg), style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                _RateChip(rate: rate),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: max <= 0 ? 0 : row.rawM / max,
                  minHeight: 4,
                  backgroundColor: Palette.slate,
                  color: rate >= 2 ? Palette.summit : Palette.glacier,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatMetres(row.rawM), style: t.titleSmall?.copyWith(fontFeatures: tabular)),
            Text('+${formatMetres(row.chargedM)} debt',
                style: t.bodySmall?.copyWith(color: Palette.mist, fontSize: 11, fontFeatures: tabular)),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.ios_share_rounded, size: 16, color: Palette.mist),
        ]),
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({required this.rate});
  final double rate;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: (rate >= 2 ? Palette.summit : Palette.glacier).withValues(alpha: 0.14),
        ),
        child: Text(rateLabel(rate),
            style: TextStyle(fontSize: 11, color: rate >= 2 ? Palette.summit : Palette.glacier)),
      );
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = c.state;
    final cfg = c.config;
    Widget line(String a, String b, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(a, style: t.bodyMedium?.copyWith(color: Palette.mist))),
            Text(b, style: t.bodyMedium?.copyWith(color: color, fontFeatures: tabular)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          line('Charged today', '+${formatMetres(s.chargedTodayM)}', color: Palette.summit),
          line('Paid by walking today', '−${formatMetres(s.paidTodayM)}', color: Palette.moss),
          line('Overnight interest (${(cfg.interestRate * 100).toStringAsFixed(1)}%/night)',
              'last night +${formatMetres(s.lastInterestM)}'),
          line('Interest paid so far', formatMetres(s.interestTotalM)),
          line('Exchange rate', '1 m scrolled = ${cfg.effective.ratio.toStringAsFixed(1)} m walked'),
          if (s.tamperChargedTodayM > 0)
            line('Tracking-gap charges today', '+${formatMetres(s.tamperChargedTodayM)}', color: Palette.alpenglow),
          if (c.gaps.isNotEmpty) ...[
            const Divider(height: 20),
            Text('Tracking gaps (charged at your average ${formatMetres(c.averageScrollPerHour)}/h)',
                style: t.bodySmall?.copyWith(color: Palette.mist)),
            for (final g in c.gaps.take(3))
              line('${_fmt(g.start)} → ${_fmt(g.end)} · ${g.reason}', '+${formatMetres(g.chargedM)}',
                  color: Palette.alpenglow),
          ],
        ]),
      ),
    );
  }

  static String _fmt(DateTime t) =>
      '${t.day}.${t.month}. ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _DebugCard extends StatelessWidget {
  const _DebugCard({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in [5.0, 25.0, 100.0])
              OutlinedButton(
                onPressed: () => c.debugInjectWalk(m),
                child: Text('Walk +${m.toStringAsFixed(0)} m'),
              ),
            OutlinedButton(onPressed: c.resetAll, child: const Text('Reset all')),
          ]),
        ),
      );
}
