import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The "climb": debt drawn as altitude on a ridge profile. The summit is the
/// full-frost line; walking brings the marker back down to the trailhead.
class AltitudeGauge extends StatelessWidget {
  const AltitudeGauge({super.key, required this.fraction, required this.frostMaxM, this.showScale = true});

  /// debt / frostMax, may exceed 1.
  final double fraction;
  final double frostMaxM;
  final bool showScale;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(
          painter: _GaugePainter(v, frostMaxM, showScale: showScale, c: context.colors),
          size: Size.infinite,
        ),
      );
}

/// Largest 1/2/5 × 10ⁿ step that puts about three ticks under [max].
double niceTickStep(double max) {
  if (max <= 0) return 0;
  final raw = max / 3;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  return [5.0, 2.0, 1.0].map((k) => k * mag).firstWhere((s) => s <= raw, orElse: () => mag);
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.f, this.frostMaxM, {required this.showScale, required this.c});
  final Palette c;
  final double f;
  final double frostMaxM;
  final bool showScale;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = h;
    final peak = Offset(w * 0.64, h * 0.16);

    // Own backdrop only when shown standalone; embedded (share card) it
    // sits directly on the host surface.
    if (showScale) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [c.raised2, c.raised]),
      );
    }

    // Far ridge.
    final far = Path()
      ..moveTo(0, base)
      ..lineTo(0, h * 0.62)
      ..lineTo(w * 0.20, h * 0.48)
      ..lineTo(w * 0.33, h * 0.58)
      ..lineTo(w * 0.47, h * 0.38)
      ..lineTo(w * 0.88, h * 0.34)
      ..lineTo(w, h * 0.44)
      ..lineTo(w, base)
      ..close();
    canvas.drawPath(far, Paint()..color = c.hairline.withValues(alpha: 0.55));

    // Main ridge.
    final ridge = Path()
      ..moveTo(w * 0.04, base)
      ..lineTo(w * 0.36, h * 0.60)
      ..lineTo(w * 0.45, h * 0.53)
      ..lineTo(peak.dx, peak.dy)
      ..lineTo(w * 0.81, h * 0.50)
      ..lineTo(w * 1.02, base)
      ..close();
    canvas.drawPath(
      ridge,
      Paint()
        ..shader = ui.Gradient.linear(peak, Offset(peak.dx, base), [c.ridge, c.raised]),
    );

    // Frost line at the summit.
    final frostY = peak.dy;
    final dash = Paint()
      ..color = c.muted.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var x = 0.0; x < w; x += 7) {
      canvas.drawLine(Offset(x, frostY), Offset(x + 3, frostY), dash);
    }

    if (showScale) {
      _label(canvas, 'Full frost ${frostMaxM.toStringAsFixed(0)} m', Offset(14, frostY - 18), c.muted);
      // Round ticks (50, 100 under a 150 m summit), never crowding the summit label.
      final step = niceTickStep(frostMaxM);
      for (var m = step; step > 0 && m < frostMaxM * 0.9; m += step) {
        final y = base - (base - frostY) * m / frostMaxM;
        canvas.drawLine(Offset(0, y), Offset(8, y), dash);
        _label(canvas, m.toStringAsFixed(m % 1 == 0 ? 0 : 1), Offset(14, y - 7), c.muted);
      }
    }

    // Trail from the trailhead up the left flank to the summit.
    final trail = Path()
      ..moveTo(w * 0.15, base)
      ..lineTo(w * 0.36, h * 0.60)
      ..lineTo(w * 0.45, h * 0.53)
      ..lineTo(peak.dx, peak.dy);
    final metric = trail.computeMetrics().first;

    double distForAltitude(double frac) {
      final targetY = base - (base - peak.dy) * frac;
      var lo = 0.0, hi = metric.length;
      for (var i = 0; i < 24; i++) {
        final mid = (lo + hi) / 2;
        if (metric.getTangentForOffset(mid)!.position.dy > targetY) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return (lo + hi) / 2;
    }

    final at = distForAltitude(f);
    canvas.drawPath(
      metric.extractPath(at, metric.length),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = c.faint.withValues(alpha: 0.6),
    );
    canvas.drawPath(
      metric.extractPath(0, at),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = c.accent,
    );

    final pos = metric.getTangentForOffset(at)!.position;
    canvas.drawCircle(pos, 7, Paint()..color = c.ink);
    canvas.drawCircle(pos, 5, Paint()..color = c.accent);
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: font, fontSize: 11, color: color, fontFeatures: tabular),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.f != f || old.frostMaxM != frostMaxM || old.showScale != showScale || old.c != c;
}
