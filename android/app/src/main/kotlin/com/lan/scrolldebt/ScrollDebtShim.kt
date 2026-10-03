package com.lan.scrolldebt

// Native shim for Scroll Debt. Everything here exists because no plugin can
// do it (see SPIKE.md / DECISIONS.md). All decisions live in Dart; this file
// only forwards accessibility geometry to Dart and executes what Dart asks
// for (frost level, notification text, settings deep links).
//
// Privacy: the accessibility service is configured with
// canRetrieveWindowContent="false" and only scroll/window-state events. We
// never call getSource(), getText() or getContentDescription().

import android.Manifest
import android.accessibilityservice.AccessibilityService
import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.AppOpsManager
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
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PixelFormat
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
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.animation.DecelerateInterpolator
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import android.widget.TextView
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

private const val TAG = "ScrollDebt"

/** Owns the single cached FlutterEngine and the method channel to Dart. */
object Shim {
    const val ENGINE_ID = "scrolldebt_engine"
    private const val CHANNEL = "com.lan.scrolldebt/native"

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var dartReady = false
    private val pending = ArrayDeque<Pair<String, Any?>>()

    var accessibility: ScrollAccessibilityService? = null

    // Last notification content pushed by Dart.
    var notifTitle = "Scroll Debt"
    var notifText = "Tracking scroll distance"
    var overridesLeft = 0
    var overrideActive = false

    /** Returns the app's engine, creating and starting main() if needed. Main thread only. */
    fun engine(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
        val app = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        val engine = FlutterEngine(app) // registers all pub plugins
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result -> handle(app, call, result) }
        channel = ch
        dartReady = false
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        Log.i(TAG, "engine started")
        return engine
    }

    /** Sends an event to Dart; queued until Dart has called `ready`. */
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
                    val label = call.argument<String>("label")
                    val ms = (call.argument<Int>("animateMs") ?: 600).toLong()
                    accessibility?.frost?.animateTo(level, label, ms)
                    result.success(accessibility != null)
                }
                "updateNotification" -> {
                    notifTitle = call.argument<String>("title") ?: notifTitle
                    notifText = call.argument<String>("text") ?: notifText
                    overridesLeft = call.argument<Int>("overridesLeft") ?: 0
                    overrideActive = call.argument<Boolean>("overrideActive") ?: false
                    DebtForegroundService.refresh(app)
                    result.success(null)
                }
                "startForegroundService" -> {
                    startForeground(app); result.success(null)
                }
                "status" -> result.success(status(app))
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
        )
    }

    /** Android 13+ "Allow restricted settings". null = cannot tell. */
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

