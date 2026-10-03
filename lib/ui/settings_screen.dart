import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_catalog.dart';
import '../core/debt_engine.dart';
import '../core/presets.dart';
import '../core/units.dart';
import '../services/controller.dart';
import '../services/native_bridge.dart';
import 'icons.dart';
import 'permissions_screen.dart';
import 'providers.dart';
import 'theme.dart';

/// Settings as a short list of groups. Each row opens its own page, so the
/// first screen fits without scrolling past controls nobody uses daily.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    final cfg = c.config;
    final t = Theme.of(context).textTheme;
    final preset = Strictness.of(cfg);
    final restricted = AppCategory.values.where(c.catalog.restricted.contains).map((e) => e.label).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SectionTitle('How strict'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.margin),
          child: Segmented<Strictness>(
            options: [for (final s in Strictness.values) (s, s.label)],
            selected: preset,
            onChanged: (s) => c.updateConfig(s.applyTo(cfg)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.margin + 4, 10, Gaps.margin + 4, 0),
          child: Text(
            cfg.demoMode
                ? 'Demo mode is on and replaces these rules. Turn it off in Developer options.'
                : preset == null
                    ? 'You\'re using custom rules. Pick a level to replace them.'
                    : '${formatRound(cfg.allowanceM)} of free scrolling a day. After that, walk '
                        '${_x(cfg.ratio)} m for every metre. Apps freeze completely at '
                        '${formatRound(cfg.frostMaxDebtM)} owed.',
            style: t.bodyMedium?.copyWith(color: context.colors.muted),
          ),
        ),
        const SectionTitle('Rules'),
        TileGroup(dividerIndent: 64, children: [
          _NavTile(
            icon: Ph.squaresFour,
            title: 'Apps that count',
            subtitle: restricted.isEmpty ? 'None' : restricted.join(', '),
            page: const _AppsThatCountPage(),
          ),
          _NavTile(
            icon: Ph.lifebuoy,
            title: 'Emergency passes',
            subtitle: '${cfg.overridesPerDay} a day, scrolling costs ${formatTimes(cfg.overridePenalty)} while unfrozen',
            page: const _PassesPage(),
          ),
          const _NavTile(
            icon: Ph.sliders,
            title: 'Custom rules',
            subtitle: 'Free scrolling, walking, frost, overnight growth',
            page: _CustomRulesPage(),
          ),
        ]),
        const SectionTitle('General'),
        TileGroup(dividerIndent: 64, children: [
          _NavTile(
            icon: Ph.user,
            title: 'You',
            subtitle: '${cfg.weightKg.toStringAsFixed(0)} kg, ${formatRound(cfg.walkGoalM)} goal, '
                '${cfg.strideM.toStringAsFixed(2)} m stride',
            page: const _YouPage(),
          ),
          _NavTile(
            icon: Ph.palette,
            title: 'Appearance',
            subtitle: _themeLabel(c.themeMode),
            page: const _AppearancePage(),
          ),
          _NavTile(
            icon: Ph.listChecks,
            title: 'Permissions',
            subtitle: c.status.serviceConnected
                ? 'Scroll measuring is on'
                : c.status.accessibilityEnabled
                    ? 'Scroll measuring has stopped'
                    : 'Scroll measuring is off',
            page: const PermissionsScreen(),
          ),
          const _NavTile(
            icon: Ph.shieldCheck,
            title: 'Privacy and data',
            subtitle: 'Everything stays on this phone',
            page: _PrivacyPage(),
          ),
        ]),
        const SectionTitle('Developer'),
        TileGroup(dividerIndent: 64, children: [
          SwitchListTile(
            secondary: const IconBadge(icon: Ph.code),
            title: const Text('Developer options'),
            subtitle: const Text('Testing tools: add steps or scrolling, demo mode'),
            value: c.developerOptions,
            onChanged: c.setDeveloperOptions,
          ),
          if (c.developerOptions) DeveloperTools(c: c),
        ]),
      ],
    );
  }
}

