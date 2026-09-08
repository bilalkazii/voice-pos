import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/db/dao/settings_dao.dart';
import '../../../core/errors/failures.dart';
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

  /// Single serialized printer selection (`{"address":…,"name":…}`).
  /// One row = one atomic upsert, so a stored selection can never be a
  /// half-written id-without-name pair.
  static const String keyPrinterSelection = 'printer_selection';

  /// Legacy Phase 7 split keys. Never written anymore; still honored on
  /// read so databases configured by older builds keep working, and are
  /// cleared whenever the selection is rewritten.
  @visibleForTesting
  static const String legacyKeyPrinterId = 'printer_id';
  @visibleForTesting
  static const String legacyKeyPrinterName = 'printer_name';

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

  /// Persists a printer selection atomically: blank ids clear back to
  /// unconfigured (preserving the long-standing Phase 7 behavior), while a
  /// valid address is stored as ONE serialized row plus legacy cleanup in a
  /// single database transaction — readers can never observe id-without-name.
  /// Throws [ValidationFailure] for malformed addresses; nothing is written
  /// in that case.
  @override
  Future<void> setPrinterSelection({String? id, String? name}) async {
    final address = id?.trim() ?? '';
    if (address.isEmpty) {
      await _dao.writePrinterSelectionAtomic(
        combined: null,
        combinedKey: keyPrinterSelection,
        legacyKeys: const [legacyKeyPrinterId, legacyKeyPrinterName],
      );
      return;
    }
    _validateMacAddress(address);
    final normalizedName =
        name?.trim().isEmpty == true ? null : name!.trim();
    await _dao.writePrinterSelectionAtomic(
      combined: jsonEncode({'address': address, 'name': normalizedName}),
      combinedKey: keyPrinterSelection,
      legacyKeys: const [legacyKeyPrinterId, legacyKeyPrinterName],
    );
  }

  /// Classic-Bluetooth MAC as reported by Android
  /// (`AA:BB:CC:DD:EE:FF`, case-insensitive).
  static final _macPattern =
      RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');

  static void _validateMacAddress(String address) {
    if (!_macPattern.hasMatch(address)) {
      throw const ValidationFailure(
        message: 'Invalid printer address.',
      );
    }
  }

  AppSettings _assemble(Map<String, String?> values) {
    final threshold = int.tryParse(values[keyDefaultThreshold] ?? '');
    final printer = _printerSelection(values);
    return AppSettings(
      storeName: (values[keyStoreName] ?? '').trim().isEmpty
          ? AppSettings.defaults.storeName
          : values[keyStoreName]!.trim(),
      voiceFeedbackEnabled: (values[keyVoiceFeedback] ?? '1') != '0',
      defaultLowStockThreshold:
          threshold == null || threshold < 0
              ? AppSettings.defaults.defaultLowStockThreshold
              : threshold,
      selectedPrinterId: printer.id,
      selectedPrinterName: printer.name,
    );
  }

  /// Printer identity, preferring the atomic serialized row and falling
  /// back to the legacy Phase 7 split pair. Corrupt values degrade to
  /// unconfigured instead of crashing.
  ({String? id, String? name}) _printerSelection(
    Map<String, String?> values,
  ) {
    final parsed = _parseSelection(values[keyPrinterSelection]);
    if (parsed != null) return parsed;
    return (
      id: _blankToNull(values[legacyKeyPrinterId]),
      name: _blankToNull(values[legacyKeyPrinterName]),
    );
  }

  /// Parses one serialized selection, or null when absent/corrupt. A valid
  /// address is required; the name is optional.
  ({String? id, String? name})? _parseSelection(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final address = decoded['address'];
        if (address is String && _macPattern.hasMatch(address)) {
          return (
            id: address,
            name: _blankToNull(decoded['name'] as String?),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  String? _blankToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
