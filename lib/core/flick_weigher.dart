/// Velocity weighting for scrolls. Pure Dart.
///
/// Slow, reading-paced scrolling is discounted; rapid repeated flicks are
/// surcharged. Speed is the metres scrolled in a package over the trailing
/// [window], so a single event cannot spike it.
library;

class FlickWeigher {
  FlickWeigher({
    this.window = const Duration(milliseconds: 1200),
    this.readingSpeed = 0.04,
    this.normalSpeed = 0.15,
    this.flickSpeed = 0.5,
    this.flickMemory = const Duration(seconds: 10),
    this.flicksForMax = 6,
    this.minWeight = 0.5,
    this.maxWeight = 1.6,
  });

  final Duration window;

  /// m/s at or below which scrolling counts as reading (minWeight).
  final double readingSpeed;

  /// m/s at which the weight reaches 1.0.
  final double normalSpeed;

  /// m/s above which a burst counts as a flick.
  final double flickSpeed;
  final Duration flickMemory;
  final int flicksForMax;
  final double minWeight;
  final double maxWeight;

  final _recent = <(int, double)>[];
  final _flicks = <int>[];
  String? _pkg;
  bool _inFlick = false;
  int? _lastT;

  /// A pause longer than this between events ends a burst.
  static const burstGapMs = 400;

  /// Returns the weight to apply to an event of [metres] at [tMs].
  double weigh(String pkg, double metres, int tMs) {
    if (pkg != _pkg) {
      _pkg = pkg;
      _recent.clear();
      _flicks.clear();
      _inFlick = false;
      _lastT = null;
    }
    if (_lastT != null && tMs - _lastT! > burstGapMs) _inFlick = false;
    _lastT = tMs;
    _recent.add((tMs, metres));
    _recent.removeWhere((e) => tMs - e.$1 > window.inMilliseconds);
    _flicks.removeWhere((t) => tMs - t > flickMemory.inMilliseconds);

    final total = _recent.fold<double>(0, (s, e) => s + e.$2);
    final speed = total / (window.inMilliseconds / 1000);

    if (speed >= flickSpeed) {
      if (!_inFlick) _flicks.add(tMs);
      _inFlick = true;
    } else {
      _inFlick = false;
    }

    if (speed <= readingSpeed) return minWeight;
    if (speed < normalSpeed) {
      final f = (speed - readingSpeed) / (normalSpeed - readingSpeed);
      return minWeight + (1 - minWeight) * f;
    }
    // Normal or fast: surcharge grows with the number of recent flicks.
    final repeated = (_flicks.length - 1).clamp(0, flicksForMax - 1);
    return 1 + (maxWeight - 1) * repeated / (flicksForMax - 1);
  }
}
