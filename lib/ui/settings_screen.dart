import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_catalog.dart';
import '../core/debt_engine.dart';
import '../services/controller.dart';
import '../services/native_bridge.dart';
import 'icons.dart';
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
    const demo = DebtConfig.demo;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Demo mode', style: t.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'For a stage demo. ${demo.allowanceM.toStringAsFixed(0)} m free, '
                  '1 m walked per metre scrolled, full frost at ${demo.frostMaxDebtM.toStringAsFixed(0)} m. '
                  'Scroll, frost, walk and clear fits in two minutes.',
                  style: t.bodySmall,
                ),
              ]),
            ),
            const SizedBox(width: 16),
            Switch(value: cfg.demoMode, onChanged: (v) => set(cfg.copyWith(demoMode: v))),
          ]),
          SectionTitle(cfg.demoMode ? 'Economy (paused by demo mode)' : 'Economy'),
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
            label: 'Metres walked per metre scrolled',
            value: cfg.ratio,
            min: 0.5,
            max: 5,
            divisions: 9,
            format: (v) => '${v.toStringAsFixed(1)}×',
            onChanged: (v) => set(cfg.copyWith(ratio: v)),
          ),
          _SliderRow(
            label: 'Debt at full frost',
            value: cfg.frostMaxDebtM,
            min: 10,
            max: 500,
            divisions: 49,
            format: (v) => '${v.toStringAsFixed(0)} m',
            onChanged: (v) => set(cfg.copyWith(frostMaxDebtM: v)),
          ),
          _SliderRow(
            label: 'Overnight interest',
            value: cfg.interestRate * 100,
            min: 0,
            max: 20,
            divisions: 40,
            format: (v) => '${v.toStringAsFixed(1)}%',
            onChanged: (v) => set(cfg.copyWith(interestRate: v / 100)),
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
          const SectionTitle('Emergency pass'),
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
            label: 'Cost while a pass is active',
            value: cfg.overridePenalty,
            min: 1,
            max: 5,
            divisions: 8,
            format: (v) => '${v.toStringAsFixed(1)}×',
            onChanged: (v) => set(cfg.copyWith(overridePenalty: v)),
          ),
          const SectionTitle('App rates'),
          Text(
            'What each app\'s scrolling costs. Free apps are never counted or frosted. Long-press to reset.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          _RatesEditor(c: c),
          const SectionTitle('Setup and privacy'),
          _LinkRow(
            icon: Ph.listChecks,
            title: 'Permissions',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const OnboardingScreen(standalone: true))),
          ),
          const Divider(indent: 40),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Ph.lockSimple, size: 22, color: Palette.muted),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Stays on this phone', style: t.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    'No internet permission and no analytics. Scroll Debt sees how far you scroll and which app '
                    'is open, never what is on screen.',
                    style: t.bodySmall,
                  ),
                ]),
              ),
            ]),
          ),
          const Divider(indent: 40),
          _LinkRow(
            icon: Ph.trash,
            title: 'Erase all data',
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  backgroundColor: Palette.raised,
                  title: const Text('Erase all data?'),
                  content: const Text('Debt, history and tracking gaps are deleted. Settings are kept.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Erase')),
                  ],
                ),
              );
              if (ok == true) await c.resetAll();
            },
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(Radii.small),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Icon(icon, size: 22, color: Palette.muted),
            const SizedBox(width: 18),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
            const Icon(Ph.caretRight, size: 16, color: Palette.faint),
          ]),
        ),
      );
}

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
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: t.bodyMedium)),
          Text(format(value), style: numeric.copyWith(fontSize: 14, color: Palette.text)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Slider(
              padding: const EdgeInsets.symmetric(vertical: 12),
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
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
            InkWell(
              borderRadius: BorderRadius.circular(Radii.small),
              onLongPress: () async {
                await c.setRate(a.pkg, null);
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.label, style: t.bodyMedium),
                      Text(
                        c.catalog.overrides.containsKey(a.pkg)
                            ? 'Custom'
                            : 'Default ${rateLabel(defaultRateFor(a.pkg, category: categoryFromAndroid(a.category)))}',
                        style: t.bodySmall,
                      ),
                    ]),
                  ),
                  DropdownButton<double>(
                    value: _closest(c.catalog.rateFor(a.pkg)),
                    underline: const SizedBox.shrink(),
                    icon: const Icon(Ph.caretDown, size: 14, color: Palette.muted),
                    borderRadius: BorderRadius.circular(Radii.small),
                    dropdownColor: Palette.raised2,
                    style: numeric.copyWith(fontSize: 14, color: Palette.text),
                    items: [for (final r in _choices) DropdownMenuItem(value: r, child: Text(rateLabel(r)))],
                    onChanged: (r) async {
                      await c.setRate(a.pkg, r);
                      setState(() {});
                    },
                  ),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  double _closest(double v) => _choices.reduce((a, b) => (a - v).abs() <= (b - v).abs() ? a : b);
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
                decoration: BoxDecoration(color: Palette.raised2, borderRadius: BorderRadius.circular(4)),
              ),
              const Spacer(),
              Container(
                width: 28,
                height: 12,
                decoration: BoxDecoration(color: Palette.raised2, borderRadius: BorderRadius.circular(4)),
              ),
            ]),
          ),
      ]);
}
