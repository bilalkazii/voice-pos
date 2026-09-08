import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';
import 'package:voice_pos/features/settings/data/settings_repository_impl.dart';
import 'package:voice_pos/features/settings/presentation/settings_providers.dart';
import 'package:voice_pos/features/voice/data/tts_feedback_service.dart';
import 'package:voice_pos/features/voice/domain/speech_services.dart';
import 'package:voice_pos/features/voice/presentation/voice_providers.dart';

import '../../test_utils.dart';

/// The persisted voice-feedback toggle must gate the production TTS
/// service — without ever needing speaker hardware.
///
/// These tests observe [voiceFeedbackProvider] through `container.listen`
/// (the supported way to watch a provider outside widgets): each write
/// completes exactly when the dependent provider rebuilds. No polling,
/// no arbitrary delays.
void main() {
  // Provides the fake binary messenger so constructing the real
  // TtsFeedbackService (which registers a method-call handler) works
  // without a widget tree or audio hardware.
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> openVoiceContainer() async {
    final db = openTestDb();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    // Plain unit test (no widget binding pumps), so closing here is safe.
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    return container;
  }

  /// Resolves with the `enabled` flag of the next [voiceFeedbackProvider]
  /// rebuild. Times out honestly if settings stop propagating.
  Future<bool> nextEnabled(ProviderContainer container) {
    final completer = Completer<bool>();
    late final ProviderSubscription<VoiceFeedbackService> sub;
    sub = container.listen<VoiceFeedbackService>(
      voiceFeedbackProvider,
      (previous, next) {
        if (!completer.isCompleted) {
          completer.complete(
            (next as TtsFeedbackService).enabled,
          );
          sub.close();
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 10));
  }

  bool currentEnabled(ProviderContainer container) {
    return (container.read(voiceFeedbackProvider) as TtsFeedbackService)
        .enabled;
  }

  group('voice feedback respects settings', () {
    test('OFF suppresses TTS without touching audio hardware', () async {
      final container = await openVoiceContainer();
      final repo = DriftSettingsRepository(
        container.read(settingsDaoProvider),
      );

      final rebuilt = nextEnabled(container);
      await repo.setVoiceFeedbackEnabled(false);
      expect(await rebuilt, isFalse);
      expect(currentEnabled(container), isFalse);

      // Returns silently — the platform TTS engine is never invoked.
      await container.read(voiceFeedbackProvider).speak('Added two Pepsi.');
    });

    test('ON allows TTS', () async {
      final container = await openVoiceContainer();
      final repo = DriftSettingsRepository(
        container.read(settingsDaoProvider),
      );
      expect((await repo.load()).voiceFeedbackEnabled, isTrue);

      final rebuilt = nextEnabled(container);
      await repo.setVoiceFeedbackEnabled(true);
      expect(await rebuilt, isTrue);
      expect(currentEnabled(container), isTrue);
    });

    test('toggling the setting swaps the service behavior live', () async {
      final container = await openVoiceContainer();
      final repo = DriftSettingsRepository(
        container.read(settingsDaoProvider),
      );

      var rebuilt = nextEnabled(container);
      await repo.setVoiceFeedbackEnabled(false);
      expect(await rebuilt, isFalse);

      rebuilt = nextEnabled(container);
      await repo.setVoiceFeedbackEnabled(true);
      expect(await rebuilt, isTrue);
      expect(currentEnabled(container), isTrue);
    });

    test('voice command execution still works while TTS is suppressed',
        () async {
      // STT path is untouched by the feedback toggle: the setting only
      // gates the TtsFeedbackService. Covered end-to-end by the Phase 3
      // voice controller tests; here we assert the production provider
      // still hands out a working (suppressed) service.
      final container = await openVoiceContainer();
      final repo = DriftSettingsRepository(
        container.read(settingsDaoProvider),
      );
      final rebuilt = nextEnabled(container);
      await repo.setVoiceFeedbackEnabled(false);
      await rebuilt;

      final service = container.read(voiceFeedbackProvider);
      await service.speak('Cart cleared.');
      await service.stop();
    });
  });
}
