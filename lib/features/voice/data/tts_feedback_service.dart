import 'package:flutter_tts/flutter_tts.dart';

import '../domain/speech_services.dart';
import '../domain/voice_language.dart';

/// Short spoken confirmations via `flutter_tts` (platform engine, offline).
/// Fire-and-forget by contract: [speak] never throws and never awaits
/// speech completion, so a slow/missing TTS engine can never stall a sale.
///
/// Each utterance stops any in-flight speech first, so rapid voice commands
/// replace — rather than queue behind — the previous confirmation.
///
/// The configured [language] selects the Android TTS locale where supported
/// (en-IN / hi-IN / mr-IN). If the requested locale is unavailable, the
/// engine keeps its current voice — the utterance is still attempted and
/// POS operations are never blocked by a missing voice.
class TtsFeedbackService implements VoiceFeedbackService {
  TtsFeedbackService({
    FlutterTts? tts,
    this.enabled = true,
    this.language = VoiceLanguage.english,
  }) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final bool enabled;
  final VoiceLanguage language;
  bool _configured = false;

  @override
  Future<void> speak(String text) async {
    if (!enabled || text.trim().isEmpty) return;
    try {
      if (!_configured) {
        final locale = language.ttsLocaleId;
        if (locale != null) {
          await _tts.setLanguage(locale);
        }
        await _tts.setSpeechRate(1.0);
        await _tts.awaitSpeakCompletion(false);
        _configured = true;
      }
      // Flush: a new confirmation replaces overlapping speech instead of
      // queueing behind it during rapid voice commands.
      await _tts.stop();
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
