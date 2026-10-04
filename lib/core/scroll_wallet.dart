/// The scroll wallet. Pure Dart: no Flutter imports, fully deterministic given
/// the timestamps passed in, so it is unit-tested in isolation.
///
/// Model (all distances in metres):
///   * The bank holds metres of scrolling. Each day starts with it empty.
///   * Walking adds to the bank, up to [WalletConfig.bankCapM]; walking while
///     it is full counts for nothing. A metre walked adds 1 / price metres,
///     where the price rises in steps with what you have scrolled today:
///       price = min(maxPrice, startPrice + floor(scrolledToday / priceStepM))
///   * Scrolling spends the bank. With the bank empty it runs an overdraft
///     (metres of scrolling owed); the frost grows with it and is full at
///     [WalletConfig.frostAtM]. Walking pays the overdraft first.
///   * During an emergency pass scrolling is free (nothing is charged).
///   * At local midnight everything resets: bank, overdraft and price.
library;

import 'dart:math' as math;

String dayKeyOf(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

class WalletConfig {
  const WalletConfig({
    this.bankCapM = 50,
    this.startPrice = 2,
    this.priceStepM = 50,
    this.maxPrice = 6,
    this.frostAtM = 20,
    this.overridesPerDay = 3,
    this.overrideMinutes = 5,
    this.strideM = 0.75,
    this.weightKg = 70,
    this.stepGoal = defaultStepGoal,
  });

  /// Most scrolling the bank can hold.
  final double bankCapM;

  /// Metres walked per metre of scrolling at the start of the day.
  final double startPrice;

  /// Every this much scrolled today, a metre of scrolling costs one more
  /// metre of walking.
  final double priceStepM;

  /// The price never goes above this many metres walked per metre scrolled.
  final double maxPrice;

  /// Overdraft (metres of scrolling owed) at which the frost is full.
  final double frostAtM;

  final int overridesPerDay;
  final int overrideMinutes;

  /// Stride length used only by WalkTracker.
  final double strideM;

  /// Body weight for calorie estimates.
  final double weightKg;

  /// Daily walking goal, in steps.
  final int stepGoal;

  static const defaultStepGoal = 10000;
  static const minStepGoal = 1000;
  static const maxStepGoal = 30000;

  /// The step goal as a distance, at the current stride.
  double get walkGoalM => stepGoal * strideM;

  static const maxBankCapM = 100.0;
  static const minBankCapM = 20.0;

  WalletConfig copyWith({
    double? bankCapM,
    double? startPrice,
    double? priceStepM,
    double? maxPrice,
    double? frostAtM,
    int? overridesPerDay,
    int? overrideMinutes,
    double? strideM,
    double? weightKg,
    int? stepGoal,
  }) =>
      WalletConfig(
        bankCapM: bankCapM ?? this.bankCapM,
        startPrice: startPrice ?? this.startPrice,
        priceStepM: priceStepM ?? this.priceStepM,
        maxPrice: maxPrice ?? this.maxPrice,
        frostAtM: frostAtM ?? this.frostAtM,
        overridesPerDay: overridesPerDay ?? this.overridesPerDay,
        overrideMinutes: overrideMinutes ?? this.overrideMinutes,
        strideM: strideM ?? this.strideM,
        weightKg: weightKg ?? this.weightKg,
        stepGoal: stepGoal ?? this.stepGoal,
      );

  Map<String, Object?> toJson() => {
        'bankCapM': bankCapM,
        'startPrice': startPrice,
        'priceStepM': priceStepM,
        'maxPrice': maxPrice,
        'frostAtM': frostAtM,
        'overridesPerDay': overridesPerDay,
        'overrideMinutes': overrideMinutes,
        'strideM': strideM,
        'weightKg': weightKg,
        'stepGoal': stepGoal,
      };

  factory WalletConfig.fromJson(Map<String, Object?> j) {
    const d = WalletConfig();
    double n(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    return WalletConfig(
      bankCapM: n('bankCapM', d.bankCapM).clamp(minBankCapM, maxBankCapM),
      startPrice: n('startPrice', d.startPrice),
      priceStepM: n('priceStepM', d.priceStepM),
      maxPrice: n('maxPrice', d.maxPrice),
      frostAtM: n('frostAtM', d.frostAtM),
      overridesPerDay: i('overridesPerDay', d.overridesPerDay),
      overrideMinutes: i('overrideMinutes', d.overrideMinutes),
      strideM: n('strideM', d.strideM),
      weightKg: n('weightKg', d.weightKg),
      stepGoal: _stepGoalFrom(j, n('strideM', d.strideM)),
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
      weightKg: old.weightKg,
      stepGoal: old.stepGoal,
    );
  }
}

/// A saved step goal; a goal saved in metres (older versions) becomes steps
/// at the saved stride, except the old 5 km default, which becomes the new
/// default.
int _stepGoalFrom(Map<String, Object?> j, double strideM) {
  final steps = (j['stepGoal'] as num?)?.toInt();
  if (steps != null) return steps.clamp(WalletConfig.minStepGoal, WalletConfig.maxStepGoal);
  final metres = (j['walkGoalM'] as num?)?.toDouble();
  if (metres == null || metres == 5000 || strideM <= 0) return WalletConfig.defaultStepGoal;
  return (metres / strideM).round().clamp(WalletConfig.minStepGoal, WalletConfig.maxStepGoal);
}

class WalletState {
  WalletState({
    required this.dayKey,
    this.scrolledTodayM = 0,
    this.pricedScrolledTodayM = 0,
    this.bankM = 0,
    this.overdraftM = 0,
    this.walkedTodayM = 0,
    this.addedTodayM = 0,
    this.overflowWalkTodayM = 0,
    this.tamperChargedTodayM = 0,
    this.lifetimeScrolledM = 0,
    this.lifetimeWalkedM = 0,
    this.overridesUsedToday = 0,
    this.overrideUntilMs,
  });

  String dayKey;
  double scrolledTodayM;

  /// Scrolled today outside passes; sets the price.
  double pricedScrolledTodayM;

  /// Metres of scrolling in the bank.
  double bankM;

  /// Metres of scrolling owed: done (or charged for a tracking gap) with the
  /// bank empty.
  double overdraftM;
  double walkedTodayM;

  /// Scrolling walking added to the bank today.
  double addedTodayM;

  /// Walking that counted for nothing because the bank was full.
  double overflowWalkTodayM;
  double tamperChargedTodayM;
  double lifetimeScrolledM;
  double lifetimeWalkedM;
  int overridesUsedToday;
  int? overrideUntilMs;

  factory WalletState.fresh(DateTime now) => WalletState(dayKey: dayKeyOf(now));

  Map<String, Object?> toJson() => {
        'dayKey': dayKey,
        'scrolledTodayM': scrolledTodayM,
        'pricedScrolledTodayM': pricedScrolledTodayM,
        'bankM': bankM,
        'overdraftM': overdraftM,
        'walkedTodayM': walkedTodayM,
        'addedTodayM': addedTodayM,
        'overflowWalkTodayM': overflowWalkTodayM,
        'tamperChargedTodayM': tamperChargedTodayM,
        'lifetimeScrolledM': lifetimeScrolledM,
        'lifetimeWalkedM': lifetimeWalkedM,
        'overridesUsedToday': overridesUsedToday,
        'overrideUntilMs': overrideUntilMs,
      };

  /// Also reads a state saved by an older model: the day's totals and
  /// lifetime figures carry over; a debt or a bank in other units does not.
  factory WalletState.fromJson(Map<String, Object?> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    final current = j.containsKey('pricedScrolledTodayM');
    return WalletState(
      dayKey: j['dayKey'] as String,
      scrolledTodayM: n('scrolledTodayM'),
      pricedScrolledTodayM: current ? n('pricedScrolledTodayM') : 0,
      bankM: current ? n('bankM') : 0,
      overdraftM: current ? n('overdraftM') : 0,
      walkedTodayM: n('walkedTodayM'),
      addedTodayM: n('addedTodayM'),
      overflowWalkTodayM: n('overflowWalkTodayM'),
      tamperChargedTodayM: n('tamperChargedTodayM'),
      lifetimeScrolledM: n('lifetimeScrolledM'),
      lifetimeWalkedM: n('lifetimeWalkedM'),
      overridesUsedToday: (j['overridesUsedToday'] as num?)?.toInt() ?? 0,
      overrideUntilMs: (j['overrideUntilMs'] as num?)?.toInt(),
    );
  }
}

class ScrollCharge {
  const ScrollCharge({required this.rawM, required this.fromBankM, required this.owedM});
  final double rawM;

  /// Paid from the bank.
  final double fromBankM;

  /// Added to the overdraft.
  final double owedM;
}

/// Metres walked per metre of scrolling once [scrolled] metres have been
/// scrolled today.
double priceAt(double scrolled, WalletConfig c) {
  final start = math.max(1.0, c.startPrice);
  final cap = math.max(start, c.maxPrice);
  if (c.priceStepM <= 0) return cap;
  return math.min(start + (scrolled / c.priceStepM).floor(), cap);
}

class ScrollWallet {
  ScrollWallet({required this._config, required this.state}) {
    _clampBank();
  }

  WalletConfig _config;
  final WalletState state;

  WalletConfig get config => _config;

  /// Lowering the cap trims the bank to it.
  set config(WalletConfig c) {
    _config = c;
    _clampBank();
  }

  WalletConfig get _e => _config;

  void _clampBank() => state.bankM = math.min(state.bankM, _e.bankCapM);

  double get bankM => state.bankM;
  double get bankCapM => _e.bankCapM;
  double get overdraftM => state.overdraftM;
  bool get bankFull => state.bankM >= _e.bankCapM - 1e-6;

  /// Metres walked per metre of scrolling, for the next metre walked.
  double get priceNow => priceAt(state.pricedScrolledTodayM, _e);

  /// Walking that clears the overdraft and brings the bank to [metres]
  /// (at most the cap), at today's price.
  double walkToUnlock(double metres) {
    final want = math.min(metres, _e.bankCapM);
    return (state.overdraftM + math.max(0.0, want - state.bankM)) * priceNow;
  }

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
      ..scrolledTodayM = 0
      ..pricedScrolledTodayM = 0
      ..bankM = 0
      ..overdraftM = 0
      ..walkedTodayM = 0
      ..addedTodayM = 0
      ..overflowWalkTodayM = 0
      ..tamperChargedTodayM = 0
      ..overridesUsedToday = 0
      ..overrideUntilMs = null;
    return true;
  }

  /// Charges a scroll of [metres] in an app that counts.
  ScrollCharge applyScroll({required double metres, required DateTime at}) {
    rollover(at);
    if (metres <= 0) return const ScrollCharge(rawM: 0, fromBankM: 0, owedM: 0);
    state.scrolledTodayM += metres;
    state.lifetimeScrolledM += metres;
    if (overrideActive(at)) return ScrollCharge(rawM: metres, fromBankM: 0, owedM: 0);
    state.pricedScrolledTodayM += metres;
    final (bank, owed) = _spend(metres);
    return ScrollCharge(rawM: metres, fromBankM: bank, owedM: owed);
  }

  /// Charges [metres] of scrolling for time without tracking: from the bank
  /// first, the rest is owed.
  double chargeGap(double metres, DateTime at) {
    rollover(at);
    if (metres <= 0) return 0;
    _spend(metres);
    state.tamperChargedTodayM += metres;
    return metres;
  }

  (double, double) _spend(double metres) {
    final fromBank = math.min(state.bankM, metres);
    state.bankM -= fromBank;
    if (state.bankM < 1e-9) state.bankM = 0;
    state.overdraftM += metres - fromBank;
    return (fromBank, metres - fromBank);
  }

  /// Applies walked distance at today's price: clears the overdraft first,
  /// then fills the bank up to its cap. Returns the scrolling added to the
  /// bank.
  double applyWalk(double metres, DateTime at) {
    rollover(at);
    if (metres <= 0) return 0;
    state.walkedTodayM += metres;
    state.lifetimeWalkedM += metres;
    final price = priceNow;
    var scroll = metres / price;
    final paid = math.min(state.overdraftM, scroll);
    state.overdraftM -= paid;
    if (state.overdraftM < 1e-9) state.overdraftM = 0;
    scroll -= paid;
    final added = math.max(0.0, math.min(scroll, _e.bankCapM - state.bankM));
    state.bankM += added;
    state.addedTodayM += added;
    state.overflowWalkTodayM += (scroll - added) * price;
    return added;
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
