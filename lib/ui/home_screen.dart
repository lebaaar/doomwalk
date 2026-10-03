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

/// A filled Material card with 16 dp padding (20 at the sides).
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: child),
      );
}

// ------------------------------------------------------------------ Today

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.c, required this.onOpenActivity});
  final ScrollDebtController c;
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
              title: 'Scroll measuring isn\'t running',
              body: 'It\'s switched on but Android stopped it, so nothing frosts. Switching it off and on again fixes it.',
            ),
          if (c.walkError != null)
            const _Notice(
              title: 'Step counting is off',
              body: 'Walking won\'t pay your debt down until physical activity access is allowed.',
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.margin),
            child: _TodayCard(c: c, onOpenActivity: onOpenActivity),
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
        color: Color.alphaBlend(col.danger.withValues(alpha: 0.12), col.raised),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const OnboardingScreen(standalone: true))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              IconBadge(icon: Ph.warningCircle, background: col.danger.withValues(alpha: 0.16), foreground: col.danger),
              const SizedBox(width: 14),
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

/// Where today stands, from most to least urgent.
enum _Verdict { walk, unfrozen, limit, low, free }

/// The one card that answers "what now?": a verdict, the number behind it,
/// and the two things it comes from, walked and scrolled today.
class _TodayCard extends StatefulWidget {
  const _TodayCard({required this.c, required this.onOpenActivity});
  final ScrollDebtController c;
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
    final debt = c.debtM;
    final owed = debt >= 0.05;
    final pass = c.overrideActive;
    final allowance = c.config.effective.allowanceM;
    final left = c.allowanceLeftM;
    final verdict = pass
        ? _Verdict.unfrozen
        : owed
            ? _Verdict.walk
            : left < 0.5
                ? _Verdict.limit
                : (allowance > 0 && left / allowance <= 0.25 ? _Verdict.low : _Verdict.free);

    // Owing turns the card navy (frost blue in dark mode); otherwise it is
    // the pale frost of the icon background.
    final fg = owed ? col.onHero : col.text;
    final muted = owed ? col.onHeroMuted : col.muted;
    final strong = owed ? col.onHero : col.accent;
    final penalty = formatTimes(c.config.overridePenalty);
    final frostPct = (c.frostLevel * 100).round();
    final apps = c.frostedAppsToday;
    final which = apps.isEmpty ? 'your restricted apps' : 'apps like ${_appList(c, apps)}';

