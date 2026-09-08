import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/printing/domain/receipt_data.dart';
import 'package:voice_pos/core/printing/esc_pos/esc_pos_encoder.dart';
import 'package:voice_pos/core/utils/money.dart';

ReceiptData sampleReceipt() {
  return ReceiptData(
    storeName: 'Kazi Mart',
    transactionNumber: 'VP-1788804734779-1822',
    createdAt: DateTime(2026, 9, 7, 21, 42),
    paymentMethod: 'cash',
    subtotalPaise: 11000,
    totalPaise: 11000,
    items: const [
      ReceiptLineItem(
        productName: 'Pepsi 500ml',
        sku: 'PEP-500',
        unitPricePaise: 4000,
        quantity: 2,
        lineTotalPaise: 8000,
      ),
      ReceiptLineItem(
        productName: 'Lays Classic',
        sku: null,
        unitPricePaise: 3000,
        quantity: 1,
        lineTotalPaise: 3000,
      ),
    ],
  );
}

/// Printable text runs of encoded output (control sequences stripped).
String printableText(List<int> bytes) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < bytes.length) {
    final byte = bytes[i];
    if (byte == 0x1B || byte == 0x1D) {
      // Skip ESC/GS command + parameters (all our commands take ≤2 params).
      i += 3;
    } else if (byte == 0x0A) {
      buffer.write('\n');
      i++;
    } else if (byte >= 0x20 && byte <= 0x7E) {
      buffer.writeCharCode(byte);
      i++;
    } else {
      buffer.write('�');
      i++;
    }
  }
  return buffer.toString();
}

