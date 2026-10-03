import 'package:flutter/widgets.dart';

/// Phosphor Regular (MIT, assets/fonts/MIT-Phosphor.txt), bundled as a font.
/// The phosphor_flutter package no longer compiles on current Flutter, so
/// the few glyphs we use are declared here directly. One family, one weight.
abstract final class Ph {
  static const _f = 'Phosphor';
  static const slidersHorizontal = IconData(0xe434, fontFamily: _f);
  static const warningCircle = IconData(0xe4e2, fontFamily: _f);
  static const caretRight = IconData(0xe13a, fontFamily: _f);
  static const snowflake = IconData(0xe5aa, fontFamily: _f);
  static const lifebuoy = IconData(0xe63a, fontFamily: _f);
  static const squaresFour = IconData(0xe464, fontFamily: _f);
  static const listChecks = IconData(0xeadc, fontFamily: _f);
  static const lockSimple = IconData(0xe308, fontFamily: _f);
  static const trash = IconData(0xe4a6, fontFamily: _f);
  static const magnifyingGlass = IconData(0xe30c, fontFamily: _f);
  static const checkCircle = IconData(0xe184, fontFamily: _f);
  static const circle = IconData(0xe18a, fontFamily: _f);
  static const export = IconData(0xeaf0, fontFamily: _f);
  static const caretDown = IconData(0xe136, fontFamily: _f);
}
