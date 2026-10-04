import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/scroll_wallet.dart';
import '../core/units.dart';
import 'icons.dart';
import 'logo.dart';
import 'price_table.dart';
import 'theme.dart';

/// How DoomWalk works, told like stories: full-screen slides with progress
/// bars on top. Tap the right side for the next one, the left for the
/// previous one, hold to pause; each moves on by itself after a few seconds.
class IntroStories extends StatefulWidget {
  const IntroStories({super.key, required this.config, required this.onDone, this.doneLabel = 'Set it up'});

  /// The numbers the slides quote (bank size, price steps, stride).
  final WalletConfig config;
  final VoidCallback onDone;
  final String doneLabel;

  @override
  State<IntroStories> createState() => _IntroStoriesState();
}

class _IntroStoriesState extends State<IntroStories> with SingleTickerProviderStateMixin {
  static const _slideTime = Duration(seconds: 7);

  late final AnimationController _timer = AnimationController(vsync: this, duration: _slideTime)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  int _index = 0;

  List<_Slide> get _slides => _buildSlides(widget.config);

  @override
  void initState() {
    super.initState();
    _timer.forward();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  void _go(int i) {
    final last = _slides.length - 1;
    if (i < 0) i = 0;
    if (i > last) {
      // The last slide waits for its button rather than closing by itself.
      _timer.stop();
      return;
    }
    setState(() => _index = i);
    _timer
      ..reset()
      ..forward();
  }

  void _next() => _go(_index + 1);
  void _previous() => _go(_index - 1);

  /// A press shorter than this is a tap (go on or back); longer is a hold,
  /// which only pauses.
  static const _tapTime = Duration(milliseconds: 250);
  int? _pointer;
  Duration? _downAt;

  void _onDown(PointerDownEvent e) {
    if (_pointer != null) return; // a second finger changes nothing
    _pointer = e.pointer;
    _downAt = e.timeStamp;
    _timer.stop();
  }

  void _onUp(PointerUpEvent e, double width) {
    if (e.pointer != _pointer) return;
    final held = e.timeStamp - _downAt!;
    _pointer = null;
    if (held < _tapTime) {
      e.localPosition.dx < width / 3 ? _previous() : _next();
    } else {
      _resume();
    }
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _resume();
  }

  void _resume() {
    // The last slide stays put once its bar is full.
    if (_timer.value < 1) _timer.forward();
  }

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final t = Theme.of(context).textTheme;
    final slides = _slides;
    final slide = slides[_index];
    final last = _index == slides.length - 1;
    // Light icons on see-through status and navigation bars, so the slide
    // runs edge to edge. (SystemUiOverlayStyle.light paints the navigation
    // bar black.)
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle(Brightness.dark),
      child: Scaffold(
        backgroundColor: col.heroFrom,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.0, -1.0),
              radius: 1.4,
              colors: [col.heroTo.withValues(alpha: 0.38), col.heroTo.withValues(alpha: 0)],
            ),
          ),
          child: SafeArea(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: AnimatedBuilder(
                      animation: _timer,
                      builder: (context, _) => Row(
                        children: [
                          for (var i = 0; i < slides.length; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: i < _index ? 1 : (i == _index ? _timer.value : 0),
                                  minHeight: 3,
                                  color: col.onHero,
                                  backgroundColor: col.onHero.withValues(alpha: 0.25),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 4, 0),
                    child: Row(
                      children: [
                        DepthTicks(size: 22, color: col.onHero),
                        const SizedBox(width: 8),
                        Text('DoomWalk', style: t.titleSmall?.copyWith(color: col.onHero)),
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: col.onHeroMuted),
                          onPressed: widget.onDone,
                          child: Text(last ? 'Close' : 'Skip'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    // Raw pointers, not a long-press recognizer: the story
                    // pauses the moment a finger lands, like Instagram's.
                    child: LayoutBuilder(
                      builder: (context, box) => Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _onDown,
                        onPointerUp: (e) => _onUp(e, box.maxWidth),
                        onPointerCancel: (e) => _onCancel(e),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: KeyedSubtree(
                            key: ValueKey(_index),
                            child: _SlideView(slide: slide),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (last)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: col.onHero,
                          foregroundColor: col.heroFrom,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: widget.onDone,
                        child: Text(widget.doneLabel),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        'Tap to go on · hold to pause',
                        textAlign: TextAlign.center,
                        style: t.bodySmall?.copyWith(color: col.onHeroMuted),
                      ),
                    ),
                ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.title, required this.body, required this.visual});
  final String title;
  final String body;
  final Widget visual;
}

List<_Slide> _buildSlides(WalletConfig c) {
  final cap = formatRound(c.bankCapM);
  final start = formatTimes(c.startPrice);
  final fillSteps = c.strideM <= 0 ? 0 : (c.bankCapM * c.startPrice / c.strideM).ceil();
  return [
    const _Slide(
      title: 'Want to scroll?\nTake a walk first.',
      body: 'DoomWalk turns walking into scrolling. No walk, no feed.',
      visual: _LogoVisual(),
    ),
    const _Slide(
      title: 'Your scrolling, in metres',
      body:
          'Every swipe in Instagram, TikTok and the like is measured in real metres. '
          'A long evening on the feed easily passes a few hundred.',
      visual: _BigFigure(value: '347 m', caption: 'scrolled today', icon: Ph.squaresFour),
    ),
    _Slide(
      title: 'Walking fills a small bank',
      body:
          'It starts empty every day and holds up to $cap of scrolling, at $start from the first step: '
          '${formatRound(c.startPrice).replaceAll(' ', '\u00A0')} walked per metre. Once it\'s full, walking '
          'adds nothing, so a long commute can\'t buy a day of scrolling.',
      visual: _BankVisual(
        cap: c.bankCapM,
        caption: '${formatCount(fillSteps)} steps fill it',
      ),
    ),
    _Slide(
      title: 'The more you scroll, the more it costs',
      body:
          'It starts at $start and goes up a tier every ${formatRound(c.priceStepM)} you scroll in a day: '
          '${tiersText(c.priceTiers)}.',
      visual: _TableVisual(config: c),
    ),
    _Slide(
      title: 'Bank empty? The app freezes',
      body:
          'Keep scrolling with an empty bank and the app frosts over until you walk. '
          'Calls, maps, banking and emergency apps are never touched.',
      visual: _FrostVisual(steps: fillSteps, unlocks: cap),
    ),
    const _Slide(
      title: 'Emergency? Use a pass',
      body: 'Three a day, five minutes each. Scrolling during a pass is free.',
      visual: _BigFigure(value: '3', caption: 'passes a day', icon: Ph.lifebuoy),
    ),
    _Slide(
      title: 'Every midnight, a fresh start',
      body: 'The bank empties and walking is back to $start. Nothing carries over, nothing grows.',
      visual: _BigFigure(value: '00:00', caption: 'back to $start', icon: Ph.moon),
    ),
    const _Slide(
      title: 'Nothing leaves your phone',
      body:
          'No internet permission, no accounts, no analytics. DoomWalk measures how far you scroll, '
          'never what\'s on screen.',
      visual: _BigFigure(value: '0', caption: 'bytes sent anywhere', icon: Ph.shieldCheck),
    ),
  ];
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Center(child: slide.visual)),
          const SizedBox(height: 24),
          Text(
            slide.title,
            style: t.headlineLarge?.copyWith(color: col.onHero, fontSize: 32, letterSpacing: -1.2, height: 1.1),
          ),
          const SizedBox(height: 12),
          Text(slide.body, style: t.bodyLarge?.copyWith(color: col.onHeroMuted, height: 1.45)),
        ],
      ),
    );
  }
}

