import 'package:flutter/material.dart';

/// Phase 0 placeholder for the cart / current-sale screen.
///
/// This will become the default (home) screen in Phase 1+.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderView(
      title: 'Current Bill',
      message: 'Cart arrives in Phase 1.',
    );
  }
}

/// Shared lightweight placeholder used by all Phase 0 feature screens.
class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(message, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
