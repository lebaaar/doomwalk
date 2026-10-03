import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_catalog.dart';
import '../core/landmarks.dart';
import '../core/units.dart';
import '../services/controller.dart';
import '../services/store.dart';
import 'icons.dart';
import 'logo.dart';
import 'onboarding_screen.dart';
import 'providers.dart';
import 'settings_screen.dart';
import 'share_card.dart';
import 'theme.dart';

/// The app shell: Today, Activity and Settings in a Material navigation bar.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
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

  void _go(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    const titles = ['Today', 'Activity', 'Settings'];
    final still = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          if (c.config.demoMode)
            Padding(
              padding: const EdgeInsets.only(right: Gaps.margin),
              child: Chip(
                label: const Text('Demo mode'),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: context.colors.faint),
              ),
            ),
        ],
      ),
      // Tabs keep their scroll position; the incoming one fades in.
      body: TweenAnimationBuilder<double>(
        key: ValueKey(_tab),
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: IndexedStack(
          index: _tab,
          children: [
            _TodayTab(c: c, onOpenActivity: () => _go(1)),
            _ActivityTab(c: c),
            const SettingsScreen(embedded: true),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: DepthTicks(small: true), label: 'Today'),
          NavigationDestination(icon: Icon(Ph.chartBar), selectedIcon: Icon(PhFill.chartBar), label: 'Activity'),
          NavigationDestination(icon: Icon(Ph.gear), selectedIcon: Icon(PhFill.gear), label: 'Settings'),
        ],
      ),
    );
  }
}

Widget _page(List<Widget> children) => ListView(
      padding: const EdgeInsets.fromLTRB(Gaps.margin, 8, Gaps.margin, 24),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: Gaps.card),
          children[i],
        ],
      ],
    );

/// A filled Material card with 16 dp padding.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );
}

// ------------------------------------------------------------------ Today

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.c, required this.onOpenActivity});
  final ScrollDebtController c;
  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context) => _page([
        if (!c.status.accessibilityEnabled)
          const _Notice(
            title: 'Scroll measuring is off',
            body: 'Time without tracking is charged at your average scroll rate. Tap to turn it on.',
          ),
        if (c.walkError != null)
          const _Notice(
            title: 'Step counting is off',
            body: 'Walking won\'t pay your debt down until physical activity access is allowed.',
          ),
        _DebtCard(c: c),
        _WalkCard(c: c, onTap: onOpenActivity),
        _TopAppsCard(c: c, onSeeAll: onOpenActivity),
      ]);
}

/// A problem that blocks part of the loop. Opens setup to fix it.
class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    return Card(
      color: col.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.surface),
        side: BorderSide(color: col.danger.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const OnboardingScreen(standalone: true))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(Ph.warningCircle, color: col.danger),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: t.bodyMedium?.copyWith(color: col.muted)),
              ]),
            ),
            Icon(Ph.caretRight, size: 18, color: col.muted),
          ]),
        ),
      ),
    );
  }
}

/// "Instagram, TikTok and 2 more".
String _appList(ScrollDebtController c, List<String> pkgs) {
  final names = pkgs.map(c.labelFor).toList();
  if (names.isEmpty) return 'restricted apps';
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} and ${names[1]}';
  if (names.length == 3) return '${names[0]}, ${names[1]} and ${names[2]}';
  return '${names[0]}, ${names[1]} and ${names.length - 2} more';
}

/// The one question the app answers: how far do I have to walk?
class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final debt = c.debtM;
    final owed = debt >= 0.05;
    final active = c.overrideActive;
    final allowance = c.config.effective.allowanceM;

    final value = owed ? debt : c.allowanceLeftM;
    final km = value >= 1000;
    final label = owed ? 'To walk' : 'Free scrolling left today';
    final progress = owed
        ? c.frostLevel
        : (allowance <= 0 ? 0.0 : (c.allowanceLeftM / allowance).clamp(0.0, 1.0));
    final apps = c.frostedAppsToday;
    final caption = owed
        ? (active
            ? 'Frost lifted by your emergency pass.'
            : 'Frost ${(c.frostLevel * 100).round()}% on ${_appList(c, apps)}. Full at ${formatRound(c.frostMaxDebtM)}.')
        : 'of ${formatRound(allowance)}. After that, scrolling turns into walking.';

    return _Panel(
      onTap: () => showLedgerSheet(context, c),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: t.titleSmall?.copyWith(color: col.muted)),
        const SizedBox(height: 8),
        Semantics(
          label: owed
              ? '${formatMetres(debt)} to walk. Frost ${(c.frostLevel * 100).round()} percent.'
              : '${formatRound(c.allowanceLeftM)} of free scrolling left today.',
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: value),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  km ? (v / 1000).toStringAsFixed(2) : v.toStringAsFixed(owed ? 1 : 0),
                  style: t.displayLarge?.copyWith(color: owed ? col.accent : col.text, fontFeatures: tabular),
                ),
              ),
              const SizedBox(width: 6),
              Text(km ? 'km' : 'm', style: t.headlineSmall?.copyWith(color: col.muted)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ExcludeSemantics(child: LinearProgressIndicator(value: progress)),
        const SizedBox(height: 10),
        Text(caption, style: t.bodyMedium?.copyWith(color: col.muted)),
        if (owed) ...[
          const SizedBox(height: 16),
          _PassButton(c: c),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => showLedgerSheet(context, c),
            child: Text(owed ? 'How ${formatMetres(debt)} adds up' : 'How it works'),
          ),
        ),
      ]),
    );
  }
}

