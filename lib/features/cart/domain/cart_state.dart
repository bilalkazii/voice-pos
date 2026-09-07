import 'cart_item.dart';

/// In-memory state of the active sale. Immutable, synchronous, never
/// persisted to SQLite — an unfinished cart lives only for the current bill.
///
/// Totals are always derived (V1 has no tax, discount, or fees):
/// `lineTotal = unitPricePaise × quantity`,
/// `subtotal = Σ lineTotal`, `total = subtotal`.
class CartState {
  const CartState({this.items = const []});

  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Total units across all lines.
  int get itemCount => items.fold(0, (sum, e) => sum + e.quantity);

  /// Distinct product lines.
  int get distinctCount => items.length;

  int get subtotalPaise => items.fold(0, (sum, e) => sum + e.lineTotalPaise);

  /// V1: identical to subtotal — no tax/discount/service charge rows exist,
  /// so the UI shows only this total.
  int get totalPaise => subtotalPaise;

  CartItem? getItem(int productId) {
    for (final item in items) {
      if (item.productId == productId) return item;
    }
    return null;
  }

  bool containsProduct(int productId) => getItem(productId) != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartState &&
          items.length == other.items.length &&
          _sameItems(items, other.items);

  @override
  int get hashCode => Object.hashAll(items);
}

bool _sameItems(List<CartItem> a, List<CartItem> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
