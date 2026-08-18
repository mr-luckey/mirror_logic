package com.appwaretech.mirrorlogic

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.appwaretech.mirrorlogic.ads.AdStoreGuard
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "AdStoreGuard"
        private const val LIFECYCLE_CHANNEL = "ad_lifecycle"
    }

    private var metaAdsManager: MetaAdsManager? = null
    private val adTaskGuard = AdTaskGuard()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val manager = MetaAdsManager(this)
        metaAdsManager = manager

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "meta_ads"
        ).setMethodCallHandler(manager)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LIFECYCLE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "adStarted" -> AdStoreGuard.onAdStarted()
                "adDismissed" -> AdStoreGuard.onAdDismissed()
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }
            result.success(null)
        }

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "meta_banner_ad",
            MetaBannerAdFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AdStoreGuard.hookActivityThread()
        application.registerActivityLifecycleCallbacks(adTaskGuard)
    }

    override fun onDestroy() {
        application.unregisterActivityLifecycleCallbacks(adTaskGuard)
        metaAdsManager?.dispose()
        metaAdsManager = null
        super.onDestroy()
    }

    private fun bringGameToForeground() {
        Log.d(TAG, "Returning to game after full-screen ad")
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
        )
    }

    private inner class AdTaskGuard : Application.ActivityLifecycleCallbacks {
        override fun onActivityPreCreated(activity: Activity, savedInstanceState: Bundle?) {
            AdStoreGuard.hookActivity(activity)
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
            AdStoreGuard.hookActivity(activity)
        }

        override fun onActivityStarted(activity: Activity) {
            AdStoreGuard.hookActivity(activity)
        }

        override fun onActivityResumed(activity: Activity) {
            if (AdStoreGuard.isUnityAdActivity(activity)) {
                AdStoreGuard.onAdStarted()
            }
        }

        override fun onActivityPaused(activity: Activity) {}

        override fun onActivityStopped(activity: Activity) {}

        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

        override fun onActivityDestroyed(activity: Activity) {
            if (!AdStoreGuard.isUnityAdActivity(activity)) return
            AdStoreGuard.onAdDismissed()
            bringGameToForeground()
        }
    }
}
