import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/product_tables.dart';

part 'product_dao.g.dart';

/// Data access for products. Works with Drift rows only — the repository
/// layer maps these to domain models. No validation here beyond what SQL
/// constraints enforce; validation lives in the domain/repository layers.
@DriftAccessor(tables: [Products])
class ProductDao extends DatabaseAccessor<AppDatabase>
    with _$ProductDaoMixin {
  ProductDao(super.db);

  /// All active products, alphabetical. Source for the product list.
  Stream<List<Product>> watchAllActive() {
    return (select(products)
          ..where((t) => t.isActive)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// One-shot fetch of all active products, alphabetical.
  Future<List<Product>> getAllActive() {
    return (select(products)
          ..where((t) => t.isActive)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Normalized search for a small retail catalog: case-insensitive
  /// substring match on name plus substring match on SKU, active only.
  ///
  /// No fuzzy/phonetic matching — that belongs to the voice phase.
  Future<List<Product>> search(String query) {
    final pattern = '%${query.trim()}%';
    return (select(products)
          ..where(
            (t) =>
                t.isActive &
                (t.name.like(pattern) | t.sku.like(pattern)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(50))
        .get();
  }

  Future<Product?> getById(int id) {
    return (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Exact (case-insensitive) name lookup among active products.
  /// Used for duplicate detection messaging and later voice matching.
  Future<Product?> getByNameExact(String name) {
    final normalized = name.trim().toLowerCase();
    return (select(products)
          ..where((t) => t.isActive & t.name.lower().equals(normalized)))
        .getSingleOrNull();
  }

  Future<int> create(ProductsCompanion entry) {
    return into(products).insert(entry);
  }

  Future<void> updateProduct(int id, ProductsCompanion entry) {
    return (update(products)..where((t) => t.id.equals(id))).write(
      entry.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  /// Soft delete: row stays for future historical sale references.
  Future<void> deactivate(int id) {
    return (update(products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Absolute stock set. Must stay >= 0 (also enforced by CHECK).
  /// Sale-based deduction arrives with checkout; it will use a conditional
  /// `stock_qty - ? ... WHERE stock_qty >= ?` update verified by this DAO.
  Future<void> updateStock(int id, int newQty) {
    return (update(products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        stockQty: Value(newQty),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Active products with `stockQty <= lowStockThreshold`.
  Stream<List<Product>> watchLowStock() {
    return (select(products)
          ..where(
            (t) =>
                t.isActive &
                t.stockQty.isSmallerOrEqual(t.lowStockThreshold),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// One-shot low-stock fetch (reports/tests).
  Future<List<Product>> getLowStock() {
    return (select(products)
          ..where(
            (t) =>
                t.isActive &
                t.stockQty.isSmallerOrEqual(t.lowStockThreshold),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }
}
