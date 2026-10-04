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
## Round 8: startup-style visual pass
Audited against the taste-skill anti-slop rules (Leonxlnx/taste-skill).
* **Type:** Geist replaces Roboto Flex (OFL, `assets/fonts/OFL-Geist.txt`),
  four static weights cut from the variable font with fontTools. Headings and
  figures are tracked tighter; the Today number is 72 sp.
* **Neutrals:** the page is a cool near-black (`#0A0C0F`) or off-white
  (`#F5F6F8`) instead of navy or frost tint. Frost blue / navy stays as the
  single accent. Cards are separated by a 1 px hairline, not by tinting.
* **One corner scale:** cards 20, sheets 28, buttons and inputs 12, tags 8.
  Buttons are no longer pills.
* **Today card:** flat navy fill lit by a radial glow instead of a linear
  gradient and the faint logo watermark. The status is a plain icon + label,
  not a pill; walked and scrolled sit side by side between hairlines instead
  of in a nested rounded box.
* **Components:** a sliding segmented control (`Segmented`) replaces the
  outlined Material one; the nav bar has no indicator blob, just a hairline
  on top and full-ink selected icons; setting rows are split by inset
  hairlines with small neutral icon badges; warnings are a neutral card with
  a red icon instead of a pink block; onboarding shows a segmented progress
  bar, and skipping steps is an outlined (secondary) button.
* **System bars:** edge-to-edge with transparent status and navigation bars
  and Android's contrast scrim off, so the area behind the back / home /
  recents buttons is the app's own colour in light and dark mode.
* **Did you know?** The landmark panel moved from Activity to Today, between
  the Today card and Most scrolled today: today's scrolling in Eiffel Towers
  with a plain sentence, and the all-time line.
* **Developer reset:** *Reset walking and scrolling* in Developer options
  (`devResetTracking`) does the same wipe as Privacy's erase (debt, steps,
  scrolling, history, gaps, passes; settings kept) after a confirmation.

## Round 9: scroll measuring that stays running
* **Why it stopped:** on Android 10+, when the app's process dies for any
  reason (crash, a permission being changed, force stop), Android marks the
  accessibility service as crashed and won't bind it again until it is
  switched off and on. Settings still shows it as on, so Today said "isn't
  running" and setup counted it as done.
* **A crash we caused:** the status-notification service called
  `startForeground` after starting the Flutter engine, and on failure just
  logged. A service started with `startForegroundService()` that misses
  `startForeground` takes the whole process down after the deadline. It now
  goes foreground first, and stops itself cleanly if Android refuses.
* **Why, in plain words:** `status` carries Android's last process exit
  record (`ApplicationExitInfo`), shown as "the app stopped today at 14:05
  because a permission was changed".
* **Self-restart:** with `WRITE_SECURE_SETTINGS` (only grantable over adb:
  `adb shell pm grant com.lan.scrolldebt android.permission.WRITE_SECURE_SETTINGS`)
  the app switches its own service off and on, automatically once it has
  looked stopped on two checks in a row, at most once a minute, or from the
  Restart button. Without it, the button opens accessibility settings with
  "switch it off, then on again".
* **Permissions page** replaces setup as the place Settings and the Today
  notices open: every permission with a live check mark and a button to its
  Android settings page, granted or not. Setup now counts scroll measuring as
  done only when it is running, and the standalone setup mode (whose only
  button was a Start that did nothing) is gone.
* **Done for the day:** with free scrolling used up and nothing owed, Today
  shows a red "Done for the day" instead of "0 m left".
* Kotlin type-checked with `kotlinc` 2.2.20 against Robolectric android-all 16
  and this engine's embedding jar (androidx.lifecycle and R stubbed).

## Round 10: a frozen app always says why
* **The problem:** the action bar only appeared from 25% frost. Below that,
  and whenever it failed to show, a frosted app was a blurred or milky screen
  with nothing on it. Taps still went through, but to an app you couldn't
  see, so it looked hung.
* **The card:** any frost now comes with a card in the middle of the screen:
  "Scroll Debt", "Instagram is frozen" (or "is frosting over"), how far to
  walk, and "Use pass (n)" / "Leave app". It follows the system light/dark
  setting with the app's palette. Only the card takes touches; the frost
  layer stays FLAG_NOT_TOUCHABLE. The app name waits for the real label
  rather than showing the package fallback ("android").
* **Used-up notice:** opening an app that counts with free scrolling used up
  and nothing owed (no frost yet) shows a banner for 4 s, "Free scrolling
  used up. Anything you scroll in Instagram now has to be walked off.", at
  most once per app every 10 minutes. It never takes touches.
* **Pass countdown:** while a pass has unfrozen the open app, a pill at the
  top counts down ("Pass: 4:32 left") on the monotonic clock, and the status
  notification shows a live countdown chronometer.
