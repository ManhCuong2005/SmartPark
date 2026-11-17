package vn.smartpark.smartpark

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.res.AssetManager
import android.graphics.*
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.FloatBuffer
import java.util.concurrent.Executors

/** Single background worker owns the session; camera frames cannot overlap. */
class PlateDetector(private val assets: AssetManager, private val modelPath: String) {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val environment = OrtEnvironment.getEnvironment()
    private var session: OrtSession? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            try {
                val value: Any? = when (call.method) {
                    "prepare" -> { prepare(); null }
                    "detect" -> detect(call)
                    "close" -> { session?.close(); session = null; null }
                    else -> throw IllegalArgumentException("Unknown detector command")
                }
                main.post { result.success(value) }
            } catch (error: Exception) {
                main.post { result.error("PLATE_DETECTOR", error.message, null) }
            }
        }
    }

    private fun prepare(): OrtSession {
        session?.let { return it }
        val options = OrtSession.SessionOptions()
        try {
            options.setIntraOpNumThreads(2)
            options.setInterOpNumThreads(1)
            val model = assets.open(modelPath).use { it.readBytes() }
            return environment.createSession(model, options).also { session = it }
        } finally { options.close() }
    }

    private fun detect(call: MethodCall): List<List<Double>> {
        val width = requireNotNull(call.argument<Int>("width"))
        val height = requireNotNull(call.argument<Int>("height"))
        val rotation = requireNotNull(call.argument<Int>("rotation"))
        val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
        require(width > 0 && height > 0 && width % 2 == 0 && height % 2 == 0)
        require(rotation in listOf(0, 90, 180, 270) && bytes.size == width * height * 3 / 2)
        val jpeg = ByteArrayOutputStream()
        check(YuvImage(bytes, ImageFormat.NV21, width, height, null)
            .compressToJpeg(Rect(0, 0, width, height), 95, jpeg))
        val packed = jpeg.toByteArray()
        val raw = requireNotNull(BitmapFactory.decodeByteArray(packed, 0, packed.size))
        val upright = Bitmap.createBitmap(raw, 0, 0, width, height,
            Matrix().apply { postRotate(rotation.toFloat()) }, false)
        val input = Bitmap.createBitmap(384, 384, Bitmap.Config.ARGB_8888)
        try {
            val scale = minOf(384.0 / upright.width, 384.0 / upright.height)
            val resizedWidth = kotlin.math.round(upright.width * scale).toInt()
            val resizedHeight = kotlin.math.round(upright.height * scale).toInt()
            val dx = (384 - resizedWidth) / 2.0
            val dy = (384 - resizedHeight) / 2.0
            val left = kotlin.math.round(dx - .1).toInt()
            val top = kotlin.math.round(dy - .1).toInt()
            Canvas(input).apply {
                drawColor(Color.rgb(114, 114, 114))
                drawBitmap(upright, null, Rect(left, top, left + resizedWidth, top + resizedHeight),
                    Paint(Paint.FILTER_BITMAP_FLAG))
            }
            val pixels = IntArray(384 * 384)
            input.getPixels(pixels, 0, 384, 0, 0, 384, 384)
            val plane = pixels.size
            val data = FloatArray(plane * 3)
            pixels.forEachIndexed { i, pixel ->
                data[i] = Color.red(pixel) / 255f
                data[plane + i] = Color.green(pixel) / 255f
                data[plane * 2 + i] = Color.blue(pixel) / 255f
            }
            val active = prepare()
            OnnxTensor.createTensor(environment, FloatBuffer.wrap(data), longArrayOf(1, 3, 384, 384)).use { tensor ->
                active.run(mapOf(active.inputNames.first() to tensor)).use { outputs ->
                    val output = outputs[0] as OnnxTensor
                    check(output.info.shape.last() == 7L) { "Invalid plate model output" }
                    val values = output.floatBuffer
                    val boxes = mutableListOf<List<Double>>()
                    while (values.remaining() >= 7) {
                        val row = FloatArray(7); values.get(row)
                        if (row[0] != 0f || row[5] != 0f || row[6] < .5f) continue
                        val x1 = (row[1] - dx) / scale / upright.width
                        val y1 = (row[2] - dy) / scale / upright.height
                        val x2 = (row[3] - dx) / scale / upright.width
                        val y2 = (row[4] - dy) / scale / upright.height
                        if (!listOf(x1, y1, x2, y2).all { it.isFinite() } ||
                            x1 < -.02 || y1 < -.02 || x2 > 1.02 || y2 > 1.02 ||
                            x2 - x1 < .15 || y2 - y1 < .07) continue
                        val padX = (x2 - x1) * .04; val padY = (y2 - y1) * .08
                        boxes.add(listOf(maxOf(0.0, x1 - padX), maxOf(0.0, y1 - padY),
                            minOf(1.0, x2 + padX), minOf(1.0, y2 + padY)))
                    }
                    return boxes.sortedByDescending { (it[2] - it[0]) * (it[3] - it[1]) }.take(4)
                }
            }
        } finally {
            input.recycle()
            if (upright !== raw) upright.recycle()
            raw.recycle()
        }
    }

    fun dispose() {
        executor.execute { session?.close(); session = null }
        executor.shutdown()
    }
}
