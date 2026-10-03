import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_catalog.dart';
import '../core/debt_engine.dart';
import '../services/controller.dart';
import '../services/native_bridge.dart';
import 'onboarding_screen.dart';
import 'providers.dart';
import 'theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    final cfg = c.config;
    final t = Theme.of(context).textTheme;
    void set(DebtConfig n) => c.updateConfig(n);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Card(
            color: cfg.demoMode ? Palette.summit.withValues(alpha: 0.12) : null,
            child: SwitchListTile(
              title: const Text('Demo mode'),
              subtitle: Text(
                'For the stage: ${DebtConfig.demo.allowanceM.toStringAsFixed(0)} m free, '
                '1 m scrolled = ${DebtConfig.demo.ratio.toStringAsFixed(0)} m walked, '
                'full frost at ${DebtConfig.demo.frostMaxDebtM.toStringAsFixed(0)} m. '
                'The whole scroll → frost → walk → clear loop fits in two minutes.',
              ),
              value: cfg.demoMode,
              onChanged: (v) => set(cfg.copyWith(demoMode: v)),
            ),
          ),
          const SizedBox(height: 20),
          Text('ECONOMY${cfg.demoMode ? ' (overridden by demo mode)' : ''}', style: t.labelSmall),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              _SliderTile(
                label: 'Free scroll per day',
                value: cfg.allowanceM,
                min: 0,
                max: 1000,
                divisions: 40,
                format: (v) => '${v.toStringAsFixed(0)} m',
                onChanged: (v) => set(cfg.copyWith(allowanceM: v)),
              ),
              _SliderTile(
                label: 'Metres walked per metre scrolled',
                value: cfg.ratio,
                min: 0.5,
                max: 5,
                divisions: 9,
                format: (v) => '${v.toStringAsFixed(1)}×',
                onChanged: (v) => set(cfg.copyWith(ratio: v)),
              ),
              _SliderTile(
                label: 'Debt at full frost',
                value: cfg.frostMaxDebtM,
                min: 10,
                max: 500,
                divisions: 49,
                format: (v) => '${v.toStringAsFixed(0)} m',
                onChanged: (v) => set(cfg.copyWith(frostMaxDebtM: v)),
              ),
              _SliderTile(
                label: 'Overnight interest on unpaid debt',
                value: cfg.interestRate * 100,
                min: 0,
                max: 20,
                divisions: 40,
                format: (v) => '${v.toStringAsFixed(1)} %',
                onChanged: (v) => set(cfg.copyWith(interestRate: v / 100)),
              ),
              _SliderTile(
                label: 'Stride length',
                value: cfg.strideM,
                min: 0.4,
                max: 1.2,
                divisions: 16,
                format: (v) => '${v.toStringAsFixed(2)} m',
                onChanged: (v) => set(cfg.copyWith(strideM: v)),
              ),
              _SliderTile(
                label: 'Emergency passes per day',
                value: cfg.overridesPerDay.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                format: (v) => v.toStringAsFixed(0),
                onChanged: (v) => set(cfg.copyWith(overridesPerDay: v.round())),
              ),
              _SliderTile(
                label: 'Emergency pass cost multiplier',
                value: cfg.overridePenalty,
                min: 1,
                max: 5,
                divisions: 8,
                format: (v) => '${v.toStringAsFixed(1)}×',
                onChanged: (v) => set(cfg.copyWith(overridePenalty: v)),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Text('APP RATES', style: t.labelSmall),
          const SizedBox(height: 4),
          Text('How much each app\'s scrolling costs. Free apps are never counted or frosted.',
              style: t.bodySmall?.copyWith(color: Palette.mist)),
          const SizedBox(height: 8),
          _RatesEditor(c: c),
          const SizedBox(height: 20),
          Text('SETUP & PRIVACY', style: t.labelSmall),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: const Text('Permissions'),
                subtitle: const Text('Re-run the setup checklist'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const OnboardingScreen(standalone: true))),
              ),
              const ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: Text('Fully on-device'),
                subtitle: Text('No internet permission, no analytics. The accessibility service '
                    'receives only scroll geometry and app switches, never screen content.'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Palette.alpenglow),
                title: const Text('Erase all data'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Erase everything?'),
                      content: const Text('Debt, history and gaps are deleted. Settings stay.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Erase')),
                      ],
                    ),
                  );
                  if (ok == true) await c.resetAll();
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
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
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: t.bodyMedium)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(format(value), style: t.bodyMedium?.copyWith(color: Palette.glacier, fontFeatures: tabular)),
          ),
        ]),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: format(value),
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

  static const _choices = [0.0, 0.5, 1.0, 2.0, 3.0];

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return FutureBuilder<List<AppMeta>>(
      future: _apps,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
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
        for (final a in snap.data!) {
          c.catalog.categories[a.pkg] = categoryFromAndroid(a.category);
        }
        return Card(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search apps',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ),
            for (final a in apps.take(60))
              ListTile(
                dense: true,
                title: Text(a.label),
                subtitle: Text(
                  c.catalog.overrides.containsKey(a.pkg) ? 'custom' : 'default ${rateLabel(defaultRateFor(a.pkg, category: categoryFromAndroid(a.category)))}',
                  style: const TextStyle(color: Palette.mist),
                ),
                trailing: DropdownButton<double>(
                  value: _closest(c.catalog.rateFor(a.pkg)),
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final r in _choices) DropdownMenuItem(value: r, child: Text(rateLabel(r))),
                  ],
                  onChanged: (r) async {
                    await c.setRate(a.pkg, r);
                    setState(() {});
                  },
                ),
                onLongPress: () async {
                  await c.setRate(a.pkg, null);
                  setState(() {});
                },
              ),
          ]),
        );
      },
    );
  }

  double _closest(double v) =>
      _choices.reduce((a, b) => (a - v).abs() <= (b - v).abs() ? a : b);
}
