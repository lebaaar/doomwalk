/// Tamper-gap charging. Pure Dart.
///
/// A gap is time during which scroll tracking was off for a reason the user
/// controls (accessibility service switched off, app force-stopped). Gaps are
/// charged as if the user had scrolled at their own average rate.
library;

import 'dart:math' as math;

class TamperGap {
  const TamperGap({required this.start, required this.end, required this.reason});
  final DateTime start;
  final DateTime end;
  final String reason;
  Duration get length => end.difference(start);
}

class TamperPolicy {
  const TamperPolicy({
    this.minGap = const Duration(minutes: 2),
    this.maxChargedHours = 16,
    this.wakingHoursPerDay = 16,
    this.fallbackMetresPerHour = 25,
  });

  /// Gaps shorter than this are ignored (service restarts, updates).
  final Duration minGap;

  /// Cap on hours charged for a single gap (nobody scrolls while asleep).
  final double maxChargedHours;
  final double wakingHoursPerDay;

  /// Used until there is a day of history.
  final double fallbackMetresPerHour;

  /// Average raw scroll metres per waking hour over [dailyRawMetres]
  /// (one entry per tracked day, most recent days).
  double averageMetresPerHour(List<double> dailyRawMetres) {
    final days = dailyRawMetres.where((m) => m > 0).toList();
    if (days.isEmpty) return fallbackMetresPerHour;
    final total = days.fold<double>(0, (s, m) => s + m);
    return total / (days.length * wakingHoursPerDay);
  }

  /// Raw metres to charge for [gap].
  double rawMetresFor(TamperGap gap, double avgMetresPerHour) {
    if (gap.length < minGap) return 0;
    final hours = math.min(gap.length.inSeconds / 3600, maxChargedHours);
    return hours * avgMetresPerHour;
  }

  /// Walking charged for [gap]: one metre per metre of estimated scrolling.
  double costFor(TamperGap gap, double avgMetresPerHour) => rawMetresFor(gap, avgMetresPerHour);
}
