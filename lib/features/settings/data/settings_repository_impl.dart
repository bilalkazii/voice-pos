import '../../../core/db/dao/settings_dao.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

/// Drift-backed [SettingsRepository]. Key/value rows in `app_settings`;
/// each setter writes exactly one key, so partial updates never disturb
/// unrelated settings and existing products/sales are never touched.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._dao);

  final SettingsDao _dao;

  static const String keyStoreName = 'store_name';
  static const String keyVoiceFeedback = 'voice_feedback_enabled';
  static const String keyDefaultThreshold = 'default_low_stock_threshold';
  static const String keyPrinterId = 'printer_id';
  static const String keyPrinterName = 'printer_name';

  @override
  Future<AppSettings> load() async {
    final rows = await _dao.getAll();
    return _assemble({for (final r in rows) r.key: r.value});
  }

  @override
  Stream<AppSettings> watch() {
    return _dao.watchAll().map(
          (rows) => _assemble({for (final r in rows) r.key: r.value}),
        );
  }

  @override
  Future<void> saveStoreName(String name) async {
    final trimmed = AppSettings.validateStoreName(name);
    await _dao.setValue(keyStoreName, trimmed);
  }

  @override
  Future<void> setVoiceFeedbackEnabled(bool enabled) {
    return _dao.setValue(keyVoiceFeedback, enabled ? '1' : '0');
  }

  @override
  Future<void> setDefaultLowStockThreshold(int threshold) async {
    AppSettings.validateThreshold(threshold);
    await _dao.setValue(keyDefaultThreshold, '$threshold');
  }

  @override
  Future<void> setPrinterSelection({String? id, String? name}) async {
    await _dao.setValue(keyPrinterId, id?.trim().isEmpty == true ? null : id?.trim());
    await _dao.setValue(
      keyPrinterName,
      name?.trim().isEmpty == true ? null : name?.trim(),
    );
  }

  AppSettings _assemble(Map<String, String?> values) {
    final threshold = int.tryParse(values[keyDefaultThreshold] ?? '');
    return AppSettings(
      storeName: (values[keyStoreName] ?? '').trim().isEmpty
          ? AppSettings.defaults.storeName
          : values[keyStoreName]!.trim(),
      voiceFeedbackEnabled: (values[keyVoiceFeedback] ?? '1') != '0',
      defaultLowStockThreshold:
          threshold == null || threshold < 0
              ? AppSettings.defaults.defaultLowStockThreshold
              : threshold,
      selectedPrinterId: _blankToNull(values[keyPrinterId]),
      selectedPrinterName: _blankToNull(values[keyPrinterName]),
    );
  }

  String? _blankToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