class _PassButton extends StatelessWidget {
  const _PassButton({required this.c});
  final ScrollDebtController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final penalty = c.config.overridePenalty.toStringAsFixed(0);
    if (c.overrideActive) {
      final s = c.overrideUntil!.difference(DateTime.now()).inSeconds.clamp(0, 99999);
      final left = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
      return Row(children: [
        Expanded(
          child: Text('Unfrozen for $left. Scrolling costs $penalty× until then.',
              style: t.bodyMedium?.merge(numeric)),
        ),
        const SizedBox(width: 12),
        OutlinedButton(onPressed: c.endOverride, child: const Text('End now')),
      ]);
    }
    final left = c.overridesLeft;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Tonal: a way out, not the main thing to do (that's walking).
      FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          backgroundColor: context.colors.accentContainer,
          foregroundColor: context.colors.onAccentContainer,
        ),
        onPressed: left > 0 ? c.startOverride : null,
        icon: const Icon(Ph.lifebuoy, size: 20),
        label: Text('Unfreeze for ${c.config.overrideMinutes} min'),
      ),
      const SizedBox(height: 6),
      Text(
        left > 0
            ? 'Scrolling costs $penalty× while unfrozen. $left ${left == 1 ? 'pass' : 'passes'} left today.'
            : 'No passes left today.',
        textAlign: TextAlign.center,
        style: t.bodySmall,
      ),
    ]);
  }
}

class _WalkCard extends StatelessWidget {
  const _WalkCard({required this.c, required this.onTap});
  final ScrollDebtController c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final goal = c.config.walkGoalM;
    return _Panel(
      onTap: onTap,
      child: Row(children: [
        Semantics(
          label: '${(c.goalProgress * 100).round()} percent of your walking goal',
          child: SizedBox.square(
            dimension: 56,
            child: Stack(fit: StackFit.expand, children: [
              CircularProgressIndicator(value: c.goalProgress, strokeWidth: 6, strokeCap: StrokeCap.round),
              Center(child: Icon(Ph.footprints, size: 22, color: context.colors.accent)),
            ]),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Walked ${formatMetres(c.state.walkedTodayM)}', style: t.titleMedium?.merge(numeric)),
            const SizedBox(height: 2),
            Text(
              c.walkError != null
                  ? 'Steps aren\'t being counted'
                  : 'of ${formatRound(goal)} goal · ${c.kcalToday.round()} kcal',
              style: t.bodyMedium?.copyWith(color: context.colors.muted),
            ),
          ]),
        ),
        Icon(Ph.caretRight, size: 18, color: context.colors.muted),
      ]),
    );
  }
}

class _TopAppsCard extends StatelessWidget {
  const _TopAppsCard({required this.c, required this.onSeeAll});
  final ScrollDebtController c;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = c.ranked(c.todayApps);
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Most scrolled today', style: t.titleMedium),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Nothing yet. Scrolling in other apps shows up here.',
                style: t.bodyMedium?.copyWith(color: context.colors.muted)),
          )
        else
          for (final r in rows.take(3)) _AppRow(c: c, row: r, max: rows.first.rawM, compact: true),
        if (rows.isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: onSeeAll,
            child: const Text('See all apps'),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Ledger

/// Bottom sheet that shows how the debt adds up, as a sum that ends at the
/// number on the Today card.
Future<void> showLedgerSheet(BuildContext context, ScrollDebtController c) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListenableBuilder(
          listenable: c,
          builder: (context, _) => LedgerView(c: c, scroll: scroll),
        ),
      ),
    );

