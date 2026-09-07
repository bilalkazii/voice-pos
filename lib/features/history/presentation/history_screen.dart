import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../checkout/domain/sale.dart';
import '../domain/daily_sales_summary.dart';
import '../domain/history_day_filter.dart';
import 'history_formatters.dart';
import 'history_providers.dart';

/// Sales history. Read-only, newest-first, bounded offline list with
/// transaction-number search, an All/Today filter, and a compact today
/// summary. Completed sales are immutable — there are no edit/delete
/// controls here.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  int _debounceId = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final id = ++_debounceId;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (id == _debounceId && mounted) {
        ref.read(historySearchQueryProvider.notifier).set(value);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(historySearchQueryProvider.notifier).clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(historySalesProvider);
    final summary = ref.watch(historySummaryProvider);
    final filter = ref.watch(historyDayFilterProvider);
    final query = ref.watch(historySearchQueryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.screenPadding,
              AppTokens.screenPadding,
              AppTokens.screenPadding,
              AppTokens.space8,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search transactions…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTokens.radiusButton),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.screenPadding,
              0,
              AppTokens.screenPadding,
              AppTokens.space8,
            ),
            child: Row(
              children: [
                for (final option in HistoryDayFilter.values) ...[
                  _FilterChip(
                    label: option.label,
                    selected: filter == option,
                    onTap: () => ref
                        .read(historyDayFilterProvider.notifier)
                        .set(option),
                  ),
                  if (option != HistoryDayFilter.values.last)
                    const SizedBox(width: AppTokens.space8),
                ],
              ],
            ),
          ),
          if (filter == HistoryDayFilter.today)
            summary.when(
              data: (s) => _TodaySummaryCard(summary: s),
              loading: () => const _SummarySkeleton(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          const SizedBox(height: AppTokens.space8),
          const _SectionHeader(),
          Expanded(
            child: salesAsync.when(
              data: (sales) => sales.isEmpty
                  ? _HistoryEmpty(query: query)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.screenPadding,
                        0,
                        AppTokens.screenPadding,
                        AppTokens.screenPadding,
                      ),
                      itemCount: sales.length,
                      separatorBuilder: (_, _) => const SizedBox(
                        height: AppTokens.space8,
                      ),
                      itemBuilder: (context, index) =>
                          _SaleCard(sale: sales[index]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _HistoryError(
                message: 'Could not load sales.',
                onRetry: () => ref.invalidate(historySalesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.summary});

  final DailySalesSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTokens.screenPadding,
        0,
        AppTokens.screenPadding,
        AppTokens.space8,
      ),
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.voiceBlueSoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TODAY', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppTokens.space4),
          Text(
            Money.formatPaise(summary.totalPaise),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            '${summary.transactionCount} transaction${summary.transactionCount == 1 ? '' : 's'}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTokens.screenPadding,
        0,
        AppTokens.screenPadding,
        AppTokens.space8,
      ),
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: AppTokens.border),
      ),
      child: const SizedBox(
        height: 70,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.screenPadding,
        0,
        AppTokens.screenPadding,
        AppTokens.space8,
      ),
      child: Text(
        'Recent Sales',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: AppTokens.space8,
        ),
        title: Text(
          sale.transactionNumber,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatHistoryDateTime(sale.createdAt),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTokens.space4),
            Text(
              '${sale.paymentMethod.label}  •  ${sale.itemCount} item${sale.itemCount == 1 ? '' : 's'}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
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

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searching = query.trim().isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching
                  ? Icons.search_off_outlined
                  : Icons.receipt_long_outlined,
              size: AppTokens.iconLarge,
              color: AppTokens.onSurfaceVariant,
            ),
            const SizedBox(height: AppTokens.space12),
            Text(
              searching
                  ? 'No transactions found'
                  : 'No sales yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.space4),
            Text(
              searching
                  ? 'Try a different transaction number.'
                  : 'Completed sales will appear here.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.space12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
