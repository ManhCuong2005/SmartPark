# ONNX parking cameras

Implemented for Android APK and Web on 2026-11-17. No database migration is needed.
The lot selection, entrance/exit direction, live server lookup, multi-frame
consensus, duplicate protection, Vietnamese announcements and payment flow remain
unchanged. iOS retains its existing ML Kit reader; ONNX is not integrated on iOS.

## Runtime and model

- One bundled YOLOv9-t plate detector, RGB NCHW 384x384 with gray-114 letterbox.
  Provenance, SHA-256 and exact tensor contract are in `assets/models/manifest.json`.
- Android uses the official `onnxruntime-android:1.20.0` through a Flutter method
  channel. Its manifest supports API 21+, preserving this app's minSdk 23.
  Newer tested artifacts 1.21.1/1.22/1.23.2 require API 24 and are not used here.
- Web bundles ONNX Runtime Web 1.23.2 JS, WASM loader and WASM binary in `web/onnx`.
  It uses one WASM thread and needs no cross-origin isolation or recognition API.
  The existing Tesseract runtime/model still loads from its pinned CDN on first use.
- Load a session once per active camera. Android inference, JPEG conversion and
  model preprocessing run on one background executor. Close sessions and output
  tensors when their work/session ends. Web also disposes inference tensors.

## Recognition

The camera supplies its existing central guide. The detector proposes plate
rectangles with score >=0.5. Ignore very small boxes and boxes mostly outside the
lane guide. Read up to four boxes rather than discarding equal competing cars.
ML Kit (Android) or Tesseract (Web) reads high-resolution crops. Map OCR coordinates
back to the upright full image so `scanTargets` applies its existing proximity
and ambiguity checks. This estimates proximity from apparent size, not meters.

Packed NV21 cropping preserves chroma alignment and supports all four image
rotations. A detector miss or unreadable crop falls back to the existing guide
OCR. Runtime/model initialization errors remain visible errors, not silent
fallback claiming that AI is running.

## Validation and limits

- Flutter tests cover ROI mapping/bytes in all four rotations, existing booking
  and wallet behavior, rejection retry, direction restrictions and duplicate scans.
- `tools/test_browser_plate_ocr.mjs` runs actual ONNX and Tesseract in Chrome,
  including synthetic one/two-row plates, yellow plates, mirror handling and
  blank-frame rejection. It downloads public upstream example fixtures into
  `.smartpark/onnx-fixtures`, not shipped app assets.
- Real photograph and Vietnamese motorcycle video samples verify localization.
  The skewed motorcycle sample is NOT a full OCR success: Tesseract does not
  reliably read all characters at confidence 70. The test checks that it cannot
  invent another valid plate. Do not claim a Vietnamese OCR accuracy percentage
  from these smoke tests or weaken the confidence threshold to pass them.
- `tools/test_browser_camera.mjs` runs the actual Flutter camera/Web detector/OCR
  with controlled video and a test backend, including a booking becoming valid
  after camera startup and completed Vietnamese audio before the five-second wait.
- Signed APK builds verify compilation and packaging, not actual ML Kit or camera
  performance on Android. No connected Android device/emulator is available here.
- ONNX adds inference time. Measure cold startup and warm end-to-end latency
  separately on target hardware; do not claim every scene is faster than OCR-only.

Current capture supports device/browser cameras, including a fixed phone or a
supported USB webcam. IP/RTSP capture requires a separate video input integration.

## Sources

- https://onnxruntime.ai/docs/tutorials/mobile/
- https://onnxruntime.ai/docs/tutorials/web/
- https://github.com/ankandrew/open-image-models
- https://github.com/ankandrew/fast-alpr
- https://github.com/ddkhoa2605/LicensePlateDetection
