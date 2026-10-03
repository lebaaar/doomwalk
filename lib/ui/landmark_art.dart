import 'package:flutter/material.dart';

import '../core/landmarks.dart';

/// A landmark's silhouette, filled in [color] up to [fraction] of its height
/// (or length, for landmarks measured end to end) over a [track] silhouette.
/// The fill animates to each new fraction; a new landmark starts from empty.
class LandmarkArt extends StatelessWidget {
  const LandmarkArt({
    super.key,
    required this.landmark,
    required this.fraction,
    required this.color,
    required this.track,
    this.height = 132,
    this.maxWidth = 120,
  });

  final Landmark landmark;
  final double fraction;
  final Color color;
  final Color track;
  final double height;

  /// Wide landmarks (a bus, a whale) shrink to fit this, keeping their shape.
  final double maxWidth;

  /// How long the fill takes to animate in.
  static const fillDuration = Duration(milliseconds: 1100);

  @override
  Widget build(BuildContext context) {
    final shape = _shapes[landmark.shape]!;
    final aspect = shape.size.width / shape.size.height;
    final w = (height * aspect).clamp(0.0, maxWidth);
    return Semantics(
      label: '${(fraction * 100).round()}% of ${landmark.refer}',
      child: TweenAnimationBuilder<double>(
        key: ValueKey(landmark.name),
        tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
        duration: fillDuration,
        curve: Curves.easeOutCubic,
        builder: (_, f, _) => SizedBox(
          width: w,
          height: w / aspect,
          child: CustomPaint(
            painter: _ArtPainter(shape, f, upright: landmark.upright, color: color, track: track),
          ),
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.shape, this.fraction, {required this.upright, required this.color, required this.track});

  final _Shape shape;
  final double fraction;
  final bool upright;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / shape.size.width;
    canvas.scale(s);
    final path = shape.path;
    final w = shape.size.width;
    final h = shape.size.height;
    canvas.drawPath(path, Paint()..color = track);
    if (fraction <= 0) return;
    canvas.save();
    canvas.clipRect(upright ? Rect.fromLTRB(0, h * (1 - fraction), w, h) : Rect.fromLTRB(0, 0, w * fraction, h));
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
    // "You are here": a short tick at the fill's edge.
    if (fraction >= 1) return;
    final tick = Paint()
      ..color = color
      ..strokeWidth = 1.2 / s * 2
      ..strokeCap = StrokeCap.round;
    if (upright) {
      final y = h * (1 - fraction);
      canvas.drawLine(Offset(-4, y), Offset(w + 4, y), tick);
    } else {
      final x = w * fraction;
      canvas.drawLine(Offset(x, -4), Offset(x, h + 4), tick);
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.fraction != fraction || old.shape != shape || old.color != color || old.track != track;
}

/// A silhouette drawn in its own [size] box, origin top left.
class _Shape {
  _Shape(this.size, Path Function() build) : path = build();
  final Size size;
  final Path path;
}

Path _poly(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

Path _rect(double l, double t, double w, double h) => Path()..addRect(Rect.fromLTWH(l, t, w, h));
Path _oval(double l, double t, double w, double h) => Path()..addOval(Rect.fromLTWH(l, t, w, h));

/// One outline from overlapping parts. Adding them to one path instead
/// would cut holes wherever two parts wind in opposite directions.
Path _union(List<Path> parts) => parts.reduce((a, b) => Path.combine(PathOperation.union, a, b));

final Map<LandmarkShape, _Shape> _shapes = {
  LandmarkShape.giraffe: _Shape(const Size(60, 100), () => _union([
        _rect(12, 68, 4, 32),
        _rect(20, 68, 4, 32),
        _rect(32, 68, 4, 32),
        _rect(40, 66, 4, 34),
        Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(9, 50, 38, 22), const Radius.circular(10))),
        _poly([36, 56, 46, 58, 54, 16, 47, 13]),
        _oval(44, 6, 15, 10),
        _rect(47, 0, 2, 8),
        _rect(52, 0, 2, 8),
        _poly([10, 54, 2, 72, 5, 73, 12, 58]),
      ])),
  LandmarkShape.bus: _Shape(const Size(100, 62), () {
    final windows = <Path>[
      for (var x = 6.0; x < 90; x += 15)
        Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 6, 11, 12), const Radius.circular(2))),
      for (var x = 21.0; x < 90; x += 15)
        Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 26, 11, 12), const Radius.circular(2))),
      _rect(5, 25, 11, 27), // door
    ];
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 52), const Radius.circular(6)));
    final cut = Path.combine(PathOperation.difference, body, _union(windows));
    return _union([
      cut,
      _oval(15, 44, 18, 18),
      _oval(69, 44, 18, 18),
    ]);
  }),
  LandmarkShape.whale: _Shape(const Size(100, 44), () => _union([
        Path()
          ..moveTo(2, 24)
          ..cubicTo(2, 8, 30, 4, 58, 10)
          ..cubicTo(70, 13, 78, 18, 86, 20)
          ..lineTo(98, 8)
          ..lineTo(94, 22)
          ..lineTo(99, 36)
          ..lineTo(85, 26)
          ..cubicTo(72, 34, 50, 40, 26, 38)
          ..cubicTo(12, 37, 2, 32, 2, 24)
          ..close(),
        _poly([36, 34, 46, 43, 50, 35]),
      ])),
  LandmarkShape.statue: _Shape(const Size(40, 100), () => _union([
        _poly([6, 100, 34, 100, 32, 71, 8, 71]),
        _rect(4, 66, 32, 5),
        _poly([11, 67, 29, 67, 25, 32, 15, 32]),
        _oval(14.5, 21, 11, 12),
        // The crown's rays.
        _poly([12, 25, 13, 18, 15.5, 23, 17, 15, 19.5, 22, 22, 15, 23.5, 23, 26, 18, 27, 25]),
        _poly([24, 36, 28, 36, 31, 10, 28, 9]),
        _poly([27, 10, 32, 10, 33, 4, 30, 0, 27, 4]),
        _poly([15, 40, 8, 44, 9, 47, 16, 44]),
      ])),
  LandmarkShape.tower: _Shape(const Size(60, 100), () => _union([
        Path()
          ..moveTo(3, 100)
          ..quadraticBezierTo(17, 72, 25, 40)
          ..lineTo(28, 10)
          ..lineTo(30, 0)
          ..lineTo(32, 10)
          ..lineTo(35, 40)
          ..quadraticBezierTo(43, 72, 57, 100)
          ..lineTo(45, 100)
          ..quadraticBezierTo(30, 72, 15, 100)
          ..close(),
        _rect(12, 68, 36, 4),
        _rect(21, 40, 18, 3),
        _rect(26, 18, 8, 2),
      ])),
  LandmarkShape.skyscraper: _Shape(const Size(40, 100), () => _union([
        _rect(6, 72, 28, 28),
        _rect(10, 48, 21, 25),
        _rect(13, 28, 14, 21),
        _rect(16, 14, 8, 15),
        _poly([18, 15, 22, 15, 20.4, 0, 19.6, 0]),
      ])),
  LandmarkShape.triglav: _Shape(const Size(100, 60), () => _poly([
        0, 60, 18, 36, 26, 40, 36, 22, 42, 26, 52, 2, 58, 12, 63, 9, 70, 20, //
        78, 18, 86, 34, 100, 60,
      ])),
  LandmarkShape.mountain: _Shape(const Size(100, 62), () => _poly([
        0, 62, 20, 32, 30, 38, 44, 16, 50, 20, 58, 0, 66, 14, 72, 10, 82, 28, 100, 62,
      ])),
  LandmarkShape.rocket: _Shape(const Size(40, 100), () => _union([
        Path()
          ..moveTo(20, 0)
          ..cubicTo(31, 12, 32, 40, 29, 72)
          ..lineTo(11, 72)
          ..cubicTo(8, 40, 9, 12, 20, 0)
          ..close(),
        _poly([11, 50, 2, 80, 11, 73]),
        _poly([29, 50, 38, 80, 29, 73]),
        _poly([14, 71, 26, 71, 20, 96]),
      ])),
};
