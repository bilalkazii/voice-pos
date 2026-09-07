import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failures.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../domain/cart_item.dart';
import 'cart_providers.dart';
import 'product_picker_sheet.dart';

/// Current Bill — the default (home) screen. In-memory cart state only;
/// nothing here writes to the database.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add product',
            onPressed: () => _openPicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear bill',
            onPressed: cart.isEmpty ? null : () => _confirmClear(context, ref),
          ),
        ],
      ),
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
            child: Row(
              children: [
                Text(
                  'Current Bill',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: AppTokens.space8),
                Text(
                  cart.isEmpty
                      ? 'empty'
                      : '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: cart.isEmpty
                ? _EmptyBill(onAdd: () => _openPicker(context))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.screenPadding,
                    ),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) => const SizedBox(
                      height: AppTokens.space8,
                    ),
                    itemBuilder: (context, index) =>
                        _CartLineCard(item: cart.items[index]),
                  ),
          ),
          _TotalRow(totalPaise: cart.totalPaise),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.screenPadding,
              AppTokens.space8,
              AppTokens.screenPadding,
              0,
            ),
            child: FilledButton.icon(
              onPressed: () => _voiceComingSoon(context),
              icon: const Icon(Icons.mic, size: AppTokens.iconMedium),
              label: const Text('SPEAK'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.screenPadding,
              AppTokens.space8,
              AppTokens.screenPadding,
              AppTokens.screenPadding,
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.checkoutGreen,
                disabledBackgroundColor:
                    AppTokens.checkoutGreen.withValues(alpha: 0.4),
              ),
              onPressed:
                  cart.isEmpty ? null : () => context.push('/checkout'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('CHECKOUT'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final message = await showProductPickerSheet(context);
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _voiceComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice input arrives in a later phase.'),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear current bill?'),
        content: const Text(
          'All items will be removed. Inventory is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.destructiveRed,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cartProvider.notifier).clearCart();
    }
  }
}

class _CartLineCard extends ConsumerWidget {
  const _CartLineCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(cartProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    '${item.quantity} × ${Money.formatPaise(item.unitPricePaise)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        tooltip: 'Decrease quantity',
                        onPressed: () => _mutate(
                          context,
                          () => notifier.decreaseQuantity(item.productId),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Increase quantity',
                        onPressed: () => _mutate(
                          context,
                          () => notifier.increaseQuantity(item.productId),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Money.formatPaise(item.lineTotalPaise),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppTokens.onSurfaceVariant,
                  tooltip: 'Remove item',
                  onPressed: () =>
                      notifier.removeProduct(item.productId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mutate(BuildContext context, Failure? Function() action) {
    final failure = action();
    if (failure != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    }
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.totalPaise});

  final int totalPaise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTokens.screenPadding,
        AppTokens.space8,
        AppTokens.screenPadding,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: AppTokens.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total', style: theme.textTheme.titleMedium),
          Text(
            Money.formatPaise(totalPaise),
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: AppTokens.fontTotal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBill extends StatelessWidget {
  const _EmptyBill({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: AppTokens.iconLarge,
              color: AppTokens.onSurfaceVariant,
            ),
            const SizedBox(height: AppTokens.space12),
            Text('No items yet.', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTokens.space4),
            Text(
              'Add products manually to start a sale.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.space16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}
