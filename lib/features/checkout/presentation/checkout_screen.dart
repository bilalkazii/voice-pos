import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../cart/presentation/cart_providers.dart';

/// Phase 2 placeholder. Real cash checkout (payment, sale persistence,
/// receipt, printing) arrives in the next phase — nothing here processes
/// a payment or touches inventory.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Amount', style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppTokens.space4),
              Text(
                Money.formatPaise(cart.totalPaise),
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: AppTokens.space4),
              Text(
                '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTokens.space16),
              Text(
                'Cash checkout arrives in the next phase. No payment is processed yet.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.space16),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Back to bill'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
