import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/feedback.dart';
import 'icons.dart';
import 'logo.dart';
import 'theme.dart';

const playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.lebaaar.doomwalk';
const sourceCodeUrl = 'https://github.com/lebaaar/doomwalk';
const kofiUrl = 'https://ko-fi.com/lebaaar';
const contactEmail = 'doomwalk@lan.si';

enum UpdateStatus { checking, available, none }

/// Asks Google Play whether a newer build exists. Play answers only for installs that came
/// from Play, so a sideloaded or debug build reads as "no update".
typedef UpdateCheck = Future<bool> Function();

Future<bool> playUpdateCheck() async {
  try {
    final info = await InAppUpdate.checkForUpdate();
    return info.updateAvailability == UpdateAvailability.updateAvailable;
  } catch (_) {
    return false;
  }
}

/// Opens [url] in its own app (Play, the browser), never inside DoomWalk
Future<void> openExternal(BuildContext context, String url) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No app can open that link')));
  }
}

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({
    super.key,
    this.checkForUpdate = playUpdateCheck,
    this.minimumCheck = const Duration(seconds: 1),
    this.diagnostics,
  });

  final UpdateCheck checkForUpdate;

  /// The spinner stays at least this long, so a fast answer doesn't flash past
  final Duration minimumCheck;

  /// App state attached to bug reports, read when the report is sent
  final Future<Map<String, String>> Function()? diagnostics;

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  var _update = UpdateStatus.checking;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final results = await Future.wait<Object?>([
      widget.checkForUpdate().catchError((Object _) => false),
      Future<void>.delayed(widget.minimumCheck),
    ]);
    if (!mounted) return;
    setState(
      () => _update = results.first == true
          ? UpdateStatus.available
          : UpdateStatus.none,
    );
  }

  Future<void> _performUpdate() async {
    var result = AppUpdateResult.inAppUpdateFailed;
    try {
      result = await InAppUpdate.performImmediateUpdate();
    } catch (_) {}
    if (result == AppUpdateResult.inAppUpdateFailed && mounted) {
      await openExternal(context, playStoreUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        // Clears the system navigation bar; settings gets this from the tab bar
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: col.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: DepthTicks(size: 68, color: col.onAccent),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'DoomWalk',
            textAlign: TextAlign.center,
            style: t.headlineMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<PackageInfo>(
            future: _info,
            builder: (context, snap) {
              final i = snap.data;
              return _VersionLine(
                version: i == null ? '' : 'v${i.version}+${i.buildNumber}',
                status: _update,
                onPlay: () => openExternal(context, playStoreUrl),
                onUpdate: _performUpdate,
              );
            },
          ),
          const SizedBox(height: 12),
          const SectionTitle('About'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.margin + 4),
            child: Text(
              'DoomWalk makes you walk before you can doomscroll. It measures how far you '
              'scroll in social and video apps, in actual metres, and only lets you scroll as '
              'far as you have walked. It never collects any personal data about you and contains no ads.',
              style: t.bodyLarge?.copyWith(height: 1.45),
            ),
          ),
          const SectionTitle('Support'),
          TileGroup(
            dividerIndent: 64,
            children: [
              _LinkRow(
                icon: Ph.envelopeSimple,
                title: 'Contact developer',
                subtitle: 'Have questions or suggestions?',
                onTap: () => _openForm(context, FeedbackKind.contact),
              ),
              _LinkRow(
                icon: Ph.bug,
                title: 'Report a bug',
                subtitle: 'Help improve the app',
                onTap: () => _openForm(context, FeedbackKind.bug),
              ),
            ],
          ),
          const SectionTitle('Development'),
          TileGroup(
            dividerIndent: 64,
            children: [
              _LinkRow(
                icon: Ph.code,
                title: 'View source code',
                subtitle: 'Open GitHub',
                onTap: () => openExternal(context, sourceCodeUrl),
              ),
              _LinkRow(
                icon: PhFill.heart,
                title: 'Buy me a Ko-fi ☕',
                subtitle: 'Support the development',
                highlight: true,
                onTap: () => openExternal(context, kofiUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, FeedbackKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FeedbackScreen(kind: kind, diagnostics: widget.diagnostics),
      ),
    );
  }
}

class _VersionLine extends StatelessWidget {
  const _VersionLine({
    required this.version,
    required this.status,
    required this.onPlay,
    required this.onUpdate,
  });

  final String version;
  final UpdateStatus status;
  final VoidCallback onPlay;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final style = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(color: col.muted, fontFeatures: tabular);
    final Widget trailing = switch (status) {
      UpdateStatus.checking => Row(
        key: const ValueKey('checking'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Checking for updates', style: style),
        ],
      ),
      UpdateStatus.available => _InlineLink(
        key: const ValueKey('available'),
        label: 'Update available',
        icon: Ph.downloadSimple,
        color: col.accent,
        style: style,
        onTap: onUpdate,
      ),
      UpdateStatus.none => _InlineLink(
        key: const ValueKey('none'),
        label: 'View on Google Play',
        color: col.muted,
        style: style,
        onTap: onPlay,
      ),
    };
    // Wraps onto two lines with large text instead of overflowing
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(version, style: style),
        Text('  •  ', style: style),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: trailing,
        ),
      ],
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({
    super.key,
    required this.label,
    required this.color,
    required this.style,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.tag),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: style?.copyWith(
                color: color,
                decoration: TextDecoration.underline,
                decorationColor: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Accent title, icon and arrow, for the Ko-fi row
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    return ListTile(
      leading: IconBadge(icon: icon, foreground: highlight ? col.accent : null),
      title: Text(
        title,
        style: highlight ? TextStyle(color: col.accent) : null,
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        Ph.caretRight,
        size: 18,
        color: highlight ? col.accent : col.muted,
      ),
      onTap: onTap,
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.kind,
    this.sender,
    this.diagnostics,
  });

  final FeedbackKind kind;
  final Future<Map<String, String>> Function()? diagnostics;
  final FeedbackSender? sender;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  final _reply = TextEditingController();
  late final _sender = widget.sender ?? FeedbackSender();
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    _reply.dispose();
    super.dispose();
  }

  bool get _bug => widget.kind == FeedbackKind.bug;

  Future<void> _send() async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final i = await PackageInfo.fromPlatform();
      await _sender.send(
        kind: widget.kind,
        message: _message.text,
        replyTo: _reply.text,
        appVersion: '${i.version}+${i.buildNumber}',
        diagnostics: _bug
            ? {
                if (i.installerStore != null)
                  'Installed from': i.installerStore!,
                ...?await widget.diagnostics?.call(),
              }
            : const {},
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _bug ? 'Bug report sent, thank you' : 'Message sent, thank you',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t send. Check your connection and try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final t = Theme.of(context).textTheme;
    final configured = widget.kind.configured;
    final canSend = configured && !_sending && _message.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(_bug ? 'Report a bug' : 'Contact developer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.margin, 4, Gaps.margin, 32),
        children: [
          Text(
            _bug
                ? 'Please describe the bug: What happened and what did you expect to happen instead instead? Steps to reproduce the bug help a lot.'
                : 'Submit questions, ideas or anything else to help improve DoomWalk. Leave your email if you want an answer.',
            style: t.bodyMedium?.copyWith(color: col.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _message,
            enabled: !_sending,
            minLines: 6,
            maxLines: 12,
            maxLength: maxFeedbackLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _bug ? 'Describe the bug' : 'Your message',
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reply,
            enabled: !_sending,
            maxLength: 200,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email (optional)',
              contentPadding: EdgeInsets.all(14),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canSend ? _send : null,
            icon: _sending
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: col.muted,
                    ),
                  )
                : const Icon(Ph.paperPlaneTilt, size: 18),
            label: Text(_sending ? 'Sending' : 'Send'),
          ),
          const SizedBox(height: 12),
          if (configured)
            Text(
              _bug
                  ? 'Sent to the developer along with the app version, phone model, Android version and whether DoomWalk\'s permissions and background service are working. No personal information is included.'
                  : 'Sent to the developer along with the app and Android version. No personal information is included.',
              style: t.bodySmall,
            )
          else
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Can\'t send messages right now. Please write an email to ',
                  style: t.bodySmall,
                ),
                _InlineLink(
                  label: contactEmail,
                  color: col.accent,
                  style: t.bodySmall,
                  onTap: () => openExternal(context, 'mailto:$contactEmail'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
