package com.xora.cattleshield

import android.graphics.BitmapFactory
import android.graphics.RectF
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.xora.cattleshield/muzzle_camera"
    private var yoloDetector: YoloDetector? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize YOLO detector
        yoloDetector = YoloDetector(this)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "detectMuzzle" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val species = call.argument<String>("species") ?: "cow"

                    if (imagePath == null) {
                        result.error("INVALID", "imagePath is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val bitmap = BitmapFactory.decodeFile(imagePath)
                        if (bitmap == null) {
                            result.error("DECODE_ERROR", "Failed to decode image", null)
                            return@setMethodCallHandler
                        }

                        // Define guide zone based on species (normalized 0-1)
                        val guideRect = if (species == "mule") {
                            RectF(0.15f, 0.25f, 0.85f, 0.65f)
                        } else {
                            RectF(0.2f, 0.28f, 0.8f, 0.62f)
                        }

                        val detection = yoloDetector?.detectMuzzle(bitmap, guideRect)
                        bitmap.recycle()

                        if (detection != null) {
                            result.success(mapOf(
                                "detected" to detection.detected,
                                "confidence" to detection.confidence.toDouble(),
                                "message" to detection.message,
                                "className" to (detection.detection?.className ?: ""),
                                "classId" to (detection.detection?.classId ?: -1)
                            ))
                        } else {
                            result.success(mapOf(
                                "detected" to false,
                                "confidence" to 0.0,
                                "message" to "Detector not ready",
                                "className" to "",
                                "classId" to -1
                            ))
                        }
                    } catch (e: Exception) {
                        result.error("DETECTION_ERROR", e.message, null)
                    }
                }
                "detect" -> {
                    val imagePath = call.argument<String>("imagePath")

                    if (imagePath == null) {
                        result.error("INVALID", "imagePath is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val bitmap = BitmapFactory.decodeFile(imagePath)
                        if (bitmap == null) {
                            result.error("DECODE_ERROR", "Failed to decode image", null)
                            return@setMethodCallHandler
                        }

                        val detections = yoloDetector?.detect(bitmap) ?: emptyList()
                        bitmap.recycle()

                        val results = detections.map { d ->
                            mapOf(
                                "className" to d.className,
                                "confidence" to d.confidence.toDouble(),
                                "classId" to d.classId,
                                "x1" to d.box.left.toDouble(),
                                "y1" to d.box.top.toDouble(),
                                "x2" to d.box.right.toDouble(),
                                "y2" to d.box.bottom.toDouble()
                            )
                        }

                        result.success(results)
                    } catch (e: Exception) {
                        result.error("DETECTION_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Register the native CameraX platform view
        flutterEngine.platformViewsController.registry
            .registerViewFactory(
                "muzzle-camera-view",
                MuzzleCameraViewFactory(this, channel)
            )
    }

    override fun onDestroy() {
        yoloDetector?.close()
        super.onDestroy()
    }
}
