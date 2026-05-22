# Task Management

- [x] Research DNB SRU API and implementation details
- [x] Create implementation plan for DNB integration
- [x] Implement `DnbService`
- [x] Update `MetadataAggregator` to include DNB
- [x] Register `DnbService` in providers
- [x] Verify DNB lookup functionality
- [x] Optimize for One-Hand-Flow
	- [x] Remove dialogs from `ScanScreen`
	- [x] Add haptic feedback to `ScanScreen`
	- [x] Implement automatic metadata lookup in `AddItemFlowScreen`
- [x] Implement ISBN OCR (Optical Character Recognition)
	- [x] Add `google_ml_kit_text_recognition` dependency
	- [x] Integrate Text Recognition into `ScanScreen`
	- [x] Implement ISBN regex extraction from recognized text
	- [x] Verify OCR functionality
