import '../../../core/db/app_database.dart' as db;
import '../../../core/db/dao/sale_dao.dart';
import '../../checkout/domain/payment_method.dart';
import '../../checkout/domain/sale.dart';
import '../domain/report_repository.dart';
import '../domain/report_summary.dart';
import '../domain/top_selling_product.dart';

/// Drift-backed [ReportRepository]. Read-only; all writes happen in the
/// checkout service. Maps DAO rows to domain models.
class DriftReportRepository implements ReportRepository {
  DriftReportRepository(this._dao);

  final SaleDao _dao;

  @override
  Future<ReportSummary> getSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final result = await _dao.getSalesSummary(start: start, end: end);
    return ReportSummary(
      totalSalesPaise: result.totalSalesPaise,
      transactionCount: result.transactionCount,
    );
  }

  @override
  Stream<ReportSummary> watchSummary({
    required DateTime start,
    required DateTime end,
  }) {
    return _dao.watchSalesSummary(start: start, end: end).map(
          (result) => ReportSummary(
            totalSalesPaise: result.totalSalesPaise,
            transactionCount: result.transactionCount,
          ),
        );
  }

  @override
  Future<List<TopSellingProduct>> getTopSelling({
    required DateTime start,
    required DateTime end,
    int limit = 5,
  }) async {
    final rows = await _dao.getTopSelling(
      start: start,
      end: end,
      limit: limit,
    );
    return rows
        .map((r) => TopSellingProduct(
              productName: r.productName,
              quantitySold: r.quantitySold,
            ))
        .toList();
  }

  @override
  Stream<List<TopSellingProduct>> watchTopSelling({
    required DateTime start,
    required DateTime end,
    int limit = 5,
  }) {
    return _dao
        .watchTopSelling(start: start, end: end, limit: limit)
        .map(
          (rows) => rows
              .map((r) => TopSellingProduct(
                    productName: r.productName,
                    quantitySold: r.quantitySold,
                  ))
              .toList(),
        );
  }

  @override
  Future<List<Sale>> recentSales({int limit = 5}) async {
    final rows = await _dao.recentSales(limit: limit);
    return rows.map(_toSale).toList();
  }

  Sale _toSale(db.Sale row) {
    return Sale(
      id: row.id,
      transactionNumber: row.transactionNumber,
      paymentMethod: PaymentMethod.fromStorage(row.paymentMethod),
      subtotalPaise: row.subtotalPaise,
      totalPaise: row.totalPaise,
      createdAt: row.createdAt,
      itemCount: 0,
    );
  }
}
