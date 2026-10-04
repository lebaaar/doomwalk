/// Which apps count, and how much. Pure Dart.
library;

const selfPackage = 'com.lebaaar.doomwalk';

/// Class name Android reports for window events from our own activity.
const selfActivity = '$selfPackage.MainActivity';

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

/// What kind of app a package is. Only some categories are restricted
/// (counted and frosted); by default just social and video feeds. Banking,
/// phone, messaging, maps and everything else land in [other] and are left
/// alone unless the user restricts them explicitly.
enum AppCategory { social, video, games, news, browser, other }

extension AppCategoryX on AppCategory {
  String get label => switch (this) {
        AppCategory.social => 'Social media',
        AppCategory.video => 'Video and short video',
        AppCategory.games => 'Games',
        AppCategory.news => 'News',
        AppCategory.browser => 'Browsers',
        AppCategory.other => 'Everything else',
      };
}

const defaultRestricted = {AppCategory.social, AppCategory.video};

/// Android ApplicationInfo.category values passed from native.
AppCategory categoryFromAndroid(int c) => switch (c) {
      0 => AppCategory.games, // CATEGORY_GAME
      2 => AppCategory.video, // CATEGORY_VIDEO
      4 => AppCategory.social, // CATEGORY_SOCIAL
      5 => AppCategory.news, // CATEGORY_NEWS
      _ => AppCategory.other, // incl. undeclared (-1), maps, productivity, finance
    };

/// Many apps don't declare a manifest category, so the big feeds are known
/// by package name.
const knownCategories = <String, AppCategory>{
  'com.instagram.android': AppCategory.social,
  'com.instagram.barcelona': AppCategory.social,
  'com.facebook.katana': AppCategory.social,
  'com.facebook.lite': AppCategory.social,
  'com.twitter.android': AppCategory.social,
  'com.snapchat.android': AppCategory.social,
  'com.reddit.frontpage': AppCategory.social,
  'com.pinterest': AppCategory.social,
  'com.tumblr': AppCategory.social,
  'com.linkedin.android': AppCategory.social,
  'org.joinmastodon.android': AppCategory.social,
  'xyz.blueskyweb.app': AppCategory.social,
  'com.bereal.ft': AppCategory.social,
  'com.zhiliaoapp.musically': AppCategory.video,
  'com.ss.android.ugc.trill': AppCategory.video,
  'com.google.android.youtube': AppCategory.video,
  'tv.twitch.android.app': AppCategory.video,
  'com.android.chrome': AppCategory.browser,
  'org.mozilla.firefox': AppCategory.browser,
  'com.brave.browser': AppCategory.browser,
  'com.sec.android.app.sbrowser': AppCategory.browser,
  'com.microsoft.emmx': AppCategory.browser,
  'com.opera.browser': AppCategory.browser,
  'com.duckduckgo.mobile.android': AppCategory.browser,
  'com.google.android.apps.magazines': AppCategory.news,
  'flipboard.app': AppCategory.news,
};

class AppCatalog {
  AppCatalog({
    Set<String> extraExempt = const {},
    Map<String, bool> overrides = const {},
    Set<AppCategory> restricted = defaultRestricted,
  })  : _extraExempt = {...extraExempt},
        overrides = {...overrides},
        restricted = {...restricted};

  final Set<String> _extraExempt;

  /// Per-app choice that beats the category rules: true = always counts,
  /// false = never counts.
  final Map<String, bool> overrides;

  /// Categories that are counted and frosted.
  final Set<AppCategory> restricted;

  /// Categories reported by Android for installed apps.
  final Map<String, AppCategory> categories = {};

  void addExempt(Iterable<String> pkgs) => _extraExempt.addAll(pkgs);

  bool isExempt(String pkg) =>
      pkg.isEmpty || exemptPackages.contains(pkg) || _extraExempt.contains(pkg);

  AppCategory categoryOf(String pkg) => knownCategories[pkg] ?? categories[pkg] ?? AppCategory.other;

  /// Whether the category rules alone restrict [pkg], ignoring overrides.
  bool restrictedByDefault(String pkg) => restricted.contains(categoryOf(pkg));

  /// Whether scrolling in [pkg] counts (and the app can frost).
  bool isRestricted(String pkg) {
    if (isExempt(pkg)) return false;
    return overrides[pkg] ?? restrictedByDefault(pkg);
  }
}
