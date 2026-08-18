package com.appwaretech.mirrorlogic

import android.app.Activity
import android.util.Log
import com.facebook.ads.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Manages Meta Audience Network full-screen ads (interstitial + rewarded)
 * and SDK initialization. Exposes a [MethodChannel.MethodCallHandler] that
 * the Flutter layer talks to over the `meta_ads` channel.
 */
class MetaAdsManager(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "MetaAds"
    }

    private var initialized = false

    // Interstitial state — at most one loaded at a time.
    private var interstitialAd: InterstitialAd? = null
    private var interstitialReady = false
    private var interstitialLoading = false

    // Rewarded state — at most one loaded at a time.
    private var rewardedAd: RewardedVideoAd? = null
    private var rewardedReady = false
    private var rewardedLoading = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "loadInterstitial" -> loadInterstitial(call, result)
            "showInterstitial" -> showInterstitial(result)
            "isInterstitialReady" -> result.success(interstitialReady)
            "disposeInterstitial" -> {
                destroyInterstitial()
                result.success(null)
            }
            "loadRewarded" -> loadRewarded(call, result)
            "showRewarded" -> showRewarded(result)
            "isRewardedReady" -> result.success(rewardedReady)
            "disposeRewarded" -> {
                destroyRewarded()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // -----------------------------------------------------------------------
    // Initialization
    // -----------------------------------------------------------------------

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        if (initialized) {
            result.success(true)
            return
        }
        val testMode = call.argument<Boolean>("testMode") ?: false
        try {
            if (testMode) {
                AdSettings.setTestMode(true)
            }
            AudienceNetworkAds.buildInitSettings(activity)
                .withInitListener { initResult ->
                    Log.d(TAG, "Meta SDK init: ${initResult.message}")
                }
                .initialize()
            initialized = true
            Log.d(TAG, "Meta Audience Network initialized (testMode=$testMode)")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Meta SDK init failed", e)
            result.success(false)
        }
    }

    // -----------------------------------------------------------------------
    // Interstitial
    // -----------------------------------------------------------------------

    private fun loadInterstitial(call: MethodCall, result: MethodChannel.Result) {
        val placementId = call.argument<String>("placementId")
        if (placementId == null) {
            result.error("INVALID_ARG", "placementId required", null)
            return
        }
        if (interstitialReady || interstitialLoading) {
            result.success(interstitialReady)
            return
        }
        interstitialLoading = true
        destroyInterstitial()

        val ad = InterstitialAd(activity, placementId)
        interstitialAd = ad

        val listener = object : InterstitialAdListener {
            override fun onAdLoaded(p0: Ad) {
                Log.d(TAG, "Interstitial loaded: $placementId")
                interstitialReady = true
                interstitialLoading = false
            }
            override fun onError(p0: Ad?, error: AdError) {
                Log.d(TAG, "Interstitial load failed: ${error.errorCode} ${error.errorMessage}")
                interstitialReady = false
                interstitialLoading = false
            }
            override fun onInterstitialDisplayed(p0: Ad) {
                Log.d(TAG, "Interstitial displayed")
            }
            override fun onInterstitialDismissed(p0: Ad) {
                Log.d(TAG, "Interstitial dismissed")
                interstitialReady = false
            }
            override fun onAdClicked(p0: Ad) {
                Log.d(TAG, "Interstitial clicked")
            }
            override fun onLoggingImpression(p0: Ad) {
                Log.d(TAG, "Interstitial impression logged")
            }
        }

        ad.loadAd(ad.buildLoadAdConfig().withAdListener(listener).build())
        result.success(false)
    }

    private fun showInterstitial(result: MethodChannel.Result) {
        val ad = interstitialAd
        if (ad == null || !interstitialReady || !ad.isAdLoaded) {
            result.success(mapOf("shown" to false, "dismissed" to true))
            return
        }
        interstitialReady = false

        val oldListener = object : InterstitialAdListener {
            override fun onAdLoaded(p0: Ad) {}
            override fun onError(p0: Ad?, error: AdError) {
                Log.d(TAG, "Interstitial show error: ${error.errorCode} ${error.errorMessage}")
                result.success(mapOf("shown" to false, "dismissed" to true))
                destroyInterstitial()
            }
            override fun onInterstitialDisplayed(p0: Ad) {}
            override fun onInterstitialDismissed(p0: Ad) {
                result.success(mapOf("shown" to true, "dismissed" to true))
                destroyInterstitial()
            }
            override fun onAdClicked(p0: Ad) {}
            override fun onLoggingImpression(p0: Ad) {}
        }

        // Re-attach listener for show-phase callbacks.
        ad.loadAd(ad.buildLoadAdConfig().withAdListener(oldListener).build())
        // The ad is already loaded, so we show immediately.
        ad.show()
    }

    private fun destroyInterstitial() {
        interstitialAd?.destroy()
        interstitialAd = null
        interstitialReady = false
        interstitialLoading = false
    }

    // -----------------------------------------------------------------------
    // Rewarded
    // -----------------------------------------------------------------------

    private fun loadRewarded(call: MethodCall, result: MethodChannel.Result) {
        val placementId = call.argument<String>("placementId")
        if (placementId == null) {
            result.error("INVALID_ARG", "placementId required", null)
            return
        }
        if (rewardedReady || rewardedLoading) {
            result.success(rewardedReady)
            return
        }
        rewardedLoading = true
        destroyRewarded()

        val ad = RewardedVideoAd(activity, placementId)
        rewardedAd = ad

        val listener = object : RewardedVideoAdListener {
            override fun onAdLoaded(p0: Ad) {
                Log.d(TAG, "Rewarded loaded: $placementId")
                rewardedReady = true
                rewardedLoading = false
            }
            override fun onError(p0: Ad?, error: AdError) {
                Log.d(TAG, "Rewarded load failed: ${error.errorCode} ${error.errorMessage}")
                rewardedReady = false
                rewardedLoading = false
            }
            override fun onRewardedVideoCompleted() {
                Log.d(TAG, "Rewarded video completed (reward earned)")
            }
            override fun onRewardedVideoClosed() {
                Log.d(TAG, "Rewarded video closed")
                rewardedReady = false
            }
            override fun onAdClicked(p0: Ad) {
                Log.d(TAG, "Rewarded clicked")
            }
            override fun onLoggingImpression(p0: Ad) {
                Log.d(TAG, "Rewarded impression logged")
            }
        }

        ad.loadAd(ad.buildLoadAdConfig().withAdListener(listener).build())
        result.success(false)
    }

    private fun showRewarded(result: MethodChannel.Result) {
        val ad = rewardedAd
        if (ad == null || !rewardedReady || !ad.isAdLoaded) {
            result.success(mapOf("shown" to false, "earned" to false, "dismissed" to true))
            return
        }
        rewardedReady = false
        var earned = false

        val listener = object : RewardedVideoAdListener {
            override fun onAdLoaded(p0: Ad) {}
            override fun onError(p0: Ad?, error: AdError) {
                Log.d(TAG, "Rewarded show error: ${error.errorCode} ${error.errorMessage}")
                result.success(mapOf("shown" to false, "earned" to false, "dismissed" to true))
                destroyRewarded()
            }
            override fun onRewardedVideoCompleted() {
                earned = true
            }
            override fun onRewardedVideoClosed() {
                result.success(mapOf("shown" to true, "earned" to earned, "dismissed" to true))
                destroyRewarded()
            }
            override fun onAdClicked(p0: Ad) {}
            override fun onLoggingImpression(p0: Ad) {}
        }

        ad.loadAd(ad.buildLoadAdConfig().withAdListener(listener).build())
        ad.show()
    }

    private fun destroyRewarded() {
        rewardedAd?.destroy()
        rewardedAd = null
        rewardedReady = false
        rewardedLoading = false
    }

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------

    fun dispose() {
        destroyInterstitial()
        destroyRewarded()
    }
}
