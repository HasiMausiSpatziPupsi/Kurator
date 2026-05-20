import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/isbn_utils.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.seriesMode = false});

  /// Nach Scan Dialog: mehrere Bücher nacheinander.
  final bool seriesMode;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _handled = false;

  Future<void> _finishSeriesScan(String isbn13) async {
    final action = await showDialog<_SeriesAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('ISBN erkannt'),
        content: SelectableText(isbn13),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _SeriesAction.another),
            child: const Text('Weiter scannen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _SeriesAction.take),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _SeriesAction.take:
        context.pop<String>(isbn13);
      case _SeriesAction.another:
      case null:
        setState(() => _handled = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final normalized = IsbnUtils.normalizeInput(raw);
    final parsed = IsbnUtils.parseAndSplit(normalized);
    if (parsed?.isbn13 == null) {
      return;
    }

    setState(() => _handled = true);
    final isbn13 = parsed!.isbn13!;
    if (widget.seriesMode) {
      // ignore: discarded_futures
      _finishSeriesScan(isbn13);
    } else {
      context.pop<String>(isbn13);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.seriesMode ? 'ISBN (Serie)' : 'ISBN scannen'),
        actions: [
          IconButton(
            tooltip: 'Schließen',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.seriesMode
                      ? 'Nach jedem Scan kannst du übernehmen oder weiter scannen.'
                      : 'EAN/ISBN-Barcode erfassen. Es wird nur eine gültige '
                          'ISBN-10 oder ISBN-13 akzeptiert.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SeriesAction { take, another }
