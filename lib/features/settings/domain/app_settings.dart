import '../../../core/constants.dart';
import '../../../core/errors/failures.dart';
import '../../voice/domain/voice_language.dart';

/// Immutable app settings. Pure Dart — no Flutter, no Drift.
///
/// Persisted locally via [SettingsRepository]; missing rows fall back to
/// [defaults] so fresh installs and migrated databases behave identically.
/// The printer selection is a configuration boundary for the future printer
/// phase — null means "not configured", never fake data.
class AppSettings {
  const AppSettings({
    required this.storeName,
    required this.voiceFeedbackEnabled,
    required this.voiceLanguage,
    required this.defaultLowStockThreshold,
    required this.selectedPrinterId,
    required this.selectedPrinterName,
  });

  static const int maxStoreNameLength = 60;

  static const AppSettings defaults = AppSettings(
    storeName: AppConstants.defaultStoreName,
    voiceFeedbackEnabled: true,
    voiceLanguage: VoiceLanguage.english,
    defaultLowStockThreshold: 5,
    selectedPrinterId: null,
    selectedPrinterName: null,
  );

  final String storeName;
  final bool voiceFeedbackEnabled;
  final VoiceLanguage voiceLanguage;
  final int defaultLowStockThreshold;
  final String? selectedPrinterId;
  final String? selectedPrinterName;

  bool get hasPrinterConfigured => selectedPrinterId != null;

  AppSettings copyWith({
    String? storeName,
    bool? voiceFeedbackEnabled,
    VoiceLanguage? voiceLanguage,
    int? defaultLowStockThreshold,
    String? selectedPrinterId,
    String? selectedPrinterName,
    bool clearPrinter = false,
  }) {
    return AppSettings(
      storeName: storeName ?? this.storeName,
      voiceFeedbackEnabled: voiceFeedbackEnabled ?? this.voiceFeedbackEnabled,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
      defaultLowStockThreshold:
          defaultLowStockThreshold ?? this.defaultLowStockThreshold,
      selectedPrinterId:
          clearPrinter ? null : (selectedPrinterId ?? this.selectedPrinterId),
      selectedPrinterName: clearPrinter
          ? null
          : (selectedPrinterName ?? this.selectedPrinterName),
    );
  }

  /// Validates a store name AFTER trimming. Throws [ValidationFailure] for
  /// blank or overlong input. Returns the trimmed value to persist.
  static String validateStoreName(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure(
        message: 'Store name cannot be blank.',
      );
    }
    if (trimmed.length > maxStoreNameLength) {
      throw ValidationFailure(
        message:
            'Store name must be $maxStoreNameLength characters or fewer.',
      );
    }
    return trimmed;
  }

  /// Validates a default low-stock threshold. Throws [ValidationFailure]
  /// for negative values.
  static int validateThreshold(int value) {
    if (value < 0) {
      throw const ValidationFailure(
        message: 'Threshold cannot be negative.',
      );
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          storeName == other.storeName &&
          voiceFeedbackEnabled == other.voiceFeedbackEnabled &&
          voiceLanguage == other.voiceLanguage &&
          defaultLowStockThreshold == other.defaultLowStockThreshold &&
          selectedPrinterId == other.selectedPrinterId &&
          selectedPrinterName == other.selectedPrinterName;

  @override
  int get hashCode => Object.hash(
        storeName,
        voiceFeedbackEnabled,
        voiceLanguage,
        defaultLowStockThreshold,
        selectedPrinterId,
        selectedPrinterName,
      );
}
