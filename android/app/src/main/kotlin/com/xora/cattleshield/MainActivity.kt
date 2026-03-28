package com.xora.cattleshield

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.xora.cattleshield/muzzle_camera"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Simple method channel — YOLOv8 detection handled server-side for now
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "detectMuzzle" -> {
                    // Return "not available" — detection done server-side via ONNX
                    result.success(mapOf(
                        "detected" to true,
                        "confidence" to 0.0,
                        "message" to "Server-side detection",
                        "className" to "",
                        "classId" to -1
                    ))
                }
                "detect" -> {
                    result.success(emptyList<Map<String, Any>>())
                }
                else -> result.notImplemented()
            }
        }
    }
}
