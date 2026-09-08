import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:voice_pos/features/voice/data/tts_feedback_service.dart';

/// Records engine calls instead of touching audio hardware.
class RecordingTts extends FlutterTts {
  RecordingTts();

  final List<String> calls = [];
  bool throwOnSpeak = false;

  @override
  Future<dynamic> setLanguage(String language) async {
    calls.add('language:$language');
    return null;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    calls.add('rate:$rate');
    return null;
  }

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {
    calls.add('awaitCompletion:$awaitCompletion');
    return null;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    if (throwOnSpeak) throw StateError('engine blew up');
    calls.add('speak:$text');
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    calls.add('stop');
    return null;
  }
}

void main() {
  // The real FlutterTts constructor registers a method-call handler, so
  // these unit tests need the (fake) binding — no audio is ever produced.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsFeedbackService speech lifecycle', () {
    test('rapid speaks flush overlapping speech instead of queueing',
        () async {
      final engine = RecordingTts();
      final service = TtsFeedbackService(tts: engine);

      await service.speak('Added two Pepsi.');
      await service.speak('Removed Pepsi.');

      // Each utterance stops the previous one first: stop always
      // immediately precedes its speak.
      final speaks = engine.calls.where((c) => c.startsWith('speak:'));
      expect(speaks, ['speak:Added two Pepsi.', 'speak:Removed Pepsi.']);
      for (var i = 0; i < engine.calls.length; i++) {
        if (engine.calls[i].startsWith('speak:')) {
          expect(i, greaterThan(0));
          expect(engine.calls[i - 1], 'stop');
        }
      }
    });

    test('disabled service never touches the engine', () async {
      final engine = RecordingTts();
      final service = TtsFeedbackService(tts: engine, enabled: false);

      await service.speak('Added two Pepsi.');

      expect(engine.calls, isEmpty);
    });

    test('blank text never touches the engine', () async {
      final engine = RecordingTts();
      final service = TtsFeedbackService(tts: engine);

      await service.speak('   ');

      expect(engine.calls, isEmpty);
    });

    test('engine failure completes silently without breaking flow', () async {
      final engine = RecordingTts()..throwOnSpeak = true;
      final service = TtsFeedbackService(tts: engine);

      // Must not throw: POS functionality continues with a silent phone.
      await service.speak('Added two Pepsi.');
      await service.stop();
    });
  });
}
