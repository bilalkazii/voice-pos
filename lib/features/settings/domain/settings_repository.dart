import 'app_settings.dart';
import '../../voice/domain/voice_language.dart';

/// Settings persistence contract. Exposes the domain model only — never
/// Drift rows. Partial updates write a single key each; unwritten keys
/// always read back as stable defaults.
abstract class SettingsRepository {
  /// Current settings, with defaults for anything never configured.
  Future<AppSettings> load();

  /// Live settings; emits on every persisted change.
  Stream<AppSettings> watch();

  /// Validates, trims, and persists the store name.
  /// Throws [ValidationFailure] for blank/overlong input.
  Future<void> saveStoreName(String name);

  Future<void> setVoiceFeedbackEnabled(bool enabled);

  Future<void> setVoiceLanguage(VoiceLanguage language);

  /// Throws [ValidationFailure] for negative values.
  Future<void> setDefaultLowStockThreshold(int threshold);

  /// Persists an actual printer selection (future printer phase).
  /// Null arguments clear the selection back to unconfigured.
  Future<void> setPrinterSelection({String? id, String? name});
}
