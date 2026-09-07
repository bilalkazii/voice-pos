/// V1 payment methods. Exactly one value exists: cash.
///
/// Designed as an enum (not scattered raw strings) so future phases can add
/// variants without touching the database layer — storage mapping lives
/// here in one place.
enum PaymentMethod {
  cash;

  /// Database representation.
  String get storage => switch (this) {
        PaymentMethod.cash => 'cash',
      };

  /// Short display label for receipts and the payment-complete screen.
  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
      };

  static PaymentMethod fromStorage(String value) {
    return switch (value) {
      'cash' => PaymentMethod.cash,
      _ => throw ArgumentError.value(value, 'value', 'Unknown payment method'),
    };
  }
}
