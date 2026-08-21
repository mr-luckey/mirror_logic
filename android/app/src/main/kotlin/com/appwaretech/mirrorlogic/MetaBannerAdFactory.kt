package com.appwaretech.mirrorlogic

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.facebook.ads.Ad
import com.facebook.ads.AdError
import com.facebook.ads.AdListener
import com.facebook.ads.AdSize
import com.facebook.ads.AdView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Meta banner PlatformView. Uses the host [Activity] — Audience Network
 * banners often fail silently when created with a non-Activity context.
 */
class MetaBannerAdFactory(
    private val activity: Activity,
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return MetaBannerPlatformView(activity, viewId, params, messenger)
    }
}

private class MetaBannerPlatformView(
    activity: Activity,
    viewId: Int,
    params: Map<*, *>,
    messenger: BinaryMessenger,
) : PlatformView {

    companion object {
        private const val TAG = "MetaAds"
    }

    private val channel = MethodChannel(messenger, "meta_banner_ad_$viewId")
    private val container = FrameLayout(activity)
    private var adView: AdView? = null

    init {
        val placementId = params["placementId"] as? String ?: ""
        val heightDp = (params["height"] as? Number)?.toInt() ?: 50

        val adSize = when (heightDp) {
            250 -> AdSize.RECTANGLE_HEIGHT_250
            90 -> AdSize.BANNER_HEIGHT_90
            else -> AdSize.BANNER_HEIGHT_50
        }

        if (placementId.isBlank()) {
            Log.e(TAG, "Banner missing placementId")
            channel.invokeMethod(
                "onError",
                mapOf("code" to -1, "message" to "missing placementId"),
            )
        } else {
            val ad = AdView(activity, placementId, adSize)
            adView = ad
            container.addView(
                ad,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                ),
            )

            val listener = object : AdListener {
                override fun onAdLoaded(p0: Ad) {
                    Log.d(TAG, "Banner loaded: $placementId")
                    channel.invokeMethod("onLoaded", null)
                }

                override fun onError(p0: Ad?, error: AdError) {
                    Log.d(
                        TAG,
                        "Banner failed: ${error.errorCode} ${error.errorMessage}",
                    )
                    channel.invokeMethod(
                        "onError",
                        mapOf(
                            "code" to error.errorCode,
                            "message" to error.errorMessage,
                        ),
                    )
                }

                override fun onAdClicked(p0: Ad) {
                    Log.d(TAG, "Banner clicked")
                }

                override fun onLoggingImpression(p0: Ad) {
                    Log.d(TAG, "Banner impression logged")
                }
            }

            ad.loadAd(ad.buildLoadAdConfig().withAdListener(listener).build())
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        adView?.destroy()
        adView = null
    }
}
