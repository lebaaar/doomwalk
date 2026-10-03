import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_catalog.dart';
import '../core/debt_engine.dart';
import '../core/flick_weigher.dart';
import '../core/landmarks.dart';
import '../core/scroll_interpreter.dart';
import '../core/tamper.dart';
import '../core/units.dart';
import '../core/walk_tracker.dart';
import 'native_bridge.dart';
import 'store.dart';

void _log(String msg) {
  if (kDebugMode) debugPrint('SD $msg');
}

/// Owns the ledger and everything that feeds it. Lives for the whole process
/// in the cached engine, whether or not the UI is attached.
class ScrollDebtController extends ChangeNotifier {
  ScrollDebtController._(this._store, this._native, this._engine, this._walk, this.catalog);

  final Store _store;
  final NativeBridge _native;
  final DebtEngine _engine;
  final WalkTracker _walk;
  final AppCatalog catalog;
  final _flick = FlickWeigher();
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

  DebtConfig get config => _engine.config;
  DebtState get state => _engine.state;
  double get debtM => _engine.debtM;
  double get frostLevel => _engine.frostLevel;
  double get allowanceLeftM => _engine.allowanceLeftM;
  double get progressToZero => _engine.progressToZero;
  double get weekRawM => _weekPriorRawM + state.scrolledTodayM;
  bool get overrideActive => _engine.overrideActive(DateTime.now());
  int get overridesLeft => _engine.overridesLeft(DateTime.now());
  DateTime? get overrideUntil => state.overrideUntilMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(state.overrideUntilMs!);

