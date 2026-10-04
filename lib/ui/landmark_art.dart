import 'package:flutter/material.dart';

import '../core/landmarks.dart';

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

  final double maxWidth;

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
            painter: _ArtPainter(
              shape,
              f,
              upright: landmark.upright,
              color: color,
              track: track,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(
    this.shape,
    this.fraction, {
    required this.upright,
    required this.color,
    required this.track,
  });

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
    canvas.clipRect(
      upright
          ? Rect.fromLTRB(0, h * (1 - fraction), w, h)
          : Rect.fromLTRB(0, 0, w * fraction, h),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
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
      old.fraction != fraction ||
      old.shape != shape ||
      old.color != color ||
      old.track != track;
}

class _Shape {
  _Shape(this.size, Path Function() build) : path = build();
  final Size size;
  final Path path;
}

Path _d(String svg) {
  final tokens = RegExp(r'[MLHVCQZ]|-?\d*\.?\d+')
      .allMatches(svg)
      .map((m) => m[0]!)
      .toList();
  final p = Path();
  var i = 0;
  var x = 0.0;
  var y = 0.0;
  double n() => double.parse(tokens[i++]);
  var cmd = 'M';
  while (i < tokens.length) {
    if (RegExp(r'[A-Z]').hasMatch(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        p.moveTo(x = n(), y = n());
        cmd = 'L';
      case 'L':
        p.lineTo(x = n(), y = n());
      case 'H':
        p.lineTo(x = n(), y);
      case 'V':
        p.lineTo(x, y = n());
      case 'C':
        p.cubicTo(n(), n(), n(), n(), x = n(), y = n());
      case 'Q':
        p.quadraticBezierTo(n(), n(), x = n(), y = n());
      case 'Z':
        p.close();
    }
  }
  return p;
}

Path _rect(double l, double t, double w, double h) =>
    Path()..addRect(Rect.fromLTWH(l, t, w, h));
Path _oval(double l, double t, double w, double h) =>
    Path()..addOval(Rect.fromLTWH(l, t, w, h));
Path _round(double l, double t, double w, double h, double r) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)),
  );

Path _union(List<Path> parts) =>
    parts.reduce((a, b) => Path.combine(PathOperation.union, a, b));

Path _cut(Path shape, List<Path> holes) =>
    Path.combine(PathOperation.difference, shape, _union(holes));

