import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_catalog.dart';
import '../core/landmarks.dart';
import '../core/units.dart';
import '../services/controller.dart';
import '../services/store.dart';
import 'icons.dart';
import 'landmark_art.dart';
import 'price_table.dart';
import 'logo.dart';
import 'permissions_screen.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _tab = 0;
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) ref.read(controllerProvider).refreshStatus();
  }

  @override
  void dispose() {
    _fade.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Taps on the Settings title; 20 in a row unlock the developer options
  /// in a release build. A pause of 3 s starts the count again.
  int _titleTaps = 0;
  DateTime _lastTitleTap = DateTime.fromMillisecondsSinceEpoch(0);
  static const _tapsToUnlock = 20;

  void _onTitleTap() {
    final c = ref.read(controllerProvider);
    if (_tab != 2 || c.developerAvailable) return;
    final now = DateTime.now();
    if (now.difference(_lastTitleTap) > const Duration(seconds: 3)) _titleTaps = 0;
    _lastTitleTap = now;
    if (++_titleTaps < _tapsToUnlock) return;
    _titleTaps = 0;
    unawaited(c.unlockDeveloperOptions());
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Developer options enabled'), duration: Duration(seconds: 2)));
  }

  void _go(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (!MediaQuery.of(context).disableAnimations) _fade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    const titles = ['Today', 'Activity', 'Settings'];
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTitleTap,
          child: Text(titles[_tab]),
        ),
      ),
      // Tabs keep their state and scroll position (the stack is never
      // rebuilt from scratch); the incoming one fades in.
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
        child: IndexedStack(
          index: _tab,
          children: [
            _TodayTab(c: c, onOpenActivity: () => _go(1)),
            _ActivityTab(c: c),
            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.hairline))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _go,
          destinations: const [
            NavigationDestination(icon: DepthTicks(small: true), label: 'Today'),
            NavigationDestination(icon: Icon(Ph.chartBar), selectedIcon: Icon(PhFill.chartBar), label: 'Activity'),
            NavigationDestination(icon: Icon(Ph.gear), selectedIcon: Icon(PhFill.gear), label: 'Settings'),
          ],
        ),
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

/// A hairline-bordered card with 18 dp padding (20 at the sides).
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 18), child: child),
      );
}

