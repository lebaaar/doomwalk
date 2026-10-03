/// Converts the hardware step counter into walked metres. Pure Dart.
///
/// This is the ONLY place steps exist. Everything downstream (ledger, UI,
/// storage) sees metres. The raw sensor reading is cumulative since boot, so
/// the tracker keeps an opaque baseline to compute deltas; it handles reboots
/// (counter goes down) and implausible jumps.
library;

class WalkTracker {
  WalkTracker({this._strideM = 0.75, this._baseline});

  double _strideM;
  int? _baseline;

  /// Opaque sensor baseline to persist across process restarts.
  int? get baseline => _baseline;

  set strideM(double v) {
    if (v > 0.2 && v < 2.0) _strideM = v;
  }

  double get strideM => _strideM;

  /// Max steps trusted from one reading (≈ 6 h of brisk walking). Larger
  /// jumps mean a stale or foreign baseline; they are dropped, not credited.
  static const _maxJump = 40000;

  /// Feeds a cumulative counter reading; returns metres walked since the
  /// previous reading (0 for the first one).
  double onCounter(int cumulative) {
    final prev = _baseline;
    _baseline = cumulative;
    if (prev == null) return 0;
    var delta = cumulative - prev;
    if (delta < 0) delta = cumulative; // counter reset by reboot
    if (delta > _maxJump) return 0;
    return delta * _strideM;
  }
}