  static Future<ScrollDebtController> start() async {
    final store = await Store.open();
    final kv = await store.readKv();
    final now = DateTime.now();
    final config = kv['config'] != null
        ? DebtConfig.fromJson(jsonDecode(kv['config']!) as Map<String, Object?>)
        : const DebtConfig();
    final state = kv['state'] != null
        ? DebtState.fromJson(jsonDecode(kv['state']!) as Map<String, Object?>)
        : DebtState.fresh(now);
    final rates = kv['rates'] != null
        ? (jsonDecode(kv['rates']!) as Map<String, Object?>)
            .map((k, v) => MapEntry(k, (v as num).toDouble()))
        : <String, double>{};
    final walk = WalkTracker(
      strideM: config.strideM,
      baseline: int.tryParse(kv['walk.sensor_baseline'] ?? ''),
    );
    final c = ScrollDebtController._(
      store,
      NativeBridge(),
      DebtEngine(config: config, state: state),
      walk,
      AppCatalog(overrides: rates),
    );
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

    final rolled = _engine.rollover(now);
    if (rolled.happened) _log('rollover ${rolled.closedDays} interest=${rolled.interestM}');
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
        _onWindow((args as Map<Object?, Object?>)['pkg'] as String? ?? '');
      case 'onServiceState':
        await _onServiceState((args as Map<Object?, Object?>)['connected'] == true);
      case 'onOverrideRequested':
        startOverride();
      case 'debugInjectWalk':
        if (kDebugMode) {
          final m = ((args as Map<Object?, Object?>)['metres'] as num).toDouble();
          _applyWalk(m, source: 'debug');
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
    final rate = catalog.rateFor(e.pkg);
    if (rate <= 0) return;
    final now = DateTime.fromMillisecondsSinceEpoch(e.timeMs);
    final rolled = _engine.state.dayKey != dayKeyOf(now);
    final weight = _flick.weigh(e.pkg, s.metres, e.timeMs);
    final charge = _engine.applyScroll(metres: s.metres, appRate: rate, at: now, velocityWeight: weight);
    if (rolled) _onRolledOver();
    _addAppDelta(e.pkg, charge.rawM, charge.costM);
    _ensureMeta(e.pkg);
    _log('scroll pkg=${e.pkg} src=${s.source.name} px=${s.pixels.toStringAsFixed(0)} '
        'm=${s.metres.toStringAsFixed(3)} w=${weight.toStringAsFixed(2)} '
        'cost=${charge.costM.toStringAsFixed(3)} debt=${debtM.toStringAsFixed(2)} '
        'today=${todayApps[e.pkg]!.rawM.toStringAsFixed(2)}');
    _changed();
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

  void _onWindow(String pkg) {
    if (pkg.isEmpty || _keyboards.contains(pkg)) return;
    _setForeground(pkg);
  }

  void _setForeground(String pkg) {
    if (pkg == foreground || _keyboards.contains(pkg)) return;
    final prev = foreground;
    foreground = pkg;
    _log('foreground $prev -> $pkg exempt=${catalog.isExempt(pkg)}');
    unawaited(flush()); // batch boundary on app switch
    _pushFrost(animateMs: 250);
    _changed();
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
    final rolled = state.dayKey != dayKeyOf(now);
    final paid = _engine.applyWalk(metres, now);
    if (rolled) _onRolledOver();
    _dirty = true;
    _log('walk src=$source m=${metres.toStringAsFixed(2)} paid=${paid.toStringAsFixed(2)} '
        'debt=${debtM.toStringAsFixed(2)} frost=${frostLevel.toStringAsFixed(3)}');
    _changed();
  }

  /// Debug builds only: simulate walking (the real path is the pedometer).
  void debugInjectWalk(double metres) {
    if (kDebugMode) _applyWalk(metres, source: 'debug');
  }

  // -------------------------------------------------------------- override

  bool startOverride() {
    final ok = _engine.startOverride(DateTime.now());
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
    final cost = _tamper.costFor(gap, avg, config.effective.ratio);
    _log('gap close len=${gap.length.inMinutes}min avg=${avg.toStringAsFixed(1)}m/h cost=$cost');
    if (cost <= 0) return;
    _engine.chargeFlat(cost, gap.end, tamper: true);
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
    final rolled = _engine.rollover(now);
    if (rolled.happened) {
      _log('rollover ${rolled.closedDays} interest=${rolled.interestM.toStringAsFixed(2)}');
      _onRolledOver();
    }
    if (state.overrideUntilMs != null && !_engine.overrideActive(now)) {
      _engine.endOverride();
      _pushFrost(force: true);
    }
    status = await _native.status().catchError((_) => status);
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
      'rates': jsonEncode(catalog.overrides),
      'heartbeat': DateTime.now().millisecondsSinceEpoch.toString(),
      'heartbeat.tracking': status.accessibilityEnabled.toString(),
      'gap.open_start': _openGapStartMs?.toString() ?? '',
      'gap.open_reason': _openGapReason ?? '',
      'onboarding.done': onboardingDone.toString(),
      if (_walk.baseline != null) 'walk.sensor_baseline': _walk.baseline.toString(),
    };
    try {
      await _store.flush(kv: kv, appDeltas: deltas);
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

  /// Called after any ledger change: batches UI, frost, widget, persistence.
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
    return catalog.rateFor(fg) > 0;
  }

  double get targetFrost =>
      (!_foregroundFrostable || overrideActive || !status.serviceConnected) ? 0 : frostLevel;

  void _pushFrost({bool force = false, int animateMs = 600}) {
    final target = targetFrost;
    final endpoint = (target == 0 || target == 1) && target != _lastFrostSent;
    if (!force && !endpoint && (target - _lastFrostSent).abs() < 0.01) return;
    _lastFrostSent = target;
    final label = '${formatMetres(debtM)} to walk';
    _log('frost -> ${target.toStringAsFixed(3)} fg=$foreground');
    unawaited(_safe(() => _native.setFrost(target, label: label, animateMs: animateMs)));
  }

  void _pushNotification() {
    final title = debtM < 0.05
        ? 'Nothing owed. ${formatMetres(allowanceLeftM, decimals: 0)} of free scrolling left'
        : '${formatMetres(debtM)} to walk';
    final text = overrideActive
        ? 'Emergency pass on until ${_hhmm(overrideUntil!)}. Scrolling costs ${config.overridePenalty.toStringAsFixed(0)}×.'
        : '${formatMetres(state.scrolledTodayM)} scrolled today, ${nearestText(state.scrolledTodayM)}';
    final key = '$title|$text|$overridesLeft|$overrideActive';
    if (key == _lastNotif) return;
    _lastNotif = key;
    unawaited(_safe(() => _native.updateNotification(
          title: title,
          text: text,
          overridesLeft: overridesLeft,
          overrideActive: overrideActive,
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
      await Future.wait([
        HomeWidget.saveWidgetData<String>('debt_text', formatMetres(debtM)),
        HomeWidget.saveWidgetData<String>('caption_text', debtM < 0.05 ? 'nothing owed' : 'to walk'),
        HomeWidget.saveWidgetData<int>('progress', (progressToZero * 100).round()),
        HomeWidget.saveWidgetData<String>(
            'scrolled_text', '${formatMetres(state.scrolledTodayM)} scrolled today'),
        HomeWidget.saveWidgetData<String>('landmark_text', nearestText(state.scrolledTodayM)),
      ]);
      await HomeWidget.updateWidget(qualifiedAndroidName: 'com.lan.scrolldebt.DebtWidgetSmall');
      await HomeWidget.updateWidget(qualifiedAndroidName: 'com.lan.scrolldebt.DebtWidgetLarge');
      _log('widget pushed debt=${debtM.toStringAsFixed(2)}');
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
      notifyListeners();
    }).catchError((Object _) {});
  }

  String labelFor(String pkg) => appMeta[pkg]?.label ?? pkg.split('.').last;

  Future<List<AppMeta>> launchableApps() => _native.launchableApps();

  // ------------------------------------------------------------- settings

  Future<void> updateConfig(DebtConfig c) async {
    _engine.config = c;
    _walk.strideM = c.strideM;
    _dirty = true;
    await flush();
    _pushFrost(force: true);
    _pushNotification();
    _pushWidget(force: true);
    notifyListeners();
  }

  Future<void> setRate(String pkg, double? rate) async {
    if (rate == null) {
      catalog.overrides.remove(pkg);
    } else {
      catalog.overrides[pkg] = rate;
    }
    _dirty = true;
    await flush();
    _pushFrost(force: true);
    notifyListeners();
  }

  Future<NativeStatus> refreshStatus() async {
    status = await _native.status();
    notifyListeners();
    return status;
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
    final fresh = DebtState.fresh(DateTime.now());
    state
      ..debtM = 0
      ..dayKey = fresh.dayKey
      ..allowanceUsedM = 0
      ..scrolledTodayM = 0
      ..chargedTodayM = 0
      ..walkedTodayM = 0
      ..paidTodayM = 0
      ..peakDebtTodayM = 0
      ..lastInterestM = 0
      ..interestTotalM = 0
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

  /// Per-app rows for a period, sorted by distance.
  List<AppTotals> ranked(Map<String, AppTotals> m) =>
      m.values.where((t) => t.rawM > 0.005).toList()..sort((a, b) => b.rawM.compareTo(a.rawM));

  double get lifetimeRawM => state.lifetimeScrolledM;

  /// Debt needed to fully frost, after demo-mode overrides.
  double get frostMaxDebtM => config.effective.frostMaxDebtM;

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
