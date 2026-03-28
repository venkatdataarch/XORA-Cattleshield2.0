package com.xora.cattleshield

import android.app.Activity
import android.content.Context
import android.view.View
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Platform View Factory that creates native CameraX views for Flutter.
 */
class MuzzleCameraViewFactory(
    private val activity: Activity,
    private val channel: MethodChannel
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val species = (params?.get("species") as? String) ?: "cow"

        return MuzzleCameraPlatformView(activity, channel, species)
    }
}

/**
 * Wraps MuzzleCameraView as a PlatformView for Flutter embedding.
 */
class MuzzleCameraPlatformView(
    private val activity: Activity,
    private val channel: MethodChannel,
    private val species: String
) : PlatformView {

    private val cameraView = MuzzleCameraView(activity, channel, species)

    init {
        // Start camera when view is created
        if (activity is LifecycleOwner) {
            cameraView.startCamera(activity)
        }

        // Listen for method calls from Flutter
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "capturePhoto" -> {
                    cameraView.capturePhoto()
                    result.success(null)
                }
                "stopCamera" -> {
                    cameraView.stopCamera()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = cameraView

    override fun dispose() {
        cameraView.stopCamera()
    }
}
