import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_catalog.dart';
import '../core/health.dart';
import '../core/landmarks.dart';
import '../core/scroll_interpreter.dart';
import '../core/scroll_wallet.dart';
import '../core/tamper.dart';
import '../core/units.dart';
import '../core/walk_tracker.dart';
import 'native_bridge.dart';
import 'store.dart';

void _log(String msg) {
  if (kDebugMode) debugPrint('SD $msg');
}

/// Owns the wallet and everything that feeds it. Lives for the whole process
/// in the cached engine, whether or not the UI is attached.
class DoomWalkController extends ChangeNotifier {
  DoomWalkController._(this._store, this._native, this._engine, this._walk, this.catalog);

  final Store _store;
  final NativeBridge _native;
  final ScrollWallet _engine;
  final WalkTracker _walk;
  final AppCatalog catalog;
  final _tamper = const TamperPolicy();
  late ScrollInterpreter _interp;

  DeviceInfo? device;
  NativeStatus status = NativeStatus.unknown();
  final Set<String> _keyboards = {};

  // Live aggregates (memory first, flushed in batches).
  final Map<String, AppTotals> todayApps = {};
  final Map<String, AppTotals> weekApps = {};
  final Map<(String, String), AppTotals> _pending = {};
  bool _dirty = false;
  double _weekPriorRawM = 0;

  final Map<String, AppMeta> appMeta = {};
  final Set<String> _metaRequested = {};

  String? foreground;

  /// 'system' | 'light' | 'dark'.
  String themeMode = 'system';

  /// Settings > Developer options. Gates every tool that fakes data
  /// (adding steps or scrolling, demo mode), in any build.
  bool developerOptions = false;

  /// A funny pop-up over the open app when today's scrolling passes a
  /// milestone (a giraffe, the Eiffel Tower...).
  bool milestoneToasts = true;

  /// Walked metres per previous day, newest first (today is live in state).
  List<(String, double)> walkHistory = [];
  bool onboardingDone = false;
  bool walkAvailable = false;
  String? walkError;
  StreamSubscription<StepCount>? _steps;
  List<GapRow> gaps = [];
  int? _openGapStartMs;
  String? _openGapReason;

  Timer? _flushTimer;
  Timer? _tick;
  Timer? _notifyTimer;
  Timer? _widgetTimer;
  DateTime _lastWidgetPush = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastFrostSent = -1;
  String _lastNotif = '';

  WalletConfig get config => _engine.config;
  WalletState get state => _engine.state;

  /// Metres to walk before scrolling past the allowance is possible again.
  double get overdraftM => _engine.overdraftM;
  double get bankM => _engine.bankM;
  double get frostLevel => _engine.frostLevel;
  double get allowanceLeftM => _engine.allowanceLeftM;

  /// How far today's walking still lets you scroll past the allowance.
  double get earnedScrollLeftM => _engine.earnedScrollLeftM;

  /// Metres walked per metre scrolled for the next earned metre.
  double get priceNow => _engine.priceNow;

  /// Walking (overdraft included) that unlocks [metres] more scrolling.
  double walkToUnlock(double metres) => _engine.walkToUnlock(metres);

  /// The chunk of scrolling the walking asks are phrased in.
  static const unlockChunkM = 100.0;
  double get weekRawM => _weekPriorRawM + state.scrolledTodayM;
  bool get overrideActive => _engine.overrideActive(DateTime.now());
  int get overridesLeft => _engine.overridesLeft(DateTime.now());
  DateTime? get overrideUntil => state.overrideUntilMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(state.overrideUntilMs!);

  static Future<DoomWalkController> start() async {
    final store = await Store.open();
    final kv = await store.readKv();
    final now = DateTime.now();
    // Model 2 is the scroll wallet. A config saved by the old debt model
    // keeps only its personal settings; its economy meant something else.
    final savedConfig = kv['config'] == null ? null : jsonDecode(kv['config']!) as Map<String, Object?>;
    final config = savedConfig == null
        ? const WalletConfig()
        : kv['model'] == '2'
            ? WalletConfig.fromJson(savedConfig)
            : WalletConfig.fromLegacyJson(savedConfig);
    final state = kv['state'] != null
        ? WalletState.fromJson(jsonDecode(kv['state']!) as Map<String, Object?>)
        : WalletState.fresh(now);
    final overrides = kv['app_overrides'] != null
        ? (jsonDecode(kv['app_overrides']!) as Map<String, Object?>).map((k, v) => MapEntry(k, v == true))
        // Old per-app rates: 0 meant "never counts", anything else "counts".
        : kv['rates'] != null
            ? (jsonDecode(kv['rates']!) as Map<String, Object?>).map((k, v) => MapEntry(k, (v as num) > 0))
            : <String, bool>{};
    final walk = WalkTracker(
      strideM: config.strideM,
      baseline: int.tryParse(kv['walk.sensor_baseline'] ?? ''),
    );
    final c = DoomWalkController._(
      store,
      NativeBridge(),
      ScrollWallet(config: config, state: state),
      walk,
      AppCatalog(
        overrides: overrides,
        restricted: kv['restricted_categories'] == null
            ? defaultRestricted
            : {
                for (final n in kv['restricted_categories']!.split(','))
                  if (AppCategory.values.any((c) => c.name == n)) AppCategory.values.byName(n),
              },
      ),
    );
    c.themeMode = kv['theme_mode'] ?? 'system';
    c.developerOptions = kv['dev_options'] == 'true';
    c.milestoneToasts = kv['milestone_toasts'] != 'false';
    c._openGapStartMs = int.tryParse(kv['gap.open_start'] ?? '');
    c._openGapReason = kv['gap.open_reason'];
    c.onboardingDone = kv['onboarding.done'] == 'true';
    await c._init(kv, now);
    return c;
  }

