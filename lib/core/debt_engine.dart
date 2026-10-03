/// The debt ledger. Pure Dart: no Flutter imports, fully deterministic given
/// the timestamps passed in, so it is unit-tested in isolation.
///
/// Model (all distances in metres):
///   * Every counted scroll consumes the daily free allowance first
///     (chronologically). Only the excess is charged:
///       cost = excess * appRate * ratio * velocityWeight * (override ? penalty : 1)
///   * debt += cost. Walking pays debt down: debt = max(0, debt - walked).
///     Walking while debt-free does not bank credit (see DECISIONS.md).
///   * At each local midnight the allowance resets and unpaid debt accrues
///     overnight interest: debt += debt * interestRate.
library;

import 'dart:math' as math;

String dayKeyOf(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

DateTime _dayStart(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

DateTime _parseDayKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

class DebtConfig {
  const DebtConfig({
    this.allowanceM = 200,
    this.ratio = 2,
    this.frostMaxDebtM = 150,
    this.interestRate = 0.02,
    this.overridePenalty = 3,
    this.overridesPerDay = 3,
    this.overrideMinutes = 5,
    this.strideM = 0.75,
    this.demoMode = false,
  });

  /// Free scroll distance per local day.
  final double allowanceM;

  /// Metres you must walk per (rate-weighted) metre scrolled.
  final double ratio;

  /// Debt at which the frost reaches full strength.
  final double frostMaxDebtM;

  /// Fraction of unpaid debt added at each local midnight.
  final double interestRate;

  /// Cost multiplier applied while an emergency override is active.
  final double overridePenalty;
  final int overridesPerDay;
  final int overrideMinutes;

  /// Stride length used only by WalkTracker.
  final double strideM;

  /// Stage demo: tiny allowance, cheap ratio, frost after a few metres.
  final bool demoMode;

  static const demo = DebtConfig(allowanceM: 2, ratio: 1, frostMaxDebtM: 15);

  /// The values the engine actually uses (demo mode overrides the economy).
  DebtConfig get effective => demoMode
      ? copyWith(
          allowanceM: demo.allowanceM,
          ratio: demo.ratio,
          frostMaxDebtM: demo.frostMaxDebtM,
        )
      : this;

  DebtConfig copyWith({
    double? allowanceM,
    double? ratio,
    double? frostMaxDebtM,
    double? interestRate,
    double? overridePenalty,
    int? overridesPerDay,
    int? overrideMinutes,
    double? strideM,
    bool? demoMode,
  }) =>
      DebtConfig(
        allowanceM: allowanceM ?? this.allowanceM,
        ratio: ratio ?? this.ratio,
        frostMaxDebtM: frostMaxDebtM ?? this.frostMaxDebtM,
        interestRate: interestRate ?? this.interestRate,
        overridePenalty: overridePenalty ?? this.overridePenalty,
        overridesPerDay: overridesPerDay ?? this.overridesPerDay,
        overrideMinutes: overrideMinutes ?? this.overrideMinutes,
        strideM: strideM ?? this.strideM,
        demoMode: demoMode ?? this.demoMode,
      );

  Map<String, Object?> toJson() => {
        'allowanceM': allowanceM,
        'ratio': ratio,
        'frostMaxDebtM': frostMaxDebtM,
        'interestRate': interestRate,
        'overridePenalty': overridePenalty,
        'overridesPerDay': overridesPerDay,
        'overrideMinutes': overrideMinutes,
        'strideM': strideM,
        'demoMode': demoMode,
      };

  factory DebtConfig.fromJson(Map<String, Object?> j) {
    const d = DebtConfig();
    double n(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    return DebtConfig(
      allowanceM: n('allowanceM', d.allowanceM),
      ratio: n('ratio', d.ratio),
      frostMaxDebtM: n('frostMaxDebtM', d.frostMaxDebtM),
      interestRate: n('interestRate', d.interestRate),
      overridePenalty: n('overridePenalty', d.overridePenalty),
      overridesPerDay: i('overridesPerDay', d.overridesPerDay),
      overrideMinutes: i('overrideMinutes', d.overrideMinutes),
      strideM: n('strideM', d.strideM),
      demoMode: j['demoMode'] as bool? ?? d.demoMode,
    );
  }
}

class DebtState {
  DebtState({
    required this.dayKey,
    this.debtM = 0,
    this.allowanceUsedM = 0,
    this.scrolledTodayM = 0,
    this.chargedTodayM = 0,
    this.walkedTodayM = 0,
    this.paidTodayM = 0,
    this.peakDebtTodayM = 0,
    this.lastInterestM = 0,
    this.interestTotalM = 0,
    this.tamperChargedTodayM = 0,
    this.lifetimeScrolledM = 0,
    this.lifetimeWalkedM = 0,
    this.overridesUsedToday = 0,
    this.overrideUntilMs,
  });

  String dayKey;
  double debtM;
  double allowanceUsedM;
  double scrolledTodayM;
  double chargedTodayM;
  double walkedTodayM;
  double paidTodayM;

  /// Highest debt seen today (incl. carried-over debt); the widget's
  /// "progress toward zero" bar is measured against it.
  double peakDebtTodayM;

  /// Interest added at the most recent midnight.
  double lastInterestM;
  double interestTotalM;
  double tamperChargedTodayM;
  double lifetimeScrolledM;
  double lifetimeWalkedM;
  int overridesUsedToday;
  int? overrideUntilMs;

  factory DebtState.fresh(DateTime now) => DebtState(dayKey: dayKeyOf(now));

  Map<String, Object?> toJson() => {
        'dayKey': dayKey,
        'debtM': debtM,
        'allowanceUsedM': allowanceUsedM,
        'scrolledTodayM': scrolledTodayM,
        'chargedTodayM': chargedTodayM,
        'walkedTodayM': walkedTodayM,
        'paidTodayM': paidTodayM,
        'peakDebtTodayM': peakDebtTodayM,
        'lastInterestM': lastInterestM,
        'interestTotalM': interestTotalM,
        'tamperChargedTodayM': tamperChargedTodayM,
        'lifetimeScrolledM': lifetimeScrolledM,
        'lifetimeWalkedM': lifetimeWalkedM,
        'overridesUsedToday': overridesUsedToday,
        'overrideUntilMs': overrideUntilMs,
      };

  factory DebtState.fromJson(Map<String, Object?> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return DebtState(
      dayKey: j['dayKey'] as String,
      debtM: n('debtM'),
      allowanceUsedM: n('allowanceUsedM'),
      scrolledTodayM: n('scrolledTodayM'),
      chargedTodayM: n('chargedTodayM'),
      walkedTodayM: n('walkedTodayM'),
      paidTodayM: n('paidTodayM'),
      peakDebtTodayM: n('peakDebtTodayM'),
      lastInterestM: n('lastInterestM'),
      interestTotalM: n('interestTotalM'),
      tamperChargedTodayM: n('tamperChargedTodayM'),
      lifetimeScrolledM: n('lifetimeScrolledM'),
      lifetimeWalkedM: n('lifetimeWalkedM'),
      overridesUsedToday: (j['overridesUsedToday'] as num?)?.toInt() ?? 0,
      overrideUntilMs: (j['overrideUntilMs'] as num?)?.toInt(),
    );
  }
}

class ScrollCharge {
  const ScrollCharge({
    required this.rawM,
    required this.freeM,
    required this.costM,
  });
  final double rawM;
  final double freeM;
  final double costM;
}

/// Summary of one or more midnights that passed.
class RolloverResult {
  const RolloverResult({required this.closedDays, required this.interestM});
  final List<String> closedDays;
  final double interestM;
  bool get happened => closedDays.isNotEmpty;
}

class DebtEngine {
  DebtEngine({required this.config, required this.state});

  DebtConfig config;
  final DebtState state;

  DebtConfig get _e => config.effective;

  double get debtM => state.debtM;
  double get allowanceLeftM => math.max(0, _e.allowanceM - state.allowanceUsedM);

  /// 0 (no debt) .. 1 (debt >= frostMaxDebtM).
  double get frostLevel =>
      _e.frostMaxDebtM <= 0 ? 0 : (state.debtM / _e.frostMaxDebtM).clamp(0.0, 1.0);

  /// 0..1 progress from today's peak debt back to zero.
  double get progressToZero =>
      state.peakDebtTodayM <= 0 ? 1 : (1 - state.debtM / state.peakDebtTodayM).clamp(0.0, 1.0);

  bool overrideActive(DateTime now) =>
      state.overrideUntilMs != null && now.millisecondsSinceEpoch < state.overrideUntilMs!;

  int overridesLeft(DateTime now) {
    rollover(now);
    return math.max(0, _e.overridesPerDay - state.overridesUsedToday);
  }

  /// Advances the ledger to [now]'s local day, applying overnight interest
  /// once per midnight crossed (capped at 60 to bound pathological clocks).
  RolloverResult rollover(DateTime now) {
    final today = dayKeyOf(now);
    if (state.dayKey == today) return const RolloverResult(closedDays: [], interestM: 0);
    final from = _parseDayKey(state.dayKey);
    final to = _dayStart(now);
    if (to.isBefore(from)) {
      // Clock moved backwards: adopt the new day without interest.
      _resetDay(today);
      return const RolloverResult(closedDays: [], interestM: 0);
    }
    final closed = <String>[];
    var interest = 0.0;
    var cursor = from;
    var nights = 0;
    while (dayKeyOf(cursor) != today && nights < 60) {
      closed.add(dayKeyOf(cursor));
      final i = state.debtM * _e.interestRate;
      state.debtM += i;
      interest += i;
      nights++;
      // DST-safe "next day".
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    state.lastInterestM = interest;
    state.interestTotalM += interest;
    _resetDay(today);
    return RolloverResult(closedDays: closed, interestM: interest);
  }

  void _resetDay(String today) {
    state
      ..dayKey = today
      ..allowanceUsedM = 0
      ..scrolledTodayM = 0
      ..chargedTodayM = 0
      ..walkedTodayM = 0
      ..paidTodayM = 0
      ..tamperChargedTodayM = 0
      ..overridesUsedToday = 0
      ..overrideUntilMs = null
      ..peakDebtTodayM = state.debtM;
  }

  /// Charges a counted scroll of [metres] in an app with [appRate].
  /// Apps with rate 0 are whitelisted: not counted at all.
  ScrollCharge applyScroll({
    required double metres,
    required double appRate,
    required DateTime at,
    double velocityWeight = 1,
  }) {
    rollover(at);
    if (metres <= 0 || appRate <= 0) {
      return const ScrollCharge(rawM: 0, freeM: 0, costM: 0);
    }
    state.scrolledTodayM += metres;
    state.lifetimeScrolledM += metres;
    final free = math.min(metres, allowanceLeftM);
    state.allowanceUsedM += free;
    final excess = metres - free;
    final mult = overrideActive(at) ? _e.overridePenalty : 1.0;
    final cost = excess * appRate * _e.ratio * velocityWeight * mult;
    _addDebt(cost);
    return ScrollCharge(rawM: metres, freeM: free, costM: cost);
  }

  /// Adds an already-priced charge (e.g. tamper gaps), bypassing the allowance.
  double chargeFlat(double cost, DateTime at, {bool tamper = false}) {
    rollover(at);
    if (cost <= 0) return 0;
    _addDebt(cost);
    if (tamper) state.tamperChargedTodayM += cost;
    return cost;
  }

  void _addDebt(double cost) {
    state.debtM += cost;
    state.chargedTodayM += cost;
    if (state.debtM > state.peakDebtTodayM) state.peakDebtTodayM = state.debtM;
  }

  /// Applies walked distance. Returns the metres of debt actually paid.
  double applyWalk(double metres, DateTime at) {
    rollover(at);
    if (metres <= 0) return 0;
    state.walkedTodayM += metres;
    state.lifetimeWalkedM += metres;
    final paid = math.min(state.debtM, metres);
    state.debtM -= paid;
    state.paidTodayM += paid;
    if (state.debtM < 1e-9) state.debtM = 0;
    return paid;
  }

  /// Starts an emergency override if any are left today.
  bool startOverride(DateTime now) {
    rollover(now);
    if (overrideActive(now)) return true;
    if (state.overridesUsedToday >= _e.overridesPerDay) return false;
    state.overridesUsedToday++;
    state.overrideUntilMs =
        now.add(Duration(minutes: _e.overrideMinutes)).millisecondsSinceEpoch;
    return true;
  }

  void endOverride() => state.overrideUntilMs = null;
}