class LedgerView extends StatelessWidget {
  const LedgerView({super.key, required this.c, this.scroll});
  final ScrollDebtController c;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final s = c.state;
    final cfg = c.config;
    Widget line(String a, String b, {bool strong = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(a, style: strong ? t.titleSmall : t.bodyLarge?.copyWith(color: col.muted))),
            Text(b, style: (strong ? t.titleSmall : t.bodyLarge)?.merge(numeric).copyWith(color: color ?? col.text)),
          ]),
        );
    final scrollChargedM = s.chargedTodayM - s.tamperChargedTodayM;
    final overM = s.scrolledTodayM - s.allowanceUsedM;
    final carriedM = s.debtM - s.chargedTodayM + s.paidTodayM;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Text('How ${formatMetres(s.debtM)} adds up', style: t.titleLarge),
        const SizedBox(height: 16),
        line('Scrolled today', formatMetres(s.scrolledTodayM)),
        line('Free scrolling', '−${formatMetres(s.allowanceUsedM)}'),
        line('Over the limit', formatMetres(overM)),
        Text(
          'Each metre over the limit is multiplied by the app\'s rate (shown next to each app), '
          'then by ${cfg.effective.ratio.toStringAsFixed(1)} to turn it into walking.',
          style: t.bodyMedium?.copyWith(color: col.muted),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 6),
        if (carriedM >= 0.05) line('Carried over from before', '+${formatMetres(carriedM)}'),
        line('Owed for scrolling', '+${formatMetres(scrollChargedM)}', color: col.accent),
        if (s.tamperChargedTodayM > 0)
          line('Owed for tracking gaps', '+${formatMetres(s.tamperChargedTodayM)}', color: col.accent),
        line('Walked off', '−${formatMetres(s.paidTodayM)}'),
        const Divider(),
        line('Left to walk', formatMetres(s.debtM), strong: true),
        const SizedBox(height: 20),
        Text('Overnight', style: t.titleSmall),
        const SizedBox(height: 4),
        Text(
          cfg.interestRate == 0
              ? 'Debt left at midnight carries over as it is.'
              : 'Debt left at midnight grows by ${(cfg.interestRate * 100).toStringAsFixed(1)}%.'
                  '${s.interestTotalM < 0.05 ? '' : ' Last night added ${formatMetres(s.lastInterestM)}, '
                      '${formatMetres(s.interestTotalM)} in total.'}',
          style: t.bodyMedium?.copyWith(color: col.muted),
        ),
        if (c.gaps.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Tracking gaps', style: t.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Time without scroll measuring is charged at your average of '
            '${formatMetres(c.averageScrollPerHour)} per hour.',
            style: t.bodyMedium?.copyWith(color: col.muted),
          ),
          for (final g in c.gaps.take(3))
            line('${_fmt(g.start)} to ${_fmt(g.end)}, ${g.reason}', '+${formatMetres(g.chargedM)}', color: col.accent),
        ],
      ],
    );
  }

  static String _fmt(DateTime t) =>
      '${t.day}.${t.month}. ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// --------------------------------------------------------------- Activity

class _ActivityTab extends StatefulWidget {
  const _ActivityTab({required this.c});
  final ScrollDebtController c;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  bool _week = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return _page([
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Today')),
          ButtonSegment(value: true, label: Text('Last 7 days')),
        ],
        selected: {_week},
        onSelectionChanged: (s) => setState(() => _week = s.first),
      ),
      _WalkingPanel(c: c, week: _week),
      _AppsPanel(c: c, week: _week),
      _LandmarksPanel(c: c, week: _week),
    ]);
  }
}

