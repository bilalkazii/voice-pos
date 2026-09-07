import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../products/presentation/products_providers.dart';
import '../data/sale_repository_impl.dart';
import '../domain/checkout_service.dart';
import '../domain/sale.dart';
import '../domain/sale_repository.dart';

final saleDaoProvider = Provider(
  (ref) => ref.watch(databaseProvider).saleDao,
);

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => DriftSaleRepository(ref.watch(saleDaoProvider)),
);

final checkoutServiceProvider = Provider<CheckoutService>(
  (ref) => CheckoutService(ref.watch(databaseProvider)),
);

/// Read path for receipt/payment-complete screens: the committed sale,
/// never the (cleared) cart.
final completedSaleProvider =
    FutureProvider.family<CompletedSale?, int>((ref, saleId) {
  return ref.watch(saleRepositoryProvider).getSaleWithItems(saleId);
});

/// UI states for the explicit cash-confirmation step.
enum CheckoutStatus {
  /// Reviewing the bill; confirmation allowed.
  ready,

  /// Transaction running; confirmation disabled, taps ignored.
  processing,

  /// Committed; cart cleared exactly once by the controller.
  success,

  /// Failed; cart intact, retry allowed.
  failure,
}

class CheckoutUiState {
  const CheckoutUiState({
    this.status = CheckoutStatus.ready,
    this.completedSale,
    this.message = '',
  });

  final CheckoutStatus status;
  final CompletedSale? completedSale;
  final String message;

  CheckoutUiState copyWith({
    CheckoutStatus? status,
    CompletedSale? completedSale,
    String? message,
  }) {
    return CheckoutUiState(
      status: status ?? this.status,
      completedSale: completedSale ?? this.completedSale,
      message: message ?? this.message,
    );
  }
}

/// Runs the explicit CONFIRM CASH PAYMENT step. Safety rules:
/// - payment starts ONLY from [confirmCashPayment] (never init/navigation)
/// - while processing, further taps are ignored (double-tap protection)
/// - after success, further taps are ignored (no duplicate sales)
/// - the cart is cleared ONLY after the transaction commits
/// - on failure the cart is untouched and the cashier can retry
class CheckoutController extends Notifier<CheckoutUiState> {
  @override
  CheckoutUiState build() => const CheckoutUiState();

  Future<void> confirmCashPayment() async {
    if (state.status == CheckoutStatus.processing ||
        state.status == CheckoutStatus.success) {
      return;
    }
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      state = state.copyWith(
        status: CheckoutStatus.failure,
        message: 'The cart is empty.',
      );
      return;
    }
    state = state.copyWith(status: CheckoutStatus.processing, message: '');
    try {
      final completed = await ref
          .read(checkoutServiceProvider)
          .completeCashSale(cart);
      // Commit succeeded — NOW, and only now, clear the bill.
      ref.read(cartProvider.notifier).clearCart();
      state = CheckoutUiState(
        status: CheckoutStatus.success,
        completedSale: completed,
      );
    } on Failure catch (e) {
      state = CheckoutUiState(
        status: CheckoutStatus.failure,
        message: e.message,
      );
    } catch (e) {
      state = CheckoutUiState(
        status: CheckoutStatus.failure,
        message: 'Checkout failed. Please try again.',
      );
    }
  }

  void reset() {
    state = const CheckoutUiState();
  }
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutUiState>(
  CheckoutController.new,
);