// ------------------------------------------------------------------ Today

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.c, required this.onOpenActivity});
  final DoomWalkController c;
  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          if (!c.status.accessibilityEnabled)
            const _Notice(
              title: 'Scroll measuring is off',
              body: 'Time without tracking is charged at your average scroll rate. Tap to turn it on.',
            )
          else if (!c.status.serviceConnected)
            const _Notice(
              title: 'Scroll measuring has stopped',
              body: 'It\'s switched on but Android stopped it, so no app gets locked. Tap to see why and restart it.',
            ),
          if (c.walkError != null)
            const _Notice(
              title: 'Step counting is off',
              body: 'Walking won\'t earn scrolling until physical activity access is allowed.',
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.margin),
            child: _TodayCard(c: c, onOpenActivity: onOpenActivity),
          ),
          const SectionTitle('Today\'s climb'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.margin),
            child: _Climb(c: c),
          ),
          SectionTitle(
            'Most scrolled today',
            action: c.todayApps.isEmpty ? null : 'See all',
            onAction: onOpenActivity,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.margin),
            child: _TopAppsCard(c: c),
          ),
        ],
      );
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.margin, 0, Gaps.margin, Gaps.card),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen())),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Ph.warningCircle, size: 20, color: col.danger),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, style: t.bodyMedium?.copyWith(color: col.muted)),
                  const SizedBox(height: 8),
                  Text('Open permissions', style: t.labelLarge?.copyWith(color: col.text)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Where today stands, from most to least urgent.
enum _Verdict { walk, unfrozen, empty, full, low, ok }

/// The one card that answers "what now?": today's steps up top, and under
/// them the bank they filled, how full it is, what a step buys right now and
/// what to do next.
class _TodayCard extends StatefulWidget {
  const _TodayCard({required this.c, required this.onOpenActivity});
  final DoomWalkController c;
  final VoidCallback onOpenActivity;

  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keeps the emergency-pass countdown fresh. Only this card rebuilds.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.c.overrideActive && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final owed = c.overdraftM >= 0.05;
    final pass = c.overrideActive;
    final verdict = pass
        ? _Verdict.unfrozen
        : owed
            ? _Verdict.walk
            : c.bankM < 0.5
                ? _Verdict.empty
                : c.bankFull
                    ? _Verdict.full
                    : (c.bankM / c.bankCapM <= 0.25 ? _Verdict.low : _Verdict.ok);

    // Frozen turns the card deep navy in both modes; otherwise it is a plain
    // card.
    final fg = owed ? col.onHero : col.text;
    final muted = owed ? col.onHeroMuted : col.muted;
    final steps = c.stepsToday;
    final goalSub = c.walkError != null
        ? 'Steps aren\'t counted yet'
        : '${(c.goalProgress * 100).round()}% of ${formatCount(c.stepGoal)} goal · ${formatMetres(c.state.walkedTodayM)}';

    // A flat fill lit from the top corner by a soft glow: strong navy while
    // frozen, a plain card with a hint of frost otherwise.
    final glow = owed ? col.heroTo : col.calmTo;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.surface + 4),
        color: owed ? col.heroFrom : col.calmFrom,
        border: Border.all(color: owed ? col.heroTo.withValues(alpha: 0.22) : col.hairline),
      ),
      child: Material(
        type: MaterialType.transparency,
        // The glow sits on the fill; a gradient in the same decoration
        // would replace the colour instead of lighting it.
        child: Ink(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.0, -1.1),
              radius: 1.25,
              colors: [glow.withValues(alpha: owed ? 0.34 : 0.10), glow.withValues(alpha: 0)],
            ),
          ),
          child: InkWell(
            onTap: () => showLedgerSheet(context, c),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(
                  label: '${formatCount(steps)} steps today. $goalSub',
                  excludeSemantics: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Ph.footprints, size: 18, color: owed ? fg : col.accent),
                      const SizedBox(width: 8),
                      Text('Steps today',
                          style: t.labelLarge?.copyWith(color: owed ? fg : col.accent, fontSize: 14)),
                    ]),
                    const SizedBox(height: 14),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: steps.toDouble()),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Text(
                        formatCount(v.round()),
                        style: t.displayLarge
                            ?.copyWith(color: fg, fontSize: 72, letterSpacing: -3.6, fontFeatures: tabular),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(goalSub, style: t.bodyMedium?.merge(numeric).copyWith(color: muted)),
                  ]),
                ),
                const SizedBox(height: 22),
                _BankBlock(c: c, verdict: verdict, fg: fg, muted: muted),
                const SizedBox(height: 18),
                _Tally(c: c, fg: fg, muted: muted, onOpenActivity: widget.onOpenActivity),
                if (owed || pass) ...[
                  const SizedBox(height: 18),
                  _PassButton(c: c, fg: fg, muted: muted),
                ],
                const SizedBox(height: 6),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: fg,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    textStyle: t.labelLarge?.copyWith(fontSize: 14),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: Icon(Ph.caretRight, size: 14, color: muted),
                  onPressed: () => showLedgerSheet(context, c),
                  label: const Text('How it works'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

String _countdown(DoomWalkController c) {
  final s = c.overrideUntil!.difference(DateTime.now()).inSeconds.clamp(0, 99999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// The bank under today's steps: what a step buys now, how full it is, how
/// far you can scroll and what to do next.
class _BankBlock extends StatelessWidget {
  const _BankBlock({required this.c, required this.verdict, required this.fg, required this.muted});
  final DoomWalkController c;
  final _Verdict verdict;
  final Color fg;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final owed = verdict == _Verdict.walk;
    final bank = c.bankM;
    final cap = c.bankCapM;
    final stride = c.config.strideM;
    final price = c.priceNow;
    final unlockM = c.unlockChunkM;
    final unlockWalk = c.walkToUnlock(unlockM);
    final line = switch (verdict) {
      _Verdict.walk => c.status.serviceConnected
          ? 'All apps that count are locked. ${stepsText(unlockWalk, stride)} '
              '(${walkMinutes(unlockWalk)}) unlock ${formatRound(unlockM)}.'
          : '${stepsText(unlockWalk, stride)} unlock ${formatRound(unlockM)}. '
              'Locking is paused while scroll measuring is off.',
      _Verdict.unfrozen => 'Unlocked for ${_countdown(c)}. Scrolling during the pass is free.',
      _Verdict.empty =>
        'Take a walk: ${stepsText(unlockWalk, stride)} (${walkMinutes(unlockWalk)}) put ${formatRound(unlockM)} in.',
      _Verdict.full => 'Bank full. Walking adds nothing until you scroll some.',
      _Verdict.low || _Verdict.ok =>
        'You can scroll ${formatRound(bank)}. ${stepsText(c.walkToUnlock(cap), stride)} fill it up.',
    };
    // The multiplier: tinted once it has risen above the day's start.
    final dear = price > c.config.startPrice;
    final chipFg = owed ? fg : (dear ? col.onAccent : col.onAccentContainer);
    final chipBg = owed ? fg.withValues(alpha: 0.14) : (dear ? col.accent : col.accentContainer);
    final per = formatMetres(1 / price, decimals: price == 1 ? 0 : 2);
    return Semantics(
      label: 'In the bank: ${formatRound(bank)} of ${formatRound(cap)}. Walking costs ${formatTimes(price)}. $line',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('In the bank', style: t.titleSmall?.copyWith(color: fg)),
          const Spacer(),
          Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 5),
            message: 'Right now 1 m walked adds $per of scrolling. '
                'Every ${formatRound(c.config.priceStepM)} you scroll today it goes up a tier: '
                '${tiersText(c.config.priceTiers)}.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Ph.footprints, size: 14, color: chipFg),
                const SizedBox(width: 6),
                Text('${formatTimes(price)} walk',
                    style: t.labelMedium?.merge(numeric).copyWith(color: chipFg, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: cap <= 0 ? 0.0 : (bank / cap).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 10,
              color: owed ? fg : col.accent,
              backgroundColor: owed ? fg.withValues(alpha: 0.14) : col.raised2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(formatRound(bank), style: t.titleLarge?.merge(numeric).copyWith(color: fg)),
          const SizedBox(width: 4),
          Text('of ${formatRound(cap)}', style: t.bodyMedium?.merge(numeric).copyWith(color: muted)),
          if (owed) ...[
            const Spacer(),
            Text('${formatRound(c.overdraftM)} owed', style: t.bodyMedium?.merge(numeric).copyWith(color: fg)),
          ],
        ]),
        const SizedBox(height: 6),
        Text(line, style: t.bodyLarge?.copyWith(color: muted, height: 1.45)),
      ]),
    );
  }
}

