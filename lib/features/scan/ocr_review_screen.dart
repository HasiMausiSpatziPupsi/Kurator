import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../utils/isbn_utils.dart';

class OcrReviewScreen extends StatefulWidget {
  const OcrReviewScreen({
    super.key,
    required this.imagePath,
  });

  final String imagePath;

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  final _isbnController = TextEditingController();
  bool _isProcessing = false;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  int _turns = 0;

  @override
  void dispose() {
    _isbnController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  /// Hochgradig flexible Extraktion für ISBN-10 und ISBN-13
  String? _extractSmartIsbn(String text) {
    // Wir extrahieren erst einmal alles, was wie eine Ziffernsequenz aussieht.
    // Ein ISBN-10 Kandidat wie 3-423-05921-4 hat inkl. Bindestrichen 13 Zeichen.
    // Ein ISBN-13 Kandidat hat 13-17 Zeichen.
    
    // Wir bereinigen den Text von Zeilenumbrüchen für die Analyse
    final normalizedText = text.replaceAll('\n', ' ').toUpperCase();
    
    // Regex für alles, was Ziffern, Bindestriche oder Leerzeichen enthält (min 10 Zeichen)
    // Wir sind hier extrem großzügig, um keine Formate zu verpassen.
    final candidateRegex = RegExp(r'([0-9][0-9\s\-]{8,15}[0-9X])');
    final matches = candidateRegex.allMatches(normalizedText);

    for (final match in matches) {
      String rawMatch = match.group(1) ?? '';
      // Alles außer Ziffern und X entfernen
      final digitsOnly = IsbnUtils.normalizeInput(rawMatch);
      
      // Jetzt prüfen wir systematisch alle Fenster in dieser Ziffernkette
      // (Falls die OCR z.B. eine Telefonnummer oder ein Datum mit erfasst hat)
      
      // 1. Suche nach ISBN-13 (Fenster von 13 Ziffern)
      for (int i = 0; i <= digitsOnly.length - 13; i++) {
        final sub = digitsOnly.substring(i, i + 13);
        if (IsbnUtils.isValidIsbn13(sub)) {
          debugPrint('Smarte OCR: Valid ISBN-13 gefunden: $sub');
          return sub;
        }
      }
      
      // 2. Suche nach ISBN-10 (Fenster von 10 Ziffern)
      for (int i = 0; i <= digitsOnly.length - 10; i++) {
        final sub = digitsOnly.substring(i, i + 10);
        if (IsbnUtils.isValidIsbn10(sub)) {
          debugPrint('Smarte OCR: Valid ISBN-10 gefunden: $sub');
          // Wir konvertieren für die App direkt zu ISBN-13, falls gewünscht
          return IsbnUtils.isbn10ToIsbn13(sub) ?? sub;
        }
      }
    }
    
    // LETZTER VERSUCH: Falls gar nichts gefunden wurde, prüfen wir den gesamten 
    // bereinigten Textblock auf jede mögliche 10er oder 13er Kombination.
    final allDigits = IsbnUtils.normalizeInput(normalizedText);
    if (allDigits.length >= 10) {
      for (int i = 0; i <= allDigits.length - 13; i++) {
        final sub = allDigits.substring(i, i + 13);
        if (IsbnUtils.isValidIsbn13(sub)) return sub;
      }
      for (int i = 0; i <= allDigits.length - 10; i++) {
        final sub = allDigits.substring(i, i + 10);
        if (IsbnUtils.isValidIsbn10(sub)) return IsbnUtils.isbn10ToIsbn13(sub) ?? sub;
      }
    }

    return null;
  }

  Future<void> _runOcr() async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final inputImage = InputImage.fromFilePath(widget.imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      debugPrint('OCR Rohtext:\n${recognizedText.text}');

      final foundIsbn = _extractSmartIsbn(recognizedText.text);

      if (mounted) {
        if (foundIsbn != null) {
          _isbnController.text = foundIsbn;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ISBN erkannt und geprüft!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine gültige ISBN gefunden. Prüfe Bildschärfe oder tippe händisch.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ISBN extrahieren'),
        actions: [
          IconButton(
            tooltip: 'Bild drehen',
            onPressed: () {
              setState(() {
                _turns = (_turns + 1) % 4;
              });
              HapticFeedback.lightImpact();
            },
            icon: const Icon(Icons.rotate_right),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RotatedBox(
                  quarterTurns: _turns,
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            if (_isProcessing)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _runOcr,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('ISBN im Foto suchen'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
            
            const SizedBox(height: 24),
            TextField(
              controller: _isbnController,
              decoration: const InputDecoration(
                labelText: 'Gefundene ISBN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
                hintText: 'Hier steht das Ergebnis...',
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 32),
            
            FilledButton.icon(
              onPressed: () {
                final isbn = _isbnController.text.trim();
                if (isbn.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bitte ISBN eingeben.')),
                  );
                  return;
                }
                Navigator.of(context).pop(isbn);
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Metadaten laden'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Abbrechen'),
            ),
          ],
        ),
      ),
    );
  }
}
