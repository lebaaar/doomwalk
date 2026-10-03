import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/landmarks.dart';
import '../core/units.dart';
import '../services/controller.dart';
import 'icons.dart';
import 'logo.dart';
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
            icon: const Icon(Ph.export, size: 18),
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
    final label = c.labelFor(pkg);
    final icon = c.appMeta[pkg]?.icon;
    final lm = nearestLandmark(week);
    final count = (week / lm.heightM).toStringAsFixed(1);
    final t = Theme.of(context).textTheme;
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.raised,
          borderRadius: BorderRadius.circular(Radii.surface),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // The mark, large and faint, sinking off the bottom edge.
          Positioned(
            right: -36,
            bottom: -48,
            child: DepthTicks(size: 240, color: context.colors.accent.withValues(alpha: 0.16)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (icon != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.small),
                    child: Image.memory(icon, width: 36, height: 36),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Text(label, style: t.titleMedium, overflow: TextOverflow.ellipsis)),
              ]),
              const Spacer(),
              Text(
                count,
                style: t.displayLarge?.copyWith(fontSize: 88, color: context.colors.accent, fontFeatures: tabular),
              ),
              Text(count == '1.0' ? lm.name : lm.plural, style: t.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'scrolled this week. ${formatMetres(week)} of thumb travel.',
                style: t.bodyMedium?.copyWith(color: context.colors.muted),
              ),
              const SizedBox(height: 120),
            ]),
          ),
          Positioned(
            right: 24,
            top: 30,
            child: Row(children: [
              DepthTicks(size: 16, small: true, color: context.colors.muted),
              const SizedBox(width: 6),
              Text('Scroll Debt', style: t.bodySmall),
            ]),
          ),
        ]),
      ),
    );
  }
}