String _x(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _themeLabel(String mode) => switch (mode) {
      'light' => 'Light',
      'dark' => 'Dark',
      _ => 'Same as the system',
    };

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, required this.subtitle, required this.page});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: IconBadge(icon: icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(Ph.caretRight, size: 18, color: context.colors.muted),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
      );
}

/// A settings sub-page: app bar with back, then a list.
class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.only(bottom: 32), children: children),
      );
}

/// Explanatory text on the page margin.
class _Help extends StatelessWidget {
  const _Help(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.margin + 4, 8, Gaps.margin + 4, 12),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.muted)),
      );
}

// ------------------------------------------------------------- sub-pages

class _AppsThatCountPage extends ConsumerWidget {
  const _AppsThatCountPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    return _SubPage(title: 'Apps that count', children: [
      const _Help('Scrolling in these apps counts toward debt, and they freeze over when you owe. '
          'Everything else, like banking, calls and maps, is never touched.'),
      TileGroup(children: [
        for (final cat in AppCategory.values)
          SwitchListTile(
            title: Text(cat.label),
            subtitle: Text(c.catalog.restricted.contains(cat) ? 'Counts at ${rateLabel(cat.rate)} rate' : 'Doesn\'t count'),
            value: c.catalog.restricted.contains(cat),
            onChanged: (v) => c.setCategoryRestricted(cat, v),
          ),
      ]),
      const SectionTitle('Single apps'),
      const _Help('Change the rule for one app. "Default" follows its category above.'),
      TileGroup(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.margin, 10, Gaps.margin, 4),
          child: _RatesEditor(c: c),
        ),
      ]),
    ]);
  }
}

class _PassesPage extends ConsumerWidget {
  const _PassesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    final cfg = c.config;
    void set(DebtConfig n) => c.updateConfig(n);
    return _SubPage(title: 'Emergency passes', children: [
      _Help('A pass unfreezes your apps for ${cfg.overrideMinutes} minutes when you really need them. '
          'Scrolling still counts, at a higher cost.'),
      TileGroup(children: [
        _SliderRow(
          label: 'Passes per day',
          value: cfg.overridesPerDay.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          format: (v) => v.toStringAsFixed(0),
          onChanged: (v) => set(cfg.copyWith(overridesPerDay: v.round())),
        ),
        _SliderRow(
          label: 'Cost while unfrozen',
          value: cfg.overridePenalty,
          min: 1,
          max: 5,
          divisions: 8,
          format: formatTimes,
          onChanged: (v) => set(cfg.copyWith(overridePenalty: v)),
        ),
      ]),
    ]);
  }
}

class _CustomRulesPage extends ConsumerWidget {
  const _CustomRulesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    final cfg = c.config;
    void set(DebtConfig n) => c.updateConfig(n);
    return _SubPage(title: 'Custom rules', children: [
      _Help(cfg.demoMode
          ? 'Demo mode is on and replaces these rules until you turn it off.'
          : 'Changing any of these switches How strict to custom.'),
      TileGroup(children: [
        _SliderRow(
          label: 'Free scrolling per day',
          value: cfg.allowanceM,
          min: 0,
          max: 1000,
          divisions: 40,
          format: (v) => '${v.toStringAsFixed(0)} m',
          onChanged: (v) => set(cfg.copyWith(allowanceM: v)),
        ),
        _SliderRow(
          label: 'Metres to walk per metre scrolled',
          value: cfg.ratio,
          min: 0.5,
          max: 5,
          divisions: 9,
          format: (v) => '${_x(v)} m',
          onChanged: (v) => set(cfg.copyWith(ratio: v)),
        ),
        _SliderRow(
          label: 'Apps freeze completely at',
          value: cfg.frostMaxDebtM,
          min: 10,
          max: 500,
          divisions: 49,
          format: (v) => '${v.toStringAsFixed(0)} m owed',
          onChanged: (v) => set(cfg.copyWith(frostMaxDebtM: v)),
        ),
        _SliderRow(
          label: 'Overnight growth of unpaid debt',
          value: cfg.interestRate * 100,
          min: 0,
          max: 20,
          divisions: 40,
          format: (v) => '${v.toStringAsFixed(1)}%',
          onChanged: (v) => set(cfg.copyWith(interestRate: v / 100)),
        ),
      ]),
    ]);
  }
}

