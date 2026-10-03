import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/landmarks.dart';
import '../core/units.dart';
import '../services/controller.dart';
import 'altitude_gauge.dart';
import 'theme.dart';

/// "Instagram: 4.2 Eiffel Towers this week" for [pkg].
String shareHeadline(String label, double weekMetres) =>
    '$label: ${nearestText(weekMetres)} this week';

Future<void> showShareCard(BuildContext context, ScrollDebtController c, String pkg) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShareDialog(c: c, pkg: pkg),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.c, required this.pkg});
  final ScrollDebtController c;
  final String pkg;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final ro = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await ro.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/scroll-debt-${widget.pkg}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      final week = widget.c.weekApps[widget.pkg]?.rawM ?? 0;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '${shareHeadline(widget.c.labelFor(widget.pkg), week)}. Paying it back on foot. #ScrollDebt',
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        RepaintBoundary(key: _boundary, child: ShareCard(c: widget.c, pkg: widget.pkg)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share'),
          ),
        ]),
      ]),
    );
  }
}

class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.c, required this.pkg});
  final ScrollDebtController c;
  final String pkg;

  @override
  Widget build(BuildContext context) {
    final week = c.weekApps[pkg]?.rawM ?? 0;
    final today = c.todayApps[pkg]?.rawM ?? 0;
    final label = c.labelFor(pkg);
    final icon = c.appMeta[pkg]?.icon;
    final lm = nearestLandmark(week);
    final t = Theme.of(context).textTheme;
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1C3350), Palette.night],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 190,
            child: Opacity(
              opacity: 0.85,
              child: AltitudeGauge(
                fraction: (week / lm.heightM).clamp(0.0, 1.0),
                frostMaxM: lm.heightM,
                showScale: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (icon != null)
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(icon, width: 44, height: 44)),
                if (icon != null) const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ),
                Text('SCROLL DEBT', style: t.labelSmall?.copyWith(color: Palette.glacier)),
              ]),
              const SizedBox(height: 28),
              Text(lm.glyph, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 6),
              Text(
                lm.count(week),
                style: t.displaySmall?.copyWith(color: Palette.summit, fontWeight: FontWeight.w400, height: 1.05),
              ),
              Text('this week', style: t.titleMedium?.copyWith(color: Palette.mist)),
              const SizedBox(height: 14),
              Text(
                '${formatMetres(week)} of thumb travel in 7 days\n${formatMetres(today)} today',
                style: t.bodyMedium?.copyWith(color: Palette.snow.withValues(alpha: 0.85), fontFeatures: tabular),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
