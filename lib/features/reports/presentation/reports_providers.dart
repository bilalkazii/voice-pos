import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../checkout/domain/sale.dart';
import '../../checkout/presentation/checkout_providers.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/products_providers.dart';
import '../data/report_repository_impl.dart';
import '../domain/report_date_range.dart';
import '../domain/report_repository.dart';
import '../domain/report_summary.dart';
import '../domain/top_selling_product.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => DriftReportRepository(ref.watch(saleDaoProvider)),
);

/// Currently selected report date range.
class ReportDateRangeNotifier extends Notifier<ReportDateRange> {
  @override
  ReportDateRange build() => ReportDateRange.today;

  void set(ReportDateRange range) {
    if (state != range) state = range;
  }
}

final reportDateRangeProvider =
    NotifierProvider<ReportDateRangeNotifier, ReportDateRange>(
  ReportDateRangeNotifier.new,
);

/// Resolves the selected [ReportDateRange] against the local clock.
final reportRangeProvider = Provider<({DateTime start, DateTime end})>((ref) {
  return ref
      .watch(reportDateRangeProvider)
      .rangeFor(DateTime.now());
});

/// Reactive aggregate summary (total + count + avg) for the current range.
/// Updates live after a committed sale — no app restart.
final reportSummaryProvider = StreamProvider<ReportSummary>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref
      .watch(reportRepositoryProvider)
      .watchSummary(start: range.start, end: range.end);
});

/// Reactive top-selling list for the current range.
final topSellingProductsProvider = StreamProvider<List<TopSellingProduct>>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref
      .watch(reportRepositoryProvider)
      .watchTopSelling(start: range.start, end: range.end);
});

/// Low-stock active products — reuses the Phase 1 definition
/// (`stockQty <= lowStockThreshold`) via ProductRepository.
final reportLowStockProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchLowStock();
});

/// Most recent committed sales (small bounded list) for the dashboard.
/// Reactive — updates live when a new sale commits.
final reportRecentSalesProvider = StreamProvider<List<Sale>>((ref) {
  return ref.watch(saleRepositoryProvider).watchRecentSales(limit: 5);
});
