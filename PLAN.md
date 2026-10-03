# Scroll Debt: plan

## Architecture (one Dart isolate, one small native shim)

```
 AccessibilityService (Kotlin)          Foreground service (Kotlin, type=health)
  ├ TYPE_VIEW_SCROLLED geometry ─┐        └ owns the persistent notification
  ├ TYPE_WINDOW_STATE_CHANGED ───┤
  └ frost overlay window  ◄──────┤ MethodChannel "com.lan.scrolldebt/native"
                                 ▼
      Headless FlutterEngine (cached, started by either service or the activity)
        main() → ScrollDebtController (Dart)
          ScrollInterpreter → FlickWeigher → DebtEngine ← WalkTracker ← pedometer
          Store (sqflite, batched 5 s / app switch) · HomeWidget · tamper checks
        runApp(UI)  ← MainActivity attaches to the same cached engine
```

* The whole app is a single Dart isolate living in a cached `FlutterEngine`.
  The services start it headless; the activity attaches to it. Swiping the app
  from recents destroys only the activity, never the engine.
* Pure-Dart core in `lib/core/` (no Flutter imports): units, DebtEngine,
  ScrollInterpreter, FlickWeigher, landmarks, AppCatalog, tamper, WalkTracker.
* Native code only where plugins cannot do the job (see SPIKE.md):
  `android/app/src/main/kotlin/com/lan/scrolldebt/ScrollDebtShim.kt` plus the
  home-screen widget provider and a debug-only receiver.

## Order of work
0. Spike (plugin capabilities) → SPIKE.md
1. Scroll capture + live per-app counter
2. DebtEngine + WalkTracker + persistence + foreground service
3. Frost overlay (blur-behind / translucent fallback)
4. Onboarding
5. Home-screen widget (2x1, 4x2)
6. Landmarks
7. Per-app rates editor
8. Emergency override
9. Flick weighting
10. Share card
11. Overnight interest
12. Tamper detection
13. Demo mode
Then README, PROGRESS, release build.
