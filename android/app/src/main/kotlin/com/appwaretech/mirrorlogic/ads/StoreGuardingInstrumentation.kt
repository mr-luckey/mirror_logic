package com.appwaretech.mirrorlogic.ads

import android.app.Activity
import android.app.Instrumentation
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.IBinder
import android.os.UserHandle
import android.util.Log

/**
 * Delegates every Activity lifecycle call to the real [Instrumentation], and
 * swallows Play Store VIEW intents that Unity fires as the ad closes.
 */
class StoreGuardingInstrumentation(
    private val base: Instrumentation,
) : Instrumentation() {

    companion object {
        private const val TAG = "AdStoreGuard"
    }

    @Suppress("unused")
    fun execStartActivity(
        who: Context?,
        contextThread: IBinder?,
        token: IBinder?,
        target: Activity?,
        intent: Intent?,
        requestCode: Int,
        options: Bundle?,
    ): ActivityResult? = gate(intent) {
        invokeOriginal(
            arrayOf(
                Context::class.java,
                IBinder::class.java,
                IBinder::class.java,
                Activity::class.java,
                Intent::class.java,
                Int::class.javaPrimitiveType!!,
                Bundle::class.java,
            ),
            arrayOf(who, contextThread, token, target, intent, requestCode, options),
        )
    }

    @Suppress("unused")
    fun execStartActivity(
        who: Context?,
        contextThread: IBinder?,
        token: IBinder?,
        target: String?,
        intent: Intent?,
        requestCode: Int,
        options: Bundle?,
    ): ActivityResult? = gate(intent) {
        invokeOriginal(
            arrayOf(
                Context::class.java,
                IBinder::class.java,
                IBinder::class.java,
                String::class.java,
                Intent::class.java,
                Int::class.javaPrimitiveType!!,
                Bundle::class.java,
            ),
            arrayOf(who, contextThread, token, target, intent, requestCode, options),
        )
    }

    @Suppress("unused")
    fun execStartActivity(
        who: Context?,
        contextThread: IBinder?,
        token: IBinder?,
        target: Activity?,
        intent: Intent?,
        requestCode: Int,
        options: Bundle?,
        user: UserHandle?,
    ): ActivityResult? = gate(intent) {
        invokeOriginal(
            arrayOf(
                Context::class.java,
                IBinder::class.java,
                IBinder::class.java,
                Activity::class.java,
                Intent::class.java,
                Int::class.javaPrimitiveType!!,
                Bundle::class.java,
                UserHandle::class.java,
            ),
            arrayOf(who, contextThread, token, target, intent, requestCode, options, user),
        )
    }

    private inline fun gate(
        intent: Intent?,
        launch: () -> ActivityResult?,
    ): ActivityResult? {
        if (intent != null && AdStoreGuard.shouldBlock(intent)) {
            Log.w(TAG, "Blocked Play Store launch from ad: $intent")
            return ActivityResult(Activity.RESULT_CANCELED, null)
        }
        return launch()
    }

    private fun invokeOriginal(
        parameterTypes: Array<Class<*>>,
        args: Array<Any?>,
    ): ActivityResult? {
        return try {
            val method = Instrumentation::class.java.getDeclaredMethod(
                "execStartActivity",
                *parameterTypes,
            )
            method.isAccessible = true
            method.invoke(base, *args) as ActivityResult?
        } catch (error: Throwable) {
            Log.e(TAG, "execStartActivity failed", error)
            null
        }
    }

    override fun callActivityOnCreate(activity: Activity, icicle: Bundle?) {
        base.callActivityOnCreate(activity, icicle)
    }

    override fun callActivityOnDestroy(activity: Activity) {
        base.callActivityOnDestroy(activity)
    }

    override fun callActivityOnRestoreInstanceState(
        activity: Activity,
        savedInstanceState: Bundle,
    ) {
        base.callActivityOnRestoreInstanceState(activity, savedInstanceState)
    }

    override fun callActivityOnPostCreate(activity: Activity, savedInstanceState: Bundle?) {
        base.callActivityOnPostCreate(activity, savedInstanceState)
    }

    override fun callActivityOnNewIntent(activity: Activity, intent: Intent) {
        base.callActivityOnNewIntent(activity, intent)
    }

    override fun callActivityOnStart(activity: Activity) {
        base.callActivityOnStart(activity)
    }

    override fun callActivityOnRestart(activity: Activity) {
        base.callActivityOnRestart(activity)
    }

    override fun callActivityOnResume(activity: Activity) {
        base.callActivityOnResume(activity)
    }

    override fun callActivityOnStop(activity: Activity) {
        base.callActivityOnStop(activity)
    }

    override fun callActivityOnPause(activity: Activity) {
        base.callActivityOnPause(activity)
    }

    override fun callActivityOnUserLeaving(activity: Activity) {
        base.callActivityOnUserLeaving(activity)
    }

    override fun callActivityOnSaveInstanceState(activity: Activity, outState: Bundle) {
        base.callActivityOnSaveInstanceState(activity, outState)
    }

    override fun onException(obj: Any?, e: Throwable?): Boolean = base.onException(obj, e)
}
