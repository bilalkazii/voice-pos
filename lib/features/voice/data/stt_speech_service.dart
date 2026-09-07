import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../domain/speech_services.dart';

/// Production push-to-talk recognition backed by `speech_to_text`
/// (on-device/platform engine — no network AI service).
///
/// Every method is total: it catches plugin errors and always completes,
/// so voice interaction degrades to an error message instead of a crash
/// or a hang. Permission is requested lazily by [initialize], i.e. only
/// when the cashier first taps SPEAK — never at app startup.
class SttSpeechService implements SpeechToTextService {
  SttSpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  Future<bool> initialize() async {
    try {
      final available = await _speech.initialize();
      if (!available) return false;
      return await _speech.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> get hasPermission async {
    try {
      return await _speech.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> listenOnce() async {
    final completer = Completer<String?>();
    void finish(String? value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) finish(result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
          partialResults: false,
          cancelOnError: true,
        ),
      );
    } catch (_) {
      finish(null);
    }

    try {
      // Guard: the engine normally stops itself (pause/timeout) and
      // delivers a final result; this only fires if it wedges.
      final text = await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
      if (text == null || text.trim().isEmpty) return null;
      return text;
    } finally {
      try {
        await _speech.stop();
      } catch (_) {}
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }
}
