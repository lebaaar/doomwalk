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
import 'landmark_art.dart';
import 'logo.dart';
import 'theme.dart';

/// The landmark a week of scrolling reads best against, from a giraffe up.
Landmark shareLandmark(double weekMetres) => nearestLandmark(weekMetres, ladder: climb);

/// "Instagram: 1.1 Statues of Liberty this week" for [pkg].
String shareHeadline(String label, double weekMetres) =>
    '$label: ${shareLandmark(weekMetres).count(weekMetres)} this week';

Future<void> showShareCard(BuildContext context, DoomWalkController c, String pkg) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShareDialog(c: c, pkg: pkg),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.c, required this.pkg});
  final DoomWalkController c;
  final String pkg;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _boundary = GlobalKey();
  final _opened = DateTime.now();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      // The silhouette fills in when the card opens; capture it finished.
      final wait = LandmarkArt.fillDuration - DateTime.now().difference(_opened);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (!mounted) return;
      final ro = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await ro.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/doomwalk-${widget.pkg}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      final week = widget.c.weekApps[widget.pkg]?.rawM ?? 0;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '${shareHeadline(widget.c.labelFor(widget.pkg), week)}. Paying it back on foot. #DoomWalk',
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A solid sheet in the page colour, so the card (raised) stands out and
    // the buttons never sit over the screen behind.
    return Dialog(
      backgroundColor: context.colors.ink,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(key: _boundary, child: ShareCard(c: widget.c, pkg: widget.pkg)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Ph.export, size: 18),
                label: const Text('Share'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.c, required this.pkg});
  final DoomWalkController c;
  final String pkg;

  @override
  Widget build(BuildContext context) {
    final week = c.weekApps[pkg]?.rawM ?? 0;
    final label = c.labelFor(pkg);
    final icon = c.appMeta[pkg]?.icon;
    final lm = shareLandmark(week);
    final n = week / lm.heightM;
    final count = n.toStringAsFixed(1);
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final glow = Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.08;
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          color: col.raised,
          borderRadius: BorderRadius.circular(Radii.surface),
        ),
        clipBehavior: Clip.antiAlias,
        // The same soft frost glow as the Today card, from the top corner,
        // over the card colour (a gradient in the same decoration would
        // replace the colour instead of lighting it).
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.surface), // not clipped by clipBehavior
          gradient: RadialGradient(
            center: const Alignment(1.0, -1.1),
            radius: 1.1,
            colors: [col.accent.withValues(alpha: glow), col.accent.withValues(alpha: 0)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.small),
                child: Image.memory(icon, width: 32, height: 32),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(label, style: t.titleMedium, overflow: TextOverflow.ellipsis)),
            // In the row, not floated over it, so long app names
            // ellipsise before the brand instead of running under it.
            const SizedBox(width: 12),
            DepthTicks(size: 16, small: true, color: col.muted),
            const SizedBox(width: 6),
            Text('DoomWalk', style: t.bodySmall),
          ]),
          // The landmark, filled up to how much of it the week covers.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: LayoutBuilder(
                builder: (_, box) => Align(
                  alignment: Alignment.bottomCenter,
                  child: LandmarkArt(
                    landmark: lm,
                    fraction: n.clamp(0.0, 1.0),
                    color: col.accent,
                    track: col.faint,
                    height: box.maxHeight,
                    maxWidth: box.maxWidth,
                  ),
                ),
              ),
            ),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(
              count,
              style: t.displayLarge?.copyWith(fontSize: 64, height: 1, color: col.accent, fontFeatures: tabular),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                count == '1.0' ? lm.name : lm.plural,
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            '${lm.emoji} scrolled this week. ${formatMetres(week)} of thumb travel.',
            style: t.bodyMedium?.copyWith(color: col.muted),
          ),
        ]),
      ),
    );
  }
}
