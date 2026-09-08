# Voice POS — Release Checklist

## Product

- **App:** Voice POS
- **Scope (V1):** single store · single device · offline-first · cash-only · voice-first · Android-first · 58mm Bluetooth thermal printer
- **Out of scope:** cloud backend, accounts/auth, multi-store, sync, UPI/card/wallets, payments, barcode scanning, analytics, LLM/voice AI, multilingual ESC/POS code pages, persistent Bluetooth sessions, active discovery

## Application Identity

- Application ID / package: `com.mizaantech.voice_pos` (do not change for the release series)
- Label: `Voice POS`
- Version name: `1.0.0` (pubspec `version: 1.0.0+1`)
- Build number / versionCode: `1`
- Orientation: portrait only

## Build

- Flutter 3.47.1 · Dart 3.13.1
- compileSdk 37 (required by permission_handler_android), targetSdk 36, minSdk 24
- Debug: `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`
- Release APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
- Release AAB: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`
- Release signing: `android/key.properties` (gitignored; template: `android/key.properties.example`), keystore stored **outside the repository**. Without `key.properties`, release builds **fail by design** with instructions — debug keys never sign releases.

## Automated QA

- `flutter analyze` → 0 issues
- `flutter test` → 383/383 passing
- Debug + release APK + AAB all build successfully

## Hardware (physical validation)

| Item | Status |
| --- | --- |
| Physical Android device install/smoke | PENDING — PHYSICAL VALIDATION REQUIRED |
| Real microphone / STT accuracy | PENDING — PHYSICAL VALIDATION REQUIRED |
| Real TTS audio | PENDING — PHYSICAL VALIDATION REQUIRED |
| SRS588/PSF-588 Bluetooth pairing | PENDING — PHYSICAL VALIDATION REQUIRED |
| Printer selection + persistence | PENDING — PHYSICAL VALIDATION REQUIRED (software-tested) |
| Test Print (physical paper) | PENDING — PHYSICAL VALIDATION REQUIRED |
| Real sale receipt (physical paper) | PENDING — PHYSICAL VALIDATION REQUIRED |
| Printer disconnect / retry / repeated print | PENDING — PHYSICAL VALIDATION REQUIRED (failure paths software-tested) |
| Bluetooth off / permission denied | PENDING — PHYSICAL VALIDATION REQUIRED (failure paths software-tested) |
| Background/resume on device | PENDING — PHYSICAL VALIDATION REQUIRED |
| Overnight/date boundary on device | PENDING — PHYSICAL VALIDATION REQUIRED (boundary logic software-tested) |

Emulator validation completed (Pixel 10a AVD, API 37): launch, permissions-contextual, catalog, cart math, checkout, receipt, history, reports, persistence across restart, print-failure paths.

## Known Limitations (V1 by design)

- No physical hardware validation yet (see table above)
- ESC/POS receipt is ASCII-safe (`₹ → Rs.`); no multilingual code pages
- Printer setup lists paired devices only; no active discovery
- Bluetooth connects per print; no persistent printer session
- No cloud sync; all data in local SQLite (`schemaVersion 3`, persistent app storage)
- Single device / single store / cash only
- `print_bluetooth_thermal`-declared `INTERNET` and `BLUETOOTH_SCAN` are stripped from the merged manifest; revisit only if a real release defect proves otherwise

## Release Gate

- **ENGINEERING RELEASE READY** — all automated gates pass, release configuration and signing path complete, artifacts reproducible from repo + externally stored keystore.
- **PUBLIC RELEASE READY** — NOT YET. Requires: production keystore signing, and every PENDING hardware row above passing on a physical device with the physical SRS588 producing real paper receipts.

### Signing replacement steps (before public release)

1. Create/obtain the production keystore **outside the repository**.
2. `copy android/key.properties.example android/key.properties` and fill production values (PKCS12: `storePassword` must equal `keyPassword`).
3. `flutter build apk --release` and `flutter build appbundle --release`; verify with `apksigner verify --print-certs` that the signer DN is the production identity, not a test key.
4. Keep the production keystore + passwords backed up outside Git.
