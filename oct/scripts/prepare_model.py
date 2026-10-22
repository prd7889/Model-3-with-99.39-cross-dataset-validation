#!/usr/bin/env python3
"""
Dynamic Model Preparation and Conversion Script for OCT Classifier.

Automatically discovers models in the workspace (.keras, .h5, .tflite, .onnx, saved_model),
converts them to TensorFlow Lite format (oct/assets/oct_model_float32.tflite),
and generates corresponding labels.txt and model_info.json metadata.
"""

import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

DEFAULT_LABELS_8 = [
    "AMD",
    "CNV",
    "CSR",
    "DME",
    "DR",
    "DRUSEN",
    "MH",
    "NORMAL",
]

DEFAULT_LABELS_4 = [
    "CNV",
    "DME",
    "DRUSEN",
    "NORMAL",
]

SUPPORTED_EXTENSIONS = {".keras", ".h5", ".hdf5", ".tflite", ".onnx", ".pt", ".pth"}


def parse_args():
    parser = argparse.ArgumentParser(
        description="Discover and prepare model files for OCT Classifier Flutter App"
    )
    parser.add_argument(
        "--model",
        "--model-path",
        dest="model_path",
        default=os.environ.get("MODEL_PATH", ""),
        help="Explicit path to model file or directory",
    )
    parser.add_argument(
        "--root-dir",
        default=str(Path(__file__).resolve().parents[2]),
        help="Repository root directory to search for models",
    )
    parser.add_argument(
        "--output-dir",
        default=str(Path(__file__).resolve().parents[1] / "assets"),
        help="Target assets directory in Flutter app",
    )
    return parser.parse_args()


def find_candidate_models(root_dir: Path, target_tflite: Path):
    candidates = []
    ignored_parts = {
        ".git",
        ".dart_tool",
        ".idea",
        "android",
        "ios",
        "linux",
        "windows",
        "build",
        "__pycache__",
        "venv",
        ".venv",
    }

    # First check root directory directly
    for entry in root_dir.iterdir():
        if entry.is_file() and entry.suffix.lower() in SUPPORTED_EXTENSIONS:
            candidates.append(entry)
        elif entry.is_dir() and (entry / "saved_model.pb").exists():
            candidates.append(entry)

    # Then check subdirectories
    for root, dirs, files in os.walk(root_dir):
        # Prune ignored directories
        dirs[:] = [d for d in dirs if d not in ignored_parts]
        for f in files:
            path = Path(root) / f
            try:
                if path.resolve() == target_tflite.resolve():
                    continue
            except Exception:
                pass

            if path.suffix.lower() in SUPPORTED_EXTENSIONS:
                if path not in candidates:
                    candidates.append(path)

    return candidates


def score_candidate(path: Path) -> tuple:
    """Score model candidates so the most relevant/recent is selected first."""
    name = path.name.lower()
    is_root = len(path.parents) > 0 and path.parent == path.parents[-1]
    priority = 0

    if "best" in name:
        priority += 50
    if "final" in name:
        priority += 40
    if "cnn_se" in name:
        priority += 30
    if "oct" in name:
        priority += 20
    if path.suffix.lower() == ".keras":
        priority += 25
    elif path.suffix.lower() in {".h5", ".hdf5"}:
        priority += 15
    elif path.suffix.lower() == ".tflite":
        priority += 10

    mtime = path.stat().st_mtime if path.exists() else 0
    return (priority, mtime)


def select_best_model(root_dir: Path, explicit_path: str, target_tflite: Path):
    if explicit_path:
        p = Path(explicit_path)
        if not p.is_absolute():
            p = root_dir / p
        if p.exists():
            return p
        raise FileNotFoundError(f"Specified model not found: {explicit_path}")

    candidates = find_candidate_models(root_dir, target_tflite)
    if not candidates:
        return None

    candidates.sort(key=score_candidate, reverse=True)
    return candidates[0]


