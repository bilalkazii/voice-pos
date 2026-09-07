/// App-wide constants for Voice POS (V1).
///
/// V1 is strictly offline-first and single-device. No backend URLs,
/// no network clients, no cloud-sync flags belong here.
abstract final class AppConstants {
  static const String appName = 'Voice POS';
  static const String applicationId = 'com.mizaantech.voice_pos';

  /// Displayed in Settings > About. Single source of truth for V1.
  static const String appVersion = '1.0.0';

  /// Currency used across the app. Money is stored as integer paise.
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  /// Fallback store name before the user configures Settings (later phase).
  static const String defaultStoreName = 'My Store';

  /// Number of fractional digits for INR (paise).
  static const int minorUnitsPerRupee = 100;
}
