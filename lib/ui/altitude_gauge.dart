import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The "climb": debt drawn as altitude on a mountain. The summit is the frost
/// line (full frost); walking brings the climber back down to base camp.
class AltitudeGauge extends StatelessWidget {
  const AltitudeGauge({super.key, required this.fraction, required this.frostMaxM, this.showScale = true});

  /// debt / frostMax, may exceed 1.
  final double fraction;
  final double frostMaxM;
  final bool showScale;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(
          painter: _GaugePainter(v, frostMaxM, over: fraction > 1, showScale: showScale),
          size: Size.infinite,
        ),
      );
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.f, this.frostMaxM, {required this.over, required this.showScale});
  final double f;
  final double frostMaxM;
  final bool over;
  final bool showScale;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = h * 0.94;
    final peak = Offset(w * 0.62, h * 0.12);

    // Sky: colder as the climb goes up.
    final sky = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
        Color.lerp(Palette.night, const Color(0xFF1C3350), f)!,
        Palette.night,
      ]);
    canvas.drawRect(Offset.zero & size, sky);

    // Stars.
    final star = Paint()..color = Palette.snow.withValues(alpha: 0.35);
    final rnd = math.Random(7);
    for (var i = 0; i < 28; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.45), rnd.nextDouble() * 1.1 + 0.2, star);
    }

    // Back ridge.
    final back = Path()
      ..moveTo(0, base)
      ..lineTo(w * 0.18, h * 0.52)
      ..lineTo(w * 0.30, h * 0.62)
      ..lineTo(w * 0.42, h * 0.40)
      ..lineTo(w * 0.86, h * 0.30)
      ..lineTo(w, h * 0.46)
      ..lineTo(w, base)
      ..close();
    canvas.drawPath(back, Paint()..color = Palette.slate);

    // Main peak.
    final left = Offset(w * 0.08, base);
    final right = Offset(w * 1.02, base);
    final mountain = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(w * 0.34, h * 0.56)
      ..lineTo(w * 0.42, h * 0.50)
      ..lineTo(peak.dx, peak.dy)
      ..lineTo(w * 0.80, h * 0.48)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(
      mountain,
      Paint()
        ..shader = ui.Gradient.linear(peak, Offset(peak.dx, base), [
          const Color(0xFF3A5A80),
          Palette.ridge,
        ]),
    );

    // Frost line + snow cap above it.
    final frostY = peak.dy + (base - peak.dy) * 0.0;
    final cap = Path()
      ..moveTo(peak.dx, peak.dy)
      ..lineTo(peak.dx + w * 0.055, peak.dy + h * 0.13)
      ..lineTo(peak.dx + w * 0.02, peak.dy + h * 0.10)
      ..lineTo(peak.dx - w * 0.01, peak.dy + h * 0.14)
      ..lineTo(peak.dx - w * 0.045, peak.dy + h * 0.10)
      ..close();
    canvas.drawPath(cap, Paint()..color = Palette.snow.withValues(alpha: 0.9));

    // Altitude ticks on the left: 0, 25, 50, 75, 100 % of the frost line.
    final tick = Paint()
      ..color = Palette.line.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; showScale && i <= 4; i++) {
      final y = base - (base - frostY) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w * 0.05, y), tick);
      final tp = TextPainter(
        text: TextSpan(
          text: i == 4 ? 'FROST ${frostMaxM.toStringAsFixed(0)} m' : (frostMaxM * i / 4).toStringAsFixed(0),
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 9,
            letterSpacing: 1.2,
            color: i == 4 ? Palette.glacier : Palette.mist.withValues(alpha: 0.7),
            fontFeatures: tabular,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w * 0.06, y - tp.height / 2));
    }

    // Dashed frost line across.
    final dash = Paint()
      ..color = Palette.glacier.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var x = w * 0.30; x < w; x += 8) {
      canvas.drawLine(Offset(x, frostY), Offset(x + 4, frostY), dash);
    }

    // Trail from base camp up the left slope to the summit.
    final trail = Path()
      ..moveTo(w * 0.16, base)
      ..lineTo(w * 0.34, h * 0.56)
      ..lineTo(w * 0.42, h * 0.50)
      ..lineTo(peak.dx, peak.dy);
    final metric = trail.computeMetrics().first;
    // Map fraction of altitude to distance along the trail.
    double distForAltitude(double frac) {
      final targetY = base - (base - peak.dy) * frac;
      var lo = 0.0, hi = metric.length;
      for (var i = 0; i < 24; i++) {
        final mid = (lo + hi) / 2;
        final y = metric.getTangentForOffset(mid)!.position.dy;
        if (y > targetY) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return (lo + hi) / 2;
    }

    final at = distForAltitude(f);
    final climbed = metric.extractPath(0, at);
    canvas.drawPath(
      metric.extractPath(0, metric.length),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Palette.mist.withValues(alpha: 0.25),
    );
    canvas.drawPath(
      climbed,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Palette.summit,
    );

    // Climber.
    final pos = metric.getTangentForOffset(at)!.position;
    final hot = over ? Palette.alpenglow : Palette.summit;
    canvas.drawCircle(pos, 13, Paint()..color = hot.withValues(alpha: 0.18));
    canvas.drawCircle(pos, 6.5, Paint()..color = hot);
    canvas.drawCircle(pos, 2.5, Paint()..color = Palette.night);

    // Base camp.
    canvas.drawCircle(Offset(w * 0.16, base), 4, Paint()..color = Palette.moss);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.f != f || old.over != over || old.frostMaxM != frostMaxM || old.showScale != showScale;
}
