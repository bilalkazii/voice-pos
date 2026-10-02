import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failures.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../voice/domain/voice_state.dart';
import '../../voice/presentation/voice_providers.dart';
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
    ref.listen(
      voiceControllerProvider.select((s) => s.checkoutRequestId),
      (previous, next) {
        if (next > (previous ?? 0) && context.mounted) {
          context.push('/checkout');
        }
      },
    );
    ref.listen(
      voiceControllerProvider.select((s) => s.status),
      (previous, next) async {
        if (previous == next || !context.mounted) return;
        final voice = ref.read(voiceControllerProvider);
        if ((next == VoiceStatus.success || next == VoiceStatus.error) &&
            voice.message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(voice.message)),
          );
        } else if (next == VoiceStatus.confirmationRequired) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Clear the current bill?'),
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
          if (!context.mounted) return;
          final controller = ref.read(voiceControllerProvider.notifier);
          if (confirmed == true) {
            await controller.confirmPendingClear();
          } else {
            controller.cancelPending();
          }
        }
      },
    );

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
          const _VoiceStatusArea(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.screenPadding,
              AppTokens.space8,
              AppTokens.screenPadding,
              0,
            ),
            child: const _VoiceButton(),
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

  void _confirmClear(BuildContext context, WidgetRef ref) async {
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

/// Large push-to-talk button. One tap = one command; tapping while
/// listening cancels. Processing disables the button to avoid races.
/// Shows the active voice language so the cashier knows which locale will
/// be used for the next interaction.
class _VoiceButton extends ConsumerWidget {
  const _VoiceButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      voiceControllerProvider.select((s) => s.status),
    );
    final language = ref.watch(currentVoiceLanguageProvider);
    final controller = ref.read(voiceControllerProvider.notifier);
    final listening = status == VoiceStatus.listening;
    final processing = status == VoiceStatus.processing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: processing
              ? null
              : listening
                  ? controller.cancelListening
                  : controller.startVoiceCommand,
          icon: Icon(
            listening ? Icons.stop : Icons.mic,
            size: AppTokens.iconMedium,
          ),
          label: Text(
            listening
                ? 'LISTENING…'
                : processing
                    ? 'PROCESSING…'
                    : 'SPEAK',
          ),
        ),
        const SizedBox(height: AppTokens.space4),
        Text(
          'Voice: ${language.label}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTokens.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

/// Subtle transcript line plus the clarification card. Success/error
/// feedback travels via SnackBar (see the listeners in [CartScreen]).
class _VoiceStatusArea extends ConsumerWidget {
  const _VoiceStatusArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceControllerProvider);
    final showTranscript = voice.transcript.isNotEmpty &&
        voice.status != VoiceStatus.idle &&
        voice.status != VoiceStatus.listening;
    if (voice.status == VoiceStatus.clarificationRequired) {
      return _ClarificationCard(voice: voice);
    }
    if (!showTranscript) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.screenPadding,
        AppTokens.space8,
        AppTokens.screenPadding,
        0,
      ),
      child: Text(
        'Heard: "${voice.transcript}"',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ClarificationCard extends ConsumerWidget {
  const _ClarificationCard({required this.voice});

  final VoiceState voice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(voiceControllerProvider.notifier);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTokens.screenPadding,
        AppTokens.space8,
        AppTokens.screenPadding,
        0,
      ),
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: AppTokens.voiceBlueSoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            voice.message,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.space8),
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space8,
            children: [
              for (final candidate in voice.candidates)
                ActionChip(
                  label: Text(candidate.name),
                  onPressed: () => controller.chooseCandidate(candidate),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: controller.cancelPending,
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
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
