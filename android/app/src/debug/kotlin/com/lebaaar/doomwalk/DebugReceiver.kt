package com.lebaaar.doomwalk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

// Debug only: adb broadcasts DEBUG_WALK, DEBUG_SCROLL and DEBUG_DUMP (see tool/device_test.sh)
class DebugReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Shim.engine(context)
        when (intent.action) {
            "com.lebaaar.doomwalk.DEBUG_WALK" ->
                Shim.send("debugInjectWalk", mapOf("metres" to intent.getFloatExtra("metres", 10f).toDouble()))
            "com.lebaaar.doomwalk.DEBUG_SCROLL" -> Shim.send("debugInjectScroll", mapOf(
                "pkg" to (intent.getStringExtra("pkg") ?: "com.instagram.android"),
                "metres" to intent.getFloatExtra("metres", 10f).toDouble(),
            ))
            "com.lebaaar.doomwalk.DEBUG_DUMP" -> Shim.send("debugDump", null)
            "com.lebaaar.doomwalk.DEBUG_RESET" -> Shim.send("debugReset", null)
        }
    }
}