  Future<void> _init(Map<String, String> kv, DateTime now) async {
    _native.setHandler(_onNative);
    try {
      final (info, st) = await _native.ready();
      device = info;
      status = st;
    } on MissingPluginException {
      // Running without the shim (widget tests).
    }
    final d = device;
    final dpi = d == null ? 420.0 : sanitizeDpi(ydpi: d.ydpi, densityDpi: d.densityDpi);
    _interp = ScrollInterpreter(screenHeightPx: d?.screenHeightPx ?? 2400, ydpi: dpi);
    if (d != null) {
      catalog.addExempt(d.launchers);
      catalog.addExempt(d.keyboards);
      _keyboards.addAll(d.keyboards);
    }
    _log('ready ydpi=${d?.ydpi} used=$dpi screenH=${d?.screenHeightPx} '
        'launchers=${d?.launchers} keyboards=${d?.keyboards}');

    // Learn every installed app's Android category up front, so apps that
    // declare CATEGORY_SOCIAL / VIDEO are restricted from their first scroll.
    try {
      for (final m in await _native.launchableApps()) {
        catalog.categories[m.pkg] = categoryFromAndroid(m.category);
      }
    } on Exception {
      // No shim (tests) or package query failed: fall back to known packages.
    }
    if (_engine.rollover(now)) _log('rollover to ${state.dayKey}');
    await _reloadPeriods();
    gaps = await _store.recentGaps();
    await _checkTamperOnStart(kv, now);

    await startWalkTracking();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _onTick());
    _dirty = true;
    await flush();
    _pushFrost(force: true);
    _pushNotification();
    _pushWidget(force: true);
    for (final pkg in todayApps.keys) {
      _ensureMeta(pkg);
    }
  }

  Future<void> _reloadPeriods() async {
    final today = state.dayKey;
    final weekStart = dayKeyOf(DateTime.now().subtract(const Duration(days: 6)));
    todayApps
      ..clear()
      ..addAll(await _store.appTotals(fromDay: today, toDay: today));
    weekApps
      ..clear()
      ..addAll(await _store.appTotals(fromDay: weekStart, toDay: today));
    final prior = await _store.appTotals(fromDay: weekStart, toDay: _yesterday(today));
    _weekPriorRawM = prior.values.fold(0.0, (s, t) => s + t.rawM);
    walkHistory = await _store.walkHistory(beforeDay: today);
  }

  String _yesterday(String dayKey) {
    final p = dayKey.split('-').map(int.parse).toList();
    return dayKeyOf(DateTime(p[0], p[1], p[2] - 1));
  }

  // ---------------------------------------------------------------- native

  Future<Object?> _onNative(MethodCall call) async {
    final args = call.arguments;
    switch (call.method) {
      case 'onScroll':
        _onScroll(RawScroll.fromMap(args as Map<Object?, Object?>));
      case 'onWindow':
        final a = args as Map<Object?, Object?>;
        _onWindow(a['pkg'] as String? ?? '', a['cls'] as String? ?? '');
      case 'onServiceState':
        await _onServiceState((args as Map<Object?, Object?>)['connected'] == true);
      case 'onOverrideRequested':
        startOverride();
      // adb hooks for tool/device_test.sh; debug builds only.
      case 'debugInjectWalk':
        if (kDebugMode) {
          final m = ((args as Map<Object?, Object?>)['metres'] as num).toDouble();
          _applyWalk(m, source: 'debug');
        }
      case 'debugInjectScroll':
        if (kDebugMode) {
          final a = args as Map<Object?, Object?>;
          _fakeScroll(a['pkg'] as String, (a['metres'] as num).toDouble());
        }
      case 'debugDump':
        if (kDebugMode) {
          _log('dump ${jsonEncode(state.toJson())} frost=${frostLevel.toStringAsFixed(3)} '
              'fg=$foreground apps=${todayApps.map((k, v) => MapEntry(k, v.rawM.toStringAsFixed(2)))}');
        }
      case 'debugReset':
        if (kDebugMode) await resetAll();
    }
    return null;
  }

  void _onScroll(RawScroll e) {
    final s = _interp.interpret(e);
    if (catalog.isExempt(e.pkg)) {
      _setForeground(e.pkg);
      return;
    }
    _setForeground(e.pkg);
    if (s.metres <= 0) return;
    _chargeScroll(e.pkg, s.metres, DateTime.fromMillisecondsSinceEpoch(e.timeMs),
        source: '${s.source.name} px=${s.pixels.toStringAsFixed(0)}');
  }

  /// The single charging path for scrolled distance (real or injected).
  /// Returns the milestone this scroll passed, if any.
  Milestone? _chargeScroll(String pkg, double metres, DateTime at, {required String source}) {
    if (!catalog.isRestricted(pkg) || metres <= 0) return null;
    _syncDay(at);
    final before = state.scrolledTodayM;
    final allowanceBefore = allowanceLeftM;
    final charge = _engine.applyScroll(metres: metres, at: at);
    _addAppDelta(pkg, charge.rawM, charge.costM);
    _ensureMeta(pkg);
    if (allowanceBefore >= 0.5 && allowanceLeftM < 0.5) _noticeIfUsedUp(force: true);
    _log('scroll pkg=$pkg src=$source m=${metres.toStringAsFixed(3)} '
        'cost=${charge.costM.toStringAsFixed(3)} bank=${bankM.toStringAsFixed(2)} '
        'owed=${overdraftM.toStringAsFixed(2)} '
        'today=${todayApps[pkg]!.rawM.toStringAsFixed(2)}');
    final hit = _celebrate(before, state.scrolledTodayM);
    _changed();
    return hit;
  }

  /// Pops up a milestone over the open app when today's scrolling has just
  /// passed one. Each fires once a day, since today's total only grows.
  /// While DoomWalk itself is open (developer tools) there is no banner:
  /// the caller shows it in its own single message instead.
  Milestone? _celebrate(double before, double after) {
    if (!milestoneToasts) return null;
    final m = milestoneCrossed(before, after);
    if (m == null) return null;
    _log('milestone ${m.metres}');
    if (status.serviceConnected && foreground != selfPackage) {
      unawaited(_safe(() => _native.showNotice(m.title, m.body, ms: 3500)));
    }
    return m;
  }

  Future<void> setMilestoneToasts(bool on) async {
    milestoneToasts = on;
    _dirty = true;
    notifyListeners();
    await flush();
  }

  void _addAppDelta(String pkg, double raw, double charged) {
    final key = (state.dayKey, pkg);
    final p = _pending.putIfAbsent(key, () => AppTotals(pkg));
    p.rawM += raw;
    p.chargedM += charged;
    final t = todayApps.putIfAbsent(pkg, () => AppTotals(pkg));
    t.rawM += raw;
    t.chargedM += charged;
    final w = weekApps.putIfAbsent(pkg, () => AppTotals(pkg));
    w.rawM += raw;
    w.chargedM += charged;
    _dirty = true;
  }

  void _onWindow(String pkg, String cls) {
    if (pkg.isEmpty || _keyboards.contains(pkg)) return;
    // Showing the frost adds windows of our own, and Android announces each
    // with a window-state event from our package. Taking that as "DoomWalk
    // is open" lifted the frost the moment it appeared. Only our activity
    // means the user really switched to this app.
    if (pkg == selfPackage && cls.isNotEmpty && cls != selfActivity) return;
    _setForeground(pkg);
  }

  void _setForeground(String pkg) {
    if (pkg == foreground || _keyboards.contains(pkg)) return;
    final prev = foreground;
    foreground = pkg;
    _log('foreground $prev -> $pkg exempt=${catalog.isExempt(pkg)}');
    _ensureMeta(pkg);
    unawaited(flush()); // batch boundary on app switch
    _pushFrost(animateMs: 250);
    _noticeIfUsedUp();
    _changed();
  }

  final _lastNotice = <String, DateTime>{};

  /// Free scrolling used up, nothing owed yet (so no frost): say so,
  /// briefly, over the app, with how much walking has earned. On opening an
  /// app at most once per app every 10 minutes; [force] is the moment the
  /// allowance runs out while scrolling.
  void _noticeIfUsedUp({bool force = false}) {
    final fg = foreground;
    if (fg == null || !_foregroundFrostable || overrideActive || !status.serviceConnected) return;
    if (overdraftM >= 0.05 || allowanceLeftM >= 0.5) return;
    final now = DateTime.now();
    final last = _lastNotice[fg];
    if (!force && last != null && now.difference(last) < const Duration(minutes: 10)) return;
    _lastNotice[fg] = now;
    final earned = earnedScrollLeftM;
    final walk = walkToUnlock(unlockChunkM);
    unawaited(_safe(() async {
      // Usually a first visit today, so the name may still be loading.
      final name = _knownLabel(fg) ?? (await _native.appInfo(fg))?.label ?? 'this app';
      if (foreground != fg) return;
      final notice = usedUpNotice(name, earnedM: earned, walkM: walk, strideM: config.strideM);
      await _native.showNotice(notice.$1, notice.$2);
    }));
  }

  // ------------------------------------------------------------------ walk

  Future<void> startWalkTracking() async {
    bool granted;
    try {
      granted = await Permission.activityRecognition.isGranted;
    } on MissingPluginException {
      granted = false;
    }
    if (!granted) {
      walkAvailable = false;
      walkError = 'Activity recognition permission not granted';
      return;
    }
    await _steps?.cancel();
    walkError = null;
    // Upgrade the foreground service type to `health` now that we can.
    unawaited(_safe(_native.startForegroundService));
    _steps = Pedometer.stepCountStream.listen(
      (s) {
        walkAvailable = true;
        final metres = _walk.onCounter(s.steps);
        _dirty = true; // persist the sensor baseline
        if (metres > 0) _applyWalk(metres, source: 'pedometer');
      },
      onError: (Object e) {
        walkAvailable = false;
        walkError = 'Step counter unavailable on this device';
        _log('pedometer error $e');
        notifyListeners();
      },
    );
  }

  void _applyWalk(double metres, {required String source}) {
    final now = DateTime.now();
    _syncDay(now);
    final banked = _engine.applyWalk(metres, now);
    _dirty = true;
    _log('walk src=$source m=${metres.toStringAsFixed(2)} banked=${banked.toStringAsFixed(2)} '
        'bank=${bankM.toStringAsFixed(2)} owed=${overdraftM.toStringAsFixed(2)} frost=${frostLevel.toStringAsFixed(3)}');
    _changed();
  }

  // ------------------------------------------------------ developer tools
  // All of these do nothing unless developer options are on.

  Future<void> setDeveloperOptions(bool on) async {
    developerOptions = on;
    _dirty = true;
    notifyListeners();
    // Nothing fake stays active behind a switch the user can't see.
    if (!on && config.demoMode) {
      await updateConfig(config.copyWith(demoMode: false));
    } else {
      await flush();
    }
  }

  /// Adds [steps] to today as if the pedometer had counted them.
  void devAddSteps(int steps) {
    if (developerOptions) _applyWalk(steps * config.strideM, source: 'dev');
  }

  /// Adds [metres] of scrolling to [pkg], priced like real scrolling.
  /// Returns the milestone it passed, if any.
  Milestone? devAddScroll(String pkg, double metres) => developerOptions ? _fakeScroll(pkg, metres) : null;

  /// Gives back today's emergency passes.
  void devRefillPasses() {
    if (!developerOptions) return;
    state.overridesUsedToday = 0;
    _dirty = true;
    _changed();
  }

  /// Walking, scrolling and the wallet back to zero, history and passes included.
  /// Settings are kept. The same wipe as Privacy's erase, one tap closer.
  Future<void> devResetTracking() async {
    if (developerOptions) await resetAll();
  }

  /// Shows the setup flow again from the start.
  Future<void> devReplayOnboarding() async {
    if (!developerOptions) return;
    onboardingDone = false;
    _dirty = true;
    await flush();
    notifyListeners();
  }

  /// Adds [metres] of scrolling to [pkg], priced exactly like real scrolling
  /// (allowance, then the bank at today's price). Exempt apps and apps that
  /// don't count are ignored, as they would be for real.
  Milestone? _fakeScroll(String pkg, double metres) {
    if (catalog.isExempt(pkg)) {
      _log('debug scroll ignored: $pkg is exempt');
      return null;
    }
    return _chargeScroll(pkg, metres, DateTime.now(), source: 'fake');
  }

  // -------------------------------------------------------------- override

  bool startOverride() {
    final now = DateTime.now();
    _syncDay(now);
    final ok = _engine.startOverride(now);
    _log('override start ok=$ok until=${state.overrideUntilMs}');
    _dirty = true;
    _pushFrost(force: true, animateMs: 300);
    _changed();
    return ok;
  }

  void endOverride() {
    _engine.endOverride();
    _dirty = true;
    _pushFrost(force: true);
    _changed();
  }

  // ---------------------------------------------------------------- tamper

  Future<void> _checkTamperOnStart(Map<String, String> kv, DateTime now) async {
    final lastBeat = int.tryParse(kv['heartbeat'] ?? '');
    final wasTracking = kv['heartbeat.tracking'] == 'true';
    final boot = device?.bootTime;
    if (_openGapStartMs == null && lastBeat != null && wasTracking && boot != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastBeat);
      // Same boot, tracking was on, and we were dead for a while: the app
      // was force-stopped or killed. A reboot is not tampering.
      if (last.isAfter(boot) && now.difference(last) > const Duration(minutes: 15)) {
        await _chargeGap(TamperGap(start: last, end: now, reason: 'tracking stopped'));
      }
    }
    if (_openGapStartMs != null && status.serviceConnected) {
      await _closeGap(now);
    } else if (_openGapStartMs == null && !status.accessibilityEnabled && wasTracking) {
      _openGap(lastBeat ?? now.millisecondsSinceEpoch, 'accessibility service turned off');
    }
  }

  Future<void> _onServiceState(bool connected) async {
    final now = DateTime.now();
    status = await _native.status();
    _log('service connected=$connected enabled=${status.accessibilityEnabled}');
    if (connected) {
      if (_openGapStartMs != null) await _closeGap(now);
      _pushFrost(force: true);
    } else {
      // Unbound. If the user switched it off, the gap is chargeable.
      final s = await _native.status();
      if (!s.accessibilityEnabled) {
        _openGap(now.millisecondsSinceEpoch, 'accessibility service turned off');
      }
    }
    _changed();
  }

  void _openGap(int startMs, String reason) {
    if (_openGapStartMs != null) return;
    _openGapStartMs = startMs;
    _openGapReason = reason;
    _dirty = true;
    _log('gap open reason=$reason');
  }

  Future<void> _closeGap(DateTime now) async {
    final start = _openGapStartMs;
    if (start == null) return;
    _openGapStartMs = null;
    await _chargeGap(TamperGap(
      start: DateTime.fromMillisecondsSinceEpoch(start),
      end: now,
      reason: _openGapReason ?? 'tracking off',
    ));
    _openGapReason = null;
    _dirty = true;
  }

  Future<void> _chargeGap(TamperGap gap) async {
    final history = await _store.dailyRaw(beforeDay: state.dayKey);
    final avg = _tamper.averageMetresPerHour(history);
    final cost = _tamper.costFor(gap, avg);
    _log('gap close len=${gap.length.inMinutes}min avg=${avg.toStringAsFixed(1)}m/h cost=$cost');
    if (cost <= 0) return;
    _syncDay(gap.end);
    _engine.chargeGap(cost, gap.end);
    final row = GapRow(gap.start, gap.end, gap.reason, cost);
    await _store.addGap(row);
    gaps = [row, ...gaps];
    _dirty = true;
    _changed();
  }

  @visibleForTesting
  void debugOpenGap(DateTime start) => _openGap(start.millisecondsSinceEpoch, 'test gap');

  double get averageScrollPerHour => _lastAvg;
  double _lastAvg = 0;

  // ------------------------------------------------------------------ tick

  Future<void> _onTick() async {
    final now = DateTime.now();
    _syncDay(now);
    if (state.overrideUntilMs != null && !_engine.overrideActive(now)) {
      _engine.endOverride();
      _pushFrost(force: true);
    }
    status = await _native.status().catchError((_) => status);
    _healService();
    if (!status.accessibilityEnabled && _openGapStartMs == null && _trackingEverEnabled) {
      _openGap(now.millisecondsSinceEpoch, 'accessibility service turned off');
    }
    _lastAvg = _tamper.averageMetresPerHour(await _store.dailyRaw(beforeDay: state.dayKey));
    _dirty = true; // heartbeat
    await flush();
    _pushNotification();
    if (now.difference(_lastWidgetPush) > const Duration(minutes: 15)) _pushWidget(force: true);
    notifyListeners();
  }

  bool get _trackingEverEnabled => status.serviceConnected || state.lifetimeScrolledM > 0;

  /// Rolls the wallet to [now]'s day before anything is charged or paid, so
  /// every day change (a clock set back included) reloads today's per-app
  /// totals instead of happening silently inside the wallet.
  void _syncDay(DateTime now) {
    if (!_engine.rollover(now)) return;
    _log('rollover to ${state.dayKey}');
    _onRolledOver();
  }

  void _onRolledOver() {
    _dirty = true;
    unawaited(flush().then((_) => _reloadPeriods()).then((_) => notifyListeners()));
  }

  // ----------------------------------------------------------- persistence

  Future<void> flush() async {
    if (!_dirty) return;
    _dirty = false;
    final deltas = Map.of(_pending);
    _pending.clear();
    final kv = <String, String>{
      'state': jsonEncode(state.toJson()),
      'config': jsonEncode(config.toJson()),
      'model': '2',
      'app_overrides': jsonEncode(catalog.overrides),
      'heartbeat': DateTime.now().millisecondsSinceEpoch.toString(),
      'heartbeat.tracking': status.accessibilityEnabled.toString(),
      'gap.open_start': _openGapStartMs?.toString() ?? '',
      'gap.open_reason': _openGapReason ?? '',
      'onboarding.done': onboardingDone.toString(),
      if (_walk.baseline != null) 'walk.sensor_baseline': _walk.baseline.toString(),
      'restricted_categories': catalog.restricted.map((c) => c.name).join(','),
      'theme_mode': themeMode,
      'dev_options': developerOptions.toString(),
      'milestone_toasts': milestoneToasts.toString(),
    };
    try {
      await _store.flush(kv: kv, appDeltas: deltas, walkedToday: (state.dayKey, state.walkedTodayM));
    } catch (e) {
      // Put the deltas back so nothing is lost.
      deltas.forEach((k, v) {
        final p = _pending.putIfAbsent(k, () => AppTotals(v.pkg));
        p.rawM += v.rawM;
        p.chargedM += v.chargedM;
      });
      _dirty = true;
      _log('flush failed $e');
    }
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(const Duration(seconds: 5), () {
      _flushTimer = null;
      flush();
    });
  }

  // -------------------------------------------------------------- outputs

  /// Called after any wallet change: batches UI, frost, widget, persistence.
  void _changed() {
    _scheduleFlush();
    _pushFrost();
    _pushWidget();
    _notifyTimer ??= Timer(const Duration(milliseconds: 250), () {
      _notifyTimer = null;
      notifyListeners();
      _pushNotification();
    });
  }

  bool get _foregroundFrostable {
    final fg = foreground;
    if (fg == null || catalog.isExempt(fg)) return false;
    return catalog.isRestricted(fg);
  }

  double get targetFrost =>
      (!_foregroundFrostable || overrideActive || !status.serviceConnected) ? 0 : frostLevel;

  int? _lastPassSent;

  /// When the running pass ends, while the open app is one it unfroze; the
  /// overlay shows a countdown to it. Null otherwise.
  int? get _passShownUntilMs => overrideActive && _foregroundFrostable ? state.overrideUntilMs : null;

  void _pushFrost({bool force = false, int animateMs = 600}) {
    final target = targetFrost;
    final pass = _passShownUntilMs;
    final endpoint = (target == 0 || target == 1) && target != _lastFrostSent;
    if (!force && !endpoint && pass == _lastPassSent && (target - _lastFrostSent).abs() < 0.01) return;
    _lastFrostSent = target;
    _lastPassSent = pass;
    final (title, body) = frostCard(_knownLabel(foreground), walkToUnlock(unlockChunkM),
        full: target >= 0.999,
        strideM: config.strideM,
        unlocksM: unlockChunkM,
        seed: DateTime.now().difference(DateTime(2000)).inDays);
    _log('frost -> ${target.toStringAsFixed(3)} fg=$foreground');
    unawaited(_safe(() => _native.setFrost(target,
        title: title,
        body: body,
        animateMs: animateMs,
        overridesLeft: overrideActive ? 0 : overridesLeft,
        passUntilMs: pass)));
  }

  void _pushNotification() {
    final title = walletHeadline(
      allowanceLeftM: allowanceLeftM,
      earnedLeftM: earnedScrollLeftM,
      overdraftM: overdraftM,
      walkToUnlockM: walkToUnlock(unlockChunkM),
      strideM: config.strideM,
    );
    final text = overrideActive
        ? 'Emergency pass on until ${_hhmm(overrideUntil!)}. Scrolling is free until then.'
        : '${formatMetres(state.scrolledTodayM)} scrolled today, ${nearestText(state.scrolledTodayM)}';
    final key = '$title|$text|$overridesLeft|$overrideActive';
    if (key == _lastNotif) return;
    _lastNotif = key;
    unawaited(_safe(() => _native.updateNotification(
          title: title,
          text: text,
          overridesLeft: overridesLeft,
          overrideActive: overrideActive,
          overrideUntilMs: overrideActive ? state.overrideUntilMs : null,
        )));
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Home-screen widget: on change, throttled to one push per 10 s (trailing).
  void _pushWidget({bool force = false}) {
    final since = DateTime.now().difference(_lastWidgetPush);
    if (!force && since < const Duration(seconds: 10)) {
      _widgetTimer ??= Timer(const Duration(seconds: 10) - since, () {
        _widgetTimer = null;
        _pushWidget(force: true);
      });
      return;
    }
    _lastWidgetPush = DateTime.now();
    unawaited(_safe(() async {
      final (big, caption) = widgetFigure(
        allowanceLeftM: allowanceLeftM,
        earnedLeftM: earnedScrollLeftM,
        overdraftM: overdraftM,
        walkToUnlockM: walkToUnlock(unlockChunkM),
        strideM: config.strideM,
      );
      await Future.wait([
        HomeWidget.saveWidgetData<String>('debt_text', big),
        HomeWidget.saveWidgetData<String>('caption_text', caption),
        // The bar is today's walking goal: the thing to do more of.
        HomeWidget.saveWidgetData<int>('progress', (goalProgress * 100).round()),
        HomeWidget.saveWidgetData<String>(
            'scrolled_text', '${formatMetres(state.scrolledTodayM)} scrolled today'),
        HomeWidget.saveWidgetData<String>('landmark_text', nearestText(state.scrolledTodayM)),
      ]);
      await HomeWidget.updateWidget(qualifiedAndroidName: 'com.lebaaar.doomwalk.DebtWidgetSmall');
      await HomeWidget.updateWidget(qualifiedAndroidName: 'com.lebaaar.doomwalk.DebtWidgetLarge');
      _log('widget pushed $big $caption');
    }));
  }

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } on MissingPluginException {
      // No native side (tests).
    } on PlatformException catch (e) {
      _log('native error $e');
    }
  }

  // ------------------------------------------------------------- app meta

  void _ensureMeta(String pkg) {
    if (!_metaRequested.add(pkg)) return;
    _native.appInfo(pkg).then((m) {
      if (m == null) return;
      appMeta[pkg] = m;
      catalog.categories[pkg] = categoryFromAndroid(m.category);
      // The frost card names the app; give it the real name once known.
      if (pkg == foreground && _lastFrostSent > 0) _pushFrost(force: true);
      notifyListeners();
    }).catchError((Object _) {});
  }

  String labelFor(String pkg) => appMeta[pkg]?.label ?? pkg.split('.').last;

  /// The app's real name, or null while it is still being looked up (the
  /// package-name fallback reads badly on the frost card: "android").
  String? _knownLabel(String? pkg) => pkg == null ? null : appMeta[pkg]?.label;

  Future<List<AppMeta>> launchableApps() => _native.launchableApps();

  // ------------------------------------------------------------- settings

  Future<void> updateConfig(WalletConfig c) async {
    _engine.config = c;
    _walk.strideM = c.strideM;
    _dirty = true;
    await flush();
    _pushFrost(force: true);
    _pushNotification();
    _pushWidget(force: true);
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    themeMode = mode;
    _dirty = true;
    notifyListeners();
    await flush();
  }

  Future<void> setCategoryRestricted(AppCategory cat, bool on) async {
    on ? catalog.restricted.add(cat) : catalog.restricted.remove(cat);
    _dirty = true;
    await flush();
    _pushFrost(force: true);
    notifyListeners();
  }

  // --------------------------------------------------------------- health

  double get kcalToday => kcalForWalk(state.walkedTodayM, config.weightKg);

  /// Walked metres over the last 7 days, today included.
  double get weekWalkedM =>
      state.walkedTodayM + walkHistory.take(6).fold<double>(0, (s, d) => s + d.$2);

  double get kcalWeek => kcalForWalk(weekWalkedM, config.weightKg);

  double get goalProgress =>
      config.walkGoalM <= 0 ? 1 : (state.walkedTodayM / config.walkGoalM).clamp(0.0, 1.0);

  int get streakDays => walkStreak([state.walkedTodayM, ...walkHistory.map((d) => d.$2)], config.walkGoalM);

  /// Last 7 days of walking, oldest first, for the week strip.
  List<double> get weekWalkSeries {
    final byDay = {for (final d in walkHistory) d.$1: d.$2};
    final now = DateTime.now();
    return [
      for (var i = 6; i >= 1; i--) byDay[dayKeyOf(DateTime(now.year, now.month, now.day - i))] ?? 0,
      state.walkedTodayM,
    ];
  }

  /// Per-app choice: null follows the category, true always counts, false
  /// never counts.
  Future<void> setAppCounts(String pkg, bool? counts) async {
    if (counts == null) {
      catalog.overrides.remove(pkg);
    } else {
      catalog.overrides[pkg] = counts;
    }
    _dirty = true;
    await flush();
    _pushFrost(force: true);
    notifyListeners();
  }

  Future<NativeStatus> refreshStatus() async {
    status = await _native.status();
    _healService();
    notifyListeners();
    return status;
  }

  // ------------------------------------------------------ service health

  bool _stalledLastCheck = false;
  DateTime? _lastRestart;

  /// Switches scroll measuring off and on again, the fix for a service that
  /// is enabled but not running. Needs WRITE_SECURE_SETTINGS (adb); returns
  /// false without it, and the user has to toggle it in Settings.
  Future<bool> restartScrollMeasuring() async {
    _lastRestart = DateTime.now();
    final ok = await _native.restartAccessibility();
    _log('restart scroll measuring: ${ok ? 'sent' : 'not allowed'}');
    return ok;
  }

  /// When Android has stopped the service and the app may restart it, do so:
  /// only once it has looked stopped on two checks in a row (not while it is
  /// still connecting after being switched on), and at most once a minute.
  void _healService() {
    final stalled = status.serviceStalled;
    final confirmed = stalled && _stalledLastCheck;
    _stalledLastCheck = stalled;
    if (!confirmed || !status.canRestartService) return;
    final last = _lastRestart;
    if (last != null && DateTime.now().difference(last) < const Duration(minutes: 1)) return;
    unawaited(restartScrollMeasuring());
  }

  NativeBridge get native => _native;

  Future<void> completeOnboarding() async {
    onboardingDone = true;
    _dirty = true;
    await flush();
    notifyListeners();
  }

  Future<void> resetAll() async {
    await _store.wipe();
    final fresh = WalletState.fresh(DateTime.now());
    state
      ..dayKey = fresh.dayKey
      ..allowanceUsedM = 0
      ..scrolledTodayM = 0
      ..earnedScrolledTodayM = 0
      ..bankM = 0
      ..overdraftM = 0
      ..walkedTodayM = 0
      ..spentTodayM = 0
      ..tamperChargedTodayM = 0
      ..lifetimeScrolledM = 0
      ..lifetimeWalkedM = 0
      ..overridesUsedToday = 0
      ..overrideUntilMs = null;
    _pending.clear();
    todayApps.clear();
    weekApps.clear();
    _weekPriorRawM = 0;
    gaps = [];
    _openGapStartMs = null;
    _dirty = true;
    await flush();
    _pushFrost(force: true);
    _pushWidget(force: true);
    _log('reset');
    notifyListeners();
  }

  /// Restricted apps used today, most scrolled first. The frost covers every
  /// restricted app; these are the examples the user will recognise.
  List<String> get frostedAppsToday => [
        for (final r in ranked(todayApps))
          if (catalog.isRestricted(r.pkg)) r.pkg,
      ];

  /// Emergency passes used today, after a day change nobody has ticked yet.
  int get passesUsedToday => config.overridesPerDay - overridesLeft;

  /// Per-app rows for a period, sorted by distance.
  List<AppTotals> ranked(Map<String, AppTotals> m) =>
      m.values.where((t) => t.rawM > 0.005).toList()..sort((a, b) => b.rawM.compareTo(a.rawM));

  double get lifetimeRawM => state.lifetimeScrolledM;

  /// Overdraft that fully frosts, after demo-mode overrides.
  double get frostAtM => config.effective.frostAtM;

  @override
  void dispose() {
    _tick?.cancel();
    _flushTimer?.cancel();
    _notifyTimer?.cancel();
    _widgetTimer?.cancel();
    _steps?.cancel();
    _store.close();
    super.dispose();
  }
}

