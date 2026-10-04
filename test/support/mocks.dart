// Shared mocks for the native shim and plugins.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const nativeChannel = 'com.lebaaar.doomwalk/native';
const codec = StandardMethodCodec();

final frostCalls = <double>[];

/// Full `setFrost` arguments (title, body, ...), newest last.
final frostArgs = <Map<Object?, Object?>>[];
final notices = <Map<Object?, Object?>>[];
final notifications = <Map<Object?, Object?>>[];
final widgetData = <String, Object?>{};

const appLabels = {
  'com.instagram.android': 'Instagram',
  'com.zhiliaoapp.musically': 'TikTok',
  'com.android.chrome': 'Chrome',
  'com.reddit.frontpage': 'Reddit',
  'com.google.android.apps.maps': 'Maps',
};

/// Launcher icons for the screenshots, drawn in test/assets/icons (only
/// some apps have one; the rest get the app's placeholder).
Uint8List? appIcon(String pkg) {
  final f = File('test/assets/icons/$pkg.png');
  return f.existsSync() ? f.readAsBytesSync() : null;
}

Future<void> sendNative(String method, [Object? args]) async {
  final binding = TestDefaultBinaryMessengerBinding.instance;
  await binding.defaultBinaryMessenger.handlePlatformMessage(
    nativeChannel,
    codec.encodeMethodCall(MethodCall(method, args)),
    (_) {},
  );
}

Map<String, Object?> scrollEvent(String pkg, int t, int dy) =>
    {'pkg': pkg, 'cls': 'androidx.recyclerview.widget.RecyclerView', 't': t, 'win': 1, 'dx': 0, 'dy': dy};

/// Merged over the default `status` reply, to fake a stopped service etc.
final statusOverrides = <String, Object?>{};
int restartCalls = 0;

void installMocks() {
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(const MethodChannel(nativeChannel), (call) async {
    switch (call.method) {
      case 'ready':
      case 'status':
        return {
          'ydpi': 400.0,
          'densityDpi': 420.0,
          'screenHeightPx': 2400.0,
          'sdk': 34,
          'launchers': ['com.google.android.apps.nexuslauncher'],
          'keyboards': ['com.google.android.inputmethod.latin'],
          'bootTimeMs': 0,
          'accessibilityEnabled': true,
          'serviceConnected': true,
          'ignoringBatteryOptimizations': true,
          'restrictedSettingsAllowed': true,
          'blurEnabled': true,
          ...statusOverrides,
        };
      case 'showNotice':
        notices.add(call.arguments as Map<Object?, Object?>);
        return true;
      case 'restartAccessibility':
        restartCalls++;
        return statusOverrides['canRestartService'] == true;
      case 'setFrost':
        frostCalls.add((call.arguments as Map)['level'] as double);
        frostArgs.add(call.arguments as Map<Object?, Object?>);
        return true;
      case 'updateNotification':
        notifications.add(call.arguments as Map<Object?, Object?>);
        return null;
      case 'appInfo':
        final pkg = (call.arguments as Map)['pkg'] as String;
        return {'pkg': pkg, 'label': appLabels[pkg] ?? pkg, 'category': 4, 'icon': appIcon(pkg)};
      case 'launchableApps':
        return [
          for (final e in appLabels.entries) {'pkg': e.key, 'label': e.value, 'category': -1, 'icon': appIcon(e.key)},
        ];
      default:
        return null;
    }
  });
  m.setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
    if (call.method == 'saveWidgetData') {
      final a = call.arguments as Map;
      widgetData[a['id'] as String] = a['data'];
    }
    return true;
  });
  m.setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => 0 /* denied */);
}

