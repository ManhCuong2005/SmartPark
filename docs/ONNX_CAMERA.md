# ONNX camera integration investigation

Status: researched on 2026-11-17. No ONNX dependency or model is integrated yet.
Existing application source is pushed through commit 02eb143 on
`release/booking-fix-v1.2.1`. The untracked empty `.vscode/settings.json` is local
editor configuration, not application code.

## Intended operation

The entrance and exit cameras continuously supply frames. Load a plate detector
once per camera session, find plate rectangles inside the lane's guide, select
one sufficiently close unambiguous target, crop that target at source resolution,
then read its characters. Preserve the existing multi-frame consensus, duplicate
protection, server-bound direction, live `kiosk.scan` RPC, payment idempotency,
Vietnamese announcements and rejection cooldown.

ONNX Runtime executes a trained model. It does not acquire camera frames, read
plate characters without an OCR model, determine real distance, or validate a
booking. Those remain application responsibilities.

## First model experiment

Evaluate `yolo-v9-t-384-license-plate-end2end` from Open Image Models, compare
against the 256 and 512 variants on identical images. These are candidate plate
detectors, not confirmed Vietnamese OCR solutions. Check the exact model's input
normalization, resize/letterbox convention, output tensors, NMS behavior and
redistribution terms before adding weights to the application. Pin the chosen
asset version and checksum. Published detector metrics do not establish accuracy
on Vietnamese motorcycle plates or the installed parking cameras.

## Integration points

- `lib/data/live_plate_reader_native.dart`: detect first, send the high-resolution
  plate crop to the existing ML Kit Latin recognizer. Map returned coordinates
  back into the upright full image for `scanTargets` and the overlay.
- `lib/data/plate_camera_image.dart`: preserve rotation, NV21/BGRA strides and
  crop offsets. Detector RGB input must be prepared separately from ML Kit input.
- `web/plate_ocr.js`: evaluate ONNX Runtime Web for detection, retaining Tesseract
  for OCR initially. The Dart FFI plugin cannot be imported into this web path.
- `live_plate_camera.dart`: retain a single in-flight frame, resource cleanup and
  session lifecycle. Avoid inference on the UI thread; load the model once.
- `pubspec.yaml`, Android configuration, web assets and third-party notices:
  change only after the model experiment passes.

The community `onnxruntime` Flutter package lists Android API 21+ but not Web;
validate its native binaries against this app's Android build and target devices.
Official Android Java integration through a Flutter platform channel is another
option if the package cannot meet those requirements. Do not install both paths.

## Verification before replacing the current reader

Use real held-out images/videos with one/two-row Vietnamese plates, white/yellow
plates, shadows, reflections, tilt, empty lanes, distant cars and equal targets.
Measure detection recall, exact full-plate OCR accuracy, false admissions, warm
end-to-end latency and cold initialization separately. Test on target Android
hardware and Chrome, including sustained capture and memory/resource cleanup.
Retain the existing tests for duplicate vehicles, new bookings without reload,
direction restrictions, audio failure and safe retries. Synthetic OCR fixtures
alone cannot validate a learned detector or establish a production speed claim.

Current capture supports cameras exposed by the device/browser. A fixed phone
or supported USB webcam fits this flow. An IP/RTSP camera requires a separate
video input integration; ONNX Runtime does not provide RTSP capture.

## Sources

- https://onnxruntime.ai/docs/tutorials/mobile/
- https://onnxruntime.ai/docs/tutorials/web/
- https://pub.dev/packages/onnxruntime
- https://github.com/ankandrew/open-image-models
- https://github.com/ankandrew/fast-alpr
