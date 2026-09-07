import '../../../core/db/app_database.dart' as db;
import '../../../core/db/dao/sale_dao.dart';
import '../domain/payment_method.dart';
import '../domain/sale.dart';
import '../domain/sale_repository.dart';

/// Drift-backed [SaleRepository]. Read-only; all writes happen inside
/// [CheckoutService]'s transaction.
class DriftSaleRepository implements SaleRepository {
  DriftSaleRepository(this._dao);

  final SaleDao _dao;

  @override
  Future<CompletedSale?> getSaleWithItems(int saleId) async {
    final row = await _dao.getSaleById(saleId);
    if (row == null) return null;
    final itemRows = await _dao.getItemsForSale(saleId);
    return CompletedSale(
      sale: _toSale(row),
      items: itemRows.map(_toSaleItem).toList(),
    );
  }

  @override
  Future<CompletedSale?> getByTransactionNumber(
    String transactionNumber,
  ) async {
    final row = await _dao.getSaleByTransactionNumber(transactionNumber);
    if (row == null) return null;
    final itemRows = await _dao.getItemsForSale(row.id);
    return CompletedSale(
      sale: _toSale(row),
      items: itemRows.map(_toSaleItem).toList(),
    );
  }

  @override
  Future<List<Sale>> recentSales({int limit = 50}) async {
    final rows = await _dao.recentSales(limit: limit);
    return rows.map((r) => _toSale(r)).toList();
  }

  @override
  Stream<List<Sale>> watchRecentSales({int limit = 50}) {
    return _dao.watchRecentSales(limit: limit).map(
          (rows) => rows.map((r) => _toSale(r)).toList(),
        );
  }

  @override
  Stream<List<Sale>> watchSalesWithCount({
    DateTime? after,
    String? transactionSearch,
    int limit = 50,
  }) {
    return _dao
        .watchSalesWithCount(
          after: after,
          transactionSearch: transactionSearch,
          limit: limit,
        )
        .map(
          (rows) => rows
              .map((r) => _toSale(r.sale, itemCount: r.itemCount))
              .toList(),
        );
  }

  @override
  Future<List<Sale>> getSalesWithCount({
    DateTime? after,
    String? transactionSearch,
    int limit = 50,
  }) async {
    final rows = await _dao.getSalesWithCount(
      after: after,
      transactionSearch: transactionSearch,
      limit: limit,
    );
    return rows
        .map((r) => _toSale(r.sale, itemCount: r.itemCount))
        .toList();
  }

  @override
  Future<int> saleCount() => _dao.saleCount();

  Sale _toSale(db.Sale row, {int itemCount = 0}) {
    return Sale(
      id: row.id,
      transactionNumber: row.transactionNumber,
      paymentMethod: PaymentMethod.fromStorage(row.paymentMethod),
      subtotalPaise: row.subtotalPaise,
      totalPaise: row.totalPaise,
      createdAt: row.createdAt,
      itemCount: itemCount,
    );
  }

  SaleItem _toSaleItem(db.SaleItem row) {
    return SaleItem(
      id: row.id,
      saleId: row.saleId,
      productId: row.productId,
      productName: row.productName,
      sku: row.sku,
      unitPricePaise: row.unitPricePaise,
      quantity: row.quantity,
      lineTotalPaise: row.lineTotalPaise,
    );
  }
}
