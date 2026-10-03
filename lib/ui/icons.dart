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
  static const sun = IconData(0xe472, fontFamily: _f);
  static const moon = IconData(0xe330, fontFamily: _f);
  static const fire = IconData(0xe242, fontFamily: _f);
  static const walk = IconData(0xe73a, fontFamily: _f);
  static const target = IconData(0xe47c, fontFamily: _f);
  static const lightning = IconData(0xe2de, fontFamily: _f);
  static const mountains = IconData(0xe7ae, fontFamily: _f);
  static const heartbeat = IconData(0xe2ac, fontFamily: _f);
  static const gear = IconData(0xe272, fontFamily: _f);
  static const chartBar = IconData(0xe150, fontFamily: _f);
  static const footprints = IconData(0xea88, fontFamily: _f);
  static const code = IconData(0xe1bc, fontFamily: _f);
  static const user = IconData(0xe4c2, fontFamily: _f);
  static const palette = IconData(0xe6c8, fontFamily: _f);
  static const shieldCheck = IconData(0xe40c, fontFamily: _f);
  static const sliders = IconData(0xe432, fontFamily: _f);
  static const ticket = IconData(0xe490, fontFamily: _f);
  static const arrowCounterClockwise = IconData(0xe038, fontFamily: _f);
}

/// Phosphor Fill, same code points, for selected states.
abstract final class PhFill {
  static const _f = 'PhosphorFill';
  static const mountains = IconData(0xe7ae, fontFamily: _f);
  static const heartbeat = IconData(0xe2ac, fontFamily: _f);
  static const squaresFour = IconData(0xe464, fontFamily: _f);
  static const gear = IconData(0xe272, fontFamily: _f);
  static const chartBar = IconData(0xe150, fontFamily: _f);
}