class _YouPage extends ConsumerWidget {
  const _YouPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    final cfg = c.config;
    void set(DebtConfig n) => c.updateConfig(n);
    return _SubPage(title: 'You', children: [
      const _Help('Used for calorie estimates and to turn steps into metres.'),
      TileGroup(children: [
        _SliderRow(
          label: 'Daily walking goal',
          value: cfg.walkGoalM / 1000,
          min: 1,
          max: 15,
          divisions: 28,
          format: (v) => '${v.toStringAsFixed(1)} km',
          onChanged: (v) => set(cfg.copyWith(walkGoalM: v * 1000)),
        ),
        _SliderRow(
          label: 'Body weight',
          value: cfg.weightKg,
          min: 40,
          max: 150,
          divisions: 110,
          format: (v) => '${v.toStringAsFixed(0)} kg',
          onChanged: (v) => set(cfg.copyWith(weightKg: v)),
        ),
        _SliderRow(
          label: 'Stride length',
          value: cfg.strideM,
          min: 0.4,
          max: 1.2,
          divisions: 16,
          format: (v) => '${v.toStringAsFixed(2)} m',
          onChanged: (v) => set(cfg.copyWith(strideM: v)),
        ),
      ]),
    ]);
  }
}

class _AppearancePage extends ConsumerWidget {
  const _AppearancePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    return _SubPage(title: 'Appearance', children: [
      const SizedBox(height: 8),
      TileGroup(children: [
        RadioGroup<String>(
          groupValue: c.themeMode,
          onChanged: (v) => c.setThemeMode(v ?? 'system'),
          child: Column(children: [
            for (final m in ['system', 'light', 'dark']) RadioListTile<String>(value: m, title: Text(_themeLabel(m))),
          ]),
        ),
      ]),
    ]);
  }
}

class _PrivacyPage extends ConsumerWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    return _SubPage(title: 'Privacy and data', children: [
      const _Help('Scroll Debt has no internet permission and no analytics. It sees how far you scroll and '
          'which app is open, never what is on the screen. All data stays on this phone.'),
      const SizedBox(height: 8),
      TileGroup(children: [
        ListTile(
          leading: IconBadge(
            icon: Ph.trash,
            background: context.colors.danger.withValues(alpha: 0.14),
            foreground: context.colors.danger,
          ),
          title: Text('Erase all data', style: TextStyle(color: context.colors.danger)),
          subtitle: const Text('Debt, history and tracking gaps. Settings are kept.'),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                title: const Text('Erase all data?'),
                content: const Text('Debt, history and tracking gaps are deleted. Settings are kept. '
                    'This can\'t be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: context.colors.danger),
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('Erase'),
                  ),
                ],
              ),
            );
            if (ok == true) await c.resetAll();
          },
        ),
      ]),
    ]);
  }
}

// ------------------------------------------------------- developer tools

/// Everything that fakes data. Only built while developer options are on,
/// and every controller call it makes checks that flag again.
class DeveloperTools extends StatefulWidget {
  const DeveloperTools({super.key, required this.c});
  final ScrollDebtController c;

  @override
  State<DeveloperTools> createState() => _DeveloperToolsState();
}

class _DeveloperToolsState extends State<DeveloperTools> {
  late final Future<List<AppMeta>> _apps;
  String? _pkg;

  @override
  void initState() {
    super.initState();
    _apps = widget.c.launchableApps().catchError((Object _) => <AppMeta>[]);
  }