class _WalkingPanel extends StatelessWidget {
  const _WalkingPanel({required this.c, required this.week});
  final ScrollDebtController c;
  final bool week;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final goal = c.config.walkGoalM;
    final series = c.weekWalkSeries;
    final peak = [goal, ...series].reduce((a, b) => a > b ? a : b);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday; // 1 = Monday
    const barMax = 72.0;
    final goalY = peak <= 0 ? 0.0 : barMax * goal / peak;
    Widget fact(String value, String label) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: t.titleMedium?.merge(numeric)),
            Text(label, style: t.bodyMedium?.copyWith(color: col.muted)),
          ]),
        );
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Walking', style: t.titleMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(formatMetres(week ? c.weekWalkedM : c.state.walkedTodayM), style: t.headlineMedium?.merge(numeric)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(week ? 'in 7 days' : 'of ${formatRound(goal)} today',
                  style: t.bodyMedium?.copyWith(color: col.muted)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Seven days, oldest left. The dashed line is the daily goal.
        Semantics(
          label: 'Walking per day, last 7 days: '
              '${[for (var i = 0; i < 7; i++) formatRound(series[i])].join(', ')}. '
              'Goal ${formatRound(goal)}.',
          excludeSemantics: true,
          child: SizedBox(
            height: barMax + 40,
            child: Stack(children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 20 + goalY,
                child: Row(children: [
                  for (var x = 0; x < 40; x++)
                    Expanded(child: Container(height: 1, color: x.isEven ? col.faint : Colors.transparent)),
                ]),
              ),
              Positioned(right: 0, bottom: 24 + goalY, child: Text('goal', style: t.labelSmall)),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        height: peak <= 0 ? 4 : (barMax * series[i] / peak).clamp(4.0, barMax),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: series[i] >= goal ? col.accent : (i == 6 ? col.muted : col.raised2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(days[(today - 7 + i) % 7], style: t.labelSmall),
                    ]),
                  ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          fact('${(week ? c.kcalWeek : c.kcalToday).round()} kcal', 'burned walking'),
          fact('${c.streakDays} ${c.streakDays == 1 ? 'day' : 'days'}', 'goal streak'),
        ]),
        const SizedBox(height: 12),
        Text(
          'Calories are an estimate for walking at ${c.config.weightKg.toStringAsFixed(0)} kg.',
          style: t.bodySmall,
        ),
      ]),
    );
  }
}

class _AppsPanel extends StatelessWidget {
  const _AppsPanel({required this.c, required this.week});
  final ScrollDebtController c;
  final bool week;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = c.ranked(week ? c.weekApps : c.todayApps);
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Scrolling by app', style: t.titleMedium),
        const SizedBox(height: 2),
        Text(
          rows.isEmpty ? 'Nothing counted yet.' : 'Tap an app to share its card.',
          style: t.bodyMedium?.copyWith(color: context.colors.muted),
        ),
        const SizedBox(height: 4),
        for (final r in rows.take(12)) _AppRow(c: c, row: r, max: rows.first.rawM),
      ]),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.c, required this.row, required this.max, this.compact = false});
  final ScrollDebtController c;
  final AppTotals row;
  final double max;

  /// Today card: no bar, no share action.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final icon = c.appMeta[row.pkg]?.icon;
    final rate = c.catalog.rateFor(row.pkg);
    final label = c.labelFor(row.pkg);
    final free = row.chargedM < 0.05;
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.small),
        onTap: compact ? null : () => showShareCard(context, c, row.pkg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.small),
                child: icon != null
                    ? Image.memory(icon, width: 36, height: 36, gaplessPlayback: true)
                    : Container(
                        width: 36,
                        height: 36,
                        color: col.raised2,
                        child: Icon(Ph.squaresFour, size: 18, color: col.muted),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: t.bodyLarge, overflow: TextOverflow.ellipsis),
                  if (compact)
                    Text('${rateLabel(rate)} rate', style: t.bodySmall)
                  else ...[
                    const SizedBox(height: 6),
                    ExcludeSemantics(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: max <= 0 ? 0 : (row.rawM / max).clamp(0.02, 1.0),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(color: col.muted, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatMetres(row.rawM), style: t.bodyLarge?.merge(numeric)),
                Text(
                  free ? 'within free' : '+${formatMetres(row.chargedM)} owed',
                  style: t.bodySmall?.merge(numeric).copyWith(color: free ? col.muted : col.accent),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LandmarksPanel extends StatelessWidget {
  const _LandmarksPanel({required this.c, required this.week});
  final ScrollDebtController c;
  final bool week;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final metres = week ? c.weekRawM : c.state.scrolledTodayM;
    final tier = week ? LandmarkTier.week : LandmarkTier.today;
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How far that is', style: t.titleMedium),
        const SizedBox(height: 8),
        Text(tier.yardstick.count(metres), style: t.headlineMedium),
        Text(
          '${formatMetres(metres)} scrolled ${week ? 'in 7 days' : 'today'}.',
          style: t.bodyMedium?.copyWith(color: col.muted),
        ),
        const SizedBox(height: 12),
        Text(
          'All time: ${LandmarkTier.lifetime.yardstick.count(c.lifetimeRawM)}, '
          '${(c.lifetimeRawM / karman.heightM * 100).toStringAsFixed(c.lifetimeRawM < 1000 ? 2 : 1)}% of the way to space.',
          style: t.bodyMedium?.copyWith(color: col.muted),
        ),
      ]),
    );
  }
}