def convert_keras_or_h5(model_path: Path, output_tflite: Path):
    print(f"Loading Keras model from {model_path}...")
    import tensorflow as tf

    try:
        import keras

        load_fn = keras.models.load_model
    except Exception:
        load_fn = tf.keras.models.load_model

    model = None
    errors = []

    for compile_mode in [False, True]:
        try:
            model = load_fn(str(model_path), compile=compile_mode)
            break
        except Exception as e:
            errors.append(str(e))

    if model is None:
        try:
            import tf_keras

            model = tf_keras.models.load_model(str(model_path), compile=False)
        except Exception as e:
            errors.append(str(e))

    if model is None:
        raise RuntimeError(
            f"Failed to load Keras model '{model_path}'. Errors:\n" + "\n".join(errors)
        )

    input_shape = getattr(model, "input_shape", None)
    output_shape = getattr(model, "output_shape", None)
    print(f"Model loaded. input_shape={input_shape}, output_shape={output_shape}")

    tflite_bytes = None

    # Try Keras 3 export to SavedModel first
    if hasattr(model, "export"):
        try:
            print("Exporting via model.export(format='tf_saved_model')...")
            with tempfile.TemporaryDirectory() as tmp_dir:
                sm_path = os.path.join(tmp_dir, "saved_model")
                model.export(sm_path, format="tf_saved_model")
                converter = tf.lite.TFLiteConverter.from_saved_model(sm_path)
                converter.optimizations = [tf.lite.Optimize.DEFAULT]
                tflite_bytes = converter.convert()
        except Exception as e:
            print(f"Note: model.export failed ({e}); falling back to from_keras_model.")

    if tflite_bytes is None:
        print("Converting via TFLiteConverter.from_keras_model...")
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_bytes = converter.convert()

    output_tflite.parent.mkdir(parents=True, exist_ok=True)
    with open(output_tflite, "wb") as f:
        f.write(tflite_bytes)

    print(
        f"Successfully generated TFLite model: {output_tflite} ({len(tflite_bytes)} bytes)"
    )
    return input_shape, output_shape


def convert_saved_model(model_dir: Path, output_tflite: Path):
    import tensorflow as tf

    print(f"Converting SavedModel from {model_dir}...")
    converter = tf.lite.TFLiteConverter.from_saved_model(str(model_dir))
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_bytes = converter.convert()

    output_tflite.parent.mkdir(parents=True, exist_ok=True)
    with open(output_tflite, "wb") as f:
        f.write(tflite_bytes)

    print(f"SavedModel converted: {output_tflite} ({len(tflite_bytes)} bytes)")
    return None, None


def inspect_tflite(tflite_path: Path):
    try:
        import tensorflow as tf

        interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
        interpreter.allocate_tensors()
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()

        in_shape = [int(x) for x in input_details[0]["shape"]]
        out_shape = [int(x) for x in output_details[0]["shape"]]
        return in_shape, out_shape
    except Exception as e:
        print(f"TFLite inspection note: {e}")
        return None, None


def determine_labels(output_shape, root_dir: Path, model_path: Path):
    num_classes = None
    if output_shape:
        if isinstance(output_shape, (list, tuple)) and len(output_shape) > 0:
            num_classes = int(output_shape[-1])

    # Check for labels file near model
    for check_dir in [model_path.parent if model_path else None, root_dir]:
        if check_dir and check_dir.exists():
            for name in ["labels.txt", "classes.txt"]:
                lp = check_dir / name
                if lp.exists():
                    with open(lp) as f:
                        lines = [line.strip() for line in f if line.strip()]
                    if lines and (num_classes is None or len(lines) == num_classes):
                        return lines

    if num_classes == 4:
        return list(DEFAULT_LABELS_4)
    if num_classes == 8:
        return list(DEFAULT_LABELS_8)
    if num_classes and num_classes > 0:
        return [f"Class {i + 1}" for i in range(num_classes)]

    return list(DEFAULT_LABELS_8)


