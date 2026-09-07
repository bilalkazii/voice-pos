import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/features/cart/presentation/cart_providers.dart';
import 'package:voice_pos/features/products/domain/product.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';
import 'package:voice_pos/features/voice/domain/voice_state.dart';
import 'package:voice_pos/features/voice/presentation/voice_providers.dart';

import 'fakes.dart';

/// Drives [VoiceController] through a [ProviderContainer] with fakes —
/// no widgets, no microphone, no database.
Future<ProviderContainer> openVoiceContainer({
  String? transcript,
  bool available = true,
  bool permissionGranted = true,
  List<Product> initialCatalog = const [],
}) async {
  final speech = FakeSpeechService(
    transcript: transcript,
    available: available,
    permissionGranted: permissionGranted,
  );
  final feedback = FakeFeedbackService();
  final repo = FakeProductRepository(List.of(initialCatalog));
  final container = ProviderContainer(
    overrides: [
      speechServiceProvider.overrideWithValue(speech),
      voiceFeedbackProvider.overrideWithValue(feedback),
      productRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<VoiceState> runCommand(
  ProviderContainer container,
  String transcript,
) async {
  final speech =
      container.read(speechServiceProvider) as FakeSpeechService;
  speech.transcript = transcript;
  await container.read(voiceControllerProvider.notifier).startVoiceCommand();
  return container.read(voiceControllerProvider);
}

void main() {
  group('states', () {
    test('starts idle', () async {
      final container = await openVoiceContainer();
      expect(
        container.read(voiceControllerProvider).status,
        VoiceStatus.idle,
      );
    });

    test('permission denied yields error without listening', () async {
      final container = await openVoiceContainer(permissionGranted: false);
      final state = await runCommand(container, 'Add Pepsi');
      expect(state.status, VoiceStatus.error);
      expect(state.message, contains('permission'));
      final speech =
          container.read(speechServiceProvider) as FakeSpeechService;
      expect(speech.listenCalls, 0);
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('recognition unavailable yields error', () async {
      final container = await openVoiceContainer(available: false);
      final state = await runCommand(container, 'Add Pepsi');
      expect(state.status, VoiceStatus.error);
      expect(state.message, contains('unavailable'));
    });

    test('empty transcript yields error', () async {
      final container = await openVoiceContainer(transcript: '   ');
      final state = await runCommand(container, '   ');
      expect(state.status, VoiceStatus.error);
      expect(state.message, contains("Didn't catch that"));
    });

    test('concurrent start while listening is ignored', () async {
      final container = await openVoiceContainer(transcript: 'Add Pepsi');
      final controller =
          container.read(voiceControllerProvider.notifier);
      // Two overlapping starts: the second must not disturb the first.
      await Future.wait([
        controller.startVoiceCommand(),
        controller.startVoiceCommand(),
      ]);
      final speech =
          container.read(speechServiceProvider) as FakeSpeechService;
      expect(speech.listenCalls, 1);
    });
  });

  group('add execution', () {
    test('add product updates cart and reports success', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi', price: 2000)],
      );
      final state = await runCommand(container, 'Add 2 Pepsi');
      expect(state.status, VoiceStatus.success);
      expect(state.transcript, 'Add 2 Pepsi');
      expect(state.message, 'Added 2 Pepsi.');
      final cart = container.read(cartProvider);
      expect(cart.items.single.quantity, 2);
      expect(cart.totalPaise, 4000);
      final feedback =
          container.read(voiceFeedbackProvider) as FakeFeedbackService;
      expect(feedback.spoken, contains('Added 2 Pepsi.'));
    });

    test('unknown product yields error and empty cart', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi')],
      );
      final state = await runCommand(container, 'Add Sprite');
      expect(state.status, VoiceStatus.error);
      expect(state.message, contains('not found'));
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('ambiguous product asks for clarification without mutating', () async {
      final container = await openVoiceContainer(
        initialCatalog: [
          makeVoiceProduct(id: 1, name: 'Pepsi'),
          makeVoiceProduct(id: 2, name: 'Pepsi Zero'),
        ],
      );
      final state = await runCommand(container, 'Add Pepsi');
      expect(state.status, VoiceStatus.clarificationRequired);
      expect(state.candidates.length, 2);
      expect(state.message, contains('Which'));
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('choosing a candidate executes the pending command', () async {
      final container = await openVoiceContainer(
        initialCatalog: [
          makeVoiceProduct(id: 1, name: 'Pepsi'),
          makeVoiceProduct(id: 2, name: 'Pepsi Zero'),
        ],
      );
      await runCommand(container, 'Add Pepsi');
      final controller =
          container.read(voiceControllerProvider.notifier);
      await controller.chooseCandidate(makeVoiceProduct(id: 2, name: 'Pepsi Zero'));
      final state = container.read(voiceControllerProvider);
      expect(state.status, VoiceStatus.success);
      final cart = container.read(cartProvider);
      expect(cart.items.single.productName, 'Pepsi Zero');
    });

    test('insufficient stock fails without corrupting cart', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi', stock: 1)],
      );
      final first = await runCommand(container, 'Add Pepsi');
      expect(first.status, VoiceStatus.success);
      final second = await runCommand(container, 'Add 5 Pepsi');
      expect(second.status, VoiceStatus.error);
      expect(second.message, contains('Only 1'));
      expect(container.read(cartProvider).items.single.quantity, 1);
    });

    test('unknown command never mutates cart', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi')],
      );
      final state =
          await runCommand(container, 'I think I might need Pepsi later');
      expect(state.status, VoiceStatus.error);
      expect(container.read(cartProvider).isEmpty, isTrue);
    });
  });

  group('cart mutations via voice', () {
    Future<ProviderContainer> openWithPepsiInCart() async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi', price: 2000)],
      );
      await runCommand(container, 'Add 2 Pepsi');
      return container;
    }

    test('remove product', () async {
      final container = await openWithPepsiInCart();
      final state = await runCommand(container, 'Remove Pepsi');
      expect(state.status, VoiceStatus.success);
      expect(state.message, 'Removed Pepsi.');
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('remove absent product reports not-in-cart', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi')],
      );
      final state = await runCommand(container, 'Remove Pepsi');
      expect(state.status, VoiceStatus.error);
      expect(state.message, contains('not in the cart'));
    });

    test('increase product', () async {
      final container = await openWithPepsiInCart();
      final state = await runCommand(container, 'Increase Pepsi');
      expect(state.status, VoiceStatus.success);
      expect(container.read(cartProvider).items.single.quantity, 3);
    });

    test('decrease product', () async {
      final container = await openWithPepsiInCart();
      final state = await runCommand(container, 'Decrease Pepsi');
      expect(state.status, VoiceStatus.success);
      expect(container.read(cartProvider).items.single.quantity, 1);
    });

    test('set quantity', () async {
      final container = await openWithPepsiInCart();
      final state = await runCommand(container, 'Set Pepsi quantity to 5');
      expect(state.status, VoiceStatus.success);
      expect(state.message, 'Pepsi quantity 5.');
      expect(container.read(cartProvider).items.single.quantity, 5);
    });
  });

  group('queries do not mutate', () {
    test('price query answers without touching cart', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi', price: 2000)],
      );
      final state = await runCommand(container, 'What is the price of Pepsi?');
      expect(state.status, VoiceStatus.success);
      expect(state.message, '"Pepsi" costs ₹20.00.');
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('stock query answers without touching cart', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi', stock: 12)],
      );
      final state =
          await runCommand(container, 'How many Pepsi are in stock?');
      expect(state.status, VoiceStatus.success);
      expect(state.message, '"Pepsi" has 12 in stock.');
      expect(container.read(cartProvider).isEmpty, isTrue);
    });
  });

  group('clear cart confirmation', () {
    test('clear asks for confirmation, cart intact until confirmed', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi')],
      );
      await runCommand(container, 'Add Pepsi');
      final asking = await runCommand(container, 'Clear cart');
      expect(asking.status, VoiceStatus.confirmationRequired);
      expect(container.read(cartProvider).isNotEmpty, isTrue);

      await container
          .read(voiceControllerProvider.notifier)
          .confirmPendingClear();
      final done = container.read(voiceControllerProvider);
      expect(done.status, VoiceStatus.success);
      expect(done.message, 'Cart cleared.');
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('cancel keeps the cart', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi')],
      );
      await runCommand(container, 'Add Pepsi');
      await runCommand(container, 'Clear cart');
      container.read(voiceControllerProvider.notifier).cancelPending();
      expect(
        container.read(voiceControllerProvider).status,
        VoiceStatus.idle,
      );
      expect(container.read(cartProvider).isNotEmpty, isTrue);
    });

    test('clear on empty cart reports without confirming', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi')],
      );
      final state = await runCommand(container, 'Clear cart');
      expect(state.status, VoiceStatus.error);
      expect(state.message, contains('already empty'));
    });
  });

  group('checkout command', () {
    test('empty cart refuses checkout', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi')],
      );
      final state = await runCommand(container, 'Checkout');
      expect(state.status, VoiceStatus.error);
      expect(state.checkoutRequestId, 0);
    });

    test('non-empty cart requests checkout navigation once', () async {
      final container = await openVoiceContainer(
        initialCatalog: [makeVoiceProduct(name: 'Pepsi')],
      );
      await runCommand(container, 'Add Pepsi');
      final before =
          container.read(voiceControllerProvider).checkoutRequestId;
      final state = await runCommand(container, 'Checkout');
      expect(state.status, VoiceStatus.success);
      expect(state.checkoutRequestId, before + 1);
      // No payment, no sale, no inventory change — cart intact.
      expect(container.read(cartProvider).isNotEmpty, isTrue);
    });
  });
}
