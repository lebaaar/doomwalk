# Contributing to DoomWalk

Everything technical lives here: building, signing, permissions, testing and how the
code is laid out. The [README](README.md) is for people who just want to use the app.

Package id: `com.lebaaar.doomwalk`. The mark is a stack of frost-blue *depth ticks*
(see [docs/logo](docs/logo/README.md)).

## Install (Fedora)

```bash
# Tools
sudo dnf install android-tools git unzip java-21-openjdk-devel
# Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
# Android SDK: install Android Studio (Flathub: com.google.AndroidStudio) or the
# command-line tools, then:
flutter doctor --android-licenses
flutter doctor
```

Enable USB debugging on the phone: Settings → About phone → tap *Build number* 7× →
back to Settings → System → Developer options → **USB debugging** on. Plug in, accept
the RSA prompt, then check that `adb devices` lists the phone. On Fedora, if it shows
`no permissions`: `sudo dnf install android-udev-rules` and re-plug.

```bash
flutter pub get
flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk
# release (no INTERNET permission):
flutter build apk --release
```

## Release build

A release build is optimised (no debug banner or slow debug checks), has no
INTERNET permission, no adb debug hooks and no `SD` logging. Sign it with your
own key so later releases can update it in place.

1. Create a key once and keep it safe (back it up: without it you can't ship
   updates to the installed app):
   ```bash
   keytool -genkey -v -keystore ~/doomwalk-upload.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (git-ignored, never commit it):
   ```properties
   storePassword=<the password you chose>
   keyPassword=<the password you chose>
   keyAlias=upload
   storeFile=/home/<you>/doomwalk-upload.jks
   ```
3. Raise `version:` in `pubspec.yaml` for every release (`1.0.1+2`: the number
   after `+` must go up, or Android refuses the update).
4. Build and install:
   ```bash
   flutter build apk --release
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   # or, for Google Play:
   flutter build appbundle --release   # build/app/outputs/bundle/release/app-release.aab
   ```
5. Check it: `aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk`
   must not list `android.permission.INTERNET`.

Without `key.properties` the release build is signed with the debug key. It
runs, but it can't update (or be updated by) an APK signed with your real key:
uninstall first, which erases the app's data. The first install of a properly
signed build over a debug one needs that uninstall too.

A sideloaded release APK needs *Allow restricted settings* before Android lets
you turn on the accessibility service (see Permissions).

## Permissions

The onboarding screen walks through each one with a deep link and a live tick:

| Step | Where | adb shortcut |
|---|---|---|
| Restricted settings (Android 13+, sideloaded) | App info → ⋮ → *Allow restricted settings* | `adb shell appops set com.lebaaar.doomwalk ACCESS_RESTRICTED_SETTINGS allow` |
| Scroll measuring (accessibility) | Settings → Accessibility → DoomWalk | `adb shell settings put secure enabled_accessibility_services com.lebaaar.doomwalk/com.lebaaar.doomwalk.ScrollAccessibilityService` and `adb shell settings put secure accessibility_enabled 1` |
| Physical activity | permission dialog | `adb shell pm grant com.lebaaar.doomwalk android.permission.ACTIVITY_RECOGNITION` |
| Notifications | permission dialog | `adb shell pm grant com.lebaaar.doomwalk android.permission.POST_NOTIFICATIONS` |
| Battery optimisation | system dialog | `adb shell dumpsys deviceidle whitelist +com.lebaaar.doomwalk` |

**Privacy:** the accessibility service sets `canRetrieveWindowContent="false"` and only
subscribes to scroll and window-state events. It reads scroll geometry and the package
name, never screen content.

## Tests

```bash
flutter analyze
flutter test                                        # unit, pipeline and widget tests
RENDER_SCREENS=1 flutter test test/render_screens_test.dart   # regenerates docs/screenshots
```

## Automated device check

```bash
./tool/device_test.sh          # SCROLL_APP=com.instagram.android SWIPES=120 to change target
```
It installs, grants everything, enables the service, swipes, screenshots the frost,
tests tap-through, exempt apps, swipe-from-recents survival, walk-off (debug hook) and
persistence, and checks the release APK for INTERNET. The results go to `docs/device/`.

Debug-only adb hooks (absent from release builds):
```bash
adb shell am broadcast -n com.lebaaar.doomwalk/.DebugReceiver -a com.lebaaar.doomwalk.DEBUG_SCROLL --es pkg com.instagram.android --ef metres 10
adb shell am broadcast -n com.lebaaar.doomwalk/.DebugReceiver -a com.lebaaar.doomwalk.DEBUG_WALK --ef metres 25
adb shell am broadcast -n com.lebaaar.doomwalk/.DebugReceiver -a com.lebaaar.doomwalk.DEBUG_DUMP
adb logcat -s flutter | grep 'SD '
```

## Demo script (under 2 minutes)
1. Before going on stage: the app is installed and onboarded, cross-window blur is on
   (Developer options → *Allow window-level blurs*, normally on by default), and
   battery saver is **off** because it disables blur.
2. Start with an empty bank: DoomWalk → ⚙ → Developer options → *Reset tracking*.
3. Open Instagram and scroll the feed. The bank is empty, so the frost fades in
   within a few dozen flicks (full at 20 m owed), with a "Take a walk" card in the
   middle. Tap a post to show that touches still work through the frost.
4. Pull down the notification: "Frozen. Walk x steps to unlock 50 m", with the
   **Emergency pass** button.
5. Open DoomWalk: the *Today* card turns navy, with the bank empty, what's owed and
   the steps to walk, and Instagram is at the top of *Most scrolled today*.
6. Walk about 30 steps around the stage. What's owed counts down and back in
   Instagram the frost melts. (Backup: Settings → Developer options → *Add steps to today*.)
7. *Activity* → *Scrolling by app* → tap Instagram → **Share** for the
   "Instagram: … this week" card.

## Model, precisely
A bank of scrolling, reset at local midnight (`lib/core/scroll_wallet.dart`):

* `bank` holds metres of scrolling, `0 ≤ bank ≤ bankCapM` (default 50 m, 20–100 m).
* Walking `w` metres adds `w / price` metres (after paying anything owed first), where
  `price = min(maxPrice, startPrice + floor(scrolledToday / priceStepM))`.
  Scrolling during an emergency pass doesn't count toward `scrolledToday`.
* Scrolling spends the bank; with it empty the rest is owed, and the frost is
  `owed / frostAtM` (full at 20 m).
* Midnight resets the bank, what's owed and the price.
* Tracking gaps (accessibility off, force-stop) are charged as scrolling at the user's
  average rate (25 m/h until there is history), from the bank first.

| Preset | `startPrice` | `priceStepM` | `maxPrice` |
|---|---|---|---|
| Gentle | 1 | 100 m | 4 |
| Balanced (default) | 2 | 50 m | 6 |
| Strict | 3 | 25 m | 8 |

The reasoning behind each choice is in [DECISIONS.md](DECISIONS.md), plugin findings in
[SPIKE.md](SPIKE.md), and status in [PROGRESS.md](PROGRESS.md).

## Layout
```
lib/core/       pure Dart (no Flutter): ScrollWallet, units, ScrollInterpreter,
                landmarks, AppCatalog, presets, tamper, WalkTracker
lib/services/   controller (orchestration), sqflite store, native bridge
lib/ui/         dashboard, altitude gauge, onboarding, settings, share card
android/.../DoomWalkShim.kt   accessibility service, frost overlay, FGS, engine host
android/.../DebtWidget.kt       home-screen widget providers (2×1, 4×2)
android/app/src/debug/          debug-only adb hooks
test/           unit + pipeline + render tests
```