/// Lines under the walking ask on the lock card, one a day ([frostCard]'s
/// seed), so the card doesn't change text while it's up.
const walkNudges = [
  'A short walk beats another hour of feed.',
  'Your legs have been waiting all day.',
  'Every step clears the blur a little.',
  'The feed will still be here. The sun might not.',
  'Fresh air first, then back to it. Deal?',
  'Your thumb deserves a break. Your legs don\'t.',
  'Put on some music and go. It\'s over before the third song.',
];

/// Minutes to walk [metres] at an easy 80 m a minute: "about 3 minutes".
String walkMinutes(double metres) {
  final min = (metres / 80).ceil();
  return min <= 1 ? 'about a minute' : 'about $min minutes';
}

/// Steps for [metres] at [strideM]: "133 steps".
String stepsText(double metres, double strideM) {
  final n = strideM <= 0 ? 0 : (metres / strideM).ceil();
  return '$n ${n == 1 ? 'step' : 'steps'}';
}

/// The card over an app once the bank is empty: what happened, how many
/// steps unlock the next [unlocksM] of scrolling, and a nudge to go.
(String, String) frostCard(String? app, double walkM,
    {required bool full, required double strideM, double unlocksM = 100, int seed = 0}) {
  final name = app ?? 'This app';
  // No-break spaces: "133 steps" and "100 m" never split across lines.
  final steps = stepsText(walkM, strideM).replaceAll(' ', '\u00A0');
  final unlocks = formatRound(unlocksM).replaceAll(' ', '\u00A0');
  final time = walkMinutes(walkM);
  final nudge = walkNudges[seed % walkNudges.length];
  return full
      ? ('$name is frozen', 'Take a walk: $steps ($time) unlocks $unlocks of scrolling.\n\n$nudge')
      : ('Take a walk first',
          'You\'re out of earned scrolling. $steps ($time) unlocks $unlocks. Scrolling more freezes $name.\n\n$nudge');
}

