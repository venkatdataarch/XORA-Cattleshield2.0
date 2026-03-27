package com.xora.cattleshield

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.*
import android.util.Size
import android.view.View
import android.widget.FrameLayout
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors
import kotlin.math.abs

/**
 * Native Android CameraX view with muzzle detection overlay.
 * Uses YOLOv8 ONNX model for real-time animal detection.
 */
class MuzzleCameraView(
    private val context: Context,
    private val channel: MethodChannel,
    private val species: String // "cow" or "mule"
) : FrameLayout(context) {

    private val previewView: PreviewView
    private val overlayView: MuzzleOverlayView
    private var detector: YoloDetector? = null
    private var imageCapture: ImageCapture? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private val analysisExecutor = Executors.newSingleThreadExecutor()

    // Auto-capture state
    private var stableFrameCount = 0
    private var lastDetectionTime = 0L
    private var isCapturing = false
    private val STABLE_FRAMES_REQUIRED = 12 // ~2 seconds at 6 fps analysis
    private val STABLE_TIMEOUT_MS = 3000L

    init {
        // Camera preview
        previewView = PreviewView(context).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
        addView(previewView)

        // Muzzle overlay
        overlayView = MuzzleOverlayView(context, species)
        addView(overlayView)

        // Initialize detector
        try {
            detector = YoloDetector(context)
        } catch (e: Exception) {
            e.printStackTrace()
            channel.invokeMethod("onError", "Failed to load YOLOv8 model: ${e.message}")
        }
    }

    fun startCamera(lifecycleOwner: LifecycleOwner) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()

                // Preview
                val preview = Preview.Builder()
                    .setTargetResolution(Size(1280, 720))
                    .build()
                    .also { it.surfaceProvider = previewView.surfaceProvider }

                // Image capture
                imageCapture = ImageCapture.Builder()
                    .setTargetResolution(Size(1920, 1080))
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                    .build()

                // Image analysis for YOLOv8 detection
                val imageAnalysis = ImageAnalysis.Builder()
                    .setTargetResolution(Size(640, 480))
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .build()

                imageAnalysis.setAnalyzer(analysisExecutor) { imageProxy ->
                    analyzeFrame(imageProxy)
                }

                // Select back camera
                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                // Unbind all and rebind
                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    preview,
                    imageCapture,
                    imageAnalysis
                )

                // Notify Flutter camera is ready
                post { channel.invokeMethod("onCameraReady", null) }

            } catch (e: Exception) {
                e.printStackTrace()
                post { channel.invokeMethod("onError", "Camera init failed: ${e.message}") }
            }
        }, ContextCompat.getMainExecutor(context))
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun analyzeFrame(imageProxy: ImageProxy) {
        if (isCapturing) {
            imageProxy.close()
            return
        }

        try {
            // Convert ImageProxy to Bitmap
            val bitmap = imageProxyToBitmap(imageProxy)
            if (bitmap != null) {
                // Define guide zone (center area where muzzle should be)
                val guideRect = getGuideRect()

                // Run YOLOv8 detection
                val result = detector?.detectMuzzle(bitmap, guideRect)

                if (result != null) {
                    post {
                        // Update overlay with detection info
                        overlayView.updateDetection(
                            result.detected,
                            result.confidence,
                            result.message,
                            result.detection?.box
                        )

                        // Send detection status to Flutter
                        channel.invokeMethod("onDetection", mapOf(
                            "detected" to result.detected,
                            "confidence" to result.confidence.toDouble(),
                            "message" to result.message,
                            "className" to (result.detection?.className ?: "")
                        ))

                        // Auto-capture logic
                        if (result.detected && result.confidence > 60f) {
                            stableFrameCount++
                            lastDetectionTime = System.currentTimeMillis()

                            if (stableFrameCount >= STABLE_FRAMES_REQUIRED) {
                                autoCapture()
                            }
                        } else {
                            // Reset if detection lost for too long
                            if (System.currentTimeMillis() - lastDetectionTime > STABLE_TIMEOUT_MS) {
                                stableFrameCount = 0
                            }
                        }
                    }
                }

                bitmap.recycle()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            imageProxy.close()
        }
    }

    private fun imageProxyToBitmap(imageProxy: ImageProxy): Bitmap? {
        return try {
            val planes = imageProxy.planes
            val buffer = planes[0].buffer
            val pixelStride = planes[0].pixelStride
            val rowStride = planes[0].rowStride
            val rowPadding = rowStride - pixelStride * imageProxy.width

            val bitmap = Bitmap.createBitmap(
                imageProxy.width + rowPadding / pixelStride,
                imageProxy.height,
                Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)

            // Crop to actual size
            Bitmap.createBitmap(bitmap, 0, 0, imageProxy.width, imageProxy.height)
        } catch (e: Exception) {
            null
        }
    }

    private fun getGuideRect(): RectF {
        return if (species == "mule") {
            // Wider rectangle for mule nose+lip
            RectF(0.2f, 0.25f, 0.8f, 0.75f)
        } else {
            // Oval area for cow muzzle
            RectF(0.25f, 0.3f, 0.75f, 0.7f)
        }
    }

    private fun autoCapture() {
        if (isCapturing) return
        capturePhoto()
    }

    fun capturePhoto() {
        if (isCapturing) return
        isCapturing = true

        val capture = imageCapture ?: run {
            isCapturing = false
            channel.invokeMethod("onError", "Camera not ready")
            return
        }

        // Generate filename with IST timestamp
        val istTimeZone = TimeZone.getTimeZone("Asia/Kolkata")
        val dateFormat = SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US)
        dateFormat.timeZone = istTimeZone
        val timestamp = dateFormat.format(Date())

        val dir = File(context.cacheDir, "muzzle_captures")
        dir.mkdirs()
        val file = File(dir, "muzzle_${species}_${timestamp}.jpg")

        val outputOptions = ImageCapture.OutputFileOptions.Builder(file).build()

        capture.takePicture(outputOptions, ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    // Calculate SHA-256 hash
                    val hash = calculateSHA256(file)

                    // IST timestamp
                    val istFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US)
                    istFormat.timeZone = istTimeZone
                    val istTimestamp = istFormat.format(Date())

                    // Send result to Flutter
                    channel.invokeMethod("onPhotoCaptured", mapOf(
                        "path" to file.absolutePath,
                        "timestamp" to istTimestamp,
                        "timezone" to "IST",
                        "sha256" to hash,
                        "species" to species
                    ))

                    isCapturing = false
                    stableFrameCount = 0

                    // Play capture sound/vibration via overlay
                    post { overlayView.showCaptureFlash() }
                }

                override fun onError(exception: ImageCaptureException) {
                    isCapturing = false
                    post { channel.invokeMethod("onError", "Capture failed: ${exception.message}") }
                }
            }
        )
    }

    private fun calculateSHA256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            var read: Int
            while (input.read(buffer).also { read = it } != -1) {
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    fun stopCamera() {
        cameraProvider?.unbindAll()
        analysisExecutor.shutdown()
        detector?.close()
    }
}

