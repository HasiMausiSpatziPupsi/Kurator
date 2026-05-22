import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isProcessingText = false;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  void _handleSuccess(String isbn13) {
    if (_handled) return;
    setState(() => _handled = true);

    // Haptisches Feedback für den "Ein-Hand-Fluss"
    HapticFeedback.mediumImpact();

    context.pop<String>(isbn13);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final normalized = IsbnUtils.normalizeInput(raw);
    final parsed = IsbnUtils.parseAndSplit(normalized);
    if (parsed?.isbn13 != null) {
      _handleSuccess(parsed!.isbn13!);
    }
  }

  /// OCR-Verarbeitung der Kamera-Frames
  Future<void> _processImage(BarcodeCapture capture) async {
    if (_handled || _isProcessingText) return;

    final image = capture.image;
    if (image == null) return;

    setState(() => _isProcessingText = true);

    try {
      final InputImage inputImage = InputImage.fromBytes(
        bytes: image,
        metadata: InputImageMetadata(
          size: Size(capture.width!, capture.height!),
          rotation: InputImageRotation.rotation0deg, // MobileScanner liefert oft bereits rotierte Bytes
          format: InputImageFormat.nv21, // Standard für Android MobileScanner
          bytesPerRow: capture.width!.toInt(),
        ),
      );

      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // Suche nach ISBN-Mustern im erkannten Text
      final String fullText = recognizedText.text;

      // Regulärer Ausdruck für ISBN-10 oder ISBN-13 (grob)
      final isbnRegex = RegExp(r'(?:ISBN(?:-1[03])?:?\s*)?((?:\d[\s-]?){9,13}[\dX])', caseSensitive: false);
      final matches = isbnRegex.allMatches(fullText);

      for (final match in matches) {
        final potentialIsbn = match.group(1);
        if (potentialIsbn != null) {
          final normalized = IsbnUtils.normalizeInput(potentialIsbn);
          final parsed = IsbnUtils.parseAndSplit(normalized);
          if (parsed?.isbn13 != null) {
            _handleSuccess(parsed!.isbn13!);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('OCR Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingText = false);
      }
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
            onDetect: (capture) {
              _onDetect(capture);
              // Zusätzlich OCR versuchen
              // ignore: discarded_futures
              _processImage(capture);
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.seriesMode
                          ? 'Richte die Kamera auf den Barcode oder die gedruckte ISBN.'
                          : 'EAN/ISBN-Barcode oder gedruckte ISBN erfassen.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Handy vibriert bei Erfolg.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
