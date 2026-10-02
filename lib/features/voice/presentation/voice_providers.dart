import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/money.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_repository.dart';
import '../../products/presentation/products_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/stt_speech_service.dart';
import '../data/tts_feedback_service.dart';
import '../domain/command_parser.dart';
import '../domain/product_matcher.dart';
import '../domain/speech_services.dart';
import '../domain/voice_command.dart';
import '../domain/voice_feedback_text.dart';
import '../domain/voice_language.dart';
import '../domain/voice_state.dart';

final speechServiceProvider = Provider<SpeechToTextService>(
  (ref) {
    final service = SttSpeechService();
    ref.onDispose(() => unawaited(service.stop()));
    return service;
  },
);

/// The selected voice command language. Gated by the persisted Settings
/// toggle (TTS stays optional — STT and parsing proceed regardless).
final currentVoiceLanguageProvider = Provider<VoiceLanguage>((ref) {
  return ref.watch(voiceLanguageProvider);
});

final voiceFeedbackProvider = Provider<VoiceFeedbackService>(
  (ref) {
    // Gated by the persisted Settings toggle (default ON while loading).
    // STT is unaffected — this suppresses spoken confirmations only.
    final enabled = ref.watch(settingsProvider).maybeWhen(
          data: (s) => s.voiceFeedbackEnabled,
          orElse: () => true,
        );
    final language = ref.watch(currentVoiceLanguageProvider);
    final service = TtsFeedbackService(enabled: enabled, language: language);
    ref.onDispose(() => unawaited(service.stop()));
    return service;
  },
);

/// Orchestrates one push-to-talk command:
///
/// listen → parse → match → validate → CartService/CartNotifier.
///
/// The controller reads products through [ProductRepository] and mutates
/// only through the cart notifier — voice NEVER touches the database
/// directly, and unknown/ambiguous/stock-limited commands never mutate
/// the cart. One tap = one command; no continuous listening, no wake word.
class VoiceController extends Notifier<VoiceState> {
  static const _matcher = ProductMatcher();
  static const _parser = CommandParser();

  @override
  VoiceState build() => const VoiceState();

  SpeechToTextService get _speech => ref.read(speechServiceProvider);
  VoiceFeedbackService get _feedback => ref.read(voiceFeedbackProvider);
  ProductRepository get _products => ref.read(productRepositoryProvider);

  VoiceLanguage get _language => ref.read(currentVoiceLanguageProvider);
  VoiceFeedbackText get _feedbackText => VoiceFeedbackText(_language);

  /// Starts one voice command. Concurrent taps while listening/processing
  /// are ignored; any other state (including a pending clarification) is
  /// replaced by the new command.
  Future<void> startVoiceCommand() async {
    if (state.status == VoiceStatus.listening ||
        state.status == VoiceStatus.processing) {
      return;
    }
    state = const VoiceState(status: VoiceStatus.listening);

    final ready = await _speech.initialize();
    if (!ready) {
      final granted = await _speech.hasPermission;
      if (!granted) {
        _fail(_feedbackText.micPermission());
      } else {
        _fail(_feedbackText.sttUnavailable());
      }
      return;
    }

    // Use the selected locale where supported; fall back gracefully inside
    // the STT implementation when the device lacks it.
    final transcript = await _speech
        .listenOnceFor(preferredLocaleId: _language.sttLocaleId);
    final text = (transcript ?? '').trim();
    if (text.isEmpty) {
      _fail(_feedbackText.noSpeech());
      return;
    }
    state = VoiceState(status: VoiceStatus.processing, transcript: text);
    await _execute(_parser.parse(text, language: _language));
  }

  /// Cancels an open microphone and returns to idle.
  Future<void> cancelListening() async {
    await _speech.stop();
    state = const VoiceState();
  }

  /// Dismisses the current result/clarification/confirmation.
  void reset() {
    state = const VoiceState();
  }

  /// Executes a pending clear after the UI's confirmation dialog.
  Future<void> confirmPendingClear() async {
    if (state.status != VoiceStatus.confirmationRequired ||
        state.pending is! ClearCartCommand) {
      return;
    }
    state = state.copyWith(status: VoiceStatus.processing, clearPending: true);
    ref.read(cartProvider.notifier).clearCart();
    _succeed(_feedbackText.cartCleared());
  }

  /// Drops a pending clarification or confirmation.
  void cancelPending() {
    state = const VoiceState();
  }

  /// Runs an ambiguous command against the user-picked candidate.
  Future<void> chooseCandidate(Product product) async {
    final pending = state.pending;
    if (state.status != VoiceStatus.clarificationRequired || pending == null) {
      return;
    }
    state = VoiceState(
      status: VoiceStatus.processing,
      transcript: state.transcript,
    );
    await _executeResolved(pending, product);
  }

  // Execution: match first, then resolve. Unknown/ambiguous/failed
  // commands return before any cart mutation.

