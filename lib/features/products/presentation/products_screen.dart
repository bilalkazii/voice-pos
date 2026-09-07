import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../domain/product.dart';
import 'product_form_screen.dart';
import 'products_providers.dart';

/// Products screen: searchable active-product list with add/edit/deactivate.
///
/// Presentation only — all data flows through Riverpod providers; widgets
/// never touch the database or DAO directly.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Debounce: avoid re-querying the database on every keystroke.
    _debounce(() {
      ref.read(productSearchQueryProvider.notifier).set(value);
    });
  }

  void _debounce(void Function() action) {
    _pendingAction = action;
    _debounceId++;
    final id = _debounceId;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (id == _debounceId && mounted) _pendingAction?.call();
    });
  }

  void Function()? _pendingAction;
  int _debounceId = 0;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final lowStock = ref.watch(lowStockProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        tooltip: 'Add product',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTokens.screenPadding),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search products or SKU',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(productSearchQueryProvider.notifier)
                              .clear();
                          setState(() {});
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTokens.radiusButton),
                ),
              ),
            ),
          ),
          lowStock.when(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : _LowStockBanner(count: items.length),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Expanded(
            child: products.when(
              data: (items) => items.isEmpty
                  ? _EmptyState(
                      searching:
                          ref.watch(productSearchQueryProvider).isNotEmpty,
                      onAdd: () => _openForm(context),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.screenPadding,
                        AppTokens.space8,
                        AppTokens.screenPadding,
                        96,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(
                        height: AppTokens.space8,
                      ),
                      itemBuilder: (context, index) =>
                          _ProductCard(product: items[index]),
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ProductsError(
                message: e is Exception ? e.toString() : 'Could not load products.',
                onRetry: () => ref.invalidate(productsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {Product? product}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product == null ? 'Product added.' : 'Product updated.',
          ),
        ),
      );
    }
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    [
                      if (product.sku != null) 'SKU ${product.sku}',
                      'Stock ${product.stockQty}',
                    ].join('  •  '),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTokens.space4),
                  Row(
                    children: [
                      Text(
                        Money.formatPaise(product.sellingPricePaise),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (product.isLowStock) ...[
                        const SizedBox(width: AppTokens.space8),
                        _LowStockChip(left: product.stockQty),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Product actions',
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ProductFormScreen(product: product),
                    ),
                  );
                } else if (value == 'deactivate') {
                  _confirmDeactivate(context, ref);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuItem(
                  value: 'deactivate',
                  child: ListTile(
                    leading: Icon(
                      Icons.archive_outlined,
                      color: AppTokens.destructiveRed,
                    ),
                    title: Text('Deactivate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate product?'),
        content: Text(
          '"${product.name}" will be hidden from the product list. '
          'It stays saved for past records.',
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
          child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final failure = await ref
        .read(productsControllerProvider.notifier)
        .deactivateProduct(product.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null ? 'Product deactivated.' : failure.message,
        ),
      ),
    );
  }
}

class _LowStockChip extends StatelessWidget {
  const _LowStockChip({required this.left});

  final int left;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTokens.warningAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Text(
        'Low: $left left',
        style: const TextStyle(
          color: Color(0xFF92400E),
          fontSize: AppTokens.fontLabel,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTokens.screenPadding,
        0,
        AppTokens.screenPadding,
        AppTokens.space8,
      ),
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: AppTokens.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: Color(0xFF92400E)),
          const SizedBox(width: AppTokens.space8),
          Expanded(
            child: Text(
              count == 1
                  ? '1 product is low on stock.'
                  : '$count products are low on stock.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching, required this.onAdd});

  final bool searching;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching
                  ? Icons.search_off_outlined
                  : Icons.inventory_2_outlined,
              size: AppTokens.iconLarge,
              color: AppTokens.onSurfaceVariant,
            ),
            const SizedBox(height: AppTokens.space12),
            Text(
              searching ? 'No matching products.' : 'No products yet.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.space4),
            Text(
              searching
                  ? 'Try a different name or SKU.'
                  : 'Add your first product to get started.',
              style: theme.textTheme.bodyMedium,
            ),
            if (!searching) ...[
              const SizedBox(height: AppTokens.space16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductsError extends StatelessWidget {
  const _ProductsError({required this.message, required this.onRetry});

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
