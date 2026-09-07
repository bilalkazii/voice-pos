import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../cart/presentation/cart_providers.dart';
import '../domain/payment_method.dart';
import 'checkout_providers.dart';

/// Checkout review + explicit cash confirmation. CASH ONLY — no amount
/// entry, no change calculation, no other payment methods.
///
/// Payment starts ONLY from the CONFIRM CASH PAYMENT button. Opening this
/// screen (including via the "Checkout" voice command) never processes
/// anything; voice can navigate here but cannot bypass confirmation.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    // Fresh review state on every entry (e.g. popping back after a sale).
    Future.microtask(
      () => ref.read(checkoutControllerProvider.notifier).reset(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final theme = Theme.of(context);

    ref.listen(checkoutControllerProvider, (previous, next) {
      if (next.status == CheckoutStatus.success &&
          next.completedSale != null &&
          context.mounted) {
        context.go('/payment-complete/${next.completedSale!.sale.id}');
      }
    });

    final processing = checkout.status == CheckoutStatus.processing;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: cart.isEmpty
          ? _EmptyCheckout(onBack: () => context.pop())
          : Column(
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
                        'Review Bill',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(width: AppTokens.space8),
                      Text(
                        '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      const _CashBadge(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.screenPadding,
                    ),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) => const SizedBox(
                      height: AppTokens.space8,
                    ),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Card(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(AppTokens.space12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style:
                                          theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(
                                        height: AppTokens.space4),
                                    Text(
                                      '${item.quantity} × ${Money.formatPaise(item.unitPricePaise)}',
                                      style:
                                          theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                Money.formatPaise(item.lineTotalPaise),
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _TotalRow(totalPaise: cart.totalPaise),
                if (checkout.status == CheckoutStatus.failure &&
                    checkout.message.isNotEmpty)
                  _CheckoutError(message: checkout.message),
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
                      disabledBackgroundColor: AppTokens.checkoutGreen
                          .withValues(alpha: 0.4),
                    ),
                    onPressed: processing
                        ? null
                        : () => ref
                            .read(checkoutControllerProvider.notifier)
                            .confirmCashPayment(),
                    icon: processing
                        ? const SizedBox(
                            width: AppTokens.iconMedium,
                            height: AppTokens.iconMedium,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.payments_outlined,
                            size: AppTokens.iconMedium,
                          ),
                    label: Text(
                      processing
                          ? 'PROCESSING…'
                          : checkout.status == CheckoutStatus.failure
                              ? 'RETRY CONFIRM CASH PAYMENT'
                              : 'CONFIRM CASH PAYMENT',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CashBadge extends StatelessWidget {
  const _CashBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTokens.checkoutGreenSoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Text(
        PaymentMethod.cash.label.toUpperCase(),
        style: const TextStyle(
          color: AppTokens.checkoutGreenDark,
          fontSize: AppTokens.fontLabel,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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

class _CheckoutError extends StatelessWidget {
  const _CheckoutError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTokens.screenPadding,
        AppTokens.space8,
        AppTokens.screenPadding,
        0,
      ),
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: AppTokens.destructiveRedSoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTokens.destructiveRed,
          ),
          const SizedBox(width: AppTokens.space8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('The cart is empty.', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTokens.space4),
            Text(
              'Add products to the bill before checking out.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.space16),
            OutlinedButton(
              onPressed: onBack,
              child: const Text('Back to bill'),
            ),
          ],
        ),
      ),
    );
  }
}
