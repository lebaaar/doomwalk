package com.lebaaar.doomwalk

import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.TextView
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowWindowManagerImpl
import java.time.Duration

/**
 * The real FrostOverlay against Robolectric's window manager: which windows
 * a frozen app gets, which of them take touches, and what they say.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class FrostOverlayTest {
    private val svc = Robolectric.setupService(ScrollAccessibilityService::class.java)
    private val wm = svc.getSystemService(WindowManager::class.java)
    private val overlay = FrostOverlay(svc)

    private fun windows(): List<View> = Shadow.extract<ShadowWindowManagerImpl>(wm).views
    private fun params(v: View) = v.layoutParams as WindowManager.LayoutParams
    private fun idle() = shadowOf(Looper.getMainLooper()).idle()
    private fun texts(v: View): List<String> = when (v) {
        is TextView -> if (v.visibility == View.VISIBLE) listOf(v.text.toString()) else emptyList()
        is ViewGroup -> (0 until v.childCount).flatMap { texts(v.getChildAt(it)) }
        else -> emptyList()
    }
    private fun touchable(v: View) = params(v).flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE == 0
    private fun fullScreen(v: View) = params(v).width == WindowManager.LayoutParams.MATCH_PARENT

    @Test fun fullFrostShowsCardOverAppAndLetsTouchesThrough() {
        overlay.animateTo(1f, "Instagram is frozen", "Take a walk: 133 steps unlocks 100 m of scrolling.", 0, 3)
        idle()
        val w = windows()
        assertEquals("frost + card", 2, w.size)
        val frost = w.single { fullScreen(it) }
        val card = w.single { !fullScreen(it) }
        assertTrue("frost must not take touches", !touchable(frost))
        assertEquals(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY, params(frost).type)
        assertTrue("card takes touches (its buttons)", touchable(card))
        assertTrue("touches outside the card go to the app",
            params(card).flags and WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL != 0)
        assertEquals(listOf("DoomWalk", "Instagram is frozen", "Take a walk: 133 steps unlocks 100 m of scrolling.", "Use pass (3)", "Leave app"), texts(card))
        assertTrue("card narrower than the screen", params(card).width > 0)
    }

    @Test fun lightFrostStillExplainsItself() {
        overlay.animateTo(0.1f, "Take a walk first", "You're out of earned scrolling. 133 steps unlocks 100 m.", 0, 0)
        idle()
        val card = windows().single { !fullScreen(it) }
        assertEquals(listOf("DoomWalk", "Take a walk first", "You're out of earned scrolling. 133 steps unlocks 100 m.", "Leave app"), texts(card))
    }

    @Test fun frostClearsCompletely() {
        overlay.animateTo(1f, "a", "b", 0, 1)
        idle()
        overlay.animateTo(0f, null, null, 0, 1)
        idle()
        assertEquals("no windows left behind", 0, windows().size)
    }

    @Test fun noticeIsUntouchableAndGoesAway() {
        overlay.notice("Free scrolling used up", "Anything you scroll in Instagram now has to be walked off.", 4000)
        idle()
        val b = windows().single()
        assertTrue(!touchable(b))
        assertEquals(listOf("Free scrolling used up", "Anything you scroll in Instagram now has to be walked off."), texts(b))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(5))
        assertEquals(0, windows().size)
    }

    @Test fun passCountsDownOverTheAppAndGoesAway() {
        val start = System.currentTimeMillis()
        overlay.animateTo(0f, null, null, 0, 0) // a pass lifts the frost
        overlay.showPass(start + 5 * 60_000)
        idle()
        val p = windows().single()
        assertTrue("pill takes touches (opens the app)", touchable(p))
        assertTrue(overlay.passText == "Pass: 5:00 left" || overlay.passText == "Pass: 4:59 left")
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(61))
        assertTrue(overlay.passText!!.startsWith("Pass: 3:5"))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(5))
        assertEquals("gone when the pass ends", 0, windows().size)
    }
}
