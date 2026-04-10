# Changelog

---

## [2.1.2] - 10 April 2026

### Fixed
- **Image-to-Text OCR**: Fixed recent functionality loss due to Firestore security rules update.

---

## [2.1.1] - 27 March 2026

### Added
- **User Reminder**: Added reminder message to verify data before saving to Food Library if user is registering with Barcode/QR Scanner or Image-to-Text method.

### Changed
- **Image-to-Text OCR**: Refactored OCR mechanism from on-device ML kit to cloud-based multimodal Gemini AI pipeline via Firebase Extension.

### Fixed
- **Barcode/QR scanner**: Fixed connection to FatSecret's API allowing for US-region barcode search.

---

## [2.1.0] - 23 March 2026

### Added
- **Food Library**: Added 2 alternative ways to register food item into Food Library - scanning barcode/QR code and image-to-text macro data extraction. Feature under improvement, effectiveness may vary.
- **Dark Mode UI**: Added Dark Mode across the app. Light/Dark Mode toggle on `Profile` screen.
- **Profile Picture**: Enabled user's profile picture update and removal.
- **Dynamic Greeting**: Implemented time-based `Dashboard` header logic ("Good morning/afternoon/evening") based on local device time.
- **Chart Label**: Added 1-decimal place value labels to the 7-Day Trend line chart for better data legibility.

### Changed
- **Calorie Summary UI**: Refactored the Daily Status card subtext to display an explicit "Consumed / Target" breakdown instead of just the target.

### Fixed
- **Pixel Overflow Error**: Resolved a "Bottom Overflowed" UI bug on the `Database` screen.

---

## [2.0.0] - 13 March 2026

### Added
- **Version Traceability**: Version label on `Sign-up/Login` and `Profile` screens.

### Security
- **Private Food Library**: Migrated the `foods` Food Library from a global root collection to a user-specific sub-collection path: `foods/{uid}/userFoods/`.
- **Legacy Data Management**: Implemented one-time migration script to seamlessly transition existing legacy data into the new private silos without service interruption or data loss.

---

## [1.0.0] - 12 March 2026

### Added
- Configured Firebase connection for Android.
- **`Sign-up/Login`:** Secure Email & Password authentication via Firebase Auth with real-time validation.
- **`Dashboard`:** Interactive real-time data visualization. 
- **`Log`:** Daily meal logging with date toggle, connected to Food Library via Firestore. Enabled CRUD operations on logged items.
- **`Database`:** Macro targets specifications, Food Library display, search filter and CRUD operations.
- **`Profile`:** Personal stats specifications, secure Change Password flow with Firebase Auth.
- Custom app icons and label.