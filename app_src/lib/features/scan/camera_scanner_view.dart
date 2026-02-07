import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

typedef OnScanned = void Function(String rawValue);

class CameraScannerView extends StatefulWidget {
  final OnScanned onScanned;
  final bool isActive;

  const CameraScannerView({
    super.key,
    required this.onScanned,
    required this.isActive,
  });

  @override
  State<CameraScannerView> createState() => _CameraScannerViewState();
}

class _CameraScannerViewState extends State<CameraScannerView> {
  CameraController? _controller;
  late final BarcodeScanner _barcodeScanner;

  bool _processing = false;
  DateTime _lastScan = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastValue;

  @override
  void initState() {
    super.initState();

    // Product barcode is alphanumeric in your case, so Code128/Code39 are most common.
    _barcodeScanner = BarcodeScanner(
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        // BarcodeFormat.qrCode, // enable if needed later
      ],
    );

    _initCamera();
  }

  InputImageRotation _rotationFromDegrees(int degrees) {
    switch (degrees) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // IMPORTANT:
    // Use NV21 on Android to match the simplified InputImageMetadata approach.
    final controller = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await controller.initialize();

    await controller.startImageStream((image) async {
      if (!widget.isActive) return;
      if (_processing) return;

      // Throttle scans
      final now = DateTime.now();
      if (now.difference(_lastScan).inMilliseconds < 800) return;

      _processing = true;
      try {
        final inputImage =
            _toInputImage(image, controller.description.sensorOrientation);

        final barcodes = await _barcodeScanner.processImage(inputImage);

        if (barcodes.isNotEmpty) {
          final raw = barcodes.first.rawValue?.trim();
          if (raw != null && raw.isNotEmpty) {
            // avoid repeated same value quickly
            if (_lastValue == raw &&
                now.difference(_lastScan).inMilliseconds < 1200) {
              return;
            }

            _lastValue = raw;
            _lastScan = now;

            widget.onScanned(raw);
          }
        }
      } catch (_) {
        // Keep silent for MVP; you can add logs later if needed.
      } finally {
        _processing = false;
      }
    });

    if (mounted) setState(() => _controller = controller);
  }

  InputImage _toInputImage(CameraImage image, int sensorRotationDegrees) {
    // Merge planes into one bytes array.
    final bytesBuilder = BytesBuilder(copy: false);
    for (final plane in image.planes) {
      bytesBuilder.add(plane.bytes);
    }
    final bytes = bytesBuilder.toBytes();

    final size = Size(image.width.toDouble(), image.height.toDouble());
    final rotation = _rotationFromDegrees(sensorRotationDegrees);

    // Newer google_mlkit_commons expects InputImageMetadata without planeData
    // (plane metadata was removed in a breaking change). [1](https://dev.to/ajmal_hasan/building-a-qr-codebarcode-scanner-app-with-react-native-and-vision-camera-534k)[2](https://deepwiki.com/flutter-ml/google_ml_kit_flutter/3.3-barcode-scanning)
    // InputImageMetadata signature: size, rotation, format, bytesPerRow. [3](https://www.linkedin.com/pulse/creating-react-native-vision-camera-code-scanner-step-by-step-uafge?tl=en)[1](https://dev.to/ajmal_hasan/building-a-qr-codebarcode-scanner-app-with-react-native-and-vision-camera-534k)
    final metadata = InputImageMetadata(
      size: size,
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CameraPreview(controller),
    );
  }
}
