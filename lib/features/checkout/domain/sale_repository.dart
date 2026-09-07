import 'sale.dart';

/// Read-side contract for completed sales. Exposes domain models only —
/// never Drift rows. The write path (atomic sale creation) belongs to
/// [CheckoutService], which owns the transaction boundary.
abstract class SaleRepository {
  /// A committed sale with its lines, or null for unknown ids. Receipt and
  /// payment-complete screens read through this — never through the cart.
  Future<CompletedSale?> getSaleWithItems(int saleId);

  Future<CompletedSale?> getByTransactionNumber(String transactionNumber);

  /// Most recent sales, newest first. Future history screens build on this.
  Future<List<Sale>> recentSales({int limit});

  Stream<List<Sale>> watchRecentSales({int limit});

  /// Reactive, bounded history query. [after] limits to sales created at or
  /// after that instant (e.g. start of today); [transactionSearch] does a
  /// case-insensitive partial match on the transaction number. Newest first,
  /// capped at [limit] (default 50). Each [Sale] carries its `itemCount`.
  /// Offline only; no backend.
  Stream<List<Sale>> watchSalesWithCount({
    DateTime? after,
    String? transactionSearch,
    int limit,
  });

  /// One-shot bounded history query with the same filters as
  /// [watchSalesWithCount].
  Future<List<Sale>> getSalesWithCount({
    DateTime? after,
    String? transactionSearch,
    int limit,
  });

  Future<int> saleCount();
}
