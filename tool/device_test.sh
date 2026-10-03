#!/usr/bin/env bash
# On-device verification for Scroll Debt (debug build). Run from the repo root
# with the phone connected over USB debugging:  ./tool/device_test.sh
# Evidence (logcat excerpts + screenshots) lands in docs/device/.
set -euo pipefail
PKG=com.lan.scrolldebt
SVC=$PKG/$PKG.ScrollAccessibilityService
OUT=docs/device
mkdir -p "$OUT"
shot() { adb exec-out screencap -p > "$OUT/$1.png"; echo "  screenshot $OUT/$1.png"; }
log()  { echo; echo "== $*"; }

log "0. device"
adb devices | tee "$OUT/devices.txt"
[ "$(adb devices | grep -cw device)" -ge 1 ] || { echo "no device"; exit 1; }
adb shell getprop ro.build.version.sdk

log "build + install"
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

log "permissions"
adb shell appops set $PKG ACCESS_RESTRICTED_SETTINGS allow || true
adb shell pm grant $PKG android.permission.ACTIVITY_RECOGNITION
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS
adb shell dumpsys deviceidle whitelist +$PKG >/dev/null
CUR=$(adb shell settings get secure enabled_accessibility_services | tr -d '\r')
case "$CUR" in *"$SVC"*) ;; null|"") adb shell settings put secure enabled_accessibility_services "$SVC" ;;
  *) adb shell settings put secure enabled_accessibility_services "$CUR:$SVC" ;; esac
adb shell settings put secure accessibility_enabled 1

log "launch, demo mode via reset + debug dump"
adb logcat -c
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 4
adb shell am broadcast -n $PKG/.DebugReceiver -a $PKG.DEBUG_RESET >/dev/null
sleep 1
shot 01_app_launched
echo "  (turn on Demo mode in Settings now for a fast loop; press Enter)"; read -r _

log "1-3. scroll in Chrome / another app -> metres, debt, frost"
W=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1); X=${W%x*}; Y=${W#*x}
TARGET=${SCROLL_APP:-com.android.chrome}
adb shell monkey -p "$TARGET" -c android.intent.category.LAUNCHER 1 >/dev/null; sleep 4
for i in $(seq 1 ${SWIPES:-80}); do
  adb shell input swipe $((X/2)) $((Y*8/10)) $((X/2)) $((Y*2/10)) 120
done
sleep 2
shot 02_frosted_app
adb logcat -d -s flutter | grep 'SD ' > "$OUT/scroll_log.txt" || true
grep -c 'SD scroll' "$OUT/scroll_log.txt" | sed 's/^/  scroll events: /'
grep 'SD frost' "$OUT/scroll_log.txt" | tail -3
adb shell dumpsys window windows | grep -i -A3 ScrollDebtFrost > "$OUT/frost_window.txt" || true

log "touch passthrough: tap still reaches the app under the frost"
adb shell input tap $((X/2)) $((Y/2)); sleep 1; shot 03_tap_through

log "exempt: settings app must not be frosted"
adb shell am start -a android.settings.SETTINGS >/dev/null; sleep 2; shot 04_settings_not_frosted

log "background survival: swipe app away from recents, keep scrolling"
adb shell am start -n $PKG/.MainActivity >/dev/null; sleep 2
adb shell input keyevent KEYCODE_APP_SWITCH; sleep 1
adb shell input swipe $((X/2)) $((Y/2)) $((X/2)) 0 200; sleep 1
adb shell input keyevent KEYCODE_HOME
adb shell monkey -p "$TARGET" -c android.intent.category.LAUNCHER 1 >/dev/null; sleep 3
adb logcat -c
for i in 1 2 3 4 5; do adb shell input swipe $((X/2)) $((Y*8/10)) $((X/2)) $((Y*2/10)) 120; done
sleep 2
adb logcat -d -s flutter | grep -c 'SD scroll' | sed 's/^/  scroll events after swipe-away: /'

log "8. emergency override via app button is manual; skipping"

log "2. walk it off (debug hook) -> frost clears"
adb shell am broadcast -n $PKG/.DebugReceiver -a $PKG.DEBUG_WALK --ef metres 1000 >/dev/null
sleep 2; shot 05_cleared
adb logcat -d -s flutter | grep -E 'SD (walk|frost)' | tail -4 | tee "$OUT/walk_log.txt"

log "5. widget: add 'Scroll Debt (4x2)' to the home screen by hand, then press Enter"; read -r _
adb shell input keyevent KEYCODE_HOME; sleep 2; shot 06_widget

log "persistence: force-stop + restart"
adb shell am broadcast -n $PKG/.DebugReceiver -a $PKG.DEBUG_DUMP >/dev/null; sleep 1
adb logcat -d -s flutter | grep 'SD dump' | tail -1 > "$OUT/dump_before.txt"
adb shell am force-stop $PKG
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null; sleep 4
adb logcat -c
adb shell am broadcast -n $PKG/.DebugReceiver -a $PKG.DEBUG_DUMP >/dev/null; sleep 1
adb logcat -d -s flutter | grep 'SD dump' | tail -1 > "$OUT/dump_after.txt"
diff <(cut -c1-200 "$OUT/dump_before.txt") <(cut -c1-200 "$OUT/dump_after.txt") && echo "  state survived restart" || true

log "release manifest has no INTERNET"
flutter build apk --release
"${ANDROID_HOME:-$HOME/Android/Sdk}"/build-tools/*/aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk 2>/dev/null \
  | tee "$OUT/release_permissions.txt" | grep -q INTERNET && echo "  FAIL: INTERNET present" || echo "  ok: no INTERNET"
echo; echo "Done. Evidence in $OUT/"
