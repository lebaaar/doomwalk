/// The scroll wallet. Pure Dart: no Flutter imports, fully deterministic given
/// the timestamps passed in, so it is unit-tested in isolation.
///
/// Model (all distances in metres):
///   * Every counted scroll uses the daily free allowance first.
///   * Walking fills a bank. Past the allowance, scrolling is paid from the
///     bank at a price (metres walked per metre scrolled) that rises in steps
///     with how much you have scrolled past the allowance today:
///       price = min(maxPrice, 1 + floor(earned / priceStepM))
///     so the first [WalletConfig.priceStepM] cost 1:1, the next 2:1, and so on.
///   * Scrolling with an empty bank runs an overdraft (metres to walk). The
///     frost grows with it and is full at [WalletConfig.frostAtM]. Walking
///     clears the overdraft first, then fills the bank.
///   * During an emergency pass scrolling is free (nothing is charged).
///   * At local midnight everything resets: allowance, price, bank and
///     overdraft. No interest, nothing carried over.
library;

import 'dart:math' as math;

String dayKeyOf(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

class WalletConfig {
  const WalletConfig({
    this.allowanceM = 150,
    this.priceStepM = 100,
    this.maxPrice = 5,
    this.frostAtM = 20,
    this.overridesPerDay = 3,
    this.overrideMinutes = 5,
    this.strideM = 0.75,
    this.demoMode = false,
    this.weightKg = 70,
    this.walkGoalM = 5000,
  });

  /// Free scroll distance per local day.
  final double allowanceM;

  /// Scrolling past the allowance after which the price goes up by 1.
  final double priceStepM;

  /// The price never goes above this many metres walked per metre scrolled.
  final double maxPrice;

  /// Overdraft (metres to walk) at which the frost reaches full strength.
  final double frostAtM;

  final int overridesPerDay;
  final int overrideMinutes;

  /// Stride length used only by WalkTracker.
  final double strideM;

  /// Stage demo: tiny allowance, fast price steps, frost after a few metres.
  final bool demoMode;

  /// Body weight for calorie estimates.
  final double weightKg;

  /// Daily walking goal.
  final double walkGoalM;

  static const demo = WalletConfig(allowanceM: 2, priceStepM: 5, maxPrice: 3, frostAtM: 5);

  /// The values the wallet actually uses (demo mode overrides the economy).
  WalletConfig get effective => demoMode
      ? copyWith(
          allowanceM: demo.allowanceM,
          priceStepM: demo.priceStepM,
          maxPrice: demo.maxPrice,
          frostAtM: demo.frostAtM,
        )
      : this;

  WalletConfig copyWith({
    double? allowanceM,
    double? priceStepM,
    double? maxPrice,
    double? frostAtM,
    int? overridesPerDay,
    int? overrideMinutes,
    double? strideM,
    bool? demoMode,
    double? weightKg,
    double? walkGoalM,
  }) =>
      WalletConfig(
        allowanceM: allowanceM ?? this.allowanceM,
        priceStepM: priceStepM ?? this.priceStepM,
        maxPrice: maxPrice ?? this.maxPrice,
        frostAtM: frostAtM ?? this.frostAtM,
        overridesPerDay: overridesPerDay ?? this.overridesPerDay,
        overrideMinutes: overrideMinutes ?? this.overrideMinutes,
        strideM: strideM ?? this.strideM,
        demoMode: demoMode ?? this.demoMode,
        weightKg: weightKg ?? this.weightKg,
        walkGoalM: walkGoalM ?? this.walkGoalM,
      );

  Map<String, Object?> toJson() => {
        'allowanceM': allowanceM,
        'priceStepM': priceStepM,
        'maxPrice': maxPrice,
        'frostAtM': frostAtM,
        'overridesPerDay': overridesPerDay,
        'overrideMinutes': overrideMinutes,
        'strideM': strideM,
        'demoMode': demoMode,
        'weightKg': weightKg,
        'walkGoalM': walkGoalM,
      };

  factory WalletConfig.fromJson(Map<String, Object?> j) {
    const d = WalletConfig();
    double n(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    return WalletConfig(
      allowanceM: n('allowanceM', d.allowanceM),
      priceStepM: n('priceStepM', d.priceStepM),
      maxPrice: n('maxPrice', d.maxPrice),
      frostAtM: n('frostAtM', d.frostAtM),
      overridesPerDay: i('overridesPerDay', d.overridesPerDay),
      overrideMinutes: i('overrideMinutes', d.overrideMinutes),
      strideM: n('strideM', d.strideM),
      demoMode: j['demoMode'] as bool? ?? d.demoMode,
      weightKg: n('weightKg', d.weightKg),
      walkGoalM: n('walkGoalM', d.walkGoalM),
    );
  }

  /// The personal settings of a config saved by the old debt model (its
  /// economy fields mean something else now and are dropped).
  factory WalletConfig.fromLegacyJson(Map<String, Object?> j) {
    final old = WalletConfig.fromJson(j);
    return const WalletConfig().copyWith(
      overridesPerDay: old.overridesPerDay,
      overrideMinutes: old.overrideMinutes,
      strideM: old.strideM,
      demoMode: old.demoMode,
      weightKg: old.weightKg,
      walkGoalM: old.walkGoalM,
    );
  }
}

class WalletState {
  WalletState({
    required this.dayKey,
    this.allowanceUsedM = 0,
    this.scrolledTodayM = 0,
    this.earnedScrolledTodayM = 0,
    this.bankM = 0,
    this.overdraftM = 0,
    this.walkedTodayM = 0,
    this.spentTodayM = 0,
    this.tamperChargedTodayM = 0,
    this.lifetimeScrolledM = 0,
    this.lifetimeWalkedM = 0,
    this.overridesUsedToday = 0,
    this.overrideUntilMs,
  });

  String dayKey;
  double allowanceUsedM;
  double scrolledTodayM;

  /// Scrolled past the allowance today (outside passes); sets the price.
  double earnedScrolledTodayM;

  /// Walked metres not yet spent on scrolling.
  double bankM;

  /// Metres to walk: scrolling (or a tracking gap) the bank couldn't cover.
  double overdraftM;
  double walkedTodayM;

  /// Walking spent today: bank and overdraft charges for scrolling and gaps.
  double spentTodayM;
  double tamperChargedTodayM;
  double lifetimeScrolledM;
  double lifetimeWalkedM;
  int overridesUsedToday;
  int? overrideUntilMs;

  factory WalletState.fresh(DateTime now) => WalletState(dayKey: dayKeyOf(now));

  Map<String, Object?> toJson() => {
        'dayKey': dayKey,
        'allowanceUsedM': allowanceUsedM,
        'scrolledTodayM': scrolledTodayM,
        'earnedScrolledTodayM': earnedScrolledTodayM,
        'bankM': bankM,
        'overdraftM': overdraftM,
        'walkedTodayM': walkedTodayM,
        'spentTodayM': spentTodayM,
        'tamperChargedTodayM': tamperChargedTodayM,
        'lifetimeScrolledM': lifetimeScrolledM,
        'lifetimeWalkedM': lifetimeWalkedM,
        'overridesUsedToday': overridesUsedToday,
        'overrideUntilMs': overrideUntilMs,
      };

  /// Also reads a state saved by the old debt model: the day's totals and
  /// lifetime figures carry over, its debt does not.
  factory WalletState.fromJson(Map<String, Object?> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return WalletState(
      dayKey: j['dayKey'] as String,
      allowanceUsedM: n('allowanceUsedM'),
      scrolledTodayM: n('scrolledTodayM'),
      earnedScrolledTodayM: n('earnedScrolledTodayM'),
      bankM: n('bankM'),
      overdraftM: n('overdraftM'),
      walkedTodayM: n('walkedTodayM'),
      spentTodayM: n('spentTodayM'),
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

  /// Walking this scroll cost (from the bank and/or as overdraft).
  final double costM;
}

/// Metres walked per metre scrolled once [earned] metres past the allowance
/// have been scrolled today.
double priceAt(double earned, WalletConfig c) {
  if (c.priceStepM <= 0) return math.max(1, c.maxPrice);
  final p = 1 + (earned / c.priceStepM).floor();
  return math.min(p.toDouble(), math.max(1, c.maxPrice));
}

/// Walking needed to scroll [metres] more, starting [earned] metres past the
/// allowance. Walks the price steps one at a time.
double walkCost(double earned, double metres, WalletConfig c) {
  var cost = 0.0;
  var x = earned;
  var left = metres;
  while (left > 1e-12) {
    final price = priceAt(x, c);
    final capped = price >= math.max(1, c.maxPrice) || c.priceStepM <= 0;
    final room = capped ? left : math.min(left, _nextStep(x, c) - x);
    cost += room * price;
    x += room;
    left -= room;
  }
  return cost;
}

/// How far [bank] metres of walking lets you scroll, starting [earned]
/// metres past the allowance. The inverse of [walkCost].
double scrollFor(double earned, double bank, WalletConfig c) {
  var scroll = 0.0;
  var x = earned;
  var left = bank;
  while (left > 1e-12) {
    final price = priceAt(x, c);
    final capped = price >= math.max(1, c.maxPrice) || c.priceStepM <= 0;
    if (capped) return scroll + left / price;
    final room = _nextStep(x, c) - x;
    final take = math.min(room, left / price);
    scroll += take;
    x += take;
    left -= take * price;
    if (take < room) break;
  }
  return scroll;
}

/// The start of the price step after the one [x] is in. Rounding can leave
/// x a hair below a boundary, so tiny gaps jump to the next one.
double _nextStep(double x, WalletConfig c) {
  final next = ((x / c.priceStepM).floor() + 1) * c.priceStepM;
  return next - x < 1e-9 ? next + c.priceStepM : next;
}

class ScrollWallet {
  ScrollWallet({required this.config, required this.state});

  WalletConfig config;
  final WalletState state;

  WalletConfig get _e => config.effective;

  double get allowanceLeftM => math.max(0, _e.allowanceM - state.allowanceUsedM);
  double get bankM => state.bankM;
  double get overdraftM => state.overdraftM;

  /// Price of the next metre scrolled past the allowance.
  double get priceNow => priceAt(state.earnedScrolledTodayM, _e);

  /// How far the bank lets you scroll at today's prices.
  double get earnedScrollLeftM => scrollFor(state.earnedScrolledTodayM, state.bankM, _e);

  /// Walking that unlocks [metres] more scrolling past the allowance, on top
  /// of what is owed (the overdraft is cleared first).
  double walkToUnlock(double metres) =>
      state.overdraftM + math.max(0, walkCost(state.earnedScrolledTodayM, metres, _e) - state.bankM);

  /// 0 (nothing owed) .. 1 (overdraft >= frostAtM). Any overdraft at all
  /// shows a little frost, so it starts the moment the bank runs out.
  double get frostLevel =>
      _e.frostAtM <= 0 ? (state.overdraftM > 0 ? 1 : 0) : (state.overdraftM / _e.frostAtM).clamp(0.0, 1.0);

  bool overrideActive(DateTime now) =>
      state.overrideUntilMs != null && now.millisecondsSinceEpoch < state.overrideUntilMs!;

  /// Passes left on [now]'s day. Pure: a day nobody has rolled over to yet
  /// simply has all of them, without rolling the wallet from a getter.
  int overridesLeft(DateTime now) {
    final used = state.dayKey == dayKeyOf(now) ? state.overridesUsedToday : 0;
    return math.max(0, _e.overridesPerDay - used);
  }

  /// Moves the wallet to [now]'s local day. A new day (or a clock set back to
  /// another day) starts from scratch. Returns whether the day changed.
  bool rollover(DateTime now) {
    final today = dayKeyOf(now);
    if (state.dayKey == today) return false;
    state
      ..dayKey = today
      ..allowanceUsedM = 0
      ..scrolledTodayM = 0
      ..earnedScrolledTodayM = 0
      ..bankM = 0
      ..overdraftM = 0
      ..walkedTodayM = 0
      ..spentTodayM = 0
      ..tamperChargedTodayM = 0
      ..overridesUsedToday = 0
      ..overrideUntilMs = null;
    return true;
  }

  /// Charges a scroll of [metres] in an app that counts.
  ScrollCharge applyScroll({required double metres, required DateTime at}) {
    rollover(at);
    if (metres <= 0) return const ScrollCharge(rawM: 0, freeM: 0, costM: 0);
    state.scrolledTodayM += metres;
    state.lifetimeScrolledM += metres;
    if (overrideActive(at)) return ScrollCharge(rawM: metres, freeM: metres, costM: 0);
    final free = math.min(metres, allowanceLeftM);
    state.allowanceUsedM += free;
    final excess = metres - free;
    if (excess <= 0) return ScrollCharge(rawM: metres, freeM: free, costM: 0);
    final cost = walkCost(state.earnedScrolledTodayM, excess, _e);
    state.earnedScrolledTodayM += excess;
    _spend(cost);
    return ScrollCharge(rawM: metres, freeM: free, costM: cost);
  }

  /// Charges [cost] metres of walking for time without tracking: from the
  /// bank first, the rest as overdraft.
  double chargeGap(double cost, DateTime at) {
    rollover(at);
    if (cost <= 0) return 0;
    _spend(cost);
    state.tamperChargedTodayM += cost;
    return cost;
  }

  void _spend(double cost) {
    final fromBank = math.min(state.bankM, cost);
    state.bankM -= fromBank;
    state.overdraftM += cost - fromBank;
    state.spentTodayM += cost;
  }

  /// Applies walked distance: clears the overdraft first, the rest goes to
  /// the bank. Returns the metres that went to the bank.
  double applyWalk(double metres, DateTime at) {
    rollover(at);
    if (metres <= 0) return 0;
    state.walkedTodayM += metres;
    state.lifetimeWalkedM += metres;
    final paid = math.min(state.overdraftM, metres);
    state.overdraftM -= paid;
    if (state.overdraftM < 1e-9) state.overdraftM = 0;
    final banked = metres - paid;
    state.bankM += banked;
    return banked;
  }

  /// Starts an emergency pass if any are left today.
  bool startOverride(DateTime now) {
    rollover(now);
    if (overrideActive(now)) return true;
    if (state.overridesUsedToday >= _e.overridesPerDay) return false;
    state.overridesUsedToday++;
    state.overrideUntilMs = now.add(Duration(minutes: _e.overrideMinutes)).millisecondsSinceEpoch;
    return true;
  }

  void endOverride() => state.overrideUntilMs = null;
}