def main():
    args = parse_args()
    root_dir = Path(args.root_dir).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    target_tflite = output_dir / "oct_model_float32.tflite"
    labels_file = output_dir / "labels.txt"
    info_file = output_dir / "model_info.json"

    print("=" * 60)
    print("OCT Dynamic Model Preparation Pipeline")
    print(f"Workspace Root : {root_dir}")
    print(f"Assets Output  : {output_dir}")
    print("=" * 60)

    selected_model = select_best_model(root_dir, args.model_path, target_tflite)

    if selected_model is None:
        print("No external model candidates found.")
        if target_tflite.exists():
            print(f"Using existing bundled model: {target_tflite}")
            in_shape, out_shape = inspect_tflite(target_tflite)
            labels = determine_labels(out_shape, root_dir, target_tflite)
            with open(labels_file, "w") as f:
                f.write("\n".join(labels) + "\n")
            print("Setup completed with bundled model.")
            return 0
        else:
            print("Error: No model found in workspace and no bundled TFLite exists.")
            return 1

    print(f"Selected source model: {selected_model}")
    print(f"Model size: {selected_model.stat().st_mtime} timestamp, {selected_model.stat().st_size} bytes")

    ext = selected_model.suffix.lower()
    in_shape, out_shape = None, None

    try:
        if ext == ".tflite":
            print(f"Source model is already TFLite. Copying to {target_tflite}...")
            shutil.copy2(selected_model, target_tflite)
            in_shape, out_shape = inspect_tflite(target_tflite)
        elif ext in {".keras", ".h5", ".hdf5"}:
            in_shape, out_shape = convert_keras_or_h5(selected_model, target_tflite)
        elif selected_model.is_dir() and (selected_model / "saved_model.pb").exists():
            in_shape, out_shape = convert_saved_model(selected_model, target_tflite)
        elif ext == ".onnx":
            print("ONNX model detected. Attempting onnx2tf / tf2onnx conversion...")
            try:
                import onnx2tf

                onnx2tf.convert(
                    input_onnx_file_path=str(selected_model),
                    output_folder_path=str(output_dir / "onnx_tflite"),
                    non_verbose=True,
                )
                converted_tflite = output_dir / "onnx_tflite" / f"{selected_model.stem}_float32.tflite"
                if converted_tflite.exists():
                    shutil.copy2(converted_tflite, target_tflite)
                else:
                    raise RuntimeError("onnx2tf did not produce expected output")
            except Exception as oe:
                print(f"Warning: ONNX conversion failed: {oe}")
                if target_tflite.exists():
                    print("Falling back to existing TFLite asset.")
                else:
                    raise
        else:
            print(f"Format {ext} requires specialized conversion. Checking fallback...")
            if not target_tflite.exists():
                raise RuntimeError(f"Unsupported model format: {ext}")

    except Exception as conversion_error:
        print(f"Error during model conversion: {conversion_error}")
        if target_tflite.exists():
            print(
                f"Warning: Preserving existing valid TFLite model at {target_tflite}"
            )
        else:
            print("Fatal: No valid TFLite model available.")
            raise

    # Inspect resulting TFLite if shapes are still unknown
    if in_shape is None or out_shape is None:
        in_shape, out_shape = inspect_tflite(target_tflite)

    labels = determine_labels(out_shape, root_dir, selected_model)
    with open(labels_file, "w") as f:
        f.write("\n".join(labels) + "\n")
    print(f"Wrote labels file: {labels_file} ({len(labels)} classes: {', '.join(labels)})")

    info = {
        "source_model": selected_model.name,
        "source_path": str(selected_model),
        "target_file": target_tflite.name,
        "input_shape": in_shape,
        "output_shape": out_shape,
        "classes": labels,
        "num_classes": len(labels),
    }

    with open(info_file, "w") as f:
        json.dump(info, f, indent=2)
    print(f"Wrote model info metadata: {info_file}")
    print("OCT Model Preparation Complete!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
