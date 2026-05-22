import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/isbn_utils.dart';
import 'ocr_review_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.seriesMode = false});

  final bool seriesMode;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _handled = false;
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSuccess(String isbn13) {
    if (_handled) return;
    setState(() => _handled = true);
    HapticFeedback.mediumImpact();
    context.pop<String>(isbn13);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      for (final barcode in barcodes) {
        final raw = barcode.rawValue;
        if (raw == null || raw.isEmpty) continue;
        final normalized = IsbnUtils.normalizeInput(raw);
        final parsed = IsbnUtils.parseAndSplit(normalized);
        if (parsed?.isbn13 != null) {
          _handleSuccess(parsed!.isbn13!);
          return;
        }
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_handled) return;
    
    // Scanner pausieren während die Kamera-App offen ist
    await _controller.stop();
    
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (photo != null && mounted) {
        // Wechsel zum neuen Review-Bildschirm
        final String? resultIsbn = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (ctx) => OcrReviewScreen(imagePath: photo.path),
          ),
        );

        if (resultIsbn != null && mounted) {
          _handleSuccess(resultIsbn);
        }
      }
    } catch (e) {
      debugPrint('Foto-Fehler: $e');
    } finally {
      if (mounted && !_handled) {
        await _controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          
          const QrScannerOverlay(
            borderColor: Colors.white,
            borderRadius: 16,
            borderLength: 40,
            borderWidth: 4,
            cutOutSize: 280,
          ),

          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => context.pop(),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Barcode automatisch oder Foto-Modus',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white12,
                      child: IconButton(
                        icon: ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            return Icon(
                              state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                              color: Colors.white,
                            );
                          },
                        ),
                        onPressed: () => _controller.toggleTorch(),
                      ),
                    ),
                    
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        height: 90,
                        width: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 45),
                      ),
                    ),

                    const SizedBox(width: 56),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QrScannerOverlay extends StatelessWidget {
  const QrScannerOverlay({
    super.key,
    this.borderColor = Colors.white,
    this.borderWidth = 4.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 150),
    this.borderRadius = 16,
    this.borderLength = 40,
    this.cutOutSize = 280,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: borderColor,
          borderWidth: borderWidth,
          overlayColor: overlayColor,
          borderRadius: borderRadius,
          borderLength: borderLength,
          cutOutSize: cutOutSize,
        ),
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 4.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 150),
    this.borderRadius = 16,
    this.borderLength = 40,
    this.cutOutSize = 280,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final backgroundPaint = Paint()..color = overlayColor;
    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - cutOutSize / 2,
      rect.top + height / 2 - cutOutSize / 2,
      cutOutSize,
      cutOutSize,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius))),
      ),
      backgroundPaint,
    );

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();
    path.moveTo(cutOutRect.left, cutOutRect.top + borderLength);
    path.lineTo(cutOutRect.left, cutOutRect.top + borderRadius);
    path.arcToPoint(Offset(cutOutRect.left + borderRadius, cutOutRect.top), radius: Radius.circular(borderRadius));
    path.lineTo(cutOutRect.left + borderLength, cutOutRect.top);
    path.moveTo(cutOutRect.right - borderLength, cutOutRect.top);
    path.lineTo(cutOutRect.right - borderRadius, cutOutRect.top);
    path.arcToPoint(Offset(cutOutRect.right, cutOutRect.top + borderRadius), radius: Radius.circular(borderRadius));
    path.lineTo(cutOutRect.right, cutOutRect.top + borderLength);
    path.moveTo(cutOutRect.right, cutOutRect.bottom - borderLength);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius);
    path.arcToPoint(Offset(cutOutRect.right - borderRadius, cutOutRect.bottom), radius: Radius.circular(borderRadius));
    path.lineTo(cutOutRect.right - borderLength, cutOutRect.bottom);
    path.moveTo(cutOutRect.left + borderLength, cutOutRect.bottom);
    path.lineTo(cutOutRect.left + borderRadius, cutOutRect.bottom);
    path.arcToPoint(Offset(cutOutRect.left, cutOutRect.bottom - borderRadius), radius: Radius.circular(borderRadius));
    path.lineTo(cutOutRect.left, cutOutRect.bottom - borderLength);

    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
