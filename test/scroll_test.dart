import 'package:flutter_test/flutter_test.dart';
import 'package:doomwalk/core/app_catalog.dart';
import 'package:doomwalk/core/flick_weigher.dart';
import 'package:doomwalk/core/scroll_interpreter.dart';

void main() {
  group('ScrollInterpreter', () {
    ScrollInterpreter make() => ScrollInterpreter(screenHeightPx: 2400, ydpi: 400);

    test('uses scrollDeltaY when present', () {
      final s = make().interpret(const RawScroll(pkg: 'a', cls: 'v', timeMs: 0, dy: 400));
      expect(s.source, ScrollSource.deltaY);
      expect(s.metres, closeTo(0.0254, 1e-12));
    });

    test('negative deltas (scrolling up) count too', () {
      final s = make().interpret(const RawScroll(pkg: 'a', cls: 'v', timeMs: 0, dx: 0, dy: -800));
      expect(s.pixels, 800);
    });

    test('pure horizontal scroll is ignored', () {
      final s = make().interpret(const RawScroll(pkg: 'a', cls: 'v', timeMs: 0, dx: 300, dy: 0));
      expect(s.metres, 0);
    });

    test('falls back to absolute scrollY differences', () {
      final i = make();
      expect(i.interpret(const RawScroll(pkg: 'c', cls: 'w', timeMs: 0, scrollY: 1000)).pixels, 0);
      final s = i.interpret(const RawScroll(pkg: 'c', cls: 'w', timeMs: 100, scrollY: 1600));
      expect(s.source, ScrollSource.scrollY);
      expect(s.pixels, 600);
    });

    test('RecyclerView item index changes are scaled by visible items', () {
      final i = make();
      i.interpret(const RawScroll(pkg: 'i', cls: 'rv', timeMs: 0, dx: 0, dy: 0, fromIndex: 3, toIndex: 6));
      final s = i.interpret(const RawScroll(pkg: 'i', cls: 'rv', timeMs: 100, dx: 0, dy: 0, fromIndex: 5, toIndex: 8));
      expect(s.source, ScrollSource.itemIndex);
      expect(s.pixels, 2 * 2400 / 4);
    });

    test('pager flips count one screen height each', () {
      final i = make();
      i.interpret(const RawScroll(pkg: 't', cls: 'pager', timeMs: 0, fromIndex: 0, toIndex: 0));
      final s = i.interpret(const RawScroll(pkg: 't', cls: 'pager', timeMs: 900, fromIndex: 1, toIndex: 1));
      expect(s.pixels, 2400);
    });

    test('huge jumps are capped at three screens', () {
      final s = make().interpret(const RawScroll(pkg: 'a', cls: 'v', timeMs: 0, dy: 99999));
      expect(s.pixels, 7200);
    });

    test('geometry-less events get a rate-limited estimate', () {
      final i = make();
      expect(i.interpret(const RawScroll(pkg: 'x', cls: 'y', timeMs: 0)).pixels, 600);
      expect(i.interpret(const RawScroll(pkg: 'x', cls: 'y', timeMs: 100)).pixels, 0);
      expect(i.interpret(const RawScroll(pkg: 'x', cls: 'y', timeMs: 500)).pixels, 600);
    });

    test('parses the native map', () {
      final r = RawScroll.fromMap({'pkg': 'p', 'cls': 'c', 't': 5, 'dy': 12, 'from': 2});
      expect(r.dy, 12);
      expect(r.fromIndex, 2);
      expect(r.scrollY, -1);
    });
  });

  group('FlickWeigher', () {
    test('slow reading scrolls are discounted', () {
      final w = FlickWeigher();
      var weight = 0.0;
      for (var t = 0; t < 10000; t += 1000) {
        weight = w.weigh('a', 0.02, t);
      }
      expect(weight, 0.5);
    });

    test('rapid repeated flicks cost more than a single flick', () {
      final w = FlickWeigher();
      final first = w.weigh('a', 0.8, 0);
      expect(first, 1.0);
      var last = first;
      // Separate bursts 1.5 s apart, each a fast flick.
      for (var k = 1; k <= 6; k++) {
        last = w.weigh('a', 0.8, k * 1500);
      }
      expect(last, greaterThan(1.5));
      expect(last, lessThanOrEqualTo(1.6));
    });

    test('state resets when the app changes', () {
      final w = FlickWeigher();
      for (var k = 0; k < 6; k++) {
        w.weigh('a', 0.8, k * 1500);
      }
      expect(w.weigh('b', 0.8, 9000), 1.0);
    });
  });

  group('AppCatalog', () {
    test('only social and video are restricted by default', () {
      final c = AppCatalog();
      expect(c.rateFor('com.instagram.android'), 2);
      expect(c.rateFor('com.zhiliaoapp.musically'), 2);
      expect(c.rateFor('com.android.chrome'), 0); // browser: not restricted
      expect(c.rateFor('com.google.android.apps.maps'), 0);
      expect(c.rateFor('si.nlb.klik'), 0); // a banking app: "other"
      c.categories['com.example.social'] = categoryFromAndroid(4);
      expect(c.rateFor('com.example.social'), 2);
      c.categories['com.example.game'] = categoryFromAndroid(0);
      expect(c.rateFor('com.example.game'), 0);
    });

    test('restricting a category turns its apps on', () {
      final c = AppCatalog(restricted: {...defaultRestricted, AppCategory.browser});
      expect(c.rateFor('com.android.chrome'), 1);
      c.restricted.remove(AppCategory.social);
      expect(c.rateFor('com.instagram.android'), 0);
    });

    test('per-app overrides win, exempt apps never count', () {
      final c = AppCatalog(overrides: {
        'com.android.chrome': 0.5,
        'com.instagram.android': 0,
        'com.android.settings': 3,
      });
      expect(c.rateFor('com.android.chrome'), 0.5);
      expect(c.rateFor('com.instagram.android'), 0);
      expect(c.isExempt('com.android.settings'), isTrue);
      expect(c.rateFor('com.android.settings'), 0);
      c.addExempt(['com.custom.launcher']);
      expect(c.isExempt('com.custom.launcher'), isTrue);
      expect(c.isExempt(selfPackage), isTrue);
    });
  });
}
