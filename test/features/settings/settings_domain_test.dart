import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/errors/failures.dart';
import 'package:voice_pos/features/settings/domain/app_settings.dart';
import 'package:voice_pos/features/voice/domain/voice_language.dart';

void main() {
  group('defaults', () {
    test('stable defaults for fresh installs and migrations', () {
      expect(AppSettings.defaults.storeName, 'My Store');
      expect(AppSettings.defaults.voiceFeedbackEnabled, isTrue);
      expect(AppSettings.defaults.defaultLowStockThreshold, 5);
      expect(AppSettings.defaults.selectedPrinterId, isNull);
      expect(AppSettings.defaults.hasPrinterConfigured, isFalse);
      expect(AppSettings.defaults.voiceLanguage, VoiceLanguage.english);
    });
  });

  group('validateStoreName', () {
    test('trims surrounding whitespace', () {
      expect(
        AppSettings.validateStoreName('  Bilal General Store  '),
        'Bilal General Store',
      );
    });

    test('rejects blank input', () {
      expect(
        () => AppSettings.validateStoreName('   '),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => AppSettings.validateStoreName(''),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects overlong names', () {
      final tooLong = List.filled(AppSettings.maxStoreNameLength + 1, 'x')
          .join();
      expect(
        () => AppSettings.validateStoreName(tooLong),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('accepts exactly the maximum length', () {
      final exact =
          List.filled(AppSettings.maxStoreNameLength, 'x').join();
      expect(AppSettings.validateStoreName(exact), exact);
    });
  });

  group('validateThreshold', () {
    test('accepts zero and positive values', () {
      expect(AppSettings.validateThreshold(0), 0);
      expect(AppSettings.validateThreshold(5), 5);
      expect(AppSettings.validateThreshold(100), 100);
    });

    test('rejects negative values', () {
      expect(
        () => AppSettings.validateThreshold(-1),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('copyWith', () {
    test('updates selected fields; clearPrinter resets both', () {
      const base = AppSettings.defaults;
      final renamed = base.copyWith(storeName: 'Shop');
      expect(renamed.storeName, 'Shop');
      expect(renamed.voiceFeedbackEnabled, isTrue);

      const withPrinter = AppSettings(
        storeName: 'Shop',
        voiceFeedbackEnabled: true,
        voiceLanguage: VoiceLanguage.english,
        defaultLowStockThreshold: 5,
        selectedPrinterId: 'AA',
        selectedPrinterName: 'P',
      );
      final cleared = withPrinter.copyWith(clearPrinter: true);
      expect(cleared.selectedPrinterId, isNull);
      expect(cleared.selectedPrinterName, isNull);

      final switched = base.copyWith(
        voiceLanguage: VoiceLanguage.marathi,
      );
      expect(switched.voiceLanguage, VoiceLanguage.marathi);
      expect(switched.voiceLanguage, isNot(base.voiceLanguage));
    });
  });
}
