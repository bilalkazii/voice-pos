/// One immutable line on a printed receipt. Pure Dart — no Flutter, no
/// Drift, no Bluetooth, no ESC/POS, no cart.
///
/// Every field is a snapshot captured at confirmation time. A later product
/// rename, reprice, SKU edit, or deactivation never changes this.
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.productName,
    required this.sku,
    required this.unitPricePaise,
    required this.quantity,
    required this.lineTotalPaise,
  });

  final String productName;
  final String? sku;
  final int unitPricePaise;
  final int quantity;
  final int lineTotalPaise;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptLineItem &&
          productName == other.productName &&
          sku == other.sku &&
          unitPricePaise == other.unitPricePaise &&
          quantity == other.quantity &&
          lineTotalPaise == other.lineTotalPaise;

  @override
  int get hashCode => Object.hash(
        productName,
        sku,
        unitPricePaise,
        quantity,
        lineTotalPaise,
      );
}

/// Immutable receipt for an ALREADY-COMMITTED sale. Pure Dart — independent
/// of widgets, Drift rows, Bluetooth, ESC/POS, the cart, and any active
/// checkout transaction.
///
/// This is the only thing a [PrinterService] ever receives, so printing can
/// never reread live product data, touch the cart, or re-enter checkout.
/// Retrying a print reuses this exact object against the same sale.
///
/// Money is integer paise throughout. `storeName` is store configuration
/// (applied at mapping time), not historical product data.
class ReceiptData {
  const ReceiptData({
    required this.storeName,
    required this.transactionNumber,
    required this.createdAt,
    required this.paymentMethod,
    required this.subtotalPaise,
    required this.totalPaise,
    required this.items,
  });

  /// Configured store name at print time.
  final String storeName;
  final String transactionNumber;
  final DateTime createdAt;

  /// Payment method code as stored on the sale (V1: `'cash'`).
  final String paymentMethod;
  final int subtotalPaise;
  final int totalPaise;
  final List<ReceiptLineItem> items;

  int get itemCount => items.fold(0, (sum, e) => sum + e.quantity);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptData &&
          storeName == other.storeName &&
          transactionNumber == other.transactionNumber &&
          paymentMethod == other.paymentMethod &&
          subtotalPaise == other.subtotalPaise &&
          totalPaise == other.totalPaise &&
          createdAt == other.createdAt &&
          items.length == other.items.length &&
          _sameItems(items, other.items);

  @override
  int get hashCode => Object.hash(
        storeName,
        transactionNumber,
        paymentMethod,
        subtotalPaise,
        totalPaise,
        createdAt,
        Object.hashAll(items),
      );
}

bool _sameItems(List<ReceiptLineItem> a, List<ReceiptLineItem> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