/// All-time steps and scrolled today, side by side between two hairlines.
class _Tally extends StatelessWidget {
  const _Tally({required this.c, required this.fg, required this.muted, required this.onOpenActivity});
  final DoomWalkController c;
  final Color fg;
  final Color muted;
  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = c.state;
    final line = fg.withValues(alpha: 0.10);
    Widget stat(String label, String value, String sub, {VoidCallback? onTap, bool first = false}) => Expanded(
          child: MergeSemantics(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(first ? 0 : 16, 14, 8, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: t.bodySmall?.copyWith(color: muted)),
                  const SizedBox(height: 4),
                  Text(value, style: t.titleLarge?.merge(numeric).copyWith(color: fg)),
                  const SizedBox(height: 2),
                  Text(sub, style: t.bodySmall?.merge(numeric).copyWith(color: muted)),
                ]),
              ),
            ),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: line))),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          stat(
            'All-time steps',
            formatCount(c.stepsLifetime),
            formatMetres(s.lifetimeWalkedM),
            onTap: onOpenActivity,
            first: true,
          ),
          VerticalDivider(width: 1, thickness: 1, color: line),
          stat('Scrolled today', formatMetres(s.scrolledTodayM), nearestText(s.scrolledTodayM)),
        ]),
      ),
    );
  }
}

