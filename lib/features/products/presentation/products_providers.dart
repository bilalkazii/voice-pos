import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart' hide Product;
import '../../../core/errors/failures.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';
import '../data/product_repository_impl.dart';

/// Phase 1 provider graph:
///
/// databaseProvider → productDaoProvider → productRepositoryProvider
///   → productsProvider / lowStockProductsProvider / productByIdProvider
/// Mutations go through productsControllerProvider (AsyncNotifier).

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() async {
    await db.close();
  });
  return db;
});

final productDaoProvider = Provider(
  (ref) => ref.watch(databaseProvider).productDao,
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => DriftProductRepository(ref.watch(productDaoProvider)),
);

/// Current search text for the products screen. Updated by the UI with a
/// short debounce so every keystroke does not re-query the database.
class ProductSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) {
    if (state != value) state = value;
  }

  void clear() => state = '';
}

final productSearchQueryProvider =
    NotifierProvider<ProductSearchQueryNotifier, String>(
  ProductSearchQueryNotifier.new,
);

/// Active products: full alphabetical list when the query is blank,
/// name/SKU matches otherwise.
final productsProvider = StreamProvider<List<Product>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  final query = ref.watch(productSearchQueryProvider);
  if (query.trim().isEmpty) return repository.watchAll();
  return Stream.fromFuture(repository.search(query));
});

final lowStockProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchLowStock();
});

final productByIdProvider =
    FutureProvider.family<Product?, int>((ref, id) {
  return ref.watch(productRepositoryProvider).getById(id);
});

/// Handles product mutations. Methods return `null` on success or the
/// [Failure] to display — list streams update automatically, no manual
/// invalidation needed.
class ProductsController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<Failure?> createProduct({
    required String name,
    required String? sku,
    required int sellingPricePaise,
    required int? costPricePaise,
    required int stockQty,
    required int lowStockThreshold,
  }) {
    return _guard(
      () => ref.read(productRepositoryProvider).create(
            name: name,
            sku: sku,
            sellingPricePaise: sellingPricePaise,
            costPricePaise: costPricePaise,
            stockQty: stockQty,
            lowStockThreshold: lowStockThreshold,
          ),
    );
  }

  Future<Failure?> updateProduct({
    required int id,
    required String name,
    required String? sku,
    required int sellingPricePaise,
    required int? costPricePaise,
    required int stockQty,
    required int lowStockThreshold,
  }) {
    return _guard(
      () => ref.read(productRepositoryProvider).update(
            id: id,
            name: name,
            sku: sku,
            sellingPricePaise: sellingPricePaise,
            costPricePaise: costPricePaise,
            stockQty: stockQty,
            lowStockThreshold: lowStockThreshold,
          ),
    );
  }

  Future<Failure?> deactivateProduct(int id) {
    return _guard(
      () => ref.read(productRepositoryProvider).deactivate(id),
    );
  }

  Future<Failure?> _guard(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return null;
    } on Failure catch (e) {
      state = AsyncError(e, StackTrace.current);
      return e;
    } catch (e) {
      final failure = DatabaseFailure(message: 'Unexpected error: $e');
      state = AsyncError(failure, StackTrace.current);
      return failure;
    }
  }
}

final productsControllerProvider =
    AsyncNotifierProvider<ProductsController, void>(
  ProductsController.new,
);
