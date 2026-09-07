import 'package:flutter/material.dart';

/// Phase 0 placeholder. Checkout arrives in a later phase.
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: Text(
          'Checkout arrives in a later phase.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
