import 'package:drift/drift.dart';

/// Application settings (schema v3), single-device key/value store.
///
/// One row per setting: `store_name`, `voice_feedback_enabled`,
/// `default_low_stock_threshold`, `printer_id`, `printer_name`.
/// Missing rows mean "never configured" — the repository applies stable
/// defaults, so a fresh install and a migrated v2 database behave the same.
class AppSettings extends Table {
  @override
  String get tableName => 'app_settings';

  TextColumn get key => text().named('key')();

  TextColumn get value => text().named('value').nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
