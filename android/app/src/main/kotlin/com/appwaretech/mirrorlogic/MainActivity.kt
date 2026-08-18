package com.appwaretech.mirrorlogic

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var metaAdsManager: MetaAdsManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val manager = MetaAdsManager(this)
        metaAdsManager = manager

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "meta_ads"
        ).setMethodCallHandler(manager)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "meta_banner_ad",
            MetaBannerAdFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
    }

    override fun onDestroy() {
        metaAdsManager?.dispose()
        metaAdsManager = null
        super.onDestroy()
    }
}
