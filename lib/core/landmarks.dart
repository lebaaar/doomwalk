/// Landmark yardsticks for distances. Pure Dart.
library;

import 'dart:math' as math;

/// The outline the Today screen draws for a landmark.
enum LandmarkShape { giraffe, bus, whale, statue, tower, skyscraper, triglav, mountain, rocket }

class Landmark {
  const Landmark(
    this.name,
    this.plural,
    this.heightM, {
    required this.refer,
    required this.emoji,
    required this.shape,
    this.upright = true,
  });
  final String name;
  final String plural;
  final double heightM;

  /// How a sentence names it: "a giraffe", "the Eiffel Tower".
  final String refer;
  final String emoji;
  final LandmarkShape shape;

  /// Measured top to bottom (a tower), or end to end when false (a bus).
  final bool upright;

  String count(double metres, {int decimals = 1}) {
    final n = metres / heightM;
    final s = n.toStringAsFixed(decimals);
    return '$s ${s == 1.0.toStringAsFixed(decimals) ? name : plural}';
  }
}

const giraffe = Landmark('giraffe', 'giraffes', 5.5,
    refer: 'a giraffe', emoji: '🦒', shape: LandmarkShape.giraffe);
const bus = Landmark('double-decker bus', 'double-decker buses', 11.2,
    refer: 'a double-decker bus', emoji: '🚌', shape: LandmarkShape.bus, upright: false);
const whale = Landmark('blue whale', 'blue whales', 30,
    refer: 'a blue whale', emoji: '🐋', shape: LandmarkShape.whale, upright: false);
const liberty = Landmark('Statue of Liberty', 'Statues of Liberty', 93,
    refer: 'the Statue of Liberty', emoji: '🗽', shape: LandmarkShape.statue);
const eiffel = Landmark('Eiffel Tower', 'Eiffel Towers', 330,
    refer: 'the Eiffel Tower', emoji: '🗼', shape: LandmarkShape.tower);
const burj = Landmark('Burj Khalifa', 'Burj Khalifas', 828,
    refer: 'the Burj Khalifa', emoji: '🏙️', shape: LandmarkShape.skyscraper);
const triglav = Landmark('Triglav', 'Triglavs', 2864,
    refer: 'Triglav', emoji: '⛰️', shape: LandmarkShape.triglav);
const everest = Landmark('Everest', 'Everests', 8849,
    refer: 'Everest', emoji: '🏔️', shape: LandmarkShape.mountain);
const karman = Landmark('Kármán line', 'Kármán lines', 100000,
    refer: 'the Kármán line', emoji: '🚀', shape: LandmarkShape.rocket);

/// The big yardsticks, for counting ("2.3 Eiffel Towers").
const landmarks = [eiffel, burj, everest, karman];

/// Every landmark, smallest first: today's climb goes up these one by one, so
/// there is always a next one close by.
const climb = [giraffe, bus, whale, liberty, eiffel, burj, triglav, everest, karman];

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

/// Landmark of [ladder] whose height is closest to [metres] on a log scale,
/// so 200 m reads as "0.6 Eiffel Towers" and 5 km as "0.6 Everests".
Landmark nearestLandmark(double metres, {List<Landmark> ladder = landmarks}) {
  if (metres <= 0) return ladder == landmarks ? eiffel : ladder.first;
  var best = ladder.first;
  var bestD = double.infinity;
  for (final l in ladder) {
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

/// Progress toward the next landmark of [ladder] not yet reached; past the
/// Kármán line it keeps counting Kármán lines.
LandmarkProgress progressToward(double metres, {List<Landmark> ladder = landmarks}) {
  final passed = ladder.where((l) => metres >= l.heightM).toList();
  final next = ladder.firstWhere((l) => metres < l.heightM, orElse: () => ladder.last);
  final frac = metres < next.heightM ? metres / next.heightM : (metres / next.heightM) % 1;
  return LandmarkProgress(next, frac.clamp(0.0, 1.0), passed);
}

/// A pop-up over the open app the moment today's scrolling passes [metres].
class Milestone {
  const Milestone(this.metres, this.title, this.body);
  final double metres;
  final String title;
  final String body;
}

final milestones = [
  const Milestone(1, '1 metre scrolled', 'Your thumb has officially left the building.'),
  Milestone(giraffe.heightM, 'Taller than a giraffe 🦒', '5.5 m already. Well above average, and not in a good way.'),
  Milestone(bus.heightM, 'Longer than a double-decker bus 🚌', 'Mind the gap. And the time.'),
  Milestone(whale.heightM, 'You scrolled a blue whale 🐋', 'The biggest animal that ever lived, nose to tail.'),
  Milestone(liberty.heightM, 'Statue of Liberty climbed 🗽', 'Give me your tired, your poor, your doomscrolling.'),
  Milestone(eiffel.heightM, 'You scaled the Eiffel Tower 🗼', 'Paris is proud. Your thumb is exhausted.'),
  Milestone(burj.heightM, 'Burj Khalifa conquered 🏙️', 'The tallest building on Earth, and it isn\'t even dinner time.'),
  Milestone(triglav.heightM, 'On top of Triglav ⛰️', 'Every Slovene should climb it once. Not like this.'),
  Milestone(everest.heightM, 'Everest summit 🏔️', 'No oxygen, no sherpas, just reels.'),
  Milestone(karman.heightM, 'You scrolled to space 🚀', '100 km. Your thumb is officially an astronaut.'),
];

/// The biggest milestone that scrolling from [before] to [after] metres
/// passed, or null. Several at once (a big jump) show only the last.
Milestone? milestoneCrossed(double before, double after) {
  Milestone? hit;
  for (final m in milestones) {
    if (before < m.metres && after >= m.metres) hit = m;
  }
  return hit;
}