  void _done(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final t = Theme.of(context).textTheme;
    const demo = DebtConfig.demo;
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.margin, 16, Gaps.margin, 4),
          child: Text(text, style: t.titleSmall),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        title: const Text('Demo mode'),
        subtitle: Text('${demo.allowanceM.toStringAsFixed(0)} m free, 1 m walked per metre, apps freeze at '
            '${demo.frostMaxDebtM.toStringAsFixed(0)} m. Scroll, freeze, walk and clear fit in two minutes.'),
        value: c.config.demoMode,
        onChanged: (v) => c.updateConfig(c.config.copyWith(demoMode: v)),
      ),
      heading('Add steps to today'),
      _Help('Counted like real steps: they pay debt down and count toward your goal. '
          '1,000 steps is ${formatRound(1000 * c.config.strideM)} at your stride.'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.margin),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in [100, 1000, 5000])
            OutlinedButton.icon(
              icon: const Icon(Ph.footprints, size: 18),
              onPressed: () {
                c.devAddSteps(n);
                _done('Added ${_thousands(n)} steps (${formatMetres(n * c.config.strideM)})');
              },
              label: Text('+${_thousands(n)}'),
            ),
        ]),
      ),
      heading('Add scrolling'),
      const _Help('Priced like real scrolling in that app: free allowance first, then its rate.'),
      FutureBuilder<List<AppMeta>>(
        future: _apps,
        builder: (context, snap) {
          // Only apps that count: scrolling anywhere else is free and would
          // be ignored, which the confirmation would misreport.
          final apps = (snap.data ?? const <AppMeta>[]).where((a) => c.catalog.isRestricted(a.pkg)).toList()
            ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
          // Pin the choice once made (or defaulted), so what the dropdown
          // shows is always what the buttons charge, even if the list re-sorts.
          if (_pkg == null || !apps.any((a) => a.pkg == _pkg)) _pkg = apps.isEmpty ? null : apps.first.pkg;
          final pkg = _pkg;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.margin),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (apps.isEmpty)
                Text(snap.hasData ? 'No apps that count are installed.' : 'Loading apps…', style: t.bodyMedium)
              else
                DropdownButtonFormField<String>(
                  key: ValueKey(pkg),
                  initialValue: pkg,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'App'),
                  icon: Icon(Ph.caretDown, size: 16, color: context.colors.muted),
                  dropdownColor: context.colors.raised2,
                  borderRadius: BorderRadius.circular(Radii.small),
                  items: [
                    for (final a in apps)
                      DropdownMenuItem(
                        value: a.pkg,
                        child: Text('${a.label}, ${rateLabel(c.catalog.rateFor(a.pkg))}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _pkg = v),
                ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in [10.0, 50.0, 200.0])
                  OutlinedButton(
                    onPressed: pkg == null
                        ? null
                        : () {
                            c.devAddScroll(pkg, m);
                            _done('Added ${formatRound(m)} of scrolling to ${c.labelFor(pkg)}');
                          },
                    child: Text('+${m.toStringAsFixed(0)} m'),
                  ),
              ]),
            ]),
          );
        },
      ),
      const SizedBox(height: 8),
      ListTile(
        leading: const Icon(Ph.ticket),
        title: const Text('Refill emergency passes'),
        subtitle: Text('${c.passesUsedToday} used today'),
        enabled: c.passesUsedToday > 0,
        onTap: () {
          c.devRefillPasses();
          _done('Passes refilled');
        },
      ),
      ListTile(
        leading: const Icon(Ph.trash),
        title: const Text('Reset walking and scrolling'),
        subtitle: const Text('Debt, steps, scrolling and history back to zero. Settings are kept.'),
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Reset walking and scrolling?'),
              content: const Text('Debt, today\'s steps and scrolling, history and tracking gaps are deleted. '
                  'Settings are kept.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Reset')),
              ],
            ),
          );
          if (ok != true) return;
          await c.devResetTracking();
          if (mounted) _done('Walking and scrolling reset');
        },
      ),
      ListTile(
        leading: const Icon(Ph.arrowCounterClockwise),
        title: const Text('Show setup again'),
        subtitle: const Text('Opens the permission walkthrough from the start'),
        onTap: c.devReplayOnboarding,
      ),
    ]);
  }
}

