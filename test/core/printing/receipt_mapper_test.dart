import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/printing/domain/receipt_data.dart';
import 'package:voice_pos/core/printing/domain/receipt_mapper.dart';
import 'package:voice_pos/features/checkout/domain/payment_method.dart';
import 'package:voice_pos/features/checkout/domain/sale.dart';

CompletedSale sampleSale() {
  final createdAt = DateTime(2026, 9, 7, 21, 42);
  return CompletedSale(
    sale: Sale(
      id: 7,
      transactionNumber: 'VP-1788804734779-1822',
      paymentMethod: PaymentMethod.cash,
      subtotalPaise: 11000,
      totalPaise: 11000,
      createdAt: createdAt,
    ),
    items: const [
      SaleItem(
        id: 11,
        saleId: 7,
        productId: 3,
        productName: 'Pepsi 500ml',
        sku: 'PEP-500',
        unitPricePaise: 4000,
        quantity: 2,
        lineTotalPaise: 8000,
      ),
      SaleItem(
        id: 12,
        saleId: 7,
        productId: 5,
        productName: 'Lays Classic',
        sku: null,
        unitPricePaise: 3000,
        quantity: 1,
        lineTotalPaise: 3000,
      ),
    ],
  );
}

void main() {
  group('ReceiptMapper.toReceiptData', () {
    test('maps header fields', () {
      final receipt = ReceiptMapper.toReceiptData(
        sampleSale(),
        storeName: 'Kazi Mart',
      );

      expect(receipt.storeName, 'Kazi Mart');
      expect(receipt.transactionNumber, 'VP-1788804734779-1822');
      expect(receipt.createdAt, DateTime(2026, 9, 7, 21, 42));
      expect(receipt.paymentMethod, 'cash');
      expect(receipt.subtotalPaise, 11000);
      expect(receipt.totalPaise, 11000);
      expect(receipt.itemCount, 3);
    });

    test('maps line items with snapshots', () {
      final receipt = ReceiptMapper.toReceiptData(
        sampleSale(),
        storeName: 'Kazi Mart',
      );

      expect(receipt.items.length, 2);
      expect(
        receipt.items[0],
        const ReceiptLineItem(
          productName: 'Pepsi 500ml',
          sku: 'PEP-500',
          unitPricePaise: 4000,
          quantity: 2,
          lineTotalPaise: 8000,
        ),
      );
      expect(receipt.items[1].sku, isNull);
      expect(receipt.items[1].lineTotalPaise, 3000);
    });

    test('applies the configured store name without touching sale data', () {
      final first = ReceiptMapper.toReceiptData(
        sampleSale(),
        storeName: 'Kazi Mart',
      );
      final second = ReceiptMapper.toReceiptData(
        sampleSale(),
        storeName: 'Bilal General Store',
      );

      expect(first.storeName, 'Kazi Mart');
      expect(second.storeName, 'Bilal General Store');
      expect(first.transactionNumber, second.transactionNumber);
      expect(first.items, second.items);
      expect(first.totalPaise, second.totalPaise);
    });

    test('uses integer paise throughout (no floating point)', () {
      final receipt = ReceiptMapper.toReceiptData(
        sampleSale(),
        storeName: 'Kazi Mart',
      );

      expect(receipt.totalPaise, isA<int>());
      expect(receipt.subtotalPaise, isA<int>());
      for (final item in receipt.items) {
        expect(item.unitPricePaise, isA<int>());
        expect(item.lineTotalPaise, isA<int>());
        expect(
          item.lineTotalPaise,
          item.unitPricePaise * item.quantity,
        );
      }
    });
  });

  group('ReceiptData value semantics', () {
    test('equal receipts compare equal', () {
      final a = ReceiptMapper.toReceiptData(
        sampleSale(),
        storeName: 'Kazi Mart',
      );
      final b = ReceiptMapper.toReceiptData(
        sampleSale(),
        storeName: 'Kazi Mart',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
