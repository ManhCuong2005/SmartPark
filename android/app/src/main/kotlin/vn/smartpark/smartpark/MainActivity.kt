package vn.smartpark.smartpark

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var detector: PlateDetector? = null
    private var channel: MethodChannel? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val path = FlutterInjector.instance().flutterLoader()
            .getLookupKeyForAsset("assets/models/plate_detector.onnx")
        val active = PlateDetector(assets, path)
        detector = active
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smartpark/plate_detector")
        channel!!.setMethodCallHandler(active::handle)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        detector?.dispose()
        detector = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