class _PassButton extends StatelessWidget {
  const _PassButton({required this.c, required this.fg, required this.muted});
  final DoomWalkController c;
  final Color fg;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (c.overrideActive) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: fg, side: BorderSide(color: fg.withValues(alpha: 0.4))),
          onPressed: c.endOverride,
          child: const Text('End pass now'),
        ),
      );
    }
    final left = c.overridesLeft;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Tonal: a way out, not the main thing to do (that's walking).
      FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          backgroundColor: fg.withValues(alpha: 0.10),
          foregroundColor: fg,
          disabledBackgroundColor: fg.withValues(alpha: 0.05),
          disabledForegroundColor: muted,
          side: BorderSide(color: fg.withValues(alpha: 0.08)),
        ),
        onPressed: left > 0 ? c.startOverride : null,
        icon: const Icon(Ph.lifebuoy, size: 20),
        label: Text('Unlock for ${c.config.overrideMinutes} min'),
      ),
      const SizedBox(height: 8),
      Text(
        left > 0
            ? 'You have $left ${left == 1 ? 'pass' : 'passes'} left for emergency dopamine hits.'
            : 'No passes left today.',
        textAlign: TextAlign.start,
        style: t.bodySmall?.merge(numeric).copyWith(color: muted),
      ),
    ]);
  }
}

class _TopAppsCard extends StatelessWidget {
  const _TopAppsCard({required this.c});
  final DoomWalkController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = c.ranked(c.todayApps);
    return _Panel(
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Nothing yet. Scrolling in other apps shows up here.',
                  style: t.bodyMedium?.copyWith(color: context.colors.muted)),
            )
          : Column(children: [
              for (final r in rows.take(3)) _AppRow(c: c, row: r, max: rows.first.rawM, compact: true),
            ]),
    );
  }
}

// ---------------------------------------------------------------- Ledger

