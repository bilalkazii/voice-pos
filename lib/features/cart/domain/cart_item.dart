import '../../../core/utils/money.dart';

/// One line on the current bill. Pure Dart — no Flutter, no Drift.
///
/// A snapshot taken when the product was added: id, display name, the
/// selling price at that moment, and the stock available at that moment.
/// A later product price/stock edit does NOT rewrite items already in the
/// cart; removing and re-adding picks up the new values.
class CartItem {
  const CartItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unitPricePaise,
    required this.quantity,
    required this.availableStock,
  });

  final int productId;
  final String productName;
  final String? sku;
  final int unitPricePaise;
  final int quantity;

  /// Stock snapshot from add time. Quantity edits validate against this so
  /// button presses never hit the database.
  final int availableStock;

  /// Derived — never stored: `unitPricePaise × quantity` (integer math).
  int get lineTotalPaise => Money.multiply(unitPricePaise, quantity);

  CartItem copyWith({int? quantity, int? availableStock}) {
    return CartItem(
      productId: productId,
      productName: productName,
      sku: sku,
      unitPricePaise: unitPricePaise,
      quantity: quantity ?? this.quantity,
      availableStock: availableStock ?? this.availableStock,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          productId == other.productId &&
          productName == other.productName &&
          sku == other.sku &&
          unitPricePaise == other.unitPricePaise &&
          quantity == other.quantity &&
          availableStock == other.availableStock;

  @override
  int get hashCode => Object.hash(
        productId,
        productName,
        sku,
        unitPricePaise,
        quantity,
        availableStock,
      );
}
