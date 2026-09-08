import '../constants.dart';

/// Safe integer money helpers for Voice POS.
///
/// All money is stored and computed as integer paise (minor units):
/// `11200` means ₹112.00. Never use `double` for money.
abstract final class Money {
  /// Formats [paise] as an INR string, e.g. `11200` → `₹112.00`.
  ///
  /// Negative values keep their sign: `-500` → `-₹5.00`.
  /// No floating point is used — formatting is pure integer math.
  static String formatPaise(int paise) {
    final sign = paise < 0 ? '-' : '';
    final abs = paise.abs();
    final rupees = abs ~/ AppConstants.minorUnitsPerRupee;
    final remainder = abs % AppConstants.minorUnitsPerRupee;
    final rupeesText = _groupThousands(rupees);
    final paiseText = remainder.toString().padLeft(2, '0');
    return '$sign${AppConstants.currencySymbol}$rupeesText.$paiseText';
  }

  /// ASCII-only variant for thermal printers whose code pages lack the
  /// rupee sign: `11200` → `Rs.112.00`. Same integer math and Indian
  /// digit grouping as [formatPaise].
  static String formatPaiseAscii(int paise, {String prefix = 'Rs.'}) {
    final sign = paise < 0 ? '-' : '';
    final abs = paise.abs();
    final rupees = abs ~/ AppConstants.minorUnitsPerRupee;
    final remainder = abs % AppConstants.minorUnitsPerRupee;
    final rupeesText = _groupThousands(rupees);
    final paiseText = remainder.toString().padLeft(2, '0');
    return '$sign$prefix$rupeesText.$paiseText';
  }

  /// Adds two paise amounts.
  static int add(int aPaise, int bPaise) => aPaise + bPaise;

  /// Subtracts [bPaise] from [aPaise].
  static int subtract(int aPaise, int bPaise) => aPaise - bPaise;

  /// Multiplies a unit price by a quantity: both integers, no rounding.
  ///
  /// Throws [ArgumentError] for negative quantities.
  static int multiply(int unitPricePaise, int quantity) {
    if (quantity < 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Quantity cannot be negative',
      );
    }
    return unitPricePaise * quantity;
  }

  /// Sums line totals for a list of paise amounts.
  static int sum(Iterable<int> lineTotalsPaise) =>
      lineTotalsPaise.fold(0, (a, b) => a + b);

  /// Indian digit grouping (lakhs/crores): 12345678 → `1,23,45,678`.
  static String _groupThousands(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;
    final lastThree = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(",")},$lastThree';
  }
}
