package com.indigolab.auto_podbor_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // RuStorePushMessaging.isConfigured: есть ли у сборки проект RuStore
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bitnebit/push")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "rustoreConfigured" -> result.success(BitNeBitApplication.isRuStorePushConfigured)
                    else -> result.notImplemented()
                }
            }
    }
}
