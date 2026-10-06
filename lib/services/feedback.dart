import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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

/// Posts a message to the developer's Discord. Sends only what the user typed, the reply
/// address they chose to give, and the app and Android version.
class FeedbackSender {
  FeedbackSender({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<void> send({
    required FeedbackKind kind,
    required String message,
    String replyTo = '',
    required String appVersion,
    String? osVersion,
  }) async {
    if (!kind.configured) {
      throw StateError('No webhook for ${kind.name} in this build');
    }
    final body = feedbackPayload(
      kind: kind,
      message: message,
      replyTo: replyTo,
      appVersion: appVersion,
      osVersion: osVersion ?? Platform.operatingSystemVersion,
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
        ],
      },
    ],
  };
}

// Discord rejects empty field values and ones over 1024 characters
String _field(String s) =>
    s.isEmpty ? '-' : (s.length > 1024 ? s.substring(0, 1024) : s);
