# OCT Sort

Flutter app for private, on-device classification of gallery images into eight
categories.

## Features

- Select one or many images using the Android photo picker.
- Run the H5-derived, float32 TensorFlow Lite model entirely on-device.
- Review each image with its top category and confidence.
- Switch to folder view to see images grouped into all eight categories.
- Remove individual images, clear a batch, or add more images.

## Model contract & Dynamic Adaptation

- Asset: `assets/oct_model_float32.tflite`
- Input: dynamically adapts to the bundled model's resolution (e.g. `[1, 200, 200, 3]`, `[1, 224, 224, 3]`, etc.)
- Preprocessing: RGB resize to target dimensions, channel normalization by 255.0
- Output: softmax probabilities dynamically matching output classes
- Labels: loaded from `assets/labels.txt` or default category mapping

## Dynamic Model Ingestion & Conversion

A Python script `scripts/prepare_model.py` automatically discovers models across the repository (`.keras`, `.h5`, `.tflite`, `.onnx`, SavedModel), converts them to optimized TFLite format, and extracts labels and metadata:

```sh
python scripts/prepare_model.py
# Or specify a custom model:
python scripts/prepare_model.py --model path/to/model.keras
```

## GitHub Actions Release Pipeline

A GitHub Actions workflow (`.github/workflows/release_apk.yml`) automatically triggers on push to `main`:
1. Discovers and converts any newly trained model dynamically.
2. Bundles the model, labels, and metadata into the Flutter app assets.
3. Runs Flutter analysis and unit/widget tests.
4. Builds the signed Android release APK.
5. Publishes a new GitHub Release with the APK binary and SHA-256 integrity checksum.

## Verification

```sh
flutter analyze
flutter test
flutter build apk --release
```
