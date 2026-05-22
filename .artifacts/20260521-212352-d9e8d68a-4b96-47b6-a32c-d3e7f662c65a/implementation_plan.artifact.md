# ISBN OCR Implementation Plan

Enable the app to recognize printed ISBN numbers (text) using the camera, supporting older books that lack barcodes.

## User Review Required

> [!IMPORTANT]
> This requires adding `google_ml_kit_text_recognition`. This package uses Google Play Services on Android to perform on-device OCR.
> I will implement a "Hybrid Scanner" that can detect both barcodes and printed ISBN text.

## Proposed Changes

### Dependencies

#### [pubspec.yaml](file:///C:/Users/User/Desktop/Projekte/Inventur/Kurator/inventur_app_v1/pubspec.yaml)
- Add `google_ml_kit_text_recognition: ^0.14.0` (or latest compatible).

### Scan Feature

#### [scan_screen.dart](file:///C:/Users/User/Desktop/Projekte/Inventur/Kurator/inventur_app_v1/lib/features/scan/scan_screen.dart)
- Integrate `TextRecognizer` from ML Kit.
- Update `_onDetect` or add a secondary processing loop to analyze camera frames for text.
- Use a Regular Expression to find ISBN-10 or ISBN-13 patterns in the recognized text.
- Normalize and validate found numbers using `IsbnUtils`.

## Verification Plan

### Manual Verification
- **Barcode Scan:** Verify that standard barcode scanning still works as before.
- **OCR Scan:** Hold the camera over a printed ISBN number (e.g., inside the imprint of an old book). Verify that the app vibrates and captures the ISBN correctly.
- **Workflow:** Ensure the captured ISBN is passed to the `AddItemFlowScreen` and triggers the automatic DNB lookup.
