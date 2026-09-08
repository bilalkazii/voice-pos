import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/printing/domain/print_result.dart';

void main() {
  group('PrintResult', () {
    test('success, unavailable, and failure are distinguishable types', () {
      const PrintResult success = PrintSuccess();
      const PrintResult unavailable = PrintUnavailable();
      const PrintResult failed = PrintFailed('No paper');

      expect(success, isA<PrintSuccess>());
      expect(unavailable, isA<PrintUnavailable>());
      expect(failed, isA<PrintFailed>());
      expect(success, isNot(unavailable));
      expect(unavailable, isNot(failed));
      expect(success, isNot(failed));
    });

    test('unavailable carries an honest default message', () {
      const result = PrintUnavailable();
      expect(result.message, contains('not configured'));
    });

    test('failed carries the failure message', () {
      const result = PrintFailed('No paper');
      expect(result.message, 'No paper');
    });

    test('success carries no message', () {
      const result = PrintSuccess();
      expect(result.message, isEmpty);
    });

    test('exhaustive switching over the three cases', () {
      String describe(PrintResult result) {
        return switch (result) {
          PrintSuccess() => 'printed',
          PrintUnavailable() => 'unavailable',
          PrintFailed() => 'failed',
        };
      }

      expect(describe(const PrintSuccess()), 'printed');
      expect(describe(const PrintUnavailable()), 'unavailable');
      expect(describe(const PrintFailed('x')), 'failed');
    });
  });
}
