import 'dart:math' as math;

enum LandmarkShape {
  giraffe,
  bus,
  whale,
  statue,
  tower,
  skyscraper,
  triglav,
  mountain,
  rocket,
}

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

  final String refer;
  final String emoji;
  final LandmarkShape shape;

  final bool upright;

  String count(double metres, {int decimals = 1}) {
    final n = metres / heightM;
    final s = n.toStringAsFixed(decimals);
    return '$s ${s == 1.0.toStringAsFixed(decimals) ? name : plural}';
  }
}

const giraffe = Landmark(
  'giraffe',
  'giraffes',
  5.5,
  refer: 'a giraffe',
  emoji: '🦒',
  shape: LandmarkShape.giraffe,
);
const bus = Landmark(
  'double-decker bus',
  'double-decker buses',
  11.2,
  refer: 'a double-decker bus',
  emoji: '🚌',
  shape: LandmarkShape.bus,
  upright: false,
);
const whale = Landmark(
  'blue whale',
  'blue whales',
  30,
  refer: 'a blue whale',
  emoji: '🐋',
  shape: LandmarkShape.whale,
  upright: false,
);
const liberty = Landmark(
  'Statue of Liberty',
  'Statues of Liberty',
  93,
  refer: 'the Statue of Liberty',
  emoji: '🗽',
  shape: LandmarkShape.statue,
);
const eiffel = Landmark(
  'Eiffel Tower',
  'Eiffel Towers',
  330,
  refer: 'the Eiffel Tower',
  emoji: '🗼',
  shape: LandmarkShape.tower,
);
const burj = Landmark(
  'Burj Khalifa',
  'Burj Khalifas',
  828,
  refer: 'the Burj Khalifa',
  emoji: '🏙️',
  shape: LandmarkShape.skyscraper,
);
const triglav = Landmark(
  'Triglav',
  'Triglavs',
  2864,
  refer: 'Triglav',
  emoji: '⛰️',
  shape: LandmarkShape.triglav,
);
const everest = Landmark(
  'Everest',
  'Everests',
  8849,
  refer: 'Everest',
  emoji: '🏔️',
  shape: LandmarkShape.mountain,
);
const karman = Landmark(
  'Kármán line',
  'Kármán lines',
  100000,
  refer: 'the Kármán line',
  emoji: '🚀',
  shape: LandmarkShape.rocket,
);

const landmarks = [eiffel, burj, everest, karman];

const climb = [
  giraffe,
  bus,
  whale,
  liberty,
  eiffel,
  burj,
  triglav,
  everest,
  karman,
];

enum LandmarkTier { today, week, lifetime }

extension LandmarkTierX on LandmarkTier {
  String get label => switch (this) {
    LandmarkTier.today => 'today',
    LandmarkTier.week => 'this week',
    LandmarkTier.lifetime => 'lifetime',
  };

  Landmark get yardstick => switch (this) {
    LandmarkTier.today => eiffel,
    LandmarkTier.week => burj,
    LandmarkTier.lifetime => everest,
  };
}

String describeTier(double metres, LandmarkTier tier) =>
    '${tier.yardstick.count(metres)} ${tier.label}';

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

String nearestText(double metres) => nearestLandmark(metres).count(metres);

class LandmarkProgress {
  const LandmarkProgress(this.next, this.fraction, this.passed);
  final Landmark next;
  final double fraction;
  final List<Landmark> passed;
}

LandmarkProgress progressToward(
  double metres, {
  List<Landmark> ladder = landmarks,
}) {
  final passed = ladder.where((l) => metres >= l.heightM).toList();
  final next = ladder.firstWhere(
    (l) => metres < l.heightM,
    orElse: () => ladder.last,
  );
  final frac = metres < next.heightM
      ? metres / next.heightM
      : (metres / next.heightM) % 1;
  return LandmarkProgress(next, frac.clamp(0.0, 1.0), passed);
}
