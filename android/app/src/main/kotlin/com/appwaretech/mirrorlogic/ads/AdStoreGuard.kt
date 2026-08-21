package com.appwaretech.mirrorlogic.ads

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.SystemClock
import android.util.Log
import java.lang.reflect.Field

/**
 * Keeps the player in-app when a Unity interstitial/rewarded **closes**,
 * without blocking a real install CTA.
 *
 * Unity often fires a Play Store VIEW as the ad activity finishes even when
 * the user only tapped X. We block those auto-redirects. A genuine click
 * (onClick well before dismiss, or while the ad is still up after a real
 * tap) is allowed through so network / Play click-through policy stays intact.
 *
 * Rate Us from [com.appwaretech.mirrorlogic.MainActivity] is never blocked.
 */
object AdStoreGuard {
    private const val TAG = "AdStoreGuard"
    private const val DISMISS_GRACE_MS = 2_000L
    /** Fake Unity "click" on close usually lands within this of dismiss. */
    private const val GENUINE_CLICK_LEAD_MS = 450L

    @Volatile
    var adVisible: Boolean = false
        private set

    @Volatile
    private var clickAtElapsed: Long = 0L

    @Volatile
    private var dismissAtElapsed: Long = 0L

    fun onAdStarted() {
        adVisible = true
        clickAtElapsed = 0L
        dismissAtElapsed = 0L
        Log.d(TAG, "Full-screen ad started")
    }

    fun onAdDismissed() {
        adVisible = false
        dismissAtElapsed = SystemClock.elapsedRealtime()
        Log.d(TAG, "Full-screen ad dismissed")
    }

    fun onAdClicked() {
        clickAtElapsed = SystemClock.elapsedRealtime()
        Log.d(TAG, "Ad click reported")
    }

    /**
     * True when the player actually tapped the creative (not Unity's
     * close-frame click spam).
     */
    fun isGenuineClickThrough(): Boolean {
        val clickAt = clickAtElapsed
        if (clickAt == 0L) return false
        val now = SystemClock.elapsedRealtime()
        val dismissAt = dismissAtElapsed
        return if (dismissAt == 0L) {
            // Mid-show: require the click to have aged — same-frame "click" on
            // close is treated as auto-redirect, not a CTA.
            now - clickAt >= GENUINE_CLICK_LEAD_MS
        } else {
            dismissAt - clickAt >= GENUINE_CLICK_LEAD_MS
        }
    }

    fun consumeShouldReclaimGame(): Boolean {
        val reclaim = !isGenuineClickThrough()
        clickAtElapsed = 0L
        return reclaim
    }

    fun isUnityAdActivity(activity: Activity): Boolean {
        return activity.javaClass.name.startsWith("com.unity3d.")
    }

    fun isOurGameActivity(context: Any?): Boolean {
        val name = context?.javaClass?.name ?: return false
        return name == "com.appwaretech.mirrorlogic.MainActivity"
    }

    fun isStoreIntent(intent: Intent): Boolean {
        val data = intent.dataString?.lowercase().orEmpty()
        val pkg = intent.`package`?.lowercase().orEmpty()
        val component = intent.component?.packageName?.lowercase().orEmpty()
        if (pkg == "com.android.vending" || component == "com.android.vending") {
            return true
        }
        if (data.startsWith("market:")) return true
        if (data.contains("play.google.com")) return true
        if (data.contains("play.app.goo.gl")) return true
        return false
    }

    fun shouldBlock(intent: Intent, who: Any? = null): Boolean {
        if (!isStoreIntent(intent)) return false
        // About / Settings Rate Us must always work.
        if (isOurGameActivity(who)) return false
        if (isGenuineClickThrough()) return false
        if (adVisible) return true
        val dismissAt = dismissAtElapsed
        if (dismissAt == 0L) return false
        return SystemClock.elapsedRealtime() - dismissAt < DISMISS_GRACE_MS
    }

    fun hookActivityThread() {
        try {
            val cls = Class.forName("android.app.ActivityThread")
            val current = cls.getDeclaredMethod("currentActivityThread").invoke(null)
            val field = cls.getDeclaredField("mInstrumentation")
            field.isAccessible = true
            val currentInstr = field.get(current) as? Instrumentation ?: return
            if (currentInstr is StoreGuardingInstrumentation) return
            field.set(current, StoreGuardingInstrumentation(currentInstr))
            Log.d(TAG, "Hooked process startActivity")
        } catch (error: Throwable) {
            Log.w(TAG, "Could not hook process startActivity", error)
        }
    }

    fun hookActivity(activity: Activity) {
        if (!isUnityAdActivity(activity)) return
        try {
            val field = instrumentationField() ?: return
            val current = field.get(activity) as? Instrumentation ?: return
            if (current is StoreGuardingInstrumentation) return
            field.set(activity, StoreGuardingInstrumentation(current))
            Log.d(TAG, "Hooked startActivity on ${activity.javaClass.name}")
        } catch (error: Throwable) {
            Log.w(TAG, "Could not hook ${activity.javaClass.name}", error)
        }
    }

    private fun instrumentationField(): Field? {
        return try {
            Activity::class.java.getDeclaredField("mInstrumentation").apply {
                isAccessible = true
            }
        } catch (_: Throwable) {
            null
        }
    }
}
