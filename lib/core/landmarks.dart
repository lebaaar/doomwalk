/// Landmark yardsticks for distances. Pure Dart.
library;

import 'dart:math' as math;

class Landmark {
  const Landmark(this.name, this.plural, this.heightM, this.glyph);
  final String name;
  final String plural;
  final double heightM;
  final String glyph;

  String count(double metres, {int decimals = 1}) {
    final n = metres / heightM;
    final s = n.toStringAsFixed(decimals);
    return '$s ${s == 1.0.toStringAsFixed(decimals) ? name : plural}';
  }
}

const eiffel = Landmark('Eiffel Tower', 'Eiffel Towers', 330, '🗼');
const burj = Landmark('Burj Khalifa', 'Burj Khalifas', 828, '🏙');
const everest = Landmark('Everest', 'Everests', 8849, '🏔');
const karman = Landmark('Kármán line', 'Kármán lines', 100000, '🚀');

const landmarks = [eiffel, burj, everest, karman];

enum LandmarkTier { today, week, lifetime }

extension LandmarkTierX on LandmarkTier {
  String get label => switch (this) {
        LandmarkTier.today => 'today',
        LandmarkTier.week => 'this week',
        LandmarkTier.lifetime => 'lifetime',
      };

  /// The yardstick that reads best at each time scale.
  Landmark get yardstick => switch (this) {
        LandmarkTier.today => eiffel,
        LandmarkTier.week => burj,
        LandmarkTier.lifetime => everest,
      };
}

/// "2.3 Eiffel Towers today"
String describeTier(double metres, LandmarkTier tier) =>
    '${tier.yardstick.count(metres)} ${tier.label}';

/// Landmark whose height is closest to [metres] on a log scale, so 200 m reads
/// as "0.6 Eiffel Towers" and 5 km as "0.6 Everests".
Landmark nearestLandmark(double metres) {
  if (metres <= 0) return eiffel;
  var best = landmarks.first;
  var bestD = double.infinity;
  for (final l in landmarks) {
    final d = (math.log(metres / l.heightM)).abs();
    if (d < bestD) {
      bestD = d;
      best = l;
    }
  }
  return best;
}

/// "0.6 Eiffel Towers"
String nearestText(double metres) => nearestLandmark(metres).count(metres);

class LandmarkProgress {
  const LandmarkProgress(this.next, this.fraction, this.passed);
  final Landmark next;
  final double fraction;
  final List<Landmark> passed;
}

/// Progress toward the next landmark not yet reached; past the Kármán line it
/// keeps counting Kármán lines.
LandmarkProgress progressToward(double metres) {
  final passed = landmarks.where((l) => metres >= l.heightM).toList();
  final next = landmarks.firstWhere((l) => metres < l.heightM, orElse: () => karman);
  final frac = metres < next.heightM ? metres / next.heightM : (metres / next.heightM) % 1;
  return LandmarkProgress(next, frac.clamp(0.0, 1.0), passed);
}