void main() {
  group('Money.formatPaiseAscii', () {
    test('formats with Rs. prefix and Indian grouping', () {
      expect(Money.formatPaiseAscii(0), 'Rs.0.00');
      expect(Money.formatPaiseAscii(1000), 'Rs.10.00');
      expect(Money.formatPaiseAscii(1050), 'Rs.10.50');
      expect(Money.formatPaiseAscii(10025), 'Rs.100.25');
      expect(Money.formatPaiseAscii(1248000), 'Rs.12,480.00');
      expect(Money.formatPaiseAscii(-500), '-Rs.5.00');
    });
  });

  group('EscPosEncoder.encode', () {
    test('starts with ESC @ init and ends with feed + partial cut', () {
      final bytes = const EscPosEncoder().encode(sampleReceipt());

      expect(bytes.sublist(0, 2), [0x1B, 0x40]);
      expect(bytes.sublist(bytes.length - 6), [
        0x1B, 0x64, 0x03, // Feed 3 lines.
        0x1D, 0x56, 0x00, // Partial cut.
      ]);
    });

    test('entire output is 7-bit ASCII', () {
      final bytes = const EscPosEncoder().encode(sampleReceipt());
      for (final byte in bytes) {
        expect(byte, inInclusiveRange(0, 127), reason: 'byte $byte');
      }
    });

    test('contains store, transaction, items, totals, and CASH', () {
      final text = printableText(const EscPosEncoder().encode(sampleReceipt()));

      expect(text, contains('Kazi Mart'));
      expect(text, contains('VP-1788804734779-1822'));
      expect(text, contains('7 Sep 2026, 9:42 PM'));
      expect(text, contains('CASH'));
      expect(text, contains('Pepsi 500ml'));
      expect(text, contains('SKU: PEP-500'));
      expect(text, contains('Lays Classic'));
      expect(text, contains('2 x Rs.40.00'));
      expect(text, contains('Rs.80.00'));
      expect(text, contains('Subtotal'));
      expect(text, contains('TOTAL'));
      expect(text, contains('Rs.110.00'));
      expect(text, contains('Thank you'));
    });

    test('content lines respect the 58mm column width', () {
      final text = printableText(const EscPosEncoder().encode(sampleReceipt()));
      for (final line in text.split('\n')) {
        expect(line.length, lessThanOrEqualTo(32), reason: '"$line"');
      }
    });

    test('line ordering matches the receipt contract', () {
      final text = printableText(const EscPosEncoder().encode(sampleReceipt()));
      final store = text.indexOf('Kazi Mart');
      final txn = text.indexOf('VP-1788804734779-1822');
      final pepsi = text.indexOf('Pepsi 500ml');
      final lays = text.indexOf('Lays Classic');
      final subtotal = text.indexOf('Subtotal');
      final total = text.indexOf('TOTAL');
      final thanks = text.indexOf('Thank you');
      expect(store, lessThan(txn));
      expect(txn, lessThan(pepsi));
      expect(pepsi, lessThan(lays));
      expect(lays, lessThan(subtotal));
      expect(subtotal, lessThan(total));
      expect(total, lessThan(thanks));
    });

    test('deterministic: identical input yields identical bytes', () {
      const encoder = EscPosEncoder();
      final first = encoder.encode(sampleReceipt());
      final second = encoder.encode(sampleReceipt());
      expect(first, second);
    });

    test('long product names wrap without exceeding width', () {
      final receipt = ReceiptData(
        storeName: 'Kazi Mart',
        transactionNumber: 'VP-1',
        createdAt: DateTime(2026, 9, 7),
        paymentMethod: 'cash',
        subtotalPaise: 5000,
        totalPaise: 5000,
        items: const [
          ReceiptLineItem(
            productName:
                'Extraordinarily Long Product Name That Exceeds Thirty Two Columns',
            sku: null,
            unitPricePaise: 5000,
            quantity: 1,
            lineTotalPaise: 5000,
          ),
        ],
      );
      final text = printableText(const EscPosEncoder().encode(receipt));
      expect(text, contains('Extraordinarily Long Product'));
      for (final line in text.split('\n')) {
        expect(line.length, lessThanOrEqualTo(32), reason: '"$line"');
      }
    });

    test('long store names wrap', () {
      final receipt = ReceiptData(
        storeName:
            'Bilal General Store And Provisions Trading Company Limited',
        transactionNumber: 'VP-1',
        createdAt: DateTime(2026, 9, 7),
        paymentMethod: 'cash',
        subtotalPaise: 100,
        totalPaise: 100,
        items: const [],
      );
      final text = printableText(const EscPosEncoder().encode(receipt));
      expect(text, contains('Bilal General Store'));
      for (final line in text.split('\n')) {
        expect(line.length, lessThanOrEqualTo(32), reason: '"$line"');
      }
    });

    test('special characters degrade safely, never corrupt bytes', () {
      final receipt = ReceiptData(
        storeName: 'Café “Kazi” Mart — ₹ Deals ♥✓',
        transactionNumber: 'VP-★-1',
        createdAt: DateTime(2026, 9, 7),
        paymentMethod: 'cash',
        subtotalPaise: 100,
        totalPaise: 100,
        items: const [
          ReceiptLineItem(
            productName: 'Samosa ₹20/pc ★',
            sku: 'SM-☃',
            unitPricePaise: 2000,
            quantity: 1,
            lineTotalPaise: 2000,
          ),
        ],
      );
      final bytes = const EscPosEncoder().encode(receipt);
      for (final byte in bytes) {
        expect(byte, inInclusiveRange(0, 127));
      }
      final text = printableText(bytes);
      expect(text, contains('Rs.'));
      expect(text, isNot(contains('₹')));
      expect(text, isNot(contains('★')));
    });

    test('empty items still produce a valid receipt', () {
      final receipt = ReceiptData(
        storeName: 'Kazi Mart',
        transactionNumber: 'TEST-PRINT',
        createdAt: DateTime(2026, 9, 7),
        paymentMethod: 'cash',
        subtotalPaise: 0,
        totalPaise: 0,
        items: const [],
      );
      final bytes = const EscPosEncoder().encode(receipt);
      expect(bytes.sublist(0, 2), [0x1B, 0x40]);
      expect(bytes.sublist(bytes.length - 6), [
        0x1B, 0x64, 0x03,
        0x1D, 0x56, 0x00,
      ]);
      final text = printableText(bytes);
      expect(text, contains('TEST-PRINT'));
      expect(text, contains('Rs.0.00'));
    });
  });

  group('EscPosEncoder helpers', () {
    test('sanitize keeps printable ASCII and maps rupee', () {
      expect(EscPosEncoder.sanitize('Pepsi 500ml'), 'Pepsi 500ml');
      expect(EscPosEncoder.sanitize('₹20'), 'Rs.20');
      expect(EscPosEncoder.sanitize('a  b\tc\nd'), 'a b c d');
      expect(EscPosEncoder.sanitize('  padded  '), 'padded');
      expect(EscPosEncoder.sanitize('naïve ♥'), 'na?ve ?');
      expect(EscPosEncoder.sanitize(''), '');
    });

    test('wrapText breaks on spaces and hard-splits long words', () {
      expect(EscPosEncoder.wrapText('a b c', 10), ['a b c']);
      expect(
        EscPosEncoder.wrapText('aaa bbb ccc', 7),
        ['aaa bbb', 'ccc'],
      );
      expect(
        EscPosEncoder.wrapText('x' * 40, 32).every((l) => l.length <= 32),
        isTrue,
      );
      expect(EscPosEncoder.wrapText('', 32), ['']);
    });

    test('twoColumn aligns right and spills on overflow', () {
      expect(
        EscPosEncoder.twoColumn('TOTAL', 'Rs.110.00', 32),
        'TOTAL${' ' * 18}Rs.110.00',
      );
      final spilled = EscPosEncoder.twoColumn('2 x Rs.40.00', 'Rs.80.00', 10);
      expect(spilled, contains('\n'));
      expect(spilled.split('\n').last.trim(), 'Rs.80.00');
    });
  });
}
