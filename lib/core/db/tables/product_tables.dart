import 'package:drift/drift.dart';

/// Products table (schema v1).
///
/// Money is ALWAYS integer paise — never floating point.
///
/// Uniqueness is enforced at the SQL level (see [AppDatabase.migration]):
/// - `products_name_active_unique`: case-insensitive name uniqueness among
///   active products (`name COLLATE NOCASE ... WHERE is_active = 1`), so
///   "Pepsi" / "PEPSI" / "pepsi" cannot silently become three products.
/// - `products_sku_active_unique`: SKU uniqueness among active products with
///   a non-null SKU. SKU itself stays nullable and optional.
///
/// Range rules are enforced both here (table CHECKs) and in the domain layer:
/// - selling price >= 0, cost price >= 0 when present
/// - stock quantity >= 0, low-stock threshold >= 0
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().named('name').withLength(min: 1, max: 100)();

  TextColumn get sku => text().named('sku').nullable()();

  IntColumn get sellingPricePaise => integer().named('selling_price_paise')();

  IntColumn get costPricePaise =>
      integer().named('cost_price_paise').nullable()();

  IntColumn get stockQty =>
      integer().named('stock_qty').withDefault(const Constant(0))();

  IntColumn get lowStockThreshold =>
      integer().named('low_stock_threshold').withDefault(const Constant(5))();

  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => const [
        'CHECK (selling_price_paise >= 0)',
        'CHECK (cost_price_paise IS NULL OR cost_price_paise >= 0)',
        'CHECK (stock_qty >= 0)',
        'CHECK (low_stock_threshold >= 0)',
      ];
}
