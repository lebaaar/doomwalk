# Spike: can the preferred plugins do the job?

**How this was done:** this build ran in a cloud container with **no phone attached**
and no Android SDK (see PROGRESS.md), so the spike was done by reading the plugins'
native source in the pub cache, not by running them. The conclusions are based on
that source. They have not been tested on a device.

| Need | Plugin checked | Finding (from source) | Verdict |
|---|---|---|---|
| Per-event scroll pixel deltas | `flutter_accessibility_service` 1.2.0 | `onAccessibilityEvent` starts with `getSource()` and **returns if it is null**. With `canRetrieveWindowContent="false"` (our privacy rule) the source is always null, so the plugin forwards **nothing**. When it does forward, it sends text, node trees and bounds, but never `scrollDeltaY`, `scrollY`, `fromIndex` or `toIndex`. It also writes every event to SharedPreferences and sends a broadcast, which costs battery. | ❌ escape hatch |
| Foreground package | same | Only taken from the source node, so with the privacy config this fails too. | ❌ escape hatch |
| Background survival incl. swipe from recents | `flutter_foreground_task` 11.0.3 | Runs a *second* FlutterEngine for its TaskHandler. Our accessibility events would have to cross engines through a custom plugin. It is workable but adds a third engine and an IPC hop. | ⚠ replaced by a tiny native FGS that keeps the **single** cached engine alive |
| Overlay that doesn't block touches | `flutter_accessibility_service` overlay | Uses `TYPE_ACCESSIBILITY_OVERLAY` + `FLAG_NOT_TOUCHABLE`, which is the right idea. It renders a whole extra `FlutterView` attached to a cached engine, and it is tied to the plugin's own service, which we can't use (row 1). | ❌ native overlay in our own service |
| True background blur | none | No plugin exposes `FLAG_BLUR_BEHIND` / `blurBehindRadius` / `isCrossWindowBlurEnabled`. | ❌ native |
| Step counter | `pedometer` 4.2.0 | Uses `applicationContext` + `TYPE_STEP_COUNTER`, so it works in a headless engine. | ✅ used |
| Widget data | `home_widget` 0.10.0 | `saveWidgetData` writes to the `HomeWidgetPreferences` SharedPreferences file, and `updateWidget(qualifiedAndroidName:)` broadcasts `APPWIDGET_UPDATE`. | ✅ used, with our own `AppWidgetProvider` |
| Permissions | `permission_handler` 13 | Activity recognition and notifications work as usual. | ✅ used |

## Escape hatch applied
`android/app/src/main/kotlin/com/lan/scrolldebt/ScrollDebtShim.kt` (one file) contains:
* `ScrollAccessibilityService`: forwards only geometry (`dx, dy, scrollY, maxScrollY,
  fromIndex, toIndex, itemCount, className, windowId`) plus the package name. The
  config sets `canRetrieveWindowContent="false"`, and the only event types are
  `typeViewScrolled|typeWindowStateChanged`.
* `FrostOverlay`: a full-screen `TYPE_ACCESSIBILITY_OVERLAY` with `FLAG_NOT_TOUCHABLE`.
  It uses `FLAG_BLUR_BEHIND` with an animated `blurBehindRadius` when cross-window blur
  is enabled, and a milky translucent layer when it isn't. It listens for blur being
  toggled (for example by battery saver).
* `DebtForegroundService` (type `health`, or `specialUse` until ACTIVITY_RECOGNITION is
  granted) and `BootReceiver`.
* `Shim`: owns the **single cached FlutterEngine** running `main()`. Both services start
  it headless, and `MainActivity` attaches to it (`shouldDestroyEngineWithHost=false`).
  Swiping the app from recents destroys only the activity.

All interpretation (pixels→metres, pager heuristics, flick weighting, pricing) happens in
pure Dart and is unit-tested.

## How apps report scrolling (handled in `lib/core/scroll_interpreter.dart`)
1. `scrollDeltaY`: plain Views, ScrollView, Compose (API 28+)
2. change of `scrollY` per scroller: WebView / Chrome
3. change of `fromIndex`: RecyclerView (sends `onScrollChanged(0,0,0,0)`, so no deltas).
   The estimate is `items × screenH / visibleItems`, so a pager (TikTok, Reels, Shorts)
   counts **one screen height per flip**.
4. no geometry at all: 0.25 screen per event, rate-limited to one every 300 ms.

## Still to confirm on a real phone
Run `./tool/device_test.sh`. These are the open risks it checks:
* whether Instagram's feed scroll events reach us without `flagRetrieveInteractiveWindows`
* the actual `scrollY`/index behaviour of Chrome and Instagram on your Android version
* the frost window appearing in `dumpsys window` and passing touches through
