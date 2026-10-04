// Tried in order: scrollDeltaY, absolute scrollY, first visible item index (a pager flip counts one screen), then a rate-limited 0.25 screen estimate

import 'units.dart';

class RawScroll {
  const RawScroll({
    required this.pkg,
    required this.cls,
    required this.timeMs,
    this.windowId = -1,
    this.dx = -1,
    this.dy = -1,
    this.scrollY = -1,
    this.maxScrollY = -1,
    this.fromIndex = -1,
    this.toIndex = -1,
    this.itemCount = -1,
  });

  final String pkg;
  final String cls;
  final int timeMs;
  final int windowId;
  final int dx;
  final int dy;
  final int scrollY;
  final int maxScrollY;
  final int fromIndex;
  final int toIndex;
  final int itemCount;

  String get key => '$pkg|$cls|$windowId';

  factory RawScroll.fromMap(Map<Object?, Object?> m) {
    int i(String k) => (m[k] as num?)?.toInt() ?? -1;
    return RawScroll(
      pkg: m['pkg'] as String? ?? '',
      cls: m['cls'] as String? ?? '',
      timeMs: i('t'),
      windowId: i('win'),
      dx: i('dx'),
      dy: i('dy'),
      scrollY: i('sy'),
      maxScrollY: i('msy'),
      fromIndex: i('from'),
      toIndex: i('to'),
      itemCount: i('count'),
    );
  }
}

enum ScrollSource { deltaY, scrollY, itemIndex, estimate, none }

class InterpretedScroll {
  const InterpretedScroll(this.pixels, this.metres, this.source);
  final double pixels;
  final double metres;
  final ScrollSource source;
}

class ScrollInterpreter {
  ScrollInterpreter({required this.screenHeightPx, required this.ydpi});

  double screenHeightPx;
  double ydpi;

  final _lastScrollY = <String, int>{};
  final _lastFrom = <String, int>{};
  final _lastEstimate = <String, int>{};

  static const estimateFraction = 0.25;
  static const estimateMinGapMs = 300;

  double get _cap => screenHeightPx * 3;

  InterpretedScroll interpret(RawScroll e) {
    final px = _pixels(e);
    final clamped = px.$1.clamp(0.0, _cap);
    return InterpretedScroll(clamped, pixelsToMetres(clamped, ydpi), px.$2);
  }

  (double, ScrollSource) _pixels(RawScroll e) {
    final k = e.key;
    final prevY = _lastScrollY[k];
    final prevFrom = _lastFrom[k];
    if (e.scrollY >= 0) _lastScrollY[k] = e.scrollY;
    if (e.fromIndex >= 0) _lastFrom[k] = e.fromIndex;

    if (e.dy > 0 || e.dy < -1)
      return (e.dy.abs().toDouble(), ScrollSource.deltaY);
    if (e.dx != 0 && e.dx != -1 && e.dy == 0) return (0, ScrollSource.none);

    if (e.scrollY >= 0 && prevY != null) {
      final d = (e.scrollY - prevY).abs();
      if (d > 0) return (d.toDouble(), ScrollSource.scrollY);
      if (e.fromIndex < 0) return (0, ScrollSource.scrollY);
    }

    if (e.fromIndex >= 0) {
      if (prevFrom == null || prevFrom == e.fromIndex)
        return (0, ScrollSource.itemIndex);
      final visible = (e.toIndex >= e.fromIndex)
          ? (e.toIndex - e.fromIndex + 1)
          : 1;
      final items = (e.fromIndex - prevFrom).abs();
      return (items * screenHeightPx / visible, ScrollSource.itemIndex);
    }

    if (e.scrollY >= 0) return (0, ScrollSource.scrollY);

    final last = _lastEstimate[k];
    if (last != null && e.timeMs - last < estimateMinGapMs)
      return (0, ScrollSource.estimate);
    _lastEstimate[k] = e.timeMs;
    return (screenHeightPx * estimateFraction, ScrollSource.estimate);
  }
}