/// Bottom sheet that explains the rules with today's numbers: the bank,
/// its cap and the price that rises as you scroll.
Future<void> showLedgerSheet(BuildContext context, DoomWalkController c) => showModalBottomSheet<void>(
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
  final DoomWalkController c;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final s = c.state;
    final cfg = c.config;
    Widget rule(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: col.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: t.bodyLarge?.copyWith(height: 1.4))),
          ]),
        );
    Widget line(String a, String b, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(a, style: strong ? t.titleSmall : t.bodyLarge?.copyWith(color: col.muted))),
            Text(b, style: (strong ? t.titleSmall : t.bodyLarge)?.merge(numeric)),
          ]),
        );
    final owed = c.overdraftM >= 0.05;
    return ListView(
      controller: scroll,
      // Edge to edge: clear the navigation bar (three-button nav is tall).
      padding: EdgeInsets.fromLTRB(24, 0, 24, 32 + MediaQuery.viewPaddingOf(context).bottom),
      children: [
        Text('How it works', style: t.titleLarge),
        const SizedBox(height: 8),
        rule(Ph.footprints, 'Walking fills your bank. It starts empty each day and holds up to ${formatRound(cfg.bankCapM)}.'),
        rule(Ph.squaresFour, 'Scrolling spends it. When it\'s empty, apps lock until you walk.'),
        rule(Ph.lightning, 'The more you scroll today, the more walking each metre costs:'),
        const SizedBox(height: 4),
        PriceTable(config: c.config, currentPrice: c.priceNow),
        const SizedBox(height: 4),
        rule(Ph.lifebuoy, '${cfg.overridesPerDay} emergency passes a day, ${cfg.overrideMinutes} min each, free scrolling.'),
        rule(Ph.moon, 'Midnight resets the bank and the price.'),
        const SizedBox(height: 16),
        Text('Today', style: t.titleSmall),
        const SizedBox(height: 4),
        line('Walked', '${formatCount(c.stepsToday)} steps'),
        line('Added to the bank', formatMetres(s.addedTodayM)),
        line('Scrolled', formatMetres(s.scrolledTodayM)),
        if (owed) line('Owed (bank empty)', formatMetres(c.overdraftM)),
        line('In the bank', '${formatMetres(c.bankM)} of ${formatRound(c.bankCapM)}', strong: true),
        if (s.overflowWalkTodayM >= 0.05 || s.tamperChargedTodayM > 0) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (s.overflowWalkTodayM >= 0.05)
                '${formatMetres(s.overflowWalkTodayM)} walked with the bank full didn\'t count.',
              if (s.tamperChargedTodayM > 0)
                '${formatMetres(s.tamperChargedTodayM)} charged for time without scroll measuring.',
            ].join(' '),
            style: t.bodyMedium?.copyWith(color: col.muted),
          ),
        ],
        if (c.gaps.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Tracking gaps', style: t.titleSmall),
          const SizedBox(height: 4),
          for (final g in c.gaps.take(3))
            line('${_fmt(g.start)} to ${_fmt(g.end)}', formatMetres(g.chargedM)),
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
  final DoomWalkController c;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  bool _week = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return _page([
      Segmented<bool>(
        options: const [(false, 'Today'), (true, 'Last 7 days')],
        selected: _week,
        onChanged: (v) => setState(() => _week = v),
      ),
      _WalkingPanel(c: c, week: _week),
      _AppsPanel(c: c, week: _week),
    ]);
  }
}

