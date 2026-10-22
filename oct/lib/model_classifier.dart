import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

const defaultClassLabels = <String>[
  'AMD',
  'CNV',
  'CSR',
  'DME',
  'DR',
  'DRUSEN',
  'MH',
  'NORMAL',
];

const classLabels = defaultClassLabels;

class Prediction {
  const Prediction({
    required this.classIndex,
    required this.scores,
    this.labelOverride,
  });

  final int classIndex;
  final List<double> scores;
  final String? labelOverride;

  String get label =>
      labelOverride ??
      (classIndex >= 0 && classIndex < classLabels.length
          ? classLabels[classIndex]
          : 'Class ${classIndex + 1}');

  double get confidence => scores[classIndex];
}

class ModelClassifier {
  Interpreter? _interpreter;
  List<String> _labels = List.from(defaultClassLabels);
  int _inputHeight = 200;
  int _inputWidth = 200;
  int _inputChannels = 3;
  TensorType _inputType = TensorType.float32;

  List<String> get labels => List.unmodifiable(_labels);
  int get inputHeight => _inputHeight;
  int get inputWidth => _inputWidth;
  int get inputChannels => _inputChannels;

  Future<void> load() async {
    final options = InterpreterOptions()..threads = 4;
    _interpreter = await Interpreter.fromAsset(
      'assets/oct_model_float32.tflite',
      options: options,
    );
    final input = _interpreter!.getInputTensor(0);
    final output = _interpreter!.getOutputTensor(0);

    _inputType = input.type;

    // Dynamically adapt to input dimensions [1, H, W, C] or [1, C, H, W]
    final inShape = input.shape;
    if (inShape.length == 4) {
      if (inShape[3] == 1 || inShape[3] == 3) {
        _inputHeight = inShape[1];
        _inputWidth = inShape[2];
        _inputChannels = inShape[3];
      } else if (inShape[1] == 1 || inShape[1] == 3) {
        _inputChannels = inShape[1];
        _inputHeight = inShape[2];
        _inputWidth = inShape[3];
      } else {
        _inputHeight = inShape[1];
        _inputWidth = inShape[2];
        _inputChannels = inShape[3];
      }
    } else if (inShape.length == 3) {
      _inputHeight = inShape[1];
      _inputWidth = inShape[2];
      _inputChannels = 1;
    }

    final numClasses = output.shape.last;

    // Dynamically load class labels if available in assets
    List<String>? loadedLabels;
    try {
      final content = await rootBundle.loadString('assets/labels.txt');
      final lines = content
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        loadedLabels = lines;
      }
    } catch (_) {
      // Optional asset might not be loaded yet
    }

    if (loadedLabels != null && loadedLabels.length == numClasses) {
      _labels = loadedLabels;
    } else if (numClasses == 8) {
      _labels = List.from(defaultClassLabels);
    } else if (numClasses == 4) {
      _labels = const ['CNV', 'DME', 'DRUSEN', 'NORMAL'];
    } else if (loadedLabels != null && loadedLabels.isNotEmpty) {
      _labels = loadedLabels.take(numClasses).toList();
      while (_labels.length < numClasses) {
        _labels.add('Class ${_labels.length + 1}');
      }
    } else {
      _labels = List.generate(numClasses, (i) => 'Class ${i + 1}');
    }
  }

  Future<Prediction> classify(String path) async {
    final interpreter = _interpreter;
    if (interpreter == null) throw StateError('Model is not loaded.');

    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unsupported image format.');
    }
    final resized = img.copyResize(
      img.bakeOrientation(decoded),
      width: _inputWidth,
      height: _inputHeight,
      interpolation: img.Interpolation.linear,
    );

    final totalPixels = _inputHeight * _inputWidth * _inputChannels;
    final isFloat = _inputType == TensorType.float32;

    List inputList;
    if (isFloat) {
      final pixels = Float32List(totalPixels);
      var offset = 0;
      for (final pixel in resized) {
        if (_inputChannels == 3) {
          pixels[offset++] = pixel.r / 255.0;
          pixels[offset++] = pixel.g / 255.0;
          pixels[offset++] = pixel.b / 255.0;
        } else {
          final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
          pixels[offset++] = gray;
        }
      }
      inputList = pixels.reshape([1, _inputHeight, _inputWidth, _inputChannels]);
    } else {
      final pixels = Uint8List(totalPixels);
      var offset = 0;
      for (final pixel in resized) {
        if (_inputChannels == 3) {
          pixels[offset++] = pixel.r.toInt();
          pixels[offset++] = pixel.g.toInt();
          pixels[offset++] = pixel.b.toInt();
        } else {
          final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round();
          pixels[offset++] = gray;
        }
      }
      inputList = pixels.reshape([1, _inputHeight, _inputWidth, _inputChannels]);
    }

    final numClasses = _labels.length;
    final output = List<double>.filled(numClasses, 0).reshape([1, numClasses]);
    interpreter.run(inputList, output);
    final scores = List<double>.from(output.first as List);
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) {
        best = i;
      }
    }
    return Prediction(
      classIndex: best,
      scores: scores,
      labelOverride: _labels[best],
    );
  }

  void close() => _interpreter?.close();
}