/** Forwards scroll geometry + foreground changes, and hosts the frost overlay. */
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

    override fun onAccessibilityEvent(e: AccessibilityEvent) {
        val pkg = e.packageName?.toString() ?: return
        val now = System.currentTimeMillis()
        when (e.eventType) {
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> Shim.send(
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
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ->
                Shim.send("onWindow", mapOf("pkg" to pkg, "t" to now))
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

/**
 * Full-screen, non-touchable TYPE_ACCESSIBILITY_OVERLAY. Accessibility
 * overlays are trusted windows, so with FLAG_NOT_TOUCHABLE every touch goes
 * to the app below (Android 12 untrusted-touch occlusion rules don't apply).
 * Real blur via FLAG_BLUR_BEHIND when cross-window blur is enabled; otherwise
 * a milky translucent layer.
 */
class FrostOverlay(private val service: AccessibilityService) {
    private val wm = service.getSystemService(WindowManager::class.java)
    private val density = service.resources.displayMetrics.density
    private val maxBlurPx = (48 * density).toInt()
    private var root: FrameLayout? = null
    private var label: TextView? = null
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
        title = "ScrollDebtFrost"
        layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
    }

    init {
        wm.addCrossWindowBlurEnabledListener(service.mainExecutor, blurListener)
    }

    fun animateTo(target: Float, text: String?, durationMs: Long) {
        val t = target.coerceIn(0f, 1f)
        animator?.cancel()
        if (t <= 0.001f && root == null) return
        ensureAdded()
        if (text != null) label?.text = text
        animator = ValueAnimator.ofFloat(level, t).apply {
            duration = durationMs
            interpolator = DecelerateInterpolator()
            addUpdateListener { apply(it.animatedValue as Float) }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    if (level <= 0.001f) detach()
                }
            })
            start()
        }
    }

    private fun ensureAdded() {
        if (root != null) return
        val tv = TextView(service).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setShadowLayer(6f, 0f, 1f, Color.argb(160, 0, 20, 40))
            setPadding((16 * density).toInt(), (8 * density).toInt(), (16 * density).toInt(), (8 * density).toInt())
            background = GradientDrawable().apply {
                cornerRadius = 20 * density
                setColor(Color.argb(150, 11, 15, 20))
            }
        }
        val fl = FrameLayout(service)
        fl.addView(tv, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.CENTER_HORIZONTAL
        ).apply { topMargin = (56 * density).toInt() })
        root = fl
        label = tv
        lastRadius = -1
        try {
            wm.addView(fl, params)
        } catch (e: Exception) {
            Log.w(TAG, "frost addView failed: $e")
            root = null
        }
    }

    private fun apply(v: Float) {
        level = v
        val r = root ?: return
        val tintAlpha: Float
        if (blurEnabled) {
            val radius = (v * maxBlurPx).toInt()
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
            if (radius != lastRadius) {
                params.blurBehindRadius = radius
                lastRadius = radius
                try { wm.updateViewLayout(r, params) } catch (_: Exception) {}
            }
            tintAlpha = 0.30f * v
        } else {
            if (params.flags and WindowManager.LayoutParams.FLAG_BLUR_BEHIND != 0) {
                params.flags = params.flags and WindowManager.LayoutParams.FLAG_BLUR_BEHIND.inv()
                params.blurBehindRadius = 0
                try { wm.updateViewLayout(r, params) } catch (_: Exception) {}
            }
            tintAlpha = 0.86f * v
        }
        r.setBackgroundColor(Color.argb((tintAlpha * 255).toInt(), 222, 234, 246))
        label?.alpha = (v * 1.6f).coerceAtMost(1f)
    }

    private fun detach() {
        root?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        root = null
        label = null
        level = 0f
    }

    fun remove() {
        animator?.cancel()
        detach()
        wm.removeCrossWindowBlurEnabledListener(blurListener)
    }
}

/**
 * Keeps the process (and therefore the Dart engine, step counting and the
 * ledger) alive with a persistent notification. Type `health` once
 * ACTIVITY_RECOGNITION is granted (Android 14 requirement), `specialUse`
 * before that.
 */
class DebtForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "debt_status"
        private const val NOTIF_ID = 42
        const val ACTION_OVERRIDE = "com.lan.scrolldebt.OVERRIDE"
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
                .setSmallIcon(R.drawable.ic_stat_mountain)
                .setContentTitle(Shim.notifTitle)
                .setContentText(Shim.notifText)
                .setContentIntent(open)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            if (!Shim.overrideActive && Shim.overridesLeft > 0) {
                val pi = PendingIntent.getService(
                    context, 1,
                    Intent(context, DebtForegroundService::class.java).setAction(ACTION_OVERRIDE),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                b.addAction(Notification.Action.Builder(
                    null as android.graphics.drawable.Icon?, "Emergency pass (${Shim.overridesLeft} left, 3× cost)", pi
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
                description = "Current scroll debt and emergency pass"
                setShowBadge(false)
            }
        )
        Shim.engine(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goForeground()
        if (intent?.action == ACTION_OVERRIDE) Shim.send("onOverrideRequested", null)
        return START_STICKY
    }

    private fun goForeground() {
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
        } catch (e: Exception) {
            Log.w(TAG, "startForeground failed: $e")
        }
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }
}

/** Restarts tracking after reboot / app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                Shim.startForeground(context)
        }
    }
}
