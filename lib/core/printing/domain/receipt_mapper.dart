import '../../../features/checkout/domain/sale.dart';
import 'receipt_data.dart';

/// Pure mapping from a committed sale to printable receipt data:
///
/// [CompletedSale] (+ configured store name) → [ReceiptData].
///
/// Reads ONLY the sale's snapshots. It never touches the product catalog,
/// the cart, or the database, so a product renamed/repriced/deactivated
/// after checkout cannot leak into the receipt. `storeName` is applied
/// here because it is store configuration, not historical product data.
abstract final class ReceiptMapper {
  static ReceiptData toReceiptData(
    CompletedSale sale, {
    required String storeName,
  }) {
    return ReceiptData(
      storeName: storeName,
      transactionNumber: sale.sale.transactionNumber,
      createdAt: sale.sale.createdAt,
      paymentMethod: sale.sale.paymentMethod.storage,
      subtotalPaise: sale.sale.subtotalPaise,
      totalPaise: sale.sale.totalPaise,
      items: [
        for (final item in sale.items)
          ReceiptLineItem(
            productName: item.productName,
            sku: item.sku,
            unitPricePaise: item.unitPricePaise,
            quantity: item.quantity,
            lineTotalPaise: item.lineTotalPaise,
          ),
      ],
    );
  }
}
