package com.lan.scrolldebt

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * DEBUG BUILDS ONLY (src/debug). Lets adb simulate walking and dump state:
 *   adb shell am broadcast -n com.lan.scrolldebt/.DebugReceiver \
 *       -a com.lan.scrolldebt.DEBUG_WALK --ef metres 25
 *   adb shell am broadcast -n com.lan.scrolldebt/.DebugReceiver \
 *       -a com.lan.scrolldebt.DEBUG_SCROLL --es pkg com.instagram.android --ef metres 10
 *   adb shell am broadcast -n com.lan.scrolldebt/.DebugReceiver \
 *       -a com.lan.scrolldebt.DEBUG_DUMP
 */
class DebugReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Shim.engine(context)
        when (intent.action) {
            "com.lan.scrolldebt.DEBUG_WALK" ->
                Shim.send("debugInjectWalk", mapOf("metres" to intent.getFloatExtra("metres", 10f).toDouble()))
            "com.lan.scrolldebt.DEBUG_SCROLL" -> Shim.send("debugInjectScroll", mapOf(
                "pkg" to (intent.getStringExtra("pkg") ?: "com.instagram.android"),
                "metres" to intent.getFloatExtra("metres", 10f).toDouble(),
            ))
            "com.lan.scrolldebt.DEBUG_DUMP" -> Shim.send("debugDump", null)
            "com.lan.scrolldebt.DEBUG_RESET" -> Shim.send("debugReset", null)
        }
    }
}
