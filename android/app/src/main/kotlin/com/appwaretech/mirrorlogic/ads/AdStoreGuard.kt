package com.appwaretech.mirrorlogic.ads

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.SystemClock
import android.util.Log
import java.lang.reflect.Field

/**
 * Stops Unity full-screen ads from dumping the player into the Play Store
 * when the ad closes. AdMob interstitials / rewarded stay in-process on
 * dismiss; Unity's test and install creatives often fire a store VIEW intent
 * from the ad activity as it finishes, even when the player only tapped X.
 *
 * Rate Us still works: those intents come from [com.appwaretech.mirrorlogic.MainActivity],
 * which is never hooked.
 */
object AdStoreGuard {
    private const val TAG = "AdStoreGuard"
    private const val DISMISS_GRACE_MS = 2_500L

    @Volatile
    var adVisible: Boolean = false
        private set

    @Volatile
    private var dismissAtElapsed: Long = 0L

    fun onAdStarted() {
        adVisible = true
        dismissAtElapsed = 0L
        Log.d(TAG, "Full-screen ad started")
    }

    fun onAdDismissed() {
        adVisible = false
        dismissAtElapsed = SystemClock.elapsedRealtime()
        Log.d(TAG, "Full-screen ad dismissed")
    }

    fun isUnityAdActivity(activity: Activity): Boolean {
        val name = activity.javaClass.name
        return name.startsWith("com.unity3d.")
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
        if (intent.action == Intent.ACTION_VIEW && data.contains("itunes.apple.com")) {
            return true
        }
        return false
    }

    fun shouldBlock(intent: Intent): Boolean {
        if (!isStoreIntent(intent)) return false
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
