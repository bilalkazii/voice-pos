import 'payment_method.dart';

/// Immutable completed-sale header. Pure Dart — no Flutter, no Drift.
///
/// Totals are integer paise. In V1 `subtotalPaise == totalPaise` (no tax,
/// discount, or fees); both are stored so history stays correct if V1 ever
/// diverges them.
class Sale {
  const Sale({
    required this.id,
    required this.transactionNumber,
    required this.paymentMethod,
    required this.subtotalPaise,
    required this.totalPaise,
    required this.createdAt,
    this.itemCount = 0,
  });

  final int id;
  final String transactionNumber;
  final PaymentMethod paymentMethod;
  final int subtotalPaise;
  final int totalPaise;
  final DateTime createdAt;

  /// Total units across the sale's lines. Populated by the history queries
  /// (a JOIN) and by the checkout service; defaults to 0 for callers that
  /// only need the header (e.g. `recentSales`).
  final int itemCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sale &&
          id == other.id &&
          transactionNumber == other.transactionNumber &&
          paymentMethod == other.paymentMethod &&
          subtotalPaise == other.subtotalPaise &&
          totalPaise == other.totalPaise &&
          createdAt == other.createdAt &&
          itemCount == other.itemCount;

  @override
  int get hashCode => Object.hash(
        id,
        transactionNumber,
        paymentMethod,
        subtotalPaise,
        totalPaise,
        createdAt,
        itemCount,
      );
}

/// One immutable line of a completed sale. All product data is a snapshot
/// taken at confirmation time — later product renames, reprices, SKU edits,
/// or deactivations never rewrite history.
class SaleItem {
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unitPricePaise,
    required this.quantity,
    required this.lineTotalPaise,
  });

  final int id;
  final int saleId;
  final int productId;
  final String productName;
  final String? sku;
  final int unitPricePaise;
  final int quantity;
  final int lineTotalPaise;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleItem &&
          id == other.id &&
          saleId == other.saleId &&
          productId == other.productId &&
          productName == other.productName &&
          sku == other.sku &&
          unitPricePaise == other.unitPricePaise &&
          quantity == other.quantity &&
          lineTotalPaise == other.lineTotalPaise;

  @override
  int get hashCode => Object.hash(
        id,
        saleId,
        productId,
        productName,
        sku,
        unitPricePaise,
        quantity,
        lineTotalPaise,
      );
}

/// A committed transaction: the sale header plus its lines. This is what
/// the payment-complete and receipt screens render — never the live cart
/// (which is cleared) and never the live product catalog (which may change).
class CompletedSale {
  const CompletedSale({required this.sale, required this.items});

  final Sale sale;
  final List<SaleItem> items;

  int get itemCount => items.fold(0, (sum, e) => sum + e.quantity);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletedSale &&
          sale == other.sale &&
          items.length == other.items.length &&
          _sameItems(items, other.items);

  @override
  int get hashCode => Object.hash(sale, Object.hashAll(items));
}

bool _sameItems(List<SaleItem> a, List<SaleItem> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
