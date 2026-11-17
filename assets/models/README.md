# Plate detector

Pretrained YOLOv9-t, 384px input, from ankandrew/Open Image Models.
The exact asset URL and SHA-256 are in `manifest.json`; retain the upstream
`LICENSE` when distributing the model. No model training was performed here.

This model detects rectangles, not plate characters. Android uses ML Kit Latin
OCR after detection. Web uses Tesseract after detection. Existing guide OCR is
retained as fallback if the model misses a plate or its crop cannot be read.
The detector is not certified for Vietnamese plates. Test with real installed
cameras; upstream detection metrics do not measure this application's OCR.
