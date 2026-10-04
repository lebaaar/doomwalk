# Contributing to DoomWalk

Info about building and signing the app, permissions, testing and code structure.
<br>
Package id: `com.lebaaar.doomwalk`. The mark is a stack of frost-blue *depth ticks* (see [docs/logo](docs/logo/README.md)).

## Prerequisites

Please ensure you have Flutter 3.13+ (with Dart 3.1+) installed and working.

```bash
flutter pub get
flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk
# or simply:
flutter run
```

## Tests

```bash
flutter analyze
flutter test # unit, pipeline and widget tests
RENDER_SCREENS=1 flutter test test/render_screens_test.dart # regenerates docs/screenshots
```

## Developer options

Debug builds Developer section is shown in Settings automatically. To unlock it in release builds, open the Settings tab and tap the title 20 times fast.

## Code structure

```
lib/core/       pure Dart (no Flutter): ScrollWallet, units, ScrollInterpreter,
                landmarks, AppCatalog, presets, tamper, WalkTracker
lib/services/   controller (orchestration), sqflite store, native bridge
lib/ui/         dashboard, onboarding, settings, share card
android/.../DoomWalkShim.kt   accessibility service, frost overlay, FGS, engine host
android/.../DebtWidget.kt       home-screen widget providers (2×1, 4×2)
android/app/src/debug/          debug-only adb hooks
test/           unit + pipeline + render tests
```

## Permissions

The onboarding screen walks through each one with a deep link and a live tick:

| Step | Where | adb shortcut |
|---|---|---|
| Restricted settings (Android 13+, sideloaded) | App info → ⋮ → *Allow restricted settings* | `adb shell appops set com.lebaaar.doomwalk ACCESS_RESTRICTED_SETTINGS allow` |
| Scroll measuring (accessibility) | Settings → Accessibility → DoomWalk | `adb shell settings put secure enabled_accessibility_services com.lebaaar.doomwalk/com.lebaaar.doomwalk.ScrollAccessibilityService` and `adb shell settings put secure accessibility_enabled 1` |
| Physical activity | permission dialog | `adb shell pm grant com.lebaaar.doomwalk android.permission.ACTIVITY_RECOGNITION` |
| Notifications | permission dialog | `adb shell pm grant com.lebaaar.doomwalk android.permission.POST_NOTIFICATIONS` |
| Battery optimisation | system dialog | `adb shell dumpsys deviceidle whitelist +com.lebaaar.doomwalk` |

**Privacy:** the accessibility service sets `canRetrieveWindowContent="false"` and only subscribes to scroll and window-state events.
It reads scroll geometry and the package name, never screen content.

## Automated device check

```bash
./tool/device_test.sh          # SCROLL_APP=com.instagram.android SWIPES=120 to change target
```
It installs, grants everything, enables the service, swipes, screenshots the frost, tests tap-through, exempt apps, swipe-from-recents survival, walk-off (debug hook) and persistence, and checks the release APK for INTERNET (so it needs `android/key.properties`). The results go to `docs/device/`.

Debug-only adb hooks (absent from release builds):
```bash
adb shell am broadcast -n com.lebaaar.doomwalk/.DebugReceiver -a com.lebaaar.doomwalk.DEBUG_SCROLL --es pkg com.instagram.android --ef metres 10
adb shell am broadcast -n com.lebaaar.doomwalk/.DebugReceiver -a com.lebaaar.doomwalk.DEBUG_WALK --ef metres 25
adb shell am broadcast -n com.lebaaar.doomwalk/.DebugReceiver -a com.lebaaar.doomwalk.DEBUG_DUMP
adb logcat -s flutter | grep 'SD '
```

## Releasing the app

Release builds must be signed with the uploaded `key.properties` (see `android/example-key.properties` for structure).
Release build fails without `android/key.properties`, so that debug-signed APK can never be shipped to production by accident.

### One-time setup

1. Create the upload key and store it somewhere safe:
   ```bash
   keytool -genkey -v -keystore ~/doomwalk-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy `android/example-key.properties` to `android/key.properties` and fill it in. It is git-ignored; never commit it or the `.jks`.
3. In Play Console, create the app (package `com.lebaaar.doomwalk`) and keep *Play App Signing* on. Play re-signs with its own key, your upload key only proves the upload is yours.
4. Fill in the store pages with the text in [docs/google-play/listing.md](docs/google-play/listing.md): short and full description, the accessibility API declaration, the foreground service declarations, the data safety form (no data collected) and the privacy policy URL ([PRIVACY.md](PRIVACY.md) on GitHub). Add an icon (512 px: `docs/logo/final/png/icon-rounded-512.png`), a feature graphic (`docs/graphics/feature-graphic.png`, 1024 x 500) and phone screenshots (`docs/graphics/screenshot-*.png`, 2160 x 3840). Both are rendered from `docs/graphics/src/graphics.html` with `node docs/graphics/src/render.cjs` (point its `require` at your Playwright install).
5. Google reviews apps that use the accessibility API; expect a few days and a possible request for a short demo video of the service doing what the declaration says.

### Every release

1. Run `flutter analyze` and `flutter test`.
2. Raise `version:` in `pubspec.yaml` (example: `1.0.1+2`).
3. Build:
   ```bash
   flutter build appbundle --release    # build/app/outputs/bundle/release/app-release.aab, for Play
   flutter build apk --release          # build/app/outputs/flutter-apk/app-release.apk, for GitHub / sideloading
   ```
4. Check the APK has no `INTERNET` permission (`tool/device_test.sh` does this too):
   ```bash
   "$ANDROID_HOME"/build-tools/*/aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk
   ```
5. Install it on a phone (`adb install -r ...`) and run through onboarding once. Uninstall any debug build first: different signing keys can't update each other, and uninstalling erases the app's data.
6. Commit the version bump (`release 1.0.1+2`), tag it and push:
   ```bash
   git tag v1.0.1 && git push origin main v1.0.1
   ```
7. GitHub: publish the APK so the README link works.
   ```bash
   gh release create v1.0.1 build/app/outputs/flutter-apk/app-release.apk --title "DoomWalk 1.0.1" --generate-notes
   ```
8. Play: Console → Testing or Production → *Create new release* → upload the `.aab`, add release notes and roll out. For a first release, run a closed test first if your account type requires it.

A sideloaded APK needs *Allow restricted settings* (App info → ⋮) before Android lets you turn on the accessibility service. Play installs don't.

### Releasing on Google Play (.aab)
1. Build the app bundle:
   ```bash
   flutter build appbundle --release
   ```
   Output lands in `build/app/outputs/bundle/release/app-release.aab`. This is the only file Play accepts for the app itself. Upload it in Play Console → Testing → Closed testing → Create release.


### Releasing on GitHub (.apk)

1. Build the APK:
   ```bash
   flutter build apk --release
   ```
   Output lands in `build/app/outputs/flutter-apk/app-release.apk`.
2. Commit the version bump and push:
   ```bash
   git tag v0.1.0 && git push origin main v0.1.0
   ```
3. Publish the APK to GitHub releases:
   ```bash
   gh release create v0.1.0 build/app/outputs/flutter-apk/app-release.apk --title "DoomWalk 0.1.0" --generate-notes
   ```
