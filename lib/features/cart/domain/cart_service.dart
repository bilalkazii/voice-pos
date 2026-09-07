import '../../../core/errors/failures.dart';
import '../../products/domain/product.dart';
import 'cart_item.dart';
import 'cart_state.dart';

/// Pure cart operations. No Flutter, no Riverpod, no database — every method
/// takes a [CartState] and returns the next one, throwing a [Failure] on
/// rule violations. Quantity buttons therefore never query the database;
/// they validate against the stock snapshot stored in each [CartItem].
///
/// Documented behaviors:
/// - Adding an existing product merges into its line (no duplicate lines).
/// - Decrementing a quantity of 1 (or setting quantity to 0) REMOVES the
///   line — zero never persists as a line quantity.
/// - Adding to the cart never touches database stock; checkout deducts it.
/// - Item prices are snapshots: later product edits don't rewrite the cart.
abstract final class CartService {
  /// Adds [quantity] of [product], merging into the existing line if any.
  static CartState addProduct(
    CartState cart,
    Product product, {
    int quantity = 1,
  }) {
    if (quantity < 1) {
      throw const ValidationFailure(message: 'Quantity must be at least 1.');
    }
    if (!product.isActive) {
      throw ProductNotFoundFailure.forQuery(product.name);
    }
    if (product.stockQty <= 0) {
      throw OutOfStockFailure(message: '"${product.name}" is out of stock.');
    }
    final existing = cart.getItem(product.id);
    final nextQty = (existing?.quantity ?? 0) + quantity;
    if (nextQty > product.stockQty) {
      throw OutOfStockFailure(
        message: 'Only ${product.stockQty} × "${product.name}" available.',
      );
    }
    if (existing != null) {
      return _replace(
        cart,
        existing.copyWith(
          quantity: nextQty,
          availableStock: product.stockQty,
        ),
      );
    }
    return CartState(
      items: [
        ...cart.items,
        CartItem(
          productId: product.id,
          productName: product.name,
          sku: product.sku,
          unitPricePaise: product.sellingPricePaise,
          quantity: quantity,
          availableStock: product.stockQty,
        ),
      ],
    );
  }

  /// +1 on a line, capped at the snapshot stock.
  static CartState increaseQuantity(CartState cart, int productId) {
    final existing = cart.getItem(productId);
    if (existing == null) {
      throw ProductNotFoundFailure.forQuery('id $productId');
    }
    if (existing.quantity + 1 > existing.availableStock) {
      throw OutOfStockFailure(
        message:
            'Only ${existing.availableStock} × "${existing.productName}" available.',
      );
    }
    return _replace(
      cart,
      existing.copyWith(quantity: existing.quantity + 1),
    );
  }

  /// −1 on a line; a quantity of 1 removes the line (zero never persists).
  static CartState decreaseQuantity(CartState cart, int productId) {
    final existing = cart.getItem(productId);
    if (existing == null) {
      throw ProductNotFoundFailure.forQuery('id $productId');
    }
    if (existing.quantity <= 1) {
      return removeProduct(cart, productId);
    }
    return _replace(
      cart,
      existing.copyWith(quantity: existing.quantity - 1),
    );
  }

  /// Absolute quantity; 0 removes the line, negative is rejected.
  static CartState setQuantity(
    CartState cart,
    int productId,
    int quantity,
  ) {
    if (quantity < 0) {
      throw const ValidationFailure(message: 'Quantity cannot be negative.');
    }
    final existing = cart.getItem(productId);
    if (existing == null) {
      throw ProductNotFoundFailure.forQuery('id $productId');
    }
    if (quantity == 0) {
      return removeProduct(cart, productId);
    }
    if (quantity > existing.availableStock) {
      throw OutOfStockFailure(
        message:
            'Only ${existing.availableStock} × "${existing.productName}" available.',
      );
    }
    return _replace(cart, existing.copyWith(quantity: quantity));
  }

  static CartState removeProduct(CartState cart, int productId) {
    if (!cart.containsProduct(productId)) {
      throw ProductNotFoundFailure.forQuery('id $productId');
    }
    return CartState(
      items: cart.items.where((e) => e.productId != productId).toList(),
    );
  }

  /// Clearing never touches inventory — the cart holds no database state.
  static CartState clearCart(CartState cart) => const CartState();

  static CartState _replace(CartState cart, CartItem updated) {
    return CartState(
      items: cart.items
          .map((e) => e.productId == updated.productId ? updated : e)
          .toList(),
    );
  }
}
