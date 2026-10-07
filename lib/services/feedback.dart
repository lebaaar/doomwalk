import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import 'controller.dart';

/// Where a message from App info goes. Each kind posts to its own Discord channel webhook
enum FeedbackKind {
  contact(
    'Message',
    0xA9D3EC,
    String.fromEnvironment('DISCORD_CONTACT_WEBHOOK'),
  ),
  bug('Bug report', 0xF2B8B5, String.fromEnvironment('DISCORD_BUG_WEBHOOK'));

  const FeedbackKind(this.label, this.color, this.webhook);
  final String label;
  final int color;

  /// Baked in at build time with --dart-define-from-file=.env; empty when the build has none
  final String webhook;

  bool get configured => webhook.isNotEmpty;
}

/// Discord caps an embed description at 4096 characters
const maxFeedbackLength = 4000;

/// Phone make and model, and the Android version with its SDK level. Falls back to the
/// bare OS string where device info isn't available
Future<({String os, String? device})> readDevice() async {
  try {
    final a = await DeviceInfoPlugin().androidInfo;
    final model = a.model.toLowerCase().startsWith(a.manufacturer.toLowerCase())
        ? a.model
        : '${a.manufacturer} ${a.model}';
    return (
      os: 'Android ${a.version.release} (SDK ${a.version.sdkInt})',
      device: model,
    );
  } catch (_) {
    return (os: Platform.operatingSystemVersion, device: null);
  }
}

/// Posts a message to the developer's Discord. Sends what the user typed, the reply
/// address they chose to give, and the app and Android version. A bug report also carries
/// the phone model and the [diagnostics] it is given; contact messages never do.
class FeedbackSender {
  FeedbackSender({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<void> send({
    required FeedbackKind kind,
    required String message,
    String replyTo = '',
    required String appVersion,
    String? osVersion,
    Map<String, String> diagnostics = const {},
  }) async {
    if (!kind.configured) {
      throw StateError('No webhook for ${kind.name} in this build');
    }
    final dev = osVersion == null
        ? await readDevice()
        : (os: osVersion, device: null);
    final body = feedbackPayload(
      kind: kind,
      message: message,
      replyTo: replyTo,
      appVersion: appVersion,
      osVersion: dev.os,
      diagnostics: kind == FeedbackKind.bug
          ? {if (dev.device != null) 'Phone': dev.device!, ...diagnostics}
          : const {},
    );
    final res = await _client
        .post(
          Uri.parse(kind.webhook),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Discord answered ${res.statusCode}');
    }
  }
}

Map<String, Object?> feedbackPayload({
  required FeedbackKind kind,
  required String message,
  required String replyTo,
  required String appVersion,
  required String osVersion,
  Map<String, String> diagnostics = const {},
}) {
  final text = message.trim();
  final reply = replyTo.trim();
  return {
    'username': 'DoomWalk',
    // Whatever the user types, never ping @everyone or a role
    'allowed_mentions': {'parse': <String>[]},
    'embeds': [
      {
        'title': kind.label,
        'description': text.length > maxFeedbackLength
            ? text.substring(0, maxFeedbackLength)
            : text,
        'color': kind.color,
        'fields': [
          if (reply.isNotEmpty)
            {'name': 'Reply to', 'value': _field(reply), 'inline': false},
          {'name': 'App', 'value': _field(appVersion), 'inline': true},
          {'name': 'Android', 'value': _field(osVersion), 'inline': true},
          if (diagnostics.isNotEmpty)
            {
              'name': 'Diagnostics',
              'value': _field(
                diagnostics.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n'),
              ),
              'inline': false,
            },
        ],
      },
    ],
  };
}

// Discord rejects empty field values and ones over 1024 characters
String _field(String s) =>
    s.isEmpty ? '-' : (s.length > 1024 ? s.substring(0, 1024) : s);

/// What the app knows about its own health, for a bug report. Only on/off states and the
/// last exit reason: no steps, scroll distances or app names.
Map<String, String> appDiagnostics(DoomWalkController c) {
  final st = c.status;
  String yn(bool v) => v ? 'yes' : 'no';
  final exit = st.lastExit;
  return {
    'Accessibility service': st.serviceConnected
        ? 'connected'
        : st.accessibilityEnabled
        ? 'enabled but not running'
        : 'off',
    'Step counting': c.walkError ?? (c.walkAvailable ? 'working' : 'off'),
    'Battery unrestricted': yn(st.ignoringBatteryOptimizations),
    if (st.restrictedSettingsAllowed != null)
      'Restricted settings allowed': yn(st.restrictedSettingsAllowed!),
    'Screen blur': yn(st.blurEnabled),
    'Locale': PlatformDispatcher.instance.locale.toLanguageTag(),
    if (exit != null)
      'Last exit': '${exit.label}, ${exit.time.toUtc().toIso8601String()}',
  };
}
