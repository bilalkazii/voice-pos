import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../domain/product.dart';
import 'products_providers.dart';

/// Add/edit product form. Converts cashier-typed prices (e.g. "112.00")
/// into integer paise with [Product.tryParsePriceToPaise] — never `double`.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  /// Null for "add", non-null for "edit".
  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _price;
  late final TextEditingController _cost;
  late final TextEditingController _stock;
  late final TextEditingController _threshold;
  bool _saving = false;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _price = TextEditingController(
      text: p == null ? '' : _paiseToInput(p.sellingPricePaise),
    );
    _cost = TextEditingController(
      text: p?.costPricePaise == null
          ? ''
          : _paiseToInput(p!.costPricePaise!),
    );
    _stock = TextEditingController(text: p == null ? '0' : '${p.stockQty}');
    _threshold = TextEditingController(
      text: p == null ? '5' : '${p.lowStockThreshold}',
    );
  }

  /// Paise → editable "112.00" string (integer math only).
  String _paiseToInput(int paise) {
    final rupees = paise ~/ 100;
    final rest = (paise % 100).toString().padLeft(2, '0');
    return '$rupees.$rest';
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _cost.dispose();
    _stock.dispose();
    _threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Product' : 'Add Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.screenPadding),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Product name *',
                hintText: 'e.g. Pepsi 500ml',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required.' : null,
            ),
            const SizedBox(height: AppTokens.space12),
            TextFormField(
              controller: _sku,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'SKU (optional)',
                hintText: 'e.g. PEP-500',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTokens.space12),
            TextFormField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,₹ ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Selling price (₹) *',
                hintText: 'e.g. 112.00',
                border: OutlineInputBorder(),
              ),
              validator: (v) => Product.tryParsePriceToPaise(v ?? '') == null
                  ? 'Enter a valid price, e.g. 112.00.'
                  : null,
            ),
            const SizedBox(height: AppTokens.space12),
            TextFormField(
              controller: _cost,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,₹ ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Cost price (₹, optional)',
                hintText: 'e.g. 90.00',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return Product.tryParsePriceToPaise(v) == null
                    ? 'Enter a valid price, e.g. 90.00.'
                    : null;
              },
            ),
            const SizedBox(height: AppTokens.space12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Stock *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _validateNonNegativeInt(v, 'Stock'),
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: TextFormField(
                    controller: _threshold,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Low-stock at *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        _validateNonNegativeInt(v, 'Threshold'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? 'Saving…'
                    : _editing
                        ? 'Save Changes'
                        : 'Add Product',
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: AppTokens.space12),
              Text(
                'Price preview: ${_previewPrice()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _validateNonNegativeInt(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return '$label cannot be negative.';
    }
    return null;
  }

  String _previewPrice() {
    final paise = Product.tryParsePriceToPaise(_price.text);
    return paise == null ? '—' : Money.formatPaise(paise);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final price = Product.tryParsePriceToPaise(_price.text)!;
      final cost = _cost.text.trim().isEmpty
          ? null
          : Product.tryParsePriceToPaise(_cost.text)!;
      final controller = ref.read(productsControllerProvider.notifier);
      final failure = _editing
          ? await controller.updateProduct(
              id: widget.product!.id,
              name: _name.text,
              sku: _sku.text.trim().isEmpty ? null : _sku.text,
              sellingPricePaise: price,
              costPricePaise: cost,
              stockQty: int.parse(_stock.text.trim()),
              lowStockThreshold: int.parse(_threshold.text.trim()),
            )
          : await controller.createProduct(
              name: _name.text,
              sku: _sku.text.trim().isEmpty ? null : _sku.text,
              sellingPricePaise: price,
              costPricePaise: cost,
              stockQty: int.parse(_stock.text.trim()),
              lowStockThreshold: int.parse(_threshold.text.trim()),
            );
      if (!mounted) return;
      if (failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
