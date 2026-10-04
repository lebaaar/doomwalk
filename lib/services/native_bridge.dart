import 'package:flutter/services.dart';

class DeviceInfo {
  DeviceInfo(Map<Object?, Object?> m)
    : ydpi = (m['ydpi'] as num?)?.toDouble() ?? 0,
      densityDpi = (m['densityDpi'] as num?)?.toDouble() ?? 420,
      screenHeightPx = (m['screenHeightPx'] as num?)?.toDouble() ?? 2400,
      sdk = (m['sdk'] as num?)?.toInt() ?? 31,
      launchers = [...(m['launchers'] as List? ?? const []).cast<String>()],
      keyboards = [...(m['keyboards'] as List? ?? const []).cast<String>()],
      bootTime = DateTime.fromMillisecondsSinceEpoch(
        (m['bootTimeMs'] as num?)?.toInt() ?? 0,
      );

  final double ydpi;
  final double densityDpi;
  final double screenHeightPx;
  final int sdk;
  final List<String> launchers;
  final List<String> keyboards;
  final DateTime bootTime;
}

class NativeStatus {
  NativeStatus(Map<Object?, Object?> m)
    : accessibilityEnabled = m['accessibilityEnabled'] == true,
      serviceConnected = m['serviceConnected'] == true,
      ignoringBatteryOptimizations = m['ignoringBatteryOptimizations'] == true,
      restrictedSettingsAllowed = m['restrictedSettingsAllowed'] as bool?,
      blurEnabled = m['blurEnabled'] == true,
      sdk = (m['sdk'] as num?)?.toInt() ?? 31,
      canRestartService = m['canRestartService'] == true,
      lastExit = ExitRecord.fromMap(m);

  NativeStatus.unknown()
    : accessibilityEnabled = false,
      serviceConnected = false,
      ignoringBatteryOptimizations = false,
      restrictedSettingsAllowed = null,
      blurEnabled = false,
      sdk = 31,
      canRestartService = false,
      lastExit = null;

  final bool accessibilityEnabled;
  final bool serviceConnected;
  final bool ignoringBatteryOptimizations;
  final bool? restrictedSettingsAllowed;
  final bool blurEnabled;
  final int sdk;

  final bool canRestartService;

  final ExitRecord? lastExit;

  bool get serviceStalled => accessibilityEnabled && !serviceConnected;
}

class ExitRecord {
  const ExitRecord({
    required this.reason,
    required this.time,
    this.description,
  });
  final int reason;
  final DateTime time;
  final String? description;

  static ExitRecord? fromMap(Map<Object?, Object?> m) {
    final r = m['exitReason'];
    final t = m['exitTimeMs'];
    if (r is! num || t is! num) return null;
    return ExitRecord(
      reason: r.toInt(),
      time: DateTime.fromMillisecondsSinceEpoch(t.toInt()),
      description: m['exitDescription'] as String?,
    );
  }

  String get label => switch (reason) {
    1 => 'it closed itself',
    2 => 'Android killed it',
    3 => 'Android closed it to free memory',
    4 => 'it crashed',
    5 => 'it crashed in native code',
    6 => 'it stopped responding',
    7 => 'it failed to start',
    8 => 'a permission was changed',
    9 => 'it used too many resources',
    10 => 'it was force stopped',
    11 => 'Android turned it off for this user',
    12 => 'a process it depended on died',
    13 => 'Android ended it',
    14 => 'Android paused it in the background',
    15 => 'its package changed',
    16 => 'the app was updated',
    _ => 'an unknown reason',
  };

  bool get isCrash => reason == 4 || reason == 5 || reason == 6 || reason == 7;
}

class AppMeta {
  AppMeta({
    required this.pkg,
    required this.label,
    this.category = -1,
    this.icon,
  });
  final String pkg;
  final String label;
  final int category;
  final Uint8List? icon;

  static AppMeta? fromMap(Map<Object?, Object?>? m) => m == null
      ? null
      : AppMeta(
          pkg: m['pkg'] as String,
          label: m['label'] as String? ?? m['pkg'] as String,
          category: (m['category'] as num?)?.toInt() ?? -1,
          icon: m['icon'] as Uint8List?,
        );
}

class NativeBridge {
  static const _ch = MethodChannel('com.lebaaar.doomwalk/native');

  void setHandler(Future<Object?> Function(MethodCall call) handler) =>
      _ch.setMethodCallHandler(handler);

  Future<(DeviceInfo, NativeStatus)> ready() async {
    final m = await _ch.invokeMapMethod<Object?, Object?>('ready') ?? const {};
    return (DeviceInfo(m), NativeStatus(m));
  }

  Future<NativeStatus> status() async {
    try {
      return NativeStatus(
        await _ch.invokeMapMethod<Object?, Object?>('status') ?? const {},
      );
    } on PlatformException {
      return NativeStatus.unknown();
    }
  }

  Future<void> setFrost(
    double level, {
    String? title,
    String? body,
    int animateMs = 600,
    int overridesLeft = 0,
    int? passUntilMs,
  }) => _ch.invokeMethod('setFrost', {
    'level': level,
    'title': title,
    'body': body,
    'animateMs': animateMs,
    'overridesLeft': overridesLeft,
    'passUntilMs': passUntilMs,
  });

  Future<void> showNotice(String title, String body, {int ms = 4000}) =>
      _ch.invokeMethod('showNotice', {'title': title, 'body': body, 'ms': ms});

  Future<void> updateNotification({
    required String title,
    required String text,
    required int overridesLeft,
    required bool overrideActive,
    int? overrideUntilMs,
  }) => _ch.invokeMethod('updateNotification', {
    'title': title,
    'text': text,
    'overridesLeft': overridesLeft,
    'overrideActive': overrideActive,
    'overrideUntilMs': overrideUntilMs,
  });

  Future<void> startForegroundService() =>
      _ch.invokeMethod('startForegroundService');
  Future<void> openAccessibilitySettings() =>
      _ch.invokeMethod('openAccessibilitySettings');
  Future<void> openAppDetails() => _ch.invokeMethod('openAppDetails');

  Future<bool> restartAccessibility() async {
    try {
      return await _ch.invokeMethod<bool>('restartAccessibility') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() =>
      _ch.invokeMethod('requestIgnoreBatteryOptimizations');

  Future<AppMeta?> appInfo(String pkg) async => AppMeta.fromMap(
    await _ch.invokeMapMethod<Object?, Object?>('appInfo', {'pkg': pkg}),
  );

  Future<List<AppMeta>> launchableApps() async {
    final list =
        await _ch.invokeListMethod<Object?>('launchableApps') ?? const [];
    return [for (final m in list) AppMeta.fromMap(m as Map<Object?, Object?>)!];
  }
}
