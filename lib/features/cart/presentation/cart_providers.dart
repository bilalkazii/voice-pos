import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/products_providers.dart';
import '../domain/cart_service.dart';
import '../domain/cart_state.dart';

/// The active sale. Synchronous in-memory [Notifier] — no database writes,
/// no async work. Quantity buttons validate against each line's stock
/// snapshot, so they never query the database.
///
/// Methods return `null` on success or the [Failure] for the UI to display.
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  Failure? addProduct(Product product, {int quantity = 1}) {
    return _guard((cart) => CartService.addProduct(cart, product, quantity: quantity));
  }

  Failure? increaseQuantity(int productId) {
    return _guard((cart) => CartService.increaseQuantity(cart, productId));
  }

  Failure? decreaseQuantity(int productId) {
    return _guard((cart) => CartService.decreaseQuantity(cart, productId));
  }

  Failure? setQuantity(int productId, int quantity) {
    return _guard((cart) => CartService.setQuantity(cart, productId, quantity));
  }

  Failure? removeProduct(int productId) {
    return _guard((cart) => CartService.removeProduct(cart, productId));
  }

  void clearCart() {
    state = CartService.clearCart(state);
  }

  Failure? _guard(CartState Function(CartState cart) action) {
    try {
      state = action(state);
      return null;
    } on Failure catch (e) {
      return e;
    }
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

/// Product search scoped to the cart's add-product picker. Separate from the
/// Products screen query state; auto-disposed with the sheet. Empty query
/// lists active products for quick tapping; text searches name/SKU.
/// One-shot futures only — no live streams needed for a transient picker.
final cartPickerResultsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, query) async {
  final repository = ref.watch(productRepositoryProvider);
  if (query.trim().isEmpty) {
    final all = await repository.getAllActive();
    return all.take(50).toList();
  }
  return repository.search(query);
});
