import 'package:flutter/material.dart';

/// Phase 0 placeholder. Products CRUD arrives in a later phase.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: Center(
        child: Text(
          'Products arrive in a later phase.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
