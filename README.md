<p align="center">
  <img src="docs/logo/final/png/icon-256.png" width="128" alt="DoomWalk icon">
</p>

<h1 align="center">DoomWalk</h1>

<p align="center"><b>Doomscroll now, walk it off later.</b></p>

<p align="center">
  Android 12+ · Flutter · fully on-device · no INTERNET permission · no analytics
</p>

---

Every flick of your thumb has a distance. DoomWalk measures how far you scroll, in
**metres**, across all your apps. Past a daily free allowance that distance turns into
**debt**: the app you're in slowly **frosts over**, and the only way to clear it is to
get up and **walk** the debt back, step by step.

| You scroll | It frosts | You walk |
|---|---|---|
| 200 m of feed a day is free. Scroll past that and every metre counts double. | The app you're in fades behind a blur. Touches still work, but it's no fun. | Steps pay the debt down and the frost melts away. |

<p align="center">
  <img src="docs/screenshots/host_tab_today.png" width="220" alt="Today dashboard">
  <img src="docs/screenshots/overlay_card_light.png" width="220" alt="Frost overlay over a locked app">
  <img src="docs/screenshots/host_share_card.png" width="220" alt="Share card">
</p>

**Why "DoomWalk"?** Doomscrolling plus a walk: the scroll is the crime, the walk is
the sentence. The name comes with a hashtag for the share card: `#DoomWalk`.

**Brand basics:** the name is written **DoomWalk**, one word with a capital W. The
mark is a stack of frost-blue *depth ticks* (see [docs/logo](docs/logo/README.md)).
Package id: `com.lebaaar.doomwalk`.

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
2. Open DoomWalk → ⚙ → **Demo mode** on → back. The dashboard shows *DEMO*:
   2 m free, 1:1, full frost at 15 m.
3. Open Instagram and doom-scroll the feed for about 30-45 s (around 60-80 flicks).
   The frost fades in as you go, with an "x m to walk" label at the top. Tap a post
   to show that touches still work through the frost.
4. Pull down the notification: "x m owed", with the **Emergency pass** button (3× cost).
5. Open DoomWalk: the *Today* card turns navy with "Time for a walk" and the
   debt as a large number, and Instagram is at the top of *Most scrolled today*.
6. Walk about 20-30 steps around the stage. Debt counts down and back in Instagram
   the frost melts. (Backup: Settings → Developer options → *Add steps to today*.)
7. *Activity* → *Scrolling by app* → tap Instagram → **Share** for the
   "Instagram: … this week" card.
8. Demo mode off afterwards.

## Model
`debt += max(0, scrolled − allowance) × appRate × RATIO × velocityWeight (× 3 during a pass)`,
walking pays it down (never below 0), the allowance resets at local midnight, and unpaid
debt accrues overnight interest. Defaults: 200 m/day free, RATIO 2, full frost at
150 m, 2 %/night, stride 0.75 m. Every value can be changed in Settings. The reasoning
is in [DECISIONS.md](DECISIONS.md), plugin findings in [SPIKE.md](SPIKE.md), and status
in [PROGRESS.md](PROGRESS.md).

## Layout
```
lib/core/       pure Dart (no Flutter): DebtEngine, units, ScrollInterpreter,
                FlickWeigher, landmarks, AppCatalog, tamper, WalkTracker
lib/services/   controller (orchestration), sqflite store, native bridge
lib/ui/         dashboard, altitude gauge, onboarding, settings, share card
android/.../DoomWalkShim.kt   accessibility service, frost overlay, FGS, engine host
android/.../DebtWidget.kt       home-screen widget providers (2×1, 4×2)
android/app/src/debug/          debug-only adb hooks
test/           unit + pipeline + render tests
```
