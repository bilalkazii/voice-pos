import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import 'history_formatters.dart';
import 'history_providers.dart';

/// Read-only detail for one committed transaction, rendered from stored
/// SaleItem snapshots. Completed sales are immutable — there are no
/// edit/delete/refund controls here. Provides VIEW RECEIPT via the existing
/// receipt screen.
class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleDetailProvider(saleId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sale Detail')),
      body: saleAsync.when(
        data: (completed) {
          if (completed == null) {
            return const Center(child: Text('Sale not found.'));
          }
          final sale = completed.sale;
          return ListView(
            padding: const EdgeInsets.all(AppTokens.screenPadding),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        sale.transactionNumber,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTokens.space8),
                      _InfoRow(
                        label: 'Date',
                        value: formatHistoryDateTime(sale.createdAt),
                      ),
                      _InfoRow(
                        label: 'Payment',
                        value: sale.paymentMethod.label,
                      ),
                      _InfoRow(
                        label: 'Items',
                        value: '${completed.itemCount}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space12),
              for (final item in completed.items) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.space12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName,
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppTokens.space4),
                        Text(
                          '${item.quantity} × ${Money.formatPaise(item.unitPricePaise)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppTokens.space4),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Line total',
                                style: theme.textTheme.bodyMedium),
                            Text(
                              Money.formatPaise(item.lineTotalPaise),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space8),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.space16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal', style: theme.textTheme.bodyMedium),
                      Text(
                        Money.formatPaise(sale.subtotalPaise),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.space16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: theme.textTheme.titleMedium),
                      Text(
                        Money.formatPaise(sale.totalPaise),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space16),
              OutlinedButton.icon(
                onPressed: () => context.push('/receipt/${sale.id}'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('VIEW RECEIPT'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load sale.')),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
