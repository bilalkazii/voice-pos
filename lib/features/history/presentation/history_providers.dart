import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/today.dart';
import '../../checkout/domain/sale.dart';
import '../../checkout/presentation/checkout_providers.dart';
import '../domain/daily_sales_summary.dart';
import '../domain/history_day_filter.dart';

/// Debounced transaction-number search text (the History search field).
class HistorySearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) {
    if (state != value) state = value;
  }

  void clear() => state = '';
}

final historySearchQueryProvider =
    NotifierProvider<HistorySearchQuery, String>(HistorySearchQuery.new);

/// All / Today filter for the History list.
class HistoryDayFilterNotifier extends Notifier<HistoryDayFilter> {
  @override
  HistoryDayFilter build() => HistoryDayFilter.all;

  void set(HistoryDayFilter filter) {
    if (state != filter) state = filter;
  }
}

final historyDayFilterProvider =
    NotifierProvider<HistoryDayFilterNotifier, HistoryDayFilter>(
  HistoryDayFilterNotifier.new,
);

/// The bounded, reactive history list combining the search text and the
/// day filter. Newest-first, capped at 50, item counts included; updates
/// live after checkout. The day boundary follows [todayStartProvider], so
/// an app left open across midnight re-queries instead of showing
/// yesterday's "Today".
final historySalesProvider = StreamProvider<List<Sale>>((ref) {
  final repository = ref.watch(saleRepositoryProvider);
  final query = ref.watch(historySearchQueryProvider);
  final filter = ref.watch(historyDayFilterProvider);
  final todayStart = ref.watch(todayStartProvider);
  return repository.watchSalesWithCount(
    after: filter == HistoryDayFilter.today ? todayStart : null,
    transactionSearch: query,
  );
});

/// Live, bounded stream of just today's sales (with counts) — the single
/// source for the summary card. Reactive so the summary updates after a
/// new checkout.
final todaySalesProvider = StreamProvider<List<Sale>>((ref) {
  final todayStart = ref.watch(todayStartProvider);
  return ref.watch(saleRepositoryProvider).watchSalesWithCount(
        after: todayStart,
      );
});

/// Derived compact summary for today (count + total), integer paise.
final historySummaryProvider = Provider<AsyncValue<DailySalesSummary>>((ref) {
  final sales = ref.watch(todaySalesProvider);
  return sales.when(
    data: (items) => AsyncData(
      DailySalesSummary(
        transactionCount: items.length,
        totalPaise: items.fold(0, (sum, e) => sum + e.totalPaise),
      ),
    ),
    loading: () => const AsyncLoading(),
    error: (e, _) => AsyncError(e, StackTrace.current),
  );
});

/// A committed sale with its lines for the detail screen.
final saleDetailProvider =
    FutureProvider.autoDispose.family<CompletedSale?, int>((ref, saleId) {
  return ref.watch(saleRepositoryProvider).getSaleWithItems(saleId);
});