/**
 * Custom overlay view that draws the muzzle guide and detection visualization.
 */
class MuzzleOverlayView(context: Context, private val species: String) : View(context) {

    private var isDetected = false
    private var confidence = 0f
    private var message = "Position muzzle in the guide"
    private var detectionBox: RectF? = null
    private var showFlash = false

    private val guidePaint = Paint().apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 3f
        isAntiAlias = true
    }

    private val detectedPaint = Paint().apply {
        color = Color.parseColor("#2ECC71") // Green
        style = Paint.Style.STROKE
        strokeWidth = 4f
        isAntiAlias = true
    }

    private val boxPaint = Paint().apply {
        color = Color.parseColor("#FF9800") // Orange
        style = Paint.Style.STROKE
        strokeWidth = 3f
        isAntiAlias = true
    }

    private val textPaint = Paint().apply {
        color = Color.WHITE
        textSize = 42f
        isAntiAlias = true
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }

    private val subtextPaint = Paint().apply {
        color = Color.parseColor("#AAAAAA")
        textSize = 32f
        isAntiAlias = true
        textAlign = Paint.Align.CENTER
    }

    private val dimPaint = Paint().apply {
        color = Color.parseColor("#80000000") // Semi-transparent black
    }

    private val flashPaint = Paint().apply {
        color = Color.parseColor("#FFFFFF")
        alpha = 0
    }

    private val progressPaint = Paint().apply {
        color = Color.parseColor("#2ECC71")
        style = Paint.Style.FILL
        isAntiAlias = true
    }

    fun updateDetection(detected: Boolean, conf: Float, msg: String, box: RectF?) {
        isDetected = detected
        confidence = conf
        message = msg
        detectionBox = box

        guidePaint.color = if (detected && conf > 60f) Color.parseColor("#2ECC71") else Color.WHITE
        invalidate()
    }

    fun showCaptureFlash() {
        showFlash = true
        invalidate()

        // Hide flash after 200ms
        postDelayed({
            showFlash = false
            invalidate()
        }, 200)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()

        if (w == 0f || h == 0f) return

        // Draw semi-transparent overlay outside the guide zone
        val guideRect = if (species == "mule") {
            RectF(w * 0.15f, h * 0.25f, w * 0.85f, h * 0.65f)
        } else {
            RectF(w * 0.2f, h * 0.28f, w * 0.8f, h * 0.62f)
        }

        // Dim the area outside the guide
        canvas.save()
        val path = android.graphics.Path()
        if (species == "mule") {
            path.addRoundRect(guideRect, 40f, 40f, android.graphics.Path.Direction.CW)
        } else {
            path.addOval(guideRect, android.graphics.Path.Direction.CW)
        }
        path.setFillType(android.graphics.Path.FillType.INVERSE_EVEN_ODD)
        canvas.drawPath(path, dimPaint)
        canvas.restore()

        // Draw guide shape
        val paint = if (isDetected && confidence > 60f) detectedPaint else guidePaint
        if (species == "mule") {
            canvas.drawRoundRect(guideRect, 40f, 40f, paint)
        } else {
            canvas.drawOval(guideRect, paint)
        }

        // Draw corner markers
        drawCornerMarkers(canvas, guideRect, paint)

        // Draw detection bounding box
        detectionBox?.let { box ->
            val screenBox = RectF(
                box.left * w, box.top * h,
                box.right * w, box.bottom * h
            )
            canvas.drawRect(screenBox, boxPaint)
        }

        // Draw guide text at top
        val guideText = if (species == "mule") "Mule Nose + Lip Area" else "Cow Muzzle (Nasal Ridge)"
        canvas.drawText(guideText, w / 2, guideRect.top - 30f, textPaint)

        // Draw status message at bottom
        canvas.drawText(message, w / 2, guideRect.bottom + 60f, subtextPaint)

        // Draw confidence bar
        val barY = guideRect.bottom + 90f
        val barWidth = w * 0.6f
        val barX = (w - barWidth) / 2

        // Background bar
        canvas.drawRoundRect(
            barX, barY, barX + barWidth, barY + 8f,
            4f, 4f,
            Paint().apply { color = Color.parseColor("#333333") }
        )

        // Confidence fill
        val fillWidth = barWidth * (confidence / 100f).coerceIn(0f, 1f)
        val fillColor = when {
            confidence > 70f -> Color.parseColor("#2ECC71") // Green
            confidence > 40f -> Color.parseColor("#FF9800") // Orange
            else -> Color.parseColor("#F44336")              // Red
        }
        canvas.drawRoundRect(
            barX, barY, barX + fillWidth, barY + 8f,
            4f, 4f,
            Paint().apply { color = fillColor }
        )

        // Confidence text
        canvas.drawText(
            "${confidence.toInt()}%",
            w / 2,
            barY + 40f,
            Paint().apply {
                color = fillColor
                textSize = 36f
                textAlign = Paint.Align.CENTER
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                isAntiAlias = true
            }
        )

        // Capture flash
        if (showFlash) {
            flashPaint.alpha = 180
            canvas.drawRect(0f, 0f, w, h, flashPaint)
        }
    }

    private fun drawCornerMarkers(canvas: Canvas, rect: RectF, paint: Paint) {
        val cornerLength = 30f
        val strokePaint = Paint(paint).apply { strokeWidth = 5f }

        // Top-left
        canvas.drawLine(rect.left, rect.top, rect.left + cornerLength, rect.top, strokePaint)
        canvas.drawLine(rect.left, rect.top, rect.left, rect.top + cornerLength, strokePaint)

        // Top-right
        canvas.drawLine(rect.right - cornerLength, rect.top, rect.right, rect.top, strokePaint)
        canvas.drawLine(rect.right, rect.top, rect.right, rect.top + cornerLength, strokePaint)

        // Bottom-left
        canvas.drawLine(rect.left, rect.bottom, rect.left + cornerLength, rect.bottom, strokePaint)
        canvas.drawLine(rect.left, rect.bottom - cornerLength, rect.left, rect.bottom, strokePaint)

        // Bottom-right
        canvas.drawLine(rect.right - cornerLength, rect.bottom, rect.right, rect.bottom, strokePaint)
        canvas.drawLine(rect.right, rect.bottom - cornerLength, rect.right, rect.bottom, strokePaint)
    }
}
