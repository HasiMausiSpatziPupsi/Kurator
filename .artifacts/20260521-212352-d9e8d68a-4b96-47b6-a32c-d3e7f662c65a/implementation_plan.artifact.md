# Refined "Capture & Review" Workflow Plan

Transform the scanning process into a multi-step "Capture & Review" flow to eliminate deadlocks and provide full user control over ISBN extraction.

## Proposed Changes

### 1. Scan Feature (The Capture Phase)

#### [scan_screen.dart](file:///C:/Users/User/Desktop/Projekte/Inventur/Kurator/inventur_app_v1/lib/features/scan/scan_screen.dart)
- **Thumb-Friendly UI:** Move Flash and Capture buttons to the bottom third of the screen.
- **Capture Logic:** When the button is pressed, grab the current frame and immediately navigate to the new `OcrReviewScreen` with the image data.
- **No Background OCR:** Stop trying to read text in real-time to prevent lag and focus on getting a sharp "shot".

### 2. NEW Review Feature (The Processing Phase)

#### [NEW] [ocr_review_screen.dart](file:///C:/Users/User/Desktop/Projekte/Inventur/Kurator/inventur_app_v1/lib/features/scan/ocr_review_screen.dart)
- **Visual Confirmation:** Display the captured image prominently.
- **Action Buttons:**
    - "Text erkennen": Trigger ML Kit OCR on the static image.
    - "Manuelle Eingabe": Focus a text field if OCR fails or needs correction.
- **Integration:** Once an ISBN is confirmed (via OCR or manual), proceed to the `AddItemFlowScreen`.

### 3. Navigation & Providers

#### [router.dart](file:///C:/Users/User/Desktop/Projekte/Inventur/Kurator/inventur_app_v1/lib/router/router.dart) (Assumption)
- Register the new `OcrReviewScreen` route.

---

## Verification Plan

### Manual Verification
1. **Capture:** Open scanner, turn on light (bottom button), and take a photo of an ISBN.
2. **Review:** Observe the new screen showing your photo.
3. **OCR:** Tap "Text erkennen" and verify that the ISBN field is populated correctly.
4. **Correction:** Manually edit a digit in the ISBN field.
5. **Finish:** Tap "Übernehmen" and verify it leads to the DNB-enriched Add screen.
