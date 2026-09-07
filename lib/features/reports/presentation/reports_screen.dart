import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../checkout/domain/sale.dart';
import '../../products/domain/product.dart';
import '../domain/report_date_range.dart';
import '../domain/report_summary.dart';
import '../domain/top_selling_product.dart';
import 'reports_providers.dart';

/// Reports & Dashboard. All metrics derive from COMPLETED sales
/// (`Sales`/`SaleItems`) — never the live cart or current product catalog.
/// Offline, reactive (new commits appear without a restart), mobile-first
/// portrait, no charts.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      // SingleChildScrollView + Column builds every section eagerly (a
      // ListView would lazily build off-screen sections), so the dashboard
      // renders fully on any height and never overflows.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _DateRangeSelector(),
            SizedBox(height: AppTokens.space12),
            _SummaryCards(),
            SizedBox(height: AppTokens.space16),
            _SectionTitle('Top Selling'),
            SizedBox(height: AppTokens.space8),
            _TopSellingSection(),
            SizedBox(height: AppTokens.space16),
            _SectionTitle('Low Stock'),
            SizedBox(height: AppTokens.space8),
            _LowStockSection(),
            SizedBox(height: AppTokens.space16),
            _SectionTitle('Recent Transactions'),
            SizedBox(height: AppTokens.space8),
            _RecentTransactionsSection(),
            SizedBox(height: AppTokens.space24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _DateRangeSelector extends ConsumerWidget {
  const _DateRangeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(reportDateRangeProvider);
    return DropdownButtonFormField<ReportDateRange>(
      initialValue: selected,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
      ),
      items: [
        for (final range in ReportDateRange.values)
          DropdownMenuItem(value: range, child: Text(range.label)),
      ],
      onChanged: (value) {
        if (value != null) {
          ref.read(reportDateRangeProvider.notifier).set(value);
        }
      },
    );
  }
}

class _SummaryCards extends ConsumerWidget {
  const _SummaryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reportSummaryProvider);
    return summary.when(
      data: (s) => _SummaryGrid(summary: s),
      loading: () => const _DashboardCardSkeleton(),
      error: (e, _) => _SectionError(
        message: 'Could not load summary.',
        onRetry: () => ref.invalidate(reportSummaryProvider),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SalesCard(summary: summary),
        const SizedBox(height: AppTokens.space8),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Avg Bill',
                value: Money.formatPaise(summary.averageBillPaise),
              ),
            ),
            const SizedBox(width: AppTokens.space8),
            Expanded(
              child: _MetricCard(
                label: 'Transactions',
                value: '${summary.transactionCount}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.voiceBlueSoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Sales", style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppTokens.space4),
          Text(
            Money.formatPaise(summary.totalSalesPaise),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            summary.transactionCount == 1
                ? '1 transaction'
                : '${summary.transactionCount} transactions',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: AppTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppTokens.space4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSellingSection extends ConsumerWidget {
  const _TopSellingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(topSellingProductsProvider);
    return products.when(
      data: (items) => items.isEmpty
          ? const _SectionEmpty('No product sales in this period.')
          : Column(
              children: [
                for (final p in items)
                  _TopSellingRow(item: p),
              ],
            ),
      loading: () => const _DashboardCardSkeleton(),
      error: (_, _) => _SectionError(
        message: 'Could not load top-selling.',
        onRetry: () => ref.invalidate(topSellingProductsProvider),
      ),
    );
  }
}

class _TopSellingRow extends StatelessWidget {
  const _TopSellingRow({required this.item});

  final TopSellingProduct item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.space8),
      child: ListTile(
        title: Text(item.productName),
        trailing: Text(
          '${item.quantitySold}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${item.quantitySold} sold',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _LowStockSection extends ConsumerWidget {
  const _LowStockSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(reportLowStockProvider);
    return products.when(
      data: (items) => items.isEmpty
          ? const _SectionEmpty('Stock levels look good.')
          : Column(
              children: [
                for (final p in items)
                  _LowStockRow(product: p),
              ],
            ),
      loading: () => const _DashboardCardSkeleton(),
      error: (_, _) => _SectionError(
        message: 'Could not load stock levels.',
        onRetry: () => ref.invalidate(reportLowStockProvider),
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.space8),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_outlined,
            color: AppTokens.warningAmber),
        title: Text(product.name),
        trailing: Text(
          '${product.stockQty} left',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RecentTransactionsSection extends ConsumerWidget {
  const _RecentTransactionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(reportRecentSalesProvider);
    return sales.when(
      data: (items) => items.isEmpty
          ? const _SectionEmpty('No recent transactions.')
          : Column(
              children: [
                for (final sale in items)
                  _RecentSaleRow(sale: sale),
              ],
            ),
      loading: () => const _DashboardCardSkeleton(),
      error: (_, _) => _SectionError(
        message: 'Could not load recent transactions.',
        onRetry: () => ref.invalidate(reportRecentSalesProvider),
      ),
    );
  }
}

class _RecentSaleRow extends StatelessWidget {
  const _RecentSaleRow({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.space8),
      child: ListTile(
        title: Text(
          sale.transactionNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(sale.paymentMethod.label),
        trailing: Text(
          Money.formatPaise(sale.totalPaise),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        onTap: () => context.push('/sale/${sale.id}'),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: AppTokens.border),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.destructiveRedSoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTokens.destructiveRed),
          const SizedBox(width: AppTokens.space8),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _DashboardCardSkeleton extends StatelessWidget {
  const _DashboardCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: AppTokens.border),
      ),
      child: const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
