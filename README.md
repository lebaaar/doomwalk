# Scroll Debt

Android app (12+) that measures how far you scroll in **metres** across all apps. Past a
daily free allowance that distance becomes a debt, the app you're in **frosts over**,
and the frost clears as you **walk** the debt back. Fully on-device: no INTERNET
permission in release, no analytics.

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

## Permissions

The onboarding screen walks through each one with a deep link and a live tick:

| Step | Where | adb shortcut |
|---|---|---|
| Restricted settings (Android 13+, sideloaded) | App info → ⋮ → *Allow restricted settings* | `adb shell appops set com.lan.scrolldebt ACCESS_RESTRICTED_SETTINGS allow` |
| Scroll measuring (accessibility) | Settings → Accessibility → Scroll Debt | `adb shell settings put secure enabled_accessibility_services com.lan.scrolldebt/com.lan.scrolldebt.ScrollAccessibilityService` and `adb shell settings put secure accessibility_enabled 1` |
| Physical activity | permission dialog | `adb shell pm grant com.lan.scrolldebt android.permission.ACTIVITY_RECOGNITION` |
| Notifications | permission dialog | `adb shell pm grant com.lan.scrolldebt android.permission.POST_NOTIFICATIONS` |
| Battery optimisation | system dialog | `adb shell dumpsys deviceidle whitelist +com.lan.scrolldebt` |

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
adb shell am broadcast -n com.lan.scrolldebt/.DebugReceiver -a com.lan.scrolldebt.DEBUG_SCROLL --es pkg com.instagram.android --ef metres 10
adb shell am broadcast -n com.lan.scrolldebt/.DebugReceiver -a com.lan.scrolldebt.DEBUG_WALK --ef metres 25
adb shell am broadcast -n com.lan.scrolldebt/.DebugReceiver -a com.lan.scrolldebt.DEBUG_DUMP
adb logcat -s flutter | grep 'SD '
```

## Demo script (under 2 minutes)
1. Before going on stage: the app is installed and onboarded, cross-window blur is on
   (Developer options → *Allow window-level blurs*, normally on by default), and
   battery saver is **off** because it disables blur.
2. Open Scroll Debt → ⚙ → **Demo mode** on → back. The dashboard shows *DEMO*:
   2 m free, 1:1, full frost at 15 m.
3. Open Instagram and doom-scroll the feed for about 30-45 s (around 60-80 flicks).
   The frost fades in as you go, with an "x m to walk" label at the top. Tap a post
   to show that touches still work through the frost.
4. Pull down the notification: "x m owed", with the **Emergency pass** button (3× cost).
5. Open Scroll Debt: *Today* shows the debt as a large number with the frost bar
   full, and Instagram at the top of *Most scrolled today*.
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
android/.../ScrollDebtShim.kt   accessibility service, frost overlay, FGS, engine host
android/.../DebtWidget.kt       home-screen widget providers (2×1, 4×2)
android/app/src/debug/          debug-only adb hooks
test/           unit + pipeline + render tests
```
