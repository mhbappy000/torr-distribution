import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../core/storage/repos.dart';
import 'camera_scanner_view.dart';

class ScanSessionPage extends StatefulWidget {
  const ScanSessionPage({super.key});

  @override
  State<ScanSessionPage> createState() => _ScanSessionPageState();
}

class _ScanSessionPageState extends State<ScanSessionPage> {
  bool _cameraReady = false;
  bool _expectingLocation = true;

  String? _activeLocationBarcode;
  String? _activeLocationCode;

  String? _lastError;
  String? _lastSuccess;

  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

  Future<void> _initPermissions() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _cameraReady = true);
    } else {
      setState(() {
        _cameraReady = false;
        _lastError = 'Camera permission is required.';
      });
    }
  }

  Future<void> _onScanned(String raw) async {
    setState(() {
      _lastError = null;
      _lastSuccess = null;
    });

    final scanned = raw.trim().toUpperCase();
    if (scanned.isEmpty) return;

    if (_expectingLocation) {
      final locCode = await Repos.resolveLocationBarcode(scanned);
      if (locCode == null) {
        setState(() => _lastError = 'Unknown location barcode: $scanned');
        return;
      }

      setState(() {
        _activeLocationBarcode = scanned;
        _activeLocationCode = locCode;
        _expectingLocation = false;
        _lastSuccess = 'Location set: $locCode';
      });
      return;
    }

    if (_activeLocationCode == null) {
      setState(() {
        _lastError = 'No active location. Tap “Change Location” and scan again.';
        _expectingLocation = true;
      });
      return;
    }

    final taskId = await Repos.findBestOpenTask(
      productBarcode: scanned,
      locationCode: _activeLocationCode!,
    );

    if (taskId == null) {
      setState(() => _lastError = 'No OPEN task for $scanned at ${_activeLocationCode!}');
      return;
    }

    await Repos.savePick(
      eventId: const Uuid().v4(),
      taskId: taskId,
      locationCode: _activeLocationCode!,
      productBarcode: scanned,
      qty: 1,
      createdAt: DateTime.now(),
    );

    setState(() {
      _lastSuccess = 'Picked 1 unit: $scanned (task $taskId)';
    });
  }

  void _changeLocation() {
    setState(() {
      _expectingLocation = true;
      _activeLocationBarcode = null;
      _activeLocationCode = null;
      _lastError = null;
      _lastSuccess = 'Scan new location barcode.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _expectingLocation ? 'Scan Location' : 'Scan Products (qty=1)';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_expectingLocation)
            TextButton(
              onPressed: _changeLocation,
              child: const Text('Change Location', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Location Barcode: ${_activeLocationBarcode ?? "-"}'),
                    const SizedBox(height: 6),
                    Text('Location Code: ${_activeLocationCode ?? "-"}'),
                    const SizedBox(height: 8),
                    if (_lastError != null)
                      Text(_lastError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    if (_lastSuccess != null)
                      Text(_lastSuccess!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _cameraReady
                  ? CameraScannerView(isActive: true, onScanned: _onScanned)
                  : Center(
                      child: Text(
                        _lastError ?? 'Camera not ready',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tip: Scan location once, then scan multiple products. Each scan counts as 1 pick.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
