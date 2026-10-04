import 'package:flutter/widgets.dart';

// Same geometry as docs/logo/final/symbol.svg; [small] uses four fatter ticks to stay legible at icon size
class DepthTicks extends StatelessWidget {
  const DepthTicks({super.key, this.size, this.color, this.small = false});

  final double? size;
  final Color? color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final s = size ?? icon.size ?? 24;
    return SizedBox.square(
      dimension: s,
      child: CustomPaint(
        painter: _TicksPainter(
          color ?? icon.color ?? const Color(0xFF0E4166),
          small,
        ),
      ),
    );
  }
}

// (y, width, height) in a 256 x 256 box
List<(double, double, double)> depthTicks({bool small = false}) {
  final out = <(double, double, double)>[];
  if (small) {
    const ws = [84.0, 132.0, 180.0, 224.0];
    const hs = [26.0, 32.0, 38.0, 44.0];
    var y = 30.0;
    for (var i = 0; i < 4; i++) {
      out.add((y, ws[i], hs[i]));
      y += hs[i] + 16;
    }
    return out;
  }
  var y = 40.0;
  for (var i = 0; i < 6; i++) {
    final w = 56.0 + i * 28, h = 12.0 + i * 4;
    out.add((y, w, h));
    y += h + 5 + i * 2;
  }
  return out;
}

class _TicksPainter extends CustomPainter {
  _TicksPainter(this.color, this.small);
  final Color color;
  final bool small;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 256;
    final ticks = depthTicks(small: small);
    for (var i = 0; i < ticks.length; i++) {
      final (y, w, h) = ticks[i];
      final t = ticks.length == 1 ? 1.0 : i / (ticks.length - 1);
      final paint = Paint()
        ..color = color.withValues(alpha: color.a * (0.32 + 0.68 * t));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((128 - w / 2) * k, y * k, w * k, h * k),
          Radius.circular(h / 2 * k),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) =>
      old.color != color || old.small != small;
}
