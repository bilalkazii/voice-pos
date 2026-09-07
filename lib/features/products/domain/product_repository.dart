import 'product.dart';

/// Product repository contract. Exposes domain models only — never Drift rows.
///
/// Implementations map expected data errors to [Failure]s from Phase 0
/// (`ValidationFailure`, `ProductNotFoundFailure`, `DatabaseFailure`).
abstract class ProductRepository {
  /// Creates a product and returns it with its database id.
  /// Throws [ValidationFailure] for bad input or duplicate name/SKU.
  Future<Product> create({
    required String name,
    required String? sku,
    required int sellingPricePaise,
    required int? costPricePaise,
    required int stockQty,
    required int lowStockThreshold,
  });

  Future<Product?> getById(int id);

  /// Active products matching [query] by name or SKU (case-insensitive).
  /// Empty query returns an empty list — use [watchAll] for the full list.
  Future<List<Product>> search(String query);

  /// Live list of all active products, alphabetical.
  Stream<List<Product>> watchAll();

  /// Updates an editable product. [updatedAt] advances automatically.
  /// Throws [ValidationFailure] for bad input/duplicates,
  /// [ProductNotFoundFailure] for unknown ids.
  Future<Product> update({
    required int id,
    required String name,
    required String? sku,
    required int sellingPricePaise,
    required int? costPricePaise,
    required int stockQty,
    required int lowStockThreshold,
  });

  /// Soft delete (`isActive = false`). Row is kept for future sale history.
  Future<void> deactivate(int id);

  /// Absolute stock set. Never negative — throws [ValidationFailure].
  Future<Product> updateStock(int id, int newQty);

  /// Live list of active products with `stockQty <= lowStockThreshold`.
  Stream<List<Product>> watchLowStock();
}
