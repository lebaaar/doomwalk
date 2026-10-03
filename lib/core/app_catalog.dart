/// Which apps count, and how much. Pure Dart.
library;

const selfPackage = 'com.lan.scrolldebt';

/// Never counted, never frosted. The native shim adds the device's actual
/// launcher(s) and enabled keyboards at runtime on top of this list.
const exemptPackages = <String>{
  selfPackage,
  // System UI, shade, settings.
  'android',
  'com.android.systemui',
  'com.android.settings',
  'com.samsung.android.settings',
  'com.android.permissioncontroller',
  'com.google.android.permissioncontroller',
  'com.google.android.packageinstaller',
  'com.android.packageinstaller',
  // Dialers / calls.
  'com.android.dialer',
  'com.google.android.dialer',
  'com.samsung.android.dialer',
  'com.samsung.android.incallui',
  'com.android.phone',
  'com.android.server.telecom',
  'com.android.incallui',
  // Emergency.
  'com.android.emergency',
  'com.google.android.apps.safetyhub',
  'com.android.cellbroadcastreceiver',
  'com.google.android.cellbroadcastreceiver',
  'com.samsung.android.emergency',
  // Launchers.
  'com.google.android.apps.nexuslauncher',
  'com.android.launcher',
  'com.android.launcher3',
  'com.sec.android.app.launcher',
  'com.miui.home',
  'com.oneplus.launcher',
  'com.oppo.launcher',
  'com.huawei.android.launcher',
  'com.motorola.launcher3',
  'com.nothing.launcher',
  'app.lawnchair',
  // Keyboards.
  'com.google.android.inputmethod.latin',
  'com.samsung.android.honeyboard',
  'com.touchtype.swiftkey',
  'com.android.inputmethod.latin',
};

enum AppCategory { social, news, browser, reference, other }

/// Android ApplicationInfo.category values passed from native.
AppCategory categoryFromAndroid(int c) => switch (c) {
      4 => AppCategory.social, // CATEGORY_SOCIAL
      2 => AppCategory.social, // CATEGORY_VIDEO (short-video feeds)
      5 => AppCategory.news, // CATEGORY_NEWS
      6 => AppCategory.reference, // CATEGORY_MAPS
      7 => AppCategory.reference, // CATEGORY_PRODUCTIVITY
      _ => AppCategory.other,
    };

const knownRates = <String, double>{
  // Social / short video: 2x.
  'com.instagram.android': 2,
  'com.instagram.barcelona': 2,
  'com.zhiliaoapp.musically': 2,
  'com.ss.android.ugc.trill': 2,
  'com.facebook.katana': 2,
  'com.facebook.lite': 2,
  'com.twitter.android': 2,
  'com.snapchat.android': 2,
  'com.reddit.frontpage': 2,
  'com.google.android.youtube': 2,
  'com.pinterest': 2,
  'com.tumblr': 2,
  'tv.twitch.android.app': 2,
  'com.linkedin.android': 2,
  'org.joinmastodon.android': 2,
  'xyz.blueskyweb.app': 2,
  'com.bereal.ft': 2,
  // News / browsers: 1x.
  'com.android.chrome': 1,
  'org.mozilla.firefox': 1,
  'com.brave.browser': 1,
  'com.sec.android.app.sbrowser': 1,
  'com.microsoft.emmx': 1,
  'com.opera.browser': 1,
  'com.duckduckgo.mobile.android': 1,
  'com.google.android.apps.magazines': 1,
  'com.google.android.googlequicksearchbox': 1,
  'flipboard.app': 1,
  // Reference / tools: 0x (whitelisted).
  'com.google.android.apps.maps': 0,
  'com.waze': 0,
  'com.amazon.kindle': 0,
  'com.google.android.apps.books': 0,
  'com.google.android.apps.docs': 0,
  'com.google.android.apps.docs.editors.docs': 0,
  'com.google.android.apps.docs.editors.sheets': 0,
  'com.google.android.apps.docs.editors.slides': 0,
  'com.microsoft.office.word': 0,
  'com.adobe.reader': 0,
  'org.wikipedia': 0,
};

double defaultRateFor(String pkg, {AppCategory? category}) {
  final known = knownRates[pkg];
  if (known != null) return known;
  return switch (category) {
    AppCategory.social => 2,
    AppCategory.news || AppCategory.browser => 1,
    AppCategory.reference => 0,
    _ => 1,
  };
}

String rateLabel(double r) => r == 0 ? 'free' : '${r % 1 == 0 ? r.toInt() : r}×';

class AppCatalog {
  AppCatalog({Set<String> extraExempt = const {}, Map<String, double> overrides = const {}})
      : _extraExempt = {...extraExempt},
        overrides = {...overrides};

  final Set<String> _extraExempt;
  final Map<String, double> overrides;
  final Map<String, AppCategory> categories = {};

  void addExempt(Iterable<String> pkgs) => _extraExempt.addAll(pkgs);

  bool isExempt(String pkg) =>
      pkg.isEmpty || exemptPackages.contains(pkg) || _extraExempt.contains(pkg);

  double rateFor(String pkg) {
    if (isExempt(pkg)) return 0;
    return overrides[pkg] ?? defaultRateFor(pkg, category: categories[pkg]);
  }
}
