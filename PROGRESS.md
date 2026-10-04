# Progress

## Why nothing here is marked "done"
This run happened in a **cloud container**, not on your machine:
* **No phone is reachable.** USB devices can't be attached to a cloud container, so
  `adb devices` is empty and there is no adb.
* **No APK could be built.** The environment's network policy blocks `dl.google.com`,
  which also serves `maven.google.com`. That rules out the Android SDK, the Android
  Gradle Plugin and every androidx artifact. `flutter build apk` cannot run here.

The brief says not to mark a feature done without device verification, so every item
is at most **partial: code complete, host-verified**. What *was* verified here:

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 86 tests pass: unit tests (ScrollWallet price, capped bank, overdraft and midnight reset, pixel→metres, landmarks, tamper gaps, WalkTracker, ScrollInterpreter, AppCatalog, presets), a full Dart pipeline test with the native channel mocked, and a UI render smoke test |
| Kotlin shim | Type-checks with `kotlinc` 2.2.20 against the Android 16 framework classes (Robolectric android-all) and the Flutter embedding jar of this engine. Only `androidx.lifecycle` was stubbed. |
| Android XML | All resource/manifest XML is well-formed. It has **not** been compiled by aapt2. |
| UI | Rendered on the host: `docs/screenshots/host_*.png` (emoji show as boxes on the host only) |

To produce on-device evidence, run `./tool/device_test.sh` on your Fedora machine with
the phone attached. It installs the app, grants permissions, enables the service,
swipes in Chrome, takes screenshots and greps logcat into `docs/device/`.

## Checklist

| # | Feature | Status | Evidence |
|---|---|---|---|
| 0 | Spike | partial (source review, not run) | SPIKE.md |
| 1 | Scroll capture, live per-app metres | partial | `ScrollAccessibilityService` → `ScrollInterpreter`; `test/scroll_test.dart`, `test/pipeline_test.dart` ("scroll -> overdraft -> frost") |
| 2 | Scroll wallet: capped bank, rising price (pedometer, FGS), persisted | partial | `test/scroll_wallet_test.dart`; pipeline test restarts the controller and reads state back from SQLite |
| 3 | Frost overlay (blur-behind / translucent), touch-through, not over exempt apps | partial | `FrostOverlay` compiles; pipeline test checks frost 1 → 0 on dialer → 1 → 0 on override → cleared by walking. Real rendering is **unverified**. |
| 4 | Onboarding with deep links, live status, auto-advance | partial | `host_onboarding.png` |
| 5 | Home widget 2×1 / 4×2 | partial | provider + layouts written; pipeline test checks the pushed data. **Not seen on a home screen.** |
| 6 | Landmarks | partial | `test/units_landmarks_test.dart`, `host_tab_activity.png` |
| 7 | Apps that count (per category and per app) + whitelist, editable | partial | `test/scroll_test.dart` (AppCatalog), pipeline "apps that don't count and exempt" test, `host_settings_apps_that_count.png` |
| 8 | Emergency pass (free scrolling for 5 min) | partial | wallet + pipeline tests |
| 9 | ~~Flick-velocity weighting~~ | removed in round 11 | see DECISIONS |
| 10 | Share card | partial | `host_share_card.png`; the share sheet itself is untested |
| 11 | ~~Overnight interest~~ → midnight reset | partial | wallet tests (reset, clock set back) |
| 12 | Tamper detection | partial | `test/tamper_walk_test.dart`, pipeline tamper test |
| 13 | ~~Demo mode~~ | removed in round 16 | an empty bank freezes within a few dozen flicks |

## Known risks / likely flaky on device
* **Instagram/TikTok event shape.** We assume RecyclerView index changes arrive with
  `fromIndex` set. If an app sends nothing useful, the fallback is 0.25 screen per
  event.
* **Horizontal carousels** built on RecyclerView count as vertical (see DECISIONS).
* **Foreground detection** without `flagRetrieveInteractiveWindows` relies on
  window-state events plus scroll events, so it may briefly lag after the
  notification shade closes.
* **Gradle versions**: the build uses the template's AGP 9.1 / Kotlin 2.4 /
  Gradle 9.3.1. It is untested because no build was possible here.
* **Restricted-settings status**: read through a hidden appop string. If that fails
  the step shows as "can't tell" and is skipped once accessibility is on.
