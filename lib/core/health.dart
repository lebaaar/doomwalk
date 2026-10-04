// ACSM walking equation at ~5 km/h nets ~0.53 kcal/kg/km
const kcalPerKgKm = 0.53;

double kcalForWalk(double metres, double weightKg) =>
    metres <= 0 || weightKg <= 0 ? 0 : weightKg * (metres / 1000) * kcalPerKgKm;

double metresForKcal(double kcal, double weightKg) =>
    kcal <= 0 || weightKg <= 0 ? 0 : kcal / (weightKg * kcalPerKgKm) * 1000;

// Today counts only once met, so an unfinished today doesn't break a running streak
int walkStreak(List<double> newestFirst, double goalM) {
  if (goalM <= 0) return 0;
  var streak = 0;
  for (var i = 0; i < newestFirst.length; i++) {
    if (newestFirst[i] >= goalM) {
      streak++;
    } else if (i == 0) {
      continue;
    } else {
      break;
    }
  }
  return streak;
}
