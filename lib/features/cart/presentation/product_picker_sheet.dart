import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../products/domain/product.dart';
import 'cart_providers.dart';

/// Bottom-sheet product picker for the cart. Searches active products by
/// name/SKU through [cartPickerResultsProvider] and adds with quantity 1.
///
/// Returns the message for the caller to show, or `null` when dismissed
/// without a selection.
Future<String?> showProductPickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusSheet),
      ),
    ),
    builder: (sheetContext) => const _ProductPickerSheet(),
  );
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
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
        setState(() => _query = value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(cartPickerResultsProvider(_query));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Product', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppTokens.space12),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search products or SKU',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTokens.radiusButton),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space12),
            Expanded(
              child: results.when(
                data: (products) => products.isEmpty
                    ? Center(
                        child: Text(
                          _query.trim().isEmpty
                              ? 'No products yet. Add them from the Products tab.'
                              : 'No matching products.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(
                          height: AppTokens.space8,
                        ),
                        itemBuilder: (context, index) => _PickerRow(
                          product: products[index],
                          onSelect: _select,
                        ),
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(
                  child: Text('Could not load products.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(Product product) {
    final failure = ref.read(cartProvider.notifier).addProduct(product);
    if (!mounted) return;
    Navigator.of(context).pop(
      failure == null ? 'Added ${product.name}.' : failure.message,
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.product, required this.onSelect});

  final Product product;
  final void Function(Product product) onSelect;

  @override
  Widget build(BuildContext context) {
    final inStock = product.stockQty > 0;
    return Card(
      child: ListTile(
        enabled: inStock,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: AppTokens.space4,
        ),
        title: Text(product.name),
        subtitle: Text(
          inStock
              ? '${Money.formatPaise(product.sellingPricePaise)}  •  Stock ${product.stockQty}'
              : 'Out of stock',
        ),
        trailing: inStock
            ? const Icon(Icons.add_circle, color: AppTokens.voiceBlue)
            : const Text('Out of stock'),
        onTap: inStock ? () => onSelect(product) : null,
      ),
    );
  }
}
