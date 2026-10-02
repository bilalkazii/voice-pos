# Voice POS

A voice-operated point-of-sale app for small shops. The cashier **speaks**
commands â€” "add two milk", "checkout", "cancel" â€” and the app runs the entire
sale without touch-heavy input.

Speech-to-text captures the utterance, a rule-based command parser plus a fuzzy
product matcher resolve it against the catalog, text-to-speech speaks the
confirmation, and the cart â†’ checkout â†’ payment flow records the sale.

**Offline by design.** There is no backend and no server. Everything persists
locally in SQLite via Drift. The `INTERNET` and `BLUETOOTH_SCAN` permissions
are stripped from the merged release manifest.

---

## Features

**Voice control**
- `speech_to_text` for capture, `flutter_tts` for spoken confirmations
- A rule-based command parser mapping normalized speech to typed commands
- Fuzzy product matching against the catalog
- Multilingual command vocabulary and localized TTS feedback
- Multilingual voice preferences in Settings

**Products**
- Full CRUD with name, price, and stock
- Catalog browsing and search

**Cart & checkout**
- Cash-only checkout with change calculation
- Quantity and per-line adjustments

**Sales history**
- Sale list with day filters
- Per-sale detail view

**Reports**
- Date-range summary
- Top-selling products

**Printing**
- Bluetooth SPP thermal receipt printers
- A hand-written pure-Dart **ESC/POS encoder** supporting 58/80-column receipts
- Print job queue with retry, timeout, dedupe and reprint
- A graceful fallback so the app degrades instead of crashing when no printer
  is available or the platform is unsupported

**Settings**
- Printer configuration
- Voice and language preferences

---

## Tech stack

| Layer | Choice |
| --- | --- |
| Framework | Flutter, Dart `^3.13.1` |
| State | Riverpod 3.4 |
| Navigation | go_router 18 |
| Database | Drift 2.34 over `sqlite3` / `sqlite3_flutter_libs` |
| Codegen | `build_runner` + `drift_dev` |
| Speech | `speech_to_text` 7.4, `flutter_tts` 4.2 |
| Printing | `print_bluetooth_thermal` + a custom ESC/POS encoder |
| Permissions | `permission_handler` 13 |
| Meta | `package_info_plus` |
| Testing | `flutter_test` â€” **37 test files, 383 tests** |
| Lint | `flutter_lints` 6 |

---

## Architecture

Feature-first, with a shared `core` layer.

```
lib/
  main.dart, app.dart
  core/
    constants.dart
    db/
      app_database.dart + .g.dart     Drift database (generated)
      dao/                            product_dao, sale_dao, settings_dao
      tables/                         product, sale, settings table definitions
    errors/failures.dart              Result/failure types
    printing/
      domain/                         PrinterService interface, receipt data,
                                      result type, receipt mapper
      data/                           Bluetooth + unavailable implementations
      esc_pos/esc_pos_encoder.dart    hand-written ESC/POS byte builder
      presentation/print_controller.dart
      bluetooth/                      transport + SPP implementation
    router/app_router.dart
    theme/                            app_theme, design tokens
    utils/                            money, today
  features/
    voice/
      domain/                         command_parser (the largest source file),
                                      product_matcher, voice_command,
                                      voice_vocabulary, voice_feedback_text,
                                      voice_language
      data/                           stt_speech_service, tts_feedback_service
      presentation/                   voice_providers
    products/  domain Â· data Â· presentation
    cart/      domain Â· presentation
    checkout/  domain Â· data Â· presentation
    history/   domain Â· presentation
    reports/   domain Â· data Â· presentation
    settings/  domain Â· data Â· presentation
test/                                     37 files, 383 tests
```

### Design notes

**`PrinterService` is an interface, not a platform call.** There is a Bluetooth
implementation and an `UnavailablePrinterService` fallback, so every screen that
can print works on a device with no paired printer, and on non-Android targets.
Printing is therefore testable without hardware.

**The ESC/POS encoder is first-party.** `print_bluetooth_thermal` is used for
the Bluetooth transport, but the receipt byte construction is hand-written â€”
58- and 80-column layouts, cut and feed commands â€” so receipt formatting is
fully unit-testable. `test/core/printing/esc_pos_encoder_test.dart` covers it.

**Speech is behind interfaces too.** `SpeechServices` abstracts both STT and
TTS, and `test/features/voice/fakes.dart` provides a fake, so the command parser
and voice state machine are tested without a microphone.

**`command_parser.dart` is the heart of the app** at roughly 20 KB. It maps
normalized speech text to `VoiceCommand` values and is the most heavily tested
component.

---

## Installation

Requires **Flutter** with Dart `^3.13.1`.

```bash
git clone https://github.com/<owner>/voice-pos.git
cd voice-pos
flutter pub get
```

There is no backend to install and no environment variables to configure.

## Configuration

All configuration is in-app under **Settings** â€” printer pairing, voice
language, and TTS preferences. Nothing is read from the environment and no
`.env` file exists or is needed.

### Release signing

Release builds are signed through `android/key.properties`, which is
**gitignored**. A placeholder template is provided:

```bash
cp android/key.properties.example android/key.properties
```

Then fill in `storePassword`, `keyPassword`, `keyAlias` and `storeFile`. The
keystore file itself belongs **outside** the repository. Changing the signing key
breaks updates for already-installed builds.

## Running locally

```bash
flutter run
```

Speech recognition and Bluetooth printing both require a **physical Android
device** â€” emulators generally will not exercise either path.

## Testing

```bash
flutter test
```

The suite covers the command parser, product matching, TTS feedback, cart and
checkout services, sale and product repositories, reports, settings, the
settings domain and widgets, the database and table definitions, and the whole
printing stack (encoder, Bluetooth service, print controller, retry logic,
receipt mapper, and print widgets).

Code generation must be current before the database tests will pass:

```bash
dart run build_runner build
```

## Building for production

```bash
flutter analyze                       # must be clean
flutter build apk --release
flutter build appbundle --release     # for Play Store upload
```

Release signing uses `android/key.properties` â€” see above.

---

## Project structure

| Path | Contents |
| --- | --- |
| `lib/core/db/` | Drift database, DAOs and table definitions (`.g.dart` is generated) |
| `lib/core/printing/` | Printer interface, Bluetooth + fallback implementations, ESC/POS encoder |
| `lib/core/theme/` | Theme and design tokens |
| `lib/features/voice/` | Command parser, product matcher, multilingual vocabulary, STT/TTS |
| `lib/features/products/` `cart/` `checkout/` `history/` `reports/` `settings/` | Feature modules, each split domain Â· data Â· presentation |
| `test/` | 37 test files, 383 tests |
| `android/` | Android host project |

`lib/core/db/*.g.dart` files are generated by `build_runner` and **are**
committed, so the project can be built without running codegen first.

