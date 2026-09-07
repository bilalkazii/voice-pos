import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/features/voice/domain/command_parser.dart';
import 'package:voice_pos/features/voice/domain/voice_command.dart';

void main() {
  const parser = CommandParser();

  group('add', () {
    test('Add 2 Pepsi', () {
      final cmd = parser.parse('Add 2 Pepsi');
      expect(cmd, isA<AddProductCommand>());
      expect((cmd as AddProductCommand).productName, 'pepsi');
      expect(cmd.quantity, 2);
    });

    test('Add two Pepsi (number word)', () {
      final cmd = parser.parse('Add two Pepsi') as AddProductCommand;
      expect(cmd.productName, 'pepsi');
      expect(cmd.quantity, 2);
    });

    test('Add three Maggi', () {
      final cmd = parser.parse('Add three Maggi') as AddProductCommand;
      expect(cmd.productName, 'maggi');
      expect(cmd.quantity, 3);
    });

    test('defaults to quantity 1', () {
      final cmd = parser.parse('Add Pepsi') as AddProductCommand;
      expect(cmd.quantity, 1);
    });

    test('strips trailing to cart', () {
      final cmd = parser.parse('Add Pepsi to cart') as AddProductCommand;
      expect(cmd.productName, 'pepsi');
    });
  });

  group('remove', () {
    test('Remove one Pepsi', () {
      final cmd = parser.parse('Remove one Pepsi') as RemoveProductCommand;
      expect(cmd.productName, 'pepsi');
      expect(cmd.quantity, 1);
    });

    test('Remove 1 Pepsi', () {
      final cmd = parser.parse('Remove 1 Pepsi') as RemoveProductCommand;
      expect(cmd.quantity, 1);
    });

    test('Remove without quantity clears the line', () {
      final cmd = parser.parse('Remove Pepsi') as RemoveProductCommand;
      expect(cmd.quantity, isNull);
    });
  });

  group('increase / decrease', () {
    test('Increase Pepsi', () {
      final cmd = parser.parse('Increase Pepsi') as IncreaseProductCommand;
      expect(cmd.productName, 'pepsi');
      expect(cmd.quantity, 1);
    });

    test('Increase Pepsi by 2', () {
      final cmd = parser.parse('Increase Pepsi by 2') as IncreaseProductCommand;
      expect(cmd.quantity, 2);
    });

    test('Decrease Pepsi', () {
      final cmd = parser.parse('Decrease Pepsi') as DecreaseProductCommand;
      expect(cmd.quantity, 1);
    });

    test('Decrease Pepsi by two (word)', () {
      final cmd =
          parser.parse('Decrease Pepsi by two') as DecreaseProductCommand;
      expect(cmd.quantity, 2);
    });

    test('unparseable by-quantity is unknown, not guessed', () {
      expect(parser.parse('Increase Pepsi by lots'), isA<UnknownCommand>());
    });
  });

  group('set quantity', () {
    test('Set Pepsi quantity to 5', () {
      final cmd =
          parser.parse('Set Pepsi quantity to 5') as SetQuantityCommand;
      expect(cmd.productName, 'pepsi');
      expect(cmd.quantity, 5);
    });

    test('Make Pepsi quantity five', () {
      final cmd =
          parser.parse('Make Pepsi quantity five') as SetQuantityCommand;
      expect(cmd.quantity, 5);
    });

    test('Change Pepsi quantity to 5', () {
      final cmd =
          parser.parse('Change Pepsi quantity to 5') as SetQuantityCommand;
      expect(cmd.quantity, 5);
    });
  });

  group('clear cart', () {
    test('Clear cart', () {
      expect(parser.parse('Clear cart'), isA<ClearCartCommand>());
    });

    test('Clear the cart', () {
      expect(parser.parse('Clear the cart'), isA<ClearCartCommand>());
    });

    test('Empty cart', () {
      expect(parser.parse('Empty cart'), isA<ClearCartCommand>());
    });
  });

  group('price queries', () {
    test("What's the price of Pepsi?", () {
      final cmd =
          parser.parse("What's the price of Pepsi?") as PriceQueryCommand;
      expect(cmd.productName, 'pepsi');
    });

    test('How much is Pepsi?', () {
      final cmd = parser.parse('How much is Pepsi?') as PriceQueryCommand;
      expect(cmd.productName, 'pepsi');
    });

    test('Price of Pepsi', () {
      final cmd = parser.parse('Price of Pepsi') as PriceQueryCommand;
      expect(cmd.productName, 'pepsi');
    });

    test('How much does Pepsi cost', () {
      final cmd =
          parser.parse('How much does Pepsi cost') as PriceQueryCommand;
      expect(cmd.productName, 'pepsi');
    });
  });

  group('stock queries', () {
    test('How many Pepsi are in stock?', () {
      final cmd = parser.parse('How many Pepsi are in stock?')
          as StockQueryCommand;
      expect(cmd.productName, 'pepsi');
    });

    test('How much Pepsi is left?', () {
      final cmd =
          parser.parse('How much Pepsi is left?') as StockQueryCommand;
      expect(cmd.productName, 'pepsi');
    });

    test('Pepsi stock', () {
      final cmd = parser.parse('Pepsi stock') as StockQueryCommand;
      expect(cmd.productName, 'pepsi');
    });
  });

  group('checkout', () {
    test('Checkout', () {
      expect(parser.parse('Checkout'), isA<CheckoutCommand>());
    });

    test('Check out', () {
      expect(parser.parse('Check out'), isA<CheckoutCommand>());
    });
  });

  group('unknown', () {
    test('conversational sentence is unknown', () {
      expect(
        parser.parse('I think I might need some Pepsi later'),
        isA<UnknownCommand>(),
      );
    });

    test('empty transcript is unknown', () {
      expect(parser.parse('   '), isA<UnknownCommand>());
    });

    test('unparseable number is unknown', () {
      expect(parser.parse('Add twenty two Pepsi'), isA<UnknownCommand>());
    });

    test('missing product name is unknown', () {
      expect(parser.parse('Add 2'), isA<UnknownCommand>());
    });

    test('random words are unknown', () {
      expect(parser.parse('Hello there'), isA<UnknownCommand>());
    });
  });

  group('normalization', () {
    test('case and punctuation insensitive', () {
      final cmd = parser.parse('  ADD 2, PEPSI!! ') as AddProductCommand;
      expect(cmd.productName, 'pepsi');
      expect(cmd.quantity, 2);
    });

    test('please is stripped', () {
      expect(
        parser.parse('Please add 2 Pepsi please'),
        isA<AddProductCommand>(),
      );
    });

    test('hyphen treated as space', () {
      expect(parser.parse('Check-out'), isA<CheckoutCommand>());
    });
  });

  group('number words', () {
    test('zero through twenty', () {
      const words = {
        'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
        'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
        'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
        'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
        'nineteen': 19, 'twenty': 20,
      };
      words.forEach((word, value) {
        expect(CommandParser.tryParseQuantity(word), value, reason: word);
      });
    });

    test('digits and bounds', () {
      expect(CommandParser.tryParseQuantity('7'), 7);
      expect(CommandParser.tryParseQuantity('007'), 7);
      expect(CommandParser.tryParseQuantity('-1'), isNull);
      expect(CommandParser.tryParseQuantity('abc'), isNull);
      expect(CommandParser.tryParseQuantity('1.5'), isNull);
      expect(CommandParser.tryParseQuantity(''), isNull);
    });
  });
}
