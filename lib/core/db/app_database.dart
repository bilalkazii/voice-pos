import 'package:drift/drift.dart';

import 'connection.dart';
import 'dao/product_dao.dart';
import 'tables/product_tables.dart';

part 'app_database.g.dart';

/// Voice POS local database (schema v1, offline-first, single-device).
///
/// Tables: products only in Phase 1 (sales/sale_items arrive with checkout).
/// Migrations: [migration] creates the baseline plus custom uniqueness
/// indexes; [onUpgrade] is the extension point for future versions — never
/// destructive recreation during normal upgrades.
@DriftDatabase(tables: [Products], daos: [ProductDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Case-insensitive name uniqueness among active products.
          await m.database.customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS products_name_active_unique '
            'ON products (name COLLATE NOCASE) WHERE is_active = 1',
          );
          // SKU uniqueness among active products that have an SKU.
          await m.database.customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS products_sku_active_unique '
            'ON products (sku) WHERE is_active = 1 AND sku IS NOT NULL',
          );
        },
        onUpgrade: (m, from, to) async {
          // v1 is the baseline. Future schema changes add stepped
          // migrations here, e.g. `if (from < 2) { ... }`.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
