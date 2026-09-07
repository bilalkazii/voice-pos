import 'package:drift/drift.dart';

import 'connection.dart';
import 'dao/product_dao.dart';
import 'dao/sale_dao.dart';
import 'tables/product_tables.dart';
import 'tables/sale_tables.dart';

part 'app_database.g.dart';

/// Voice POS local database (offline-first, single-device).
///
/// v1: products (+ case-insensitive uniqueness indexes).
/// v2: adds sales + sale_items for cash checkout (non-destructive upgrade;
/// existing products are preserved).
///
/// Migrations: [migration] creates the full current schema for fresh
/// installs; [onUpgrade] steps existing databases forward version by
/// version — never destructive recreation during normal upgrades.
@DriftDatabase(tables: [Products, Sales, SaleItems], daos: [ProductDao, SaleDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createCustomIndexes(m.database);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(sales);
            await m.createTable(saleItems);
            await _createSaleIndexes(m.database);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Uniqueness is enforced at the SQL level, never by Dart checks alone:
  /// - `products_name_active_unique`: "Pepsi"/"PEPSI"/"pepsi" cannot
  ///   silently become three active products.
  /// - `products_sku_active_unique`: SKU unique among active, non-null SKUs.
  /// - `sales_transaction_number_unique` is declared on the table; the
  ///   lookup indexes below speed up history queries.
  Future<void> _createCustomIndexes(
    GeneratedDatabase database,
  ) async {
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS products_name_active_unique '
      'ON products (name COLLATE NOCASE) WHERE is_active = 1',
    );
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS products_sku_active_unique '
      'ON products (sku) WHERE is_active = 1 AND sku IS NOT NULL',
    );
    await _createSaleIndexes(database);
  }

  Future<void> _createSaleIndexes(GeneratedDatabase database) async {
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS sales_created_at_idx '
      'ON sales (created_at)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS sale_items_sale_id_idx '
      'ON sale_items (sale_id)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS sale_items_product_id_idx '
      'ON sale_items (product_id)',
    );
  }
}
