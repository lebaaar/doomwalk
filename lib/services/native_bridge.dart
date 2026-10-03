import 'package:flutter/services.dart';

/// Device facts reported by the native shim on `ready`.
class DeviceInfo {
  DeviceInfo(Map<Object?, Object?> m)
      : ydpi = (m['ydpi'] as num?)?.toDouble() ?? 0,
        densityDpi = (m['densityDpi'] as num?)?.toDouble() ?? 420,
        screenHeightPx = (m['screenHeightPx'] as num?)?.toDouble() ?? 2400,
        sdk = (m['sdk'] as num?)?.toInt() ?? 31,
        launchers = [...(m['launchers'] as List? ?? const []).cast<String>()],
        keyboards = [...(m['keyboards'] as List? ?? const []).cast<String>()],
        bootTime = DateTime.fromMillisecondsSinceEpoch((m['bootTimeMs'] as num?)?.toInt() ?? 0);

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
        sdk = (m['sdk'] as num?)?.toInt() ?? 31;

  NativeStatus.unknown()
      : accessibilityEnabled = false,
        serviceConnected = false,
        ignoringBatteryOptimizations = false,
        restrictedSettingsAllowed = null,
        blurEnabled = false,
        sdk = 31;

  final bool accessibilityEnabled;
  final bool serviceConnected;
  final bool ignoringBatteryOptimizations;
  final bool? restrictedSettingsAllowed;
  final bool blurEnabled;
  final int sdk;
}

class AppMeta {
  AppMeta({required this.pkg, required this.label, this.category = -1, this.icon});
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

/// Thin wrapper over the shim's MethodChannel.
class NativeBridge {
  static const _ch = MethodChannel('com.lan.scrolldebt/native');

  void setHandler(Future<Object?> Function(MethodCall call) handler) =>
      _ch.setMethodCallHandler(handler);

  Future<(DeviceInfo, NativeStatus)> ready() async {
    final m = await _ch.invokeMapMethod<Object?, Object?>('ready') ?? const {};
    return (DeviceInfo(m), NativeStatus(m));
  }

  Future<NativeStatus> status() async {
    try {
      return NativeStatus(await _ch.invokeMapMethod<Object?, Object?>('status') ?? const {});
    } on PlatformException {
      return NativeStatus.unknown();
    }
  }

  Future<void> setFrost(double level, {String? label, int animateMs = 600}) =>
      _ch.invokeMethod('setFrost', {'level': level, 'label': label, 'animateMs': animateMs});

  Future<void> updateNotification({
    required String title,
    required String text,
    required int overridesLeft,
    required bool overrideActive,
  }) =>
      _ch.invokeMethod('updateNotification', {
        'title': title,
        'text': text,
        'overridesLeft': overridesLeft,
        'overrideActive': overrideActive,
      });

  Future<void> startForegroundService() => _ch.invokeMethod('startForegroundService');
  Future<void> openAccessibilitySettings() => _ch.invokeMethod('openAccessibilitySettings');
  Future<void> openAppDetails() => _ch.invokeMethod('openAppDetails');
  Future<void> requestIgnoreBatteryOptimizations() =>
      _ch.invokeMethod('requestIgnoreBatteryOptimizations');

  Future<AppMeta?> appInfo(String pkg) async =>
      AppMeta.fromMap(await _ch.invokeMapMethod<Object?, Object?>('appInfo', {'pkg': pkg}));

  Future<List<AppMeta>> launchableApps() async {
    final list = await _ch.invokeListMethod<Object?>('launchableApps') ?? const [];
    return [for (final m in list) AppMeta.fromMap(m as Map<Object?, Object?>)!];
  }
}
