import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/settings_tables.dart';

part 'settings_dao.g.dart';

/// Key/value persistence for app settings. Stores raw strings only —
/// parsing, defaults, and validation live in the settings repository and
/// domain layers.
@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Raw value for [key], or null when never configured.
  Future<String?> getValue(String key) {
    return (select(appSettings)..where((t) => t.key.equals(key)))
        .map((row) => row.value)
        .getSingleOrNull();
  }

  /// Reactive raw value for [key] (null = never configured).
  Stream<String?> watchValue(String key) {
    return (select(appSettings)..where((t) => t.key.equals(key)))
        .map((row) => row.value)
        .watchSingleOrNull();
  }

  /// All stored rows (used to assemble the full settings snapshot).
  Stream<List<AppSetting>> watchAll() {
    return select(appSettings).watch();
  }

  Future<List<AppSetting>> getAll() {
    return select(appSettings).get();
  }

  /// Upserts [key]. A null [value] clears the row back to "never
  /// configured" (falls back to the stable default).
  Future<void> setValue(String key, String? value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: Value(value)),
    );
  }
}
