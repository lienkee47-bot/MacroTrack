# Changelog

---

## (2.0.1) - ?? March 2026

### Added
- **Dynamic Greeting**: Implemented time-based header logic ("Good morning/afternoon/evening") based on local device time.
- **Chart Annotations**: Added 1-decimal place value labels to the `7-Day Trend` line chart for better data legibility.
- **Dark Mode UI**: Added Light/Dark Mode toggle on `Profile` screen.

### Changed
- **Calorie Summary UI**: Refactored the 'Daily Status' card subtext to display an explicit "Consumed / Target" breakdown instead of just the target.

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