String _thousands(int n) => n >= 1000 ? '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}' : '$n';

// --------------------------------------------------------------- widgets

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.margin, 12, Gaps.margin, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: t.bodyLarge)),
          Text(format(value), style: t.bodyLarge?.merge(numeric).copyWith(color: context.colors.accent)),
        ]),
        Slider(
          padding: const EdgeInsets.symmetric(vertical: 16),
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          semanticFormatterCallback: format,
          onChanged: onChanged,
        ),
      ]),
    );
  }
}

class _RatesEditor extends StatefulWidget {
  const _RatesEditor({required this.c});
  final ScrollDebtController c;

  @override
  State<_RatesEditor> createState() => _RatesEditorState();
}

class _RatesEditorState extends State<_RatesEditor> {
  late Future<List<AppMeta>> _apps;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _apps = widget.c.launchableApps().catchError((Object _) => <AppMeta>[]);
  }

  static const _choices = <double?>[null, 0, 1, 2, 3];

  String _choiceLabel(double? r) => r == null ? 'Default' : (r == 0 ? 'Never counts' : '${rateLabel(r)} rate');

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final t = Theme.of(context).textTheme;
    return FutureBuilder<List<AppMeta>>(
      future: _apps,
      builder: (context, snap) {
        if (!snap.hasData) return const _RatesSkeleton();
        for (final a in snap.data!) {
          c.catalog.categories[a.pkg] = categoryFromAndroid(a.category);
        }
        final seen = c.weekApps.keys.toSet();
        final apps = snap.data!
            .where((a) => !c.catalog.isExempt(a.pkg))
            .where((a) => _query.isEmpty || a.label.toLowerCase().contains(_query) || a.pkg.contains(_query))
            .toList()
          ..sort((a, b) {
            final s = (seen.contains(b.pkg) ? 1 : 0) - (seen.contains(a.pkg) ? 1 : 0);
            return s != 0 ? s : a.label.toLowerCase().compareTo(b.label.toLowerCase());
          });
        return Column(children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Ph.magnifyingGlass, size: 18),
              hintText: 'Search apps',
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
          const SizedBox(height: 8),
          for (final a in apps.take(60))
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.label, style: t.bodyLarge),
                    Text(
                      '${c.catalog.categoryOf(a.pkg).label}, '
                      '${c.catalog.isRestricted(a.pkg) ? 'counts at ${rateLabel(c.catalog.rateFor(a.pkg))}' : 'doesn\'t count'}',
                      style: t.bodyMedium?.copyWith(color: context.colors.muted),
                    ),
                  ]),
                ),
                DropdownButton<double?>(
                  value: c.catalog.overrides[a.pkg],
                  underline: const SizedBox.shrink(),
                  icon: Icon(Ph.caretDown, size: 14, color: context.colors.muted),
                  borderRadius: BorderRadius.circular(Radii.small),
                  dropdownColor: context.colors.raised2,
                  style: t.bodyMedium?.copyWith(color: context.colors.text),
                  items: [for (final r in _choices) DropdownMenuItem(value: r, child: Text(_choiceLabel(r)))],
                  onChanged: (r) async {
                    await c.setRate(a.pkg, r);
                    setState(() {});
                  },
                ),
              ]),
            ),
        ]);
      },
    );
  }
}

/// Loading placeholder shaped like the list it stands in for.
class _RatesSkeleton extends StatelessWidget {
  const _RatesSkeleton();

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(
                width: 90.0 + (i * 37) % 80,
                height: 12,
                decoration: BoxDecoration(color: context.colors.raised2, borderRadius: BorderRadius.circular(4)),
              ),
              const Spacer(),
              Container(
                width: 28,
                height: 12,
                decoration: BoxDecoration(color: context.colors.raised2, borderRadius: BorderRadius.circular(4)),
              ),
            ]),
          ),
      ]);
}