    final (IconData icon, String status) = switch (verdict) {
      _Verdict.walk => (Ph.walk, 'Time for a walk'),
      _Verdict.unfrozen => (Ph.lifebuoy, 'Unfrozen for ${_countdown(c)}'),
      _Verdict.limit => (Ph.lockSimple, 'Free scrolling used up'),
      _Verdict.low => (Ph.warningCircle, 'Almost at your limit'),
      _Verdict.free => (Ph.checkCircle, 'You\'re good to scroll'),
    };
    final value = owed ? debt : left;
    final sentence = switch (verdict) {
      _Verdict.walk => c.status.serviceConnected
          ? 'to walk off. Until then, $which stay frosted ($frostPct%).'
          : 'to walk off. Frost is paused while scroll measuring is off.',
      _Verdict.unfrozen => owed
          ? 'still to walk off. Scrolling costs $penalty until the pass ends.'
          : 'of free scrolling left. Past that, scrolling costs $penalty until the pass ends.',
      _Verdict.limit => 'of free scrolling left. Anything more you scroll has to be walked off.',
      _Verdict.low || _Verdict.free => 'of free scrolling left today, out of ${formatRound(allowance)}.',
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.surface + 4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: owed ? [col.heroFrom, col.heroTo] : [col.calmFrom, col.calmTo],
        ),
        border: owed ? null : Border.all(color: col.hairline),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showLedgerSheet(context, c),
          child: Stack(children: [
            // The logo, large and faint, bleeding off the corner.
            Positioned(
              right: -36,
              top: -20,
              child: ExcludeSemantics(child: DepthTicks(size: 190, color: fg.withValues(alpha: 0.07))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [...previous, ?current],
                  ),
                  child: _StatusPill(key: ValueKey(verdict), icon: icon, text: status, color: strong),
                ),
                const SizedBox(height: 18),
                Semantics(
                  label: '$status. ${formatMetres(value)} $sentence',
                  excludeSemantics: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: value),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      // Unit follows the animated value, so crossing 1 km
                      // never shows metres formatted as kilometres.
                      builder: (_, v, _) {
                        final km = v >= 999.95;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              km ? (v / 1000).toStringAsFixed(2) : v.toStringAsFixed(owed ? 1 : 0),
                              style: t.displayLarge?.copyWith(color: fg, fontSize: 64, fontFeatures: tabular),
                            ),
                            const SizedBox(width: 6),
                            Text(km ? 'km' : 'm', style: t.headlineSmall?.copyWith(color: muted)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(sentence, style: t.bodyLarge?.copyWith(color: muted, height: 1.4)),
                  ]),
                ),
                if (!owed) ...[
                  const SizedBox(height: 16),
                  // Drains like a battery as the free scrolling is used.
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: allowance <= 0 ? 0.0 : (left / allowance).clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 10,
                          color: col.accent,
                          backgroundColor: col.accent.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _Tally(c: c, fg: fg, muted: muted, onOpenActivity: widget.onOpenActivity),
                if (owed || pass) ...[
                  const SizedBox(height: 16),
                  _PassButton(c: c, fg: fg, muted: muted),
                ],
                const SizedBox(height: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: strong,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Ph.caretRight, size: 14),
                  onPressed: () => showLedgerSheet(context, c),
                  label: Text(owed ? 'How ${formatMetres(debt)} adds up' : 'How it works'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

String _countdown(ScrollDebtController c) {
  final s = c.overrideUntil!.difference(DateTime.now()).inSeconds.clamp(0, 99999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({super.key, required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.labelLarge?.merge(numeric).copyWith(color: color)),
        ]),
      );
}

/// Walked and scrolled today, as two plain rows.
class _Tally extends StatelessWidget {
  const _Tally({required this.c, required this.fg, required this.muted, required this.onOpenActivity});
  final ScrollDebtController c;
  final Color fg;
  final Color muted;
  final VoidCallback onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = c.state;
    final over = s.scrolledTodayM - s.allowanceUsedM;
    Widget row(Widget badge, String label, String sub, String value) => MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              badge,
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: t.titleSmall?.copyWith(color: fg)),
                  Text(sub, style: t.bodySmall?.merge(numeric).copyWith(color: muted)),
                ]),
              ),
              const SizedBox(width: 12),
              Text(value, style: t.titleMedium?.merge(numeric).copyWith(color: fg)),
            ]),
          ),
        );
    IconBadge badge({IconData? icon, Widget? child}) => IconBadge(
          icon: icon,
          size: 36,
          background: fg.withValues(alpha: 0.08),
          foreground: fg,
          child: child,
        );
    return Container(
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpenActivity,
          child: row(
            badge(icon: Ph.footprints),
            'Walked today',
            c.walkError != null
                ? 'Steps aren\'t being counted'
                : '${(c.goalProgress * 100).round()}% of your ${formatRound(c.config.walkGoalM)} goal',
            formatMetres(s.walkedTodayM),
          ),
        ),
        row(
          badge(child: const DepthTicks(small: true)),
          'Scrolled today',
          over >= 0.05
              ? '${formatRound(s.allowanceUsedM)} free, ${formatMetres(over)} over'
              : 'All within your free scrolling',
          formatMetres(s.scrolledTodayM),
        ),
      ]),
    );
  }
}

class _PassButton extends StatelessWidget {
  const _PassButton({required this.c, required this.fg, required this.muted});
  final ScrollDebtController c;
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
    final penalty = formatTimes(c.config.overridePenalty);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Tonal: a way out, not the main thing to do (that's walking).
      FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          backgroundColor: fg.withValues(alpha: 0.12),
          foregroundColor: fg,
          disabledBackgroundColor: fg.withValues(alpha: 0.06),
          disabledForegroundColor: muted,
        ),
        onPressed: left > 0 ? c.startOverride : null,
        icon: const Icon(Ph.lifebuoy, size: 20),
        label: Text('Unfreeze for ${c.config.overrideMinutes} min'),
      ),
      const SizedBox(height: 6),
      Text(
        left > 0
            ? 'Scrolling costs $penalty while unfrozen. $left ${left == 1 ? 'pass' : 'passes'} left today.'
            : 'No passes left today.',
        textAlign: TextAlign.center,
        style: t.bodySmall?.copyWith(color: muted),
      ),
    ]);
  }
}

class _TopAppsCard extends StatelessWidget {
  const _TopAppsCard({required this.c});
  final ScrollDebtController c;

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
          'then by ${formatTimes(cfg.effective.ratio)} to turn it into walking.',
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
                    ? Image.memory(icon, width: 40, height: 40, gaplessPlayback: true)
                    : Container(
                        width: 40,
                        height: 40,
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
                          decoration: BoxDecoration(color: col.accent, borderRadius: BorderRadius.circular(2)),
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
