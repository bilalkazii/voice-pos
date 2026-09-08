import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../settings/presentation/settings_providers.dart';
import 'checkout_providers.dart';

/// Success screen shown exactly once per committed sale. Renders the
/// COMMITTED transaction (loaded by id from the repository) — never the
/// live cart, which was cleared after commit.
///
/// PRINTER INTEGRATION POINT (dedicated printer phase): printing starts
/// from the committed sale data available here. A printer failure must
/// NEVER roll the sale back, restore stock, or duplicate the transaction —
/// the database commit above is authoritative.
class PaymentCompleteScreen extends ConsumerWidget {
  const PaymentCompleteScreen({super.key, required this.saleId});

  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(completedSaleProvider(saleId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Complete'),
        automaticallyImplyLeading: false,
      ),
      body: saleAsync.when(
        data: (completed) {
          if (completed == null) {
            return _UnknownSale(onNewSale: () => context.go('/'));
          }
          final sale = completed.sale;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.space24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 72,
                    color: AppTokens.checkoutGreen,
                  ),
                  const SizedBox(height: AppTokens.space12),
                  Text(
                    'Payment Complete!',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    Money.formatPaise(sale.totalPaise),
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    '${completed.itemCount} item${completed.itemCount == 1 ? '' : 's'}  •  Cash',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTokens.space8),
                  SelectableText(
                    sale.transactionNumber,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('d MMM yyyy, h:mm a')
                        .format(sale.createdAt.toLocal()),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTokens.space20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTokens.checkoutGreen,
                    ),
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('NEW SALE'),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/receipt/${sale.id}'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('VIEW RECEIPT'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _UnknownSale(onNewSale: () => context.go('/')),
      ),
    );
  }
}

class _UnknownSale extends StatelessWidget {
  const _UnknownSale({required this.onNewSale});

  final VoidCallback onNewSale;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sale not found.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.space16),
            FilledButton(
              onPressed: onNewSale,
              child: const Text('NEW SALE'),
            ),
          ],
        ),
      ),
    );
  }
}

/// On-screen receipt for a committed sale. All data comes from the stored
/// Sale/SaleItems snapshots — product renames or reprices after the sale
/// never change this view.
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.saleId});

  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(completedSaleProvider(saleId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: saleAsync.when(
        data: (completed) {
          if (completed == null) {
            return const Center(child: Text('Receipt not found.'));
          }
          final sale = completed.sale;
          return ListView(
            padding: const EdgeInsets.all(AppTokens.screenPadding),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        ref.watch(storeNameProvider),
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTokens.space4),
                      Text(
                        sale.transactionNumber,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        DateFormat('d MMM yyyy, h:mm a')
                            .format(sale.createdAt.toLocal()),
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const Divider(height: AppTokens.space24),
                      for (final item in completed.items) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName),
                                  Text(
                                    '${item.quantity} × ${Money.formatPaise(item.unitPricePaise)}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Money.formatPaise(item.lineTotalPaise),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.space8),
                      ],
                      const Divider(height: AppTokens.space24),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total',
                              style: theme.textTheme.titleMedium),
                          Text(
                            Money.formatPaise(sale.totalPaise),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space4),
                      Text(
                        'Paid by ${sale.paymentMethod.label}',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.checkoutGreen,
                ),
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('NEW SALE'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Could not load receipt.')),
      ),
    );
  }
}
