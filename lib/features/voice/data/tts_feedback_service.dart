import 'package:flutter_tts/flutter_tts.dart';

import '../domain/speech_services.dart';

/// Short spoken confirmations via `flutter_tts` (platform engine, offline).
/// Fire-and-forget by contract: [speak] never throws and never awaits
/// speech completion, so a slow/missing TTS engine can never stall a sale.
///
/// There is no voice-settings screen in V1; [enabled] keeps the service
/// easy to wire to a Settings toggle later without touching callers.
class TtsFeedbackService implements VoiceFeedbackService {
  TtsFeedbackService({FlutterTts? tts, this.enabled = true})
      : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final bool enabled;
  bool _configured = false;

  @override
  Future<void> speak(String text) async {
    if (!enabled || text.trim().isEmpty) return;
    try {
      if (!_configured) {
        await _tts.setLanguage('en-IN');
        await _tts.setSpeechRate(1.0);
        await _tts.awaitSpeakCompletion(false);
        _configured = true;
      }
      await _tts.speak(text);
    } catch (_) {
      // A silent phone beats a crashed sale.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Test double that records spoken lines instead of playing audio.
class NoopFeedbackService implements VoiceFeedbackService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}
