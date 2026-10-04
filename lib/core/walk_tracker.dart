class WalkTracker {
  WalkTracker({this._strideM = 0.75, this._baseline});

  double _strideM;
  int? _baseline;

  int? get baseline => _baseline;

  set strideM(double v) {
    if (v > 0.2 && v < 2.0) _strideM = v;
  }

  double get strideM => _strideM;

  // Larger jumps mean a stale or foreign baseline and are dropped
  static const _maxJump = 40000;

  double onCounter(int cumulative) {
    final prev = _baseline;
    _baseline = cumulative;
    if (prev == null) return 0;
    var delta = cumulative - prev;
    if (delta < 0) delta = cumulative;
    if (delta > _maxJump) return 0;
    return delta * _strideM;
  }
}