/// The banner when free scrolling runs out in an app that counts.
(String, String) usedUpNotice(String app, {required double earnedM, required double walkM, required double strideM}) =>
    earnedM >= 0.5
        ? ('Free scrolling used up', 'Now spending your walk: ${formatRound(earnedM)} earned left for $app and the rest.')
        : ('Free scrolling used up', 'Take a walk first: ${stepsText(walkM, strideM)} unlocks 100 m in $app.');

/// One line for the status notification.
String walletHeadline({
  required double allowanceLeftM,
  required double earnedLeftM,
  required double overdraftM,
  required double walkToUnlockM,
  required double strideM,
}) {
  if (overdraftM >= 0.05) return 'Frozen. Walk ${stepsText(walkToUnlockM, strideM)} to unlock 100 m';
  if (allowanceLeftM >= 0.5) {
    final extra = earnedLeftM >= 0.5 ? ' + ${formatRound(earnedLeftM)} earned' : '';
    return '${formatRound(allowanceLeftM)} free scrolling left$extra';
  }
  if (earnedLeftM >= 0.5) return '${formatRound(earnedLeftM)} of earned scrolling left';
  return 'Take a walk: ${stepsText(walkToUnlockM, strideM)} unlocks 100 m';
}

/// The home-screen widget's big figure and the caption under it.
(String, String) widgetFigure({
  required double allowanceLeftM,
  required double earnedLeftM,
  required double overdraftM,
  required double walkToUnlockM,
  required double strideM,
}) {
  final total = allowanceLeftM + earnedLeftM;
  if (overdraftM < 0.05 && total >= 0.5) {
    return (formatRound(total), allowanceLeftM >= 0.5 ? 'left to scroll' : 'earned, left to scroll');
  }
  final n = strideM <= 0 ? 0 : (walkToUnlockM / strideM).ceil();
  return ('$n', 'steps to unlock 100 m');
}
