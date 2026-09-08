import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart'
    hide Product, Sale, SaleItem;
import 'package:voice_pos/core/printing/data/unavailable_printer_service.dart';
import 'package:voice_pos/core/printing/domain/print_result.dart';
import 'package:voice_pos/core/printing/domain/receipt_mapper.dart';
import 'package:voice_pos/features/cart/domain/cart_service.dart';
import 'package:voice_pos/features/cart/domain/cart_state.dart';
import 'package:voice_pos/features/checkout/data/sale_repository_impl.dart';
import 'package:voice_pos/features/checkout/domain/checkout_service.dart';
import 'package:voice_pos/features/checkout/domain/sale.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';

import 'fakes.dart';

/// Opens a memory database, seeds one product (Pepsi, stock 10), commits a
/// real cash sale for 2 × Pepsi through [CheckoutService], and returns the
/// committed sale plus the database.
Future<({AppDatabase db, CompletedSale sale})> commitPepsiSale() async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final products = DriftProductRepository(db.productDao);
  final pepsi = await products.create(
    name: 'Pepsi 500ml',
    sku: 'PEP-500',
    sellingPricePaise: 4000,
    costPricePaise: null,
    stockQty: 10,
    lowStockThreshold: 2,
  );
  final cart = CartService.addProduct(
    const CartState(),
    pepsi,
    quantity: 2,
  );
  final sale = await CheckoutService(db).completeCashSale(cart);
  return (db: db, sale: sale);
}

Future<int> stockOf(AppDatabase db, int productId) async {
  final row = await db.productDao.getById(productId);
  return row!.stockQty;
}

void main() {
  group('print retry contract', () {
    test('fail then retry succeeds on the SAME committed sale', () async {
      final (:db, :sale) = await commitPepsiSale();
      final receipt = ReceiptMapper.toReceiptData(
        sale,
        storeName: 'Kazi Mart',
      );
      final printer = FakePrinterService([
        const PrintFailed('No paper'),
        const PrintSuccess(),
      ]);

      // First attempt fails.
      final first = await printer.printReceipt(receipt);
      expect(first, isA<PrintFailed>());

      // Retry reuses the exact same receipt — never checkout, cart, or DB.
      final retry = await printer.printReceipt(receipt);
      expect(retry, isA<PrintSuccess>());

      expect(printer.calls, 2);
      expect(printer.printed[0], receipt);
      expect(printer.printed[1], receipt);
      expect(printer.printed[0], printer.printed[1]);
      expect(
        printer.printed[1].transactionNumber,
        sale.sale.transactionNumber,
      );

      // Exactly one sale exists; inventory was deducted exactly once by the
      // original checkout (10 → 8), and retries changed nothing.
      expect(await db.saleDao.saleCount(), 1);
      expect(await stockOf(db, sale.items.first.productId), 8);
    });

    test('repeated failures leave sale and inventory untouched', () async {
      final (:db, :sale) = await commitPepsiSale();
      final receipt = ReceiptMapper.toReceiptData(
        sale,
        storeName: 'Kazi Mart',
      );
      final printer = FakePrinterService([
        const PrintFailed('No paper'),
        const PrintFailed('No paper'),
        const PrintFailed('No paper'),
      ]);

      for (var i = 0; i < 3; i++) {
        final result = await printer.printReceipt(receipt);
        expect(result, isA<PrintFailed>());
      }

      expect(printer.calls, 3);
      // The committed sale persists; inventory reflects only the original
      // checkout deduction — retries never re-enter checkout.
      final persisted =
          await db.saleDao.getSaleById(sale.sale.id);
      expect(persisted, isNotNull);
      expect(persisted!.transactionNumber, sale.sale.transactionNumber);
      expect(await db.saleDao.saleCount(), 1);
      expect(await stockOf(db, sale.items.first.productId), 8);
    });

    test('unavailable printer keeps the completed sale', () async {
      final (:db, :sale) = await commitPepsiSale();
      const printer = UnavailablePrinterService();
      final receipt = ReceiptMapper.toReceiptData(
        sale,
        storeName: 'Kazi Mart',
      );

      final result = await printer.printReceipt(receipt);

      expect(result, isA<PrintUnavailable>());
      expect(result.message, contains('not configured'));
      expect(await db.saleDao.saleCount(), 1);
      expect(await stockOf(db, sale.items.first.productId), 8);
    });

    test('retry receipt reflects historical snapshots, not live catalog',
        () async {
      final (:db, :sale) = await commitPepsiSale();
      final products = DriftProductRepository(db.productDao);
      final live = await products.getById(sale.items.first.productId);

      // Rename/reprice AFTER the sale committed.
      await products.update(
        id: live!.id,
        name: 'Pepsi MAX',
        sku: 'PEP-MAX',
        sellingPricePaise: 9999,
        costPricePaise: null,
        stockQty: live.stockQty,
        lowStockThreshold: live.lowStockThreshold,
      );

      // Reload the committed sale through the repository (exactly as a
      // retry flow would) and map again.
      final repository = DriftSaleRepository(db.saleDao);
      final reloaded =
          await repository.getSaleWithItems(sale.sale.id);
      expect(reloaded, isNotNull);
      final receipt = ReceiptMapper.toReceiptData(
        reloaded!,
        storeName: 'Kazi Mart',
      );

      expect(receipt.items.single.productName, 'Pepsi 500ml');
      expect(receipt.items.single.unitPricePaise, 4000);
      expect(receipt.totalPaise, 8000);
    });
  });
}