class _WalkingPanel extends StatelessWidget {
  const _WalkingPanel({required this.c, required this.week});
  final DoomWalkController c;
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
            Text(value, style: t.titleLarge?.merge(numeric)),
            const SizedBox(height: 2),
            Text(label, style: t.bodySmall),
          ]),
        );
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Walking', style: t.labelLarge?.copyWith(color: col.muted)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(formatCount(c.stepsFor(week ? c.weekWalkedM : c.state.walkedTodayM)),
                style: t.headlineLarge?.merge(numeric)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(week ? 'steps in 7 days' : 'of ${formatCount(c.stepGoal)} steps today',
                  style: t.bodyMedium?.copyWith(color: col.muted)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Seven days, oldest left. The dashed line is the daily goal.
        Semantics(
          label: 'Walking per day, last 7 days: '
              '${[for (var i = 0; i < 7; i++) formatRound(series[i])].join(', ')}. '
              'Goal ${formatCount(c.stepGoal)} steps.',
          excludeSemantics: true,
          child: SizedBox(
            height: barMax + 40,
            child: Stack(children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 22 + goalY,
                child: Row(children: [
                  for (var x = 0; x < 40; x++)
                    Expanded(child: Container(height: 1, color: x.isEven ? col.faint : Colors.transparent)),
                ]),
              ),
              Positioned(right: 0, bottom: 26 + goalY, child: Text('goal', style: t.labelSmall)),
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
                      // Fixed height so bars start exactly 22 px up, where
                      // the goal line is measured from.
                      SizedBox(height: 16, child: Text(days[(today - 7 + i) % 7], style: t.labelSmall)),
                    ]),
                  ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 14),
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
  final DoomWalkController c;
  final bool week;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = c.ranked(week ? c.weekApps : c.todayApps);
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Scrolling by app', style: t.labelLarge?.copyWith(color: context.colors.muted)),
        const SizedBox(height: 8),
        Text(
          rows.isEmpty ? 'Nothing counted yet.' : 'Tap an app to share its card.',
          style: t.bodyMedium?.copyWith(color: context.colors.muted),
        ),
        const SizedBox(height: 8),
        for (final r in rows.take(12)) _AppRow(c: c, row: r, max: rows.first.rawM),
      ]),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.c, required this.row, required this.max, this.compact = false});
  final DoomWalkController c;
  final AppTotals row;
  final double max;

  /// Today card: no bar, the category instead.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final icon = c.appMeta[row.pkg]?.icon;
    final label = c.labelFor(row.pkg);
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.small),
        onTap: () => showShareCard(context, c, row.pkg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.small),
                child: icon != null
                    ? Image.memory(icon, width: 40, height: 40, gaplessPlayback: true)
                    : Container(
                        width: 40,
                        height: 40,
                        color: col.raised2,
                        child: Icon(Ph.squaresFour, size: 18, color: col.muted),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  if (compact)
                    Text(c.catalog.categoryOf(row.pkg).label, style: t.bodySmall)
                  else ...[
                    const SizedBox(height: 6),
                    ExcludeSemantics(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: max <= 0 ? 0 : (row.rawM / max).clamp(0.02, 1.0),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(color: col.accent, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatMetres(row.rawM), style: t.bodyLarge?.merge(numeric).copyWith(fontWeight: FontWeight.w500)),
                Text('scrolled', style: t.bodySmall?.copyWith(color: col.muted)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Today's scrolling as a climb up the next landmark: its silhouette fills
/// as you scroll, the ones already passed line up underneath. Plus the
/// all-time total.
class _Climb extends StatelessWidget {
  const _Climb({required this.c});
  final DoomWalkController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final metres = c.state.scrolledTodayM;
    final p = progressToward(metres, ladder: climb);
    final next = p.next;
    final pct = (p.fraction * 100).floor();
    final lifetime = c.lifetimeRawM;
    final way = next.upright ? 'up' : 'along';
    final size = next.upright ? 'tall' : 'long';
    final beyond = metres >= next.heightM; // past the last landmark
    final art = LandmarkArt(landmark: next, fraction: p.fraction, color: col.accent, track: col.faint);
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$pct%', style: t.headlineMedium?.merge(numeric)),
              const SizedBox(height: 2),
              Text('of the way $way ${next.refer}\u00A0${next.emoji}', style: t.bodyLarge),
              const SizedBox(height: 8),
              Text(
                metres < 0.05
                    ? 'It\'s ${formatRound(next.heightM)} $size. Nothing scrolled yet today, so you haven\'t started.'
                    : beyond
                        ? 'You\'ve scrolled ${next.count(metres)} today. Please go outside.'
                        : '${formatMetres(next.heightM - metres)} to go. You\'ve scrolled ${formatMetres(metres)} today.',
                style: t.bodyMedium?.merge(numeric).copyWith(color: col.muted),
              ),
            ]),
          ),
          // Tall landmarks stand beside the text; long ones lie under it.
          if (next.upright) ...[const SizedBox(width: 16), art],
        ]),
        if (!next.upright)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: LayoutBuilder(
              builder: (_, box) => Center(
                child: LandmarkArt(
                  landmark: next,
                  fraction: p.fraction,
                  color: col.accent,
                  track: col.faint,
                  height: 96,
                  maxWidth: box.maxWidth,
                ),
              ),
            ),
          ),
        if (p.passed.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final l in p.passed) _Passed(l),
          ]),
        ],
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 14),
        Text(
          'All time: ${LandmarkTier.lifetime.yardstick.count(lifetime)}, '
          '${(lifetime / karman.heightM * 100).toStringAsFixed(lifetime < 1000 ? 2 : 1)}% of the way to space.',
          style: t.bodyMedium?.merge(numeric).copyWith(color: col.muted),
        ),
      ]),
    );
  }
}

/// A landmark already passed today: "🦒 Giraffe ✓".
class _Passed extends StatelessWidget {
  const _Passed(this.l);
  final Landmark l;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final name = l.name[0].toUpperCase() + l.name.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: col.accentContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '${l.emoji} $name',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: col.onAccentContainer),
      ),
    );
  }
}
