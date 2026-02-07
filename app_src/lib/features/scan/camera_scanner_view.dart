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
    _barcodeScanner = BarcodeScanner(
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
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

    final controller = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();

    await controller.startImageStream((image) async {
      if (!widget.isActive) return;
      if (_processing) return;

      final now = DateTime.now();
      if (now.difference(_lastScan).inMilliseconds < 800) return;

      _processing = true;
      try {
        final input = _toInputImage(image, controller.description.sensorOrientation);
        final barcodes = await _barcodeScanner.processImage(input);

        if (barcodes.isNotEmpty) {
          final raw = barcodes.first.rawValue?.trim();
          if (raw != null && raw.isNotEmpty) {
            if (_lastValue == raw && now.difference(_lastScan).inMilliseconds < 1200) {
              return;
            }
            _lastValue = raw;
            _lastScan = now;
            widget.onScanned(raw);
          }
        }
      } catch (_) {
      } finally {
        _processing = false;
      }
    });

    setState(() => _controller = controller);
  }

  InputImage _toInputImage(CameraImage image, int sensorRotationDegrees) {
    final bytes = _concatenatePlanes(image.planes);
    final size = Size(image.width.toDouble(), image.height.toDouble());
    final rotation = _rotationFromDegrees(sensorRotationDegrees);
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    final planeData = image.planes
        .map(
          (plane) => InputImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          ),
        )
        .toList();

    final metadata = InputImageMetadata(
      size: size,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
      planeData: planeData,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
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
