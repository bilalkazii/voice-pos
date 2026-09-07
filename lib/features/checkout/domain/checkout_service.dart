import 'dart:math';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/db/app_database.dart' as db;
import '../../../core/errors/failures.dart';
import '../../../core/utils/money.dart';
import '../../cart/domain/cart_state.dart';
import 'payment_method.dart';
import 'sale.dart';

/// Owns the cash-checkout transaction boundary. Pure business logic +
/// database transaction — no Flutter, no Riverpod, no printing.
///
/// `completeCashSale` runs EVERYTHING inside one Drift transaction:
/// re-validate against current DB stock → insert sale → insert items →
/// guarded inventory decrement → commit. Any failure throws a [Failure]
/// and Drift rolls the whole transaction back: no partial sale, no partial
/// deduction, ever.
///
/// Rules enforced here (never trusted from the UI or the cart snapshot):
/// - cart must be non-empty; quantities/prices sane (integer math only)
/// - every product re-read from the DB: must exist, be active, and have
///   `stockQty >= requested quantity`
/// - totals recomputed from cart snapshots (the price the customer saw);
///   the live product price is NEVER substituted
/// - inventory decremented with a guarded
///   `stock_qty - ? ... WHERE stock_qty >= ?` update; zero affected rows
///   aborts the sale
/// - the cart is NOT cleared here — the controller clears it only after
///   this method returns successfully
class CheckoutService {
  CheckoutService(this._db);

  final db.AppDatabase _db;

  static const int _maxTransactionNumberAttempts = 5;

  Future<CompletedSale> completeCashSale(CartState cart) async {
    if (cart.isEmpty) {
      throw const EmptyCartFailure();
    }
    _validateCartInvariants(cart);
    final subtotal = _computeSubtotal(cart);

    return _db.transaction(() async {
      // 1. Re-read CURRENT database state — the cart's stock snapshot is
      //    never trusted at checkout.
      final rows = <db.Product>[];
      for (final item in cart.items) {
        final row = await _db.productDao.getById(item.productId);
        if (row == null) {
          throw ProductNotFoundFailure(
            message:
                '"${item.productName}" is no longer available.',
          );
        }
        if (!row.isActive) {
          throw ValidationFailure(
            message: '"${item.productName}" is no longer available.',
          );
        }
        if (row.stockQty < item.quantity) {
          if (row.stockQty <= 0) {
            throw OutOfStockFailure(
              message: '"${item.productName}" is out of stock.',
            );
          }
          throw OutOfStockFailure(
            message:
                '"${item.productName}" only has ${row.stockQty} left.',
          );
        }
        rows.add(row);
      }

      // 2. Create the sale (transaction number retries on collision).
      final saleId = await _insertSaleWithUniqueNumber(
        subtotalPaise: subtotal,
        now: DateTime.now(),
      );

      // 3. Create sale items from CART snapshots (name/SKU/price as shown
      //    on the bill — history survives later product edits).
      await _db.saleDao.createSaleItems([
        for (final item in cart.items)
          db.SaleItemsCompanion.insert(
            saleId: saleId,
            productId: item.productId,
            productName: item.productName,
            sku: Value(item.sku),
            unitPricePaise: item.unitPricePaise,
            quantity: item.quantity,
            lineTotalPaise: item.lineTotalPaise,
          ),
      ]);

      // 4. Guarded inventory deduction — verifies affected rows so a race
      //    between validation and update still rolls back safely.
      for (final item in cart.items) {
        final affected = await _db.saleDao.deductStockGuarded(
          item.productId,
          item.quantity,
        );
        if (affected == 0) {
          throw OutOfStockFailure(
            message:
                '"${item.productName}" stock changed. Please review the bill.',
          );
        }
      }

      // 5. Read back the committed rows for the receipt screens.
      final saleRow = await _db.saleDao.getSaleById(saleId);
      if (saleRow == null) {
        throw const DatabaseFailure(
          message: 'Sale could not be read after checkout.',
        );
      }
      final itemRows = await _db.saleDao.getItemsForSale(saleId);
      final itemCount = itemRows.fold(0, (sum, row) => sum + row.quantity);
      return CompletedSale(
        sale: Sale(
          id: saleRow.id,
          transactionNumber: saleRow.transactionNumber,
          paymentMethod: PaymentMethod.fromStorage(saleRow.paymentMethod),
          subtotalPaise: saleRow.subtotalPaise,
          totalPaise: saleRow.totalPaise,
          createdAt: saleRow.createdAt,
          itemCount: itemCount,
        ),
        items: [
          for (final row in itemRows)
            SaleItem(
              id: row.id,
              saleId: row.saleId,
              productId: row.productId,
              productName: row.productName,
              sku: row.sku,
              unitPricePaise: row.unitPricePaise,
              quantity: row.quantity,
              lineTotalPaise: row.lineTotalPaise,
            ),
        ],
      );
    });
  }

  void _validateCartInvariants(CartState cart) {
    for (final item in cart.items) {
      if (item.quantity < 1) {
        throw ValidationFailure(
          message: '"${item.productName}" has an invalid quantity.',
        );
      }
      if (item.unitPricePaise < 0) {
        throw ValidationFailure(
          message: '"${item.productName}" has an invalid price.',
        );
      }
    }
  }

  /// Recomputes the total from cart snapshots with integer math. The UI
  /// never supplies the total — it is always derived here.
  int _computeSubtotal(CartState cart) {
    return Money.sum(cart.items.map((e) => e.lineTotalPaise));
  }

  Future<int> _insertSaleWithUniqueNumber({
    required int subtotalPaise,
    required DateTime now,
  }) async {
    SqliteException? lastError;
    for (var attempt = 0;
        attempt < _maxTransactionNumberAttempts;
        attempt++) {
      final number = generateTransactionNumber(now: now);
      try {
        return await _db.saleDao.createSale(
          db.SalesCompanion.insert(
            transactionNumber: number,
            paymentMethod: PaymentMethod.cash.storage,
            subtotalPaise: subtotalPaise,
            totalPaise: subtotalPaise,
          ),
        );
      } on SqliteException catch (e) {
        if (!_isUniqueViolation(e)) rethrow;
        lastError = e;
      }
    }
    throw DatabaseFailure(
      message:
          'Could not generate a unique transaction number: ${lastError?.message}',
    );
  }

  bool _isUniqueViolation(SqliteException e) {
    return e.extendedResultCode == 2067 ||
        e.message.contains('UNIQUE constraint failed');
  }

  /// Local, offline transaction reference: `VP-<epochMillis>-<random4>`.
  /// Millis keep it human-sortable; the random suffix plus the database
  /// UNIQUE constraint (with retry above) make collisions impossible in
  /// practice on a single device.
  static String generateTransactionNumber({DateTime? now, Random? random}) {
    final millis = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final suffix = ((random ?? Random()).nextInt(9000) + 1000).toString();
    return 'VP-$millis-$suffix';
  }
}
