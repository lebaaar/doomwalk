package com.lebaaar.doomwalk

// All decisions live in Dart; this file only forwards accessibility geometry (canRetrieveWindowContent=false, never getSource/getText/getContentDescription) and executes what Dart asks for

import android.Manifest
import android.accessibilityservice.AccessibilityService
import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.ApplicationExitInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.animation.DecelerateInterpolator
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

private const val TAG = "DoomWalk"

object Shim {
    const val ENGINE_ID = "doomwalk_engine"
    private const val CHANNEL = "com.lebaaar.doomwalk/native"

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var dartReady = false
    private val pending = ArrayDeque<Pair<String, Any?>>()

    var accessibility: ScrollAccessibilityService? = null

    var notifTitle = "DoomWalk"
    var notifText = "Tracking scroll distance"
    var overridesLeft = 0
    var overrideActive = false
    var overrideUntilMs: Long? = null

    fun engine(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
        val app = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        val engine = FlutterEngine(app)
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result -> handle(app, call, result) }
        channel = ch
        dartReady = false
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        Log.i(TAG, "engine started")
        return engine
    }

    fun send(method: String, args: Any?) {
        main.post {
            val ch = channel
            if (ch == null || !dartReady) {
                if (pending.size >= 512) pending.removeFirst()
                pending.addLast(method to args)
            } else {
                ch.invokeMethod(method, args)
            }
        }
    }

    fun startForeground(context: Context) {
        try {
            context.startForegroundService(Intent(context, DebtForegroundService::class.java))
        } catch (e: Exception) {
            Log.w(TAG, "could not start foreground service: $e")
        }
    }

    fun isAccessibilityEnabled(context: Context): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val me = ComponentName(context, ScrollAccessibilityService::class.java)
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == me }
    }

    private fun handle(app: Context, call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "ready" -> {
                    dartReady = true
                    result.success(deviceInfo(app))
                    while (pending.isNotEmpty()) {
                        val (m, a) = pending.removeFirst()
                        channel?.invokeMethod(m, a)
                    }
                }
                "setFrost" -> {
                    val level = (call.argument<Double>("level") ?: 0.0).toFloat()
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val ms = (call.argument<Int>("animateMs") ?: 600).toLong()
                    val passes = call.argument<Int>("overridesLeft") ?: 0
                    accessibility?.frost?.animateTo(level, title, body, ms, passes)
                    accessibility?.frost?.showPass(call.argument<Number>("passUntilMs")?.toLong())
                    result.success(accessibility != null)
                }
                "showNotice" -> {
                    accessibility?.frost?.notice(
                        call.argument<String>("title") ?: "",
                        call.argument<String>("body") ?: "",
                        (call.argument<Int>("ms") ?: 4000).toLong(),
                    )
                    result.success(accessibility != null)
                }
                "updateNotification" -> {
                    notifTitle = call.argument<String>("title") ?: notifTitle
                    notifText = call.argument<String>("text") ?: notifText
                    overridesLeft = call.argument<Int>("overridesLeft") ?: 0
                    overrideActive = call.argument<Boolean>("overrideActive") ?: false
                    overrideUntilMs = call.argument<Number>("overrideUntilMs")?.toLong()
                    DebtForegroundService.refresh(app)
                    result.success(null)
                }
                "startForegroundService" -> {
                    startForeground(app); result.success(null)
                }
                "status" -> result.success(status(app))
                "restartAccessibility" -> result.success(restartAccessibility(app))
                "openAccessibilitySettings" -> {
                    val cn = ComponentName(app, ScrollAccessibilityService::class.java)
                    val details = Intent("android.settings.ACCESSIBILITY_DETAILS_SETTINGS")
                        .putExtra(Intent.EXTRA_COMPONENT_NAME, cn.flattenToString())
                    if (!launch(app, details)) launch(app, Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "openAppDetails" -> {
                    launch(app, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", app.packageName, null)))
                    result.success(null)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    val ok = launch(app, Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:${app.packageName}")))
                    if (!ok) launch(app, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    result.success(null)
                }
                "appInfo" -> result.success(appInfo(app, call.argument<String>("pkg") ?: ""))
                "launchableApps" -> result.success(launchableApps(app))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("shim", e.toString(), null)
        }
    }

    private fun launch(app: Context, intent: Intent): Boolean = try {
        app.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }

    private fun deviceInfo(app: Context): Map<String, Any?> {
        val dm = app.resources.displayMetrics
        val wm = app.getSystemService(WindowManager::class.java)
        val bounds = wm.maximumWindowMetrics.bounds
        val pm = app.packageManager
        val launchers = pm.queryIntentActivities(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), PackageManager.MATCH_ALL
        ).map { it.activityInfo.packageName }.distinct()
        val keyboards = app.getSystemService(InputMethodManager::class.java)
            .enabledInputMethodList.map { it.packageName }.distinct()
        return mapOf(
            "ydpi" to dm.ydpi.toDouble(),
            "densityDpi" to dm.densityDpi.toDouble(),
            "screenHeightPx" to maxOf(bounds.height(), bounds.width()).toDouble(),
            "sdk" to Build.VERSION.SDK_INT,
            "launchers" to launchers,
            "keyboards" to keyboards,
            "bootTimeMs" to (System.currentTimeMillis() - SystemClock.elapsedRealtime()),
        ) + status(app)
    }

    private fun status(app: Context): Map<String, Any?> {
        val pm = app.getSystemService(PowerManager::class.java)
        return mapOf(
            "accessibilityEnabled" to isAccessibilityEnabled(app),
            "serviceConnected" to (accessibility != null),
            "ignoringBatteryOptimizations" to pm.isIgnoringBatteryOptimizations(app.packageName),
            "restrictedSettingsAllowed" to restrictedSettingsAllowed(app),
            "blurEnabled" to app.getSystemService(WindowManager::class.java).isCrossWindowBlurEnabled,
            "sdk" to Build.VERSION.SDK_INT,
            "canRestartService" to canWriteSecureSettings(app),
        ) + lastExit(app)
    }

    // A dead process takes the accessibility service with it and Android 10+ won't rebind it until it is switched off and on
    private fun lastExit(app: Context): Map<String, Any?> = try {
        val info = app.getSystemService(ActivityManager::class.java)
            .getHistoricalProcessExitReasons(app.packageName, 0, 1).firstOrNull()
        if (info == null) emptyMap() else mapOf(
            "exitReason" to info.reason,
            "exitDescription" to info.description,
            "exitTimeMs" to info.timestamp,
            "exitWasCrash" to (info.reason == ApplicationExitInfo.REASON_CRASH ||
                info.reason == ApplicationExitInfo.REASON_CRASH_NATIVE),
        )
    } catch (e: Exception) {
        emptyMap()
    }

    private fun canWriteSecureSettings(app: Context) =
        app.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) == PackageManager.PERMISSION_GRANTED

    // Android clears the crashed mark when a service leaves the enabled list and binds it fresh when re-added
    private fun restartAccessibility(app: Context): Boolean {
        if (!canWriteSecureSettings(app)) return false
        val me = ComponentName(app, ScrollAccessibilityService::class.java)
        val cr = app.contentResolver
        val key = Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        val others = (Settings.Secure.getString(cr, key) ?: "").split(':')
            .filter { it.isNotBlank() && ComponentName.unflattenFromString(it) != me }
        return try {
            Settings.Secure.putString(cr, key, others.joinToString(":"))
            main.postDelayed({
                try {
                    Settings.Secure.putString(cr, key, (others + me.flattenToString()).joinToString(":"))
                    Settings.Secure.putString(cr, Settings.Secure.ACCESSIBILITY_ENABLED, "1")
                    Log.i(TAG, "accessibility service re-enabled")
                } catch (e: Exception) {
                    Log.w(TAG, "re-enable failed: $e")
                }
            }, 800)
            true
        } catch (e: Exception) {
            Log.w(TAG, "restart failed: $e")
            false
        }
    }

    @Suppress("DEPRECATION") // checkOpNoThrow(String…) needs API 36; minSdk is 31
    private fun restrictedSettingsAllowed(app: Context): Boolean? {
        if (Build.VERSION.SDK_INT < 33) return true
        return try {
            val ops = app.getSystemService(AppOpsManager::class.java)
            val mode = ops.unsafeCheckOpNoThrow(
                "android:access_restricted_settings", app.applicationInfo.uid, app.packageName
            )
            mode != AppOpsManager.MODE_ERRORED && mode != AppOpsManager.MODE_IGNORED
        } catch (e: Exception) {
            null
        }
    }

    private fun appInfo(app: Context, pkg: String): Map<String, Any?>? {
        val pm = app.packageManager
        return try {
            val ai = pm.getApplicationInfo(pkg, 0)
            val icon = pm.getApplicationIcon(ai)
            val size = 96
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            icon.setBounds(0, 0, size, size)
            icon.draw(canvas)
            val out = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            mapOf(
                "pkg" to pkg,
                "label" to pm.getApplicationLabel(ai).toString(),
                "category" to ai.category,
                "system" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                "icon" to out.toByteArray(),
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun launchableApps(app: Context): List<Map<String, Any?>> {
        val pm = app.packageManager
        return pm.queryIntentActivities(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0
        ).map { it.activityInfo.applicationInfo }.distinctBy { it.packageName }.map {
            mapOf(
                "pkg" to it.packageName,
                "label" to pm.getApplicationLabel(it).toString(),
                "category" to it.category,
            )
        }
    }
}

class ScrollAccessibilityService : AccessibilityService() {
    var frost: FrostOverlay? = null
        private set

    override fun onServiceConnected() {
        Shim.accessibility = this
        frost = FrostOverlay(this)
        Shim.engine(this)
        Shim.startForeground(this)
        Shim.send("onServiceState", mapOf("connected" to true, "t" to System.currentTimeMillis()))
        Log.i(TAG, "accessibility service connected")
    }

    private var lastScrollPkg: String? = null

    override fun onAccessibilityEvent(e: AccessibilityEvent) {
        val pkg = e.packageName?.toString() ?: return
        val now = System.currentTimeMillis()
        when (e.eventType) {
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                // Our own scrolling is forwarded once (it marks us as the open app) and the rest dropped so our lists don't flood the engine
                if (pkg == packageName && lastScrollPkg == pkg) return
                lastScrollPkg = pkg
                Shim.send(
                    "onScroll", hashMapOf(
                        "pkg" to pkg,
                        "cls" to (e.className?.toString() ?: ""),
                        "t" to now,
                        "win" to e.windowId,
                        "dx" to e.scrollDeltaX,
                        "dy" to e.scrollDeltaY,
                        "sy" to e.scrollY,
                        "msy" to e.maxScrollY,
                        "from" to e.fromIndex,
                        "to" to e.toIndex,
                        "count" to e.itemCount,
                    )
                )
            }
            // The class name lets Dart tell our activity from our frost windows, which fire the same event type
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> Shim.send(
                "onWindow", mapOf("pkg" to pkg, "cls" to (e.className?.toString() ?: ""), "t" to now)
            )
        }
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        disconnect()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        disconnect()
        super.onDestroy()
    }

    private fun disconnect() {
        if (Shim.accessibility !== this) return
        frost?.remove()
        frost = null
        Shim.accessibility = null
        Shim.send("onServiceState", mapOf("connected" to false, "t" to System.currentTimeMillis()))
        Log.i(TAG, "accessibility service disconnected")
    }
}

// Full-screen non-touchable accessibility overlay (blur, or a milky tint without cross-window blur) plus a touchable card; trusted overlays let touches outside the card reach the app below
class FrostOverlay(private val service: AccessibilityService) {
    private val wm = service.getSystemService(WindowManager::class.java)
    private val density = service.resources.displayMetrics.density
    private val maxBlurPx = (48 * density).toInt()
    private val handler = Handler(Looper.getMainLooper())
    private var root: FrameLayout? = null
    private var animator: ValueAnimator? = null
    private var level = 0f
    private var blurEnabled = wm.isCrossWindowBlurEnabled
    private var lastRadius = -1
    private val blurListener = java.util.function.Consumer<Boolean> {
        blurEnabled = it
        lastRadius = -1
        apply(level)
    }
    private val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        title = "DoomWalkFrost"
        layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
    }

    // FLAG_NOT_TOUCH_MODAL lets every touch outside the card reach the app below
    private var card: LinearLayout? = null
    private var cardTitle: TextView? = null
    private var cardBody: TextView? = null
    private var passButton: TextView? = null
    private var overridesLeft = 0
    private var titleText = "Take a walk first"
    private var bodyText = ""
    private val cardParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT
    ).apply {
        title = "DoomWalkFrostCard"
        gravity = Gravity.CENTER
    }

    private var banner: LinearLayout? = null
    private val bannerParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT
    ).apply {
        title = "DoomWalkNotice"
        gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        y = (56 * density).toInt()
    }
    private val hideBanner = Runnable { removeBanner() }

    private var pass: TextView? = null
    // Monotonic clock so a clock change can't skew it
    private var passEndElapsed = 0L
    private val passParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT
    ).apply {
        title = "DoomWalkPass"
        gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        y = (40 * density).toInt()
    }
    private val tickPass = object : Runnable {
        override fun run() {
            val left = passEndElapsed - SystemClock.elapsedRealtime()
            if (left <= 0) {
                removePass()
                return
            }
            val s = (left + 999) / 1000
            pass?.text = "Pass: %d:%02d left".format(s / 60, s % 60)
            handler.postDelayed(this, (left - 1) % 1000 + 1)
        }
    }

    private class Colors(
        val surface: Int, val text: Int, val muted: Int, val hairline: Int,
        val accent: Int, val onAccent: Int, val danger: Int,
    )

    private fun colors(): Colors {
        val night = (service.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        return if (night) Colors(
            surface = Color.rgb(0x12, 0x15, 0x1A), text = Color.rgb(0xED, 0xF0, 0xF3),
            muted = Color.rgb(0x8D, 0x96, 0xA1), hairline = Color.rgb(0x23, 0x28, 0x30),
            accent = Color.rgb(0xA9, 0xD3, 0xEC), onAccent = Color.rgb(0x0A, 0x0C, 0x0F),
            danger = Color.rgb(0xF2, 0xB8, 0xB5),
        ) else Colors(
            surface = Color.WHITE, text = Color.rgb(0x0C, 0x11, 0x17),
            muted = Color.rgb(0x5B, 0x64, 0x70), hairline = Color.rgb(0xE3, 0xE6, 0xEA),
            accent = Color.rgb(0x0E, 0x41, 0x66), onAccent = Color.WHITE,
            danger = Color.rgb(0xB3, 0x26, 0x1E),
        )
    }

    init {
        wm.addCrossWindowBlurEnabledListener(service.mainExecutor, blurListener)
    }

    val isCardShown get() = card != null
    val passText: String? get() = pass?.text?.toString()

    fun showPass(untilMs: Long?) {
        if (untilMs == null || untilMs <= System.currentTimeMillis()) {
            removePass()
            return
        }
        passEndElapsed = SystemClock.elapsedRealtime() + (untilMs - System.currentTimeMillis())
        if (pass == null) {
            val c = colors()
            val tv = text("", 14f, c.text, bold = true).apply {
                setPadding(dp(14), dp(8), dp(14), dp(8))
                background = GradientDrawable().apply {
                    cornerRadius = dp(20).toFloat()
                    setColor(c.surface)
                    setStroke(dp(1), c.hairline)
                }
                elevation = dp(6).toFloat()
                fontFeatureSettings = "tnum"
                minHeight = dp(36)
                gravity = Gravity.CENTER
                isClickable = true
                setOnClickListener { openApp() }
            }
            pass = tv
            try {
                wm.addView(tv, passParams)
            } catch (e: Exception) {
                Log.w(TAG, "pass addView failed: $e")
                pass = null
                return
            }
        }
        handler.removeCallbacks(tickPass)
        tickPass.run()
    }

    private fun openApp() {
        try {
            service.startActivity(
                Intent(service, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            )
        } catch (e: Exception) {
            Log.w(TAG, "open app from pass failed: $e")
        }
    }

    private fun removePass() {
        handler.removeCallbacks(tickPass)
        pass?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        pass = null
    }
    val isBannerShown get() = banner != null

    fun animateTo(target: Float, title: String?, body: String?, durationMs: Long, passesLeft: Int) {
        val t = target.coerceIn(0f, 1f)
        overridesLeft = passesLeft
        if (title != null) titleText = title
        if (body != null) bodyText = body
        // cancel() also fires onAnimationEnd; clearing the field first stops a superseded fade-in from detaching the window
        val old = animator
        animator = null
        old?.cancel()
        if (t <= 0.001f) {
            removeCard()
            if (root == null) return
        } else {
            ensureAdded()
            ensureCard()
            updateCard()
        }
        val next = ValueAnimator.ofFloat(level, t).apply {
            duration = durationMs
            interpolator = DecelerateInterpolator()
            addUpdateListener { apply(it.animatedValue as Float) }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    if (animator === animation && level <= 0.001f) detach()
                }
            })
        }
        animator = next
        next.start()
    }

    fun notice(title: String, body: String, ms: Long) {
        removeBanner()
        val c = colors()
        val ll = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(14), dp(18), dp(14))
            background = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(c.surface)
                setStroke(dp(1), c.hairline)
            }
            elevation = dp(8).toFloat()
            addView(text(title, 16f, c.text, bold = true))
            addView(text(body, 14f, c.muted), LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(2) })
        }
        bannerParams.width = cardWidth()
        banner = ll
        try {
            wm.addView(ll, bannerParams)
            ll.alpha = 0f
            ll.translationY = -dp(24).toFloat()
            ll.animate().alpha(1f).translationY(0f).setDuration(280)
                .setInterpolator(DecelerateInterpolator()).start()
            handler.postDelayed(hideBanner, ms)
        } catch (e: Exception) {
            Log.w(TAG, "notice addView failed: $e")
            banner = null
        }
    }

    private fun ensureAdded() {
        if (root != null) return
        val fl = FrameLayout(service)
        root = fl
        lastRadius = -1
        try {
            wm.addView(fl, params)
        } catch (e: Exception) {
            Log.w(TAG, "frost addView failed: $e")
            root = null
        }
    }

    private fun dp(v: Int) = (v * density).toInt()

    private fun cardWidth(): Int {
        val screen = wm.currentWindowMetrics.bounds.width()
        return minOf(screen - dp(48), dp(440)).coerceAtLeast(dp(200))
    }

    private fun text(s: String, sp: Float, color: Int, bold: Boolean = false) = TextView(service).apply {
        text = s
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        setTextColor(color)
        if (bold) typeface = Typeface.create(Typeface.DEFAULT, 600, false)
        setLineSpacing(0f, 1.15f)
    }

    private fun button(s: String, filled: Boolean, c: Colors, onClick: () -> Unit) = TextView(service).apply {
        text = s
        gravity = Gravity.CENTER
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
        typeface = Typeface.create(Typeface.DEFAULT, 500, false)
        setTextColor(if (filled) c.onAccent else c.text)
        minHeight = dp(48)
        setPadding(dp(16), dp(12), dp(16), dp(12))
        background = GradientDrawable().apply {
            cornerRadius = dp(12).toFloat()
            if (filled) setColor(c.accent) else setStroke(dp(1), c.hairline)
        }
        isClickable = true
        setOnClickListener { onClick() }
    }

    private fun ensureCard() {
        if (card != null) return
        val c = colors()
        val eyebrow = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(ImageView(service).apply {
                setImageResource(R.drawable.ic_stat_ticks)
                imageTintList = ColorStateList.valueOf(c.accent)
            }, LinearLayout.LayoutParams(dp(22), dp(22)))
            addView(text("DoomWalk", 14f, c.text, bold = true), LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { marginStart = dp(8) })
        }
        val title = text(titleText, 22f, c.text, bold = true)
        val body = text(bodyText, 15f, c.muted)
        val pass = button("Use pass", filled = false, c) { Shim.send("onOverrideRequested", null) }
        val leave = button("Leave app", filled = true, c) {
            service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
        }
        fun weighted(start: Int) = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            .apply { marginStart = start }
        val buttons = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            addView(pass, weighted(0))
            addView(leave, weighted(dp(8)))
        }
        fun below(top: Int) = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = top }
        val ll = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(20), dp(22), dp(20))
            background = GradientDrawable().apply {
                cornerRadius = dp(24).toFloat()
                setColor(c.surface)
                setStroke(dp(1), c.hairline)
            }
            elevation = dp(12).toFloat()
            addView(eyebrow)
            addView(title, below(dp(6)))
            addView(body, below(dp(8)))
            addView(buttons, below(dp(20)))
        }
        card = ll
        cardTitle = title
        cardBody = body
        passButton = pass
        cardParams.width = cardWidth()
        try {
            wm.addView(ll, cardParams)
            ll.alpha = 0f
            ll.animate().alpha(1f).setDuration(200).start()
        } catch (e: Exception) {
            Log.w(TAG, "frost card addView failed: $e")
            card = null
        }
    }

    private fun updateCard() {
        cardTitle?.text = titleText
        cardBody?.text = bodyText
        passButton?.let {
            it.visibility = if (overridesLeft > 0) View.VISIBLE else View.GONE
            it.text = "Use pass ($overridesLeft)"
        }
    }

    private fun removeCard() {
        card?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        card = null
        cardTitle = null
        cardBody = null
        passButton = null
    }

    private fun removeBanner() {
        handler.removeCallbacks(hideBanner)
        banner?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        banner = null
    }

    private fun apply(v: Float) {
        level = v
        val r = root ?: return
        // Any debt blurs at half strength, growing to full; the first 5% of the level only fades that in
        val s = if (v <= 0f) 0f else minOf(1f, 0.5f + 0.5f * v) * minOf(1f, v / 0.05f)
        val tintAlpha: Float
        if (blurEnabled) {
            val radius = (s * maxBlurPx).toInt()
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
            if (radius != lastRadius) {
                params.blurBehindRadius = radius
                lastRadius = radius
                try { wm.updateViewLayout(r, params) } catch (_: Exception) {}
            }
            tintAlpha = 0.35f * s
        } else {
            if (params.flags and WindowManager.LayoutParams.FLAG_BLUR_BEHIND != 0) {
                params.flags = params.flags and WindowManager.LayoutParams.FLAG_BLUR_BEHIND.inv()
                params.blurBehindRadius = 0
                try { wm.updateViewLayout(r, params) } catch (_: Exception) {}
            }
            tintAlpha = 0.94f * s
        }
        r.setBackgroundColor(Color.argb((tintAlpha * 255).toInt(), 226, 240, 248))
    }

    private fun detach() {
        root?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        root = null
        removeCard()
        level = 0f
    }

    fun remove() {
        val old = animator
        animator = null
        old?.cancel()
        detach()
        removeBanner()
        removePass()
        wm.removeCrossWindowBlurEnabledListener(blurListener)
    }
}

class DebtForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "debt_status"
        private const val NOTIF_ID = 42
        const val ACTION_OVERRIDE = "com.lebaaar.doomwalk.OVERRIDE"
        private var running = false

        fun refresh(context: Context) {
            if (!running) return
            context.getSystemService(NotificationManager::class.java)
                .notify(NOTIF_ID, build(context))
        }

        private fun build(context: Context): Notification {
            val open = PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val b = Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_ticks)
                .setContentTitle(Shim.notifTitle)
                .setContentText(Shim.notifText)
                .setContentIntent(open)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            val until = Shim.overrideUntilMs
            if (Shim.overrideActive && until != null && until > System.currentTimeMillis()) {
                b.setWhen(until).setShowWhen(true).setUsesChronometer(true).setChronometerCountDown(true)
            }
            if (!Shim.overrideActive && Shim.overridesLeft > 0) {
                val pi = PendingIntent.getService(
                    context, 1,
                    Intent(context, DebtForegroundService::class.java).setAction(ACTION_OVERRIDE),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                b.addAction(Notification.Action.Builder(
                    null as android.graphics.drawable.Icon?, "Emergency pass (${Shim.overridesLeft} left)", pi
                ).build())
            }
            return b.build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Debt status", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Scrolling left, steps to walk and the emergency pass"
                setShowBadge(false)
            }
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // startForeground first: a slow cold engine start can miss Android's deadline, which kills the whole process
        if (!goForeground()) return START_NOT_STICKY
        Shim.engine(this)
        if (intent?.action == ACTION_OVERRIDE) Shim.send("onOverrideRequested", null)
        return START_STICKY
    }

    private fun goForeground(): Boolean {
        val notification = build(this)
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                val health = checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
                    PackageManager.PERMISSION_GRANTED
                startForeground(
                    NOTIF_ID, notification,
                    if (health) ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
                    else ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIF_ID, notification)
            }
            running = true
            return true
        } catch (e: Exception) {
            // Never reaching startForeground() after startForegroundService() crashes the app, so stop cleanly
            Log.w(TAG, "startForeground failed: $e")
            stopSelf()
            return false
        }
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                Shim.startForeground(context)
        }
    }
}