* **Checked on the JVM:** `android/app/src/test/.../FrostOverlayTest.kt` runs
  the real overlay on Robolectric (`./gradlew testDebugUnitTest`): windows
  added, touch flags, card text at full and light frost, clean removal,
  banner timeout, pass countdown. It passed here outside Gradle (androidx
  test stubbed, since Google's Maven is blocked in this environment).
  `docs/screenshots/overlay_*.png` are the native views drawn by
  Robolectric's native graphics.

## Round 11: walk first, then scroll (the scroll wallet)
The debt model had too many dials (app rate × ratio × velocity weight × pass
penalty, plus overnight interest) for anyone to predict what a scroll cost, so
it couldn't steer behaviour. It is replaced by a wallet: `lib/core/scroll_wallet.dart`
(`ScrollWallet`, `WalletConfig`, `WalletState`; `DebtEngine` and `FlickWeigher`
are gone).
* **The rule:** a free allowance, then you scroll as far as you walk. Walking
  fills a bank at any time of day, so "take a walk first" actually works.
* **Price in steps, not a curve:** `price = min(maxPrice, 1 + floor(earned / priceStepM))`,
  where `earned` is today's scrolling past the allowance. Whole steps can be
  shown as a plain "2×" and checked by hand; a smooth curve can't. The cap
  (5:1 on Balanced) keeps a long day from feeling hopeless.
* **Overdraft instead of an instant lock:** with an empty bank, scrolling is
  owed as walking and the frost grows with it, full at `frostAtM` (20 m). That
  is a few flicks, so it feels almost immediate, but it never slams down
  mid-post. The overdraft is charged at the current price, like the bank.
  Walking clears it first, then banks.
* **Midnight resets everything:** allowance, price, bank and overdraft. A banked
  hike can't buy a week of scrolling, and nothing owed carries into tomorrow
  (the guilt spiral is what makes people uninstall). No interest.
* **Passes are free scrolling:** 3 a day, 5 minutes. The 3× penalty is gone; the
  daily limit already makes them scarce. Scrolling during a pass uses no
  allowance and doesn't raise the price.
* **Apps count or don't:** per-category and per-app rates are now a yes/no
  (`AppCatalog.isRestricted`). Saved per-app rates migrate: 0 → never counts,
  anything else → counts (`app_overrides` replaces `rates`).
* **Tamper gaps** are charged 1:1 as walking (no ratio), from the bank first.
* **Walking asks are in steps** ("133 steps unlock 100 m"), scrolling left is in
  metres. Steps are what you can act on; metres are the fun number.
* **Migration:** the kv key `model` = `2` marks a wallet config. An older saved
  config keeps only its personal settings (stride, weight, goal, passes, demo);
  an older saved state keeps today's and lifetime totals, never its debt.
* **Widget:** the big figure is scrolling left (free + earned), or the steps to
  unlock 100 m when frozen. Its bar is now today's walking goal.
* **Demo mode:** 2 m free, price +1 every 5 m up to 3:1, full frost at 5 m owed.

## Round 12: an empty, capped bank instead of a free allowance
* **The problem with round 11:** the step counter sees all walking, so an
  ordinary 5 km day banked about 1.2 km of scrolling without any decision to
  walk. And the Today card had two pots (free, then earned), which read badly.
* **No allowance.** The day starts with 0 m in the bank. Scrolling first thing
  means walking first.
* **The bank holds scrolling, capped** (`bankCapM`, 250 m, 50-500 m in
  Settings → Bank). Walking while it's full adds nothing, and Today says
  "Bank full". The cap is a setting of its own, outside the presets, so moving
  it doesn't turn the rules "custom".
* **The price is paid when you walk:** a metre walked adds `1 / price` metres,
  `price = min(maxPrice, 1 + floor(scrolledToday / priceStepM))`. Units in the
  bank are always metres of scrolling, so the cap and the Today number mean the
  same thing. Scrolling during a pass doesn't raise the price.
* **Owed is in metres of scrolling too;** the frost is full at 20 m owed, and
  walking pays it at today's price before anything goes in the bank.
* **Asks are capped by the bank:** "x steps put 100 m in the bank" uses
  100 m or the cap if it is smaller.
* **Tracking gaps** are charged as scrolling (25 m/h fallback, or your average),
  from the bank first.
* **Today card:** "In the bank" with metres and a battery bar of the cap,
  "Running low" under a quarter, "Bank full", "Take a walk first" (steps, not
  red: it's how every day starts), "Time for a walk" when frozen.
* **Migration:** a state saved by an older model keeps today's and lifetime
  totals but not its bank (it was in metres walked) or debt.

## Round 13: steps first on Today
* **The big number is today's steps**, with the walking goal (in steps) and the
  distance under it. Walking is the thing to do more of, so it leads.
* **The bank sits right under it as one block:** "In the bank", a bar of how
  full it is against the cap, "133 m of 250 m", and one line saying what to do
  (scroll, fill it up, take a walk, or what's frozen). The **multiplier chip**
  ("1× walk", filled once it's above 1×) sits on the bank's header, where it
  applies; tapping it explains what a metre walked adds right now.
* **Bottom row:** all-time steps (and metres) next to scrolled today.
* Steps are always walked metres over the stride (`DoomWalkController.stepsToday`,
  `stepsLifetime`, `stepGoal`), so changing the stride re-reads history.
* `formatCount` replaces the settings-only `_thousands`, which broke past a million.

## Round 14: blank screen after an update
* **Cause:** `main()` awaited `SystemChrome.setEnabledSystemUIMode` before
  `runApp`. When a service starts the engine (after `adb install -r`, a reboot
  or a kill, with scroll measuring on) there is no activity yet, and Flutter's
  Android `PlatformChannel` drops the call without ever replying. The await
  never returned, `runApp` never ran, and the activity attached to a cached
  engine with nothing to draw. The accessibility service keeps the process
  alive, so reopening the app didn't help either.
* **Fix:** the call is fired without awaiting and re-applied by an
  `AppLifecycleListener` whenever the activity resumes.
  `test/startup_test.dart` gives the platform channel a handler that never
  answers and checks that `main()` still reaches `runApp` (it times out on the
  old code).

## Round 15: the walking goal is in steps
* `WalletConfig.stepGoal` (default 10,000, 1,000-30,000 in Settings → You in
  steps of 500) replaces the 5 km `walkGoalM`, which is now derived as
  `stepGoal × stride` for the goal bar, streaks and the widget.
* **Migration:** a goal saved in metres becomes steps at the saved stride; the
  untouched old default (5 km) becomes the new 10,000.
* The Activity tab's walking panel counts steps too ("of 10,000 steps today").

## Round 16: the price table, story intro, a short "How it works", no demo mode
* **Price table** (`lib/ui/price_table.dart`): scrolled today → multiplier →
  steps for 100 m, built from the preset and the stride, with today's row
  highlighted. It sits under How strict in Settings and in "How it works".
* **"How it works"** is five one-line rules (bank, spending and freezing, the
  table, passes, midnight) and a short Today: steps, added to the bank,
  scrolled, owed, in the bank. Walking lost to a full bank and tracking gaps
  get one line only when they happened.
* **Story intro** (`lib/ui/intro_stories.dart`): eight full-screen slides (nine until the two bank slides were merged) with
  progress bars; tap right/left to move, hold to pause, 7 s each, the last one
  waits for its button. It shows once before setup (`intro.seen`) and again
  from Settings → How DoomWalk works. The numbers come from the config.
* **Demo mode is gone.** The day starts with an empty bank, so the frost
  already appears within a few dozen flicks; the config field, its settings
  switch and the "Demo mode" chip are removed, and a saved `demoMode` is
  ignored.

## Round 17: a small bank that costs more from the start
* **Bank:** 50 m by default, 20-100 m in Settings → Bank (it was 250 m, up to 500).
  250 m was about 1,600 swipes for a 3-minute walk: far too generous.
* **Starting price** (`WalletConfig.startPrice`): walking isn't 1:1 from the first
  step any more. `price = min(maxPrice, startPrice + floor(scrolledToday / priceStepM))`.
  Presets: Gentle 1× +1/100 m max 4×, Balanced 2× +1/50 m max 6×, Strict 3× +1/25 m
  max 8×. Custom rules gained a "Walking per metre at first" slider; start and max
  push each other so the start is never above the max.
* **Walking asks fill the whole bank** ("134 steps put 50 m in it"), since it is
  at most 100 m. The price table's last column is "Fill 50 m".
* **Migration:** config model `3`. A saved config from before keeps only the
  personal settings (stride, weight, step goal, passes); the economy resets to the
  new Balanced.
* **Docs:** the README is for users (what it is, how it works, features, privacy);
  building, signing, permissions, testing, the precise model and the code layout
  moved to CONTRIBUTING.md.

## Round 18: price tiers, and hold-to-pause that pauses
* **Tiers instead of +1:** `WalletConfig.priceTiers` (Balanced 3×, 5×, 7×, 10×,
  15×; one tier up per 50 m scrolled in a day) replaces `startPrice`/`maxPrice`.
  Filling the 50 m bank costs 200 steps first thing and 1,000 at the top tier.
  Gentle is 2, 3, 5, 7, 10 per 50 m; Strict 5, 7, 10, 15, 20 per 25 m. The tiers
  come from the preset; Custom rules keeps the tier length and the freeze point.
  Saved tiers must be numbers ≥ 1 that never go down, or the defaults are used.
  Config model `4`: older saved economies reset, personal settings stay.
* **Hold to pause:** the stories used a long-press recognizer, which only fires
  after 500 ms; until then the bar kept running, and letting go sooner counted
  as a tap and skipped the slide. A raw `Listener` on the slide area now pauses
  the moment a finger lands; a release within 250 ms is a tap (back/next),
  anything longer just resumes.
