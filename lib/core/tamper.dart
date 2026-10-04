import 'dart:math' as math;

class TamperGap {
  const TamperGap({
    required this.start,
    required this.end,
    required this.reason,
  });
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

  final Duration minGap;

  final double maxChargedHours;
  final double wakingHoursPerDay;

  final double fallbackMetresPerHour;

  double averageMetresPerHour(List<double> dailyRawMetres) {
    final days = dailyRawMetres.where((m) => m > 0).toList();
    if (days.isEmpty) return fallbackMetresPerHour;
    final total = days.fold<double>(0, (s, m) => s + m);
    return total / (days.length * wakingHoursPerDay);
  }

  double rawMetresFor(TamperGap gap, double avgMetresPerHour) {
    if (gap.length < minGap) return 0;
    final hours = math.min(gap.length.inSeconds / 3600, maxChargedHours);
    return hours * avgMetresPerHour;
  }

  double costFor(TamperGap gap, double avgMetresPerHour) =>
      rawMetresFor(gap, avgMetresPerHour);
}
