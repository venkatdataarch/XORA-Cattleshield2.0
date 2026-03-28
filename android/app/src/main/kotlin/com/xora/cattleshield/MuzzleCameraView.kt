package com.xora.cattleshield

import android.content.Context
import android.graphics.*
import android.util.Log
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
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors

/**
 * Native Android CameraX view with muzzle detection overlay.
 */
class MuzzleCameraView(
    private val context: Context,
    private val channel: MethodChannel,
    private val species: String
) : FrameLayout(context) {

    private val previewView: PreviewView
    private val overlayView: MuzzleOverlayView
    private var imageCapture: ImageCapture? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var isCapturing = false

    companion object {
        private const val TAG = "MuzzleCameraView"
    }

    init {
        // Camera preview - use COMPATIBLE mode for best device support
        previewView = PreviewView(context).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
        addView(previewView)

        // Muzzle overlay on top
        overlayView = MuzzleOverlayView(context, species)
        addView(overlayView)

        Log.d(TAG, "MuzzleCameraView created for species: $species")
    }

    fun startCamera(lifecycleOwner: LifecycleOwner) {
        Log.d(TAG, "Starting camera...")

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                Log.d(TAG, "Camera provider obtained")

                // Preview - simple setup
                val preview = Preview.Builder()
                    .build()
                    .also {
                        it.surfaceProvider = previewView.surfaceProvider
                        Log.d(TAG, "Surface provider set")
                    }

                // Image capture
                imageCapture = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                    .build()

                // Select back camera
                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                // Unbind all and rebind
                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    preview,
                    imageCapture
                )

                Log.d(TAG, "Camera bound to lifecycle successfully")

                // Notify Flutter camera is ready
                post {
                    channel.invokeMethod("onCameraReady", null)
                    overlayView.setCameraReady(true)
                }

            } catch (e: Exception) {
                Log.e(TAG, "Camera init failed", e)
                post {
                    channel.invokeMethod("onError", "Camera init failed: ${e.message}")
                }
            }
        }, ContextCompat.getMainExecutor(context))
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
                    Log.d(TAG, "Photo captured: ${file.absolutePath}")

                    // Calculate SHA-256 hash
                    val hash = calculateSHA256(file)

                    // IST timestamp
                    val istFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US)
                    istFormat.timeZone = istTimeZone
                    val istTimestamp = istFormat.format(Date())

                    // Show capture flash
                    overlayView.showCaptureFlash()

                    // Send result to Flutter
                    channel.invokeMethod("onPhotoCaptured", mapOf(
                        "path" to file.absolutePath,
                        "timestamp" to istTimestamp,
                        "timezone" to "IST",
                        "sha256" to hash,
                        "species" to species
                    ))

                    isCapturing = false
                }

                override fun onError(exception: ImageCaptureException) {
                    Log.e(TAG, "Capture failed", exception)
                    isCapturing = false
                    channel.invokeMethod("onError", "Capture failed: ${exception.message}")
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
    }
}

/**
 * Overlay view that draws the muzzle guide watermark.
 */
class MuzzleOverlayView(context: Context, private val species: String) : View(context) {

    private var cameraReady = false
    private var showFlash = false

    private val guidePaint = Paint().apply {
        color = Color.WHITE
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
        color = Color.parseColor("#60000000")
    }

    private val flashPaint = Paint().apply {
        color = Color.WHITE
        alpha = 0
    }

    fun setCameraReady(ready: Boolean) {
        cameraReady = ready
        invalidate()
    }

    fun showCaptureFlash() {
        showFlash = true
        invalidate()
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

        // Guide zone
        val guideRect = if (species == "mule") {
            RectF(w * 0.15f, h * 0.25f, w * 0.85f, h * 0.65f)
        } else {
            RectF(w * 0.2f, h * 0.28f, w * 0.8f, h * 0.62f)
        }

        // Dim outside guide
        canvas.save()
        val path = android.graphics.Path()
        if (species == "mule") {
            path.addRoundRect(guideRect, 40f, 40f, android.graphics.Path.Direction.CW)
        } else {
            path.addOval(guideRect, android.graphics.Path.Direction.CW)
        }
        path.fillType = android.graphics.Path.FillType.INVERSE_EVEN_ODD
        canvas.drawPath(path, dimPaint)
        canvas.restore()

        // Draw guide shape
        if (species == "mule") {
            canvas.drawRoundRect(guideRect, 40f, 40f, guidePaint)
        } else {
            canvas.drawOval(guideRect, guidePaint)
        }

        // Corner markers
        drawCornerMarkers(canvas, guideRect)

        // Guide text
        val guideText = if (species == "mule") "Mule Nose + Lip Area" else "Cow Muzzle (Nasal Ridge)"
        canvas.drawText(guideText, w / 2, guideRect.top - 30f, textPaint)

        // Status text
        val statusText = if (cameraReady) "Position muzzle in the guide" else "Starting camera..."
        canvas.drawText(statusText, w / 2, guideRect.bottom + 60f, subtextPaint)

        // Capture flash
        if (showFlash) {
            flashPaint.alpha = 180
            canvas.drawRect(0f, 0f, w, h, flashPaint)
        }
    }

    private fun drawCornerMarkers(canvas: Canvas, rect: RectF) {
        val len = 30f
        val paint = Paint(guidePaint).apply { strokeWidth = 5f }

        canvas.drawLine(rect.left, rect.top, rect.left + len, rect.top, paint)
        canvas.drawLine(rect.left, rect.top, rect.left, rect.top + len, paint)

        canvas.drawLine(rect.right - len, rect.top, rect.right, rect.top, paint)
        canvas.drawLine(rect.right, rect.top, rect.right, rect.top + len, paint)

        canvas.drawLine(rect.left, rect.bottom, rect.left + len, rect.bottom, paint)
        canvas.drawLine(rect.left, rect.bottom - len, rect.left, rect.bottom, paint)

        canvas.drawLine(rect.right - len, rect.bottom, rect.right, rect.bottom, paint)
        canvas.drawLine(rect.right, rect.bottom - len, rect.right, rect.bottom, paint)
    }
}