class _LogoVisual extends StatelessWidget {
  const _LogoVisual();

  @override
  Widget build(BuildContext context) => DepthTicks(size: 140, color: context.colors.onHero);
}

class _BigFigure extends StatelessWidget {
  const _BigFigure({required this.value, required this.caption, required this.icon});
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final t = Theme.of(context).textTheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: col.onHeroMuted),
          const SizedBox(height: 12),
          Text(
            value,
            style: t.displayLarge?.copyWith(color: col.onHero, fontSize: 88, letterSpacing: -4, fontFeatures: tabular),
          ),
          Text(caption, style: t.titleMedium?.copyWith(color: col.onHeroMuted)),
        ],
      ),
    );
  }
}

/// The bank bar filling from [from] to [to] of [cap].
class _BankVisual extends StatelessWidget {
  const _BankVisual({required this.cap, required this.caption});
  final double cap;

  /// Under the bar while it fills; "Bank full" once it is.
  final String caption;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final t = Theme.of(context).textTheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 3000),
      curve: Curves.easeInOutCubic,
      builder: (context, v, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Ph.footprints, size: 22, color: col.onHero),
              const SizedBox(width: 8),
              Text('In the bank', style: t.titleMedium?.copyWith(color: col.onHero)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 22,
              color: col.onHero,
              backgroundColor: col.onHero.withValues(alpha: 0.16),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${formatRound(v * cap)} of ${formatRound(cap)}',
            style: t.headlineMedium?.merge(numeric).copyWith(color: col.onHero),
          ),
          const SizedBox(height: 4),
          Text(
            v >= 0.999 ? 'Bank full: walking adds nothing' : caption,
            style: t.bodyLarge?.copyWith(color: v >= 0.999 ? col.onHero : col.onHeroMuted),
          ),
        ],
      ),
    );
  }
}

class _TableVisual extends StatelessWidget {
  const _TableVisual({required this.config});
  final WalletConfig config;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: col.raised, borderRadius: BorderRadius.circular(Radii.surface)),
      child: PriceTable(config: config, currentPrice: config.startPrice),
    );
  }
}

/// A frosted phone screen with the card it shows.
class _FrostVisual extends StatelessWidget {
  const _FrostVisual({required this.steps, required this.unlocks});
  final int steps;
  final String unlocks;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final t = Theme.of(context).textTheme;
    Widget post(double w) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 46,
      width: w,
      decoration: BoxDecoration(color: col.onHero.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(8)),
    );
    return AspectRatio(
      aspectRatio: 0.62,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: col.onHero.withValues(alpha: 0.3), width: 2),
          color: const Color(0xFFE2F0F8).withValues(alpha: 0.18),
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // As many posts as fit; the rest is cut off like a real feed.
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: Column(children: [for (var i = 0; i < 9; i++) post(i % 3 == 2 ? 120 : double.infinity)]),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: col.raised, borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Take a walk first', style: t.titleSmall?.copyWith(color: col.text)),
                  const SizedBox(height: 4),
                  Text(
                    '${formatCount(steps)} steps put $unlocks in the bank.',
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(color: col.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
