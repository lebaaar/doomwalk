# Decisions

Reasonable defaults chosen without asking, as instructed.

## Architecture
* **One Dart isolate for everything.** A cached `FlutterEngine` runs `main()`. The
  services start it headless, and the activity attaches to it. The controller, the
  ledger and the pedometer subscription therefore live as long as the process does,
  independent of the UI. There is no cross-isolate syncing.
* **Escape hatch used** (see SPIKE.md). There is one Kotlin shim file plus the widget
  provider and a debug-only receiver.
* **Dropped plugins:** `flutter_accessibility_service`, because it drops every event
  when content access is off and it reads screen text. `flutter_foreground_task`,
  because it would need a second engine; a 60-line native FGS keeps the single engine
  instead.
* **sqflite instead of drift.** There are three tables and no build_runner step.
* **Dependencies added:** `share_plus`, for the system share sheet; `path_provider`, for
  the share image temp file; `shared_preferences`, which home_widget pulls in anyway;
  `sqflite_common_ffi` (dev only), so the full pipeline can be tested on the host.
* **Riverpod:** `ChangeNotifierProvider` from `flutter_riverpod/legacy.dart` exposes the
  process-wide controller. The controller is the single source of truth, so a
  notifier fits best.

## Measurement
* `metres = px / ydpi × 0.0254`. **Density assumption:** `DisplayMetrics.ydpi` is the
  real panel density. If it is implausible (<100 or >900) or more than 40 % away from
  `densityDpi`, we use `densityDpi` instead. This is common on some OEM builds.
* One event is capped at 3 screen heights, so a "jump to top" doesn't cost 50 m.
* Horizontal scrolls (`dx≠0, dy=0`) are ignored. **Known limitation:** horizontal
  RecyclerViews such as story carousels report neither dx nor dy, so their page flips
  count as vertical screens.
* The keyboard showing up is not treated as an app switch. A scroll event also sets
  the foreground app, which repairs a missed window-state event after the shade
  closes.

## Economy
* Allowance is consumed chronologically by **counted** scrolls (apps with a rate > 0).
  Only the excess is charged: `excess × appRate × RATIO × velocityWeight × (override ? 3 : 1)`.
* **Running balance, clamped at 0:** walking while debt-free **does not bank credit**.
  Otherwise one morning walk would pre-pay a day of scrolling and the frost would
  never appear. This matches "debt = max(0, …) − walked, never below 0" for any order
  where scrolling comes first.
* Apps with a 0× rate are whitelisted: they are not counted, use no allowance and are
  never frosted (covering Maps during navigation would be dangerous).
* **Interest:** 2 %/night by default. It is applied once per local midnight crossed
  (catching up after the phone was off, capped at 60 nights), and never when the clock
  goes backwards.
* **Emergency pass:** 3 per day, 5 minutes each, 3× cost while active. It is started
  from the app or from the notification action. The frost overlay can't take touches
  by design, so the button is not on the frost.
* **Flick weighting** uses speed over a 1.2 s window per app. At or below 0.04 m/s
  (reading) the weight is 0.5×, rising linearly to 1× at 0.15 m/s. Each separate burst
  above 0.5 m/s within 10 s adds to a surcharge, up to 1.6×.
* **Tamper gaps:**
  1. The service is seen disabled while we are alive, or it unbinds while disabled.
     The gap opens then and closes when the service reconnects.
  2. On start, the last heartbeat (written every 30 s) is from the **same boot**, more
     than 15 min old, and tracking was on. That means a force-stop or kill.
  Reboots are never charged. Gaps under 2 min are free. One gap is charged for at most
  16 h, at the user's average raw metres per waking hour over the last 7 days
  (25 m/h until history exists), × RATIO, outside the allowance.
* **Demo mode:** 2 m allowance, ratio 1, full frost at 15 m. About 7.5 m of Instagram
  scrolling (60–80 swipes) frosts it fully, and about 20 steps clear it. Overriding
  frost-max is an addition the spec didn't list, but the loop can't fit in 2 minutes
  without it.
* **Widget "progress toward zero"** is measured against today's peak debt.
* **Week** means a rolling 7 days, including today.
* **Landmark tiers:** today uses Eiffel Towers, this week uses Burj Khalifas, lifetime
  uses Everests plus "% of the way to space" (the Kármán line). "Nearest landmark" is
  the closest on a log scale.

## Privacy
* The release manifest removes INTERNET with `tools:node="remove"`. The debug manifest
  re-adds it only for the Flutter tool.
* We never call `getSource()`, `getText()` or `getContentDescription()`.
  `flagIncludeNotImportantViews` only widens which views' scroll events arrive.
* **Steps:** they exist only inside `WalkTracker`. One opaque sensor baseline (the
  cumulative counter reading) is persisted so that walking done while the process was
  dead still counts. It is never shown and never enters the ledger.
* `allowBackup=false`.

## Testing hooks
* The debug-only `DebugReceiver` (in `src/debug`, so it is absent from release)
  handles `DEBUG_WALK` (inject walked metres), `DEBUG_DUMP` and `DEBUG_RESET`. Dart
  also checks `kDebugMode`.
* Logs are `SD …` lines under the `flutter` logcat tag, in debug builds only.
