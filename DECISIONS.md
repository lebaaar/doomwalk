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
* In-app testing tools live behind **Settings → Developer options** (see round 4),
  in any build.
* Logs are `SD …` lines under the `flutter` logcat tag, in debug builds only.

## Visual design (taste-skill pass)
The UI was reworked against the anti-slop rules from
[tasteskill.dev](https://www.tasteskill.dev/) (source: github.com/Leonxlnx/taste-skill;
the site itself is blocked by this environment's network policy). The skill targets web
landing pages, so only its general rules were applied:
* **One accent** (glacier cyan `#7CC4E8`, matching the frost overlay) used only for debt
  and primary actions, on a single cool neutral scale. The previous four accents
  (blue, orange, green, red) are gone.
* **Type:** Geist with tabular figures, and Geist Mono for the gauge scale only.
  (Replaced by Roboto Flex in round 4.)
* **Icons:** Phosphor Regular as one family, bundled as a font (MIT). The
  `phosphor_flutter` package was abandoned in 2024 and no longer compiles, because
  `IconData` is now a final class. No emoji anywhere.
* **No eyebrows:** the uppercase wide-tracked labels on every section became
  sentence-case section titles.
* **Cards only where elevation means something:** the gauge, the active onboarding
  step and the "tracking off" alert. Everything else is grouped with hairlines and
  space, so the three equal stat cards are now a plain figure row.
* **No progress bars with filled tracks.** Per-app bars are track-less, and landmark
  progress is written out as text.
* **No glow halo or decorative stars** in the gauge.
* **One radius scale:** 16 for surfaces, 8 for small elements, pills for buttons.
* **Copy pass:** no em or en dashes, middle dots rationed, plain sentences instead of
  cute lines.
* **Onboarding** renders the steps only after the first status check, so there is no
  flash of wrong state.

## Round 3: restriction by category, frost actions, light mode, health
* **Only social and video apps are restricted by default.** `AppCategory` comes from
  Android's `ApplicationInfo.category` (social, video, game, news) plus a list of
  known packages, because many apps don't declare a category. Everything else
  (banking, calls, messaging, maps, system apps) falls into "Everything else",
  which is off. Each category can be toggled, and each app can be set to
  Default / Off / 1× / 2× / 3×.
* **Frost action bar:** a second, small `TYPE_ACCESSIBILITY_OVERLAY` window at the
  bottom. It is touchable, with `FLAG_NOT_TOUCH_MODAL` so touches outside it pass
  through. It shows the debt, **Use pass (N)** and **Leave app** (`GLOBAL_ACTION_HOME`),
  and appears only once the frost is at 25% or more, so light frost stays out of
  the way.
* **Light mode:** `Palette` is now a `ThemeExtension` with dark and light variants,
  read via `context.colors`. The light accent is deepened to `#16739E` to keep
  4.5:1 contrast on white. There is a System / Light / Dark switch in Settings and a
  quick toggle in the app bar.
* **Health:** body weight and a daily walking goal (default 70 kg, 5 km).
  Calories use 0.53 kcal per kg per km (ACSM walking estimate, labelled as an
  estimate). The dashboard shows today vs goal, a 7-day bar strip with the goal
  line, kcal today and for the week, and a goal streak. Debt is also shown as
  kcal. Walked metres per day are stored in a new `walk_day` table (DB v2,
  migrated).

## Round 4: Material 3 redesign (direction B)
An MD3 audit (hamen/material-3-skill, audit mode) scored the previous UI 60/100 and
the Today screen showed about 20 numbers. Direction B was chosen from three options:
* **Three tabs:** Today, Activity (the old Health and Apps tabs merged, with a
  Today / Last 7 days switch) and Settings. The theme toggle left the app bar; it
  lives in Settings → Appearance.
* **Today is three cards:** what you owe (number, frost bar, which apps are frozen,
  the emergency pass as a tonal button that only shows while you owe), walking
  (goal ring) and the top three apps. The ledger moved to a bottom sheet opened by
  tapping the debt card. It reads as a sum that ends at the number on the card.
* **Settings is a short list:** a Gentle / Balanced / Strict preset
  (`lib/core/presets.dart`; Balanced is the default config) sets free scrolling,
  the walking ratio, full-frost debt and overnight growth at once. Individual
  sliders moved to sub-pages (Apps that count, Emergency passes, Custom rules, You,
  Appearance, Privacy and data).
* **Developer options** is a persisted switch (`dev_options`). Only while it is on
  does Settings show demo mode, *Add steps to today*, *Add scrolling* to a chosen
  app, *Refill emergency passes* and *Show setup again*. Every controller method
  behind them (`devAddSteps`, `devAddScroll`, ...) checks the flag again, and
  turning the switch off also ends demo mode, so nothing fake stays active
  unseen. The adb hooks used by `tool/device_test.sh` still need a debug build.
* **Type:** Roboto Flex, the Material 3 typeface, as four static weights cut from
  the variable font with fontTools (OFL, `assets/fonts/OFL-RobotoFlex.txt`). Its
  digits are tabular by default. The Glacier palette stays; dynamic colour is off
  on purpose.
* **Audit fixes:** MD3 corner scale (cards 12, sheets and dialogs 28), 16 dp
  margins, a separate `danger` colour for problems (it used to equal the accent),
  `faint` no longer used for text (it was 2.5 to 3.1:1), 48 dp touch targets on
  buttons and sliders, `Semantics` labels on the debt number, goal ring and week
  chart, a fade between tabs that respects reduced motion, and predictive back
  (`enableOnBackInvokedCallback`).

## Round 5: logo and Frost palette
* **Logo:** depth ticks, six rounded bars that widen and thicken going down.
  Chosen after six concept rounds made with the logo-design skill
  (kaankiziltug/logo-design-skill); masters and rules in `docs/logo/`. The
  mountain is gone everywhere: the Today tab, the share card and the
  notification icon now use the mark, and `AltitudeGauge` was removed.
* **Palette "Frost"** replaces "Glacier" so the app matches the icon: navy
  `#0E4166` on white and frost blue `#E2F0F8` in light mode, the icon
  inverted (frost blue `#A9D3EC` on deep navy `#07131F`) in dark mode. Every
  text and accent pair passes 4.5:1. The frost overlay tint, its action bar,
  the splash screen and the home-screen widgets use the same colours, with
  dark values in `values-night`.
* **Launcher icon:** adaptive (white to frost-blue gradient background, navy
  vector ticks) with a monochrome layer for Android 13 themed icons. The
  vector is flat; the soft shadow exists only in the PNG and store artwork.

## Round 6: one-card Today and a modern pass
* **Today is one card that answers "what now?"** A status pill gives the verdict
  (*Time for a walk*, *Unfrozen for 3:12*, *Free scrolling used up*, *Almost at your
  limit* at 25 % or less, *You're good to scroll*), one big number backs it (metres
  to walk, or free scrolling left) with a plain sentence, and two rows below show
  what it comes from: *Walked today* and *Scrolled today*. While you owe, the card
  turns navy in light mode and frost blue in dark mode; otherwise it stays pale
  frost with a bar that drains like a battery. No columns or charts. The separate
  walking card left Today (its goal ring lives on as "x % of your goal" under
  *Walked today*, and the full chart is in Activity). *Most scrolled today* is
  unchanged apart from its heading moving above the card with a *See all* link.
* **Modern pass, same Material 3 rules:** the logo colours stay; the page is tinted
  frost (`#EEF4F9`) so white cards lift off it without shadows. Headings and
  figures are SemiBold with tight tracking instead of Light, the app bar title is
  30 sp. Corners follow the expressive scale (cards 24, sheets 32, small 12),
  segmented buttons are pills, the navigation bar shares the page colour. Settings
  rows sit in rounded groups with tonal icon badges (`TileGroup`, `IconBadge` in
  `lib/ui/theme.dart`), and warnings are tinted cards instead of outlined ones.

## Round 7: bug audit
* **Frost vanished as soon as it appeared.** Adding the frost overlay (and its
  action bar) makes Android send a window-state event from our own package, and
  `_onWindow` took that as "Scroll Debt is open", which is exempt, so the frost
  faded out again until the next scroll. The shim now sends the event's class
  name, and only our activity (`com.lan.scrolldebt.MainActivity`) switches the
  foreground to Scroll Debt. Covered by a pipeline test.
* **Overlay race:** `ValueAnimator.cancel()` also fires `onAnimationEnd`, so a
  fade-in superseded at level 0 detached the window and restarted from zero
  (flicker, and one more self window event). Only the current animator may
  detach now.
* **Silent day change:** `overridesLeft` rolled the ledger over from a getter
  (and passes and tamper gaps did too), so after midnight the per-app totals
  could stay on yesterday until a restart. Every day change now goes through
  `_syncDay`, and `overridesLeft` is pure.
* **UI:** switching tabs rebuilt all three (lost Activity's Today / 7 days choice
  and scroll positions); a pass running after the debt was paid off hid its
  countdown and *End pass*; half-step pass costs showed rounded (1.5× as 2×,
  also in the notification, which was hardcoded to 3×); the big number showed
  metres in km format while animating across 1 km; `formatRound(999.6)` gave
  "1000 m"; the Today card claimed frost while the service was stopped (now a
  notice says so); the share card's brand overlapped long app names; the week
  chart's goal line sat 2 px off; the developer *Add scrolling* list offered
  free apps and could charge a different app than the one shown.
* **Not changed, on purpose:** Developer options stay available in release
  builds (Round 4). Anyone can add steps there, so turn the switch off before
  handing the phone over, or ask for it to be limited to debug builds.
* **Known limit:** pulling the notification shade lifts the frost (System UI is
  exempt), and closing it sends no event, so the frost returns on the next
  scroll or app switch rather than instantly.
