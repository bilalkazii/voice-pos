import '../../utils/money.dart';
import '../domain/receipt_data.dart';

/// Pure-Dart ESC/POS encoder for 58mm thermal receipt printers. No Flutter,
/// no Bluetooth, no database — bytes in, bytes out, fully deterministic.
///
/// Design constraints for common low-end printers:
/// - 32 columns (Font A @ 58mm), conservative text-first layout.
/// - The ENTIRE output is 7-bit ASCII (every byte ≤ 127): the rupee sign
///   becomes `Rs.`, anything outside printable ASCII becomes `?`. Printers
///   with limited code pages cannot be corrupted by our output.
/// - No images, barcodes, QR, or custom fonts in V1.
/// - Ends with line feeds + a partial-cut command (`GS V NUL`), which
///   cutters honor and cutterless printers harmlessly ignore.
///
/// Money stays integer paise; multilingual product names fall back to `?`
/// per character (documented V1 limitation — the on-screen receipt keeps
/// full Unicode).
class EscPosEncoder {
  const EscPosEncoder({this.cols = 32});

  /// Printable columns per line for 58mm paper.
  final int cols;

  /// Encodes a full receipt. Deterministic: the same [ReceiptData] always
  /// yields identical bytes.
  List<int> encode(ReceiptData receipt) {
    final out = <int>[];
    out.addAll(_init);
    // Header: store, transaction, date, payment — centered. Every
    // interpolated field is sanitized and wrapped: even system-generated
    // values (transaction numbers) must never leak non-ASCII code units
    // into the byte stream, and no line may exceed the paper width.
    for (final line in wrapText(sanitize(receipt.storeName), cols)) {
      out.addAll(_bold);
      out.addAll(_centered(line));
      out.addAll(_boldOff);
    }
    for (final line in wrapText(
      sanitize('Transaction: ${receipt.transactionNumber}'),
      cols,
    )) {
      out.addAll(_centered(line));
    }
    for (final line in wrapText(sanitize(_formatDate(receipt.createdAt)), cols)) {
      out.addAll(_centered(line));
    }
    for (final line in wrapText(
      sanitize('Payment: ${_paymentLabel(receipt.paymentMethod)}'),
      cols,
    )) {
      out.addAll(_centered(line));
    }
    out.addAll(_text(''));
    out.addAll(_text(_rule()));
    // Items.
    for (final item in receipt.items) {
      for (final line in wrapText(sanitize(item.productName), cols)) {
        out.addAll(_text(line));
      }
      if (item.sku != null && item.sku!.trim().isNotEmpty) {
        for (final line
            in wrapText('SKU: ${sanitize(item.sku!)}', cols)) {
          out.addAll(_text(line));
        }
      }
      out.addAll(
        _text(
          twoColumn(
            '${item.quantity} x ${Money.formatPaiseAscii(item.unitPricePaise)}',
            Money.formatPaiseAscii(item.lineTotalPaise),
            cols,
          ),
        ),
      );
    }
    out.addAll(_text(_rule()));
    out.addAll(
      _text(
        twoColumn(
          'Subtotal',
          Money.formatPaiseAscii(receipt.subtotalPaise),
          cols,
        ),
      ),
    );
    out.addAll(_bold);
    out.addAll(
      _text(
        twoColumn(
          'TOTAL',
          Money.formatPaiseAscii(receipt.totalPaise),
          cols,
        ),
      ),
    );
    out.addAll(_boldOff);
    out.addAll(_text(_rule()));
    out.addAll(_centered('Thank you'));
    out.addAll(const [0x1B, 0x64, 0x03]); // Feed 3 lines.
    out.addAll(const [0x1D, 0x56, 0x00]); // Partial cut.
    return out;
  }

  /// ESC @ — reset printer state.
  static const List<int> _init = [0x1B, 0x40];

  static const List<int> _bold = [0x1B, 0x45, 0x01];
  static const List<int> _boldOff = [0x1B, 0x45, 0x00];

  static List<int> _text(String line) => [...line.codeUnits, 0x0A];

  List<int> _centered(String line) => [0x1B, 0x61, 0x01, ..._text(line)];

  String _rule() => ''.padRight(cols, '-');

  static String _paymentLabel(String code) {
    if (code.toLowerCase() == 'cash') return 'CASH';
    return code.toUpperCase();
  }

  /// Locale-independent receipt timestamp (`7 Sep 2026, 9:42 PM`).
  static String _formatDate(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = value.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '$hour12:$minute $ampm';
  }

  /// Replaces anything outside printable ASCII with `?` (₹ becomes `Rs.`),
  /// and collapses all whitespace runs to single spaces. The result is
  /// guaranteed 7-bit clean.
  static String sanitize(String input) {
    final buffer = StringBuffer();
    var lastWasSpace = true; // Trim leading whitespace implicitly.
    for (final rune in input.runes) {
      if (rune == 0x20B9) {
        // U+20B9 RUPEE SIGN.
        buffer.write('Rs.');
        lastWasSpace = false;
      } else if (rune == 0x0A || rune == 0x0D || rune == 0x09 || rune == 0x20) {
        if (!lastWasSpace) {
          buffer.write(' ');
          lastWasSpace = true;
        }
      } else if (rune >= 0x20 && rune <= 0x7E) {
        buffer.writeCharCode(rune);
        lastWasSpace = false;
      } else {
        buffer.write('?');
        lastWasSpace = false;
      }
    }
    final text = buffer.toString();
    return text.endsWith(' ') ? text.substring(0, text.length - 1) : text;
  }

  /// Wraps [text] to lines of at most [width] columns, breaking on spaces.
  /// Overlong words are hard-split. Never returns an empty list.
  static List<String> wrapText(String text, int width) {
    final words = <String>[];
    for (final raw in text.split(' ')) {
      if (raw.isEmpty) continue;
      var rest = raw;
      while (rest.length > width) {
        words.add(rest.substring(0, width));
        rest = rest.substring(width);
      }
      words.add(rest);
    }
    if (words.isEmpty) return [''];
    final lines = <String>[];
    var current = words.first;
    for (final word in words.skip(1)) {
      if (current.length + 1 + word.length <= width) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    lines.add(current);
    return lines;
  }

  /// Left/right column layout: `left` padded and `right` flush-right.
  /// Overflows spill `right` onto its own right-aligned line so columns
  /// never merge on narrow paper.
  static String twoColumn(String left, String right, int width) {
    if (left.length + 1 + right.length <= width) {
      return '$left${''.padRight(width - left.length - right.length)}$right';
    }
    return '$left\n${''.padRight(width - right.length)}$right';
  }
}
