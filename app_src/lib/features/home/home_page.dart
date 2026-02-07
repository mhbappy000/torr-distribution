import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/storage/repos.dart';
import '../scan/scan_session_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _imported = false;
  bool _busy = false;
  String? _status;

  Future<void> _importSampleData() async {
    setState(() {
      _busy = true;
      _status = 'Importing sample data...';
    });

    try {
      final productsCsv = await rootBundle.loadString('assets/data/products.csv');
      final tasksCsv = await rootBundle.loadString('assets/data/pick_tasks.csv');
      final locBarCsv = await rootBundle.loadString('assets/data/location_barcodes.csv');

      await Repos.importProductsCsv(productsCsv);
      await Repos.importPickTasksCsv(tasksCsv);
      await Repos.importLocationBarcodesCsv(locBarCsv);

      setState(() {
        _imported = true;
        _status = 'Sample data imported successfully.';
      });
    } catch (e) {
      setState(() => _status = 'Import failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Torr Distribution')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MVP Flow', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('1) Scan Location once (e.g., CWHTR06432).'),
                    const Text('2) Pick multiple items: scan product barcode repeatedly.'),
                    const Text('3) Each product scan = qty 1. Tap “Change Location” when moving.'),
                    const SizedBox(height: 6),
                    Text('Data status: ${_imported ? "Imported" : "Not imported"}'),
                    if (_status != null) ...[
                      const SizedBox(height: 8),
                      Text(_status!),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _importSampleData,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: const Text('Import Sample Data (Assets)'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ScanSessionPage()),
                      );
                    },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Start Picking (Scan)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final summary = await Repos.getQuickSummary();
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Quick Summary'),
                          content: Text(summary),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                          ],
                        ),
                      );
                    },
              icon: const Icon(Icons.bar_chart),
              label: const Text('View Quick Summary'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tip: Update CSV files in app_src/assets/data. For real use, load tasks from ERP/API later.',
              style: TextStyle(color: Colors.black54),
            )
          ],
        ),
      ),
    );
  }
}
