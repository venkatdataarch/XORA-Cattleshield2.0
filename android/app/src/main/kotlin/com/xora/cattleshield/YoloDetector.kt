package com.xora.cattleshield

import ai.onnxruntime.*
import android.content.Context
import android.graphics.Bitmap
import android.graphics.RectF
import java.nio.FloatBuffer
import java.util.PriorityQueue

/**
 * YOLOv8 detector using ONNX Runtime.
 * Detects objects from COCO dataset — we filter for class 19 (cow) and nearby classes.
 */
class YoloDetector(context: Context) {

    private var ortSession: OrtSession? = null
    private var ortEnv: OrtEnvironment? = null

    // COCO class indices for livestock
    companion object {
        const val INPUT_SIZE = 320
        const val CONFIDENCE_THRESHOLD = 0.35f
        const val IOU_THRESHOLD = 0.45f

        // COCO classes: 19=cow, 17=cat, 16=dog, 18=horse, 20=elephant, 21=bear
        // We detect cow (19), horse (18) — mule looks like horse to COCO model
        val ANIMAL_CLASSES = setOf(19, 18, 17, 16, 20, 21)
        val MUZZLE_CLASSES = setOf(19, 18) // cow and horse/mule
    }

    init {
        try {
            ortEnv = OrtEnvironment.getEnvironment()
            val sessionOptions = OrtSession.SessionOptions()
            sessionOptions.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)

            // Load model from assets
            val modelBytes = context.assets.open("yolov8n.onnx").readBytes()
            ortSession = ortEnv?.createSession(modelBytes, sessionOptions)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    data class Detection(
        val box: RectF,        // Bounding box in 0-1 coordinates
        val confidence: Float,
        val classId: Int,
        val className: String
    )

    /**
     * Run YOLOv8 inference on a bitmap.
     * Returns list of detections filtered for animal/muzzle classes.
     */
    fun detect(bitmap: Bitmap): List<Detection> {
        val session = ortSession ?: return emptyList()
        val env = ortEnv ?: return emptyList()

        try {
            // Preprocess: resize to 320x320, normalize to [0,1], CHW format
            val resized = Bitmap.createScaledBitmap(bitmap, INPUT_SIZE, INPUT_SIZE, true)
            val inputBuffer = preprocessImage(resized)

            // Create input tensor [1, 3, 320, 320]
            val shape = longArrayOf(1, 3, INPUT_SIZE.toLong(), INPUT_SIZE.toLong())
            val inputTensor = OnnxTensor.createTensor(env, inputBuffer, shape)

            // Run inference
            val inputName = session.inputNames.iterator().next()
            val results = session.run(mapOf(inputName to inputTensor))

            // Parse output
            val outputTensor = results[0] as OnnxTensor
            val output = outputTensor.floatBuffer

            // YOLOv8 output: [1, 84, 8400] — 84 = 4 bbox + 80 classes, 8400 proposals
            val detections = parseYolov8Output(output, bitmap.width, bitmap.height)

            inputTensor.close()
            results.close()

            return detections
        } catch (e: Exception) {
            e.printStackTrace()
            return emptyList()
        }
    }

    /**
     * Check if a muzzle-region animal is detected in the guide zone.
     * Returns confidence 0-100 and guidance message.
     */
    fun detectMuzzle(bitmap: Bitmap, guideRect: RectF): MuzzleDetectionResult {
        val detections = detect(bitmap)

        // Filter for cow/horse (muzzle-relevant) classes
        val muzzleDetections = detections.filter { it.classId in MUZZLE_CLASSES }

        if (muzzleDetections.isEmpty()) {
            return MuzzleDetectionResult(
                detected = false,
                confidence = 0f,
                message = "No animal detected — point camera at the muzzle",
                detection = null
            )
        }

        // Find best detection
        val best = muzzleDetections.maxByOrNull { it.confidence }!!

        // Check if detection is in guide zone
        val overlapRatio = calculateOverlap(best.box, guideRect)

        return when {
            overlapRatio < 0.2f -> MuzzleDetectionResult(
                detected = true,
                confidence = (best.confidence * 30).coerceAtMost(30f),
                message = "Animal detected — move muzzle into the guide",
                detection = best
            )
            overlapRatio < 0.5f -> MuzzleDetectionResult(
                detected = true,
                confidence = (best.confidence * 50 + overlapRatio * 20),
                message = "Getting closer — align muzzle with the guide",
                detection = best
            )
            else -> MuzzleDetectionResult(
                detected = true,
                confidence = (best.confidence * 60 + overlapRatio * 40).coerceAtMost(100f),
                message = "Muzzle aligned — hold steady",
                detection = best
            )
        }
    }

    private fun preprocessImage(bitmap: Bitmap): FloatBuffer {
        val pixels = IntArray(INPUT_SIZE * INPUT_SIZE)
        bitmap.getPixels(pixels, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)

        val buffer = FloatBuffer.allocate(3 * INPUT_SIZE * INPUT_SIZE)

        // CHW format, normalized to [0, 1]
        for (c in 0 until 3) {
            for (i in pixels.indices) {
                val pixel = pixels[i]
                val value = when (c) {
                    0 -> ((pixel shr 16) and 0xFF) / 255.0f  // R
                    1 -> ((pixel shr 8) and 0xFF) / 255.0f   // G
                    2 -> (pixel and 0xFF) / 255.0f            // B
                    else -> 0f
                }
                buffer.put(value)
            }
        }
        buffer.rewind()
        return buffer
    }

    private fun parseYolov8Output(output: FloatBuffer, imgWidth: Int, imgHeight: Int): List<Detection> {
        val numClasses = 80
        val numProposals = 8400
        val numOutputs = 4 + numClasses  // 84

        // Output shape: [1, 84, 8400] — transposed from typical YOLO
        val rawDetections = mutableListOf<Detection>()

        for (i in 0 until numProposals) {
            // Extract bbox: center_x, center_y, width, height
            val cx = output.get(0 * numProposals + i)
            val cy = output.get(1 * numProposals + i)
            val w = output.get(2 * numProposals + i)
            val h = output.get(3 * numProposals + i)

            // Find best class
            var maxScore = 0f
            var maxClassId = 0
            for (c in 0 until numClasses) {
                val score = output.get((4 + c) * numProposals + i)
                if (score > maxScore) {
                    maxScore = score
                    maxClassId = c
                }
            }

            if (maxScore < CONFIDENCE_THRESHOLD) continue
            if (maxClassId !in ANIMAL_CLASSES) continue

            // Convert to normalized coordinates [0, 1]
            val x1 = ((cx - w / 2) / INPUT_SIZE).coerceIn(0f, 1f)
            val y1 = ((cy - h / 2) / INPUT_SIZE).coerceIn(0f, 1f)
            val x2 = ((cx + w / 2) / INPUT_SIZE).coerceIn(0f, 1f)
            val y2 = ((cy + h / 2) / INPUT_SIZE).coerceIn(0f, 1f)

            val className = COCO_CLASSES.getOrElse(maxClassId) { "unknown" }

            rawDetections.add(Detection(
                box = RectF(x1, y1, x2, y2),
                confidence = maxScore,
                classId = maxClassId,
                className = className
            ))
        }

        // NMS
        return nonMaxSuppression(rawDetections)
    }

    private fun nonMaxSuppression(detections: List<Detection>): List<Detection> {
        if (detections.isEmpty()) return emptyList()

        val sorted = detections.sortedByDescending { it.confidence }
        val selected = mutableListOf<Detection>()

        val active = BooleanArray(sorted.size) { true }

        for (i in sorted.indices) {
            if (!active[i]) continue
            selected.add(sorted[i])

            for (j in i + 1 until sorted.size) {
                if (!active[j]) continue
                if (calculateIoU(sorted[i].box, sorted[j].box) > IOU_THRESHOLD) {
                    active[j] = false
                }
            }
        }

        return selected
    }

    private fun calculateIoU(a: RectF, b: RectF): Float {
        val intersectLeft = maxOf(a.left, b.left)
        val intersectTop = maxOf(a.top, b.top)
        val intersectRight = minOf(a.right, b.right)
        val intersectBottom = minOf(a.bottom, b.bottom)

        if (intersectRight <= intersectLeft || intersectBottom <= intersectTop) return 0f

        val intersectArea = (intersectRight - intersectLeft) * (intersectBottom - intersectTop)
        val aArea = (a.right - a.left) * (a.bottom - a.top)
        val bArea = (b.right - b.left) * (b.bottom - b.top)

        return intersectArea / (aArea + bArea - intersectArea)
    }

    private fun calculateOverlap(detection: RectF, guide: RectF): Float {
        val intersectLeft = maxOf(detection.left, guide.left)
        val intersectTop = maxOf(detection.top, guide.top)
        val intersectRight = minOf(detection.right, guide.right)
        val intersectBottom = minOf(detection.bottom, guide.bottom)

        if (intersectRight <= intersectLeft || intersectBottom <= intersectTop) return 0f

        val intersectArea = (intersectRight - intersectLeft) * (intersectBottom - intersectTop)
        val detectionArea = (detection.right - detection.left) * (detection.bottom - detection.top)

        return if (detectionArea > 0) intersectArea / detectionArea else 0f
    }

    fun close() {
        ortSession?.close()
        ortEnv?.close()
    }

    data class MuzzleDetectionResult(
        val detected: Boolean,
        val confidence: Float,
        val message: String,
        val detection: Detection?
    )

    // COCO class names (we only use a few)
    private val COCO_CLASSES = mapOf(
        0 to "person", 1 to "bicycle", 2 to "car", 3 to "motorcycle",
        14 to "bird", 15 to "cat", 16 to "dog", 17 to "horse",
        18 to "sheep", 19 to "cow", 20 to "elephant", 21 to "bear",
        22 to "zebra", 23 to "giraffe"
    )
}