  Future<void> _execute(VoiceCommand command) async {
    if (command is CheckoutCommand) return _executeCheckout();
    if (command is ClearCartCommand) return _executeClear();
    if (command is UnknownCommand) {
      _fail(_feedbackText.unknown());
      return;
    }

    List<Product> catalog;
    try {
      catalog = await _products.getAllActive();
    } catch (_) {
      _fail(_feedbackText.productLoadError());
      return;
    }
    final match = _matcher.match(_spokenName(command), catalog);
    switch (match) {
      case ProductMatchUnique(:final product):
        await _executeResolved(command, product);
      case ProductMatchAmbiguous(:final candidates):
        final message = _feedbackText.whichProduct(_spokenName(command));
        state = state.copyWith(
          status: VoiceStatus.clarificationRequired,
          message: message,
          candidates: candidates,
          pending: command,
        );
        _say(message);
      case ProductMatchNone():
        _fail(_feedbackText.productNotFound(_spokenName(command)));
    }
  }

  Future<void> _executeResolved(VoiceCommand command, Product product) async {
    final cart = ref.read(cartProvider.notifier);
    switch (command) {
      case AddProductCommand(:final quantity):
        final failure = cart.addProduct(product, quantity: quantity);
        if (failure != null) {
          _fail(failure.message);
        } else {
          _succeed(_feedbackText.added(product.name, quantity: quantity));
        }
      case RemoveProductCommand(:final quantity):
        final line = ref.read(cartProvider).getItem(product.id);
        if (line == null) {
          _fail(_feedbackText.notInCart(product.name));
          return;
        }
        final Failure? failure;
        if (quantity == null || quantity >= line.quantity) {
          failure = cart.removeProduct(product.id);
        } else {
          failure = cart.setQuantity(product.id, line.quantity - quantity);
        }
        if (failure != null) {
          _fail(failure.message);
        } else {
          _succeed(_feedbackText.removed(product.name));
        }
      case IncreaseProductCommand(:final quantity):
        _mutateLine(
          product,
          quantity == 1
              ? cart.increaseQuantity(product.id)
              : _increaseBy(cart, product.id, quantity),
        );
      case DecreaseProductCommand(:final quantity):
        _mutateLine(
          product,
          quantity == 1
              ? cart.decreaseQuantity(product.id)
              : _decreaseBy(cart, product.id, quantity),
        );
      case SetQuantityCommand(:final quantity):
        _mutateLine(product, cart.setQuantity(product.id, quantity));
      case PriceQueryCommand():
        _succeed(_feedbackText.price(
          product.name,
          Money.formatPaise(product.sellingPricePaise),
        ));
      case StockQueryCommand():
        _succeed(_feedbackText.stock(product.name, product.stockQty));
      case ClearCartCommand():
      case CheckoutCommand():
      case UnknownCommand():
        _fail(_feedbackText.unknown());
    }
  }

  /// Applies repeated +/- as one step (CartService has no bulk step).
  Failure? _increaseBy(CartNotifier cart, int productId, int times) {
    Failure? failure;
    for (var i = 0; i < times; i++) {
      failure = cart.increaseQuantity(productId);
      if (failure != null) break;
    }
    return failure;
  }

  Failure? _decreaseBy(CartNotifier cart, int productId, int times) {
    Failure? failure;
    for (var i = 0; i < times; i++) {
      failure = cart.decreaseQuantity(productId);
      if (failure != null) break;
    }
    return failure;
  }

  /// Reports the post-op quantity, or removal when the line is gone.
  void _mutateLine(Product product, Failure? failure) {
    if (failure != null) {
      _fail(failure.message);
      return;
    }
    final line = ref.read(cartProvider).getItem(product.id);
    if (line == null) {
      _succeed(_feedbackText.removed(product.name));
    } else {
      _succeed(_feedbackText.quantityNow(product.name, line.quantity));
    }
  }

  void _executeClear() {
    if (ref.read(cartProvider).isEmpty) {
      _fail(_feedbackText.cartEmptyWarning());
      return;
    }
    state = state.copyWith(
      status: VoiceStatus.confirmationRequired,
      message: _feedbackText.clearConfirmMessage(),
      pending: const ClearCartCommand(),
    );
  }

  void _executeCheckout() {
    if (ref.read(cartProvider).isEmpty) {
      _fail(_feedbackText.checkoutEmptyWarning());
      return;
    }
    state = state.copyWith(
      status: VoiceStatus.success,
      message: _feedbackText.checkoutOpening(),
      clearPending: true,
      checkoutRequestId: state.checkoutRequestId + 1,
    );
    _say(_feedbackText.checkoutOpening());
  }

  String _spokenName(VoiceCommand command) {
    return switch (command) {
      AddProductCommand(:final productName) => productName,
      RemoveProductCommand(:final productName) => productName,
      IncreaseProductCommand(:final productName) => productName,
      DecreaseProductCommand(:final productName) => productName,
      SetQuantityCommand(:final productName) => productName,
      PriceQueryCommand(:final productName) => productName,
      StockQueryCommand(:final productName) => productName,
      _ => '',
    };
  }

  void _succeed(String message) {
    state = state.copyWith(
      status: VoiceStatus.success,
      message: message,
      candidates: const [],
      clearPending: true,
    );
    _say(message);
  }

  void _fail(String message) {
    state = state.copyWith(
      status: VoiceStatus.error,
      message: message,
      candidates: const [],
      clearPending: true,
    );
    _say(message);
  }

  /// Best-effort spoken feedback: never awaited, never throws.
  void _say(String text) {
    try {
      unawaited(_feedback.speak(text));
    } catch (_) {}
  }
}

final voiceControllerProvider =
    NotifierProvider<VoiceController, VoiceState>(
  VoiceController.new,
);
