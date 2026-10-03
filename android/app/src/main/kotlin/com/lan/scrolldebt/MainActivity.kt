package com.lan.scrolldebt

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Attaches the UI to the long-lived engine owned by [Shim]. The engine is
 * never destroyed with the activity, so swiping the app away from recents
 * keeps tracking alive.
 */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine = Shim.engine(context)

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Shim.startForeground(this)
    }
}
