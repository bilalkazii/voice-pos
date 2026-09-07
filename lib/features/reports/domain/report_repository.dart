import '../../checkout/domain/sale.dart';
import 'report_summary.dart';
import 'top_selling_product.dart';

/// Read-side contract for the Reports dashboard. Exposes domain models only
/// — never Drift rows, SQL, aliases, or expressions. All metrics derive from
/// completed `Sales`/`SaleItems`; the live cart and current product catalog
/// are never used. Aggregations run inside SQLite.
abstract class ReportRepository {
  /// One-shot summary (total paise + transaction count) for a half-open
  /// range. `averageBillPaise` is derived in the domain model.
  Future<ReportSummary> getSummary({required DateTime start, required DateTime end});

  /// Reactive summary for the same range — updates when a sale commits.
  Stream<ReportSummary> watchSummary({required DateTime start, required DateTime end});

  /// One-shot top-selling products (by summed quantity) for the range.
  Future<List<TopSellingProduct>> getTopSelling({
    required DateTime start,
    required DateTime end,
    int limit,
  });

  /// Reactive top-selling products for the range.
  Stream<List<TopSellingProduct>> watchTopSelling({
    required DateTime start,
    required DateTime end,
    int limit,
  });

  /// Most recent committed sales, newest first. Reuses the Phase 5 history
  /// read path so Reports can link into the existing Sale Detail screen.
  Future<List<Sale>> recentSales({int limit});
}
