package com.xora.cattleshield

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.xora.cattleshield/muzzle_camera"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Register the native CameraX platform view
        flutterEngine.platformViewsController.registry
            .registerViewFactory(
                "muzzle-camera-view",
                MuzzleCameraViewFactory(this, channel)
            )
    }
}
