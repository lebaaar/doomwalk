import 'package:flutter/material.dart';

/// Google Play prominent disclosure for the AccessibilityService API. Shown
/// before Android's accessibility settings open. Two explicit buttons, and
/// back or a tap outside does not count as consent.
Future<bool> confirmAccessibilityDisclosure(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (d) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Accessibility access'),
        content: const SingleChildScrollView(
          child: Text(
            'DoomWalk uses Android\'s AccessibilityService API to measure how far you scroll in other apps '
            'and to blur those apps once the scrolling you earned by walking is used up.\n\n'
            'To do this it receives scroll events and the name of the app that is open. It cannot read '
            'what is on your screen, and it does not collect text, passwords or personal information. '
            'Your scrolling and walking data never leaves your phone.\n\n'
            'Tap Agree, then switch DoomWalk on in Android\'s accessibility settings.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('No thanks'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Agree'),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}
