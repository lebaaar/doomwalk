/// Walking health maths. Pure Dart.
///
/// Energy: walking on flat ground at an ordinary pace burns roughly
/// 0.5 kcal per kg of body weight per km (ACSM walking equation at
/// ~5 km/h nets ~0.53 kcal/kg/km). It is an estimate, shown as such.
library;

const kcalPerKgKm = 0.53;

double kcalForWalk(double metres, double weightKg) =>
    metres <= 0 || weightKg <= 0 ? 0 : weightKg * (metres / 1000) * kcalPerKgKm;

/// Metres you'd need to walk to burn [kcal].
double metresForKcal(double kcal, double weightKg) =>
    kcal <= 0 || weightKg <= 0 ? 0 : kcal / (weightKg * kcalPerKgKm) * 1000;

/// Consecutive days meeting [goalM], counting back from the newest entry.
/// [newestFirst] holds walked metres per day, today first. Today counts
/// only once met, so an unfinished today doesn't break a running streak.
int walkStreak(List<double> newestFirst, double goalM) {
  if (goalM <= 0) return 0;
  var streak = 0;
  for (var i = 0; i < newestFirst.length; i++) {
    if (newestFirst[i] >= goalM) {
      streak++;
    } else if (i == 0) {
      continue; // today still in progress
    } else {
      break;
    }
  }
  return streak;
}
