const selfPackage = 'com.lebaaar.doomwalk';

const selfActivity = '$selfPackage.MainActivity';

const exemptPackages = <String>{
  selfPackage,
  'android',
  'com.android.systemui',
  'com.android.settings',
  'com.samsung.android.settings',
  'com.android.permissioncontroller',
  'com.google.android.permissioncontroller',
  'com.google.android.packageinstaller',
  'com.android.packageinstaller',
  'com.android.dialer',
  'com.google.android.dialer',
  'com.samsung.android.dialer',
  'com.samsung.android.incallui',
  'com.android.phone',
  'com.android.server.telecom',
  'com.android.incallui',
  'com.android.emergency',
  'com.google.android.apps.safetyhub',
  'com.android.cellbroadcastreceiver',
  'com.google.android.cellbroadcastreceiver',
  'com.samsung.android.emergency',
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
  'com.google.android.inputmethod.latin',
  'com.samsung.android.honeyboard',
  'com.touchtype.swiftkey',
  'com.android.inputmethod.latin',
};

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

AppCategory categoryFromAndroid(int c) => switch (c) {
  0 => AppCategory.games,
  2 => AppCategory.video,
  4 => AppCategory.social,
  5 => AppCategory.news,
  _ => AppCategory.other,
};

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
  }) : _extraExempt = {...extraExempt},
       overrides = {...overrides},
       restricted = {...restricted};

  final Set<String> _extraExempt;

  final Map<String, bool> overrides;

  final Set<AppCategory> restricted;

  final Map<String, AppCategory> categories = {};

  void addExempt(Iterable<String> pkgs) => _extraExempt.addAll(pkgs);

  bool isExempt(String pkg) =>
      pkg.isEmpty || exemptPackages.contains(pkg) || _extraExempt.contains(pkg);

  AppCategory categoryOf(String pkg) =>
      knownCategories[pkg] ?? categories[pkg] ?? AppCategory.other;

  bool restrictedByDefault(String pkg) => restricted.contains(categoryOf(pkg));

  bool isRestricted(String pkg) {
    if (isExempt(pkg)) return false;
    return overrides[pkg] ?? restrictedByDefault(pkg);
  }
}