final Map<LandmarkShape, _Shape> _shapes = {
  LandmarkShape.giraffe: _Shape(
    const Size(60, 100),
    () => _cut(
      _union([
        _d(
          'M8 57 C8 50 13 47 21 48 L38 45 C45 44 50 48 50 54 C50 61 45 64 38 64 L18 65 C11 65 8 62 8 57 Z',
        ),
        for (final (x, top) in [
          (11.0, 60.0),
          (18.0, 61.0),
          (37.0, 59.0),
          (44.0, 57.0),
        ])
          _d(
            'M$x $top L${x + 4.5} $top L${x + 3.6} 79 L${x + 4} 97 L${x + 4.6} 100 L$x 100 '
            'L${x + 0.4} 97 L${x + 0.6} 79 Z',
          ),
        _d('M37 52 C40 40 43 28 45 17 L51.5 15.5 C51 28 50 40 50 52 Z'),
        _d(
          'M43.5 17 C43.5 12.5 47 10 51 10.5 L57.5 13.5 C60 14.8 60 18.2 57.5 19 L51 20 '
          'C47 21 43.5 20.5 43.5 17 Z',
        ),
        _d('M46.6 12 L47.2 5 L48.8 5 L49.2 11.6 Z'),
        _oval(46.4, 2.8, 3.2, 3.2),
        _d('M50.4 11.4 L51 4.6 L52.6 4.6 L52.8 11.8 Z'),
        _oval(50.2, 2.4, 3.2, 3.2),
        _d('M45 13.5 L39.5 11 L44.6 16.5 Z'),
        _d('M9.6 52 C6.5 59 5 65 4.6 73 L6.2 73 C6.8 65 8.5 59 11.6 54 Z'),
        _oval(3.2, 71, 4.4, 6),
      ]),
      [_oval(52.8, 13.6, 2, 2)],
    ),
  ),
  LandmarkShape.bus: _Shape(
    const Size(100, 62),
    () => _cut(
      _union([
        _cut(_d('M7 0 H88 C95 0 100 5 100 12 V51 H0 V7 C0 3 3 0 7 0 Z'), [
          for (final x in [5.0, 21.0, 37.0, 53.0, 69.0])
            _round(x, 6, 13, 12, 2),
          _round(85, 6, 10, 12, 2),
          for (final x in [5.0, 21.0, 37.0, 53.0]) _round(x, 25, 13, 12, 2),
          _round(69, 25, 10, 12, 2),
          _round(84, 25, 11, 22, 2),
          _rect(0, 21, 100, 1.4),
          _oval(9, 40, 22, 22),
          _oval(63, 40, 22, 22),
        ]),
        _oval(11.5, 42.5, 17, 17),
        _oval(65.5, 42.5, 17, 17),
      ]),
      [_oval(17, 48, 6, 6), _oval(71, 48, 6, 6)],
    ),
  ),
  LandmarkShape.whale: _Shape(
    const Size(100, 40),
    () => _cut(
      _union([
        _d(
          'M1 18 C1 11 9 7.5 22 7.5 C44 7.5 66 11 83 16 L90.5 8.5 C92.5 6.5 96.5 7.5 96 10.5 L93.8 18.5 '
          'C93.6 19.6 93.6 20.6 94 21.6 L97.6 28.6 C98.4 31.6 95 32.8 92.8 31 L83 23.5 '
          'C68 29 48 32.5 27 31.8 C11 31.2 1 26 1 18 Z',
        ),
        _d('M67 12.6 C69.5 10.5 72 8 74.6 6.8 C74.2 9.5 74.2 12 75.2 14.4 Z'),
        _d('M24 27.5 C28 33 34 37 41.5 39 C38.5 35 36.5 31.5 35.6 28.2 Z'),
      ]),
      [
        _d('M3 21 C10 22.6 18 22.8 27 22 L27 23 C18 23.8 10 23.6 3.2 22.2 Z'),
        _oval(10.4, 15.4, 2.4, 2.4),
      ],
    ),
  ),
  LandmarkShape.statue: _Shape(
    const Size(40, 100),
    () => _cut(
      _union([
        _d('M5 100 H35 V95 H32.5 V79 H34.5 V74.5 H5.5 V79 H7.5 V95 H5 Z'),
        _rect(9, 70.5, 22, 4.5),
        _d(
          'M12 71 C12 59 13 47 14.5 38.5 C16.5 35.5 23.5 35.5 25.5 38.5 C27 47 28 59 28 71 Z',
        ),
        _oval(16, 25.4, 8, 9.6),
        _d(
          'M14.4 28.6 L10.6 23.4 L15.6 25.8 L15 19.6 L18.4 24.2 L20 17.4 L21.6 24.2 L25 19.6 L24.4 25.8 '
          'L29.4 23.4 L25.6 28.6 Z',
        ),
        _d('M22.6 39 L25.8 37.6 L30.6 13.4 L27.8 12.8 Z'),
        _d('M26.4 9 H32.4 L31.2 13.6 H27.6 Z'),
        _d('M29.4 0 C31.8 3 32.4 6 29.4 8.6 C26.4 6 27 3 29.4 0 Z'),
        _d('M9.4 40.4 L14.6 39 L16 53.6 L10.8 55 Z'),
      ]),
      [_rect(9, 78, 22, 1.2), _rect(9, 91, 22, 1.2)],
    ),
  ),
  LandmarkShape.tower: _Shape(
    const Size(60, 100),
    () => _cut(
      _union([
        _d(
          'M2 100 C10 88 15 78 17 66 L43 66 C45 78 50 88 58 100 L47.5 100 C44 88 37 80.5 30 80.5 '
          'C23 80.5 16 88 12.5 100 Z',
        ),
        _rect(10, 63, 40, 4.5),
        _d(
          'M17.5 63.5 C19.5 55 21 49 22.2 44 L37.8 44 C39 49 40.5 55 42.5 63.5 Z',
        ),
        _rect(18.5, 41, 23, 3.5),
        _d('M22.5 41.5 C25 30 27 20 28.2 11 L31.8 11 C33 20 35 30 37.5 41.5 Z'),
        _rect(26.8, 7, 6.4, 4.5),
        _rect(29.3, 0, 1.4, 8),
      ]),
      [
        _d(
          'M24.6 63.2 C26 57.5 28.2 53.4 30 52.6 C31.8 53.4 34 57.5 35.4 63.2 Z',
        ),
        _d('M30 24 L31.2 35 L30 39 L28.8 35 Z'),
      ],
    ),
  ),
  LandmarkShape.skyscraper: _Shape(
    const Size(40, 100),
    () => _cut(
      _d(
        'M4 100 V86 H7 V74 H10 V62 H12.5 V50 H14.5 V38 H16.3 V28 H17.6 V18 H19.2 L19.7 4 L20 0 '
        'L20.3 4 L20.8 18 H22.4 V22 H23.7 V32 H25.5 V44 H27.5 V56 H30 V68 H33 V80 H36 V100 Z',
      ),
      [_rect(19.4, 30, 1.2, 70), _rect(12, 66, 1, 34), _rect(27, 60, 1, 40)],
    ),
  ),
  LandmarkShape.triglav: _Shape(
    const Size(100, 60),
    () => _cut(
      _d(
        'M0 60 L18 34 L24 38 L34 20 L42 28 L52 3 L62 26 L70 19 L80 33 L86 30 L100 60 Z',
      ),
      [_d('M44 23 L52 3 L60.6 23 L57.6 20.2 L54.6 24.6 L51.6 20.4 L48.4 25 Z')],
    ),
  ),
  LandmarkShape.mountain: _Shape(
    const Size(100, 62),
    () => _cut(
      _d(
        'M0 62 L14 41 L20 44 L31 27 L37 31 L52 2 L60 14 L64 12 L73 23 L79 21 L88 36 L100 62 Z',
      ),
      [
        _d(
          'M42.6 20.4 L52 2 L60 14 L64 12 L67 15.6 L63.2 15 L60 19.6 L56.4 16.6 L53 22.6 L49.6 18.4 L46 23.6 Z',
        ),
      ],
    ),
  ),
  LandmarkShape.rocket: _Shape(
    const Size(40, 100),
    () => _cut(
      _union([
        _cut(
          _union([
            _d('M20 0 C27.5 7 30 19 30 34 V73 H10 V34 C10 19 12.5 7 20 0 Z'),
            _d('M10 50 L2.5 64 V81 L10 74 Z'),
            _d('M30 50 L37.5 64 V81 L30 74 Z'),
            _d('M12.5 73 H27.5 L29 79 H11 Z'),
            _d('M14 81.5 H26 C26 89 23 94 20 100 C17 94 14 89 14 81.5 Z'),
          ]),
          [_oval(14.5, 26.5, 11, 11)],
        ),
        _oval(16.7, 28.7, 6.6, 6.6),
      ]),
      [_rect(10, 15, 20, 1.4), _rect(10, 58, 20, 1.4)],
    ),
  ),
};
